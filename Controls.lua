---------------------------------------------------------
--  DrangedAddons - Controls
--  Author: Dranged
---------------------------------------------------------
-- The hub's own row widgets, on top of the house kit (same NS.UI): a flat
-- on/off switch, a -/+ stepper, section headings and setting rows.

local ADDON, NS = ...
local UI = NS.UI

---------------------------------------------------------
--  SECTION: Switch
---------------------------------------------------------
-- A flat on/off switch: accent track with the knob on the right when on.
function UI.Toggle(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 18)
    b.track = b:CreateTexture(nil, "BACKGROUND")
    b.track:SetAllPoints()
    b.knob = b:CreateTexture(nil, "ARTWORK")
    b.knob:SetSize(12, 12)

    function b:Refresh()
        local ok, on = pcall(get)
        on = ok and on and true or false
        self.on = on
        self.knob:ClearAllPoints()
        if on then
            local r, g, bl = NS.AccentColor()
            self.track:SetColorTexture(r, g, bl, 0.9)
            self.knob:SetColorTexture(1, 1, 1, 1)
            self.knob:SetPoint("RIGHT", -3, 0)
        else
            self.track:SetColorTexture(0.16, 0.16, 0.18, 1)
            self.knob:SetColorTexture(0.5, 0.5, 0.52, 1)
            self.knob:SetPoint("LEFT", 3, 0)
        end
    end
    b:SetScript("OnClick", function(self)
        local ok, err = pcall(set, not self.on)
        if not ok then NS.Print("|cffff4040couldn't change that:|r " .. tostring(err)) end
        UI.RefreshAll()
    end)
    function b:SetActive(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.5)
    end
    return UI.Track(b)
end

---------------------------------------------------------
--  SECTION: Stepper
---------------------------------------------------------
-- [-] value [+]. fmt(v) turns the value into the text shown.
function UI.Stepper(parent, width, get, set, minV, maxV, step, fmt)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(width, 22)
    local function Nudge(dir)
        local v = math.floor((get() + dir * step) / step + 0.5) * step
        set(math.max(minV, math.min(maxV, v)))
        UI.RefreshAll()
    end
    local minus = UI.Button(h, "-", 22, 22, function() Nudge(-1) end)
    minus:SetPoint("LEFT")
    local plus = UI.Button(h, "+", 22, 22, function() Nudge(1) end)
    plus:SetPoint("RIGHT")
    local value = UI.Text(h, "", "GameFontHighlight")
    value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    value:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    value:SetJustifyH("CENTER")
    function h:Refresh() value:SetText(fmt and fmt(get()) or get()) end
    return UI.Track(h)
end

---------------------------------------------------------
--  SECTION: Sections and rows
---------------------------------------------------------
-- A heading in the accent colour with a hairline under it. Takes 30 px.
function UI.Section(parent, text, y)
    local fs = UI.Text(parent, text, "GameFontNormal")
    fs:SetPoint("TOPLEFT", 0, y - 6)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, y - 24)
    line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    UI.Track({ Refresh = function() fs:SetTextColor(NS.AccentColor()) end })
    return fs
end

