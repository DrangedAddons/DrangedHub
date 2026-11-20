---------------------------------------------------------
--  DrangedAddons - Host
--  Author: Dranged
---------------------------------------------------------
-- Shows another addon's settings window inside the hub. The window is moved
-- into the hub's scroll area, loses its own border, title bar and close
-- button, and from then on lives there: when the addon shows it (its slash
-- command, its minimap button) the hub opens on that addon's page, and when
-- the addon hides it the hub closes.
--
-- Nothing in the other addon is changed on disk. A reload with "Show addon
-- settings inside this window" turned off puts every window back.

local ADDON, NS = ...

local Host = {}
NS.Host = Host

NS.HOST_W = 700   -- width given to a hosted Options page

local byFrame = {}   -- frame -> record
local byName = {}    -- addon name -> record

---------------------------------------------------------
--  SECTION: Finding the settings frame
---------------------------------------------------------
local function SpecSettings(entry)
    return entry.spec and entry.spec.settings
end

local function Lookup(s)
    local f
    if s.frame then
        if type(s.frame) == "function" then
            local ok, got = pcall(s.frame)
            f = ok and got or nil
        else
            f = _G[s.frame]
        end
    elseif s.canvas then
        f = NS.canvas[s.canvas]
    end
    if type(f) == "table" and f.SetParent and f.GetObjectType then return f end
end

-- The frame, built by the addon's own opener when it doesn't exist yet.
local function Resolve(entry)
    local s = SpecSettings(entry)
    if not s then return nil end
    local f = Lookup(s)
    if not f and s.frame and s.open then
        pcall(s.open)
        f = Lookup(s)
    end
    return f
end

function Host.Has(entry)
    return SpecSettings(entry) ~= nil
end

---------------------------------------------------------
--  SECTION: Taking the window's own chrome off
---------------------------------------------------------
local function HideChrome(rec)
    -- The kit's Blizzard-art shell, EllesmereUI-style title band and title text.
    -- Older copies of the kit name them with their own prefix (nsNineSlice,
    -- crNineSlice, erNineSlice ...), so match on the ending.
    for key, obj in pairs(rec.frame) do
        if type(key) == "string" and type(obj) == "table" and obj.Hide then
            if key:match("^%l%l?%l?NineSlice$") then
                obj:Hide()
                for k2, piece in pairs(obj) do
                    if type(k2) == "string" and type(piece) == "table" and piece.Hide
                        and (k2:match("Bg$") or k2:match("Shade$")) then
                        piece:Hide()
                    end
                end
            elseif key:match("^%l%l?%l?TopBar$") or key:match("^%l%l?%l?Title$") then
                obj:Hide()
            end
        end
    end
end

