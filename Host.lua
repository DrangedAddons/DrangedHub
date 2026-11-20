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
-- The hub never looks inside the window. Whatever the addon puts in it, in
-- any version, is what shows: the hub only measures it and scrolls it.
--
-- Nothing in the other addon is changed on disk. A reload with "Show addon
-- settings inside this window" turned off puts every window back.

local ADDON, NS = ...

local Host = {}
NS.Host = Host

NS.HOST_W = 700   -- width of the hub's own pages

local byFrame = {}   -- frame -> record
local byName = {}    -- addon name -> record

---------------------------------------------------------
--  SECTION: Finding the settings frame
---------------------------------------------------------
local function SpecSettings(entry)
    local spec = NS.Spec(entry)
    return spec and spec.settings
end

local function IsFrame(f)
    return type(f) == "table" and f.SetParent and f.GetObjectType and true or false
end

local function Lookup(s)
    local f
    if s.frame then
        if type(s.frame) == "function" then
            local ok, got = pcall(s.frame)
            f = ok and got or nil
        elseif type(s.frame) == "string" then
            f = _G[s.frame]
        else
            f = s.frame
        end
    elseif s.canvas then
        f = NS.canvas[s.canvas]
    end
    if IsFrame(f) then return f end
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
                rec.hadTitle = true
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
    if f.close and f.close.Hide then
        f.close:Hide()
        rec.hadTitle = true
    end
    for _, child in ipairs({ f:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" then
            local text = child.GetText and child:GetText() or nil
            local point, rel = child:GetPoint(1)
            if text == "Close" or (CLOSE and text == CLOSE) then
                child:Hide()
            elseif (not text or text == "") and point == "TOPRIGHT" and (rel == f or rel == nil)
                and (child:GetWidth() or 99) <= 36 then
                child:Hide()
                rec.hadTitle = true
            end
        end
    end
    -- it no longer drags or clamps on its own
    pcall(f.RegisterForDrag, f)
    pcall(f.SetScript, f, "OnDragStart", nil)
    pcall(f.SetClampedToScreen, f, false)
    pcall(f.SetToplevel, f, false)
end

---------------------------------------------------------
--  SECTION: Measuring what's inside
---------------------------------------------------------
-- An Options page has no size of its own, and a window can lose its title
-- bar: both are measured from what's in them, so they follow whatever the
-- addon's current version draws.

local DOWN = { far = "BOTTOM", near = "TOP" }
local ACROSS = { far = "RIGHT", near = "LEFT" }

-- Which side of an axis an anchor point is on.
local function Side(point, axis)
    if type(point) ~= "string" then return "mid" end
    if point:find(axis.far, 1, true) then return "far" end
    if point:find(axis.near, 1, true) then return "near" end
    return "mid"
end

-- Does that side of obj move when f's bottom (or right) edge moves? Something
-- pinned to the page's bottom follows the page's size, so it says nothing
-- about how tall the contents are. Follows the anchors back to f.
local function Moves(obj, side, f, axis, depth)
    if obj == f then return side ~= "near" end
    if depth > 6 or not obj.GetNumPoints then return false end
    local hasNear, hasFar, nearMoves, farMoves, midMoves
    for i = 1, obj:GetNumPoints() or 0 do
        local point, rel, relPoint = obj:GetPoint(i)
        local moves = false
        if type(rel) == "table" and rel ~= obj then
            moves = Moves(rel, Side(relPoint or point, axis), f, axis, depth + 1)
        end
        local s = Side(point, axis)
        if s == "near" then
            hasNear, nearMoves = true, moves
        elseif s == "far" then
            hasFar, farMoves = true, moves
        else
            midMoves = midMoves or moves
        end
    end
    if hasNear and hasFar then   -- stretched between two anchors
        if side == "near" then return nearMoves end
        if side == "far" then return farMoves end
        return nearMoves or farMoves
    end
    if hasNear then return nearMoves end
    if hasFar then return farMoves end
    return midMoves or false
end

-- Width and height the contents of f need, from f's top left corner.
local function Extent(f)
    local top, left = f:GetTop(), f:GetLeft()
    if not top or not left then return nil end
    local low, far = top, left
    local function Walk(obj, depth)
        if obj.IsShown and not obj:IsShown() then return end
        if not Moves(obj, "far", f, DOWN, 0) then
            local b = obj.GetBottom and obj:GetBottom()
            if b and b < low then low = b end
        end
        if not Moves(obj, "far", f, ACROSS, 0) then
            local r = obj.GetRight and obj:GetRight()
            if r and r > far then far = r end
        end
        -- a scroll frame's contents are clipped to it: its own edges are what count
        if depth < 4 and obj.GetChildren and obj:GetObjectType() ~= "ScrollFrame"
            and not (obj.DoesClipChildren and obj:DoesClipChildren()) then
            for _, child in ipairs({ obj:GetChildren() }) do Walk(child, depth + 1) end
            for _, region in ipairs({ obj:GetRegions() }) do Walk(region, depth + 1) end
        end
    end
    for _, child in ipairs({ f:GetChildren() }) do Walk(child, 1) end
    for _, region in ipairs({ f:GetRegions() }) do Walk(region, 1) end
    return far - left + 16, top - low + 24
end

-- How much of a window's top was its title bar: the gap above the first
-- thing still showing once the title and close button are gone.
local function TitleGap(rec)
    local f = rec.frame
    local top = f:GetTop()
    if not top then return nil end
    local high
    local function See(obj)
        if obj:IsShown() then
            local t = obj:GetTop()
            if t and (not high or t > high) then high = t end
        end
    end
    for _, child in ipairs({ f:GetChildren() }) do See(child) end
    for _, region in ipairs({ f:GetRegions() }) do
        if region:GetObjectType() == "FontString" then See(region) end
    end
    if not high then return 0 end
    return math.max(0, math.min(90, math.floor(top - high - 6 + 0.5)))
end

local function Viewport()
    local w, h
    if NS.HostViewport then w, h = NS.HostViewport() end
    if not w or w <= 0 then w = NS.HOST_W end
    if not h or h <= 0 then h = 600 end
    return w, h
end

-- An Options page fills the pane, and is bigger when its contents need it.
local function SizePage(rec)
    local vw, vh = Viewport()
    rec.frame:SetSize(math.max(vw, rec.needW or 0), math.max(vh, rec.needH or 0))
end

local function Place(rec)
    local f, holder = rec.frame, rec.holder
    if f:GetParent() ~= holder then f:SetParent(holder) end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, rec.crop)
    if rec.page then SizePage(rec) end
    f:SetFrameStrata(holder:GetFrameStrata())
    f:SetFrameLevel(holder:GetFrameLevel() + 1)
    Strip(rec)
end

-- Re-reads what the contents need. Returns true when something changed.
local function Measure(rec)
    if rec.frozen then return false end
    local changed = false
    if rec.page then
        local ok, w, h = pcall(Extent, rec.frame)
        if ok and w and h then
            if math.abs(w - (rec.needW or 0)) > 2 or math.abs(h - (rec.needH or 0)) > 2 then
                -- contents that keep growing with the page would never settle: stop following them
                if rec.needH and h > rec.needH + 2 then rec.grew = (rec.grew or 0) + 1 else rec.grew = 0 end
                if rec.grew > 8 then
                    rec.frozen = true
                    return false
                end
                rec.needW, rec.needH = w, h
                SizePage(rec)
                changed = true
            end
        end
    elseif rec.autoCrop and rec.hadTitle and (rec.cropLooks or 0) < 4 then
        -- only while the window settles after being shown: contents that move
        -- later (a list scrolling under the title) mustn't shift the crop
        rec.cropLooks = (rec.cropLooks or 0) + 1
        local ok, gap = pcall(TitleGap, rec)
        if ok and gap and gap ~= rec.crop then
            rec.crop = gap
            rec.frame:ClearAllPoints()
            rec.frame:SetPoint("TOPLEFT", rec.holder, "TOPLEFT", 0, gap)
            changed = true
        end
    end
    return changed
end

---------------------------------------------------------
--  SECTION: When the addon shows or hides its window itself
---------------------------------------------------------
local function OnShown(rec)
    if rec.internal or not rec.holder then return end
    if NS.OpenTo then NS.OpenTo(rec.entry.name) end
    if rec.page then
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
    local rec = { entry = entry, frame = f, crop = 0, fresh = true }
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
    -- keep following the contents while the page is on show: sections open,
    -- lists fill, a new version adds options
    local wait = 0
    f:HookScript("OnUpdate", function(_, elapsed)
        wait = wait + (elapsed or 0)
        if wait < 0.4 then return end
        wait = 0
        if rec.holder and Measure(rec) and NS.OnHostedResize then NS.OnHostedResize(rec) end
    end)
    return rec
end

---------------------------------------------------------
--  SECTION: Showing and parking
---------------------------------------------------------
-- Puts the addon's settings into holder and shows them. Returns the record,
-- or nil when the addon has no window the hub can host. The second result is
-- true the first time this window is shown here.
function Host.Attach(entry, holder)
    local f = Resolve(entry)
    if not f then return nil end
    local s = SpecSettings(entry)
    local rec = byFrame[f] or Adopt(entry, f)
    byName[entry.name] = rec
    rec.holder = holder
    -- a page: sized by the hub. A window: its own size, minus its title bar.
    rec.page = (s.page or (s.canvas and not s.frame)) and true or false
    rec.autoCrop = not rec.page and s.crop == nil
    if s.crop then
        rec.crop = s.crop
    elseif rec.page then
        rec.crop = 0
    end
    rec.frozen, rec.grew, rec.cropLooks = false, 0, 0
    rec.internal = true
    local ok, err = pcall(function()
        -- Fonts first. Changing a font after the page is laid out moves the
        -- text, and what's anchored under it can be left undrawn.
        if NS.NoteThemeFonts then NS.NoteThemeFonts(f) end
        Place(rec)
        if rec.page and f:IsShown() then f:Hide() end   -- so its OnShow builds the page
        f:Show()
        Measure(rec)
    end)
    rec.internal = false
    if not ok then
        if not rec.warned then
            rec.warned = true
            NS.Print("|cffff4040couldn't show " .. entry.title .. "'s settings here:|r " .. tostring(err))
        end
        return nil
    end
    local first = rec.fresh
    rec.fresh = false
    return rec, first
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

-- The pane changed size or scale: fit the hosted window to it again.
function Host.Refit(entry)
    local rec = byName[entry.name]
    if not rec or not rec.holder or not rec.frame:IsShown() then return end
    rec.internal = true
    pcall(function()
        Place(rec)
        Measure(rec)
    end)
    rec.internal = false
end