-- A 28 px setting row: optional icon, a label on the left, the control goes on
-- the right (anchor it to row's RIGHT).
function UI.Row(parent, label, y, icon)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(28)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    if icon then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexture(icon)
    end
    row.label = UI.Text(row, label)
    row.label:SetPoint("LEFT", icon and 30 or 4, 0)
    return row
end

---------------------------------------------------------
--  SECTION: Scroll box (both ways)
---------------------------------------------------------
-- For content the hub doesn't control: another addon's window, any size.
-- The wheel scrolls down. Shift+wheel scrolls sideways, and so does the
-- wheel when there's nothing to scroll down. Both bars drag.
-- Returns the scroll frame and its content frame.
function UI.ScrollBox(parent)
    local BAR, GAP = 6, 6
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT")
    sf:SetPoint("BOTTOMRIGHT", -(BAR + GAP), 0)
    if sf.SetClipsChildren then sf:SetClipsChildren(true) end
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(10, 10)
    sf:SetScrollChild(content)
    sf.contentW, sf.contentH = 10, 10

    local function Bar()
        local track = CreateFrame("Frame", nil, parent)
        track:EnableMouse(true)
        local bg = track:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.12, 0.12, 1)
        track.thumb = track:CreateTexture(nil, "OVERLAY")
        track.thumb:SetColorTexture(0.55, 0.55, 0.55, 1)
        track:Hide()
        return track
    end
    local vbar, hbar = Bar(), Bar()
    vbar:SetWidth(BAR)
    vbar:SetPoint("TOPRIGHT")
    vbar:SetPoint("BOTTOMRIGHT")
    vbar.thumb:SetWidth(BAR)
    hbar:SetHeight(BAR)
    hbar:SetPoint("BOTTOMLEFT")
    hbar:SetPoint("BOTTOMRIGHT", -(BAR + GAP), 0)
    hbar.thumb:SetHeight(BAR)

    local function MaxY() return math.max(0, sf.contentH - (sf:GetHeight() or 0)) end
    local function MaxX() return math.max(0, sf.contentW - (sf:GetWidth() or 0)) end
    local function Clamp(v, max) return math.max(0, math.min(max, v or 0)) end

    local busy
    function sf:UpdateBars()
        if busy then return end
        busy = true
        -- the sideways bar only takes room when there's something to scroll
        local needX = MaxX() > 0.5
        if needX ~= self.hasX then
            self.hasX = needX
            self:SetPoint("BOTTOMRIGHT", -(BAR + GAP), needX and (BAR + GAP) or 0)
        end
        local maxY, maxX = MaxY(), MaxX()
        if (self:GetVerticalScroll() or 0) > maxY then self:SetVerticalScroll(maxY) end
        if (self:GetHorizontalScroll() or 0) > maxX then self:SetHorizontalScroll(maxX) end

        vbar:SetShown(maxY > 0.5)
        if maxY > 0.5 then
            local th, vh = vbar:GetHeight() or 0, self:GetHeight() or 0
            local h = math.max(16, th * vh / self.contentH)
            vbar.thumb:SetHeight(h)
            vbar.thumb:ClearAllPoints()
            vbar.thumb:SetPoint("TOP", vbar, "TOP", 0, -(th - h) * ((self:GetVerticalScroll() or 0) / maxY))
        end
        hbar:SetShown(needX)
        if needX then
            local tw, vw = hbar:GetWidth() or 0, self:GetWidth() or 0
            local w = math.max(16, tw * vw / self.contentW)
            hbar.thumb:SetWidth(w)
            hbar.thumb:ClearAllPoints()
            hbar.thumb:SetPoint("LEFT", hbar, "LEFT", (tw - w) * ((self:GetHorizontalScroll() or 0) / maxX), 0)
        end
        busy = false
    end
    function sf:ScrollTo(y)
        self:SetVerticalScroll(Clamp(y, MaxY()))
        self:UpdateBars()
    end
    function sf:ScrollToX(x)
        self:SetHorizontalScroll(Clamp(x, MaxX()))
        self:UpdateBars()
    end
    function sf:SetContentSize(w, h)
        self.contentW, self.contentH = w, h
        content:SetSize(w, h)
        self:UpdateBars()
    end
    function sf:Viewport()
        return self:GetWidth() or 0, (self:GetHeight() or 0) + (self.hasX and (BAR + GAP) or 0)
    end

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() or MaxY() <= 0.5 then
            self:ScrollToX((self:GetHorizontalScroll() or 0) - delta * 40)
        else
            self:ScrollTo((self:GetVerticalScroll() or 0) - delta * 40)
        end
    end)
    sf:SetScript("OnSizeChanged", function(self)
        self:UpdateBars()
        if self.onViewport then self.onViewport() end
    end)

    local function DragY()
        local _, y = GetCursorPosition()
        y = y / vbar:GetEffectiveScale()
        local top, h = vbar:GetTop(), vbar:GetHeight()
        if top and h and h > 0 then sf:ScrollTo((top - y) / h * MaxY()) end
    end
    local function DragX()
        local x = GetCursorPosition()
        x = x / hbar:GetEffectiveScale()
        local left, w = hbar:GetLeft(), hbar:GetWidth()
        if left and w and w > 0 then sf:ScrollToX((x - left) / w * MaxX()) end
    end
    vbar:SetScript("OnMouseDown", function(self) DragY(); self:SetScript("OnUpdate", DragY) end)
    vbar:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    hbar:SetScript("OnMouseDown", function(self) DragX(); self:SetScript("OnUpdate", DragX) end)
    hbar:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    return sf, content
end
