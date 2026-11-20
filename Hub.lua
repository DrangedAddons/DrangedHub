---------------------------------------------------------
--  DrangedAddons - Hub window
--  Author: Dranged
---------------------------------------------------------
-- One window: the addon list down the left, the picked addon on the right
-- (its icon, name, version and minimap switch, its settings, and buttons for
-- its other windows along the bottom).

local ADDON, NS = ...
local UI = NS.UI
local Host = NS.Host

local W, H = 990, 760
local SIDE_W = 214
local HEAD_H, FOOT_H = 66, 46
local ROW_H = 28

local frame, inner
local parts = {}
local current      -- the entry on show
local pending      -- the entry to open on next show
local listRows, listLabels = {}, {}
local actionButtons = {}
local Select, RefreshList

---------------------------------------------------------
--  SECTION: Look
---------------------------------------------------------
-- Runs after the kit themes the window: the layout sits inside whatever
-- border that look draws, and the accent-coloured pieces follow it.
local function PostTheme()
    if not frame or not inner then return end
    local theme = NS.ActiveTheme()
    local flat = theme == "eui"
    local art = (theme == "forever" or theme == "blizzard") and frame.nsNineSlice and true or false
    local l, r, t, b = 11, 12, 12, 11
    if flat then
        l, r, t, b = 1, 1, 1, 1
    elseif art then
        l, r, t, b = 6, 4, 22, 4
    end
    inner:ClearAllPoints()
    inner:SetPoint("TOPLEFT", l, -t)
    inner:SetPoint("BOTTOMRIGHT", -r, b)

    if frame.nsTopBar then frame.nsTopBar:Hide() end
    frame.nsTitle:SetShown(art)

    local useFlat = flat and parts.flatClose ~= nil
    if parts.flatClose then parts.flatClose:SetShown(useFlat) end
    parts.stockClose:SetShown(not useFlat)
    parts.stockClose:ClearAllPoints()
    if art then
        parts.stockClose:SetPoint("TOPRIGHT", 1, 0)
    else
        parts.stockClose:SetPoint("TOPRIGHT", -4, -4)
    end

    local ar, ag, ab = NS.AccentColor()
    parts.headLine:SetColorTexture(ar, ag, ab, 0.9)
    if flat then
        parts.title:SetTextColor(1, 1, 1)
        parts.brand:SetTextColor(1, 1, 1)
    else
        parts.title:SetTextColor(1, 0.82, 0)
        parts.brand:SetTextColor(1, 0.82, 0)
    end
    if RefreshList then RefreshList() end
end

local baseApplyTheme = NS.ApplyTheme
function NS.ApplyTheme(f)
    baseApplyTheme(f)
    if f == frame then pcall(PostTheme) end
end

---------------------------------------------------------
--  SECTION: Addon list (left)
---------------------------------------------------------
local function ListRow(i)
    local r = listRows[i]
    if r then return r end
    r = CreateFrame("Button", nil, parts.list)
    r:SetSize(SIDE_W - 16, ROW_H)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.bar = r:CreateTexture(nil, "BORDER")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(3)
    r:SetHighlightTexture(UI.WHITE)
    local hl = r:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.06)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 14, 0)
    r.text = UI.Text(r, "")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 9, 0)
    r.text:SetPoint("RIGHT", -6, 0)
    r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.entry then Select(self.entry) end
    end)
    listRows[i] = r
    return r
end

local function ListLabel(i)
    local fs = listLabels[i]
    if fs then return fs end
    fs = UI.Text(parts.list, "", "GameFontNormalSmall")
    listLabels[i] = fs
    return fs
end