local function Strip(rec)
    local f = rec.frame
    if f.SetBackdrop then
        rec.stripping = true
        pcall(f.SetBackdrop, f, nil)
        rec.stripping = false
    end
    HideChrome(rec)
    if rec.once then return end
    rec.once = true
    -- the close X (a small textless button in the top right corner) and any "Close" button
    if f.close and f.close.Hide then f.close:Hide() end
    for _, child in ipairs({ f:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" then
            local text = child.GetText and child:GetText() or nil
            local point, rel = child:GetPoint(1)
            if text == "Close" or (CLOSE and text == CLOSE) then
                child:Hide()
            elseif (not text or text == "") and point == "TOPRIGHT" and (rel == f or rel == nil)
                and (child:GetWidth() or 99) <= 36 then
                child:Hide()
            end
        end
    end
    -- it no longer drags or clamps on its own
    pcall(f.RegisterForDrag, f)
    pcall(f.SetScript, f, "OnDragStart", nil)
    pcall(f.SetClampedToScreen, f, false)
    pcall(f.SetToplevel, f, false)
end

-- How tall an Options page's contents are (it has no size of its own).
local function Measure(f)
    local top = f:GetTop()
    if not top then return nil end
    local low = top
    for _, child in ipairs({ f:GetChildren() }) do
        if child:IsShown() then
            local b = child:GetBottom()
            if b and b < low then low = b end
        end
    end
    for _, region in ipairs({ f:GetRegions() }) do
        if region:IsShown() then
            local b = region:GetBottom()
            if b and b < low then low = b end
        end
    end
    return math.max(200, top - low + 24)
end

local function Place(rec)
    local f, holder = rec.frame, rec.holder
    if f:GetParent() ~= holder then f:SetParent(holder) end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, rec.crop)
    if rec.canvas then f:SetSize(NS.HOST_W, rec.height or 600) end
    f:SetFrameStrata(holder:GetFrameStrata())
    f:SetFrameLevel(holder:GetFrameLevel() + 1)
    Strip(rec)
end

---------------------------------------------------------
--  SECTION: When the addon shows or hides its window itself
---------------------------------------------------------
local function OnShown(rec)
    if rec.internal or not rec.holder then return end
    if NS.OpenTo then NS.OpenTo(rec.entry.name) end
    if rec.canvas then
        -- the game's Options window just took the page back: put it here again
        C_Timer.After(0, function()
            if not rec.holder then return end
            pcall(Place, rec)
            -- closing the Options window may hide the page: that isn't the addon closing it
            rec.internal = true
            if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then
                pcall(HideUIPanel, SettingsPanel)
            end
            if not rec.frame:IsShown() then pcall(rec.frame.Show, rec.frame) end
            rec.internal = false
        end)
    end
end

local function OnHidden(rec)
    if rec.internal or not rec.holder then return end
    if NS.IsShowing and NS.IsShowing(rec.entry) then NS.Close() end
end

local function Adopt(entry, f)
    local s = SpecSettings(entry)
    local rec = {
        entry = entry,
        frame = f,
        crop = s.crop or 0,
        canvas = s.canvas and not s.frame and true or false,
    }
    byFrame[f] = rec
    byName[entry.name] = rec

    hooksecurefunc(f, "Show", function() OnShown(rec) end)
    hooksecurefunc(f, "Hide", function() OnHidden(rec) end)
    hooksecurefunc(f, "SetShown", function(_, on)
        if on then OnShown(rec) else OnHidden(rec) end
    end)
    -- the addon re-themes or re-places its window when it shows
    f:HookScript("OnShow", function()
        if rec.holder then pcall(Place, rec) end
    end)
    f:HookScript("OnSizeChanged", function()
        if rec.holder and NS.OnHostedResize then NS.OnHostedResize(rec) end
    end)
    if f.SetBackdrop then
        hooksecurefunc(f, "SetBackdrop", function(self, backdrop)
            if rec.stripping or not rec.holder then return end
            if backdrop then
                rec.stripping = true
                pcall(self.SetBackdrop, self, nil)
                rec.stripping = false
            end
            -- a look change redraws the rest of the shell after this call
            if not rec.pending then
                rec.pending = true
                C_Timer.After(0, function()
                    rec.pending = false
                    pcall(HideChrome, rec)
                end)
            end
        end)
    end
    if rec.canvas then
        local wait = 0
        f:HookScript("OnUpdate", function(self, elapsed)
            wait = wait + elapsed
            if wait < 0.4 then return end
            wait = 0
            local h = Measure(self)
            if h and math.abs(h - (rec.height or 0)) > 2 then
                rec.height = h
                self:SetHeight(h)
            end
        end)
    end
    return rec
end

---------------------------------------------------------
--  SECTION: Showing and parking
---------------------------------------------------------
-- Puts the addon's settings into holder and shows them. Returns the record,
-- or nil when the addon has no window the hub can host.
function Host.Attach(entry, holder)
    local f = Resolve(entry)
    if not f then return nil end
    local rec = byFrame[f] or Adopt(entry, f)
    rec.holder = holder
    rec.internal = true
    local ok, err = pcall(function()
        Place(rec)
        if rec.canvas and f:IsShown() then f:Hide() end   -- so its OnShow builds the page
        f:Show()
    end)
    rec.internal = false
    if not ok then
        if not rec.warned then
            rec.warned = true
            NS.Print("|cffff4040couldn't show " .. entry.title .. "'s settings here:|r " .. tostring(err))
        end
        return nil
    end
    return rec
end

function Host.Record(entry)
    return byName[entry.name]
end

-- Hides the hosted window without that counting as "the addon closed it".
function Host.Park(entry)
    local rec = byName[entry.name]
    if not rec or not rec.holder then return end
    rec.internal = true
    pcall(rec.frame.Hide, rec.frame)
    rec.internal = false
end
