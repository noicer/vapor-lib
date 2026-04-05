--[[

              VAPOR LENS  UI LIBRARY  v1.1                    
                                                              
  Aesthetic: 1:1 with original VaporLens v1.6 design.        
  Window is fixed-size. Content area scrolls internally.      
  Horizontal tab nav. Lucide icon support.                    
                                                              
   QUICK START   
                                                              
  local VL = loadstring(game:HttpGet("RAW_URL"))()            
                                                              
  local Win = VL:CreateWindow({                               
      Title     = "My Script",                                
      Subtitle  = "v1.0",                                     
      Icon      = "zap",       -- Lucide icon name (string)   
      ToggleKey = Enum.KeyCode.RightControl,                  
      Width     = 480,         -- optional, default 480       
      Height    = 380,         -- optional, default 380       
  })                                                          
                                                              
  local Tab = Win:CreateTab("Dashboard")                      
  -- or: Win:CreateTab("Combat", "sword")  (with icon)        
                                                              
  Tab:CreateSection("Aimbot")                                 
                                                              
  local tog = Tab:CreateToggle({                              
      Name = "Enable Aimbot", CurrentValue = false,           
      Flag = "AimbotOn",                                      
      Callback = function(v) print(v) end,                    
  })                                                          
  tog:Set(true)                                               
                                                              
  local sl = Tab:CreateSlider({                               
      Name = "FOV", Range = {1,360}, Increment = 1,           
      Suffix = "", CurrentValue = 90,                        
      Callback = function(v) print(v) end,                    
  })                                                          
                                                              
  Tab:CreateButton({ Name = "Teleport",                       
      Callback = function() end })                            
                                                              
  Tab:CreateDropdown({                                        
      Name = "Target", Options = {"Head","Torso"},            
      CurrentOption = {"Head"}, MultipleOptions = false,      
      Callback = function(opt) print(opt) end,                
  })                                                          
                                                              
  Tab:CreateInput({                                           
      Name = "Player", PlaceholderText = "Name...",           
      Callback = function(t) print(t) end,                    
  })                                                          
                                                              
  Tab:CreateKeybind({                                         
      Name = "Toggle Key", CurrentKeybind = Enum.KeyCode.F,  
      Callback = function(k) print(k) end,                    
  })                                                          
                                                              
  Tab:CreateLabel("Heads-up text", "info")                    
  Tab:CreateParagraph({ Title = "Note", Content = "..." })    
                                                              
  VL:Notify({ Title="Hi", Content="Ready!", Icon="check" })   
  VL:Destroy()                                                

]]

-- 
--  SERVICES
-- 
local UIS  = game:GetService("UserInputService")
local TS   = game:GetService("TweenService")
local RS   = game:GetService("RunService")
local Plrs = game:GetService("Players")

local lp   = Plrs.LocalPlayer
local pGui = lp:WaitForChild("PlayerGui")

-- 
--  LUCIDE ICONS  (same atlas as Rayfield  Latte Softworks)
--  Load is async. applyIcon() queues requests made before load.
-- 
local Icons     = nil
local iconReady = false
local iconQueue = {}   -- { imageLabel, source }
local ICON_ATLAS_URL = "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua"
local DEFAULT_DROPDOWN_ICON = "chevron-down"
local DEFAULT_COLLAPSE_ICON = "arrow-down"
local atlasLoaderStarted = false
local flushIconQueue
local function trim(str)
    return string.match(tostring(str), "^%s*(.-)%s*$")
end

local function clearImageRect(img)
    img.ImageRectSize = Vector2.new(0, 0)
    img.ImageRectOffset = Vector2.new(0, 0)
end

local function applyAtlasIcon(img, iconName)
    local atlas = Icons and Icons["48px"]
    if not atlas then
        return false
    end

    local entry = atlas[iconName]
    if not entry then
        return false
    end

    img.Image = "rbxassetid://" .. entry[1]
    img.ImageRectSize = Vector2.new(entry[2][1], entry[2][2])
    img.ImageRectOffset = Vector2.new(entry[3][1], entry[3][2])
    return true
end

local function normalizeAssetUri(source)
    if source == nil then
        return nil
    end

    if type(source) == "number" then
        return "rbxassetid://" .. source
    end

    if type(source) ~= "string" then
        return nil
    end

    local value = trim(source)
    if value == "" then
        return nil
    end

    if value:match("^rbxassetid://") or value:match("^rbxthumb://") or value:match("^https?://") then
        return value
    end

    if value:match("^%d+$") then
        return "rbxassetid://" .. value
    end

    return nil
end

local function applyResolvedIcon(img, source)
    if not (img and img.Parent and source ~= nil) then
        return
    end

    if type(source) == "table" then
        local image = source.Image or source.Uri or source.AssetId or source.Id
        local assetUri = normalizeAssetUri(image)
        if assetUri then
            img.Image = assetUri
            clearImageRect(img)

            local rectSize = source.ImageRectSize
            local rectOffset = source.ImageRectOffset
            if typeof(rectSize) == "Vector2" then
                img.ImageRectSize = rectSize
            elseif type(rectSize) == "table" then
                img.ImageRectSize = Vector2.new(rectSize[1] or 0, rectSize[2] or 0)
            end

            if typeof(rectOffset) == "Vector2" then
                img.ImageRectOffset = rectOffset
            elseif type(rectOffset) == "table" then
                img.ImageRectOffset = Vector2.new(rectOffset[1] or 0, rectOffset[2] or 0)
            end
            return
        end

        source = source.Name or source.Icon or source.Lucide
    end

    local assetUri = normalizeAssetUri(source)
    if assetUri then
        img.Image = assetUri
        clearImageRect(img)
        return
    end

    local iconName = string.lower(trim(source))
    if iconReady then
        if not applyAtlasIcon(img, iconName) then
            warn("VaporLens | Unknown icon: " .. iconName)
        end
    else
        if not atlasLoaderStarted then
            atlasLoaderStarted = true
            task.spawn(function()
                local ok, res = pcall(function()
                    return loadstring(game:HttpGet(ICON_ATLAS_URL))()
                end)
                if ok and type(res) == "table" then
                    Icons = res
                    iconReady = true
                    flushIconQueue()
                else
                    warn("VaporLens | Lucide icons failed: " .. tostring(res))
                end
            end)
        end
        table.insert(iconQueue, {img, iconName})
    end
end
flushIconQueue = function()
    for _, entry in ipairs(iconQueue) do
        local img, source = entry[1], entry[2]
        if img and img.Parent then
            applyResolvedIcon(img, source)
        end
    end
    iconQueue = {}
end

local function applyIcon(img, source)
    if not source or source == "" then return end
    applyResolvedIcon(img, source)
end

-- 
--  THEME   maps 1:1 to the original VaporLens v1.6 values
-- 
local T = {
    -- Window
    Glass          = Color3.fromRGB(255, 255, 255),
    GlassTransp    = 0.96,
    Border         = Color3.fromRGB(255, 255, 255),
    BorderTransp   = 0.90,
    -- Accent
    Glow           = Color3.fromRGB(0, 200, 255),
    -- Text
    Primary        = Color3.fromRGB(255, 255, 255),
    Secondary      = Color3.fromRGB(255, 255, 255),
    SecTransp      = 0.45,
    -- Elements
    ElemBg         = Color3.fromRGB(255, 255, 255),
    ElemTransp     = 0.98,
    ElemHoverTransp= 0.95,
    ElemBdrTransp  = 0.90,
    -- Controls
    ToggleOff      = Color3.fromRGB(26, 26, 28),
    SliderTrack    = Color3.fromRGB(28, 28, 36),
    InputBg        = Color3.fromRGB(14, 14, 20),
    -- Section label
    SectionTransp  = 0.55,
    -- Notification
    NotifBg        = Color3.fromRGB(8, 8, 14),
}

