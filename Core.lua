---------------------------------------------------------
--  DrangedAddons - Core
--  Author: Dranged
---------------------------------------------------------
-- Finds the installed Dranged addons, keeps what the hub knows about each one,
-- and owns the saved settings, the slash command and the minimap button.
--
-- Each addon says for itself where its settings are, so a new version of an
-- addon (or a new addon) needs no new version of the hub. Two ways, and
-- neither depends on which addon loads first:
--
-- 1. Lines in the addon's .toc (no code):
--
--   ## X-DrangedHub-Frame: MyAddonConfig        its settings window (a global frame name)
--   ## X-DrangedHub-Page: MyAddon               or: the name of its Options > AddOns page
--   ## X-DrangedHub-Open: /myaddon config       builds the window when it doesn't exist yet
--   ## X-DrangedHub-Crop: 40                    px of the window's title bar to cut off (left out: measured)
--   ## X-DrangedHub-Actions: Main window=/myaddon; Preview=/myaddon preview [keep]
--   ## X-DrangedHub-Minimap: MyAddonLDB         its LibDBIcon name when that isn't the folder name
--   ## X-DrangedHub-Tool: 1                     list it under Tools
--
-- 2. A table in the addon's Lua, for anything that needs a function:
--
--   DrangedHubSpecs = DrangedHubSpecs or {}
--   DrangedHubSpecs.MyAddon = {
--     settings = {
--       frame = "MyAddonConfig",              -- a global name, the frame itself, or a function returning it
--       canvas = "MyAddon",                   -- or: the name of its Options > AddOns page
--       page = true,                          -- frame is a sizeless page: the hub sizes and scrolls it
--       open = function() ... end,            -- builds/opens the settings when the frame doesn't exist yet
--       crop = 34,                            -- px of title bar to cut off (left out: measured)
--     },
--     minimap = { get = function() end, set = function(on) end },   -- only for a button that isn't LibDBIcon's
--     ldb = "MyAddon",                        -- its LibDBIcon name when that isn't the folder name
--     actions = { { "Open window", function() end, keep = true } }, -- footer buttons; keep = leave the hub open
--   }
--
-- Adapters.lua holds the same thing for addon versions that say nothing.

local ADDON, NS = ...

local Hub = {}
_G.DrangedAddons = Hub
NS.API = Hub

-- The name players see. The folder (ADDON) is DrangedHub, because the
-- DrangedAddons repo name belongs to the desktop manager app.
local TITLE = "DrangedAddons"
NS.TITLE = TITLE

NS.LOGO = "Interface\\AddOns\\" .. ADDON .. "\\logo"

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local NumAddOns = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
local AddOnInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

NS.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "?"

function NS.Print(msg)
    print("|cffffd100" .. TITLE .. "|r: " .. tostring(msg))
end

---------------------------------------------------------
--  SECTION: Options > AddOns pages
---------------------------------------------------------
-- Addons that keep their settings on a game Options page register a frame for
-- it. Remembering those frames (for every addon that loads after this one)
-- lets the hub show the page in its own window.
NS.canvas = {}
if Settings and Settings.RegisterCanvasLayoutCategory then
    hooksecurefunc(Settings, "RegisterCanvasLayoutCategory", function(panel, name)
        if type(name) == "string" and type(panel) == "table" then NS.canvas[name] = panel end
    end)
end

---------------------------------------------------------
--  SECTION: What the hub knows about each addon
---------------------------------------------------------
-- First one found wins: the addon's own Lua table, the addon's own .toc
-- lines, the hub's built-in list (Adapters.lua), a guess from the usual
-- frame names.
DrangedHubSpecs = DrangedHubSpecs or {}
local builtin = {}

-- Same as setting DrangedHubSpecs[spec.name], for addons that load after the hub.
function Hub.Register(spec)
    if type(spec) ~= "table" or type(spec.name) ~= "string" then return end
    DrangedHubSpecs[spec.name] = spec
    local entry = NS.byName and NS.byName[spec.name]
    if entry then entry.mm = nil end
end

function NS.Builtin(spec)
    builtin[spec.name] = spec
end

-- The hub's own entry for an addon, whatever the addon says about itself.
function NS.BuiltinSpec(name)
    return builtin[name]
end

