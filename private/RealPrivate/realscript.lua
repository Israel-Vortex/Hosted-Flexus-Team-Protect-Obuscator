--[[
  FlexusHub · Loader + Intro Cinemática
  Animación mejorada · Logo + fondos nuevos · Audio en bucle hasta CONTINUAR

  Duels: no hace falta listar cada PlaceId de cada modo.
  Se resuelve PlaceId → GameId (universo) → nombre → Universal.lua
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

-- ================= PROTECT GUI =================
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

local function _gl()
	local prefixes = { "Core", "Player", "Camera", "Input", "Render", "UI", "Hud", "Topbar", "Badge", "Prompt", "Chat", "Mobile", "Touch" }
	return prefixes[math.random(1, #prefixes)] .. _rn(8)
end

local function protectGui(gui)
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(gui) end
	end)
	pcall(function()
		if protect_gui then protect_gui(gui) end
	end)
	pcall(function()
		gui.Name = _gl()
	end)
end

local function parentHidden(gui)
	local ok = false
	pcall(function()
		if gethui then
			gui.Parent = gethui()
			ok = true
		end
	end)
	if not ok then
		pcall(function()
			protectGui(gui)
			gui.Parent = CoreGui
			ok = true
		end)
	end
	if not ok then
		pcall(function()
			gui.Parent = PlayerGui
		end)
	end
end

-- ================= CONFIG FLEXUSHUB =================
local INTRO_AUDIO_URL =
	"https://www.image2url.com/r2/default/audio/1789249131827-a7aff83d-4a2d-4f1a-8f8d-d891a48b7f81.mp3"
local INTRO_FILE = "flexushub_intro_cache.mp3"

-- Logo + fondos (Graphite / Neon Blue / Golden)
local LOGO_ID = "rbxassetid://78482030075403"
local BG_IDS = {
	"rbxassetid://83511264088514", -- Graphite (default)
	"rbxassetid://91622993482762", -- Neon Blue
	"rbxassetid://73167161449222", -- Golden
}
local BG_ID = BG_IDS[1]

local BASE_URL =
	"https://raw.githubusercontent.com/Israel-Vortex/FlexusHub-Team/refs/heads/main/Scripts-Flexus/Top-one/"

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

-- ================= RESOLVE SCRIPT =================
local function resolveScriptFile()
	local placeId = game.PlaceId
	local gameId = game.GameId

	if gamesByPlaceId[placeId] then
		return gamesByPlaceId[placeId]
	end
	if gamesByUniverseId[gameId] then
		return gamesByUniverseId[gameId]
	end

	local name = string.lower(tostring(game.Name or ""))
	if string.find(name, "duel", 1, true) or string.find(name, "asesin", 1, true) or string.find(name, "sheriff", 1, true) then
		return "Duels.lua"
	end
	if string.find(name, "murder", 1, true) and string.find(name, "mystery", 1, true) then
		return "MM2.lua"
	end
	if string.find(name, "steal", 1, true) and string.find(name, "egg", 1, true) then
		return "StealAnEgg.lua"
	end
	if string.find(name, "disaster", 1, true) or string.find(name, "natural", 1, true) then
		return "SurvDisaster.lua"
	end
	return nil
end

-- ================= UTILS =================
local function tween(obj, t, props, style, dir)
	style = style or Enum.EasingStyle.Quint
	dir = dir or Enum.EasingDirection.Out
	local info = TweenInfo.new(t, style, dir)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local introSound = nil
local finished = false
local connections = {}

local function loadIntroAudio(url)
	local ok = pcall(function()
		if isfile and writefile and getcustomasset then
			if not isfile(INTRO_FILE) then
				local data = game:HttpGet(url)
				writefile(INTRO_FILE, data)
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
	if not ok or not introSound then
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

-- ================= INTRO GUI =================
local gui = Instance.new("ScreenGui")
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(gui)
parentHidden(gui)

-- Full black cover
local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.fromRGB(4, 4, 6)
cover.BorderSizePixel = 0
cover.Parent = gui

-- Background image (cinematic)
local bg = Instance.new("ImageLabel")
bg.Size = UDim2.fromScale(1.12, 1.12)
bg.Position = UDim2.fromScale(0.5, 0.5)
bg.AnchorPoint = Vector2.new(0.5, 0.5)
bg.BackgroundTransparency = 1
bg.Image = BG_ID
bg.ImageTransparency = 1
bg.ScaleType = Enum.ScaleType.Crop
bg.Parent = cover

-- Slow ken-burns drift
task.spawn(function()
	while cover.Parent and not finished do
		tween(bg, 8, {
			Size = UDim2.fromScale(1.18, 1.18),
			Position = UDim2.fromScale(0.48, 0.52),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(8)
		if finished then break end
		tween(bg, 8, {
			Size = UDim2.fromScale(1.12, 1.12),
			Position = UDim2.fromScale(0.52, 0.48),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(8)
	end
end)

-- Vignette / dim
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.25
dim.BorderSizePixel = 0
dim.Parent = cover

local dimGrad = Instance.new("UIGradient")
dimGrad.Rotation = 90
dimGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(40, 40, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})
dimGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.5, 0.45),
	NumberSequenceKeypoint.new(1, 0.05),
})
dimGrad.Parent = dim

-- Scanline overlay
local scan = Instance.new("Frame")
scan.Size = UDim2.fromScale(1, 0.04)
scan.Position = UDim2.fromScale(0, -0.1)
scan.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
scan.BackgroundTransparency = 0.92
scan.BorderSizePixel = 0
scan.ZIndex = 5
scan.Parent = cover
task.spawn(function()
	while cover.Parent and not finished do
		scan.Position = UDim2.fromScale(0, -0.08)
		local tw = tween(scan, 2.8, { Position = UDim2.fromScale(0, 1.05) }, Enum.EasingStyle.Linear)
		task.wait(2.8)
		task.wait(0.6)
	end
end)

-- Particles / sparks
local particleFolder = Instance.new("Folder")
particleFolder.Name = "FX"
particleFolder.Parent = cover

local function spawnSpark()
	if finished then return end
	local spark = Instance.new("Frame")
	local size = math.random(2, 5)
	spark.Size = UDim2.fromOffset(size, size)
	spark.Position = UDim2.fromScale(math.random(), 1.05)
	spark.AnchorPoint = Vector2.new(0.5, 0.5)
	spark.BackgroundColor3 = (math.random() > 0.7) and GOLD or ACCENT
	spark.BackgroundTransparency = 0.2
	spark.BorderSizePixel = 0
	spark.ZIndex = 4
	spark.Parent = particleFolder
	Instance.new("UICorner", spark).CornerRadius = UDim.new(1, 0)
	local dur = math.random(35, 70) / 10
	tween(spark, dur, {
		Position = UDim2.fromScale(spark.Position.X.Scale + (math.random() - 0.5) * 0.15, -0.05),
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Linear)
	task.delay(dur + 0.1, function()
		pcall(function() spark:Destroy() end)
	end)
end

task.spawn(function()
	while cover.Parent and not finished do
		spawnSpark()
		if math.random() > 0.5 then spawnSpark() end
		task.wait(0.12)
	end
end)

-- Center stack
local center = Instance.new("Frame")
center.Size = UDim2.fromScale(0.9, 0.7)
center.Position = UDim2.fromScale(0.5, 0.55)
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.BackgroundTransparency = 1
center.Parent = cover

-- Glow behind logo
local glow = Instance.new("Frame")
glow.Size = UDim2.fromOffset(220, 220)
glow.Position = UDim2.fromScale(0.5, 0.28)
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.BackgroundColor3 = ACCENT
glow.BackgroundTransparency = 0.85
glow.BorderSizePixel = 0
glow.Parent = center
Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

local glow2 = Instance.new("Frame")
glow2.Size = UDim2.fromOffset(140, 140)
glow2.Position = UDim2.fromScale(0.5, 0.28)
glow2.AnchorPoint = Vector2.new(0.5, 0.5)
glow2.BackgroundColor3 = GOLD
glow2.BackgroundTransparency = 0.88
glow2.BorderSizePixel = 0
glow2.Parent = center
Instance.new("UICorner", glow2).CornerRadius = UDim.new(1, 0)

-- Logo ring
local function makeRing(size, thick, color, trans)
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(size, size)
	ring.Position = UDim2.fromScale(0.5, 0.28)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Parent = center
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thick
	stroke.Color = color
	stroke.Transparency = trans
	stroke.Parent = ring
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	return ring, stroke
end

local ring1, stroke1 = makeRing(130, 1.5, ACCENT, 0.55)
local ring2, stroke2 = makeRing(160, 1, ACCENT_DIM, 0.7)
local ring3, stroke3 = makeRing(195, 1, GOLD, 0.8)

-- Pulse rings
task.spawn(function()
	while cover.Parent and not finished do
		tween(ring1, 1.4, { Size = UDim2.fromOffset(145, 145) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tween(ring2, 1.6, { Size = UDim2.fromOffset(175, 175) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(1.4)
		if finished then break end
		tween(ring1, 1.4, { Size = UDim2.fromOffset(130, 130) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tween(ring2, 1.6, { Size = UDim2.fromOffset(160, 160) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(1.4)
	end
end)

-- Slow rotate outer ring via UIGradient trick (size oscillation already enough)

-- Logo container
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

-- Title
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
title.TextStrokeTransparency = 0.7
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.Parent = center

local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.fromOffset(0, 2)
titleLine.Position = UDim2.fromScale(0.5, 0.62)
titleLine.AnchorPoint = Vector2.new(0.5, 0.5)
titleLine.BackgroundColor3 = GOLD
titleLine.BackgroundTransparency = 1
titleLine.BorderSizePixel = 0
titleLine.Parent = center

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.fromScale(0.9, 0)
subtitle.AutomaticSize = Enum.AutomaticSize.Y
subtitle.Position = UDim2.fromScale(0.5, 0.66)
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 15
subtitle.TextColor3 = ACCENT_DIM
subtitle.Text = "Scripts · Protección · Comunidad"
subtitle.TextTransparency = 1
subtitle.Parent = center

local audioStatus = Instance.new("TextLabel")
audioStatus.Size = UDim2.fromScale(0.9, 0)
audioStatus.AutomaticSize = Enum.AutomaticSize.Y
audioStatus.Position = UDim2.fromScale(0.5, 0.74)
audioStatus.AnchorPoint = Vector2.new(0.5, 0)
audioStatus.BackgroundTransparency = 1
audioStatus.Font = Enum.Font.GothamMedium
audioStatus.TextSize = 12
audioStatus.TextColor3 = GOLD
audioStatus.Text = "● AUDIO EN BUCLE"
audioStatus.TextTransparency = 1
audioStatus.Parent = center

-- Continue button
local continueBtn = Instance.new("TextButton")
continueBtn.Size = UDim2.fromOffset(200, 48)
continueBtn.Position = UDim2.fromScale(0.5, 0.88)
continueBtn.AnchorPoint = Vector2.new(0.5, 0.5)
continueBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
continueBtn.BackgroundTransparency = 1
continueBtn.Text = "CONTINUAR"
continueBtn.Font = Enum.Font.GothamBold
continueBtn.TextSize = 16
continueBtn.TextColor3 = Color3.fromRGB(10, 10, 12)
continueBtn.TextTransparency = 1
continueBtn.AutoButtonColor = false
continueBtn.Parent = center
Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 12)
local btnStroke = Instance.new("UIStroke")
btnStroke.Color = ACCENT
btnStroke.Thickness = 1.5
btnStroke.Transparency = 1
btnStroke.Parent = continueBtn

local footer = Instance.new("TextLabel")
footer.Size = UDim2.fromScale(1, 0)
footer.AutomaticSize = Enum.AutomaticSize.Y
footer.Position = UDim2.fromScale(0.5, 0.97)
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextColor3 = Color3.fromRGB(120, 120, 130)
footer.Text = "discord.gg/Fn74MpzFUn  ·  flexushub-scripts.netlify.app"
footer.TextTransparency = 1
footer.Parent = cover

-- ================= INTRO SEQUENCE =================
task.spawn(function()
	-- Fade in bg
	tween(bg, 1.2, { ImageTransparency = 0.15 }, Enum.EasingStyle.Quad)
	tween(dim, 1.0, { BackgroundTransparency = 0.35 })
	task.wait(0.35)

	-- Logo reveal
	tween(logoWrap, 0.7, { BackgroundTransparency = 0.1 }, Enum.EasingStyle.Back)
	tween(logo, 0.8, { ImageTransparency = 0 }, Enum.EasingStyle.Quad)
	tween(glow, 1.2, { BackgroundTransparency = 0.78, Size = UDim2.fromOffset(260, 260) })
	tween(glow2, 1.4, { BackgroundTransparency = 0.82, Size = UDim2.fromOffset(180, 180) })
	task.wait(0.25)

	-- Title
	tween(title, 0.7, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
	task.wait(0.15)
	tween(titleLine, 0.55, { Size = UDim2.fromOffset(120, 2), BackgroundTransparency = 0.15 })
	tween(subtitle, 0.6, { TextTransparency = 0.1 })
	task.wait(0.2)
	tween(audioStatus, 0.5, { TextTransparency = 0.15 })
	tween(footer, 0.6, { TextTransparency = 0.25 })

	-- Button
	task.wait(0.25)
	tween(continueBtn, 0.5, { BackgroundTransparency = 0, TextTransparency = 0 }, Enum.EasingStyle.Back)
	tween(btnStroke, 0.5, { Transparency = 0.4 })

	-- Soft logo pulse forever until continue
	while cover.Parent and not finished do
		tween(logoWrap, 1.1, { Size = UDim2.fromOffset(102, 102) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tween(glow, 1.1, { BackgroundTransparency = 0.72 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(1.1)
		if finished then break end
		tween(logoWrap, 1.1, { Size = UDim2.fromOffset(96, 96) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tween(glow, 1.1, { BackgroundTransparency = 0.82 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(1.1)
	end
end)

-- Audio
task.spawn(function()
	loadIntroAudio(INTRO_AUDIO_URL)
	audioStatus.Text = "● AUDIO EN BUCLE"
end)

-- Cycle backgrounds slowly (optional visual polish)
task.spawn(function()
	local idx = 1
	while cover.Parent and not finished do
		task.wait(12)
		if finished then break end
		idx = (idx % #BG_IDS) + 1
		tween(bg, 1.2, { ImageTransparency = 0.55 })
		task.wait(1.2)
		if finished then break end
		bg.Image = BG_IDS[idx]
		tween(bg, 1.4, { ImageTransparency = 0.15 })
	end
end)

-- ================= EXIT + LOAD =================
local function destroyIntro()
	stopAudio()
	finished = true
	for _, c in ipairs(connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	tween(center, 0.4, { Position = UDim2.fromScale(0.5, 0.42) })
	tween(cover, 0.55, { BackgroundTransparency = 1 })
	tween(bg, 0.55, { ImageTransparency = 1 })
	tween(dim, 0.55, { BackgroundTransparency = 1 })
	tween(title, 0.35, { TextTransparency = 1 })
	tween(subtitle, 0.35, { TextTransparency = 1 })
	tween(audioStatus, 0.3, { TextTransparency = 1 })
	tween(logo, 0.35, { ImageTransparency = 1 })
	tween(logoWrap, 0.35, { BackgroundTransparency = 1 })
	tween(glow, 0.35, { BackgroundTransparency = 1 })
	tween(glow2, 0.35, { BackgroundTransparency = 1 })
	tween(continueBtn, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
	tween(footer, 0.3, { TextTransparency = 1 })
	tween(titleLine, 0.3, { BackgroundTransparency = 1 })
	task.delay(0.6, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

local function runGameLoader()
	local scriptFile = resolveScriptFile() or "Universal.lua"
	local isUniversal = (scriptFile == "Universal.lua")
	if isUniversal then
		print(
			"[FlexusHub] Juego no listado → Universal | PlaceId="
				.. tostring(game.PlaceId)
				.. " GameId="
				.. tostring(game.GameId)
				.. " Name="
				.. tostring(game.Name)
		)
	end
	local success, err = pcall(function()
		loadstring(game:HttpGet(BASE_URL .. scriptFile))()
	end)
	if not success then
		warn("[FlexusHub] Error al cargar " .. tostring(scriptFile) .. ":", err)
		if not isUniversal then
			warn("[FlexusHub] Intentando Universal.lua…")
			local ok2, err2 = pcall(function()
				loadstring(game:HttpGet(BASE_URL .. "Universal.lua"))()
			end)
			if not ok2 then
				warn("[FlexusHub] Universal también falló:", err2)
			end
		end
	end
end

local function onContinue()
	if finished then
		return
	end
	finished = true
	subtitle.Text = "Entrando…"
	audioStatus.Text = "● CARGANDO"

	-- Flash
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = ACCENT
	flash.BackgroundTransparency = 0.75
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Parent = cover
	tween(flash, 0.5, { BackgroundTransparency = 1 })

	task.wait(0.28)
	destroyIntro()
	task.wait(0.45)
	runGameLoader()
end

continueBtn.MouseButton1Click:Connect(onContinue)
continueBtn.MouseEnter:Connect(function()
	if finished then
		return
	end
	tween(continueBtn, 0.15, { BackgroundColor3 = GOLD, Size = UDim2.fromOffset(208, 50) })
end)
continueBtn.MouseLeave:Connect(function()
	if finished then
		return
	end
	tween(continueBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(240, 240, 245), Size = UDim2.fromOffset(200, 48) })
end)

print("[FlexusHub] intro ready · " .. tostring(game.PlaceId))
