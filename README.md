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

```lua
local VaporLens = loadstring(game:HttpGet("https://raw.githubusercontent.com/noicer/vapor-lib/main/vapor.lua"))()

-- Theme Configuration (Optional)
VaporLens:SetTheme({
    Glow = Color3.fromRGB(0, 180, 255),
})

-- Window Creation
local Window = VaporLens:CreateWindow({
    Title = "VaporLens",
    Subtitle = "Neutral Interface — v1.1",
    Icon = "layers",
    ToggleKey = Enum.KeyCode.RightControl,
    Width = 480,
    Height = 380,
})

-- Tabs Creation
local TabMain = Window:CreateTab({ Title = "Elements", Icon = "component" })
local TabSettings = Window:CreateTab({ Title = "Advanced", Icon = "settings" })

-- ────────────────────────────────────────────────────────────
-- MAIN TAB ELEMENTS
-- ────────────────────────────────────────────────────────────

TabMain:CreateSection("Controls")

-- Toggle
local Toggle = TabMain:CreateToggle({
    Name = "Toggle",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(Value)
        print("Toggle changed to:", Value)
    end,
})

-- Slider
local Slider = TabMain:CreateSlider({
    Name = "Slider",
    Range = {0, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "Slider1",
    Callback = function(Value)
        print("Slider changed to:", Value)
    end,
})

-- Button
TabMain:CreateButton({
    Name = "Button",
    Icon = "check-circle",
    Callback = function()
        VaporLens:Notify({
            Title = "Notification",
            Content = "The button was successfully pressed!",
            Icon = "info",
            Duration = 3,
        })
    end,
})

TabMain:CreateSection("Selectors")

-- Dropdown
local Dropdown = TabMain:CreateDropdown({
    Name = "Dropdown",
    Options = {"Option 1", "Option 2", "Option 3", "Option 4"},
    CurrentOption = {"Option 1"},
    MultipleOptions = false,
    Flag = "Dropdown1",
    Callback = function(Option)
        print("Dropdown selected:", Option)
    end,
})

-- Player Dropdown
local PlayerDropdown = TabMain:CreatePlayerDropdown({
    Name = "Player Dropdown",
    ShowSelf = true,
    AvatarScale = 1.0,
    DisplayNameScale = 1.0,
    UsernameScale = 1.0,
    Callback = function(Player)
        if Player then
            print("Selected player:", Player.DisplayName)
        end
    end,
})

-- ────────────────────────────────────────────────────────────
-- SETTINGS TAB ELEMENTS
-- ────────────────────────────────────────────────────────────

TabSettings:CreateSection("Input & Text")

-- Input
local Input = TabSettings:CreateInput({
    Name = "Input",
    PlaceholderText = "Type something...",
    MaxLength = 20,
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        print("Input text:", Text)
    end,
})

-- Keybind
local Keybind = TabSettings:CreateKeybind({
    Name = "Keybind",
    CurrentKeybind = Enum.KeyCode.F,
    HoldToInteract = false,
    Flag = "Keybind1",
    Callback = function(Key)
        print("Keybind pressed:", Key)
    end,
})

TabSettings:CreateSection("Feedback")

-- Progress Bar
local ProgressBar = TabSettings:CreateProgressBar({
    Name = "Progress Bar",
    Value = 75,
    Max = 100,
    Suffix = "%",
    Color = Color3.fromRGB(0, 255, 150),
    Flag = "Progress1",
})

-- Label
local Label = TabSettings:CreateLabel("Label (Simple Text)", "info", Color3.fromRGB(200, 200, 200))

-- Paragraph
TabSettings:CreateParagraph({
    Title = "Paragraph",
    Content = "This is a paragraph element useful for long descriptions or usage instructions within your interface.",
})

-- 5. API Manipulation Example
task.delay(5, function()
    ProgressBar:Set(100)
    Label:Set("Label Updated via API", Color3.fromRGB(0, 180, 255))
end)
```

## Attribution

- Vapor backend/public release work by noicer
- Lucide integration by Rayfield
- Icons provided by Lucide

See [NOTICE](./NOTICE) for attribution details.

## License

This project is licensed under Apache-2.0. See [LICENSE](./LICENSE).

## Notes

- This repository currently ships the release file as [`vapor.lua`](./vapor.lua)
