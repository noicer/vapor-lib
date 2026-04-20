-- VaporLens v1.1 — Exemplo completo de uso
-- Carrega a lib via servidor local (ex: python -m http.server 80 na pasta do projeto)
local VaporLens = loadstring(game:HttpGet("http://localhost/vapor_test.lua"))()

-- ────────────────────────────────────────────────────────────
--  Configuração opcional de tema (deve vir ANTES de CreateWindow)
-- ────────────────────────────────────────────────────────────
VaporLens:SetTheme({
	Glow = Color3.fromRGB(0, 200, 255), -- accent ciano padrão
})

-- ────────────────────────────────────────────────────────────
--  Janela principal
-- ────────────────────────────────────────────────────────────
local Win = VaporLens:CreateWindow({
	Title = "Vapor Demo",
	Subtitle = "v1.1 — todos os elementos",
	Icon = "layers",
	ToggleKey = Enum.KeyCode.RightControl,
	Width = 320,
	Height = 420,
})

-- ════════════════════════════════════════════════════════════
--  TAB 1 — CONTROLES BÁSICOS
-- ════════════════════════════════════════════════════════════
local TabBasico = Win:CreateTab("Básico", "sliders-horizontal")

-- ───── Seção ─────
TabBasico:CreateSection("Toggles & Sliders")

-- Toggle simples
local togAimbot = TabBasico:CreateToggle({
	Name = "Aimbot",
	CurrentValue = false,
	Flag = "AimbotOn",
	Callback = function(v)
		print("[Aimbot]", v)
	end,
})

-- Toggle já ligado de início
local togESP = TabBasico:CreateToggle({
	Name = "ESP",
	CurrentValue = true,
	Flag = "ESPOn",
	Callback = function(v)
		print("[ESP]", v)
	end,
})

-- Slider básico
local sliderFOV = TabBasico:CreateSlider({
	Name = "FOV",
	Range = { 10, 360 },
	Increment = 5,
	Suffix = "°",
	CurrentValue = 90,
	Flag = "AimbotFOV",
	Callback = function(v)
		print("[FOV]", v)
	end,
})

-- Slider de velocidade
local sliderSpeed = TabBasico:CreateSlider({
	Name = "Velocidade",
	Range = { 16, 100 },
	Increment = 1,
	Suffix = " u/s",
	CurrentValue = 16,
	Callback = function(v)
		print("[Speed]", v)
	end,
})

-- ───── Seção ─────
TabBasico:CreateSection("Botões")

-- Botão simples (sem ícone)
TabBasico:CreateButton({
	Name = "Teleportar ao Spawn",
	Callback = function()
		print("[Teleport] executado")
		VaporLens:Notify({
			Title = "Teleporte",
			Content = "Teleportando ao spawn...",
			Icon = "map-pin",
			Duration = 3,
		})
	end,
})

-- Botão com ícone (Task 4 — largura 88px)
TabBasico:CreateButton({
	Name = "Executar Script",
	Icon = "zap",
	Callback = function()
		print("[Script] executado")
		VaporLens:Notify({
			Title = "Script",
			Content = "Rodando...",
			Icon = "terminal",
			Duration = 2,
		})
	end,
})

-- Botão com ícone diferente
TabBasico:CreateButton({
	Name = "Limpar Workspace",
	Icon = "trash-2",
	Callback = function()
		print("[Clear] workspace limpo")
	end,
})

-- ════════════════════════════════════════════════════════════
--  TAB 2 — DROPDOWN & JOGADORES
-- ════════════════════════════════════════════════════════════
local TabDrop = Win:CreateTab("Dropdown", "list")

TabDrop:CreateSection("Dropdown Padrão")

-- Dropdown simples, seleção única
local ddTarget = TabDrop:CreateDropdown({
	Name = "Parte Alvo",
	Options = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },
	CurrentOption = { "Head" },
	MultipleOptions = false,
	Flag = "AimbotPart",
	Callback = function(opt)
		print("[Target]", opt)
	end,
})

-- Dropdown com múltipla seleção (mais de 5 opções → scroll interno)
local ddWeapons = TabDrop:CreateDropdown({
	Name = "Armas Ativas",
	Options = { "Pistola", "Rifle", "Shotgun", "Sniper", "SMG", "LMG", "Lançador" },
	CurrentOption = { "Rifle" },
	MultipleOptions = true,
	Callback = function(opts)
		-- opts é uma tabela quando MultipleOptions = true
		print("[Weapons]", table.concat(type(opts) == "table" and opts or { tostring(opts) }, ", "))
	end,
})

TabDrop:CreateSection("Dropdown de Jogadores")

-- Dropdown player-aware (Task 1a/1b): mostra avatares, rastreia joins/leaves
local ddPlayer = TabDrop:CreatePlayerDropdown({
	Name = "Focar Jogador",
	ShowSelf = false,
	AvatarScale = 1.25, -- oculta o próprio LocalPlayer
	DisplayNameScale = 1.15,
	UsernameScale = 1.15,
	Callback = function(player)
		if player then
			print("[Focus]", player.Name, "(UserId:", player.UserId .. ")")
			VaporLens:Notify({
				Title = "Foco",
				Content = "Mirando em " .. player.DisplayName,
				Icon = "crosshair",
				Duration = 2,
			})
		else
			print("[Focus] nenhum jogador selecionado")
		end
	end,
})

-- Botão para forçar refresh manual da lista de jogadores
TabDrop:CreateButton({
	Name = "Atualizar Lista",
	Icon = "refresh-cw",
	Callback = function()
		ddPlayer:Refresh()
		print("[PlayerDrop] refreshed. Selecionado:", tostring(ddPlayer:GetSelected()))
	end,
})

