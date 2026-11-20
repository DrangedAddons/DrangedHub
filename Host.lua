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

---------------------------------------------------------
--  SECTION: Placing
---------------------------------------------------------
-- Rule for this file: nothing here changes a frame's anchors, size or shown
-- state from inside a size or show handler. Those handlers only tell the hub
-- to lay out again, and the hub does that from its own OnUpdate. Re-anchoring
-- a page while the game is in the middle of laying it out leaves parts of it
-- undrawn.

-- A hub-made show or hide isn't "the addon opened/closed its window".
local function Enter(rec) rec.internal = (rec.internal or 0) + 1 end
local function Leave(rec) rec.internal = math.max(0, (rec.internal or 0) - 1) end
local function Internal(rec) return (rec.internal or 0) > 0 end

local function Place(rec)
    local f, holder = rec.frame, rec.holder
    if f:GetParent() ~= holder then f:SetParent(holder) end
    f:ClearAllPoints()
    if rec.page then
        -- The way the game's Options window holds a page: pinned to both
        -- corners of a holder, and the holder is what gets a size.
        f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
        f:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    else
        f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, rec.crop)
    end
    f:SetFrameStrata(holder:GetFrameStrata())
    f:SetFrameLevel(holder:GetFrameLevel() + 1)
    Strip(rec)
end

