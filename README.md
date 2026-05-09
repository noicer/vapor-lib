# VaporLens

VaporLens is a vibesloppy-coded Roblox UI library optimized for performance and accessibility.

## Highlights

- **Mobile Adaptive**: Auto-clamping window size based on Viewport and native touch feedback.
- **Performance**: Native `UIListLayout` integration and aggressive tween/connection cleanup.
- **Lucide Icons**: Full Lucide icon support.
- **Anti-Leak**: Global registry protection ensures zero memory leakage on re-execution.

## Loadstring

Copy this line to get started:

```lua
local VaporLens = loadstring(game:HttpGet("https://raw.githubusercontent.com/noicer/vapor-lib/main/vapor.lua"))()
```

## Complete Usage Example (v1.3.1)

```lua
local VaporLens = loadstring(game:HttpGet("https://raw.githubusercontent.com/noicer/vapor-lib/main/vapor.lua"))()

-- 1. Configuration (Optional)
-- Full theme keys reference
--[[
VaporLens:SetTheme({   
    -- Window
    Glass = Color3.fromRGB(15, 15, 17),        -- Window background tint
    GlassTransp = 0.25,                        -- Window background transparency
    Border = Color3.fromRGB(45, 45, 50),       -- Window + element border color
    BorderTransp = 0.50,                       -- Window border transparency
    
    -- Accent
    Glow = Color3.fromRGB(0, 180, 255),        -- Accent / active color
    
    -- Text
    Primary = Color3.fromRGB(240, 240, 240),   -- Primary text color
    Secondary = Color3.fromRGB(160, 160, 165), -- Secondary text color
    SecTransp = 0,                             -- Secondary text transparency
    
    -- Elements
    ElemBg = Color3.fromRGB(30, 30, 35),       -- Element row background tint
    ElemTransp = 0.40,                         -- Element row transparency
    ElemHoverTransp = 0.20,                    -- Element hover transparency
    ElemBdrTransp = 0.70,                      -- Element border transparency
    
    -- Controls
    ToggleOff = Color3.fromRGB(40, 40, 45),    -- Toggle track color when off
    SliderTrack = Color3.fromRGB(20, 20, 25),  -- Slider unfilled track color
    InputBg = Color3.fromRGB(10, 10, 12),      -- Input field background
    
    -- Section Label
    SectionTransp = 0.30,                      -- Section label transparency
    
    -- Notification
    NotifBg = Color3.fromRGB(5, 5, 8),         -- Notification background
})
]]

-- 2. Window Creation (Adaptive & Mobile Ready)
local Window = VaporLens:CreateWindow({
    Title = "VaporLens",
    Subtitle = "User Interface — v1.3.1",
    Icon = "layers", -- Lucide icon name
    ToggleKey = Enum.KeyCode.RightControl,
    Width = 500,
    Height = 400,
})

-- 3. Tabs Creation
local TabMain = Window:CreateTab("Elements", "component")
local TabSelectors = Window:CreateTab("Selectors", "list")
local TabPlayers = Window:CreateTab("Players", "users")
local TabMisc = Window:CreateTab("Misc", "settings")

-- ────────────────────────────────────────────────────────────
-- MAIN ELEMENTS
-- ────────────────────────────────────────────────────────────

TabMain:CreateSection("Basic Controls")

-- Toggle
local Toggle = TabMain:CreateToggle({
    Name = "Active Feature",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(Value)
        print("Toggle changed to:", Value)
    end,
})

-- Slider
local Slider = TabMain:CreateSlider({
    Name = "Precision Slider",
    Range = {0, 10},
    Increment = 0.1,
    Suffix = " units",
    CurrentValue = 5,
    Flag = "Slider1",
    Callback = function(Value)
        print("Slider value:", Value)
    end,
})

-- Button
TabMain:CreateButton({
    Name = "Execute Notification",
    Icon = "info",
    Callback = function()
        VaporLens:Notify({
            Title = "Notification",
            Content = "Action performed successfully!",
            Icon = "check-circle",
            Duration = 3,
        })
    end,
})

-- ────────────────────────────────────────────────────────────
-- SELECTORS TAB
-- ────────────────────────────────────────────────────────────

TabSelectors:CreateSection("Dropdown Types")

-- Single-Selection Dropdown
TabSelectors:CreateDropdown({
    Name = "Mode Selector",
    Options = {"Legit", "Blatant", "Rage"},
    CurrentOption = "Legit",
    Flag = "DropdownSingle",
    Callback = function(Option)
        print("Mode selected:", Option)
    end,
})

-- Multi-Selection Dropdown
TabSelectors:CreateDropdown({
    Name = "ESP Filters",
    Options = {"Boxes", "Tracers", "Names", "Health"},
    MultipleOptions = true,
    CurrentOption = {"Boxes", "Names"},
    Flag = "DropdownMulti",
    Callback = function(SelectedTable)
        print("Active filters:", table.concat(SelectedTable, ", "))
    end,
})

-- Player Dropdown (Auto-updates with server churn)
TabPlayers:CreatePlayerDropdown({
    Name = "Target Player",
    ShowSelf = true,
    Callback = function(Player)
        if Player then
            print("Targeting:", Player.DisplayName)
        end
    end,
})

-- ────────────────────────────────────────────────────────────
-- UTILITY & FEEDBACK
-- ────────────────────────────────────────────────────────────

-- Progress Bar
local ProgressBar = TabMisc:CreateProgressBar({
    Name = "Download Status",
    Value = 45,
    Max = 100,
    Suffix = "%",
    Color = Color3.fromRGB(0, 255, 150)
})

-- Label
local Label = TabMisc:CreateLabel("Critical system warning!", "alert-triangle", Color3.fromRGB(255, 80, 80))

-- Paragraph
TabMisc:CreateParagraph({
    Title = "Developer Note",
    Content = "VaporLens automatically handles GUI protection and input blocking when invisible."
})

-- Keybind
TabMisc:CreateKeybind({
    Name = "Self-Destruct",
    CurrentKeybind = Enum.KeyCode.F,
    HoldToInteract = false,
    Flag = "Keybind1",
    Callback = function(Key)
        print("Keybind pressed:", Key)
    end,
})

-- ────────────────────────────────────────────────────────────
-- INTERFACE CONTROLS & METHODS
-- ────────────────────────────────────────────────────────────

-- Floating Action Button (FAB)
local FAB = Window:CreateFloatingButton({
    Icon = "ghost",
    Text = "Vapor Menu",
    SnapToEdges = true -- Mobile-friendly snapping
})

-- Set a toggle keybind within a tab
Window:CreateToggleKeybind(TabMisc, {
    Name = "Toggle UI Key",
    CurrentKeybind = Enum.KeyCode.RightControl
})

-- API Manipulation Example
task.delay(5, function()
    Slider:Set(8.5)
    Toggle:Set(true)
    ProgressBar:Set(100)
    Label:Set("System Stabilized", Color3.fromRGB(0, 255, 120))
end)
```

## Attribution

- Backend/Release by noicer
- Lucide integration by Rayfield
- Icons provided by Lucide

## License

This project is licensed under Apache-2.0. See [LICENSE](./LICENSE).
