# Vapor

Vapor is a vibecoded Roblox UI library lol

## Highlights

- Support for Lucide icons, Roblox assets, and external image sources
- Fixed dropdown, input, clipping, and connection cleanup issues

## Loadstring

Copy this exact line:

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

- Lucide integration by Rayfield
- Icons provided by Lucide

See [NOTICE](./NOTICE) for attribution details.

## License

This project is licensed under Apache-2.0. See [LICENSE](./LICENSE).

## Notes

- This repository currently ships the release file as [`vapor.lua`](./vapor.lua)
