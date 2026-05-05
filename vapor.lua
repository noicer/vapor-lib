--
--  SERVICES
--
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

--
--  ANTI-DUPLICATE REGISTRY
--  Executor-wide shared table detects re-execution and destroys the previous instance.
--  Uses getgenv() (standard across 90%+ executors) with _G fallback for Studio.
--
local VAPOR_REGISTRY_KEY = "__VaporLens_Instance__"
local _sharedEnv = _G
do
	local ok, env = pcall(function()
		if type(getgenv) == "function" then
			return getgenv()
		end
		return nil
	end)
	if ok and type(env) == "table" then
		_sharedEnv = env
	end
end

--
--  LUCIDE ICONS  (same atlas as Rayfield  Latte Softworks)
--  Load is async. applyIcon() queues requests made before load.
--
local Icons = nil
local iconReady = false
local iconLoadFailed = false
local iconQueue = {} -- { imageLabel, source }
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
	elseif iconLoadFailed then
		return
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
				else
					iconLoadFailed = true
					warn("VaporLens | Lucide icons failed: " .. tostring(res))
				end
				task.defer(function() flushIconQueue() end) -- deferred: guarantees assignment completes before invocation
			end)
		end
		table.insert(iconQueue, { img, iconName })
	end
end
flushIconQueue = function()
	for _, entry in ipairs(iconQueue) do
		local img, source = entry[1], entry[2]
		if iconReady and img and img.Parent then
			applyResolvedIcon(img, source)
		end
	end
	iconQueue = {}
end

local function applyIcon(img, source)
	if not source or source == "" then
		return
	end
	applyResolvedIcon(img, source)
end

--
--  THEME
--
local T = {
	-- Window
	Glass = Color3.fromRGB(15, 15, 17),
	GlassTransp = 0.25,
	Border = Color3.fromRGB(45, 45, 50),
	BorderTransp = 0.50,

	-- Accent
	Glow = Color3.fromRGB(0, 180, 255),

	-- Text
	Primary = Color3.fromRGB(240, 240, 240),
	Secondary = Color3.fromRGB(160, 160, 165),
	SecTransp = 0,

	-- Elements
	ElemBg = Color3.fromRGB(30, 30, 35),
	ElemTransp = 0.40,
	ElemHoverTransp = 0.20,
	ElemBdrTransp = 0.70,

	-- Controls
	ToggleOff = Color3.fromRGB(40, 40, 45),
	SliderTrack = Color3.fromRGB(20, 20, 25),
	InputBg = Color3.fromRGB(10, 10, 12),

	-- Section label
	SectionTransp = 0.30,

	-- Notification
	NotifBg = Color3.fromRGB(5, 5, 8),
}

--
--  FONTS
--
local FB = Enum.Font.GothamBold
local FM = Enum.Font.GothamMedium -- paragraph body only

--
--  SIZING  same proportions as original v1.6
--
local HDR_H = 82 -- header (matches original)
local NAV_H = 32 -- nav bar
local PAD = 25 -- horizontal padding
local ELEM_H = 52 -- standard row height
local ELEM_TALL = 72 -- slider row height
local EDGE_SAFE = 6

-- Notification geometry
local NF = { W = 290, H = 48, Gap = 9, Right = 20, Bot = 20 }

local NAME_ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local NAME_RNG = Random.new(math.floor(os.clock() * 1000000) % 2147483647)
local _nameSerial = 0
local _idSerial = 0

local function nextOpaqueName()
	_nameSerial = _nameSerial + 1
	local len = 10 + (_nameSerial % 7)
	local out = table.create(len + 1)
	out[1] = string.char(NAME_RNG:NextInteger(97, 122))
	for i = 2, len do
		local idx = NAME_RNG:NextInteger(1, #NAME_ALPHABET)
		out[i] = NAME_ALPHABET:sub(idx, idx)
	end
	out[len + 1] = string.format("%x", _nameSerial)
	return table.concat(out)
end

local function nextId(prefix)
	_idSerial = _idSerial + 1
	return string.format("%s_%d_%s", prefix or "id", _idSerial, nextOpaqueName())
end

local function cloak(instance)
	if instance then
		instance.Name = nextOpaqueName()
	end
	return instance
end

--
--  HELPERS
--
local function qt(obj, goal, dur, style, dir)
	if not obj then
		return nil
	end

	local ok, tw = pcall(function()
		if obj.Parent == nil then
			return nil
		end
		return TS:Create(
			obj,
			TweenInfo.new(dur or 0.28, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
			goal
		)
	end)
	if not ok or not tw then
		return nil
	end

	tw:Play()
	return tw
end

local function corner(p, r)
	local c = cloak(Instance.new("UICorner"))
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end

local function stroke(p, col, tr, th)
	local s = cloak(Instance.new("UIStroke"))
	s.Color = col or T.Border
	s.Transparency = tr or 0
	s.Thickness = th or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function pad(p, l, r, t, b)
	local u = cloak(Instance.new("UIPadding"))
	u.PaddingLeft = UDim.new(0, l or 0)
	u.PaddingRight = UDim.new(0, r or 0)
	u.PaddingTop = UDim.new(0, t or 0)
	u.PaddingBottom = UDim.new(0, b or 0)
	u.Parent = p
	return u
end

local function vList(p, gap)
	local l = cloak(Instance.new("UIListLayout"))
	l.FillDirection = Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or 0)
	l.Parent = p
	return l
end

local function hList(p, gap, valign)
	local l = cloak(Instance.new("UIListLayout"))
	l.FillDirection = Enum.FillDirection.Horizontal
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or 0)
	l.VerticalAlignment = valign or Enum.VerticalAlignment.Center
	l.Parent = p
	return l
end

local function icoLabel(parent, sz, col)
	local img = cloak(Instance.new("ImageLabel"))
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(0, sz or 18, 0, sz or 18)
	img.ImageColor3 = col or T.Primary
	img.Parent = parent
	return img
end

local function safeMount(sg)
	local ok = pcall(function()
		-- Executor fallback chain: gethui > get_hidden_gui > syn.protect_gui > protect_gui > CoreGui
		if type(gethui) == "function" then
			sg.Parent = gethui()
			return
		end
		if type(get_hidden_gui) == "function" then
			sg.Parent = get_hidden_gui()
			return
		end
		if syn and type(syn.protect_gui) == "function" then
			syn.protect_gui(sg)
			sg.Parent = CoreGui
			return
		end
		if type(protect_gui) == "function" then
			protect_gui(sg)
			sg.Parent = CoreGui
			return
		end
		if not RS:IsStudio() and CoreGui:FindFirstChild("RobloxGui") then
			sg.Parent = CoreGui.RobloxGui
			return
		end
		sg.Parent = CoreGui
	end)
	return ok and sg.Parent ~= nil
end

local function create(className, props)
	local instance = cloak(Instance.new(className))
	for key, value in pairs(props or {}) do
		local ok, err = pcall(function()
			if key == "Parent" then
				instance.Parent = value
			else
				instance[key] = value
			end
		end)
		if not ok then
			warn("VaporLens | Ignored invalid " .. className .. "." .. tostring(key) .. ": " .. tostring(err))
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

local function asTable(value)
	return type(value) == "table" and value or {}
end

local function safeText(value, fallback)
	local valueType = type(value)
	if valueType == "string" then
		return value
	end
	if valueType == "number" or valueType == "boolean" then
		return tostring(value)
	end
	return fallback or ""
end

local function safeNumber(value, fallback, minValue, maxValue)
	local n = type(value) == "number" and value or tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		n = fallback
	end
	n = n or 0
	if minValue ~= nil and n < minValue then
		n = minValue
	end
	if maxValue ~= nil and n > maxValue then
		n = maxValue
	end
	return n
end

local function safeKeyCode(value, fallback)
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	if type(value) == "string" then
		local ok, key = pcall(function()
			return Enum.KeyCode[value]
		end)
		if ok and key then
			return key
		end
	end
	return fallback or Enum.KeyCode.Unknown
end

local function safeFlag(value)
	local flag = safeText(value, "")
	return flag ~= "" and flag or nil
end

local function safeColor(value, fallback)
	return typeof(value) == "Color3" and value or fallback
end

local function normalizeOptions(options)
	local out = {}
	if type(options) ~= "table" then
		return out
	end
	for _, option in ipairs(options) do
		table.insert(out, safeText(option, ""))
	end
	return out
end

local function createIconButton(parent, props)
	local button = create("TextButton", {
		Name = props.Name or nextOpaqueName(),
		Size = props.Size or UDim2.new(0, 32, 0, 32),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})

	local icon = icoLabel(button, props.IconSize or 16, props.Color or T.Glow)
	icon.Name = nextOpaqueName()
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	if props.Icon then
		applyIcon(icon, props.Icon)
	end

	return button, icon
end

local function bindHoverState(target, fillObj, borderObj, isLocked)
	local hovered = false

	local function apply(nextHover, instant)
		if isLocked and isLocked() then
			nextHover = false
		end
		if hovered == nextHover and not instant then
			return
		end

		hovered = nextHover
		local fillTransparency = hovered and T.ElemHoverTransp or T.ElemTransp
		local borderTransparency = hovered and 0.78 or T.ElemBdrTransp

		if instant then
			fillObj.BackgroundTransparency = fillTransparency
			borderObj.Transparency = borderTransparency
			return
		end

		qt(fillObj, { BackgroundTransparency = fillTransparency }, 0.18)
		qt(borderObj, { Transparency = borderTransparency }, 0.18)
	end

	target.MouseEnter:Connect(function()
		apply(true, false)
	end)
	target.MouseLeave:Connect(function()
		apply(false, false)
	end)
	apply(false, true)

	return apply
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
	pad(shell, 16, 16, 0, 8)
	return shell, shellStroke
end

--
--  SHARED ROW BUILDER
--
local function baseRow(page, h)
	h = h or ELEM_H
	local Row = cloak(Instance.new("Frame"))
	Row.Size = UDim2.new(1, 0, 0, h)
	Row.BackgroundColor3 = T.ElemBg
	Row.BackgroundTransparency = 1
	Row.Parent = page
	captureInput(Row)
	corner(Row, 12)
	local rs = stroke(Row, T.Border, 1, 1)
	pad(Row, 16, 16, 0, 0)
	bindHoverState(Row, Row, rs)
	return Row, rs
end

-- rowLabel(row, text, rightPx)
-- Creates a left-aligned descriptive TextLabel that respects the right-aligned interactive element.
-- @param rightPx  pixel width of the right element + 8px gap buffer. Label width = 1, -(rightPx).
--                 Falls back to scale 0.55 if nil (legacy compat). O(1) property assignment.
local function rowLabel(row, text, rightPx)
	local l = cloak(Instance.new("TextLabel"))
	if type(rightPx) == "number" and rightPx > 0 then
		-- Offset-based: prevents overlap with right element regardless of window width or DPI
		l.Size = UDim2.new(1, -rightPx, 1, 0)
	else
		-- Legacy scale fallback (should not be used for new elements)
		l.Size = UDim2.new(0.55, 0, 1, 0)
	end
	l.BackgroundTransparency = 1
	l.Text = safeText(text, "")
	l.TextColor3 = T.Primary
	l.Font = FB
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true      -- word-wrap on overflow
	l.TextTruncate = Enum.TextTruncate.AtEnd  -- ellipsis if still overflows after wrap
	l.Parent = row
	return l
end

--
--  LIBRARY
--
local VaporLens = { Flags = {}, Version = "1.2" }

local _gui = nil
local _notifStack = {}
local _destroyed = false
local _sessionId = 0
local _trackedConnections = {}

local function trackConnection(conn)
	if conn then
		table.insert(_trackedConnections, conn)
	end
	return conn
end

local function safeDisconnect(conn)
	if conn then
		pcall(function()
			conn:Disconnect()
		end)
	end
end

local function disconnectTrackedConnections()
	for i, conn in ipairs(_trackedConnections) do
		safeDisconnect(conn)
		_trackedConnections[i] = nil
	end
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