-- 
--  FONTS
-- 
local FB = Enum.Font.GothamBold
local FM = Enum.Font.GothamMedium   -- paragraph body only

-- 
--  SIZING  same proportions as original v1.6
-- 
local HDR_H    = 82     -- header (matches original)
local NAV_H    = 32     -- nav bar
local PAD      = 25     -- horizontal padding
local ELEM_H   = 52     -- standard row height
local ELEM_TALL = 72    -- slider row height
local EDGE_SAFE = 6

-- Notification geometry
local NF = { W = 290, H = 48, Gap = 9, Right = 20, Bot = 20 }

-- 
--  HELPERS
-- 
local function qt(obj, goal, dur, style, dir)
    local tw = TS:Create(obj,
        TweenInfo.new(dur or 0.28,
            style or Enum.EasingStyle.Quart,
            dir   or Enum.EasingDirection.Out),
        goal)
    tw:Play()
    return tw
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, col, tr, th)
    local s = Instance.new("UIStroke")
    s.Color = col or T.Border
    s.Transparency = tr or 0
    s.Thickness = th or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function pad(p, l, r, t, b)
    local u = Instance.new("UIPadding")
    u.PaddingLeft   = UDim.new(0, l or 0)
    u.PaddingRight  = UDim.new(0, r or 0)
    u.PaddingTop    = UDim.new(0, t or 0)
    u.PaddingBottom = UDim.new(0, b or 0)
    u.Parent = p
    return u
end

local function vList(p, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, gap or 0)
    l.Parent        = p
    return l
end

local function hList(p, gap, valign)
    local l = Instance.new("UIListLayout")
    l.FillDirection     = Enum.FillDirection.Horizontal
    l.SortOrder         = Enum.SortOrder.LayoutOrder
    l.Padding           = UDim.new(0, gap or 0)
    l.VerticalAlignment = valign or Enum.VerticalAlignment.Center
    l.Parent            = p
    return l
end

local function icoLabel(parent, sz, col)
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size        = UDim2.new(0, sz or 18, 0, sz or 18)
    img.ImageColor3 = col or T.Primary
    img.Parent      = parent
    return img
end

local function safeMount(sg)
    local ok = pcall(function()
        if gethui then sg.Parent = gethui(); return end
        if syn and syn.protect_gui then
            syn.protect_gui(sg)
            sg.Parent = game:GetService("CoreGui"); return
        end
        local cg = game:GetService("CoreGui")
        if not RS:IsStudio() and cg:FindFirstChild("RobloxGui") then
            sg.Parent = cg.RobloxGui; return
        end
        sg.Parent = pGui
    end)
    if not ok then sg.Parent = pGui end
end

local function create(className, props)
    local instance = Instance.new(className)
    for key, value in pairs(props or {}) do
        if key == "Parent" then
            instance.Parent = value
        else
            instance[key] = value
        end
    end
    return instance
end

local function captureInput(guiObject)
    pcall(function()
        guiObject.Active = true
    end)
    return guiObject
end

local function createIconButton(parent, props)
    local button = create("TextButton", {
        Name = props.Name or "IconButton",
        Size = props.Size or UDim2.new(0, 32, 0, 32),
        Position = props.Position or UDim2.new(),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = parent,
    })

    local icon = icoLabel(button, props.IconSize or 16, props.Color or T.Glow)
    icon.Name = "Icon"
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    if props.Icon then
        applyIcon(icon, props.Icon)
    end

    return button, icon
end

local function createDropdownShell(page, height)
    local shell = create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = T.ElemBg,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = page,
    })
    captureInput(shell)
    corner(shell, 12)
    local shellStroke = stroke(shell, T.Border, 1, 1)
    pad(shell, 16, 16, 0, 0)
    return shell, shellStroke
end

-- 
--  SHARED ROW BUILDER
-- 
local function baseRow(page, h)
    h = h or ELEM_H
    local Row = Instance.new("Frame")
    Row.Size                   = UDim2.new(1, 0, 0, h)
    Row.BackgroundColor3       = T.ElemBg
    Row.BackgroundTransparency = 1
    Row.Parent                 = page
    captureInput(Row)
    corner(Row, 12)
    local rs = stroke(Row, T.Border, 1, 1)
    pad(Row, 16, 16, 0, 0)

    Row.MouseEnter:Connect(function()
        qt(Row, {BackgroundTransparency = T.ElemHoverTransp}, 0.18)
        qt(rs,  {Transparency = 0.78}, 0.18)
    end)
    Row.MouseLeave:Connect(function()
        qt(Row, {BackgroundTransparency = T.ElemTransp}, 0.18)
        qt(rs,  {Transparency = T.ElemBdrTransp}, 0.18)
    end)

    qt(Row, {BackgroundTransparency = T.ElemTransp}, 0.35)
    qt(rs,  {Transparency = T.ElemBdrTransp}, 0.35)
    return Row, rs
end

local function rowLabel(row, text, wScale)
    local l = Instance.new("TextLabel")
    l.Size               = UDim2.new(wScale or 0.55, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text               = text or ""
    l.TextColor3         = T.Primary
    l.Font               = FB
    l.TextSize           = 14
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = row
    return l
end

-- 
--  LIBRARY
-- 
local VaporLens = { Flags = {}, Version = "1.1" }

local _gui        = nil
local _notifStack = {}
local _destroyed  = false
local _dragConn   = nil
local _connections = {}

local function trackConnection(conn)
    if conn then
        table.insert(_connections, conn)
    end
    return conn
end

local function disconnectTrackedConnections()
    for i = #_connections, 1, -1 do
        local conn = _connections[i]
        if conn then
            pcall(function()
                conn:Disconnect()
            end)
        end
        _connections[i] = nil
    end
    _dragConn = nil
end

local function runCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(function()
            callback(table.unpack(args, 1, args.n))
        end)
        if not ok then
            warn("VaporLens | Callback error: " .. tostring(err))
        end
    end)
end

-- 
--  VaporLens:SetTheme(custom)
--
--  Merges any keys from `custom` into the theme table T.
--  Must be called BEFORE :CreateWindow() so every element
--  picks up the new values at build time.
--
--  Available keys (all optional  only override what you want):
--
--    Glass          Color3   window background tint
--    GlassTransp    number   window background transparency  (01)
--    Border         Color3   window + element border colour
--    BorderTransp   number   window border transparency      (01)
--    Glow           Color3   accent / active colour
--    Primary        Color3   primary text colour
--    Secondary      Color3   secondary text colour
--    SecTransp      number   secondary text transparency     (01)
--    ElemBg         Color3   element row background tint
--    ElemTransp     number   element row transparency        (01)
--    ElemHoverTransp number  element hover transparency      (01)
--    ElemBdrTransp  number   element border transparency     (01)
--    ToggleOff      Color3   toggle track colour when off
--    SliderTrack    Color3   slider unfilled track colour
--    InputBg        Color3   input field background
--    SectionTransp  number   section label transparency      (01)
--    NotifBg        Color3   notification background
-- 
function VaporLens:SetTheme(custom)
    assert(type(custom) == "table", "VaporLens:SetTheme() expects a table")
    for k, v in pairs(custom) do
        if T[k] ~= nil then
            T[k] = v
        else
            warn("VaporLens:SetTheme() | Unknown key: " .. tostring(k))
        end
    end
