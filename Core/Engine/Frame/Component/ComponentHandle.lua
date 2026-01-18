-- [ ORBIT COMPONENT HANDLE ]------------------------------------------------------------------------
-- Creates and manages drag handles for component editing.
-- Handles are invisible overlays that enable drag interaction.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.ComponentHandle = {}
local Handle = Engine.ComponentHandle

-- Import helpers
local Helpers = Engine.ComponentHelpers
local SafeGetSize = Helpers.SafeGetSize
local SafeGetNumber = Helpers.SafeGetNumber


-- [ CONFIGURATION ]-----------------------------------------------------------------------------

local MIN_HANDLE_WIDTH = 50
local MIN_HANDLE_HEIGHT = 20

-- [ HANDLE POOL ]-------------------------------------------------------------------------------

local handlePool = {}

local function AcquireHandle()
    return table.remove(handlePool)
end

local function ReleaseHandle(handle)
    if handle then
        handle:Hide()
        handle:SetScript("OnUpdate", nil)
        handle:SetScript("OnEnter", nil)
        handle:SetScript("OnLeave", nil)
        handle:SetScript("OnMouseDown", nil)
        handle:SetScript("OnMouseUp", nil)
        table.insert(handlePool, handle)
    end
end

-- [ CREATE HANDLE ]-----------------------------------------------------------------------------

function Handle:Create(component, parent, callbacks)
    if not component then return nil end
    
    callbacks = callbacks or {}
    
    -- Try pool first
    local handle = AcquireHandle()
    
    if not handle then
        -- Create new handle frame
        handle = CreateFrame("Frame", nil, UIParent)
        handle:SetFrameStrata("FULLSCREEN_DIALOG")
        handle:SetFrameLevel(200)
        
        -- Background texture
        handle.bg = handle:CreateTexture(nil, "BACKGROUND")
        handle.bg:SetAllPoints()
        handle.bg:SetColorTexture(0.3, 0.8, 0.3, 0)
        
        -- Border textures
        local borderSize = 1
        handle.borderTop = handle:CreateTexture(nil, "BORDER")
        handle.borderTop:SetColorTexture(0.3, 0.8, 0.3, 0)
        handle.borderTop:SetPoint("TOPLEFT", 0, 0)
        handle.borderTop:SetPoint("TOPRIGHT", 0, 0)
        handle.borderTop:SetHeight(borderSize)
        
        handle.borderBottom = handle:CreateTexture(nil, "BORDER")
        handle.borderBottom:SetColorTexture(0.3, 0.8, 0.3, 0)
        handle.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
        handle.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
        handle.borderBottom:SetHeight(borderSize)
        
        handle.borderLeft = handle:CreateTexture(nil, "BORDER")
        handle.borderLeft:SetColorTexture(0.3, 0.8, 0.3, 0)
        handle.borderLeft:SetPoint("TOPLEFT", 0, 0)
        handle.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
        handle.borderLeft:SetWidth(borderSize)
        
        handle.borderRight = handle:CreateTexture(nil, "BORDER")
        handle.borderRight:SetColorTexture(0.3, 0.8, 0.3, 0)
        handle.borderRight:SetPoint("TOPRIGHT", 0, 0)
        handle.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
        handle.borderRight:SetWidth(borderSize)
        
        -- Color helper
        function handle:SetHandleColor(r, g, b, bgAlpha, borderAlpha)
            self.bg:SetColorTexture(r, g, b, bgAlpha)
            self.borderTop:SetColorTexture(r, g, b, borderAlpha)
            self.borderBottom:SetColorTexture(r, g, b, borderAlpha)
            self.borderLeft:SetColorTexture(r, g, b, borderAlpha)
            self.borderRight:SetColorTexture(r, g, b, borderAlpha)
        end
    end
    
    -- Store references
    handle.component = component
    handle.parent = parent
    handle.callbacks = callbacks
    handle.isDragging = false
    
    -- Size update function
    local function UpdateHandleSize()
        local width, height = SafeGetSize(component)
        local handleW = math.max(width, MIN_HANDLE_WIDTH)
        local handleH = math.max(height, MIN_HANDLE_HEIGHT)
        handle:SetSize(handleW, handleH)
        handle:ClearAllPoints()
        handle:SetPoint("CENTER", component, "CENTER", 0, 0)
    end
    
    handle.UpdateSize = UpdateHandleSize
    UpdateHandleSize()
    
    -- Enable mouse
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    
    -- Hover scripts
    handle:SetScript("OnEnter", function(self)
        if callbacks.isSelected and callbacks.isSelected(component) then
            self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.6)
        else
            self:SetHandleColor(0.3, 0.8, 0.3, 0.05, 0.4)
        end
        SetCursor("Interface\\CURSOR\\UI-Cursor-Move")
        if callbacks.onEnter then callbacks.onEnter(component) end
    end)
    
    handle:SetScript("OnLeave", function(self)
        if not self.isDragging then
            if callbacks.isSelected and callbacks.isSelected(component) then
                self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
            else
                self:SetHandleColor(0.3, 0.8, 0.3, 0, 0)
            end
        end
        ResetCursor()
        if callbacks.onLeave then callbacks.onLeave(component) end
    end)
    
    -- Mouse down - select and start drag
    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if callbacks.onSelect then callbacks.onSelect(component) end
            
            self.isDragging = true
            self:SetHandleColor(0.3, 1, 0.3, 0.35, 0.8)
            
            -- Store drag offset
            local cursorX, cursorY = GetCursorPosition()
            local compScale = SafeGetNumber(component:GetEffectiveScale(), 1)
            cursorX, cursorY = cursorX / compScale, cursorY / compScale
            
            local compWidth, compHeight = SafeGetSize(component)
            local compLeft = SafeGetNumber(component:GetLeft(), 0)
            local compBottom = SafeGetNumber(component:GetBottom(), 0)
            local compCenterX = compLeft + compWidth / 2
            local compCenterY = compBottom + compHeight / 2
            
            self.dragOffsetX = compCenterX - cursorX
            self.dragOffsetY = compCenterY - cursorY
            
            -- Drag update loop
            self:SetScript("OnUpdate", function(self)
                if not IsMouseButtonDown("LeftButton") then
                    self.isDragging = false
                    self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
                    self:SetScript("OnUpdate", nil)
                    if callbacks.onDragStop then callbacks.onDragStop(component, self) end
                    return
                end
                if callbacks.onDragUpdate then callbacks.onDragUpdate(component, self) end
            end)
        end
    end)
    
    -- Mouse up backup
    handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isDragging then
            self.isDragging = false
            self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
            self:SetScript("OnUpdate", nil)
            if callbacks.onDragStop then callbacks.onDragStop(component, self) end
        end
    end)
    
    -- Hook SetText for FontStrings
    if component.SetText then
        hooksecurefunc(component, "SetText", function()
            C_Timer.After(0, UpdateHandleSize)
        end)
    end
    
    handle:Hide()
    return handle
end

-- [ RELEASE HANDLE ]----------------------------------------------------------------------------

function Handle:Release(handle)
    ReleaseHandle(handle)
end

-- [ CLEAR POOL ]------------------------------------------------------------------------------

function Handle:ClearPool()
    for _, h in ipairs(handlePool) do
        h:SetParent(nil)
    end
    wipe(handlePool)
end
