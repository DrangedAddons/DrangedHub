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

## For addon authors
`Adapters.lua` describes the addons above. An addon can describe itself instead:

```lua
if DrangedAddons then
    DrangedAddons.Register({
        name = "MyAddon",                          -- the addon's folder name
        settings = {
            frame = "MyAddonConfig",               -- global name of the settings window, or a function returning it
            open = function() MyAddon.OpenConfig() end,   -- builds it when it doesn't exist yet
            crop = 34,                             -- px of the window's own title bar to cut off
        },
        actions = { { "Open window", function() MyAddon.Toggle() end } },
    })
end
```

`DrangedAddons.Open("MyAddon")` opens the hub on an addon's page.

## Development
- `tools/make_icon.py` builds `logo.tga`, `icon.tga` and `icon.ico` from `tools/penrose.png`.
- `tools/test/run.py` loads the addon against a mock of the WoW frame API and runs `smoke.lua` in four looks. It needs `lupa` (`pip install lupa`).
- `Theme.lua`, `Widgets.lua` and `Window.lua` are the shared Dranged UI kit, copied in unchanged.

Includes LibStub, CallbackHandler, LibDataBroker and LibDBIcon (see Libs).