local function Meta(name, field)
    local v = GetMeta(name, "X-DrangedHub-" .. field)
    if type(v) ~= "string" then return nil end
    v = strtrim(v)
    if v == "" then return nil end
    return v
end

-- Slash commands, read from the SLASH_<KEY>n globals. SlashCmdList itself is
-- only ever indexed by key: on this client walking it with pairs() finds none
-- of the addons' commands.
local slashMap    -- KEY -> { "/cmd", ... }
local slashKey    -- "/cmd" (lower case) -> KEY

local function ReadSlashes()
    slashMap, slashKey = {}, {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" then
            local key = k:match("^SLASH_(.-)%d+$")
            if key then
                slashMap[key] = slashMap[key] or {}
                table.insert(slashMap[key], v)
                slashKey[v:lower()] = key
            end
        end
    end
end

-- The function behind a command, or nil.
local function SlashHandler(cmd)
    -- the game's own lookup table, where the client leaves it reachable
    local hash = rawget(_G, "hash_SlashCmdList")
    if type(hash) == "table" then
        local fn = hash[cmd:upper()]
        if type(fn) == "function" then return fn end
    end
    for pass = 1, 2 do
        if not slashKey or pass == 2 then ReadSlashes() end   -- second pass: an addon loaded since
        local key = slashKey[cmd]
        local fn = key and SlashCmdList[key]
        if type(fn) == "function" then return fn end
    end
    return nil
end

-- Last resort: put the text through the chat box, which is what typing it does.
local function TypeSlash(text)
    local box = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) or ChatFrame1EditBox
        or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
    if not (box and box.SetText and box.GetText) then return false end
    local send
    if type(ChatEdit_SendText) == "function" then
        send = function() ChatEdit_SendText(box, 0) end
    elseif type(box.SendText) == "function" then
        send = function() box:SendText() end
    else
        return false
    end
    local typed = box:GetText()
    box:SetText(text)
    local ok = pcall(send)
    box:SetText(typed or "")   -- whatever the player was in the middle of typing
    return ok
end

-- Runs a slash command given as text ("/myaddon config"), as if typed.
-- Returns false when nothing could run it.
local slashFailed = {}

function NS.RunSlash(text)
    local cmd, rest = tostring(text):match("^%s*(/%S+)%s*(.-)%s*$")
    if not cmd then return false end
    cmd = cmd:lower()
    local fn = SlashHandler(cmd)
    if fn then
        fn(rest)
        return true
    end
    if TypeSlash(cmd .. (rest ~= "" and (" " .. rest) or "")) then return true end
    if not slashFailed[cmd] then
        slashFailed[cmd] = true
        NS.Print("couldn't run " .. cmd .. ".")
    end
    return false
end

