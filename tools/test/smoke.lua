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
    end
end)
Settings.RegisterCanvasLayoutCategory(ttePanel, "TooltipExtras")
SlashCmdList.TOOLTIPEXTRAS = function() TTE_SLASH = true end

DBI:Register("CastCount", {}, { hide = false })
DBI:Register("VendorPoint", {}, {})
FireEvent("PLAYER_LOGIN")

Say("look = " .. LOOK)
Check(NS.addons and #NS.addons == 8, "found 8 Dranged addons, got " .. tostring(NS.addons and #NS.addons))
Check(NS.byName.TooltipExtras.title == "TooltipExtras", "colour codes stripped from titles")
Check(NS.byName.Questie == nil, "other authors' addons are left out")
Check(DBI:GetMinimapButton("DrangedAddons") ~= nil, "hub minimap button registered")

SlashCmdList.DRANGEDHUB("")
local hub = DrangedAddonsFrame
Check(hub and hub:IsShown(), "/dranged opens the window")
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
local upd = ttePanel:GetScript("OnUpdate")
if upd then upd(ttePanel, 1) end
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