function RefreshList()
    if not parts.list then return end
    local ar, ag, ab = NS.AccentColor()
    local y, nRow, nLabel = -4, 0, 0

    local function Label(text)
        nLabel = nLabel + 1
        local fs = ListLabel(nLabel)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 14, y - 10)
        fs:SetText(text)
        fs:SetTextColor(ar, ag, ab)
        fs:Show()
        y = y - 28
    end
    local function Row(entry)
        nRow = nRow + 1
        local r = ListRow(nRow)
        r.entry = entry
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r.icon:SetTexture(entry.icon)
        r.icon:SetDesaturated(not entry.loaded)
        r.icon:SetAlpha(entry.loaded and 1 or 0.6)
        r.text:SetText(entry.rowTitle or entry.title)
        local selected = entry == current
        r.sel:SetColorTexture(ar, ag, ab, selected and 0.16 or 0)
        r.bar:SetColorTexture(ar, ag, ab, selected and 1 or 0)
        if selected then
            r.text:SetTextColor(1, 1, 1)
        elseif entry.loaded then
            r.text:SetTextColor(0.82, 0.82, 0.82)
        else
            r.text:SetTextColor(0.5, 0.5, 0.5)
        end
        r:Show()
        y = y - ROW_H
    end

    Row(NS.self)
    local groups = {
        { "ADDONS", function(e) return e.loaded and not e.tool end },
        { "TOOLS", function(e) return e.loaded and e.tool end },
        { "NOT LOADED", function(e) return not e.loaded end },
    }
    for _, group in ipairs(groups) do
        local any = false
        for _, entry in ipairs(NS.addons or {}) do
            if group[2](entry) then
                if not any then
                    Label(group[1])
                    any = true
                end
                Row(entry)
            end
        end
    end
    for i = nRow + 1, #listRows do listRows[i]:Hide() end
    for i = nLabel + 1, #listLabels do listLabels[i]:Hide() end
    parts.listScroll:SetContentHeight(-y + 6)
end

