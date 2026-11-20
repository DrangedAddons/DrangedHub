# Changelog

## 0.2.2
- **Fixed:** addons whose `.toc` opens their settings with a slash command (AuctionatorSync, CastCount, ConfuciusSay, CrateCost, GroupHost, HoTForecast, ShoppingDock, ZoneStyle) showed "settings open in their own window" and chat said "no command /async (is the addon loaded?)". The hub looked commands up by walking the game's command list, which finds nothing on this client. Commands are now found through their `SLASH_` names, and typed into the chat box if that fails too.
- If an addon's own way of opening its settings doesn't produce the window, the hub tries the way its built-in entry knows before giving up.
- A command that can't be run is reported once, not on every click.

## 0.2.1
- **Fixed:** in 0.2.0 an Options page (EscortReady) came up empty and stayed empty. Pages are now held the way the game's own Options window holds them: pinned to both corners of a holder that the hub sizes, instead of being given a size and re-placed.
- The hub no longer re-anchors or resizes a hosted window from inside a size or show handler. Those only flag that a layout is needed, and the layout runs from the hub's own update, at most once a frame.
- The hub no longer changes fonts inside a hosted window. An addon's window keeps the fonts its own addon gave it; an Options page keeps the game's.
- A page shown in the hub for the first time is shown once more a moment later, and again only if the game still hasn't placed something in it.
- The hub can no longer close and reopen itself while it's putting a page in.
- `/dranged debug` prints what the hub thinks is on show (sizes, anchors, how many things in the page have no place on screen), for when a page looks wrong.

## 0.2.0
- **Fixed:** an addon's page could come up half drawn the first time it was clicked (EscortReady showed its title and one unlabelled tick box) and only filled in on the second click. The hub was changing the page's fonts after it had been laid out. Fonts now go on first, and the first show is repeated a frame later.
- **Addons describe themselves.** An addon can say where its settings window is, how to build it and which buttons it wants, with `X-DrangedHub` lines in its `.toc` or a `DrangedHubSpecs` entry in its Lua. Either works whichever addon loads first. A new version of an addon, or a new addon, no longer needs a new version of the hub. The built-in list stays for addon versions that say nothing, and an addon's own description replaces its entry there. See the README.
- **Addons that say nothing** are still picked up when their window is named `<Addon>Config`, `<Addon>Settings` or `<Addon>Options`.
- **Any size of window.** The pane scrolls both ways. A window wider than the pane widens the hub as far as the screen allows; past that, Shift+wheel or the bottom bar scrolls sideways.
- **Title bars are measured** when an addon doesn't give a crop, so a hosted window whose title bar changes height still lines up.
- **Options pages are measured properly:** nested contents count, a background or buttons pinned to the page's bottom edge don't, and the page follows sections opening and closing. A page fills the pane when its contents are smaller.
- An addon loaded after login (load on demand) moves from Not loaded to Addons without a reload.
- Changing Window size refits the page on show.

## 0.1.0
First beta. Not tested widely yet: expect layout fixes.

- **One window for every Dranged addon.** `/dranged`, the Penrose minimap button, the addon list button or Options > AddOns > DrangedAddons opens it. Installed Dranged addons are found from their `.toc` and listed on the left under Addons, Tools and Not loaded.
- **Settings inside the window.** AuctionatorSync, CastCount, ConfuciusSay, CraftRoute, CrateCost, GroupHost, HoTForecast, ShoppingDock and ZoneStyle show their settings window in the right-hand pane; EscortReady and TooltipExtras show their Options > AddOns page. Opening an addon's settings its usual way opens the hub on that addon's page.
- **Buttons for each addon's other windows** along the bottom, with its slash commands.
- **Minimap buttons:** a switch per addon, plus Hide all and Show all on the Overview page. Nothing is hidden until you ask.
- **Load on/off** per addon for this character.
- **Window size** stepper (70% to 180%), Look picker and Reload UI.
- SpawnCamp and WebbyFrames keep their own settings windows; the hub has buttons that open them.
