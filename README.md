# DrangedHub

A WoW Forever addon. One window, titled **DrangedAddons** in game, that lists every Dranged addon you have installed and shows each one's settings.

The folder and repo are called DrangedHub because the DrangedAddons repo is the desktop addon manager.

## What it does
- **Finds the addons itself.** Any installed addon whose `.toc` says `Author: Dranged` or has an `X-DrangedAddons-Games` line is listed, loaded or not.
- **Shows each addon's settings in the window.** The addon's own settings window is moved into the right-hand pane without its border, title bar and close button. After that, the addon's own slash command or minimap button opens the hub on its page.
- **Buttons for the addon's other windows** along the bottom (CrateCost's crate list, CraftRoute's materials, and so on), plus its slash commands.
- **Minimap buttons in one place.** A switch per addon on its page, and on the Overview page a switch for every addon with **Hide all** and **Show all**. Nothing is hidden until you ask.
- **Load on/off per addon** for this character, on the Overview page. The game applies it at the next reload.
- **Window size** from 70% to 180%, a **Look** picker (Auto follows EllesmereUI when it's installed), and a **Reload UI** button.

## Using it
- `/dranged`, the minimap button, the addon list button or Options > AddOns > DrangedAddons opens the window.
- `/dranged cast` opens it on CastCount. Any start of an addon's name works. `/dranged overview` opens the first page.

Settings are account-wide: they are the window's size and look, and whether its minimap button shows.

## Which addons show their settings here
| Addon | In the hub |
|---|---|
| AuctionatorSync, CastCount, ConfuciusSay, CraftRoute, CrateCost, GroupHost, HoTForecast, ShoppingDock, ZoneStyle | settings window |
| EscortReady, TooltipExtras | their Options > AddOns page |
| SpawnCamp, WebbyFrames | buttons that open their own windows |
| VendorPoint, FishIO and the Probe tools | their commands and buttons |

No other addon's files are changed. Turn off **Show addon settings inside this window** on the Overview page and reload to give every window back.

## How an addon tells the hub about itself
Each addon says where its settings are, so a new version of an addon, or a whole new addon, needs no new version of the hub. The hub never looks inside a settings window: whatever the addon draws there is what shows, measured and scrolled as it is.

The hub takes the first of these it finds:

1. the addon's `DrangedHubSpecs` entry (Lua)
2. the addon's `X-DrangedHub` lines (`.toc`)
3. the hub's built-in list in `Adapters.lua`, for addon versions from before they said it themselves
4. a window named `<Addon>Config`, `<Addon>Settings` or `<Addon>Options`

Neither of the first two depends on which addon loads first.

### In the .toc
No code. Leave out what doesn't apply.

```
## X-DrangedHub-Frame: MyAddonConfig
## X-DrangedHub-Open: /myaddon config
## X-DrangedHub-Actions: Main window=/myaddon; Preview=/myaddon preview [keep]
```

| Line | Meaning |
|---|---|
| `X-DrangedHub-Frame` | global name of the settings window |
| `X-DrangedHub-Page` | or: the name of its Options > AddOns page (the hub must load before the addon for this one; otherwise use the Lua form with `frame` and `page = true`) |
| `X-DrangedHub-Open` | slash command that builds the window when it doesn't exist yet |
| `X-DrangedHub-Crop` | px of the window's own title bar to cut off. Left out, the hub measures it |
| `X-DrangedHub-Actions` | footer buttons, `Label=/command` separated by `;`. `[keep]` after a command leaves the hub open |
| `X-DrangedHub-Minimap` | its LibDBIcon name, when that isn't the folder name |
| `X-DrangedHub-Tool` | `1` lists it under Tools |

### In Lua
For anything that needs a function. Works whether the addon loads before or after the hub.

```lua
DrangedHubSpecs = DrangedHubSpecs or {}
DrangedHubSpecs.MyAddon = {
    settings = {
        frame = "MyAddonConfig",        -- a global name, the frame itself, or a function returning it
        page = true,                    -- the frame is a sizeless page: the hub sizes and scrolls it
        open = function() MyAddon.OpenConfig() end,   -- builds it when it doesn't exist yet
        crop = 34,                      -- left out: measured
    },
    minimap = { get = function() end, set = function(on) end },   -- only for a button that isn't LibDBIcon's
    actions = { { "Open window", function() MyAddon.Toggle() end, keep = true } },
}
```

`DrangedAddons.Open("MyAddon")` opens the hub on an addon's page.

### What a hosted window can rely on
- **Any size.** Taller than the pane: it scrolls. Wider: the hub window widens as far as the screen allows, then scrolls sideways (Shift+wheel, or drag the bar).
- **Changing size while open.** A window that resizes, or a page whose sections open and close, is followed.
- **Its own scroll lists, dropdowns, sliders and edit boxes** work as they do in its own window. The wheel scrolls the list under the cursor, and the pane everywhere else.
- **A page should be anchored from its top left.** Things pinned to a page's bottom or right edge follow the pane's size and aren't counted as contents.

## Development
- `tools/make_icon.py` builds `logo.tga`, `icon.tga` and `icon.ico` from `tools/penrose.png`.
- `/dranged debug` prints the state of the page on show.
- `tools/test/run.py` loads the addon against a mock of the WoW frame API and runs `smoke.lua` in four looks. It needs `lupa` (`pip install lupa`).
- `Theme.lua`, `Widgets.lua` and `Window.lua` are the shared Dranged UI kit, copied in unchanged.

Includes LibStub, CallbackHandler, LibDataBroker and LibDBIcon (see Libs).