local function rememberFlag(flag, value)
	local key = safeFlag(flag)
	if key then
		VaporLens.Flags[key] = value
	end
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
--    GlassTransp    number   window background transparency  (0–1)
--    Border         Color3   window + element border colour
--    BorderTransp   number   window border transparency      (0–1)
--    Glow           Color3   accent / active colour
--    Primary        Color3   primary text colour
--    Secondary      Color3   secondary text colour
--    SecTransp      number   secondary text transparency     (0–1)
--    ElemBg         Color3   element row background tint
--    ElemTransp     number   element row transparency        (0–1)
--    ElemHoverTransp number  element hover transparency      (0–1)
--    ElemBdrTransp  number   element border transparency     (0–1)
--    ToggleOff      Color3   toggle track colour when off
--    SliderTrack    Color3   slider unfilled track colour
--    InputBg        Color3   input field background
--    SectionTransp  number   section label transparency      (0–1)
--    NotifBg        Color3   notification background
--
function VaporLens:SetTheme(custom)
	if type(custom) ~= "table" then
		warn("VaporLens:SetTheme() expects a table")
		return
	end
	for k, v in pairs(custom) do
		if T[k] ~= nil then
			local currentType = typeof(T[k])
			if typeof(v) == currentType then
				if currentType == "number" then
					T[k] = math.clamp(v, 0, 1)
				else
					T[k] = v
				end
			else
				warn("VaporLens:SetTheme() | Invalid value for key: " .. tostring(k))
			end
		else
			warn("VaporLens:SetTheme() | Unknown key: " .. tostring(k))
		end
	end
end

function VaporLens:SetIconAtlas(atlas)
	if type(atlas) ~= "table" then
		warn("VaporLens:SetIconAtlas() expects a table")
		return
	end
	Icons = atlas
	iconReady = true
	iconLoadFailed = false
	flushIconQueue()
end

--
--  NOTIFICATIONS
--
local function _notifPos(i)
	return UDim2.new(1, -NF.Right, 1, -(NF.Bot + (i - 1) * (NF.H + NF.Gap)))
end

local function _reposNotifs()
	for i, notif in ipairs(_notifStack) do
		local frame = notif and notif.Frame
		if frame and frame.Parent then
			qt(frame, { Position = _notifPos(i) }, 0.28)
		end
	end
end

local function dropNotification(notif)
	local idx = table.find(_notifStack, notif)
	if idx then
		table.remove(_notifStack, idx)
	end

	if notif then
		notif.Cancelled = true
		local frame = notif.Frame
		if frame and frame.Parent then
			frame:Destroy()
		end
	end

	_reposNotifs()
end

function VaporLens:Notify(data)
	if _destroyed or not (_gui and _gui.Parent) then
		return nil
	end
	data = asTable(data)
	local dur = safeNumber(data.Duration, 4, 0.05, 120)
	local parent = _gui
	local idx = #_notifStack + 1
	local sessionId = _sessionId

	local N = cloak(Instance.new("Frame"))
	N.Size = UDim2.new(0, NF.W, 0, NF.H)
	N.AnchorPoint = Vector2.new(1, 1)
	N.Position = UDim2.new(1, NF.Right + 24, 1, -(NF.Bot + (idx - 1) * (NF.H + NF.Gap)))
	N.BackgroundColor3 = T.NotifBg
	N.BackgroundTransparency = 0.08
	N.Parent = parent
	captureInput(N)
	corner(N, 10)
	local nStr = stroke(N, T.Glow, 0.55, 1)

	local bar = cloak(Instance.new("Frame"))
	bar.Size = UDim2.new(0, 3, 0.5, 0)
	bar.Position = UDim2.new(0, 12, 0.25, 0)
	bar.BackgroundColor3 = T.Glow
	bar.BorderSizePixel = 0
	bar.Parent = N
	corner(bar, 2)

	local hasIco = data.Icon ~= nil and data.Icon ~= ""
	local ico = icoLabel(N, 18, T.Glow)
	ico.Position = UDim2.new(0, 24, 0.5, -9)
	if hasIco then
		applyIcon(ico, data.Icon)
	end

	local tx = hasIco and 50 or 26

	local nTit = cloak(Instance.new("TextLabel"))
	nTit.Size = UDim2.new(1, -(tx + 12), 0, 15)
	nTit.Position = UDim2.new(0, tx, 0.5, -16)
	nTit.BackgroundTransparency = 1
	nTit.Text = safeText(data.Title, "")
	nTit.TextColor3 = T.Primary
	nTit.Font = FB
	nTit.TextSize = 12
	nTit.TextXAlignment = Enum.TextXAlignment.Left
	nTit.Parent = N

	local nSub = cloak(Instance.new("TextLabel"))
	nSub.Size = UDim2.new(1, -(tx + 12), 0, 13)
	nSub.Position = UDim2.new(0, tx, 0.5, 2)
	nSub.BackgroundTransparency = 1
	nSub.Text = safeText(data.Content, "")
	nSub.TextColor3 = T.Secondary
	nSub.TextTransparency = T.SecTransp
	nSub.Font = FB
	nSub.TextSize = 11
	nSub.TextXAlignment = Enum.TextXAlignment.Left
	nSub.TextWrapped = true
	nSub.Parent = N

	local notif = {
		Frame = N,
		Cancelled = false,
		SessionId = sessionId,
	}

	table.insert(_notifStack, notif)
	qt(N, { Position = _notifPos(idx) }, 0.44, Enum.EasingStyle.Quart)

	task.delay(dur, function()
		if _destroyed or notif.Cancelled or notif.SessionId ~= _sessionId then
			return
		end
		if not N.Parent then
			dropNotification(notif)
			return
		end
		local exitPos = UDim2.new(1, NF.Right + 24, N.Position.Y.Scale, N.Position.Y.Offset)
		qt(N, { BackgroundTransparency = 1, Position = exitPos }, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		qt(nStr, { Transparency = 1 }, 0.36)
		qt(nTit, { TextTransparency = 1 }, 0.36)
		qt(nSub, { TextTransparency = 1 }, 0.36)
		qt(bar, { BackgroundTransparency = 1 }, 0.36)
		qt(ico, { ImageTransparency = 1 }, 0.36)
		task.delay(0.38, function()
			if _destroyed or notif.Cancelled or notif.SessionId ~= _sessionId then
				return
			end
			dropNotification(notif)
		end)
	end)

	return notif
end

local InputManager = {
	Connections = {},
	ActiveSlider = nil,
	ListeningKeybind = nil,
	DragState = nil,
	ToggleHandler = nil,
	Keybinds = {},
}

function InputManager:ReleaseBinding(binding)
	if binding and binding.HoldToInteract and binding.Held then
		binding.Held = false
		if binding.Callback then
			runCallback(binding.Callback, false)
		end
	end
end

function InputManager:CancelListening(binding)
	local listener = binding or self.ListeningKeybind
	if listener and listener.CancelListen then
		pcall(listener.CancelListen)
	end
	if self.ListeningKeybind == listener or binding == nil then
		self.ListeningKeybind = nil
	end
end

function InputManager:RegisterKeybind(binding)
	if not binding then
		return nil
	end
	if binding.__VaporBindingId then
		return binding.__VaporBindingId
	end
	local id = nextId("kb")
	binding.__VaporBindingId = id
	self.Keybinds[id] = binding
	return id
end

function InputManager:UnregisterKeybind(id)
	if id then
		self:ReleaseBinding(self.Keybinds[id])
		self.Keybinds[id] = nil
	end
end

function InputManager:Init()
	self:Destroy()

	self.Connections.MouseMoved = UIS.InputChanged:Connect(function(inp)
		local inputType = inp.UserInputType
		if inputType ~= Enum.UserInputType.MouseMovement and inputType ~= Enum.UserInputType.Touch then
			return
		end

		local dragState = self.DragState
		if dragState then
			if dragState.Alive and not dragState.Alive() then
				self.DragState = nil
			elseif dragState.Active and typeof(dragState.Update) == "function" then
				local ok, err = pcall(dragState.Update, inp.Position)
				if not ok then
					self.DragState = nil
					warn("VaporLens | Drag update error: " .. tostring(err))
				end
			end
		end

		local slider = self.ActiveSlider
		if slider then
			if slider.Alive and not slider.Alive() then
				self.ActiveSlider = nil
			elseif typeof(slider.Update) == "function" then
				local ok, err = pcall(slider.Update, inp.Position.X)
				if not ok then
					self.ActiveSlider = nil
					warn("VaporLens | Slider update error: " .. tostring(err))
				end
			end
		end
	end)

	self.Connections.MouseEnded = UIS.InputEnded:Connect(function(inp)
		local inputType = inp.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			if self.ActiveSlider then
				self.ActiveSlider = nil
			end
			local dragState = self.DragState
			if dragState then
				dragState.Active = false
				-- Defer clearing so element-local InputEnded handlers can still compare ownership.
				task.defer(function()
					if self.DragState == dragState and not dragState.Active then
						self.DragState = nil
					end
				end)
			end
		end

		local releasedKey = inp.KeyCode
		if releasedKey == Enum.KeyCode.Unknown then
			return
		end

		for id, binding in pairs(self.Keybinds) do
			if binding.Alive and not binding.Alive() then
				self:ReleaseBinding(binding)
				self.Keybinds[id] = nil
			elseif binding.HoldToInteract and binding.Held and binding.GetKey and binding.GetKey() == releasedKey then
				binding.Held = false
				if binding.Callback then
					runCallback(binding.Callback, false)
				end
			end
		end
	end)

	self.Connections.KeyBegan = UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then
			return
		end

		local key = inp.KeyCode
		if self.ListeningKeybind and key ~= Enum.KeyCode.Unknown then
			local listener = self.ListeningKeybind
			if listener.Alive and not listener.Alive() then
				self:CancelListening(listener)
				return
			end
			self.ListeningKeybind = nil
			listener.SetKey(key)
			return
		end

		local toggleHandler = self.ToggleHandler
		if toggleHandler and key ~= Enum.KeyCode.Unknown and toggleHandler.GetKey and toggleHandler.Callback then
			if toggleHandler.Alive and not toggleHandler.Alive() then
				self.ToggleHandler = nil
			elseif toggleHandler.GetKey() == key then
				toggleHandler.Callback(key)
				return
			end
		end

		if key == Enum.KeyCode.Unknown then return end 

		for id, binding in pairs(self.Keybinds) do
			if binding.Alive and not binding.Alive() then
				self:ReleaseBinding(binding)
				self.Keybinds[id] = nil
			elseif binding.GetKey and binding.GetKey() == key then
				if binding.HoldToInteract then
					if not binding.Held and binding.Callback then
						binding.Held = true
						runCallback(binding.Callback, true)
					end
				elseif binding.Callback then
					runCallback(binding.Callback, key)
				end
			end
		end
	end)
end

