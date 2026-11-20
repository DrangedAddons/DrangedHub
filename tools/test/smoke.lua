-- Runs the hub against the mock. Globals in: ADDON_DIR, MOCK, LOOK
dofile(MOCK)

local fails = 0
local function Check(cond, what)
    if cond then Say("  ok   " .. what) else fails = fails + 1; Say("  FAIL " .. what) end
end

-- CraftRoute loads before the hub and has its settings frame at load.
CraftRouteDB = { minimap = {} }
CraftRoute = { UpdateMinimapButton = function() CR_UPDATED = (CR_UPDATED or 0) + 1 end }
local crWin = CreateFrame("Frame", "CraftRouteSettings", UIParent, "BackdropTemplate")
crWin:SetSize(660, 640)
crWin:Hide()
crWin:SetScript("OnShow", function(self) CR_SHOWN = (CR_SHOWN or 0) + 1; self:SetBackdrop({}) ; self:SetHeight(700) end)
local crClose = CreateFrame("Button", nil, crWin)
crClose:SetText("Close")
SlashCmdList.CRAFTROUTE = function(msg) CR_SLASH = msg end
SLASH_CRAFTROUTE1, SLASH_CRAFTROUTE2 = "/craftroute", "/cr"

-- CastCount: a lazily built window with a toggle, like the real one.
local ccWin
local function CCBuild()
    ccWin = CreateFrame("Frame", "CastCountConfig", UIParent, "BackdropTemplate")
    ccWin:SetSize(680, 500)
    ccWin:SetBackdrop({})
    local x = CreateFrame("Button", nil, ccWin, "UIPanelCloseButton")
    x:SetSize(32, 32)
    x:SetPoint("TOPRIGHT", 2, 2)
    CC_X = x
    table.insert(UISpecialFrames, "CastCountConfig")
end
function CastCount_OnCompartmentClick()
    if ccWin and ccWin:IsShown() then ccWin:Hide() return end
    if not ccWin then CCBuild() end
    ccWin:Show()
end
SLASH_CASTCOUNT1 = "/cc"

-- TocAddon: described by X-DrangedHub lines in its .toc. Its window is built by its slash command.
local tocWin
SLASH_TOCADDON1 = "/tocaddon"
SlashCmdList.TOCADDON = function(msg)
    TOC_SLASH = msg
    if msg == "config" and not tocWin then
        tocWin = CreateFrame("Frame", "TocAddonWin", UIParent, "BackdropTemplate")
        tocWin:SetSize(1400, 500)   -- wider than the hub's pane
        tocWin:SetPoint("CENTER")
        tocWin.nsTitle = tocWin:CreateFontString()
        tocWin.nsTitle:SetPoint("TOP", 0, -10)
        tocWin.nsTitle:SetText("TocAddon")
        local body = CreateFrame("Frame", nil, tocWin)
        body:SetSize(600, 300)
        body:SetPoint("TOPLEFT", 16, -46)
        tocWin:Hide()
    end
    if tocWin and msg == "config" then tocWin:Show() end
end

-- LuaAddon: loads before the hub and describes itself with a table. Its page has a
-- background that fills it and two buttons pinned to its bottom edge.
local luaPage = CreateFrame("Frame")   -- left shown, like a page nobody has opened yet
luaPage:SetScript("OnShow", function() LUA_SHOWN = (LUA_SHOWN or 0) + 1 end)
do
    local bg = luaPage:CreateTexture()
    bg:SetAllPoints()
    local block = CreateFrame("Frame", nil, luaPage)
    block:SetSize(400, 1500)
    block:SetPoint("TOPLEFT", 16, -16)
    local ok = CreateFrame("Button", nil, luaPage)
    ok:SetSize(100, 22)
    ok:SetPoint("BOTTOMLEFT", 16, 16)
    local cancel = CreateFrame("Button", nil, luaPage)
    cancel:SetSize(100, 22)
    cancel:SetPoint("LEFT", ok, "RIGHT", 8, 0)
end
DrangedHubSpecs = DrangedHubSpecs or {}
DrangedHubSpecs.LuaAddon = {
    settings = { frame = function() return luaPage end, page = true },
    actions = { { "Lua action", function() LUA_ACTION = true end, keep = true } },
}

-- GuessAddon: says nothing, has a window under a usual name.
local guessWin = CreateFrame("Frame", "GuessAddonConfig", UIParent)
guessWin:SetSize(500, 400)
guessWin:Hide()

local NS = LoadAddon(ADDON_DIR, "DrangedHub",
    { "Theme.lua", "Widgets.lua", "Window.lua", "Core.lua", "Controls.lua", "Host.lua", "Adapters.lua", "Hub.lua" })
FireEvent("ADDON_LOADED", "DrangedHub")

