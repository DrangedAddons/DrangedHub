---------------------------------------------------------
--  DrangedAddons - Core
--  Author: Dranged
---------------------------------------------------------
-- Finds the installed Dranged addons, keeps what the hub knows about each one,
-- and owns the saved settings, the slash command and the minimap button.
--
-- An addon can describe itself to the hub (Adapters.lua does this for the
-- addons that don't yet):
--
--   DrangedAddons.Register({
--     name = "MyAddon",                       -- the addon's folder name
--     settings = {
--       frame = "MyAddonConfig",              -- its settings window: a global name or a function returning the frame
--       canvas = "MyAddon",                   -- or: the name of its Options > AddOns page
--       open = function() ... end,            -- builds/opens the settings when the frame doesn't exist yet
--       crop = 34,                            -- px of the window's own title bar to cut off
--     },
--     minimap = { get = function() end, set = function(on) end },   -- only for a button that isn't LibDBIcon's
--     ldb = "MyAddon",                        -- its LibDBIcon name when that isn't the folder name
--     actions = { { "Open window", function() end, keep = true } }, -- footer buttons; keep = leave the hub open
--   })

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
--  SECTION: Registry
---------------------------------------------------------
local specs = {}

function Hub.Register(spec)
    if type(spec) ~= "table" or type(spec.name) ~= "string" then return end
    specs[spec.name] = spec
    local entry = NS.byName and NS.byName[spec.name]
    if entry then
        entry.spec = spec
        entry.mm = nil
    end
end
NS.Register = Hub.Register

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
                    tool = name:find("Probe$") ~= nil,
                    spec = specs[name],
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
    local spec = entry.spec
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
local slashMap

function NS.Commands(entry)
    if not slashMap then
        slashMap = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "string" then
                local key = k:match("^SLASH_(.-)%d+$")
                if key then
                    slashMap[key] = slashMap[key] or {}
                    table.insert(slashMap[key], v)
                end
            end
        end
    end
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
        if arg ~= ADDON then return end
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
