# Vapor

Vapor is a Roblox UI library focused on keeping the original Vapor visual identity while modernizing the backend for better stability, icon support, and public distribution.

## Highlights

- Original Vapor visual style preserved
- Self-contained single-file build
- Lucide icon atlas embedded locally
- Support for Lucide names, Roblox assets, and external image sources
- Fixed dropdown, input, clipping, and connection cleanup issues

## Loadstring

```lua
local Vapor = loadstring(game:HttpGet("https://raw.githubusercontent.com/noicer/vapor-lib/main/vapor.lua"))()
```

## Basic Example

```lua
local Vapor = loadstring(game:HttpGet("https://raw.githubusercontent.com/noicer/vapor-lib/main/vapor.lua"))()

local Window = Vapor:CreateWindow({
    Title = "Vapor",
    Subtitle = "Example",
    Icon = "sparkles",
    CollapseIcon = "panel-top-close",
    ToggleKey = Enum.KeyCode.RightControl,
})

local Main = Window:CreateTab({
    Title = "Main",
    Icon = "layout-dashboard",
})

Main:CreateButton({
    Name = "Notify",
    Callback = function()
        Vapor:Notify({
            Title = "Vapor",
            Content = "Library loaded successfully.",
            Icon = "rocket",
            Duration = 4,
        })
    end,
})
```

## Attribution

- Vapor backend/public release work by noicer
- Lucide integration approach inspired by Rayfield
- Icons provided by Lucide

See [NOTICE](./NOTICE) for attribution details.

## License

This project is licensed under Apache-2.0. See [LICENSE](./LICENSE).

## Notes

- This repository currently ships the release file as [`vapor.lua`](./vapor.lua)