-- Addons after the hub: Options pages.
local ttePanel = CreateFrame("Frame")
ttePanel:SetScript("OnShow", function(self)
    TTE_BUILT = (TTE_BUILT or 0) + 1
    if not self.child then
        self.child = CreateFrame("Frame", nil, self)
        self.child:SetSize(300, 820)
        self.child:SetPoint("TOPLEFT", 16, -16)
    end
end)
Settings.RegisterCanvasLayoutCategory(ttePanel, "TooltipExtras")
SlashCmdList.TOOLTIPEXTRAS = function() TTE_SLASH = true end

DBI:Register("CastCount", {}, { hide = false })
DBI:Register("VendorPoint", {}, {})
FireEvent("PLAYER_LOGIN")

Say("look = " .. LOOK)
Check(NS.addons and #NS.addons == 11, "found 11 Dranged addons, got " .. tostring(NS.addons and #NS.addons))
Check(NS.byName.TooltipExtras.title == "TooltipExtras", "colour codes stripped from titles")
Check(NS.byName.Questie == nil, "other authors' addons are left out")
Check(DBI:GetMinimapButton("DrangedAddons") ~= nil, "hub minimap button registered")

SlashCmdList.DRANGEDHUB("")
local hub = DrangedAddonsFrame
Check(hub and hub:IsShown(), "/dranged opens the window")
local function Drive(dt) hub:GetScript("OnUpdate")(hub, dt) end
SlashCmdList.DRANGEDHUB("")
Check(not hub:IsShown(), "/dranged again closes it")

-- hosted window
SlashCmdList.DRANGEDHUB("castcount")
Check(hub:IsShown() and ccWin and ccWin:IsVisible(), "/dranged castcount shows CastCount's settings")
Check(ccWin:GetParent() ~= UIParent, "CastCount window moved into the hub")
Check(ccWin.backdropInfo == nil, "its backdrop is off")
Check(not CC_X:IsShown(), "its close X is hidden")
ccWin:SetBackdrop({})
FlushTimers()
Check(ccWin.backdropInfo == nil, "a re-applied backdrop is stripped again")

-- the addon's own toggle
CastCount_OnCompartmentClick()
Check(not hub:IsShown(), "CastCount hiding its window closes the hub")
Check(not ccWin:IsShown(), "window is hidden after that")
CastCount_OnCompartmentClick()
Check(hub:IsShown() and ccWin:IsVisible(), "CastCount showing its window opens the hub on it")

-- switching pages parks the old one without closing
SlashCmdList.DRANGEDHUB("craftroute")
Check(hub:IsShown() and crWin:IsVisible() and not ccWin:IsShown(), "switch to CraftRoute parks CastCount")
Check(crWin.backdropInfo == nil, "CraftRoute's OnShow backdrop is stripped")
Check(not crClose:IsShown(), "CraftRoute's Close button is hidden")
local mm = NS.Minimap(NS.byName.CraftRoute)
mm.set(false)
Check(CraftRouteDB.minimap.hide == true and CR_UPDATED == 1, "CraftRoute minimap adapter hides its button")
mm.set(true)

-- Options page
SlashCmdList.DRANGEDHUB("tooltip")
Check(ttePanel:IsVisible() and TTE_BUILT == 1, "TooltipExtras Options page shown in the hub and built")
Drive(1)
Check(ttePanel:GetHeight() > 800, "Options page height follows its contents, got " .. ttePanel:GetHeight())
Check(not crWin:IsShown(), "CraftRoute parked")

-- pages without hosted settings
SlashCmdList.DRANGEDHUB("escort")
Check(hub:IsShown(), "EscortReady (page not captured) falls back to an info page")
SlashCmdList.DRANGEDHUB("fishio")
SlashCmdList.DRANGEDHUB("vendor")
SlashCmdList.DRANGEDHUB("zonestyle")
SlashCmdList.DRANGEDHUB("hotprobe")
Check(hub:IsShown(), "info pages for the rest")

-- an addon described by its .toc: window built by its command, title bar measured, wide window
SlashCmdList.DRANGEDHUB("overview")
local normalW = hub:GetWidth()
Check(NS.byName.TocAddon.tool == true, "X-DrangedHub-Tool lists the addon under Tools")
SlashCmdList.DRANGEDHUB("tocaddon")
Check(TOC_SLASH == "config" and tocWin and tocWin:IsVisible(), ".toc Frame + Open: the command builds the window and it shows in the hub")
Check(tocWin:GetParent() ~= UIParent and not tocWin.nsTitle:IsShown(), "its title is off")
local _, _, _, _, cropY = tocWin:GetPoint(1)
Check(cropY == 40, "title bar measured without a Crop line, got " .. tostring(cropY))
Check(hub:GetWidth() > normalW, "the hub widens for a 1400 px window, got " .. tostring(hub:GetWidth()))
local spec = NS.Spec(NS.byName.TocAddon)
Check(#spec.actions == 2 and spec.actions[1][1] == "Main window" and spec.actions[2].keep == true, ".toc Actions parsed, [keep] read")
spec.actions[2][2]()
Check(TOC_SLASH == "preview", "a .toc action runs its slash command")
SlashCmdList.DRANGEDHUB("overview")
Check(hub:GetWidth() == normalW, "back to the normal width on another page")

-- an addon described in Lua before the hub loaded
LUA_SHOWN = 0
HUB_HIDES = 0
hub:HookScript("OnHide", function() HUB_HIDES = HUB_HIDES + 1 end)
local hidesBefore = HUB_HIDES
SlashCmdList.DRANGEDHUB("luaaddon")
Check(luaPage:IsVisible() and luaPage:GetParent() ~= nil, "DrangedHubSpecs entry set before the hub loaded is hosted")
Check(luaPage:GetHeight() == 1540, "page height from its contents, pinned buttons and background ignored, got " .. tostring(luaPage:GetHeight()))
Check(luaPage:GetNumPoints() == 2, "a page is pinned to both corners of its holder, like in the game's Options window")
local shownBefore = LUA_SHOWN
Drive(0.1)
Check(LUA_SHOWN == shownBefore + 1 and luaPage:IsVisible() and hub:IsShown(), "first show is repeated a moment later")
for _ = 1, 12 do Drive(1) end
Check(luaPage:GetHeight() == 1540, "and the height stays there, got " .. tostring(luaPage:GetHeight()))
Check(LUA_SHOWN == shownBefore + 1, "a page that drew properly isn't shown again")
local shownAfter = LUA_SHOWN
SlashCmdList.DRANGEDHUB("overview")
SlashCmdList.DRANGEDHUB("luaaddon")
for _ = 1, 4 do Drive(0.5) end
Check(LUA_SHOWN == shownAfter + 1, "later shows aren't repeated")
Check(HUB_HIDES == hidesBefore, "the hub never closed itself while putting a page in")
local printedBefore = #PRINTED
SlashCmdList.DRANGEDHUB("debug")
Check(#PRINTED >= printedBefore + 6, "/dranged debug prints the page's state")

-- an addon's own description beats the built-in one
local builtinSpec = NS.Spec(NS.byName.CastCount)
DrangedHubSpecs.CastCount = { settings = { frame = "CastCountConfig", crop = 10 } }
Check(NS.Spec(NS.byName.CastCount) ~= builtinSpec and NS.Spec(NS.byName.CastCount).settings.crop == 10, "an addon's own entry replaces the built-in one")
DrangedHubSpecs.CastCount = nil
Check(NS.Spec(NS.byName.CastCount) == builtinSpec, "and the built-in one is back without it")

-- an addon that says nothing
SlashCmdList.DRANGEDHUB("guessaddon")
Check(guessWin:IsVisible() and guessWin:GetParent() ~= UIParent, "a window named <Addon>Config is found without being told")

-- overview
SlashCmdList.DRANGEDHUB("drangedaddons")
NS.OpenTo("DrangedHub")
NS.SetAllMinimap(false)
Check(DBI:GetMinimapButton("CastCount").db.hide == true and not DBI:GetMinimapButton("CastCount"):IsShown(),
    "Hide all hides CastCount's minimap button and saves it")
Check(DBI:GetMinimapButton("VendorPoint").db.hide == true, "and VendorPoint's")
Check(CraftRouteDB.minimap.hide == true, "and CraftRoute's own")
Check(not DBI:GetMinimapButton("DrangedAddons").db.hide, "the hub's own button stays")
NS.SetAllMinimap(true)
Check(DBI:GetMinimapButton("CastCount"):IsShown(), "Show all brings them back")
NS.SetEnabled("ZoneStyle", true)
Check(NS.IsEnabled("ZoneStyle"), "enable toggle")
NS.UI.RefreshAll()
NS.SetLook("classic")
NS.SetLook("auto")

-- reopening lands on the last page; Esc-style hide of the hosted frame
hub:Hide()
SlashCmdList.DRANGEDHUB("castcount")
ccWin:Hide()
Check(not hub:IsShown(), "Esc on the hosted window closes the hub")
SlashCmdList.DRANGEDHUB("")
Check(hub:IsShown() and ccWin:IsVisible(), "reopens on the last page")

-- hosting off
NS.db.host = false
SlashCmdList.DRANGEDHUB("craftroute")
Check(hub:IsShown() and not crWin:IsVisible(), "hosting off: info page instead")
NS.db.host = true

FlushTimers()
for _, line in ipairs(PRINTED) do Say("  print: " .. line) end
Say(fails == 0 and "ALL OK" or (fails .. " FAILED"))
FAILS = fails