end

function VaporLens:SetIconAtlas(atlas)
    assert(type(atlas) == "table", "VaporLens:SetIconAtlas() expects a table")
    Icons = atlas
    iconReady = true
    flushIconQueue()
end

-- 
--  NOTIFICATIONS
-- 
local function _notifPos(i)
    return UDim2.new(1, -NF.Right, 1, -(NF.Bot + (i-1)*(NF.H+NF.Gap)))
end

local function _reposNotifs()
    for i, n in ipairs(_notifStack) do
        if n and n.Parent then qt(n, {Position = _notifPos(i)}, 0.28) end
    end
end

function VaporLens:Notify(data)
    if _destroyed then return end
    data = data or {}
    local dur    = data.Duration or 4
    local parent = _gui or pGui
    local idx    = #_notifStack + 1

    local N = Instance.new("Frame")
    N.Size                   = UDim2.new(0, NF.W, 0, NF.H)
    N.AnchorPoint            = Vector2.new(1, 1)
    N.Position               = UDim2.new(1, NF.Right+24, 1, -(NF.Bot+(idx-1)*(NF.H+NF.Gap)))
    N.BackgroundColor3       = T.NotifBg
    N.BackgroundTransparency = 0.08
    N.Parent                 = parent
    captureInput(N)
    corner(N, 10)
    local nStr = stroke(N, T.Glow, 0.55, 1)

    local bar = Instance.new("Frame")
    bar.Size             = UDim2.new(0, 3, 0.5, 0)
    bar.Position         = UDim2.new(0, 12, 0.25, 0)
    bar.BackgroundColor3 = T.Glow
    bar.BorderSizePixel  = 0
    bar.Parent           = N
    corner(bar, 2)

    local hasIco = data.Icon ~= nil and data.Icon ~= ""
    local ico    = icoLabel(N, 18, T.Glow)
    ico.Position = UDim2.new(0, 24, 0.5, -9)
    if hasIco then applyIcon(ico, data.Icon) end

    local tx = hasIco and 50 or 26

    local nTit = Instance.new("TextLabel")
    nTit.Size               = UDim2.new(1, -(tx+12), 0, 15)
    nTit.Position           = UDim2.new(0, tx, 0.5, -16)
    nTit.BackgroundTransparency = 1
    nTit.Text               = data.Title   or ""
    nTit.TextColor3         = T.Primary
    nTit.Font               = FB
    nTit.TextSize           = 12
    nTit.TextXAlignment     = Enum.TextXAlignment.Left
    nTit.Parent             = N

    local nSub = Instance.new("TextLabel")
    nSub.Size               = UDim2.new(1, -(tx+12), 0, 13)
    nSub.Position           = UDim2.new(0, tx, 0.5, 2)
    nSub.BackgroundTransparency = 1
    nSub.Text               = data.Content or ""
    nSub.TextColor3         = T.Secondary
    nSub.TextTransparency   = T.SecTransp
    nSub.Font               = FB
    nSub.TextSize           = 11
    nSub.TextXAlignment     = Enum.TextXAlignment.Left
    nSub.TextWrapped        = true
    nSub.Parent             = N

    table.insert(_notifStack, N)
    qt(N, {Position = _notifPos(idx)}, 0.44, Enum.EasingStyle.Quart)

    task.delay(dur, function()
        if not N.Parent then return end
        local exitPos = UDim2.new(1, NF.Right+24, N.Position.Y.Scale, N.Position.Y.Offset)
        qt(N,    {BackgroundTransparency = 1, Position = exitPos}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        qt(nStr, {Transparency = 1},      0.36)
        qt(nTit, {TextTransparency = 1},  0.36)
        qt(nSub, {TextTransparency = 1},  0.36)
        qt(bar,  {BackgroundTransparency = 1}, 0.36)
        qt(ico,  {ImageTransparency = 1}, 0.36)
        task.delay(0.38, function()
            local i = table.find(_notifStack, N)
            if i then
                table.remove(_notifStack, i)
                if N.Parent then N:Destroy() end
                _reposNotifs()
            end
        end)
    end)
end

-- 
--  DESTROY
-- 
function VaporLens:Destroy()
    _destroyed = true
    disconnectTrackedConnections()
    if _gui and _gui.Parent then _gui:Destroy() end
    _gui = nil
    for _, n in ipairs(_notifStack) do
        if n and n.Parent then n:Destroy() end
    end
    _notifStack = {}
    self.Flags = {}
end

-- 
--  CREATE WINDOW
-- 
function VaporLens:CreateWindow(cfg)
    cfg = cfg or {}
    if _destroyed then _destroyed = false end
    if _gui or #_connections > 0 or #_notifStack > 0 then
        self:Destroy()
        _destroyed = false
    end

    local WIN_W     = cfg.Width     or 480
    local WIN_H     = cfg.Height    or 380
    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightControl

    --  ScreenGui 
    local sg = Instance.new("ScreenGui")
    sg.Name           = "VaporLensUI"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder   = 2147483647
    _gui = sg
    safeMount(sg)

    pcall(function()
        for _, g in ipairs(sg.Parent:GetChildren()) do
            if g.Name == sg.Name and g ~= sg then g.Enabled = false end
        end
    end)

    --  Main container  FIXED SIZE 
    local Main = Instance.new("Frame")
    Main.Name                   = "Main"
    Main.Size                   = UDim2.new(0, WIN_W, 0, WIN_H)
    Main.Position               = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
    Main.BackgroundColor3       = T.Glass
    Main.BackgroundTransparency = T.GlassTransp
    Main.ClipsDescendants       = true
    Main.Parent                 = sg
    captureInput(Main)
    corner(Main, 24)
    stroke(Main, T.Border, T.BorderTransp, 1)

    local GlassBase = Instance.new("Frame")
    GlassBase.Name                   = "GlassBase"
    GlassBase.Size                   = UDim2.new(1, 0, 1, 0)
    GlassBase.BackgroundColor3       = Color3.fromRGB(17, 0, 28)
    GlassBase.BackgroundTransparency = 0.14
    GlassBase.BorderSizePixel        = 0
    GlassBase.ZIndex                 = 0
    GlassBase.Parent                 = Main
    corner(GlassBase, 24)

    local GlassGradient = Instance.new("UIGradient")
    GlassGradient.Rotation = 125
    GlassGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(17, 0, 28)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(34, 1, 53)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(58, 2, 91)),
    })
    GlassGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.08),
        NumberSequenceKeypoint.new(0.50, 0.22),
        NumberSequenceKeypoint.new(1.00, 0.04),
    })
    GlassGradient.Parent = GlassBase

    local GlassSheen = Instance.new("Frame")
    GlassSheen.Name                   = "GlassSheen"
    GlassSheen.Size                   = UDim2.new(1, -2, 0.42, 0)
    GlassSheen.Position               = UDim2.new(0, 1, 0, 1)
    GlassSheen.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    GlassSheen.BackgroundTransparency = 0.93
    GlassSheen.BorderSizePixel        = 0
    GlassSheen.ZIndex                 = 0
    GlassSheen.Parent                 = Main
    corner(GlassSheen, 22)

    local SheenGradient = Instance.new("UIGradient")
    SheenGradient.Rotation = 90
    SheenGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.00),
        NumberSequenceKeypoint.new(0.35, 0.72),
        NumberSequenceKeypoint.new(1.00, 1.00),
    })
    SheenGradient.Parent = GlassSheen

    local InnerGlassStroke = Instance.new("UIStroke")
    InnerGlassStroke.Color = Color3.fromRGB(145, 86, 191)
    InnerGlassStroke.Transparency = 0.78
    InnerGlassStroke.Thickness = 1
    InnerGlassStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    InnerGlassStroke.Parent = GlassBase

    local InnerClip = Instance.new("Frame")
    InnerClip.Name                   = "InnerClip"
    InnerClip.Size                   = UDim2.new(1, -(EDGE_SAFE * 2), 1, -(EDGE_SAFE * 2))
    InnerClip.Position               = UDim2.new(0, EDGE_SAFE, 0, EDGE_SAFE)
    InnerClip.BackgroundTransparency = 1
    InnerClip.BorderSizePixel        = 0
    InnerClip.ClipsDescendants       = true
    InnerClip.ZIndex                 = 1
    InnerClip.Parent                 = Main
    captureInput(InnerClip)
    corner(InnerClip, 18)

    --  HEADER (82px  identical to original) 
    local Header = Instance.new("Frame")
    Header.Name               = "Header"
    Header.Size               = UDim2.new(1, 0, 0, HDR_H)
    Header.BackgroundTransparency = 1
    Header.Parent             = InnerClip
    captureInput(Header)
    pad(Header, PAD, PAD, PAD, PAD)

    local hGrad = Instance.new("UIGradient")
    hGrad.Rotation     = 90
    hGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(1, 1),
    })
    hGrad.Parent = Header

    -- Icon box  absolute left (3232, matches original)
    local IcoBox = Instance.new("Frame")
    IcoBox.Size               = UDim2.new(0, 32, 0, 32)
    IcoBox.Position           = UDim2.new(0, 0, 0.5, -16)
    IcoBox.BackgroundColor3   = T.Glow
    IcoBox.BackgroundTransparency = 0.50
    IcoBox.Parent             = Header
    corner(IcoBox, 8)
    local icoGlow = Instance.new("UIStroke")
    icoGlow.Color       = T.Glow
    icoGlow.Thickness   = 3
    icoGlow.Transparency = 0.6
    icoGlow.Parent      = IcoBox

    local IcoImg = icoLabel(IcoBox, 18, Color3.new(1,1,1))
    IcoImg.Position = UDim2.new(0.5, -9, 0.5, -9)
    applyIcon(IcoImg, cfg.Icon or "droplets")

    -- Collapse button  absolute right
    local ColBtn, ColIcon = createIconButton(Header, {
        Name = "CollapseButton",
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -32, 0.5, -16),
        Icon = cfg.CollapseIcon or DEFAULT_COLLAPSE_ICON,
        IconSize = 16,
        Color = T.Glow,
    })

    -- Title / subtitle  fills between icon and collapse btn
    local TxtBlk = Instance.new("Frame")
    TxtBlk.Size               = UDim2.new(1, -(32+15+32+10), 1, 0)
    TxtBlk.Position           = UDim2.new(0, 32+15, 0, 0)
    TxtBlk.BackgroundTransparency = 1
    TxtBlk.Parent             = Header

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size               = UDim2.new(1, 0, 0, 18)
    TitleLbl.Position           = UDim2.new(0, 0, 0.5, -18)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text               = string.upper(cfg.Title or "VAPOR LENS")
    TitleLbl.TextColor3         = T.Primary
    TitleLbl.Font               = FB
    TitleLbl.TextSize           = 16
    TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
    TitleLbl.Parent             = TxtBlk

    local SubLbl = Instance.new("TextLabel")
    SubLbl.Size               = UDim2.new(1, 0, 0, 12)
    SubLbl.Position           = UDim2.new(0, 0, 0.5, 5)
    SubLbl.BackgroundTransparency = 1
    SubLbl.Text               = cfg.Subtitle or ("SYSTEM OVERLAY v" .. VaporLens.Version)
    SubLbl.TextColor3         = T.Secondary
    SubLbl.TextTransparency   = T.SecTransp
    SubLbl.Font               = FB
    SubLbl.TextSize           = 11
    SubLbl.TextXAlignment     = Enum.TextXAlignment.Left
    SubLbl.Parent             = TxtBlk

    --  NAV BAR (32px, horizontal tabs, matches original) 
    local Nav = Instance.new("Frame")
    Nav.Size              = UDim2.new(1, 0, 0, NAV_H)
    Nav.Position          = UDim2.new(0, 0, 0, HDR_H)
    Nav.BackgroundTransparency = 1
    Nav.Parent            = InnerClip
    captureInput(Nav)
    pad(Nav, PAD, PAD, 0, 0)
    hList(Nav, 20, Enum.VerticalAlignment.Center)

    --  SCROLLABLE CONTENT 
    --  Fixed height = WIN_H - header - nav.
    --  Elements scroll inside; scrollbar appears only on overflow.
    local CONTENT_Y = HDR_H + NAV_H
    local CONTENT_H = WIN_H - CONTENT_Y

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size               = UDim2.new(1, 0, 0, CONTENT_H)
    ContentFrame.Position           = UDim2.new(0, 0, 0, CONTENT_Y)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ClipsDescendants   = true
    ContentFrame.Parent             = InnerClip
    captureInput(ContentFrame)

    --  TAB STATE 
    local _pages   = {}
    local _navBtns = {}
    local _activeId = nil

    local function activateTab(id)
        _activeId = id
        for tid, page in pairs(_pages) do
            page.Visible = (tid == id)
        end
        for tid, btn in pairs(_navBtns) do
            local on = (tid == id)
            local ul = btn:FindFirstChild("Underline")
            qt(btn, {
                TextColor3       = on and T.Primary or T.Secondary,
                TextTransparency = on and 0 or T.SecTransp,
            }, 0.28)
            if ul then ul.Visible = on end
        end
    end

    --  DRAG 
    local drag = {on = false, inp = nil, start = nil, startPos = nil}

    Header.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        drag.on       = true
        drag.start    = inp.Position
        drag.startPos = Main.Position
    end)
    trackConnection(UIS.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            drag.inp = inp
        end
    end))
    trackConnection(UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            drag.on = false
        end
    end))
    _dragConn = trackConnection(RS.RenderStepped:Connect(function()
        if not (drag.on and drag.inp and drag.start) then return end
        local d = drag.inp.Position - drag.start
        Main.Position = UDim2.new(
            drag.startPos.X.Scale, drag.startPos.X.Offset + d.X,
            drag.startPos.Y.Scale, drag.startPos.Y.Offset + d.Y
        )
    end))

    --  COLLAPSE 
    local _collapsed = false
    ColBtn.MouseButton1Click:Connect(function()
        _collapsed = not _collapsed
        if _collapsed then
            Main:SetAttribute("ExpandedY", WIN_H)
            qt(Main,   {Size = UDim2.new(0, WIN_W, 0, HDR_H)}, 0.5, Enum.EasingStyle.Exponential)
            qt(ColIcon, {Rotation = -90}, 0.4, Enum.EasingStyle.Back)
        else
            local tY = Main:GetAttribute("ExpandedY") or WIN_H
            qt(Main,   {Size = UDim2.new(0, WIN_W, 0, tY)}, 0.5, Enum.EasingStyle.Exponential)
            qt(ColIcon, {Rotation = 0},  0.4, Enum.EasingStyle.Back)
        end
    end)

    --  VISIBILITY KEYBIND 
    local _visible = true
    trackConnection(UIS.InputBegan:Connect(function(inp, gpe)
        if gpe or _destroyed then return end
        if inp.KeyCode == toggleKey then
            _visible     = not _visible
            Main.Visible = _visible
            if _visible then
                VaporLens:Notify({
                    Title    = cfg.Title or "Vapor Lens",
                    Content  = "Interface restored.",
                    Icon     = "monitor",
                    Duration = 3,
                })
            end
        end
    end))

    --  ENTRANCE ANIMATION 
    Main.BackgroundTransparency = 1
    GlassBase.BackgroundTransparency = 1
    GlassSheen.BackgroundTransparency = 1
    InnerGlassStroke.Transparency = 1
    Main.Size     = UDim2.new(0, WIN_W * 0.94, 0, WIN_H * 0.94)
    Main.Position = UDim2.new(0.5, -math.floor(WIN_W*0.47), 0.5, -math.floor(WIN_H*0.47))
    task.delay(0.04, function()
        qt(Main, {
            BackgroundTransparency = T.GlassTransp,
            Size     = UDim2.new(0, WIN_W, 0, WIN_H),
            Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
        }, 0.52, Enum.EasingStyle.Exponential)
        qt(GlassBase, {BackgroundTransparency = 0.14}, 0.52, Enum.EasingStyle.Exponential)
        qt(GlassSheen, {BackgroundTransparency = 0.93}, 0.52, Enum.EasingStyle.Exponential)
        qt(InnerGlassStroke, {Transparency = 0.78}, 0.52, Enum.EasingStyle.Exponential)
    end)

    -- 
    --  WINDOW OBJECT
    -- 
    local Window = {}

    -- 
    --  Window:CreateTab(title, iconName?)
    --  or  Window:CreateTab({ Title = "...", Icon = "..." })
    -- 
    function Window:CreateTab(titleOrCfg, iconName)
        local tabName, tabIcon
        if type(titleOrCfg) == "table" then
            tabName = titleOrCfg.Title or titleOrCfg.Name or "Tab"
            tabIcon = titleOrCfg.Icon
        else
            tabName = tostring(titleOrCfg or "Tab")
            tabIcon = iconName
        end
        local tabId = tabName .. "_" .. tostring(os.clock())

        -- Nav button (matches original: AutomaticSize.X, underline)
        local NavBtn = Instance.new("TextButton")
        NavBtn.Name              = tabName
        NavBtn.Size              = UDim2.new(0, 0, 1, 0)
        NavBtn.AutomaticSize     = Enum.AutomaticSize.X
        NavBtn.BackgroundTransparency = 1
        NavBtn.Text              = string.upper(tabName)
        NavBtn.Font              = FB
        NavBtn.TextSize          = 13
        NavBtn.TextColor3        = T.Secondary
        NavBtn.TextTransparency  = T.SecTransp
        NavBtn.Parent            = Nav

        local Underline = Instance.new("Frame")
        Underline.Name             = "Underline"
        Underline.Size             = UDim2.new(1, 0, 0, 2)
        Underline.Position         = UDim2.new(0, 0, 1, -2)
        Underline.BackgroundColor3 = T.Glow
        Underline.BorderSizePixel  = 0
        Underline.Visible          = false
        Underline.Parent           = NavBtn

        _navBtns[tabId] = NavBtn

        -- Scrollable page  fills the content frame, scrolls on Y
        local Page = Instance.new("ScrollingFrame")
        Page.Name                  = "Page_" .. tabName
        Page.Size                  = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.BorderSizePixel       = 0
        Page.ScrollBarThickness    = 3
        Page.ScrollBarImageColor3  = T.Glow
        Page.ScrollBarImageTransparency = 0.60
        Page.AutomaticCanvasSize   = Enum.AutomaticSize.Y
        Page.CanvasSize            = UDim2.new(0, 0, 0, 0)
        Page.Visible               = false
        Page.Parent                = ContentFrame
        captureInput(Page)
        pad(Page, PAD, PAD, PAD, PAD)
        vList(Page, 12)

        _pages[tabId] = Page
        if not _activeId then activateTab(tabId) end

        NavBtn.MouseButton1Click:Connect(function()
            activateTab(tabId)
        end)

        -- 
        --  TAB ELEMENT FACTORIES
        -- 
        local Tab = {}

        --  CreateSection 
        function Tab:CreateSection(name)
            local Sec = Instance.new("Frame")
            Sec.Size                   = UDim2.new(1, 0, 0, 28)
            Sec.BackgroundTransparency = 1
            Sec.Parent                 = Page

            local function sideLine(xScale, wScale)
                local f = Instance.new("Frame")
                f.Size              = UDim2.new(wScale, 0, 0, 1)
                f.Position          = UDim2.new(xScale, 0, 0.5, 0)
                f.BackgroundColor3  = T.Border
                f.BackgroundTransparency = 0.80
                f.BorderSizePixel   = 0
                f.Parent            = Sec
            end
            sideLine(0, 0.14)
            sideLine(0.86, 0.14)

            local sl = Instance.new("TextLabel")
            sl.Size               = UDim2.new(0.72, 0, 1, 0)
            sl.Position           = UDim2.new(0.14, 0, 0, 0)
            sl.BackgroundTransparency = 1
            sl.Text               = string.upper(name or "")
            sl.TextColor3         = T.Secondary
            sl.TextTransparency   = T.SectionTransp
            sl.Font               = FB
            sl.TextSize           = 10
            sl.TextXAlignment     = Enum.TextXAlignment.Center
            sl.Parent             = Sec
        end

        --  CreateToggle 
        --  3618 track, 14px ball  identical to v1.6 original
        function Tab:CreateToggle(s)
            s = s or {}
            local Row, _ = baseRow(Page)
            rowLabel(Row, s.Name or "")

            local isOn = s.CurrentValue == true

            local Track = Instance.new("TextButton")
            Track.Size             = UDim2.new(0, 36, 0, 18)
            Track.Position         = UDim2.new(1, -36, 0.5, -9)
            Track.BackgroundColor3 = isOn and T.Glow or T.ToggleOff
            Track.Text             = ""
            Track.Parent           = Row
            corner(Track, 10)

            local Ball = Instance.new("Frame")
            Ball.Size             = UDim2.new(0, 14, 0, 14)
            Ball.Position         = isOn and UDim2.new(0, 20, 0, 2) or UDim2.new(0, 2, 0, 2)
            Ball.BackgroundColor3 = Color3.new(1, 1, 1)
            Ball.Parent           = Track
            corner(Ball, 7)

            local function applyState(on)
                qt(Ball,  {Position = on and UDim2.new(0,20,0,2) or UDim2.new(0,2,0,2)}, 0.3, Enum.EasingStyle.Quart)
                qt(Track, {BackgroundColor3 = on and T.Glow or T.ToggleOff}, 0.3)
            end

            Track.MouseButton1Click:Connect(function()
                isOn = not isOn
                applyState(isOn)
                s.CurrentValue = isOn
                if s.Flag then VaporLens.Flags[s.Flag] = s end
                if s.Callback then runCallback(s.Callback, isOn) end
            end)

            s.CurrentValue = isOn
            if s.Flag then VaporLens.Flags[s.Flag] = s end

            function s:Set(v)
                isOn = v == true
                applyState(isOn)
                s.CurrentValue = isOn
                if s.Callback then runCallback(s.Callback, isOn) end
            end

            return s
        end

        --  CreateSlider 
        function Tab:CreateSlider(s)
            s = s or {}
            local minV = (s.Range and s.Range[1]) or 0
            local maxV = (s.Range and s.Range[2]) or 100
            local inc  = s.Increment or 1
            local suf  = s.Suffix or ""
            local cur  = math.clamp(s.CurrentValue or minV, minV, maxV)
            local span = math.max(maxV - minV, 1)

            local Row, _ = baseRow(Page, ELEM_TALL)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size               = UDim2.new(0.6, 0, 0, 22)
            nameLbl.Position           = UDim2.new(0, 0, 0, 12)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text               = s.Name or ""
            nameLbl.TextColor3         = T.Primary
            nameLbl.Font               = FB
            nameLbl.TextSize           = 14
            nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
            nameLbl.Parent             = Row

            -- Value label right-aligned, glow colour (matches "82%" in original)
            local valLbl = Instance.new("TextLabel")
            valLbl.Size               = UDim2.new(0.4, 0, 0, 22)
            valLbl.Position           = UDim2.new(0.6, 0, 0, 12)
            valLbl.BackgroundTransparency = 1
            valLbl.Text               = tostring(cur) .. suf
            valLbl.TextColor3         = T.Glow
            valLbl.Font               = FB
            valLbl.TextSize           = 12
            valLbl.TextXAlignment     = Enum.TextXAlignment.Right
            valLbl.Parent             = Row

            local TrkBg = Instance.new("Frame")
            TrkBg.Size             = UDim2.new(1, 0, 0, 4)
            TrkBg.Position         = UDim2.new(0, 0, 0, 52)
            TrkBg.BackgroundColor3 = T.SliderTrack
            TrkBg.BorderSizePixel  = 0
            TrkBg.Parent           = Row
            corner(TrkBg, 2)

            local Fill = Instance.new("Frame")
            Fill.Size             = UDim2.new((cur-minV)/span, 0, 1, 0)
            Fill.BackgroundColor3 = T.Glow
            Fill.BorderSizePixel  = 0
            Fill.Parent           = TrkBg
            corner(Fill, 2)

            local Thumb = Instance.new("Frame")
            Thumb.Size             = UDim2.new(0, 14, 0, 14)
            Thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
            Thumb.Position         = UDim2.new((cur-minV)/span, 0, 0.5, 0)
            Thumb.BackgroundColor3 = Color3.new(1, 1, 1)
            Thumb.Parent           = TrkBg
            corner(Thumb, 7)

            local slDrag = false

            local function snap(v)
                return math.round((v - minV) / inc) * inc + minV
            end

            local function setVal(px)
                local rel = math.clamp((px - TrkBg.AbsolutePosition.X) / math.max(TrkBg.AbsoluteSize.X, 1), 0, 1)
                cur = math.clamp(snap(minV + rel * span), minV, maxV)
                local r2 = (cur-minV)/span
                Fill.Size      = UDim2.new(r2, 0, 1, 0)
                Thumb.Position = UDim2.new(r2, 0, 0.5, 0)
                valLbl.Text    = tostring(cur) .. suf
                s.CurrentValue = cur
                if s.Callback then runCallback(s.Callback, cur) end
            end

            TrkBg.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    slDrag = true; setVal(inp.Position.X)
                end
            end)
            trackConnection(UIS.InputChanged:Connect(function(inp)
                if slDrag and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    setVal(inp.Position.X)
                end
            end))
            trackConnection(UIS.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    slDrag = false
                end
            end))

            s.CurrentValue = cur
            if s.Flag then VaporLens.Flags[s.Flag] = s end

            function s:Set(v)
                cur = math.clamp(snap(v), minV, maxV)
                local r = (cur-minV)/span
                Fill.Size      = UDim2.new(r, 0, 1, 0)
                Thumb.Position = UDim2.new(r, 0, 0.5, 0)
                valLbl.Text    = tostring(cur) .. suf
                s.CurrentValue = cur
                if s.Callback then runCallback(s.Callback, cur) end
            end

            return s
        end

        --  CreateButton 
        function Tab:CreateButton(s)
            s = s or {}
            local Row, _ = baseRow(Page)
            rowLabel(Row, s.Name or "", 0.60)

            local RunBtn = Instance.new("TextButton")
            RunBtn.Size              = UDim2.new(0, 72, 0, 26)
            RunBtn.Position          = UDim2.new(1, -72, 0.5, -13)
            RunBtn.BackgroundColor3  = T.Glow
            RunBtn.BackgroundTransparency = 0.84
            RunBtn.Text              = "Run"
            RunBtn.TextColor3        = T.Glow
            RunBtn.Font              = FB
            RunBtn.TextSize          = 12
            RunBtn.Parent            = Row
            corner(RunBtn, 7)
            stroke(RunBtn, T.Glow, 0.65, 1)

            RunBtn.MouseButton1Click:Connect(function()
                qt(RunBtn, {BackgroundTransparency = 0.55}, 0.08)
                task.delay(0.12, function()
                    qt(RunBtn, {BackgroundTransparency = 0.84}, 0.22)
                end)
                runCallback(s.Callback)
            end)

            function s:Set(label)
                RunBtn.Text = label or (s.Name or "")
            end

            return s
        end

        --  CreateInput 
        function Tab:CreateInput(s)
            s = s or {}
            local Row, _ = baseRow(Page)
            rowLabel(Row, s.Name or "", 0.44)

            local IFrm = Instance.new("Frame")
            IFrm.Size              = UDim2.new(0, 152, 0, 26)
            IFrm.Position          = UDim2.new(1, -152, 0.5, -13)
            IFrm.BackgroundColor3  = T.InputBg
            IFrm.ClipsDescendants  = true
            IFrm.Parent            = Row
            corner(IFrm, 7)
            stroke(IFrm, T.Border, 0.80, 1)

            local IBox = Instance.new("TextBox")
            IBox.Size              = UDim2.new(1, -18, 1, 0)
            IBox.Position          = UDim2.new(0, 9, 0, 0)
            IBox.BackgroundTransparency = 1
            IBox.Text              = s.CurrentValue or ""
            IBox.PlaceholderText   = s.PlaceholderText or "Enter value..."
            IBox.PlaceholderColor3 = Color3.fromRGB(88, 88, 100)
            IBox.TextColor3        = T.Primary
            IBox.Font              = FB
            IBox.TextSize          = 12
            IBox.ClearTextOnFocus  = false
            IBox.TextXAlignment    = Enum.TextXAlignment.Left
            IBox.TextTruncate      = Enum.TextTruncate.AtEnd
            IBox.TextWrapped       = false
            IBox.Parent            = IFrm

            IBox.FocusLost:Connect(function()
                s.CurrentValue = IBox.Text
                if s.RemoveTextAfterFocusLost then IBox.Text = "" end
                if s.Flag then VaporLens.Flags[s.Flag] = s end
                if s.Callback then runCallback(s.Callback, s.CurrentValue) end
            end)

            if s.Flag then VaporLens.Flags[s.Flag] = s end

            function s:Set(v)
                IBox.Text      = v or ""
                s.CurrentValue = v or ""
                if s.Callback then runCallback(s.Callback, s.CurrentValue) end
            end

            return s
        end

        --  CreateKeybind 
        function Tab:CreateKeybind(s)
            s = s or {}
            local Row, _ = baseRow(Page)
            rowLabel(Row, s.Name or "", 0.52)

            local cur       = s.CurrentKeybind or Enum.KeyCode.Unknown
            local listening = false

            local KBtn = Instance.new("TextButton")
            KBtn.Size              = UDim2.new(0, 96, 0, 26)
            KBtn.Position          = UDim2.new(1, -96, 0.5, -13)
            KBtn.BackgroundColor3  = T.ToggleOff
            KBtn.Text              = (typeof(cur) == "EnumItem") and cur.Name or tostring(cur)
            KBtn.TextColor3        = T.Glow
            KBtn.Font              = FB
            KBtn.TextSize          = 12
            KBtn.Parent            = Row
            corner(KBtn, 6)
            stroke(KBtn, T.Glow, 0.60, 1)

            trackConnection(UIS.InputBegan:Connect(function(inp, gpe)
                if gpe or listening then return end
                if typeof(cur) == "EnumItem" and inp.KeyCode == cur then
                    if not s.CallOnChange and s.Callback then
                        if s.HoldToInteract then
                            runCallback(s.Callback, true)
                            local ec
                            ec = trackConnection(UIS.InputEnded:Connect(function(i2)
                                if i2.KeyCode == cur then
                                    ec:Disconnect()
                                    runCallback(s.Callback, false)
                                end
                            end))
                        else
                            runCallback(s.Callback, cur)
                        end
                    end
                end
            end))

            KBtn.MouseButton1Click:Connect(function()
                if listening then return end
                listening       = true
                KBtn.Text       = "[ ... ]"
                KBtn.TextColor3 = T.Secondary

                local conn
                conn = trackConnection(UIS.InputBegan:Connect(function(inp, gpe)
                    if gpe then return end
                    if inp.KeyCode ~= Enum.KeyCode.Unknown then
                        cur              = inp.KeyCode
                        KBtn.Text        = cur.Name
                        KBtn.TextColor3  = T.Glow
                        listening        = false
                        s.CurrentKeybind = cur
                        conn:Disconnect()
                        if s.Flag then VaporLens.Flags[s.Flag] = s end
                        if s.CallOnChange and s.Callback then
                            runCallback(s.Callback, cur)
                        end
                    end
                end))
            end)

            s.CurrentKeybind = cur
            if s.Flag then VaporLens.Flags[s.Flag] = s end

            function s:Set(v)
                cur              = v
                KBtn.Text        = (typeof(v) == "EnumItem") and v.Name or tostring(v)
                s.CurrentKeybind = v
            end

            return s
        end

        --  CreateDropdown 
        function Tab:CreateDropdown(s)
            s = s or {}
            local isMulti = s.MultipleOptions == true
            local options = s.Options or {}

            local sel = {}
            if s.CurrentOption then
                if type(s.CurrentOption) == "table" then
                    for _, v in ipairs(s.CurrentOption) do sel[v] = true end
                elseif type(s.CurrentOption) == "string" then
                    sel[s.CurrentOption] = true
                end
            elseif options[1] then
                sel[options[1]] = true
            end

            local function selText()
                local parts = {}
                for _, o in ipairs(options) do
                    if sel[o] then table.insert(parts, o) end
                end
                if #parts == 0 then return "None" end
                if isMulti and #parts > 1 then return "Various" end
                return parts[1]
            end

            local BASE_H = ELEM_H
            local ITEM_H = 34
            local isOpen = false
            local closedDropdownIcon = s.ClosedIcon or s.DropdownIcon or DEFAULT_DROPDOWN_ICON
            local openDropdownIcon = s.OpenIcon or s.DropdownIconOpen or closedDropdownIcon

            local DD, ddStr = createDropdownShell(Page, BASE_H)
            local HeaderRow = Instance.new("Frame")
            HeaderRow.Name = "DropdownHeader"
            HeaderRow.Size = UDim2.new(1, 0, 0, BASE_H)
            HeaderRow.BackgroundTransparency = 1
            HeaderRow.ZIndex = 2
            HeaderRow.Parent = DD

            DD.MouseEnter:Connect(function()
                if not isOpen then
                    qt(DD,    {BackgroundTransparency = T.ElemHoverTransp}, 0.18)
                    qt(ddStr, {Transparency = 0.78}, 0.18)
                end
            end)
            DD.MouseLeave:Connect(function()
                qt(DD,    {BackgroundTransparency = T.ElemTransp}, 0.18)
                qt(ddStr, {Transparency = T.ElemBdrTransp}, 0.18)
            end)
            qt(DD,    {BackgroundTransparency = T.ElemTransp}, 0.35)
            qt(ddStr, {Transparency = T.ElemBdrTransp}, 0.35)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size               = UDim2.new(0.5, 0, 0, BASE_H)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text               = s.Name or ""
            nameLbl.TextColor3         = T.Primary
            nameLbl.Font               = FB
            nameLbl.TextSize           = 14
            nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
            nameLbl.Parent             = HeaderRow

            local selLbl = Instance.new("TextLabel")
            selLbl.Size               = UDim2.new(0.42, 0, 0, BASE_H)
            selLbl.Position           = UDim2.new(0.5, 0, 0, 0)
            selLbl.BackgroundTransparency = 1
            selLbl.Text               = selText()
            selLbl.TextColor3         = T.Glow
            selLbl.Font               = FB
            selLbl.TextSize           = 12
            selLbl.TextXAlignment     = Enum.TextXAlignment.Right
            selLbl.TextTruncate       = Enum.TextTruncate.AtEnd
            selLbl.Parent             = HeaderRow

            local chev = icoLabel(HeaderRow, 16, T.Glow)
            chev.AnchorPoint        = Vector2.new(0.5, 0.5)
            chev.Position           = UDim2.new(1, -8, 0, BASE_H / 2)

            local function syncDropdownChevron(opened)
                if opened then
                    applyIcon(chev, openDropdownIcon)
                    qt(chev, {Rotation = 180}, 0.26)
                else
                    applyIcon(chev, closedDropdownIcon)
                    qt(chev, {Rotation = 0}, 0.24)
                end
            end

            syncDropdownChevron(false)

            local optSyncs = {}
            local function getChosen()
                local chosen = {}
                for _, optionName in ipairs(options) do
                    if sel[optionName] then
                        table.insert(chosen, optionName)
                    end
                end
                return chosen
            end

            local function syncAllOptions()
                for _, sync in pairs(optSyncs) do
                    sync()
                end
                selLbl.Text = selText()
            end

            for i, opt in ipairs(options) do
                local IBtn = Instance.new("TextButton")
                IBtn.Size              = UDim2.new(1, 0, 0, ITEM_H)
                IBtn.Position          = UDim2.new(0, 0, 0, BASE_H + (i-1)*ITEM_H)
                IBtn.BackgroundColor3  = sel[opt] and T.Glow or Color3.new(1,1,1)
                IBtn.BackgroundTransparency = sel[opt] and 0.84 or 0.99
                IBtn.Text              = ""
                IBtn.ZIndex            = 1
                IBtn.Parent            = DD
                corner(IBtn, 7)

                local ck = Instance.new("TextLabel")
                ck.Size               = UDim2.new(0, 20, 1, 0)
                ck.BackgroundTransparency = 1
                ck.Text               = sel[opt] and "" or ""
                ck.TextColor3         = T.Glow
                ck.Font               = FB
                ck.TextSize           = 11
                ck.Parent             = IBtn

                local optLbl = Instance.new("TextLabel")
                optLbl.Size               = UDim2.new(1, -24, 1, 0)
                optLbl.Position           = UDim2.new(0, 22, 0, 0)
                optLbl.BackgroundTransparency = 1
                optLbl.Text               = opt
                optLbl.TextColor3         = sel[opt] and T.Glow or T.Primary
                optLbl.TextTransparency   = sel[opt] and 0 or T.SecTransp
                optLbl.Font               = FB
                optLbl.TextSize           = 13
                optLbl.TextXAlignment     = Enum.TextXAlignment.Left
                optLbl.Parent             = IBtn

                local function sync()
                    qt(IBtn,   {BackgroundTransparency = sel[opt] and 0.84 or 0.99}, 0.18)
                    qt(IBtn,   {BackgroundColor3 = sel[opt] and T.Glow or Color3.new(1,1,1)}, 0.18)
                    ck.Text = sel[opt] and "*" or ""
                    qt(optLbl, {
                        TextColor3       = sel[opt] and T.Glow or T.Primary,
                        TextTransparency = sel[opt] and 0 or T.SecTransp,
                    }, 0.18)
                end
                optSyncs[opt] = sync

                IBtn.MouseButton1Click:Connect(function()
                    if isMulti then
                        sel[opt] = not sel[opt]
                    else
                        for k in pairs(sel) do sel[k] = false end
                        sel[opt] = true
                    end
                    syncAllOptions()

                    local chosen = getChosen()
                    s.CurrentOption = isMulti and chosen or chosen[1]
                    if s.Flag then VaporLens.Flags[s.Flag] = s end
                    if s.Callback then runCallback(s.Callback, s.CurrentOption) end

                    if not isMulti then
                        isOpen = false
                        qt(DD,   {Size = UDim2.new(1, 0, 0, BASE_H)}, 0.28, Enum.EasingStyle.Quart)
                        syncDropdownChevron(false)
                    end
                end)
            end

            local Interact = Instance.new("TextButton")
            Interact.Size               = UDim2.new(1, 0, 0, BASE_H)
            Interact.BackgroundTransparency = 1
            Interact.Text               = ""
            Interact.ZIndex             = 5
            Interact.Parent             = HeaderRow

            Interact.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    qt(DD,   {Size = UDim2.new(1, 0, 0, BASE_H + #options*ITEM_H)}, 0.32, Enum.EasingStyle.Quart)
                    syncDropdownChevron(true)
                else
                    qt(DD,   {Size = UDim2.new(1, 0, 0, BASE_H)}, 0.26, Enum.EasingStyle.Quart)
                    syncDropdownChevron(false)
                end
            end)

            local initialChosen = getChosen()
            s.CurrentOption = isMulti and initialChosen or initialChosen[1]
            if s.Flag then VaporLens.Flags[s.Flag] = s end
            syncAllOptions()

            function s:Set(v)
                for k in pairs(sel) do sel[k] = false end
                if type(v) == "table" then
                    for _, val in ipairs(v) do sel[val] = true end
                else
                    sel[v] = true
                end
                local chosen = getChosen()
                s.CurrentOption = isMulti and chosen or chosen[1]
                syncAllOptions()
                if s.Flag then VaporLens.Flags[s.Flag] = s end
                if s.Callback then runCallback(s.Callback, s.CurrentOption) end
            end

            return s
        end

        --  CreateLabel 
        function Tab:CreateLabel(text, iconName, color)
            local Row = Instance.new("Frame")
            Row.Size                   = UDim2.new(1, 0, 0, 34)
            Row.BackgroundColor3       = T.ElemBg
            Row.BackgroundTransparency = 0.99
            Row.Parent                 = Page
            corner(Row, 8)
            stroke(Row, T.Border, 0.94, 1)
            pad(Row, 16, 16, 0, 0)

            local hasIco = iconName ~= nil and iconName ~= ""
            local icoEl  = icoLabel(Row, 15, color or T.Glow)
            icoEl.Position = UDim2.new(0, 0, 0.5, -7)
            if hasIco then applyIcon(icoEl, iconName) end

            local tx = hasIco and 22 or 0
            local lbl = Instance.new("TextLabel")
            lbl.Size               = UDim2.new(1, -tx, 1, 0)
            lbl.Position           = UDim2.new(0, tx, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text               = text or ""
            lbl.TextColor3         = color or T.Secondary
            lbl.TextTransparency   = color and 0 or T.SecTransp
            lbl.Font               = FB
            lbl.TextSize           = 12
            lbl.TextXAlignment     = Enum.TextXAlignment.Left
            lbl.Parent             = Row

            local LV = {}
            function LV:Set(newText, newColor)
                lbl.Text = newText or lbl.Text
                if newColor then
                    lbl.TextColor3    = newColor
                    icoEl.ImageColor3 = newColor
                end
            end

            return LV
        end

        --  CreateParagraph 
        function Tab:CreateParagraph(s)
            s = s or {}
            local Row = Instance.new("Frame")
            Row.Size                   = UDim2.new(1, 0, 0, 84)
            Row.BackgroundColor3       = T.ElemBg
            Row.BackgroundTransparency = 0.99
            Row.Parent                 = Page
            corner(Row, 10)
            stroke(Row, T.Border, 0.94, 1)
            pad(Row, 16, 16, 10, 10)

            local tLbl = Instance.new("TextLabel")
            tLbl.Size               = UDim2.new(1, 0, 0, 18)
            tLbl.BackgroundTransparency = 1
            tLbl.Text               = s.Title   or ""
            tLbl.TextColor3         = T.Primary
            tLbl.Font               = FB
            tLbl.TextSize           = 14
            tLbl.TextXAlignment     = Enum.TextXAlignment.Left
            tLbl.Parent             = Row

            local cLbl = Instance.new("TextLabel")
            cLbl.Size               = UDim2.new(1, 0, 0, 44)
            cLbl.Position           = UDim2.new(0, 0, 0, 24)
            cLbl.BackgroundTransparency = 1
            cLbl.Text               = s.Content or ""
            cLbl.TextColor3         = T.Secondary
            cLbl.TextTransparency   = T.SecTransp
            cLbl.Font               = FM
            cLbl.TextSize           = 12
            cLbl.TextXAlignment     = Enum.TextXAlignment.Left
            cLbl.TextWrapped        = true
            cLbl.Parent             = Row

            local PV = {}
            function PV:Set(ns)
                tLbl.Text = ns.Title   or tLbl.Text
                cLbl.Text = ns.Content or cLbl.Text
            end

            return PV
        end

        return Tab
    end -- CreateTab

    --  Window utilities 
    function Window:SelectTab(name)
        for id in pairs(_pages) do
            if id:lower():find(name:lower(), 1, true) then
                activateTab(id)
                return
            end
        end
    end

    function Window:SetToggleKey(key)
        toggleKey = key
    end

    function Window:Destroy()
        VaporLens:Destroy()
    end

    task.delay(0.7, function()
        VaporLens:Notify({
            Title    = cfg.Title or "Vapor Lens",
            Content  = "Interface initialized.",
            Icon     = "check-circle",
            Duration = 3,
        })
    end)

    return Window
end -- CreateWindow

return VaporLens




