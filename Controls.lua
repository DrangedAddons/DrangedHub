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
