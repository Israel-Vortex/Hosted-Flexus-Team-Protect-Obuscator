--[[
  FlexusHub · Loader + Intro
  Detecta juego (PlaceId / GameId / nombre) y carga el script.
  Si falla, intenta Universal. Multi-URL por si GitHub falla.
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

local function _rn(n)
	n = n or 10
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local s = ""
	for _ = 1, n do
		local i = math.random(1, #chars)
		s = s .. chars:sub(i, i)
	end
	return s
end

local function protectGui(gui)
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(gui) end
	end)
	pcall(function()
		if protect_gui then protect_gui(gui) end
	end)
	pcall(function()
		gui.Name = "Core" .. _rn(10)
	end)
end

local function parentHidden(gui)
	local ok = pcall(function()
		if gethui then
			gui.Parent = gethui()
			return true
		end
		return false
	end)
	if not ok then
		pcall(function()
			protectGui(gui)
			gui.Parent = CoreGui
		end)
	end
	if not gui.Parent then
		pcall(function()
			gui.Parent = PlayerGui
		end)
	end
end

local INTRO_AUDIO_URL =
	"https://www.image2url.com/r2/default/audio/1789249131827-a7aff83d-4a2d-4f1a-8f8d-d891a48b7f81.mp3"
local INTRO_FILE = "flexushub_intro_cache.mp3"
local LOGO_ID = "rbxassetid://78482030075403"
local BG_IDS = {
	"rbxassetid://83511264088514",
	"rbxassetid://91622993482762",
	"rbxassetid://73167161449222",
}

-- Varias URLs base por si una falla
local BASE_URLS = {
	"https://raw.githubusercontent.com/Israel-Vortex/FlexusHub-Team/refs/heads/main/Scripts-Flexus/Top-one/",
	"https://cdn.jsdelivr.net/gh/Israel-Vortex/FlexusHub-Team@main/Scripts-Flexus/Top-one/",
}

local gamesByPlaceId = {
	[135856908115931] = "Duels.lua",
	[74084441161738] = "Duels.lua",
	[142823291] = "MM2.lua",
	[107778070777162] = "StealAnEgg.lua",
	[189707] = "SurvDisaster.lua",
}

local gamesByUniverseId = {
	[7219654364] = "Duels.lua",
}

local ACCENT = Color3.fromRGB(245, 245, 250)
local ACCENT_DIM = Color3.fromRGB(180, 180, 190)
local GOLD = Color3.fromRGB(255, 210, 90)

local function resolveScriptFile()
	local placeId = tonumber(game.PlaceId) or 0
	local gameId = tonumber(game.GameId) or 0

	if gamesByPlaceId[placeId] then
		return gamesByPlaceId[placeId], "placeId"
	end
	if gameId ~= 0 and gamesByUniverseId[gameId] then
		return gamesByUniverseId[gameId], "universeId"
	end

	local name = string.lower(tostring(game.Name or ""))
	if string.find(name, "murder", 1, true) and string.find(name, "mystery", 1, true) then
		return "MM2.lua", "name"
	end
	if
		string.find(name, "duel", 1, true)
		or string.find(name, "asesin", 1, true)
		or string.find(name, "sheriff", 1, true)
		or string.find(name, "murderer", 1, true)
	then
		return "Duels.lua", "name"
	end
	if string.find(name, "steal", 1, true) and string.find(name, "egg", 1, true) then
		return "StealAnEgg.lua", "name"
	end
	if string.find(name, "disaster", 1, true) or string.find(name, "natural", 1, true) then
		return "SurvDisaster.lua", "name"
	end
	return "Universal.lua", "fallback"
end

local function safeLoadstring(src)
	local loader = loadstring or load
	if not loader then
		return nil, "loadstring/load no disponible"
	end
	return loader(src)
end

local function httpGet(url)
	local ok, res = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(res) == "string" and #res > 40 then
		return res
	end
	return nil
end

local function loadScriptFile(scriptFile)
	local lastErr = "sin intento"
	for _, base in ipairs(BASE_URLS) do
		local url = base .. scriptFile
		print("[FlexusHub] HttpGet:", url)
		local src = httpGet(url)
		if not src then
			lastErr = "HttpGet fallo: " .. url
			warn("[FlexusHub]", lastErr)
		else
			local fn, err = safeLoadstring(src)
			if not fn then
				lastErr = "loadstring: " .. tostring(err)
				warn("[FlexusHub]", lastErr)
			else
				local okRun, runErr = pcall(fn)
				if okRun then
					print("[FlexusHub] OK ->", scriptFile, "desde", base)
					return true
				end
				lastErr = "runtime: " .. tostring(runErr)
				warn("[FlexusHub] Error ejecutando", scriptFile, ":", runErr)
			end
		end
	end
	return false, lastErr
end

local function runGameLoader()
	local scriptFile, how = resolveScriptFile()
	print(
		"[FlexusHub] Target:",
		scriptFile,
		"| how:",
		how,
		"| PlaceId:",
		game.PlaceId,
		"| GameId:",
		game.GameId,
		"| Name:",
		game.Name
	)

	local ok = loadScriptFile(scriptFile)
	if ok then
		return
	end

	-- Si no era Universal, intentar Universal como ultimo recurso
	if scriptFile ~= "Universal.lua" then
		warn("[FlexusHub] Fallo", scriptFile, "-> intentando Universal.lua")
		local ok2 = loadScriptFile("Universal.lua")
		if ok2 then
			return
		end
	end
	warn("[FlexusHub] No se pudo cargar ningun script. Revisa internet / GitHub en el executor.")
end

local function tween(obj, t, props, style, dir)
	style = style or Enum.EasingStyle.Quint
	dir = dir or Enum.EasingDirection.Out
	local tw = TweenService:Create(obj, TweenInfo.new(t, style, dir), props)
	tw:Play()
	return tw
end

local introSound = nil
local finished = false

local function loadIntroAudio(url)
	pcall(function()
		if isfile and writefile and getcustomasset then
			if not isfile(INTRO_FILE) then
				writefile(INTRO_FILE, game:HttpGet(url))
			end
			local snd = Instance.new("Sound")
			snd.SoundId = getcustomasset(INTRO_FILE)
			snd.Volume = 0.85
			snd.Looped = true
			snd.Parent = workspace
			snd:Play()
			introSound = snd
			return
		end
	end)
	if not introSound then
		pcall(function()
			local snd = Instance.new("Sound")
			snd.SoundId = url
			snd.Volume = 0.85
			snd.Looped = true
			snd.Parent = workspace
			snd:Play()
			introSound = snd
		end)
	end
end

local function stopAudio()
	pcall(function()
		if introSound then
			introSound:Stop()
			introSound:Destroy()
			introSound = nil
		end
	end)
end

-- ================= INTRO UI =================
local gui = Instance.new("ScreenGui")
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(gui)
parentHidden(gui)

local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.fromRGB(4, 4, 6)
cover.BorderSizePixel = 0
cover.Parent = gui

local bg = Instance.new("ImageLabel")
bg.Size = UDim2.fromScale(1.12, 1.12)
bg.Position = UDim2.fromScale(0.5, 0.5)
bg.AnchorPoint = Vector2.new(0.5, 0.5)
bg.BackgroundTransparency = 1
bg.Image = BG_IDS[1]
bg.ImageTransparency = 1
bg.ScaleType = Enum.ScaleType.Crop
bg.Parent = cover

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.3
dim.BorderSizePixel = 0
dim.Parent = cover

local center = Instance.new("Frame")
center.Size = UDim2.fromScale(0.9, 0.7)
center.Position = UDim2.fromScale(0.5, 0.55)
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.BackgroundTransparency = 1
center.Parent = cover

local logoWrap = Instance.new("Frame")
logoWrap.Size = UDim2.fromOffset(96, 96)
logoWrap.Position = UDim2.fromScale(0.5, 0.28)
logoWrap.AnchorPoint = Vector2.new(0.5, 0.5)
logoWrap.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
logoWrap.BackgroundTransparency = 0.15
logoWrap.BorderSizePixel = 0
logoWrap.Parent = center
Instance.new("UICorner", logoWrap).CornerRadius = UDim.new(0.28, 0)
local logoStroke = Instance.new("UIStroke")
logoStroke.Color = ACCENT
logoStroke.Thickness = 1.5
logoStroke.Transparency = 0.35
logoStroke.Parent = logoWrap

local logo = Instance.new("ImageLabel")
logo.Size = UDim2.fromScale(0.82, 0.82)
logo.Position = UDim2.fromScale(0.5, 0.5)
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.BackgroundTransparency = 1
logo.Image = LOGO_ID
logo.ScaleType = Enum.ScaleType.Fit
logo.ImageTransparency = 1
logo.Parent = logoWrap

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0)
title.AutomaticSize = Enum.AutomaticSize.Y
title.Position = UDim2.fromScale(0.5, 0.52)
title.AnchorPoint = Vector2.new(0.5, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 36
title.TextColor3 = ACCENT
title.Text = "FLEXUSHUB"
title.TextTransparency = 1
title.Parent = center

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.fromScale(0.9, 0)
subtitle.AutomaticSize = Enum.AutomaticSize.Y
subtitle.Position = UDim2.fromScale(0.5, 0.62)
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 15
subtitle.TextColor3 = ACCENT_DIM
subtitle.Text = "Scripts · Proteccion · Comunidad"
subtitle.TextTransparency = 1
subtitle.Parent = center

local audioStatus = Instance.new("TextLabel")
audioStatus.Size = UDim2.fromScale(0.9, 0)
audioStatus.AutomaticSize = Enum.AutomaticSize.Y
audioStatus.Position = UDim2.fromScale(0.5, 0.70)
audioStatus.AnchorPoint = Vector2.new(0.5, 0)
audioStatus.BackgroundTransparency = 1
audioStatus.Font = Enum.Font.GothamMedium
audioStatus.TextSize = 12
audioStatus.TextColor3 = GOLD
audioStatus.Text = "AUDIO EN BUCLE"
audioStatus.TextTransparency = 1
audioStatus.Parent = center

local continueBtn = Instance.new("TextButton")
continueBtn.Size = UDim2.fromOffset(200, 48)
continueBtn.Position = UDim2.fromScale(0.5, 0.86)
continueBtn.AnchorPoint = Vector2.new(0.5, 0.5)
continueBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
continueBtn.BackgroundTransparency = 1
continueBtn.Text = "CONTINUAR"
continueBtn.Font = Enum.Font.GothamBold
continueBtn.TextSize = 16
continueBtn.TextColor3 = Color3.fromRGB(10, 10, 12)
continueBtn.TextTransparency = 1
continueBtn.AutoButtonColor = true
continueBtn.Active = true
continueBtn.Parent = center
Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 12)

local footer = Instance.new("TextLabel")
footer.Size = UDim2.fromScale(1, 0)
footer.AutomaticSize = Enum.AutomaticSize.Y
footer.Position = UDim2.fromScale(0.5, 0.97)
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextColor3 = Color3.fromRGB(120, 120, 130)
footer.Text = "discord.gg/Fn74MpzFUn"
footer.TextTransparency = 1
footer.Parent = cover

task.spawn(function()
	tween(bg, 1.0, { ImageTransparency = 0.15 })
	tween(dim, 0.8, { BackgroundTransparency = 0.35 })
	task.wait(0.2)
	tween(logo, 0.6, { ImageTransparency = 0 })
	tween(logoWrap, 0.6, { BackgroundTransparency = 0.1 })
	task.wait(0.15)
	tween(title, 0.5, { TextTransparency = 0 })
	tween(subtitle, 0.5, { TextTransparency = 0.1 })
	tween(audioStatus, 0.5, { TextTransparency = 0.15 })
	tween(footer, 0.5, { TextTransparency = 0.3 })
	task.wait(0.15)
	tween(continueBtn, 0.45, { BackgroundTransparency = 0, TextTransparency = 0 })
end)

task.spawn(function()
	loadIntroAudio(INTRO_AUDIO_URL)
end)

local function destroyIntro()
	stopAudio()
	pcall(function()
		tween(cover, 0.4, { BackgroundTransparency = 1 })
		tween(bg, 0.4, { ImageTransparency = 1 })
		tween(dim, 0.4, { BackgroundTransparency = 1 })
		tween(title, 0.3, { TextTransparency = 1 })
		tween(subtitle, 0.3, { TextTransparency = 1 })
		tween(audioStatus, 0.3, { TextTransparency = 1 })
		tween(logo, 0.3, { ImageTransparency = 1 })
		tween(continueBtn, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
		tween(footer, 0.3, { TextTransparency = 1 })
	end)
	task.delay(0.5, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

local function onContinue()
	if finished then
		return
	end
	finished = true
	subtitle.Text = "Entrando..."
	audioStatus.Text = "CARGANDO"
	print("[FlexusHub] CONTINUAR presionado -> cargando script...")

	-- Cargar YA (no depender solo del delay de la intro)
	task.spawn(function()
		task.wait(0.15)
		destroyIntro()
		task.wait(0.2)
		local ok, err = pcall(runGameLoader)
		if not ok then
			warn("[FlexusHub] runGameLoader crash:", err)
		end
	end)
end

-- PC + movil
continueBtn.MouseButton1Click:Connect(onContinue)
pcall(function()
	continueBtn.Activated:Connect(onContinue)
end)
pcall(function()
	continueBtn.TouchTap:Connect(onContinue)
end)

print(
	"[FlexusHub] intro ready | PlaceId="
		.. tostring(game.PlaceId)
		.. " GameId="
		.. tostring(game.GameId)
		.. " Name="
		.. tostring(game.Name)
)
