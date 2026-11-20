---------------------------------------------------------
--  DrangedAddons - Adapters
--  Author: Dranged
---------------------------------------------------------
-- What the hub knows about addon versions that don't describe themselves:
-- where each one's settings window is, how to get it built, how much of its
-- title bar to cut off, and which windows get a button in the footer.
-- An addon with X-DrangedHub lines in its .toc, or its own DrangedHubSpecs
-- entry, replaces its entry here (see Core.lua), so this list only ever has
-- to cover the versions that were out before the addon said it itself.

local ADDON, NS = ...

-- The addon's "addon list" click (the same thing its minimap button does).
local function Compartment(fn, button)
    return function()
        local f = _G[fn]
        if f then f(nil, button or "LeftButton") end
    end
end

local function Slash(key, msg)
    return function()
        local f = SlashCmdList[key]
        if f then f(msg or "") end
    end
end

NS.Builtin({
    name = "AuctionatorSync",
    settings = { frame = "AuctionatorSyncFrame", open = Compartment("AuctionatorSync_OnCompartmentClick"), crop = 34 },
    actions = { { "Price list", Compartment("AuctionatorSync_OnCompartmentClick", "RightButton") } },
})

NS.Builtin({
    name = "CastCount",
    settings = { frame = "CastCountConfig", open = Compartment("CastCount_OnCompartmentClick"), crop = 34 },
})

NS.Builtin({
    name = "ConfuciusSay",
    settings = { frame = "ConfuciusSayConfig", open = Compartment("ConfuciusSay_OnCompartmentClick"), crop = 34 },
})

NS.Builtin({
    name = "CraftRoute",
    settings = { frame = "CraftRouteSettings", crop = 60 },
    -- its own minimap button, not LibDBIcon's
    minimap = {
        get = function() return not (CraftRouteDB and CraftRouteDB.minimap and CraftRouteDB.minimap.hide) end,
        set = function(on)
            if not CraftRouteDB then return end
            CraftRouteDB.minimap = CraftRouteDB.minimap or {}
            CraftRouteDB.minimap.hide = (not on) or nil
            if CraftRoute and CraftRoute.UpdateMinimapButton then CraftRoute.UpdateMinimapButton() end
        end,
    },
    actions = {
        { "CraftRoute window", Slash("CRAFTROUTE", "window") },
        { "Materials", Slash("CRAFTROUTE", "all") },
    },
})

NS.Builtin({
    name = "CrateCost",
    settings = { frame = "CrateCostConfig", open = Slash("CRATECOST", "config"), crop = 42 },
    actions = {
        { "Home", Slash("CRATECOST", "") },
        { "Crate list", Slash("CRATECOST", "list") },
        { "Writs", Slash("CRATECOST", "writs") },
        { "Merchant", Slash("CRATECOST", "merchant") },
        { "Cart", Slash("CRATECOST", "cart") },
    },
})

NS.Builtin({
    name = "EscortReady",
    settings = {
        canvas = "EscortReady",
        open = function() if EscortReady and EscortReady.OpenSettings then EscortReady.OpenSettings() end end,
    },
})

NS.Builtin({
    name = "GroupHost",
    settings = { frame = "GroupHostFrame", open = Compartment("GroupHost_OnCompartmentClick"), crop = 40 },
})

NS.Builtin({
    name = "HoTForecast",
    settings = { frame = "HoTForecastConfig", open = Compartment("HoTForecast_OnCompartmentClick"), crop = 42 },
})

NS.Builtin({
    name = "ShoppingDock",
    settings = { frame = "ShoppingDockSettings", open = Compartment("ShoppingDock_OnCompartmentClick", "RightButton"), crop = 40 },
    actions = { { "Shopping list", Slash("SHOPPINGDOCK", "") } },
})

-- Its settings are a panel beside its main window, so they stay there.
NS.Builtin({
    name = "SpawnCamp",
    actions = {
        { "SpawnCamp window", Slash("SPAWNCAMP", "") },
        { "Settings", function() if SpawnCamp and SpawnCamp.OpenSettings then SpawnCamp.OpenSettings() end end },
    },
})

NS.Builtin({
    name = "TooltipExtras",
    settings = { canvas = "TooltipExtras", open = Slash("TOOLTIPEXTRAS", "") },
})

NS.Builtin({
    name = "VendorPoint",
    actions = {
        { "Nearest vendor", Slash("VENDORPOINT", "vendor"), keep = true },
        { "Nearest repair", Slash("VENDORPOINT", "repair"), keep = true },
        { "Floating frame", Slash("VENDORPOINT", "frame"), keep = true },
    },
})

-- Webby's own settings window (820 wide, with its own side list) stays its own.
NS.Builtin({
    name = "WebbyFrames",
    actions = { { "Settings", Compartment("WebbyFrames_OnCompartmentClick") } },
})

NS.Builtin({
    name = "ZoneStyle",
    settings = { frame = "ZoneStyleConfig", open = Compartment("ZoneStyle_OnCompartmentClick"), crop = 42 },
    actions = { { "Preview", Slash("ZONESTYLE", "preview"), keep = true } },
})