-- The addon's X-DrangedHub lines as a spec, or nil when it has none.
local function TocSpec(name)
    local frame, page = Meta(name, "Frame"), Meta(name, "Page")
    local open, actions, ldb = Meta(name, "Open"), Meta(name, "Actions"), Meta(name, "Minimap")
    if not (frame or page or open or actions or ldb) then return nil end
    local spec = { name = name, ldb = ldb }
    local opener = open and function() NS.RunSlash(open) end or nil
    if frame or page then
        spec.settings = { frame = frame, canvas = page, open = opener, crop = tonumber(Meta(name, "Crop") or "") }
    elseif opener then
        spec.settings = { open = opener }
    end
    if actions then
        spec.actions = {}
        for part in actions:gmatch("[^;]+") do
            local label, cmd = part:match("^%s*(.-)%s*=%s*(.-)%s*$")
            if label and label ~= "" and cmd and cmd ~= "" then
                local keep = false
                local bare = cmd:match("^(.-)%s*%[keep%]$")
                if bare then keep, cmd = true, bare end
                spec.actions[#spec.actions + 1] = { label, function() NS.RunSlash(cmd) end, keep = keep }
            end
        end
    end
    return spec
end

-- An addon that says nothing and isn't in the built-in list: look for a
-- settings window under the names the Dranged addons use.
local GUESS = { "Config", "Settings", "Options", "ConfigFrame", "SettingsFrame", "OptionsFrame" }

local function Guess(entry)
    if entry.guess then return entry.guess end
    if not entry.loaded then return nil end
    for _, suffix in ipairs(GUESS) do
        local f = _G[entry.name .. suffix]
        if type(f) == "table" and f.SetParent and f.GetObjectType and f.GetNumPoints then
            entry.guess = { name = entry.name, settings = { frame = entry.name .. suffix } }
            return entry.guess
        end
    end
    return nil
end

function NS.Spec(entry)
    if entry.isHub then return nil end
    local own = DrangedHubSpecs[entry.name]
    if type(own) == "table" then return own end
    if entry.toc == nil then entry.toc = TocSpec(entry.name) or false end
    return entry.toc or builtin[entry.name] or Guess(entry)
end

local function Clean(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

-- The hub's own page (the first row of the list).
NS.self = {
    name = ADDON,
    title = TITLE,
    rowTitle = "Overview",
    notes = "One window for every Dranged addon's settings.",
    version = NS.VERSION,
    icon = NS.LOGO,
    loaded = true,
    isHub = true,
}

-- Every installed addon written by Dranged, loaded or not.
function NS.Scan()
    local list, byName = {}, {}
    for i = 1, NumAddOns() do
        local name, title, notes = AddOnInfo(i)
        if name and name ~= ADDON then
            local author = GetMeta(name, "Author") or ""
            if GetMeta(name, "X-DrangedAddons-Games") or author:find("Dranged", 1, true) then
                local icon = GetMeta(name, "IconTexture")
                local entry = {
                    name = name,
                    title = Clean(title) or name,
                    notes = Clean(notes) or "",
                    version = GetMeta(name, "Version"),
                    icon = tonumber(icon) or icon or NS.LOGO,
                    loaded = IsLoaded(name) and true or false,
                    tool = name:find("Probe$") ~= nil or Meta(name, "Tool") ~= nil,
                }
                list[#list + 1] = entry
                byName[name] = entry
            end
        end
    end
    table.sort(list, function(a, b) return a.title:lower() < b.title:lower() end)
    NS.addons, NS.byName = list, byName
end

---------------------------------------------------------
--  SECTION: Loading an addon or not
---------------------------------------------------------
-- For this character; the game applies it at the next reload.
function NS.IsEnabled(name)
    local who = UnitName("player")
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, name, who)
        if ok and type(state) == "number" then return state > 0 end
    end
    if GetAddOnEnableState then
        local ok, state = pcall(GetAddOnEnableState, who, name)
        if ok and type(state) == "number" then return state > 0 end
    end
    return IsLoaded(name) and true or false
end

function NS.SetEnabled(name, on)
    local who = UnitName("player")
    local fn
    if on then
        fn = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
    else
        fn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
    end
    if fn then pcall(fn, name, who) end
end

---------------------------------------------------------
--  SECTION: Minimap buttons
---------------------------------------------------------
-- Returns { get, set } for an addon's minimap button, or nil when it has none.
-- Most are LibDBIcon buttons: the saved table the addon registered is on the
-- button, so hiding it here is remembered by the addon itself.
function NS.Minimap(entry)
    if entry.isHub then
        return {
            get = function() return not NS.db.minimap.hide end,
            set = function(on) NS.SetLauncherShown(on) end,
        }
    end
    if not entry.loaded then return nil end
    local spec = NS.Spec(entry)
    if spec and spec.minimap then return spec.minimap end
    if entry.mm then return entry.mm end
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    local id = (spec and spec.ldb) or entry.name
    local button = DBI and DBI:GetMinimapButton(id)
    if not button then return nil end
    entry.mm = {
        get = function()
            if button.db then return not button.db.hide end
            return button:IsShown() and true or false
        end,
        set = function(on)
            if button.db then button.db.hide = not on end
            if on then DBI:Show(id) else DBI:Hide(id) end
        end,
    }
    return entry.mm
end

function NS.SetAllMinimap(on)
    for _, entry in ipairs(NS.addons or {}) do
        local mm = NS.Minimap(entry)
        if mm then pcall(mm.set, on) end
    end
end

---------------------------------------------------------
--  SECTION: Slash commands of an addon
---------------------------------------------------------
-- Every /command whose SLASH_ key starts with the addon's name, e.g.
-- SLASH_CRATECOSTWRITS1 for CrateCost. Read from the globals once.
function NS.Commands(entry)
    if not slashMap then ReadSlashes() end
    local up = entry.name:upper()
    local out, seen = {}, {}
    for key, cmds in pairs(slashMap) do
        if key:sub(1, #up) == up then
            for _, cmd in ipairs(cmds) do
                if not seen[cmd] then
                    seen[cmd] = true
                    out[#out + 1] = cmd
                end
            end
        end
    end
    table.sort(out)
    return out
end

---------------------------------------------------------
--  SECTION: Minimap button and Options > AddOns page
---------------------------------------------------------
-- The kit's UI.Launcher and UI.RegisterSettingsPage name things after the
-- folder. These two do the same job under the name players see.
local function Launcher()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (LDB and DBI) then return end
    local obj = LDB:NewDataObject(TITLE, {
        type = "launcher",
        text = TITLE,
        icon = "Interface\\AddOns\\" .. ADDON .. "\\icon",
        OnClick = function() NS.Toggle() end,
        OnTooltipShow = function(tt)
            tt:AddLine(TITLE)
            tt:AddLine("|cffffd100Click|r to open", 1, 1, 1)
            tt:AddLine("|cffffd100Drag|r to move this button", 1, 1, 1)
        end,
    })
    DBI:Register(TITLE, obj, NS.db.minimap)
end

function NS.SetLauncherShown(on)
    NS.db.minimap.hide = not on
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if not DBI then return end
    if on then DBI:Show(TITLE) else DBI:Hide(TITLE) end
end

local function SettingsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local UI = NS.UI
    local panel = CreateFrame("Frame")
    panel.name = TITLE
    local tex = panel:CreateTexture(nil, "ARTWORK")
    tex:SetSize(24, 24)
    tex:SetTexture(NS.LOGO)
    tex:SetPoint("TOPLEFT", 16, -12)
    local title = UI.Text(panel, TITLE, "GameFontNormalLarge")
    title:SetPoint("LEFT", tex, "RIGHT", 6, 0)
    local text = UI.Text(panel, "Every Dranged addon's settings are in one window. You can also open it with /dranged.")
    text:SetPoint("TOPLEFT", 16, -46)
    local btn = UI.Button(panel, "Open " .. TITLE, 180, 24, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        NS.OpenTo()
    end)
    btn:SetPoint("TOPLEFT", 16, -74)
    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------
--  SECTION: Startup
---------------------------------------------------------
local DEFAULTS = { theme = "auto", scale = 1, host = true }

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= ADDON then
            -- an addon loaded on demand after login
            local entry = NS.byName and NS.byName[arg]
            if entry and not entry.loaded then
                entry.loaded = true
                if NS.RefreshWindow then NS.RefreshWindow() end
            end
            return
        end
        DrangedAddonsDB = DrangedAddonsDB or {}
        NS.db = DrangedAddonsDB
        for k, v in pairs(DEFAULTS) do
            if NS.db[k] == nil then NS.db[k] = v end
        end
        NS.db.minimap = NS.db.minimap or { hide = false }
    elseif event == "PLAYER_LOGIN" then
        if not NS.db then return end
        NS.Scan()
        Launcher()
        pcall(SettingsPage)
    end
end)

function DrangedAddons_OnCompartmentClick()
    NS.Toggle()
end

-- The key starts with the folder name so the hub lists its own commands too.
SLASH_DRANGEDHUB1 = "/dranged"
SLASH_DRANGEDHUB2 = "/drangedaddons"
SlashCmdList.DRANGEDHUB = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "" then
        NS.Toggle()
        return
    end
    if msg == "debug" then
        NS.DebugDump()
        return
    end
    if msg == "overview" or TITLE:lower():sub(1, #msg) == msg or ADDON:lower():sub(1, #msg) == msg then
        NS.OpenTo(ADDON)
        return
    end
    for _, entry in ipairs(NS.addons or {}) do
        if entry.name:lower():sub(1, #msg) == msg or entry.title:lower():sub(1, #msg) == msg then
            NS.OpenTo(entry.name)
            return
        end
    end
    NS.Print("no Dranged addon starts with '" .. msg .. "'. /dranged opens the window.")
end

-- For other addons: DrangedAddons.Open("CastCount") or DrangedAddons.Open().
function Hub.Open(name) NS.OpenTo(name) end
function Hub.Toggle() NS.Toggle() end