function InputManager:Destroy()
	for key, conn in pairs(self.Connections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
		self.Connections[key] = nil
	end

	self.ActiveSlider = nil
	self:CancelListening()
	self.DragState = nil
	self.ToggleHandler = nil
	for id, binding in pairs(self.Keybinds) do
		self:ReleaseBinding(binding)
		self.Keybinds[id] = nil
	end
	self.Keybinds = {}
end

--
--  DESTROY
--
function VaporLens:Destroy()
	_destroyed = true
	InputManager:Destroy()
	disconnectTrackedConnections()
	for _, notif in ipairs(_notifStack) do
		if notif then
			notif.Cancelled = true
			local frame = notif.Frame
			if frame and frame.Parent then
				frame:Destroy()
			end
		end
	end
	_notifStack = {}
	if _gui and _gui.Parent then
		_gui:Destroy()
	end
	_gui = nil
	self.Flags = {}
	-- Clear global registry sentinel to prevent dangling references
	if _sharedEnv[VAPOR_REGISTRY_KEY] == self then
		_sharedEnv[VAPOR_REGISTRY_KEY] = nil
	end
end

--
--  CREATE WINDOW
--
function VaporLens:CreateWindow(cfg)
	cfg = asTable(cfg)

	-- Anti-duplicate: destroy any previous VaporLens instance from a prior script execution.
	-- Uses shared environment registry to locate the old instance regardless of cloak() randomization.
	local prev = _sharedEnv[VAPOR_REGISTRY_KEY]
	if prev and prev ~= self and type(prev.Destroy) == "function" then
		pcall(prev.Destroy, prev)
	end
	_sharedEnv[VAPOR_REGISTRY_KEY] = self

	if _gui or #_notifStack > 0 then
		self:Destroy()
	end
	_destroyed = false
	_sessionId = _sessionId + 1
	InputManager:Init()

	local WIN_W = math.floor(safeNumber(cfg.Width, 480, 320, 900))
	local WIN_H = math.floor(safeNumber(cfg.Height, 380, HDR_H + NAV_H + 120, 720))
	local toggleKey = safeKeyCode(cfg.ToggleKey, Enum.KeyCode.RightControl)
	local sessionId = _sessionId

	--  ScreenGui
	local sg = cloak(Instance.new("ScreenGui"))
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = math.random(100000, 999999)
	_gui = sg
	if not safeMount(sg) then
		_gui = nil
		_destroyed = true
		error("VaporLens | Failed to mount into a protected GUI container")
	end

	--  Main container  FIXED SIZE
	local Main = cloak(Instance.new("Frame"))
	Main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
	Main.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
	Main.BackgroundColor3 = T.Glass
	Main.BackgroundTransparency = T.GlassTransp
	Main.ClipsDescendants = true
	Main.Parent = sg
	captureInput(Main)
	corner(Main, 24)
	stroke(Main, T.Border, T.BorderTransp, 1)

	local GlassBase = cloak(Instance.new("Frame"))
	GlassBase.Size = UDim2.new(1, 0, 1, 0)
	GlassBase.BackgroundColor3 = Color3.fromRGB(17, 0, 28)
	GlassBase.BackgroundTransparency = 0.14
	GlassBase.BorderSizePixel = 0
	GlassBase.ZIndex = 0
	GlassBase.Parent = Main
	corner(GlassBase, 24)

	local GlassGradient = cloak(Instance.new("UIGradient"))
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

	local GlassSheen = cloak(Instance.new("Frame"))
	GlassSheen.Size = UDim2.new(1, -2, 0.42, 0)
	GlassSheen.Position = UDim2.new(0, 1, 0, 1)
	GlassSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	GlassSheen.BackgroundTransparency = 0.93
	GlassSheen.BorderSizePixel = 0
	GlassSheen.ZIndex = 0
	GlassSheen.Parent = Main
	corner(GlassSheen, 22)

	local SheenGradient = cloak(Instance.new("UIGradient"))
	SheenGradient.Rotation = 90
	SheenGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.00),
		NumberSequenceKeypoint.new(0.35, 0.72),
		NumberSequenceKeypoint.new(1.00, 1.00),
	})
	SheenGradient.Parent = GlassSheen

	local InnerGlassStroke = cloak(Instance.new("UIStroke"))
	InnerGlassStroke.Color = Color3.fromRGB(145, 86, 191)
	InnerGlassStroke.Transparency = 0.78
	InnerGlassStroke.Thickness = 1
	InnerGlassStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	InnerGlassStroke.Parent = GlassBase

	local InnerClip = cloak(Instance.new("Frame"))
	InnerClip.Size = UDim2.new(1, -(EDGE_SAFE * 2), 1, -(EDGE_SAFE * 2))
	InnerClip.Position = UDim2.new(0, EDGE_SAFE, 0, EDGE_SAFE)
	InnerClip.BackgroundTransparency = 1
	InnerClip.BorderSizePixel = 0
	InnerClip.ClipsDescendants = true
	InnerClip.ZIndex = 1
	InnerClip.Parent = Main
	captureInput(InnerClip)
	corner(InnerClip, 18)

	--  HEADER (82px  identical to original)
	local Header = cloak(Instance.new("Frame"))
	Header.Size = UDim2.new(1, 0, 0, HDR_H)
	Header.BackgroundTransparency = 1
	Header.Parent = InnerClip
	captureInput(Header)
	pad(Header, PAD, PAD, PAD, PAD)

	local hGrad = cloak(Instance.new("UIGradient"))
	hGrad.Rotation = 90
	hGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.95),
		NumberSequenceKeypoint.new(1, 1),
	})
	hGrad.Parent = Header

	-- Icon box  absolute left (32×32, matches original)
	local IcoBox = cloak(Instance.new("Frame"))
	IcoBox.Size = UDim2.new(0, 32, 0, 32)
	IcoBox.Position = UDim2.new(0, 0, 0.5, -16)
	IcoBox.BackgroundColor3 = T.Glow
	IcoBox.BackgroundTransparency = 0.50
	IcoBox.Parent = Header
	corner(IcoBox, 8)
	local icoGlow = cloak(Instance.new("UIStroke"))
	icoGlow.Color = T.Glow
	icoGlow.Thickness = 3
	icoGlow.Transparency = 0.6
	icoGlow.Parent = IcoBox

	local IcoImg = icoLabel(IcoBox, 18, Color3.new(1, 1, 1))
	IcoImg.Position = UDim2.new(0.5, -9, 0.5, -9)
	applyIcon(IcoImg, cfg.Icon or "droplets")

	-- Collapse button  absolute right
	local ColBtn, ColIcon = createIconButton(Header, {
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -32, 0.5, -16),
		Icon = cfg.CollapseIcon or DEFAULT_COLLAPSE_ICON,
		IconSize = 16,
		Color = T.Glow,
	})

	-- Title / subtitle  fills between icon and collapse btn
	local TxtBlk = cloak(Instance.new("Frame"))
	TxtBlk.Size = UDim2.new(1, -(32 + 15 + 32 + 10), 1, 0)
	TxtBlk.Position = UDim2.new(0, 32 + 15, 0, 0)
	TxtBlk.BackgroundTransparency = 1
	TxtBlk.Parent = Header

	local TitleLbl = cloak(Instance.new("TextLabel"))
	TitleLbl.Size = UDim2.new(1, 0, 0, 18)
	TitleLbl.Position = UDim2.new(0, 0, 0.5, -18)
	TitleLbl.BackgroundTransparency = 1
	TitleLbl.Text = string.upper(safeText(cfg.Title, "VAPOR LENS"))
	TitleLbl.TextColor3 = T.Primary
	TitleLbl.Font = FB
	TitleLbl.TextSize = 16
	TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
	TitleLbl.Parent = TxtBlk

	local SubLbl = cloak(Instance.new("TextLabel"))
	SubLbl.Size = UDim2.new(1, 0, 0, 12)
	SubLbl.Position = UDim2.new(0, 0, 0.5, 5)
	SubLbl.BackgroundTransparency = 1
	SubLbl.Text = safeText(cfg.Subtitle, "SYSTEM OVERLAY v" .. VaporLens.Version)
	SubLbl.TextColor3 = T.Secondary
	SubLbl.TextTransparency = T.SecTransp
	SubLbl.Font = FB
	SubLbl.TextSize = 11
	SubLbl.TextXAlignment = Enum.TextXAlignment.Left
	SubLbl.Parent = TxtBlk

	--  NAV BAR (32px, horizontal tabs, matches original)
	local Nav = cloak(Instance.new("ScrollingFrame"))
	Nav.Size = UDim2.new(1, 0, 0, NAV_H)
	Nav.Position = UDim2.new(0, 0, 0, HDR_H)
	Nav.BackgroundTransparency = 1
	Nav.BorderSizePixel = 0
	Nav.ScrollBarThickness = 0
	Nav.ScrollingDirection = Enum.ScrollingDirection.X
	Nav.AutomaticCanvasSize = Enum.AutomaticSize.X
	Nav.CanvasSize = UDim2.new(0, 0, 0, 0)
	Nav.Parent = InnerClip
	captureInput(Nav)
	pad(Nav, PAD, PAD, 0, 0)
	hList(Nav, 20, Enum.VerticalAlignment.Center)

	-- Custom drag-to-scroll for Nav.
	-- Owns a specific InputObject so it cannot conflict with window/floating/slider drags.
	local navDrag = { active = false, input = nil, startX = 0, startCanvas = 0 }
	
	trackConnection(Nav.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			if InputManager.ActiveSlider or (InputManager.DragState and InputManager.DragState.Active) then
				return
			end
			navDrag.active = true
			navDrag.input = inp
			navDrag.startX = inp.Position.X
			navDrag.startCanvas = Nav.CanvasPosition.X
		end
	end))
	
	trackConnection(Nav.InputEnded:Connect(function(inp)
		if navDrag.input == inp or inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			navDrag.active = false
			navDrag.input = nil
		end
	end))
	
	InputManager.Connections.NavDrag = UIS.InputChanged:Connect(function(inp)
		if navDrag.active and not InputManager.ActiveSlider and not (InputManager.DragState and InputManager.DragState.Active)
			and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = navDrag.startX - inp.Position.X
			local maxScroll = math.max(0, Nav.AbsoluteCanvasSize.X - Nav.AbsoluteWindowSize.X)
			Nav.CanvasPosition = Vector2.new(math.clamp(navDrag.startCanvas + delta, 0, maxScroll), 0)
		end
	end)

	InputManager.Connections.NavDragEnd = UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			if navDrag.active then
				navDrag.active = false
				navDrag.input = nil
			end
		end
	end)

	--  SCROLLABLE CONTENT
	--  Fixed height = WIN_H - header - nav.
	--  Elements scroll inside; scrollbar appears only on overflow.
	local CONTENT_Y = HDR_H + NAV_H
	local CONTENT_H = WIN_H - CONTENT_Y

	local ContentFrame = cloak(Instance.new("Frame"))
	ContentFrame.Size = UDim2.new(1, 0, 0, CONTENT_H)
	ContentFrame.Position = UDim2.new(0, 0, 0, CONTENT_Y)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.ClipsDescendants = true
	ContentFrame.Parent = InnerClip
	captureInput(ContentFrame)

	--  TAB STATE
	local _pages = {}
	local _navBtns = {}
	local _navUnderlines = {}
	local _tabNames = {}
	local _tabOrder = {}
	local _activeId = nil
	local _activePageConns = {}

	--  GLOBAL CUSTOM SCROLLBAR (Elegant curved tip solution)
	local GlobalScrollTrack = cloak(Instance.new("Frame"))
	GlobalScrollTrack.Size = UDim2.new(0, 4, 1, -40)
	GlobalScrollTrack.AnchorPoint = Vector2.new(1, 0.5)
	GlobalScrollTrack.Position = UDim2.new(1, -8, 0.5, 0)
	GlobalScrollTrack.BackgroundTransparency = 1
	GlobalScrollTrack.ZIndex = 10
	GlobalScrollTrack.Parent = ContentFrame

	local GlobalScrollThumb = cloak(Instance.new("Frame"))
	GlobalScrollThumb.BackgroundColor3 = T.Glow
	GlobalScrollThumb.BackgroundTransparency = 0.45
	GlobalScrollThumb.BorderSizePixel = 0
	GlobalScrollThumb.Parent = GlobalScrollTrack
	corner(GlobalScrollThumb, 3)

	local function updateGlobalScroll()
		local page = _pages[_activeId]
		if not page then
			GlobalScrollThumb.Visible = false
			return
		end

		local canvasH = math.max(1, page.AbsoluteCanvasSize.Y)
		local viewH = math.max(1, page.AbsoluteWindowSize.Y)
		if canvasH <= viewH then
			GlobalScrollThumb.Visible = false
			return
		end

		GlobalScrollThumb.Visible = true
		local ratio = viewH / canvasH
		local trackH = GlobalScrollTrack.AbsoluteSize.Y
		local thumbH = math.max(20, trackH * ratio)

		GlobalScrollThumb.Size = UDim2.new(1, 0, 0, thumbH)

		local trackScrollable = trackH - thumbH
		local canvasScrollable = canvasH - viewH
		local scrollRatio = page.CanvasPosition.Y / canvasScrollable

		GlobalScrollThumb.Position = UDim2.new(0, 0, 0, trackScrollable * scrollRatio)
	end

	local function activateTab(id)
		_activeId = id
		if InputManager.ListeningKeybind and InputManager.ListeningKeybind.Scope ~= id then
			InputManager:CancelListening(InputManager.ListeningKeybind)
		end
		if InputManager.ActiveSlider and InputManager.ActiveSlider.Scope ~= id then
			InputManager.ActiveSlider = nil
		end
		for tid, page in pairs(_pages) do
			page.Visible = (tid == id)
		end
		for tid, btn in pairs(_navBtns) do
			local on = (tid == id)
			qt(btn, {
				TextColor3 = on and T.Primary or T.Secondary,
				TextTransparency = on and 0 or T.SecTransp,
			}, 0.28)
			local ul = _navUnderlines[tid]
			if ul then
				ul.Visible = on
			end
		end

		for _, conn in ipairs(_activePageConns) do
			safeDisconnect(conn)
		end
		_activePageConns = {}

		local page = _pages[id]
		if page then
			table.insert(_activePageConns, page:GetPropertyChangedSignal("CanvasPosition"):Connect(updateGlobalScroll))
			table.insert(_activePageConns, page:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateGlobalScroll))
			table.insert(_activePageConns, page:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateGlobalScroll))
			task.defer(updateGlobalScroll)
		else
			GlobalScrollThumb.Visible = false
		end
	end

	--  DRAG
	local dragState = {}
	dragState.Active = false
	dragState.Start = nil
	dragState.StartPos = nil
	dragState.Input = nil
	dragState.Alive = function()
		return Main.Parent ~= nil and Header.Parent ~= nil
	end
	dragState.Update = function(pos)
		if not dragState.Active or not dragState.Start or not dragState.StartPos then
			return
		end
		local d = pos - dragState.Start
		Main.Position = UDim2.new(
			dragState.StartPos.X.Scale,
			dragState.StartPos.X.Offset + d.X,
			dragState.StartPos.Y.Scale,
			dragState.StartPos.Y.Offset + d.Y
		)
	end

	trackConnection(Header.InputBegan:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if InputManager.ActiveSlider or (InputManager.DragState and InputManager.DragState.Active) then
			return
		end
		dragState.Active = true
		dragState.Input = inp
		dragState.Start = inp.Position
		dragState.StartPos = Main.Position
		InputManager.DragState = dragState
	end))

	--  COLLAPSE
	local _collapsed = false
	ColBtn.MouseButton1Click:Connect(function()
		_collapsed = not _collapsed
		if _collapsed then
			Main:SetAttribute("ExpandedY", WIN_H)
			qt(Main, { Size = UDim2.new(0, WIN_W, 0, HDR_H) }, 0.5, Enum.EasingStyle.Exponential)
			qt(ColIcon, { Rotation = -90 }, 0.4, Enum.EasingStyle.Back)
		else
			local tY = Main:GetAttribute("ExpandedY") or WIN_H
			qt(Main, { Size = UDim2.new(0, WIN_W, 0, tY) }, 0.5, Enum.EasingStyle.Exponential)
			qt(ColIcon, { Rotation = 0 }, 0.4, Enum.EasingStyle.Back)
		end
	end)

	--  VISIBILITY KEYBIND
	local _visible = true
	InputManager.ToggleHandler = {
		Alive = function()
			return Main.Parent ~= nil and not _destroyed
		end,
		GetKey = function()
			return toggleKey
		end,
		Callback = function()
			_visible = not _visible
				Main.Visible = _visible
				if _visible then
					VaporLens:Notify({
						Title = safeText(cfg.Title, "Vapor Lens"),
						Content = "Interface restored.",
						Icon = "monitor",
						Duration = 3,
					})
			end
		end,
	}

	--  ENTRANCE ANIMATION
	Main.BackgroundTransparency = 1
	GlassBase.BackgroundTransparency = 1
	GlassSheen.BackgroundTransparency = 1
	InnerGlassStroke.Transparency = 1
	Main.Size = UDim2.new(0, WIN_W * 0.94, 0, WIN_H * 0.94)
	Main.Position = UDim2.new(0.5, -math.floor(WIN_W * 0.47), 0.5, -math.floor(WIN_H * 0.47))
	task.delay(0.04, function()
		if _destroyed or sessionId ~= _sessionId or not Main.Parent then
			return
		end
		qt(Main, {
			BackgroundTransparency = T.GlassTransp,
			Size = UDim2.new(0, WIN_W, 0, WIN_H),
			Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
		}, 0.52, Enum.EasingStyle.Exponential)
		qt(GlassBase, { BackgroundTransparency = 0.14 }, 0.52, Enum.EasingStyle.Exponential)
		qt(GlassSheen, { BackgroundTransparency = 0.93 }, 0.52, Enum.EasingStyle.Exponential)
		qt(InnerGlassStroke, { Transparency = 0.78 }, 0.52, Enum.EasingStyle.Exponential)
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
			tabName = safeText(titleOrCfg.Title or titleOrCfg.Name, "Tab")
			tabIcon = titleOrCfg.Icon
		else
			tabName = safeText(titleOrCfg, "Tab")
			tabIcon = iconName
		end
		local tabId = nextId("tab")

		-- Nav button (matches original: AutomaticSize.X, underline)
		local NavBtn = cloak(Instance.new("TextButton"))
		NavBtn.Size = UDim2.new(0, 0, 1, 0)
		NavBtn.AutomaticSize = Enum.AutomaticSize.X
		NavBtn.BackgroundTransparency = 1
		NavBtn.Text = string.upper(tabName)
		NavBtn.Font = FB
		NavBtn.TextSize = 13
		NavBtn.TextColor3 = T.Secondary
		NavBtn.TextTransparency = T.SecTransp
		NavBtn.Parent = Nav

		local Underline = cloak(Instance.new("Frame"))
		Underline.Size = UDim2.new(1, 0, 0, 2)
		Underline.Position = UDim2.new(0, 0, 1, -2)
		Underline.BackgroundColor3 = T.Glow
		Underline.BorderSizePixel = 0
		Underline.Visible = false
		Underline.Parent = NavBtn

		_navBtns[tabId] = NavBtn
		_navUnderlines[tabId] = Underline
		_tabNames[tabId] = tabName
		table.insert(_tabOrder, tabId)

		-- Scrollable page  fills the content frame, scrolls on Y
		local Page = cloak(Instance.new("ScrollingFrame"))
		Page.Size = UDim2.new(1, 0, 1, 0)
		Page.BackgroundTransparency = 1
		Page.BorderSizePixel = 0
		Page.ScrollBarThickness = 0 -- Ocultado o nativo em favor do GlobalScrollThumb
		Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		Page.CanvasSize = UDim2.new(0, 0, 0, 0)
		Page.Visible = false
		Page.Parent = ContentFrame
		captureInput(Page)
		pad(Page, PAD, PAD, PAD, PAD)
		vList(Page, 12)

		_pages[tabId] = Page
		if not _activeId then
			activateTab(tabId)
		end

		NavBtn.MouseButton1Click:Connect(function()
			activateTab(tabId)
		end)

		--
		--  TAB ELEMENT FACTORIES
		--
		local Tab = { Id = tabId, Name = tabName }

		function Tab:Destroy()
			if InputManager.ListeningKeybind and InputManager.ListeningKeybind.Scope == tabId then
				InputManager:CancelListening(InputManager.ListeningKeybind)
			end
			if InputManager.ActiveSlider and InputManager.ActiveSlider.Scope == tabId then
				InputManager.ActiveSlider = nil
			end
			if InputManager.DragState and InputManager.DragState.Scope == tabId then
				InputManager.DragState = nil
			end
			for id, binding in pairs(InputManager.Keybinds) do
				if binding.Scope == tabId then
					InputManager:UnregisterKeybind(id)
				end
			end

			_pages[tabId] = nil
			_navBtns[tabId] = nil
			_navUnderlines[tabId] = nil
			_tabNames[tabId] = nil

			local orderIndex = table.find(_tabOrder, tabId)
			if orderIndex then
				table.remove(_tabOrder, orderIndex)
			end

			if NavBtn.Parent then
				NavBtn:Destroy()
			end
			if Page.Parent then
				Page:Destroy()
			end

			if _activeId == tabId then
				_activeId = nil
				for _, nextTabId in ipairs(_tabOrder) do
					if _pages[nextTabId] then
						activateTab(nextTabId)
						break
					end
				end
			end
		end

		--  CreateSection
		function Tab:CreateSection(name)
			local Sec = cloak(Instance.new("Frame"))
			Sec.Size = UDim2.new(1, 0, 0, 28)
			Sec.BackgroundTransparency = 1
			Sec.Parent = Page

			local function sideLine(xScale, wScale)
				local f = cloak(Instance.new("Frame"))
				f.Size = UDim2.new(wScale, 0, 0, 1)
				f.Position = UDim2.new(xScale, 0, 0.5, 0)
				f.BackgroundColor3 = T.Border
				f.BackgroundTransparency = 0.80
				f.BorderSizePixel = 0
				f.Parent = Sec
			end
			sideLine(0, 0.14)
			sideLine(0.86, 0.14)

			local sl = cloak(Instance.new("TextLabel"))
			sl.Size = UDim2.new(0.72, 0, 1, 0)
			sl.Position = UDim2.new(0.14, 0, 0, 0)
			sl.BackgroundTransparency = 1
			sl.Text = string.upper(safeText(name, ""))
			sl.TextColor3 = T.Secondary
			sl.TextTransparency = T.SectionTransp
			sl.Font = FB
			sl.TextSize = 10
			sl.TextXAlignment = Enum.TextXAlignment.Center
			sl.TextTruncate = Enum.TextTruncate.AtEnd  -- prevent overflow past side lines
			sl.Parent = Sec
		end

		--  CreateToggle
		--  36×18 track, 14px ball  identical to v1.6 original
		function Tab:CreateToggle(s)
			s = asTable(s)
			local Row, _ = baseRow(Page)
			-- Toggle track: 36px wide, positioned at UDim2(1, -36, ...). Gap = 8px. Total = 44px.
			rowLabel(Row, safeText(s.Name, ""), 44)

			local isOn = s.CurrentValue == true

			local Track = cloak(Instance.new("TextButton"))
			Track.Size = UDim2.new(0, 36, 0, 18)
			Track.Position = UDim2.new(1, -36, 0.5, -9)
			Track.BackgroundColor3 = isOn and T.Glow or T.ToggleOff
			Track.Text = ""
			Track.Parent = Row
			corner(Track, 10)

			local Ball = cloak(Instance.new("Frame"))
			Ball.Size = UDim2.new(0, 14, 0, 14)
			Ball.Position = isOn and UDim2.new(0, 20, 0, 2) or UDim2.new(0, 2, 0, 2)
			Ball.BackgroundColor3 = Color3.new(1, 1, 1)
			Ball.Parent = Track
			corner(Ball, 7)

			local function applyState(on)
				qt(
					Ball,
					{ Position = on and UDim2.new(0, 20, 0, 2) or UDim2.new(0, 2, 0, 2) },
					0.3,
					Enum.EasingStyle.Quart
				)
				qt(Track, { BackgroundColor3 = on and T.Glow or T.ToggleOff }, 0.3)
			end

			Track.MouseButton1Click:Connect(function()
				isOn = not isOn
				applyState(isOn)
				s.CurrentValue = isOn
				if s.Flag then
					rememberFlag(s.Flag, s)
				end
				if s.Callback then
					runCallback(s.Callback, isOn)
				end
			end)

			s.CurrentValue = isOn
			if s.Flag then
				rememberFlag(s.Flag, s)
			end

			function s:Set(v)
				isOn = v == true
				applyState(isOn)
				s.CurrentValue = isOn
				if s.Callback then
					runCallback(s.Callback, isOn)
				end
			end

			return s
		end

		--  CreateSlider
		function Tab:CreateSlider(s)
			s = asTable(s)
			local range = asTable(s.Range)
			local minV = safeNumber(range[1], 0)
			local maxV = safeNumber(range[2], 100)
			if maxV < minV then
				minV, maxV = maxV, minV
			end
			local inc = safeNumber(s.Increment, 1, 0.000001)
			local suf = safeText(s.Suffix, "")
			local cur = math.clamp(safeNumber(s.CurrentValue, minV), minV, maxV)
			local span = math.max(maxV - minV, 1)

			local Row, _ = baseRow(Page, ELEM_TALL)

			-- Slider name label: shares top row with value label (right-aligned at 0.4 scale).
			-- Use 0.6 scale here since both labels are in the top half of the tall row. O(1).
			local nameLbl = cloak(Instance.new("TextLabel"))
			nameLbl.Size = UDim2.new(0.6, 0, 0, 22)
			nameLbl.Position = UDim2.new(0, 0, 0, 12)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = safeText(s.Name, "")
			nameLbl.TextColor3 = T.Primary
			nameLbl.Font = FB
			nameLbl.TextSize = 14
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.Parent = Row

			-- Value label right-aligned, glow colour (matches "82%" in original)
			local valLbl = cloak(Instance.new("TextLabel"))
			valLbl.Size = UDim2.new(0.4, 0, 0, 22)
			valLbl.Position = UDim2.new(0.6, 0, 0, 12)
			valLbl.BackgroundTransparency = 1
			valLbl.Text = tostring(cur) .. suf
			valLbl.TextColor3 = T.Glow
			valLbl.Font = FB
			valLbl.TextSize = 12
			valLbl.TextXAlignment = Enum.TextXAlignment.Right
			valLbl.Parent = Row

			local TrkBg = cloak(Instance.new("Frame"))
			TrkBg.Size = UDim2.new(1, 0, 0, 4)
			TrkBg.Position = UDim2.new(0, 0, 0, 52)
			TrkBg.BackgroundColor3 = T.SliderTrack
			TrkBg.BorderSizePixel = 0
			TrkBg.Parent = Row
			corner(TrkBg, 2)

			local Fill = cloak(Instance.new("Frame"))
			Fill.Size = UDim2.new((cur - minV) / span, 0, 1, 0)
			Fill.BackgroundColor3 = T.Glow
			Fill.BorderSizePixel = 0
			Fill.Parent = TrkBg
			corner(Fill, 2)

			local Thumb = cloak(Instance.new("Frame"))
			Thumb.Size = UDim2.new(0, 14, 0, 14)
			Thumb.AnchorPoint = Vector2.new(0.5, 0.5)
			Thumb.Position = UDim2.new((cur - minV) / span, 0, 0.5, 0)
			Thumb.BackgroundColor3 = Color3.new(1, 1, 1)
			Thumb.Parent = TrkBg
			corner(Thumb, 7)

			local function snap(v)
				return math.round((v - minV) / inc) * inc + minV
			end

			local function setVal(px)
				local rel = math.clamp((px - TrkBg.AbsolutePosition.X) / math.max(TrkBg.AbsoluteSize.X, 1), 0, 1)
				cur = math.clamp(snap(minV + rel * span), minV, maxV)
				local r2 = (cur - minV) / span
				Fill.Size = UDim2.new(r2, 0, 1, 0)
				Thumb.Position = UDim2.new(r2, 0, 0.5, 0)
				valLbl.Text = tostring(cur) .. suf
				s.CurrentValue = cur
				if s.Callback then
					runCallback(s.Callback, cur)
				end
			end

			local sliderController = {
				Scope = tabId,
				Alive = function()
					return TrkBg.Parent ~= nil and Row.Parent ~= nil
				end,
				Update = setVal,
			}

			TrkBg.InputBegan:Connect(function(inp)
				if
					inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.Touch
				then
					InputManager.ActiveSlider = sliderController
					setVal(inp.Position.X)
				end
			end)

			Row.AncestryChanged:Connect(function(_, parent)
				if parent == nil and InputManager.ActiveSlider == sliderController then
					InputManager.ActiveSlider = nil
				end
			end)

			s.CurrentValue = cur
			if s.Flag then
				rememberFlag(s.Flag, s)
			end

			function s:Set(v)
				cur = math.clamp(snap(safeNumber(v, cur)), minV, maxV)
				local r = (cur - minV) / span
				Fill.Size = UDim2.new(r, 0, 1, 0)
				Thumb.Position = UDim2.new(r, 0, 0.5, 0)
				valLbl.Text = tostring(cur) .. suf
				s.CurrentValue = cur
				if s.Callback then
					runCallback(s.Callback, cur)
				end
			end

			return s
		end

		--  CreateButton
		function Tab:CreateButton(s)
			s = asTable(s)
			local Row, _ = baseRow(Page)
			-- Button: max 88px wide (icon variant) + 8px gap = 96px right offset.
			local btnW = s.Icon and 88 or 72
			rowLabel(Row, safeText(s.Name, ""), btnW + 8)

			-- btnW already calculated above for rowLabel offset
			local RunBtn = cloak(Instance.new("TextButton"))
			RunBtn.Size = UDim2.new(0, btnW, 0, 26)
			RunBtn.Position = UDim2.new(1, -btnW, 0.5, -13)
			RunBtn.BackgroundColor3 = T.Glow
			RunBtn.BackgroundTransparency = 0.84
			RunBtn.Text = s.Icon and "" or "Run"
			RunBtn.TextColor3 = T.Glow
			RunBtn.Font = FB
			RunBtn.TextSize = 12
			RunBtn.Parent = Row
			corner(RunBtn, 7)
			stroke(RunBtn, T.Glow, 0.65, 1)

			if s.Icon then
				-- Icon + "Run" label laid out horizontally inside the button
				local inner = cloak(Instance.new("Frame"))
				inner.Size = UDim2.new(1, -8, 1, 0)
				inner.Position = UDim2.new(0, 4, 0, 0)
				inner.BackgroundTransparency = 1
				inner.Parent = RunBtn
				hList(inner, 4, Enum.VerticalAlignment.Center)

				local ico = icoLabel(inner, 14, T.Glow)
				applyIcon(ico, s.Icon)

				local runLbl = cloak(Instance.new("TextLabel"))
				runLbl.Size = UDim2.new(1, -18, 1, 0)
				runLbl.BackgroundTransparency = 1
				runLbl.Text = "Run"
				runLbl.TextColor3 = T.Glow
				runLbl.Font = FB
				runLbl.TextSize = 12
				runLbl.TextXAlignment = Enum.TextXAlignment.Left
				runLbl.Parent = inner
			end

			RunBtn.MouseButton1Click:Connect(function()
				qt(RunBtn, { BackgroundTransparency = 0.55 }, 0.08)
				task.delay(0.12, function()
					qt(RunBtn, { BackgroundTransparency = 0.84 }, 0.22)
				end)
				runCallback(s.Callback)
			end)

			function s:Set(label)
				if not s.Icon then
					RunBtn.Text = safeText(label, safeText(s.Name, ""))
				end
			end

			return s
		end

		--  CreateInput
		function Tab:CreateInput(s)
			s = asTable(s)
			local Row, _ = baseRow(Page)
			-- Input frame: 152px wide + 8px gap = 160px right offset.
			rowLabel(Row, safeText(s.Name, ""), 160)

			local IFrm = cloak(Instance.new("Frame"))
			IFrm.Size = UDim2.new(0, 152, 0, 26)
			IFrm.Position = UDim2.new(1, -152, 0.5, -13)
			IFrm.BackgroundColor3 = T.InputBg
			IFrm.ClipsDescendants = true
			IFrm.Parent = Row
			corner(IFrm, 7)
			stroke(IFrm, T.Border, 0.80, 1)

			local IBox = cloak(Instance.new("TextBox"))
			IBox.Size = UDim2.new(1, -18, 1, 0)
			IBox.Position = UDim2.new(0, 9, 0, 0)
			IBox.BackgroundTransparency = 1
			IBox.Text = safeText(s.CurrentValue, "")
			IBox.PlaceholderText = safeText(s.PlaceholderText, "Enter value...")
			IBox.PlaceholderColor3 = Color3.fromRGB(88, 88, 100)
			IBox.TextColor3 = T.Primary
			IBox.Font = FB
			IBox.TextSize = 12
			IBox.ClearTextOnFocus = false
			IBox.TextXAlignment = Enum.TextXAlignment.Left
			IBox.TextTruncate = Enum.TextTruncate.AtEnd
			IBox.TextWrapped = false
			IBox.Parent = IFrm

			IBox.FocusLost:Connect(function()
				s.CurrentValue = IBox.Text
				if s.RemoveTextAfterFocusLost then
					IBox.Text = ""
				end
				if s.Flag then
					rememberFlag(s.Flag, s)
				end
				if s.Callback then
					runCallback(s.Callback, s.CurrentValue)
				end
			end)

			local maxLength = type(s.MaxLength) == "number" and math.max(0, math.floor(s.MaxLength)) or nil
			if maxLength then
				-- Truncate silently; do NOT fire Callback on truncation
				IBox:GetPropertyChangedSignal("Text"):Connect(function()
					if #IBox.Text > maxLength then
						IBox.Text = string.sub(IBox.Text, 1, maxLength)
					end
				end)
			end

			if s.Flag then
				rememberFlag(s.Flag, s)
			end

			function s:Set(v)
				IBox.Text = safeText(v, "")
				s.CurrentValue = IBox.Text
				if s.Callback then
					runCallback(s.Callback, s.CurrentValue)
				end
			end

			return s
		end

		--  CreateKeybind
		function Tab:CreateKeybind(s)
			s = asTable(s)
			local Row, _ = baseRow(Page)
			-- Keybind button: 96px wide + 8px gap = 104px right offset.
			rowLabel(Row, safeText(s.Name, ""), 104)

			local cur = safeKeyCode(s.CurrentKeybind, Enum.KeyCode.Unknown)
			local listening = false

			local KBtn = cloak(Instance.new("TextButton"))
			KBtn.Size = UDim2.new(0, 96, 0, 26)
			KBtn.Position = UDim2.new(1, -96, 0.5, -13)
			KBtn.BackgroundColor3 = T.ToggleOff
			KBtn.Text = (typeof(cur) == "EnumItem") and cur.Name or tostring(cur)
			KBtn.TextColor3 = T.Glow
			KBtn.Font = FB
			KBtn.TextSize = 12
			KBtn.Parent = Row
			corner(KBtn, 6)
			stroke(KBtn, T.Glow, 0.60, 1)

			local keybindController
			local bindingId = nil

			local function updateVisual()
				if listening then
					KBtn.Text = "[ ... ]"
					KBtn.TextColor3 = T.Secondary
					return
				end
				KBtn.Text = (typeof(cur) == "EnumItem") and cur.Name or tostring(cur)
				KBtn.TextColor3 = T.Glow
			end

			local function applyKey(key, triggerChange)
				cur = safeKeyCode(key, Enum.KeyCode.Unknown)
				listening = false
				s.CurrentKeybind = cur
				updateVisual()
				if s.Flag then
					rememberFlag(s.Flag, s)
				end
				if triggerChange and s.CallOnChange and s.Callback then
					runCallback(s.Callback, cur)
				end
			end

			keybindController = {
				Scope = tabId,
				HoldToInteract = s.HoldToInteract == true,
				Held = false,
				Alive = function()
					return KBtn.Parent ~= nil and Row.Parent ~= nil
				end,
				GetKey = function()
					return cur
				end,
				Callback = (not s.CallOnChange) and s.Callback or nil,
				SetKey = function(key)
					applyKey(key, true)
				end,
				CancelListen = function()
					listening = false
					updateVisual()
				end,
			}

			bindingId = InputManager:RegisterKeybind(keybindController)

			KBtn.MouseButton1Click:Connect(function()
				if listening then
					return
				end
				if InputManager.ListeningKeybind and InputManager.ListeningKeybind ~= keybindController then
					InputManager:CancelListening(InputManager.ListeningKeybind)
				end
				listening = true
				updateVisual()
				InputManager.ListeningKeybind = keybindController
			end)

			Row.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					InputManager:UnregisterKeybind(bindingId)
					if InputManager.ListeningKeybind == keybindController then
						InputManager:CancelListening(keybindController)
					end
				end
			end)

			s.CurrentKeybind = cur
			if s.Flag then
				rememberFlag(s.Flag, s)
			end

			function s:Set(v)
				applyKey(v, false)
			end

			return s
		end

		--  CreateDropdown (full replacement: PlayerMode, avatar rows, height cap, click-outside backdrop)
		function Tab:CreateDropdown(s)
			s = asTable(s)
			local isMulti = s.MultipleOptions == true
			local isPlayerMode = s.PlayerMode == true
			local showSelf = s.ShowSelf ~= false -- default true

			local avatarScale = safeNumber(s.AvatarScale, 1.25, 0.5, 2)
			local displayNameScale = safeNumber(s.DisplayNameScale, 1.15, 0.5, 2)
			local usernameScale = safeNumber(s.UsernameScale, 1.15, 0.5, 2)

			local MAX_DROPDOWN_VISIBLE = 5
			local BASE_H = ELEM_H
			local ITEM_H = isPlayerMode and 44 or 34
			local isOpen = false
			local backdrop = nil -- fullscreen click-outside catcher
			local selectedPlayer = nil -- PlayerMode only
			local addedConn, removingConn

			local closedDropdownIcon = s.ClosedIcon or s.DropdownIcon or DEFAULT_DROPDOWN_ICON
			local openDropdownIcon = s.OpenIcon or s.DropdownIconOpen or closedDropdownIcon

			-- Options: array of strings (normal) or Player instances (PlayerMode)
			local options = {}
			if isPlayerMode then
				for _, p in ipairs(Players:GetPlayers()) do
					if showSelf or p ~= Players.LocalPlayer then
						table.insert(options, p)
					end
				end
			else
				options = normalizeOptions(s.Options)
			end

			-- Selection state for normal mode (keyed by string option value)
			local sel = {}
			if not isPlayerMode then
				if s.CurrentOption then
					if type(s.CurrentOption) == "table" then
						for _, v in ipairs(s.CurrentOption) do
							sel[safeText(v, "")] = true
						end
					elseif type(s.CurrentOption) == "string" then
						sel[s.CurrentOption] = true
					end
				elseif options[1] then
					sel[options[1]] = true
				end
			end

			local DD, ddStr = createDropdownShell(Page, BASE_H)

			local HeaderRow = cloak(Instance.new("Frame"))
			HeaderRow.Size = UDim2.new(1, 0, 0, BASE_H)
			HeaderRow.BackgroundTransparency = 1
			HeaderRow.ZIndex = 2
			HeaderRow.Parent = DD

			local syncDropdownHover = bindHoverState(DD, DD, ddStr, function()
				return isOpen
			end)

			-- Dropdown name label: right container uses 0.5 scale - 34px, plus 30px chevron zone.
			-- Constrain to 0.5 scale to prevent overlap with RightContainer. O(1).
			local nameLbl = cloak(Instance.new("TextLabel"))
			nameLbl.Size = UDim2.new(0.5, -8, 0, BASE_H)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = safeText(s.Name, "")
			nameLbl.TextColor3 = T.Primary
			nameLbl.Font = FB
			nameLbl.TextSize = 14
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.Parent = HeaderRow

			local RightContainer = cloak(Instance.new("Frame"))
			RightContainer.Size = UDim2.new(0.5, -34, 1, 0)
			RightContainer.Position = UDim2.new(1, -30, 0, 0)
			RightContainer.AnchorPoint = Vector2.new(1, 0)
			RightContainer.BackgroundTransparency = 1
			RightContainer.ClipsDescendants = true
			RightContainer.Parent = HeaderRow

			local RightLayout = cloak(Instance.new("UIListLayout"))
			RightLayout.FillDirection = Enum.FillDirection.Horizontal
			RightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			RightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
			RightLayout.Padding = UDim.new(0, 8)
			RightLayout.Parent = RightContainer

			-- LayoutOrder 1:
			local headerAvatar = nil
			if isPlayerMode then
				headerAvatar = cloak(Instance.new("ImageLabel"))
				local hAvSize = math.floor(22 * avatarScale)
				headerAvatar.Size = UDim2.new(0, hAvSize, 0, hAvSize)
				headerAvatar.BackgroundTransparency = 1
				headerAvatar.ImageTransparency = 1
				headerAvatar.ZIndex = 2
				headerAvatar.LayoutOrder = 1
				headerAvatar.Parent = RightContainer
				corner(headerAvatar, math.floor(hAvSize / 2))
			end

			-- LayoutOrder 2:
			local selLbl = cloak(Instance.new("TextLabel"))
			selLbl.Size = UDim2.new(1, 0, 1, 0)
			selLbl.BackgroundTransparency = 1
			selLbl.TextColor3 = T.Glow
			selLbl.TextTruncate = Enum.TextTruncate.AtEnd
			selLbl.Font = FB
			selLbl.TextSize = 12
			selLbl.TextXAlignment = Enum.TextXAlignment.Right
			selLbl.LayoutOrder = 2
			selLbl.Parent = RightContainer

			local chev = icoLabel(HeaderRow, 16, T.Glow)
			chev.AnchorPoint = Vector2.new(0.5, 0.5)
			chev.Position = UDim2.new(1, -8, 0, BASE_H / 2)

			local function syncDropdownChevron(opened)
				if opened then
					applyIcon(chev, openDropdownIcon)
					qt(chev, { Rotation = 180 }, 0.26)
				else
					applyIcon(chev, closedDropdownIcon)
					qt(chev, { Rotation = 0 }, 0.24)
				end
			end
			syncDropdownChevron(false)

			local ibtnList = {}
			local optSyncs = {} -- normal mode per-option sync fns

			local function closeBackdrop()
				if backdrop and backdrop.Parent then
					backdrop:Destroy()
				end
				backdrop = nil
			end

			local function closeDropdown()
				isOpen = false
				qt(DD, { Size = UDim2.new(1, 0, 0, BASE_H) }, 0.26, Enum.EasingStyle.Quart)
				syncDropdownChevron(false)
				closeBackdrop()
			end

			local function selText()
				if isPlayerMode then
					return selectedPlayer and selectedPlayer.DisplayName or "None"
				end
				local parts = {}
				for _, o in ipairs(options) do
					if sel[o] then
						table.insert(parts, o)
					end
				end
				if #parts == 0 then
					return "None"
				end
				if isMulti and #parts > 1 then
					return "Various"
				end
				return parts[1]
			end

			local function updateHeaderPlayer(player)
				selectedPlayer = player
				if headerAvatar then
					if player then
						-- rbxthumb URIs load silently; invalid userId shows nothing
						headerAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=48&h=48"
						qt(headerAvatar, { ImageTransparency = 0 }, 0.18)
					else
						qt(headerAvatar, { ImageTransparency = 1 }, 0.18)
					end
				end
				selLbl.Text = selText()
			end

			-- The item container is either a ScrollingFrame (>5 options) or a plain Frame
			local itemContainer = nil

			local function buildItemContainer()
				if itemContainer and itemContainer.Parent then
					itemContainer:Destroy()
				end
				itemContainer = nil
				ibtnList = {}

				local count = #options
				if count > MAX_DROPDOWN_VISIBLE then
					local sf = cloak(Instance.new("ScrollingFrame"))
					sf.Size = UDim2.new(1, 0, 1, -BASE_H)
					sf.Position = UDim2.new(0, 0, 0, BASE_H)
					sf.BackgroundTransparency = 1
					sf.BorderSizePixel = 0
					sf.ScrollBarThickness = 3
					sf.ScrollBarImageColor3 = T.Glow
					sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
					sf.CanvasSize = UDim2.new(0, 0, 0, 0)
					sf.ZIndex = 1
					sf.Parent = DD
					vList(sf, 0)
					itemContainer = sf
				else
					local plain = cloak(Instance.new("Frame"))
					plain.Size = UDim2.new(1, 0, 0, count * ITEM_H)
					plain.Position = UDim2.new(0, 0, 0, BASE_H)
					plain.BackgroundTransparency = 1
					plain.Parent = DD
					vList(plain, 0)
					itemContainer = plain
				end
			end

			local function buildItems()
				buildItemContainer()
				ibtnList = {}
				optSyncs = {}

				if isPlayerMode then
					for _, player in ipairs(options) do
						local isLocal = player == Players.LocalPlayer
						local isSelected = player == selectedPlayer

						local IBtn = cloak(Instance.new("TextButton"))
						IBtn.Size = UDim2.new(1, 0, 0, ITEM_H)
						IBtn.BackgroundColor3 = isSelected and T.Glow or T.ElemBg
						IBtn.BackgroundTransparency = isSelected and 0.84 or 0.99
						IBtn.Text = ""
						IBtn.ZIndex = 22
						IBtn.Parent = itemContainer
						corner(IBtn, 7)

						-- Avatar
						local avatarImg = cloak(Instance.new("ImageLabel"))
						local iAvSize = math.floor(24 * avatarScale)
						avatarImg.Size = UDim2.new(0, iAvSize, 0, iAvSize)
						avatarImg.Position = UDim2.new(0, 6, 0.5, -math.floor(iAvSize / 2))
						avatarImg.BackgroundTransparency = 1
						avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=48&h=48"
						avatarImg.ZIndex = 23
						avatarImg.Parent = IBtn
						corner(avatarImg, math.floor(iAvSize / 2))

						local txtBlock = cloak(Instance.new("Frame"))
						txtBlock.Size = UDim2.new(1, -(12 + iAvSize), 1, 0)
						txtBlock.Position = UDim2.new(0, 6 + iAvSize + 6, 0, 0)
						txtBlock.BackgroundTransparency = 1
						txtBlock.Parent = IBtn

						local dispLbl = cloak(Instance.new("TextLabel"))
						dispLbl.Size = UDim2.new(1, 0, 0, 14)
						dispLbl.Position = UDim2.new(0, 0, 0.5, -14)
						dispLbl.BackgroundTransparency = 1
						dispLbl.Text = player.DisplayName
						dispLbl.TextColor3 = T.Primary
						dispLbl.Font = FB
						dispLbl.TextSize = 13 * displayNameScale
						dispLbl.TextXAlignment = Enum.TextXAlignment.Left
						dispLbl.Parent = txtBlock

						local userLbl = cloak(Instance.new("TextLabel"))
						userLbl.Size = UDim2.new(1, 0, 0, 12)
						userLbl.Position = UDim2.new(0, 0, 0.5, 2)
						userLbl.BackgroundTransparency = 1
						userLbl.Text = "@" .. player.Name
						userLbl.TextColor3 = T.Secondary
						userLbl.TextTransparency = T.SecTransp
						userLbl.Font = FB
						userLbl.TextSize = 10 * usernameScale
						userLbl.TextXAlignment = Enum.TextXAlignment.Left
						userLbl.Parent = txtBlock

						table.insert(ibtnList, IBtn)

						IBtn.MouseButton1Click:Connect(function()
							updateHeaderPlayer(player)
							s.CurrentOption = player
							if s.Flag then
								rememberFlag(s.Flag, s)
							end
							if s.Callback then
								runCallback(s.Callback, player)
							end
							closeDropdown()
						end)
					end
				else
					-- Normal (string) mode
					for _, opt in ipairs(options) do
						local IBtn = cloak(Instance.new("TextButton"))
						IBtn.Size = UDim2.new(1, 0, 0, ITEM_H)
						IBtn.BackgroundColor3 = sel[opt] and T.Glow or T.ElemBg
						IBtn.BackgroundTransparency = sel[opt] and 0.84 or 0.99
						IBtn.Text = ""
						IBtn.ZIndex = 22
						IBtn.Parent = itemContainer
						corner(IBtn, 7)

						local ck = cloak(Instance.new("TextLabel"))
						ck.Size = UDim2.new(0, 20, 1, 0)
						ck.BackgroundTransparency = 1
						ck.Text = sel[opt] and "●" or ""
						ck.TextColor3 = T.Glow
						ck.Font = FB
						ck.TextSize = 11
						ck.Parent = IBtn

						local optLbl = cloak(Instance.new("TextLabel"))
						optLbl.Size = UDim2.new(1, -24, 1, 0)
						optLbl.Position = UDim2.new(0, 22, 0, 0)
						optLbl.BackgroundTransparency = 1
						optLbl.Text = opt
						optLbl.TextColor3 = sel[opt] and T.Glow or T.Primary
						optLbl.TextTransparency = sel[opt] and 0 or T.SecTransp
						optLbl.Font = FB
						optLbl.TextSize = 13
						optLbl.TextXAlignment = Enum.TextXAlignment.Left
						optLbl.Parent = IBtn

						local function sync()
							qt(IBtn, { BackgroundTransparency = sel[opt] and 0.84 or 0.99 }, 0.18)
							qt(IBtn, { BackgroundColor3 = sel[opt] and T.Glow or T.ElemBg }, 0.18)
							ck.Text = sel[opt] and "●" or ""
							qt(optLbl, {
								TextColor3 = sel[opt] and T.Glow or T.Primary,
								TextTransparency = sel[opt] and 0 or T.SecTransp,
							}, 0.18)
						end
						optSyncs[opt] = sync

						table.insert(ibtnList, IBtn)

						IBtn.MouseButton1Click:Connect(function()
							if isMulti then
								sel[opt] = not sel[opt]
							else
								for k in pairs(sel) do
									sel[k] = false
								end
								sel[opt] = true
							end
							for _, fn in pairs(optSyncs) do
								fn()
							end
							selLbl.Text = selText()

							local chosen = {}
							for _, o in ipairs(options) do
								if sel[o] then
									table.insert(chosen, o)
								end
							end
							s.CurrentOption = isMulti and chosen or chosen[1]
							if s.Flag then
								rememberFlag(s.Flag, s)
							end
							if s.Callback then
								runCallback(s.Callback, s.CurrentOption)
							end

							if not isMulti then
								closeDropdown()
							end
						end)
					end
				end
			end

			-- Initial build
			buildItems()
			selLbl.Text = selText()

			-- PlayerMode: live player tracking via PlayerAdded / PlayerRemoving
			if isPlayerMode then
				local function rebuildPlayerOptions()
					options = {}
					for _, p in ipairs(Players:GetPlayers()) do
						if showSelf or p ~= Players.LocalPlayer then
							table.insert(options, p)
						end
					end

					-- If selected player is gone, reset selection
					if selectedPlayer then
						local found = false
						for _, p in ipairs(options) do
							if p == selectedPlayer then
								found = true
								break
							end
						end
						if not found then
							updateHeaderPlayer(nil)
							s.CurrentOption = nil
							if s.Callback then
								runCallback(s.Callback, nil)
							end
							if isOpen then
								closeDropdown()
							end
						end
					end

					buildItems()
					selLbl.Text = selText()

					if isOpen then
						local expandH = BASE_H + math.min(#options, MAX_DROPDOWN_VISIBLE) * ITEM_H
						DD.Size = UDim2.new(1, 0, 0, expandH)
					end
				end

				addedConn = Players.PlayerAdded:Connect(function()
					rebuildPlayerOptions()
				end)
				removingConn = Players.PlayerRemoving:Connect(function()
					task.defer(rebuildPlayerOptions)
				end)

				-- Clean up connections when the dropdown element is removed from the hierarchy
				DD.AncestryChanged:Connect(function(_, parent)
					if parent == nil then
						if addedConn then
							addedConn:Disconnect()
							addedConn = nil
						end
						if removingConn then
							removingConn:Disconnect()
							removingConn = nil
						end
						closeBackdrop()
					end
				end)
			end

			-- Interact button sits over the header row (ZIndex 5, invisible)
			local Interact = cloak(Instance.new("TextButton"))
			Interact.Size = UDim2.new(1, 0, 0, BASE_H)
			Interact.BackgroundTransparency = 1
			Interact.Text = ""
			Interact.ZIndex = 5
			Interact.Parent = HeaderRow

			Interact.MouseButton1Click:Connect(function()
				if InputManager.ActiveSlider or (InputManager.DragState and InputManager.DragState.Active) then
					return
				end
				isOpen = not isOpen
				if isOpen then
					local expandH = BASE_H + (math.min(#options, MAX_DROPDOWN_VISIBLE) * ITEM_H) + 8
					qt(DD, { Size = UDim2.new(1, 0, 0, expandH) }, 0.32, Enum.EasingStyle.Quart)
					syncDropdownChevron(true)

					-- Fullscreen transparent button blocks underlying controls while the dropdown owns pointer input.
					closeBackdrop()
					backdrop = cloak(Instance.new("TextButton"))
					backdrop.Size = UDim2.new(1, 0, 1, 0)
					backdrop.BackgroundTransparency = 1
					backdrop.Text = ""
					backdrop.ZIndex = 19
					backdrop.Parent = Main
					DD.ZIndex = 20
					HeaderRow.ZIndex = 21
					Interact.ZIndex = 24
					if itemContainer then
						itemContainer.ZIndex = 21
					end
					backdrop.MouseButton1Click:Connect(function()
						closeDropdown()
					end)
				else
					closeDropdown()
				end
				syncDropdownHover(false, false)
			end)

			-- Initial option state for normal mode
			if not isPlayerMode then
				local initialChosen = {}
				for _, o in ipairs(options) do
					if sel[o] then
						table.insert(initialChosen, o)
					end
				end
				s.CurrentOption = isMulti and initialChosen or initialChosen[1]
				if s.Flag then
					rememberFlag(s.Flag, s)
				end
			end

			function s:Set(v)
				if isPlayerMode then
					if typeof(v) == "Instance" and v:IsA("Player") then
						updateHeaderPlayer(v)
					else
						updateHeaderPlayer(nil)
					end
					s.CurrentOption = selectedPlayer
				else
					for k in pairs(sel) do
						sel[k] = false
					end
					if type(v) == "table" then
						for _, val in ipairs(v) do
							sel[safeText(val, "")] = true
						end
					else
						sel[safeText(v, "")] = true
					end
					local chosen = {}
					for _, o in ipairs(options) do
						if sel[o] then
							table.insert(chosen, o)
						end
					end
					s.CurrentOption = isMulti and chosen or chosen[1]
					for _, fn in pairs(optSyncs) do
						fn()
					end
					selLbl.Text = selText()
				end
				if s.Flag then
					rememberFlag(s.Flag, s)
				end
				closeDropdown()
			end

			function s:Refresh()
				if not isPlayerMode then
					return
				end
				options = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if showSelf or p ~= Players.LocalPlayer then
						table.insert(options, p)
					end
				end
				buildItems()
				selLbl.Text = selText()
			end

			function s:GetSelected()
				return selectedPlayer
			end

			return s
		end

		--  CreatePlayerDropdown: convenience wrapper that enables PlayerMode
		function Tab:CreatePlayerDropdown(s)
			s = asTable(s)
			s.PlayerMode = true
			return self:CreateDropdown(s)
		end

		--  CreateProgressBar
		function Tab:CreateProgressBar(s)
			s = asTable(s)
			local maxV = safeNumber(s.Max, 100, 0.000001)
			local cur = math.clamp(safeNumber(s.Value, 0), 0, maxV)
			local suf = safeText(s.Suffix, "")
			local col = safeColor(s.Color, T.Glow)
			local span = math.max(maxV, 1)

			local Row, _ = baseRow(Page, ELEM_TALL)

			-- ProgressBar name label: same layout as Slider (0.6 scale, top row). O(1).
			local nameLbl = cloak(Instance.new("TextLabel"))
			nameLbl.Size = UDim2.new(0.6, 0, 0, 22)
			nameLbl.Position = UDim2.new(0, 0, 0, 12)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = safeText(s.Name, "")
			nameLbl.TextColor3 = T.Primary
			nameLbl.Font = FB
			nameLbl.TextSize = 14
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.Parent = Row

			local valLbl = cloak(Instance.new("TextLabel"))
			valLbl.Size = UDim2.new(0.4, 0, 0, 22)
			valLbl.Position = UDim2.new(0.6, 0, 0, 12)
			valLbl.BackgroundTransparency = 1
			valLbl.Text = tostring(cur) .. suf
			valLbl.TextColor3 = col
			valLbl.Font = FB
			valLbl.TextSize = 12
			valLbl.TextXAlignment = Enum.TextXAlignment.Right
			valLbl.Parent = Row

			local TrkBg = cloak(Instance.new("Frame"))
			TrkBg.Size = UDim2.new(1, 0, 0, 4)
			TrkBg.Position = UDim2.new(0, 0, 0, 52)
			TrkBg.BackgroundColor3 = T.SliderTrack
			TrkBg.BorderSizePixel = 0
			TrkBg.Parent = Row
			corner(TrkBg, 2)

			local Fill = cloak(Instance.new("Frame"))
			Fill.Size = UDim2.new(cur / span, 0, 1, 0)
			Fill.BackgroundColor3 = col
			Fill.BorderSizePixel = 0
			Fill.Parent = TrkBg
			corner(Fill, 2)

			s.CurrentValue = cur
			if s.Flag then
				rememberFlag(s.Flag, s)
			end

			function s:Set(value)
				cur = math.clamp(safeNumber(value, cur), 0, maxV)
				s.CurrentValue = cur
				qt(Fill, { Size = UDim2.new(cur / span, 0, 1, 0) }, 0.35, Enum.EasingStyle.Quart)
				valLbl.Text = tostring(cur) .. suf
			end

			return s
		end

		--  CreateLabel
		function Tab:CreateLabel(text, iconName, color)
			color = safeColor(color, nil)
			local Row = cloak(Instance.new("Frame"))
			Row.Size = UDim2.new(1, 0, 0, 34)
			Row.BackgroundColor3 = T.ElemBg
			Row.BackgroundTransparency = 0.99
			Row.Parent = Page
			corner(Row, 8)
			stroke(Row, T.Border, 0.94, 1)
			pad(Row, 16, 16, 0, 0)

			local hasIco = iconName ~= nil and iconName ~= ""
			local icoEl = icoLabel(Row, 15, color or T.Glow)
			icoEl.Position = UDim2.new(0, 0, 0.5, -7)
			if hasIco then
				applyIcon(icoEl, iconName)
			end

			local tx = hasIco and 22 or 0
			local lbl = cloak(Instance.new("TextLabel"))
			lbl.Size = UDim2.new(1, -tx, 1, 0)
			lbl.Position = UDim2.new(0, tx, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = safeText(text, "")
			lbl.TextColor3 = color or T.Secondary
			lbl.TextTransparency = color and 0 or T.SecTransp
			lbl.Font = FB
			lbl.TextSize = 12
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextWrapped = true
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Parent = Row

			local LV = {}
			function LV:Set(newText, newColor)
				lbl.Text = newText ~= nil and safeText(newText, lbl.Text) or lbl.Text
				newColor = safeColor(newColor, nil)
				if newColor then
					lbl.TextColor3 = newColor
					icoEl.ImageColor3 = newColor
				end
			end

			return LV
		end

		--  CreateParagraph
		function Tab:CreateParagraph(s)
			s = asTable(s)
			local Row = cloak(Instance.new("Frame"))
			Row.Size = UDim2.new(1, 0, 0, 84)
			Row.BackgroundColor3 = T.ElemBg
			Row.BackgroundTransparency = 0.99
			Row.Parent = Page
			corner(Row, 10)
			stroke(Row, T.Border, 0.94, 1)
			pad(Row, 16, 16, 10, 10)

			local tLbl = cloak(Instance.new("TextLabel"))
			tLbl.Size = UDim2.new(1, 0, 0, 18)
			tLbl.BackgroundTransparency = 1
			tLbl.Text = safeText(s.Title, "")
			tLbl.TextColor3 = T.Primary
			tLbl.Font = FB
			tLbl.TextSize = 14
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			tLbl.Parent = Row

			local cLbl = cloak(Instance.new("TextLabel"))
			cLbl.Size = UDim2.new(1, 0, 0, 44)
			cLbl.Position = UDim2.new(0, 0, 0, 24)
			cLbl.BackgroundTransparency = 1
			cLbl.Text = safeText(s.Content, "")
			cLbl.TextColor3 = T.Secondary
			cLbl.TextTransparency = T.SecTransp
			cLbl.Font = FM
			cLbl.TextSize = 12
			cLbl.TextXAlignment = Enum.TextXAlignment.Left
			cLbl.TextWrapped = true
			cLbl.Parent = Row

			local PV = {}
			function PV:Set(ns)
				ns = asTable(ns)
				tLbl.Text = ns.Title ~= nil and safeText(ns.Title, tLbl.Text) or tLbl.Text
				cLbl.Text = ns.Content ~= nil and safeText(ns.Content, cLbl.Text) or cLbl.Text
			end

			return PV
		end

		return Tab
	end -- CreateTab

	--  Window utilities
	function Window:SelectTab(name)
		local needle = string.lower(tostring(name or ""))
		for id, displayName in pairs(_tabNames) do
			if string.lower(displayName):find(needle, 1, true) then
				activateTab(id)
				return
			end
		end
	end

	function Window:SetToggleKey(key)
		key = safeKeyCode(key, Enum.KeyCode.Unknown)
		if key == nil or key == Enum.KeyCode.Unknown then
			toggleKey = nil -- explicitly disable toggle
			return
		end
		toggleKey = key
	end

	--  Window:CreateToggleKeybind(tabObj, cfg?)
	--  Creates a Keybind element on the given tab wired to update the global UI visibility toggle key.
	--  Accepts all standard CreateKeybind config. CurrentKeybind defaults to the active toggleKey.
	--  O(1) key update via shared toggleKey upvalue; no extra InputManager registrations.
	function Window:CreateToggleKeybind(tabObj, cfg)
		cfg = asTable(cfg)
		cfg.Name = cfg.Name or "Toggle UI Key"
		cfg.CurrentKeybind = cfg.CurrentKeybind or toggleKey
		cfg.CallOnChange = true
		local originalCallback = cfg.Callback
		cfg.Callback = function(newKey)
			toggleKey = newKey -- shared upvalue with ToggleHandler.GetKey
			if originalCallback then
				runCallback(originalCallback, newKey)
			end
		end
		return tabObj:CreateKeybind(cfg)
	end

	--  Window:CreateFloatingButton(cfg?)
	--
	--  AUDIT (v1.3):
	--  1. FIXED: Drag-triggers-click bug. Root cause: InputManager's global UIS.InputEnded
	--     clears fabDragState.Active BEFORE FabBtn.InputEnded fires on some executors/platforms,
	--     causing the `Active && !Dragged` tap check to fail unpredictably.
	--     Fix: Track the specific InputObject instance (_activeInput) to pair began/ended events.
	--     The local _wasDragged flag is independent of InputManager state.
	--  2. FIXED: Drag bounds used fixed BTN_SZ for width clamping; now uses Fab.AbsoluteSize.X.
	--  3. ADDED: cfg.DragEnabled, cfg.ClickCallback, cfg.DragThreshold, cfg.SnapToEdges,
	--     cfg.PulseOnClick, cfg.ZIndex config params.
	--  4. ADDED: :SetClickCallback, :SetDragEnabled, :SetDragThreshold, :SetSnapToEdges methods.
	--
	--  cfg.Icon           string    Lucide icon name or asset URI (default "eye")
	--  cfg.Text           string    optional label next to icon (pill shape when set)
	--  cfg.Size           number    button height in px (default 48, min 44 for touch)
	--  cfg.Position       UDim2     initial position (default bottom-left)
	--  cfg.Visible        boolean   initial visibility (default true)
	--  cfg.Flag           string    optional flag key for VaporLens.Flags
	--  cfg.DragEnabled    boolean   allow drag-to-reposition (default true)
	--  cfg.ClickCallback  function  custom tap callback; overrides default UI toggle when set
	--  cfg.DragThreshold  number    px movement to register drag (default 4, clamped 2-20)
	--  cfg.SnapToEdges    boolean   snap to nearest screen edge on drag end (default false)
	--  cfg.PulseOnClick   boolean   play visual pulse on tap (default true)
	--  cfg.ZIndex         number    override ZIndex (default 10)
	function Window:CreateFloatingButton(cfgBtn)
		cfgBtn = asTable(cfgBtn)

		-- Parameter validation. O(1).
		local BTN_SZ = math.floor(safeNumber(cfgBtn.Size, 48, 44, 96))
		local btnVisible = cfgBtn.Visible ~= false
		local btnSessionId = sessionId
		local btnText = safeText(cfgBtn.Text, "")
		local hasText = btnText ~= ""
		local dragEnabled = cfgBtn.DragEnabled ~= false
		local clickCallback = type(cfgBtn.ClickCallback) == "function" and cfgBtn.ClickCallback or nil
		local dragThreshold = safeNumber(cfgBtn.DragThreshold, 4, 2, 20)
		local snapToEdges = cfgBtn.SnapToEdges == true
		local pulseOnClick = cfgBtn.PulseOnClick ~= false
		local fabZIndex = math.floor(safeNumber(cfgBtn.ZIndex, 10, 1, 1000))

		-- Pill geometry constants
		local ICO_SZ = math.floor(BTN_SZ * 0.42)
		local TEXT_PAD_L = 6
		local TEXT_PAD_R = 14
		local PILL_RADIUS = math.floor(BTN_SZ / 2)

		local function measurePillWidth(text)
			text = safeText(text, "")
			if not text or text == "" then return BTN_SZ end
			local estW = math.ceil(#text * 7.2) -- GothamBold@13 ~7.2px/char
			return math.max(BTN_SZ + TEXT_PAD_L + estW + TEXT_PAD_R, BTN_SZ + 40)
		end

		local function getViewportSize()
			local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
			return (ok and vp) or Vector2.new(1920, 1080)
		end

		local fabWidth = measurePillWidth(btnText)

		-- Container frame
		local Fab = cloak(Instance.new("Frame"))
		Fab.Size = UDim2.new(0, fabWidth, 0, BTN_SZ)
		Fab.Position = (typeof(cfgBtn.Position) == "UDim2" and cfgBtn.Position)
			or UDim2.new(0, 20, 1, -(BTN_SZ + 20))
		Fab.BackgroundColor3 = T.Glass
		Fab.BackgroundTransparency = T.GlassTransp
		Fab.Visible = btnVisible
		Fab.ZIndex = fabZIndex
		Fab.Parent = sg
		captureInput(Fab)
		corner(Fab, PILL_RADIUS)
		local fabStroke = stroke(Fab, T.Glow, 0.45, 1.5)

		local FabGlow = cloak(Instance.new("Frame"))
		FabGlow.Size = UDim2.new(1, 0, 1, 0)
		FabGlow.BackgroundColor3 = T.Glow
		FabGlow.BackgroundTransparency = 0.92
		FabGlow.ZIndex = 0
		FabGlow.Parent = Fab
		corner(FabGlow, PILL_RADIUS)

		local fabIco = icoLabel(Fab, ICO_SZ, T.Glow)
		fabIco.AnchorPoint = Vector2.new(0.5, 0.5)
		fabIco.Position = UDim2.new(0, math.floor(BTN_SZ / 2), 0.5, 0)
		fabIco.ZIndex = 2
		applyIcon(fabIco, cfgBtn.Icon or "eye")

		local fabLbl = cloak(Instance.new("TextLabel"))
		fabLbl.Size = UDim2.new(1, -(BTN_SZ + TEXT_PAD_R), 1, 0)
		fabLbl.Position = UDim2.new(0, BTN_SZ + TEXT_PAD_L, 0, 0)
		fabLbl.BackgroundTransparency = 1
		fabLbl.Text = btnText
		fabLbl.TextColor3 = T.Primary
		fabLbl.Font = FB
		fabLbl.TextSize = 13
		fabLbl.TextXAlignment = Enum.TextXAlignment.Left
		fabLbl.TextTruncate = Enum.TextTruncate.AtEnd
		fabLbl.Visible = hasText
		fabLbl.ZIndex = 2
		fabLbl.Parent = Fab

		local FabBtn = cloak(Instance.new("TextButton"))
		FabBtn.Size = UDim2.new(1, 0, 1, 0)
		FabBtn.BackgroundTransparency = 1
		FabBtn.Text = ""
		FabBtn.ZIndex = fabZIndex + 1
		FabBtn.Parent = Fab

		-- INPUT STATE — fixes the drag-triggers-click bug.
		-- Tracks the specific InputObject to reliably pair began/ended events.
		-- _wasDragged is a local flag independent of InputManager.DragState.Active,
		-- which can be cleared by the global UIS.InputEnded handler before this fires.
		local _activeInput = nil  -- the InputObject that started the current interaction
		local _wasDragged = false
		local _dragStartPos = nil -- Fab absolute position at drag start (UDim2)

		-- Drag state registered with InputManager for position updates. O(1) per frame.
		local fabDragState = {}
		fabDragState.Active = false
		fabDragState.Start = nil
		fabDragState.StartPos = nil
		fabDragState.Alive = function()
			return Fab.Parent ~= nil and not _destroyed
		end
		fabDragState.Update = function(pos)
			if not _activeInput or not fabDragState.Start or not _dragStartPos then
				return
			end
			local d = pos - fabDragState.Start
			if d.Magnitude > dragThreshold then
				_wasDragged = true
			end
			if not dragEnabled then return end
			-- Clamp within screen bounds. O(1).
			local curW = Fab.AbsoluteSize.X
			local vpSize = getViewportSize()
			local newX = math.clamp(_dragStartPos.X.Offset + d.X, 0, vpSize.X - curW)
			local newY = math.clamp(_dragStartPos.Y.Offset + d.Y, 0, vpSize.Y - BTN_SZ)
			Fab.Position = UDim2.new(0, newX, 0, newY)
		end

		-- Snap to nearest horizontal screen edge. O(1).
		local function snapToEdge()
			if not snapToEdges then return end
			local vpSize = getViewportSize()
			local curX = Fab.AbsolutePosition.X
			local curW = Fab.AbsoluteSize.X
			local mid = vpSize.X / 2
			local targetX = (curX + curW / 2) < mid and 12 or (vpSize.X - curW - 12)
			qt(Fab, { Position = UDim2.new(0, targetX, Fab.Position.Y.Scale, Fab.Position.Y.Offset) }, 0.28, Enum.EasingStyle.Quart)
		end

		-- Visual pulse feedback. O(1).
		local function doPulse()
			if not pulseOnClick then return end
			qt(fabStroke, { Transparency = 0 }, 0.08)
			qt(FabGlow, { BackgroundTransparency = 0.75 }, 0.08)
			task.delay(0.15, function()
				if Fab.Parent then
					qt(fabStroke, { Transparency = 0.45 }, 0.22)
					qt(FabGlow, { BackgroundTransparency = 0.92 }, 0.22)
				end
			end)
		end

		-- InputBegan: start tracking a specific InputObject. O(1).
		FabBtn.InputBegan:Connect(function(inp)
			local t = inp.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
			if _activeInput then return end -- already tracking an interaction
			-- Yield to main window drag if active
			if InputManager.DragState and InputManager.DragState.Active then return end

			_activeInput = inp
			_wasDragged = false
			fabDragState.Active = true
			fabDragState.Start = inp.Position
			_dragStartPos = UDim2.new(0, Fab.AbsolutePosition.X, 0, Fab.AbsolutePosition.Y)
			fabDragState.StartPos = _dragStartPos
			InputManager.DragState = fabDragState
		end)

		-- InputEnded: only process the EXACT InputObject that began the interaction.
		-- This is the core fix: we no longer rely on fabDragState.Active (which can be
		-- cleared by InputManager's global UIS.InputEnded before this handler fires). O(1).
		FabBtn.InputEnded:Connect(function(inp)
			if inp ~= _activeInput then return end -- ignore unrelated inputs
			local wasDragged = _wasDragged

			-- Reset interaction state before firing callbacks (prevents re-entrancy issues)
			_activeInput = nil
			_wasDragged = false
			fabDragState.Active = false
			if InputManager.DragState == fabDragState then
				InputManager.DragState = nil
			end

			if wasDragged then
				-- Drag completed — optionally snap to edge
				snapToEdge()
			else
				-- Tap detected — fire click action. O(1).
				doPulse()
				if clickCallback then
					runCallback(clickCallback)
				else
					-- Default: toggle main UI visibility
					_visible = not _visible
					Main.Visible = _visible
					if _visible then
						VaporLens:Notify({
							Title = cfg.Title or "Vapor Lens",
							Content = "Interface restored.",
							Icon = "monitor",
							Duration = 3,
						})
					end
				end
			end
		end)

		-- Hover (desktop only)
		FabBtn.MouseEnter:Connect(function()
			qt(FabGlow, { BackgroundTransparency = 0.82 }, 0.18)
			qt(fabStroke, { Transparency = 0.20 }, 0.18)
		end)
		FabBtn.MouseLeave:Connect(function()
			qt(FabGlow, { BackgroundTransparency = 0.92 }, 0.18)
			qt(fabStroke, { Transparency = 0.45 }, 0.18)
		end)

		-- Entrance animation
		Fab.BackgroundTransparency = 1
		FabGlow.BackgroundTransparency = 1
		fabStroke.Transparency = 1
		fabIco.ImageTransparency = 1
		fabLbl.TextTransparency = 1
		task.delay(0.3, function()
			if _destroyed or btnSessionId ~= _sessionId or not Fab.Parent then return end
			qt(Fab, { BackgroundTransparency = T.GlassTransp }, 0.36, Enum.EasingStyle.Quart)
			qt(FabGlow, { BackgroundTransparency = 0.92 }, 0.36, Enum.EasingStyle.Quart)
			qt(fabStroke, { Transparency = 0.45 }, 0.36, Enum.EasingStyle.Quart)
			qt(fabIco, { ImageTransparency = 0 }, 0.36, Enum.EasingStyle.Quart)
			if hasText then
				qt(fabLbl, { TextTransparency = 0 }, 0.36, Enum.EasingStyle.Quart)
			end
		end)

		-- Cleanup on destroy: release drag state if mid-interaction
		Fab.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				_activeInput = nil
				_wasDragged = false
				if InputManager.DragState == fabDragState then
					InputManager.DragState = nil
				end
			end
		end)

		-- Config object. O(1) all methods.
		local fabConfig = { CurrentValue = btnVisible, Instance = Fab }

		function fabConfig:Set(v)
			if type(v) == "boolean" then
				btnVisible = v
				fabConfig.CurrentValue = v
				Fab.Visible = v
			end
		end

		function fabConfig:SetIcon(icon)
			if icon and Fab.Parent then applyIcon(fabIco, icon) end
		end

		function fabConfig:SetText(text)
			if not Fab.Parent then return end
			local nextText = safeText(text, "")
			local newHasText = nextText ~= ""
			hasText = newHasText
			fabLbl.Text = nextText
			fabLbl.Visible = newHasText
			qt(Fab, { Size = UDim2.new(0, measurePillWidth(nextText), 0, BTN_SZ) }, 0.28, Enum.EasingStyle.Quart)
			if newHasText then qt(fabLbl, { TextTransparency = 0 }, 0.28, Enum.EasingStyle.Quart) end
		end

		function fabConfig:SetPosition(pos)
			if typeof(pos) == "UDim2" and Fab.Parent then Fab.Position = pos end
		end

		function fabConfig:SetClickCallback(cb)
			clickCallback = type(cb) == "function" and cb or nil
		end

		function fabConfig:SetDragEnabled(v)
			dragEnabled = v == true
		end

		function fabConfig:SetDragThreshold(px)
			dragThreshold = math.clamp(type(px) == "number" and px or 4, 2, 20)
		end

		function fabConfig:SetSnapToEdges(v)
			snapToEdges = v == true
		end

		rememberFlag(cfgBtn.Flag, fabConfig)

		return fabConfig
	end

	function Window:Destroy()
		VaporLens:Destroy()
	end

	task.delay(0.7, function()
		if _destroyed or sessionId ~= _sessionId or not (_gui and _gui.Parent) then
			return
		end
		VaporLens:Notify({
			Title = cfg.Title or "Vapor Lens",
			Content = "Interface initialized.",
			Icon = "check-circle",
			Duration = 3,
		})
	end)

	return Window
end -- CreateWindow

return VaporLens
