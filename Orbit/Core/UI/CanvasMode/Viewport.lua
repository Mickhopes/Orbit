-- [ CANVAS MODE - VIEWPORT ]--------------------------------------------------------
-- Viewport with zoom/pan controls for Canvas Mode
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants

-- [ PREVIEW CONTAINER ]-------------------------------------------------------------------------
-- Architecture: PreviewContainer > Viewport (clips) > TransformLayer (zoom/pan) > PreviewFrame

Dialog.PreviewContainer = CreateFrame("Frame", nil, Dialog)
Dialog.PreviewContainer:SetPoint("TOPLEFT", Dialog, "TOPLEFT", C.VIEWPORT_PADDING, -C.TITLE_HEIGHT)
Dialog.PreviewContainer:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -C.VIEWPORT_PADDING, C.FOOTER_HEIGHT + C.DOCK_HEIGHT + 10)

-- Viewport: Clips children to create the viewable area
Dialog.Viewport = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.Viewport:SetAllPoints()
Dialog.Viewport:SetClipsChildren(true)
Dialog.Viewport:EnableMouse(true)
Dialog.Viewport:EnableMouseWheel(true)
Dialog.Viewport:RegisterForDrag("MiddleButton", "LeftButton")

-- TransformLayer: Receives zoom (SetScale) and pan (position offset)
Dialog.TransformLayer = CreateFrame("Frame", nil, Dialog.Viewport)
Dialog.TransformLayer:SetSize(1, 1)  -- Size managed dynamically
Dialog.TransformLayer:SetPoint("CENTER", Dialog.Viewport, "CENTER", 0, 0)

-- [ ZOOM/PAN HELPERS ]-----------------------------------------------------------------------

-- Calculate pan clamping bounds
local function GetPanBounds(transformLayer, viewport, zoomLevel)
    local baseWidth = transformLayer.baseWidth or 200
    local baseHeight = transformLayer.baseHeight or 60
    local scaledW = baseWidth * zoomLevel
    local scaledH = baseHeight * zoomLevel
    local viewW = viewport:GetWidth()
    local viewH = viewport:GetHeight()
    
    -- Allow panning up to the point where preview edge reaches viewport center
    local maxX = math.max(0, (scaledW / 2) - (viewW / 2) + C.PAN_CLAMP_PADDING)
    local maxY = math.max(0, (scaledH / 2) - (viewH / 2) + C.PAN_CLAMP_PADDING)
    
    return maxX, maxY
end

-- Apply pan with clamping
local function ApplyPanOffset(dialog, offsetX, offsetY)
    local maxX, maxY = GetPanBounds(dialog.TransformLayer, dialog.Viewport, dialog.zoomLevel)
    
    dialog.panOffsetX = math.max(-maxX, math.min(maxX, offsetX))
    dialog.panOffsetY = math.max(-maxY, math.min(maxY, offsetY))
    
    dialog.TransformLayer:ClearAllPoints()
    dialog.TransformLayer:SetPoint("CENTER", dialog.Viewport, "CENTER", dialog.panOffsetX, dialog.panOffsetY)
end

-- Apply zoom level
local function ApplyZoom(dialog, newZoom)
    newZoom = math.max(C.MIN_ZOOM, math.min(C.MAX_ZOOM, newZoom))
    -- Round to 2 decimal places
    newZoom = math.floor(newZoom * 100 + 0.5) / 100
    
    dialog.zoomLevel = newZoom
    dialog.TransformLayer:SetScale(newZoom)
    
    -- Re-clamp pan after zoom change (visible area may have changed)
    ApplyPanOffset(dialog, dialog.panOffsetX, dialog.panOffsetY)
    
    -- Update zoom indicator if present
    if dialog.ZoomIndicator then
        dialog.ZoomIndicator:SetText(string.format("%.0f%%", newZoom * 100))
    end
end

-- Export helpers for use by other modules
CanvasMode.ApplyZoom = ApplyZoom
CanvasMode.ApplyPanOffset = ApplyPanOffset

-- [ ZOOM HANDLER ]--------------------------------------------------------------------------

Dialog.Viewport:SetScript("OnMouseWheel", function(self, delta)
    local newZoom = Dialog.zoomLevel + (delta * C.ZOOM_STEP)
    ApplyZoom(Dialog, newZoom)
end)

-- [ PAN HANDLERS ]--------------------------------------------------------------------------

Dialog.Viewport:SetScript("OnDragStart", function(self)
    self.isPanning = true
    local mx, my = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.panStartMouseX = mx / scale
    self.panStartMouseY = my / scale
    self.panStartOffsetX = Dialog.panOffsetX
    self.panStartOffsetY = Dialog.panOffsetY
end)

Dialog.Viewport:SetScript("OnDragStop", function(self)
    self.isPanning = false
    ResetCursor()
end)

Dialog.Viewport:SetScript("OnUpdate", function(self)
    if self.isPanning then
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mx = mx / scale
        my = my / scale
        
        local deltaX = mx - self.panStartMouseX
        local deltaY = my - self.panStartMouseY
        
        ApplyPanOffset(Dialog, self.panStartOffsetX + deltaX, self.panStartOffsetY + deltaY)
    end
end)

-- [ ZOOM INDICATOR ]------------------------------------------------------------------------

Dialog.ZoomIndicator = Dialog.PreviewContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.ZoomIndicator:SetPoint("BOTTOMRIGHT", Dialog.PreviewContainer, "BOTTOMRIGHT", -5, 5)
Dialog.ZoomIndicator:SetText(string.format("%.0f%%", C.DEFAULT_ZOOM * 100))
Dialog.ZoomIndicator:SetTextColor(0.7, 0.7, 0.7, 0.8)