-- ════════════════════════════════════════════════════════════
--  TAB 3 — INPUT & KEYBIND
-- ════════════════════════════════════════════════════════════
local TabInput = Win:CreateTab("Input", "keyboard")

TabInput:CreateSection("Caixas de Texto")

-- Input simples
local inputNome = TabInput:CreateInput({
	Name = "Nome do Jogador",
	PlaceholderText = "ex: Roblox",
	CurrentValue = "",
	Callback = function(text)
		print("[Nome]", text)
	end,
})

-- Input com MaxLength (Task 5) — máximo 16 caracteres
local inputCmd = TabInput:CreateInput({
	Name = "Comando",
	PlaceholderText = "max 16 chars",
	MaxLength = 16,
	Callback = function(text)
		print("[Cmd]", text)
	end,
})

-- Input que limpa após confirmar
TabInput:CreateInput({
	Name = "Chat Rápido",
	PlaceholderText = "Mensagem...",
	RemoveTextAfterFocusLost = true,
	Callback = function(text)
		if text ~= "" then
			print("[Chat]", text)
		end
	end,
})

TabInput:CreateSection("Keybind")

-- Keybind simples (dispara ao pressionar)
local kbToggle = TabInput:CreateKeybind({
	Name = "Toggle Aimbot",
	CurrentKeybind = Enum.KeyCode.F,
	Flag = "AimbotKey",
	Callback = function(key)
		print("[Keybind] pressionado:", key.Name)
		togAimbot:Set(
			not VaporLens.Flags["AimbotOn"]
					and VaporLens.Flags["AimbotOn"] ~= nil
					and VaporLens.Flags["AimbotOn"].CurrentValue
				or false
		)
	end,
})

-- Keybind hold-to-interact
TabInput:CreateKeybind({
	Name = "Sprint",
	CurrentKeybind = Enum.KeyCode.LeftShift,
	HoldToInteract = true,
	Callback = function(held)
		print("[Sprint]", held and "iniciado" or "parado")
	end,
})

-- ════════════════════════════════════════════════════════════
--  TAB 4 — PROGRESSO & GRID
-- ════════════════════════════════════════════════════════════
local TabExtra = Win:CreateTab("Extra", "grid-2x2")

TabExtra:CreateSection("Barras de Progresso")

-- Barra de HP
local barHP = TabExtra:CreateProgressBar({
	Name = "HP",
	Value = 100,
	Max = 100,
	Suffix = "%",
	Color = Color3.fromRGB(80, 220, 100),
})

-- Barra de Munição
local barAmmo = TabExtra:CreateProgressBar({
	Name = "Munição",
	Value = 30,
	Max = 30,
	Suffix = " balas",
	Color = Color3.fromRGB(255, 200, 50),
})

-- Barra de XP (parcialmente cheia)
local barXP = TabExtra:CreateProgressBar({
	Name = "XP",
	Value = 47,
	Max = 100,
	Suffix = " xp",
})

-- Botão para simular dano (decrementa HP)
TabExtra:CreateButton({
	Name = "Simular Dano (-10 HP)",
	Icon = "heart",
	Callback = function()
		local cur = VaporLens.Flags["BarHP"] or 100
		cur = math.clamp(cur - 10, 0, 100)
		VaporLens.Flags["BarHP"] = cur
		barHP:Set(cur)
		print("[HP]", cur)
	end,
})

-- Botão para simular recarga
TabExtra:CreateButton({
	Name = "Recarregar",
	Icon = "rotate-ccw",
	Callback = function()
		barAmmo:Set(30)
		print("[Ammo] recarregada")
	end,
})

-- ════════════════════════════════════════════════════════════
--  TAB 5 — LABELS & PARAGRAFO
-- ════════════════════════════════════════════════════════════
local TabInfo = Win:CreateTab("Info", "info")

TabInfo:CreateSection("Labels")

local lbStatus = TabInfo:CreateLabel("Sistema iniciado com sucesso.", "check-circle", Color3.fromRGB(80, 220, 100))
TabInfo:CreateLabel("Atenção: use por sua conta e risco.", "alert-triangle", Color3.fromRGB(255, 180, 50))
TabInfo:CreateLabel("Pressione RCtrl para mostrar/ocultar.", "eye")

TabInfo:CreateSection("Parágrafo")

TabInfo:CreateParagraph({
	Title = "Sobre o Script",
	Content = "Este é um exemplo demonstrando todos os elementos disponíveis na VaporLens v1.1. "
		.. "Novidades: CreatePlayerDropdown com avatares, CreateProgressBar, CreateGrid, "
		.. "ícone em CreateButton e MaxLength em CreateInput.",
})

TabInfo:CreateParagraph({
	Title = "Atalhos",
	Content = "RightControl — toggle da janela\nF — toggle aimbot (keybind configurável)\nLShift (hold) — sprint",
})

-- ────────────────────────────────────────────────────────────
--  Notificação de boas-vindas
-- ────────────────────────────────────────────────────────────
task.delay(1.2, function()
	VaporLens:Notify({
		Title = "Vapor Demo",
		Content = "Todos os elementos carregados!",
		Icon = "sparkles",
		Duration = 5,
	})
end)

-- ────────────────────────────────────────────────────────────
--  Exemplo de uso das APIs programáticas
-- ────────────────────────────────────────────────────────────
task.delay(3, function()
	-- Simula dano progressivo na barra de HP
	for i = 90, 40, -10 do
		task.wait(0.8)
		barHP:Set(i)
	end
end)

task.delay(5, function()
	-- Muda seleção do dropdown via API
	ddTarget:Set("Torso")
	print("[API] Target setado para Torso")
end)

task.delay(7, function()
	-- Atualiza label de status
	lbStatus:Set("Executando há 7 segundos.", Color3.fromRGB(0, 200, 255))
end)