---------------------------------------------------------
--  SECTION: Overview page (the hub's own settings)
---------------------------------------------------------
local homeBuilt

local function BuildHome()
    if homeBuilt then return end
    homeBuilt = true
    local c = parts.homeContent
    local y = 0
    local function Row(label, icon)
        local row = UI.Row(c, label, y, icon)
        y = y - ROW_H
        return row
    end
    local function Section(text)
        UI.Section(c, text, y)
        y = y - 32
    end

    -- Minimap
    Section("Minimap buttons")
    local own = Row("DrangedAddons", NS.LOGO)
    local ownMM = NS.Minimap(NS.self)
    UI.Toggle(own, ownMM.get, ownMM.set):SetPoint("RIGHT", -6, 0)

    local all = Row("Every other addon")
    local hideAll = UI.Button(all, "Hide all", 84, 22, function()
        NS.SetAllMinimap(false)
        UI.RefreshAll()
    end)
    hideAll:SetPoint("RIGHT", -6, 0)
    local showAll = UI.Button(all, "Show all", 84, 22, function()
        NS.SetAllMinimap(true)
        UI.RefreshAll()
    end)
    showAll:SetPoint("RIGHT", hideAll, "LEFT", -6, 0)

    for _, entry in ipairs(NS.addons or {}) do
        local mm = NS.Minimap(entry)
        if mm then
            local row = Row(entry.title, entry.icon)
            UI.Toggle(row, mm.get, mm.set):SetPoint("RIGHT", -6, 0)
        end
    end

    -- Window
    y = y - 8
    Section("Window")
    local look = Row("Look")
    local dd = UI.Dropdown(look, 260, function()
        local items = {}
        for _, o in ipairs(NS.LookOptions()) do items[#items + 1] = { value = o.value, label = o.text } end
        return items
    end, function() return NS.db.theme end, function(v) NS.SetLook(v) end)
    dd:SetPoint("RIGHT", -6, 0)

    local host = Row("Show addon settings inside this window")
    UI.Toggle(host, function() return NS.db.host end, function(on)
        NS.db.host = on
        if not on then NS.Print("reload the UI to give the addons their own settings windows back.") end
    end):SetPoint("RIGHT", -6, 0)

    -- Installed
    y = y - 8
    Section("Installed addons")
    for _, entry in ipairs(NS.addons or {}) do
        local row = Row(entry.title .. (entry.version and ("  |cff808080v" .. entry.version .. "|r") or ""), entry.icon)
        local toggle = UI.Toggle(row, function() return NS.IsEnabled(entry.name) end, function(on)
            NS.SetEnabled(entry.name, on)
        end)
        toggle:SetPoint("RIGHT", -6, 0)
        local state = UI.Text(row, "", "GameFontHighlightSmall")
        state:SetPoint("RIGHT", toggle, "LEFT", -10, 0)
        UI.Track({ Refresh = function()
            local on = NS.IsEnabled(entry.name)
            if on ~= entry.loaded then
                state:SetText("reload to apply")
                state:SetTextColor(NS.AccentColor())
            else
                state:SetText(on and "loaded" or "off")
                state:SetTextColor(0.5, 0.5, 0.5)
            end
        end })
    end

    parts.homeScroll:SetContentHeight(-y + 12)
end

---------------------------------------------------------
--  SECTION: Addon page (right)
---------------------------------------------------------
-- Widens the window when what it hosts is wider than the pane, as far as the
-- screen allows. Past that the pane scrolls sideways.
local function FitWidth(want)
    local vw = parts.hostScroll:GetWidth() or 0
    if vw <= 0 then return end
    local cur = frame:GetWidth() or W
    local base = vw - (cur - W)   -- the pane's width at the normal window width
    local target = W + math.max(0, math.ceil((want or 0) - base))
    local screen = (UIParent:GetWidth() or 0) / (frame:GetScale() or 1) - 40
    if screen > W then target = math.min(target, screen) end
    if math.abs(target - cur) > 0.5 then frame:SetWidth(target) end
end

-- Sizes the pane to what the hosted window or page needs. Runs from the
-- window's own OnUpdate (and right after a page is picked), never from inside
-- a size or show handler: those only set `dirty`.
local dirty       -- lay out again on the next update
local sinceLook   -- seconds since the last look at the hosted contents
local checks      -- { entry, t1, t2 ... }: times left at which to check the page drew

local function LayoutHosted()
    local rec = current and Host.Record(current)
    if not rec or not rec.holder then return end
    Host.Replace(rec)   -- only if the addon moved it
    local w, h, want = Host.Need(rec)
    FitWidth(want)
    w, h = Host.Need(rec)   -- the pane may be wider now
    parts.hostScroll:SetContentSize(w, h)
end

NS.OnHostedResize = function(rec)
    if current == rec.entry then dirty = true end
end

-- The room a hosted page has: the pane's width and height.
NS.HostViewport = function()
    if parts.hostScroll then return parts.hostScroll:Viewport() end
end

-- Shows the hosted page again, the way clicking its row a second time does.
local function Reshow(rec)
    rec.reshown = (rec.reshown or 0) + 1
    parts.hostPage:Hide()
    parts.hostPage:Show()
    Host.Replace(rec, true)
    LayoutHosted()
end

-- The hub's heartbeat while it's open.
local function OnUpdate(_, elapsed)
    local rec = current and Host.Record(current)
    if not rec or not rec.holder or not parts.hostPage:IsShown() then
        dirty, checks = false, nil
        return
    end
    -- contents change without any size event (a section opens, a list fills)
    sinceLook = (sinceLook or 0) + (elapsed or 0)
    if sinceLook >= 0.4 then
        sinceLook = 0
        dirty = true
    end
    if dirty then
        dirty = false
        LayoutHosted()
    end
    -- A page shown here for the first time gets shown once more a frame
    -- later, and again if the game still hasn't placed everything in it.
    if checks and checks.entry == current then
        checks.t = checks.t + (elapsed or 0)
        local due = checks[1]
        if due and checks.t >= due then
            table.remove(checks, 1)
            local lost = Host.Lost(rec)
            -- once more regardless the first time; after that only while it helps
            if checks.always or (lost > 0 and lost ~= checks.lost) then
                checks.always, checks.lost = false, lost
                Reshow(rec)
            end
            if #checks == 0 then checks = nil end
        end
    else
        checks = nil
    end
end

-- /dranged debug: what the hub thinks is on show, for when a page looks wrong.
function NS.DebugDump()
    local out = {}
    out[#out + 1] = ("v%s, look %s, scale %s, open %s"):format(NS.VERSION, tostring(NS.ActiveTheme()),
        tostring(NS.db.scale), tostring(frame ~= nil and frame:IsShown()))
    if frame and current then
        local rec = Host.Record(current)
        out[#out + 1] = ("page %s, window %.0fx%.0f, pane %.0fx%.0f, scrolled %.0f / %.0f"):format(current.name,
            frame:GetWidth() or 0, frame:GetHeight() or 0, parts.hostScroll:GetWidth() or 0, parts.hostScroll:GetHeight() or 0,
            parts.hostScroll:GetVerticalScroll() or 0, parts.hostScroll:GetHorizontalScroll() or 0)
        if rec and rec.holder and parts.hostPage:IsShown() then
            local ok, lines = pcall(Host.Describe, rec)
            if ok then
                for _, line in ipairs(lines) do out[#out + 1] = line end
            else
                out[#out + 1] = "describe failed: " .. tostring(lines)
            end
        else
            out[#out + 1] = "no hosted window on show for this page"
        end
    end
    for _, line in ipairs(out) do NS.Print(line) end
end

local function InfoText(entry, hasSettings)
    local lines = {}
    if not entry.loaded then
        lines[#lines + 1] = entry.title .. " is installed but not loaded on this character."
        lines[#lines + 1] = "Turn it on under Overview > Installed addons, then reload the UI."
    elseif hasSettings then
        lines[#lines + 1] = entry.title .. "'s settings open in their own window. Use the button below."
    else
        lines[#lines + 1] = entry.title .. " has no settings window."
    end
    local cmds = entry.loaded and NS.Commands(entry) or {}
    if #cmds > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Commands:  |cffffd100" .. table.concat(cmds, "   ") .. "|r"
    end
    return table.concat(lines, "\n")
end

local function ShowActions(list)
    local x = 18
    for i, action in ipairs(list) do
        local b = actionButtons[i]
        if not b then
            b = UI.Button(parts.main, "", 100, 24, function(self)
                local a = self.action
                if not a then return end
                if not a.keep then frame:Hide() end
                local ok, err = pcall(a[2])
                if not ok then NS.Print("|cffff4040that button failed:|r " .. tostring(err)) end
            end)
            actionButtons[i] = b
        end
        b.action = action
        b:SetText(action[1])
        local fs = b:GetFontString()
        b:SetWidth(math.max(80, (fs and fs:GetStringWidth() or 60) + 28))
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", x, 11)
        b:Show()
        x = x + b:GetWidth() + 6
    end
    for i = #list + 1, #actionButtons do actionButtons[i]:Hide() end
end

function Select(entry)
    entry = entry or NS.self
    if current and current ~= entry then Host.Park(current) end
    current = entry
    NS.db.last = entry.name

    -- header
    parts.icon:SetTexture(entry.icon)
    parts.title:SetText(entry.title)
    parts.notes:SetText(entry.notes or "")
    parts.version:SetText(entry.version and ("v" .. entry.version) or "")
    local mm = NS.Minimap(entry)
    parts.mmToggle:SetShown(mm ~= nil)
    parts.mmLabel:SetShown(mm ~= nil)

    -- body
    parts.homePage:Hide()
    parts.infoPage:Hide()
    parts.hostPage:Hide()
    local actions = {}
    local spec = NS.Spec(entry)
    local rec, first
    if entry.isHub then
        BuildHome()
        parts.homePage:Show()
    else
        if entry.loaded and NS.db.host and Host.Has(entry) then
            parts.hostPage:Show()
            -- a page takes its size from the pane's holder: give it the pane's size to start with
            local vw, vh = parts.hostScroll:Viewport()
            if vw > 0 and vh > 0 then parts.hostScroll:SetContentSize(vw, vh) end
            rec, first = Host.Attach(entry, parts.hostContent)
        end
        if rec then
            LayoutHosted()
            parts.hostScroll:ScrollTo(0)
            parts.hostScroll:ScrollToX(0)
        else
            parts.hostPage:Hide()
            local opener = entry.loaded and spec and spec.settings and spec.settings.open
            parts.infoText:SetText(InfoText(entry, opener and true or false))
            parts.infoPage:Show()
            if opener then actions[#actions + 1] = { "Open settings", opener } end
        end
        if entry.loaded and spec and spec.actions then
            for _, a in ipairs(spec.actions) do actions[#actions + 1] = a end
        end
    end

    -- footer
    ShowActions(actions)
    local cmds = entry.loaded and NS.Commands(entry) or {}
    parts.cmds:SetText(table.concat(cmds, "   "))

    -- back to the normal width
    if not rec and math.abs((frame:GetWidth() or W) - W) > 0.5 then frame:SetWidth(W) end

    RefreshList()
    UI.RefreshAll()
    NS.NoteThemeFonts(frame)
    dirty, sinceLook = rec ~= nil, 0
    if first then
        -- next frame: show it once more whatever it looks like; then twice more only if needed
        checks = { entry = entry, t = 0, always = true, 0.05, 0.3, 1 }
    elseif rec then
        checks = { entry = entry, t = 0, always = false, 0.3, 1 }
    else
        checks = nil
    end
end

-- An addon loaded after login (load on demand): its row moves to Addons.
function NS.RefreshWindow()
    if frame and frame:IsShown() then RefreshList() end
end

---------------------------------------------------------
--  SECTION: Building the window
---------------------------------------------------------
-- A thin X for the flat look. Nil when this client can't draw lines.
local function FlatClose(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    local lines = {}
    local ok = pcall(function()
        for i, ends in ipairs({ { "TOPLEFT", "BOTTOMRIGHT" }, { "TOPRIGHT", "BOTTOMLEFT" } }) do
            local line = b:CreateLine(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, 1)
            line:SetThickness(1.5)
            local dx = (i == 1) and 5 or -5
            line:SetStartPoint(ends[1], b, dx, -5)
            line:SetEndPoint(ends[2], b, -dx, 5)
            lines[i] = line
        end
    end)
    if not ok then
        b:Hide()
        return nil
    end
    local function Tint(v)
        for _, line in ipairs(lines) do line:SetVertexColor(v, v, v) end
    end
    Tint(0.65)
    b:SetScript("OnEnter", function() Tint(1) end)
    b:SetScript("OnLeave", function() Tint(0.65) end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function Build()
    frame = CreateFrame("Frame", "DrangedAddonsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop(NS.DEFAULT_BACKDROP)
    frame:SetScale(NS.db.scale or 1)
    frame:Hide()
    tinsert(UISpecialFrames, "DrangedAddonsFrame")

    -- only shown in the Blizzard-art looks, in their title bar
    frame.nsTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.nsTitle:SetPoint("TOP", 0, -5)
    frame.nsTitle:SetText("DrangedAddons")

    parts.stockClose = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    parts.stockClose:SetPoint("TOPRIGHT", -4, -4)
    parts.stockClose:SetScript("OnClick", function() frame:Hide() end)

    inner = CreateFrame("Frame", nil, frame)
    inner:SetPoint("TOPLEFT", 11, -12)
    inner:SetPoint("BOTTOMRIGHT", -12, 11)

    -- Left: brand, addon list, window size, reload
    local side = CreateFrame("Frame", nil, inner)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDE_W)
    local sideBg = side:CreateTexture(nil, "BACKGROUND")
    sideBg:SetAllPoints()
    sideBg:SetColorTexture(0, 0, 0, 0.28)
    local sideLine = side:CreateTexture(nil, "BORDER")
    sideLine:SetWidth(1)
    sideLine:SetPoint("TOPRIGHT")
    sideLine:SetPoint("BOTTOMRIGHT")
    sideLine:SetColorTexture(1, 1, 1, 0.07)

    local logo = side:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 14, -14)
    logo:SetTexture(NS.LOGO)
    parts.brand = UI.Text(side, "DrangedAddons", "GameFontNormalLarge")
    parts.brand:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -2)
    local sub = UI.Text(side, "/dranged   v" .. NS.VERSION, "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", parts.brand, "BOTTOMLEFT", 0, -4)

    local listHolder = CreateFrame("Frame", nil, side)
    listHolder:SetPoint("TOPLEFT", 0, -64)
    listHolder:SetPoint("BOTTOMRIGHT", -3, 86)
    parts.listScroll, parts.list = UI.ScrollArea(listHolder, SIDE_W - 16)

    local reload = UI.Button(side, "Reload UI", SIDE_W - 28, 24, function() ReloadUI() end)
    reload:SetPoint("BOTTOMLEFT", 14, 14)
    local sizeLabel = UI.Text(side, "Window size", "GameFontHighlightSmall")
    sizeLabel:SetPoint("BOTTOMLEFT", 14, 53)
    sizeLabel:SetTextColor(0.7, 0.7, 0.7)
    local stepper = UI.Stepper(side, 98, function() return NS.db.scale or 1 end, function(v)
        NS.db.scale = v
        frame:SetScale(v)
        dirty = true
    end, 0.7, 1.8, 0.1, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
    stepper:SetPoint("BOTTOMRIGHT", -14, 48)

    -- Right: header, body, footer
    local main = CreateFrame("Frame", nil, inner)
    main:SetPoint("TOPLEFT", side, "TOPRIGHT")
    main:SetPoint("BOTTOMRIGHT")
    parts.main = main

    parts.icon = main:CreateTexture(nil, "ARTWORK")
    parts.icon:SetSize(40, 40)
    parts.icon:SetPoint("TOPLEFT", 18, -13)
    parts.title = UI.Text(main, "", "GameFontNormalLarge")
    parts.title:SetPoint("TOPLEFT", parts.icon, "TOPRIGHT", 12, -3)
    parts.notes = UI.Text(main, "", "GameFontHighlightSmall")
    parts.notes:SetPoint("TOPLEFT", parts.title, "BOTTOMLEFT", 0, -5)
    parts.notes:SetPoint("RIGHT", main, "RIGHT", -190, 0)
    parts.notes:SetWordWrap(false)
    parts.notes:SetTextColor(0.72, 0.72, 0.72)
    parts.version = UI.Text(main, "", "GameFontDisableSmall")
    parts.version:SetPoint("TOPRIGHT", -46, -17)
    parts.mmToggle = UI.Toggle(main, function()
        local mm = current and NS.Minimap(current)
        return mm and mm.get()
    end, function(on)
        local mm = current and NS.Minimap(current)
        if mm then mm.set(on) end
    end)
    parts.mmToggle:SetPoint("TOPRIGHT", -18, -39)
    parts.mmLabel = UI.Text(main, "Minimap button", "GameFontHighlightSmall")
    parts.mmLabel:SetPoint("RIGHT", parts.mmToggle, "LEFT", -8, 0)
    parts.mmLabel:SetTextColor(0.72, 0.72, 0.72)

    parts.headLine = main:CreateTexture(nil, "ARTWORK")
    parts.headLine:SetHeight(1)
    parts.headLine:SetPoint("TOPLEFT", 18, -HEAD_H)
    parts.headLine:SetPoint("TOPRIGHT", -18, -HEAD_H)

    local footLine = main:CreateTexture(nil, "ARTWORK")
    footLine:SetHeight(1)
    footLine:SetPoint("BOTTOMLEFT", 0, FOOT_H)
    footLine:SetPoint("BOTTOMRIGHT", 0, FOOT_H)
    footLine:SetColorTexture(1, 1, 1, 0.07)
    parts.cmds = UI.Text(main, "", "GameFontDisableSmall")
    parts.cmds:SetPoint("BOTTOMRIGHT", -18, 17)
    parts.cmds:SetJustifyH("RIGHT")

    local body = CreateFrame("Frame", nil, main)
    body:SetPoint("TOPLEFT", 18, -(HEAD_H + 10))
    body:SetPoint("BOTTOMRIGHT", -10, FOOT_H + 8)

    parts.homePage = CreateFrame("Frame", nil, body)
    parts.homePage:SetAllPoints()
    parts.homeScroll, parts.homeContent = UI.ScrollArea(parts.homePage, NS.HOST_W)

    parts.hostPage = CreateFrame("Frame", nil, body)
    parts.hostPage:SetAllPoints()
    -- Two plain frames between the page and its scroll box. The kit's font
    -- pass walks this window eight frames deep, and these put a hosted
    -- addon's window past that: its fonts are its own business, and changing
    -- them under a page that's already laid out left parts of it undrawn.
    local wrap = CreateFrame("Frame", nil, parts.hostPage)
    wrap:SetAllPoints()
    local wrap2 = CreateFrame("Frame", nil, wrap)
    wrap2:SetAllPoints()
    parts.hostScroll, parts.hostContent = UI.ScrollBox(wrap2)
    parts.hostScroll.onViewport = function() dirty = true end

    parts.infoPage = CreateFrame("Frame", nil, body)
    parts.infoPage:SetAllPoints()
    parts.infoText = UI.Text(parts.infoPage, "")
    parts.infoText:SetPoint("TOPLEFT", 4, -8)
    parts.infoText:SetWidth(640)
    parts.infoText:SetJustifyV("TOP")
    parts.infoText:SetSpacing(4)

    parts.flatClose = FlatClose(main)
    if parts.flatClose then
        parts.flatClose:SetPoint("TOPRIGHT", -12, -12)
        parts.flatClose:SetFrameLevel(main:GetFrameLevel() + 10)
    end

    frame:SetScript("OnShow", function(self)
        NS.ApplyTheme(self)
        local entry = pending or current or (NS.db.last and NS.byName[NS.db.last]) or NS.self
        pending = nil
        Select(entry)
    end)
    frame:SetScript("OnHide", function()
        if current then Host.Park(current) end
        UI.CloseMenu()
    end)
    frame:SetScript("OnUpdate", OnUpdate)
    NS.ThemeRegisterWindow(frame)
end

---------------------------------------------------------
--  SECTION: Opening and closing
---------------------------------------------------------
-- name: an addon's folder name, or nil for whatever was open last.
function NS.OpenTo(name)
    if not NS.db or not NS.addons then return end   -- before login
    if not frame then Build() end
    local entry
    if name == ADDON then
        entry = NS.self
    elseif name then
        entry = NS.byName[name]
    end
    if frame:IsShown() then
        if entry then Select(entry) end
    else
        pending = entry
        frame:Show()
    end
end

function NS.Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        NS.OpenTo()
    end
end

function NS.Close()
    if frame then frame:Hide() end
end

function NS.IsShowing(entry)
    return frame ~= nil and frame:IsShown() and current == entry
end