-- Has the addon (or the game's Options window) moved the frame elsewhere?
local function Displaced(rec)
    local f = rec.frame
    if f:GetParent() ~= rec.holder then return true end
    local _, rel = f:GetPoint(1)
    return rel ~= rec.holder
end

-- The size the hub's pane has to give this window or page, and the width
-- worth widening the hub for. Only reads, apart from a measured title crop.
function Host.Need(rec)
    local f = rec.frame
    local s = f:GetScale() or 1
    if rec.page then
        if not rec.frozen then
            local ok, w, h = pcall(Extent, f)
            if ok and w and h then
                -- contents that keep growing with the page would never settle: stop following them
                if rec.needH and h > rec.needH + 2 then rec.grew = (rec.grew or 0) + 1 else rec.grew = 0 end
                if rec.grew > 8 then
                    rec.frozen = true
                else
                    rec.needW, rec.needH = w, h
                end
            end
        end
        local vw, vh = Viewport()
        return math.max(vw, (rec.needW or 0) * s), math.max(vh, (rec.needH or 0) * s), (rec.needW or 0) * s
    end
    if rec.autoCrop and rec.hadTitle and (rec.cropLooks or 0) < 4 then
        -- only while the window settles after being shown: contents that move
        -- later (a list scrolling under the title) mustn't shift the crop
        rec.cropLooks = (rec.cropLooks or 0) + 1
        local ok, gap = pcall(TitleGap, rec)
        if ok and gap and gap ~= rec.crop then
            rec.crop = gap
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", rec.holder, "TOPLEFT", 0, gap)
        end
    end
    local w = (f:GetWidth() or 0) * s
    local h = ((f:GetHeight() or 0) - rec.crop) * s
    return math.max(50, w), math.max(50, h), w
end

---------------------------------------------------------
--  SECTION: When the addon shows or hides its window itself
---------------------------------------------------------
local function OnShown(rec)
    if Internal(rec) or not rec.holder then return end
    if NS.OpenTo then NS.OpenTo(rec.entry.name) end
    if rec.page then
        -- the game's Options window just took the page back: put it here again
        C_Timer.After(0, function()
            if not rec.holder then return end
            Enter(rec)
            pcall(Place, rec)
            -- closing the Options window may hide the page: that isn't the addon closing it
            if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then
                pcall(HideUIPanel, SettingsPanel)
            end
            if not rec.frame:IsShown() then pcall(rec.frame.Show, rec.frame) end
            Leave(rec)
            if NS.OnHostedResize then NS.OnHostedResize(rec) end
        end)
    end
end

local function OnHidden(rec)
    if Internal(rec) or not rec.holder then return end
    if NS.IsShowing and NS.IsShowing(rec.entry) then NS.Close() end
end

local function Adopt(entry, f)
    local rec = { entry = entry, frame = f, crop = 0, fresh = true, internal = 0 }
    byFrame[f] = rec
    byName[entry.name] = rec

    hooksecurefunc(f, "Show", function() OnShown(rec) end)
    hooksecurefunc(f, "Hide", function() OnHidden(rec) end)
    hooksecurefunc(f, "SetShown", function(_, on)
        if on then OnShown(rec) else OnHidden(rec) end
    end)
    -- the addon may re-place its window when it shows; the hub puts it back on its next update
    f:HookScript("OnShow", function()
        if rec.holder and NS.OnHostedResize then
            rec.check = true
            NS.OnHostedResize(rec)
        end
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
    rec.frozen, rec.grew, rec.cropLooks, rec.check = false, 0, 0, false
    Enter(rec)
    local ok, err = pcall(function()
        Place(rec)
        if not f:IsShown() then f:Show() end
    end)
    Leave(rec)
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
    Enter(rec)
    pcall(rec.frame.Hide, rec.frame)
    Leave(rec)
end

-- Puts the frame back in its holder. force: always; otherwise only when the
-- addon moved it since the hub last looked.
function Host.Replace(rec, force)
    if not rec.holder then return end
    local need = force or (rec.check and Displaced(rec))
    rec.check = false
    if not need then return end
    Enter(rec)
    pcall(Place, rec)
    Leave(rec)
end

---------------------------------------------------------
--  SECTION: Checking what the game drew
---------------------------------------------------------
-- Counts what is on show in the hosted frame and what has no place on screen:
-- shown and anchored, but the game has no rectangle for it, so it isn't
-- drawn. (Templates carry spare textures with no anchor at all; those don't count.)
local function Census(f)
    local shown, lost = 0, 0
    local function Walk(obj, depth)
        if obj.IsShown and not obj:IsShown() then return end
        shown = shown + 1
        if obj.GetNumPoints and (obj:GetNumPoints() or 0) > 0 and not (obj:GetLeft() and obj:GetTop()) then
            lost = lost + 1
        end
        if depth < 2 and obj.GetChildren then
            for _, child in ipairs({ obj:GetChildren() }) do Walk(child, depth + 1) end
            for _, region in ipairs({ obj:GetRegions() }) do Walk(region, depth + 1) end
        end
    end
    for _, child in ipairs({ f:GetChildren() }) do Walk(child, 1) end
    for _, region in ipairs({ f:GetRegions() }) do Walk(region, 1) end
    return shown, lost
end

-- How much of the hosted frame the game hasn't placed: 0 when it's all there,
-- -1 when the frame itself isn't on show.
function Host.Lost(rec)
    local f = rec.frame
    if not f:IsVisible() or not f:GetLeft() then return -1 end
    local ok, _, lost = pcall(Census, f)
    return ok and lost or 0
end

-- Lines for /dranged debug.
function Host.Describe(rec)
    local f = rec.frame
    local function N(v) return v and ("%.0f"):format(v) or "nil" end
    local lines = {}
    lines[#lines + 1] = ("%s: %s, crop %s, needs %sx%s, internal %s, reshown %s"):format(
        rec.entry.name, rec.page and "page" or "window", tostring(rec.crop), N(rec.needW), N(rec.needH),
        tostring(rec.internal), tostring(rec.reshown or 0))
    lines[#lines + 1] = ("frame: shown %s, visible %s, in holder %s, size %sx%s, left %s top %s, scale %.2f, alpha %.2f, level %s"):format(
        tostring(f:IsShown()), tostring(f:IsVisible()), tostring(f:GetParent() == rec.holder),
        N(f:GetWidth()), N(f:GetHeight()), N(f:GetLeft()), N(f:GetTop()),
        f:GetEffectiveScale() or 0, f:GetAlpha() or 0, tostring(f:GetFrameLevel()))
    for i = 1, math.min(2, f:GetNumPoints() or 0) do
        local point, rel, relPoint, x, y = f:GetPoint(i)
        lines[#lines + 1] = ("point %d: %s to %s %s, %s, %s"):format(i, tostring(point),
            rel == rec.holder and "holder" or tostring(rel and rel.GetName and rel:GetName() or rel), tostring(relPoint), N(x), N(y))
    end
    local h = rec.holder
    lines[#lines + 1] = ("holder: size %sx%s, left %s top %s, visible %s"):format(
        N(h:GetWidth()), N(h:GetHeight()), N(h:GetLeft()), N(h:GetTop()), tostring(h:IsVisible()))
    local ok, shown, lost = pcall(Census, f)
    if ok then
        lines[#lines + 1] = ("inside: %d things on show, %d without a place on screen"):format(shown, lost)
    else
        lines[#lines + 1] = "inside: couldn't count (" .. tostring(shown) .. ")"
    end
    return lines
end
