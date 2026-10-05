--[[
  FlexusHub · Loader
  Intro → Menu → Seleccionas script → precarga → EJECUTAR confirma
  Solo ejecuta el archivo elegido (Duels.lua, MM2.lua, etc.)
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
	if not ok or not gui.Parent then
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
local BG_ID = "rbxassetid://83511264088514"

-- URL base (se completa con el .lua elegido)
local BASE_URL =
	"https://raw.githubusercontent.com/Israel-Vortex/FlexusHub-Team/refs/heads/main/Scripts-Flexus/Top-one/"
local BASE_URL_MIRROR =
	"https://cdn.jsdelivr.net/gh/Israel-Vortex/FlexusHub-Team@main/Scripts-Flexus/Top-one/"

local SCRIPT_OPTIONS = {
	{ Name = "Duels", File = "Duels.lua", Desc = "Asesinos VS Sheriffs" },
	{ Name = "MM2", File = "MM2.lua", Desc = "Murder Mystery 2" },
	{ Name = "Steal an Egg", File = "StealAnEgg.lua", Desc = "Steal an Egg" },
	{ Name = "Survival Disaster", File = "SurvDisaster.lua", Desc = "Natural Disaster" },
	{ Name = "Universal", File = "Universal.lua", Desc = "Cualquier juego" },
}

local ACCENT = Color3.fromRGB(245, 245, 250)
local ACCENT_DIM = Color3.fromRGB(170, 170, 180)
local GOLD = Color3.fromRGB(255, 210, 90)
local PANEL = Color3.fromRGB(14, 14, 18)
local PANEL2 = Color3.fromRGB(22, 22, 28)
local BORDER = Color3.fromRGB(200, 200, 210)

local function tween(obj, t, props)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function safeLoadstring(src)
	local loader = loadstring or load
	if not loader then
		return nil, "loadstring no disponible"
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

-- ================= STATE =================
local introSound = nil
local finishedIntro = false
local selectedFile = nil -- nil hasta que el usuario elija
local selectedName = "Ninguno"
local preparedFn = nil -- loadstring ya listo
local preparedSrc = nil
local prepareToken = 0 -- evita race si cambian opcion rapido

local function fullUrl(fileName)
	return BASE_URL .. tostring(fileName)
end

-- Precarga: descarga + loadstring del archivo elegido (NO ejecuta)
local function prepareScript(fileName)
	prepareToken = prepareToken + 1
	local myToken = prepareToken
	preparedFn = nil
	preparedSrc = nil

	print("[FlexusHub] Preparando:", fileName)
	print("[FlexusHub] URL:", fullUrl(fileName))

	local src = httpGet(BASE_URL .. fileName)
	if not src then
		src = httpGet(BASE_URL_MIRROR .. fileName)
	end
	if myToken ~= prepareToken then
		return false, "cancelado"
	end
	if not src then
		return false, "HttpGet fallo"
	end

	local fn, err = safeLoadstring(src)
	if myToken ~= prepareToken then
		return false, "cancelado"
	end
	if not fn then
		return false, "loadstring: " .. tostring(err)
	end

	preparedSrc = src
	preparedFn = fn
	print("[FlexusHub] Listo para ejecutar:", fileName, "(" .. tostring(#src) .. " bytes)")
	return true
end

local function runPrepared()
	if not preparedFn then
		return false, "No hay script preparado. Elige uno en la lista."
	end
	local file = selectedFile
	print("[FlexusHub] EJECUTANDO:", file)
	print("[FlexusHub] URL final:", fullUrl(file))
	local ok, err = pcall(preparedFn)
	if ok then
		print("[FlexusHub] OK ejecutado:", file)
		return true
	end
	warn("[FlexusHub] Error runtime en", file, ":", err)
	return false, tostring(err)
end

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

-- ================= ROOT GUI =================
local gui = Instance.new("ScreenGui")
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(gui)
parentHidden(gui)

-- ========== INTRO ==========
local introCover = Instance.new("Frame")
introCover.Size = UDim2.fromScale(1, 1)
introCover.BackgroundColor3 = Color3.fromRGB(4, 4, 6)
introCover.BorderSizePixel = 0
introCover.Parent = gui

local introBg = Instance.new("ImageLabel")
introBg.Size = UDim2.fromScale(1.1, 1.1)
introBg.Position = UDim2.fromScale(0.5, 0.5)
introBg.AnchorPoint = Vector2.new(0.5, 0.5)
introBg.BackgroundTransparency = 1
introBg.Image = BG_ID
introBg.ImageTransparency = 1
introBg.ScaleType = Enum.ScaleType.Crop
introBg.Parent = introCover

local introDim = Instance.new("Frame")
introDim.Size = UDim2.fromScale(1, 1)
introDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
introDim.BackgroundTransparency = 0.3
introDim.BorderSizePixel = 0
introDim.Parent = introCover

local introCenter = Instance.new("Frame")
introCenter.Size = UDim2.fromScale(0.9, 0.6)
introCenter.Position = UDim2.fromScale(0.5, 0.5)
introCenter.AnchorPoint = Vector2.new(0.5, 0.5)
introCenter.BackgroundTransparency = 1
introCenter.Parent = introCover

local introLogoWrap = Instance.new("Frame")
introLogoWrap.Size = UDim2.fromOffset(96, 96)
introLogoWrap.Position = UDim2.fromScale(0.5, 0.28)
introLogoWrap.AnchorPoint = Vector2.new(0.5, 0.5)
introLogoWrap.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
introLogoWrap.BackgroundTransparency = 0.1
introLogoWrap.BorderSizePixel = 0
introLogoWrap.Parent = introCenter
Instance.new("UICorner", introLogoWrap).CornerRadius = UDim.new(0.28, 0)
local ils = Instance.new("UIStroke")
ils.Color = ACCENT
ils.Thickness = 1.5
ils.Transparency = 0.35
ils.Parent = introLogoWrap

local introLogo = Instance.new("ImageLabel")
introLogo.Size = UDim2.fromScale(0.82, 0.82)
introLogo.Position = UDim2.fromScale(0.5, 0.5)
introLogo.AnchorPoint = Vector2.new(0.5, 0.5)
introLogo.BackgroundTransparency = 1
introLogo.Image = LOGO_ID
introLogo.ImageTransparency = 1
introLogo.ScaleType = Enum.ScaleType.Fit
introLogo.Parent = introLogoWrap

local introTitle = Instance.new("TextLabel")
introTitle.Size = UDim2.fromScale(1, 0)
introTitle.AutomaticSize = Enum.AutomaticSize.Y
introTitle.Position = UDim2.fromScale(0.5, 0.52)
introTitle.AnchorPoint = Vector2.new(0.5, 0)
introTitle.BackgroundTransparency = 1
introTitle.Font = Enum.Font.GothamBlack
introTitle.TextSize = 36
introTitle.TextColor3 = ACCENT
introTitle.Text = "FLEXUSHUB"
introTitle.TextTransparency = 1
introTitle.Parent = introCenter

local introSub = Instance.new("TextLabel")
introSub.Size = UDim2.fromScale(0.9, 0)
introSub.AutomaticSize = Enum.AutomaticSize.Y
introSub.Position = UDim2.fromScale(0.5, 0.64)
introSub.AnchorPoint = Vector2.new(0.5, 0)
introSub.BackgroundTransparency = 1
introSub.Font = Enum.Font.Gotham
introSub.TextSize = 15
introSub.TextColor3 = ACCENT_DIM
introSub.Text = "Scripts · Proteccion · Comunidad"
introSub.TextTransparency = 1
introSub.Parent = introCenter

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
continueBtn.AutoButtonColor = true
continueBtn.Parent = introCenter
Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 12)

task.spawn(function()
	tween(introBg, 1.0, { ImageTransparency = 0.18 })
	task.wait(0.15)
	tween(introLogo, 0.55, { ImageTransparency = 0 })
	tween(introTitle, 0.5, { TextTransparency = 0 })
	tween(introSub, 0.5, { TextTransparency = 0.12 })
	task.wait(0.12)
	tween(continueBtn, 0.4, { BackgroundTransparency = 0, TextTransparency = 0 })
end)

task.spawn(function()
	loadIntroAudio(INTRO_AUDIO_URL)
end)

-- ========== MENU ==========
local menuCover = Instance.new("Frame")
menuCover.Size = UDim2.fromScale(1, 1)
menuCover.BackgroundColor3 = Color3.fromRGB(6, 6, 8)
menuCover.BackgroundTransparency = 1
menuCover.BorderSizePixel = 0
menuCover.Visible = false
menuCover.Parent = gui

local menuBg = Instance.new("ImageLabel")
menuBg.Size = UDim2.fromScale(1, 1)
menuBg.BackgroundTransparency = 1
menuBg.Image = BG_ID
menuBg.ImageTransparency = 0.35
menuBg.ScaleType = Enum.ScaleType.Crop
menuBg.Parent = menuCover

local menuDim = Instance.new("Frame")
menuDim.Size = UDim2.fromScale(1, 1)
menuDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
menuDim.BackgroundTransparency = 0.35
menuDim.BorderSizePixel = 0
menuDim.Parent = menuCover

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(520, 340)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Parent = menuCover
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = BORDER
panelStroke.Thickness = 2
panelStroke.Transparency = 0.25
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 64)
header.BackgroundColor3 = PANEL2
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)
local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 20)
headerMask.Position = UDim2.new(0, 0, 1, -20)
headerMask.BackgroundColor3 = PANEL2
headerMask.BackgroundTransparency = 0.15
headerMask.BorderSizePixel = 0
headerMask.Parent = header

local headerLogo = Instance.new("ImageLabel")
headerLogo.Size = UDim2.fromOffset(40, 40)
headerLogo.Position = UDim2.new(0, 16, 0.5, 0)
headerLogo.AnchorPoint = Vector2.new(0, 0.5)
headerLogo.BackgroundTransparency = 1
headerLogo.Image = LOGO_ID
headerLogo.ScaleType = Enum.ScaleType.Fit
headerLogo.Parent = header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -70, 0, 22)
headerTitle.Position = UDim2.new(0, 66, 0.5, -12)
headerTitle.BackgroundTransparency = 1
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 18
headerTitle.TextColor3 = ACCENT
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Text = "FlexusHub"
headerTitle.Parent = header

local headerSub = Instance.new("TextLabel")
headerSub.Size = UDim2.new(1, -70, 0, 16)
headerSub.Position = UDim2.new(0, 66, 0.5, 8)
headerSub.BackgroundTransparency = 1
headerSub.Font = Enum.Font.Gotham
headerSub.TextSize = 12
headerSub.TextColor3 = ACCENT_DIM
headerSub.TextXAlignment = Enum.TextXAlignment.Left
headerSub.Text = "Elige el script y luego EJECUTAR"
headerSub.Parent = header

local side = Instance.new("Frame")
side.Size = UDim2.new(0, 180, 1, -80)
side.Position = UDim2.new(0, 12, 0, 72)
side.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
side.BackgroundTransparency = 0.1
side.BorderSizePixel = 0
side.Parent = panel
Instance.new("UICorner", side).CornerRadius = UDim.new(0, 12)
local sideStroke = Instance.new("UIStroke")
sideStroke.Color = Color3.fromRGB(90, 90, 100)
sideStroke.Thickness = 1.2
sideStroke.Transparency = 0.4
sideStroke.Parent = side

local sideTitle = Instance.new("TextLabel")
sideTitle.Size = UDim2.new(1, -16, 0, 24)
sideTitle.Position = UDim2.new(0, 8, 0, 8)
sideTitle.BackgroundTransparency = 1
sideTitle.Font = Enum.Font.GothamBold
sideTitle.TextSize = 12
sideTitle.TextColor3 = ACCENT_DIM
sideTitle.TextXAlignment = Enum.TextXAlignment.Left
sideTitle.Text = "SCRIPTS"
sideTitle.Parent = side

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -12, 1, -40)
list.Position = UDim2.new(0, 6, 0, 34)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = ACCENT_DIM
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = side

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 2)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 2)
pad.PaddingRight = UDim.new(0, 2)
pad.Parent = list

local mid = Instance.new("Frame")
mid.Size = UDim2.new(1, -210, 1, -80)
mid.Position = UDim2.new(0, 200, 0, 72)
mid.BackgroundTransparency = 1
mid.Parent = panel

local midCard = Instance.new("Frame")
midCard.Size = UDim2.new(1, -8, 1, -8)
midCard.Position = UDim2.fromOffset(4, 4)
midCard.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
midCard.BackgroundTransparency = 0.08
midCard.BorderSizePixel = 0
midCard.Parent = mid
Instance.new("UICorner", midCard).CornerRadius = UDim.new(0, 12)
local midStroke = Instance.new("UIStroke")
midStroke.Color = Color3.fromRGB(90, 90, 100)
midStroke.Thickness = 1.2
midStroke.Transparency = 0.4
midStroke.Parent = midCard

local midLogo = Instance.new("ImageLabel")
midLogo.Size = UDim2.fromOffset(72, 72)
midLogo.Position = UDim2.new(0.5, 0, 0, 28)
midLogo.AnchorPoint = Vector2.new(0.5, 0)
midLogo.BackgroundTransparency = 1
midLogo.Image = LOGO_ID
midLogo.ScaleType = Enum.ScaleType.Fit
midLogo.Parent = midCard

local midName = Instance.new("TextLabel")
midName.Size = UDim2.new(1, -24, 0, 28)
midName.Position = UDim2.new(0, 12, 0, 112)
midName.BackgroundTransparency = 1
midName.Font = Enum.Font.GothamBold
midName.TextSize = 22
midName.TextColor3 = ACCENT
midName.Text = "Ninguno"
midName.Parent = midCard

local midDesc = Instance.new("TextLabel")
midDesc.Size = UDim2.new(1, -24, 0, 40)
midDesc.Position = UDim2.new(0, 12, 0, 142)
midDesc.BackgroundTransparency = 1
midDesc.Font = Enum.Font.Gotham
midDesc.TextSize = 13
midDesc.TextColor3 = ACCENT_DIM
midDesc.TextWrapped = true
midDesc.Text = "Toca un script a la izquierda.\nSe preparara el loadstring."
midDesc.Parent = midCard

local midFile = Instance.new("TextLabel")
midFile.Size = UDim2.new(1, -24, 0, 18)
midFile.Position = UDim2.new(0, 12, 0, 188)
midFile.BackgroundTransparency = 1
midFile.Font = Enum.Font.GothamMedium
midFile.TextSize = 11
midFile.TextColor3 = GOLD
midFile.Text = "(sin seleccionar)"
midFile.Parent = midCard

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -24, 0, 18)
statusLbl.Position = UDim2.new(0, 12, 1, -78)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11
statusLbl.TextColor3 = ACCENT_DIM
statusLbl.Text = "Selecciona un script"
statusLbl.Parent = midCard

local execBtn = Instance.new("TextButton")
execBtn.Size = UDim2.fromOffset(200, 46)
execBtn.Position = UDim2.new(0.5, 0, 1, -28)
execBtn.AnchorPoint = Vector2.new(0.5, 1)
execBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
execBtn.BorderSizePixel = 0
execBtn.Text = "EJECUTAR SCRIPT"
execBtn.Font = Enum.Font.GothamBold
execBtn.TextSize = 15
execBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
execBtn.AutoButtonColor = true
execBtn.Active = false
execBtn.Parent = midCard
Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 12)
local execStroke = Instance.new("UIStroke")
execStroke.Color = BORDER
execStroke.Thickness = 1.5
execStroke.Transparency = 0.5
execStroke.Parent = execBtn

local optionButtons = {}

local function setExecReady(ready)
	if ready then
		execBtn.Active = true
		execBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
		execBtn.TextColor3 = Color3.fromRGB(12, 12, 14)
		execStroke.Transparency = 0.35
		execBtn.Text = "EJECUTAR SCRIPT"
	else
		execBtn.Active = false
		execBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
		execBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
		execStroke.Transparency = 0.5
	end
end

local function refreshSelectionUI()
	midName.Text = selectedName
	midFile.Text = selectedFile and selectedFile or "(sin seleccionar)"
	for file, btn in pairs(optionButtons) do
		local active = (file == selectedFile)
		btn.BackgroundColor3 = active and Color3.fromRGB(55, 55, 62) or Color3.fromRGB(18, 18, 24)
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = active and GOLD or Color3.fromRGB(70, 70, 80)
			stroke.Transparency = active and 0.15 or 0.55
		end
	end
end

local function onSelectOption(opt)
	selectedFile = opt.File
	selectedName = opt.Name
	midDesc.Text = opt.Desc
	refreshSelectionUI()
	setExecReady(false)
	statusLbl.Text = "Preparando " .. opt.File .. "..."
	statusLbl.TextColor3 = GOLD

	task.spawn(function()
		local ok, err = prepareScript(opt.File)
		-- solo actualizar si sigue siendo la misma seleccion
		if selectedFile ~= opt.File then
			return
		end
		if ok then
			statusLbl.Text = "Listo: " .. opt.File
			statusLbl.TextColor3 = Color3.fromRGB(120, 220, 140)
			setExecReady(true)
		else
			statusLbl.Text = "Error: " .. tostring(err)
			statusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
			setExecReady(false)
			preparedFn = nil
		end
	end)
end

for i, opt in ipairs(SCRIPT_OPTIONS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -4, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.LayoutOrder = i
	btn.Parent = list
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(70, 70, 80)
	st.Thickness = 1
	st.Transparency = 0.55
	st.Parent = btn

	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(1, -12, 0, 18)
	n.Position = UDim2.new(0, 8, 0, 4)
	n.BackgroundTransparency = 1
	n.Font = Enum.Font.GothamBold
	n.TextSize = 13
	n.TextColor3 = ACCENT
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.Text = opt.Name
	n.Parent = btn

	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(1, -12, 0, 14)
	d.Position = UDim2.new(0, 8, 0, 22)
	d.BackgroundTransparency = 1
	d.Font = Enum.Font.Gotham
	d.TextSize = 10
	d.TextColor3 = ACCENT_DIM
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.Text = opt.File
	d.Parent = btn

	local function click()
		onSelectOption(opt)
	end
	btn.MouseButton1Click:Connect(click)
	pcall(function()
		btn.Activated:Connect(click)
	end)

	optionButtons[opt.File] = btn
end

local function showMenu()
	stopAudio()
	introCover.Visible = false
	menuCover.Visible = true
	menuCover.BackgroundTransparency = 1
	panel.BackgroundTransparency = 1
	tween(menuCover, 0.35, { BackgroundTransparency = 0 })
	tween(panel, 0.4, { BackgroundTransparency = 0.05 })
end

local function closeLoaderUI()
	stopAudio()
	pcall(function()
		menuCover.Visible = false
		introCover.Visible = false
	end)
	pcall(function()
		gui:Destroy()
	end)
end

local function hideAllAndRun()
	if not selectedFile then
		statusLbl.Text = "Primero elige un script"
		statusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
		return
	end
	if not preparedFn then
		statusLbl.Text = "Aun preparando... espera"
		statusLbl.TextColor3 = GOLD
		return
	end

	local fileNow = selectedFile
	local fn = preparedFn
	statusLbl.Text = "Ejecutando " .. fileNow .. "..."
	execBtn.Text = "CARGANDO..."
	execBtn.Active = false

	print("[FlexusHub] CONFIRMAR ejecutar solo:", fileNow)
	print("[FlexusHub] URL final:", fullUrl(fileNow))

	-- Cerrar menu YA (antes de ejecutar) para que no tape la pantalla
	-- aunque el script tarde o se cuelgue
	task.spawn(function()
		pcall(function()
			tween(panel, 0.2, { BackgroundTransparency = 1 })
			tween(menuCover, 0.25, { BackgroundTransparency = 1 })
		end)
		task.wait(0.25)
		closeLoaderUI()

		-- Ejecutar DESPUES de quitar el menu
		task.spawn(function()
			if not fn then
				warn("[FlexusHub] No hay funcion preparada para", fileNow)
				return
			end
			local ok, err = pcall(fn)
			if ok then
				print("[FlexusHub] OK ejecutado:", fileNow)
			else
				warn("[FlexusHub] Error runtime en", fileNow, ":", err)
			end
		end)
	end)
end

local function onContinue()
	if finishedIntro then
		return
	end
	finishedIntro = true
	introSub.Text = "Abriendo menu..."
	task.spawn(function()
		task.wait(0.2)
		showMenu()
	end)
end

continueBtn.MouseButton1Click:Connect(onContinue)
pcall(function()
	continueBtn.Activated:Connect(onContinue)
end)

execBtn.MouseButton1Click:Connect(function()
	if execBtn.Active then
		hideAllAndRun()
	end
end)
pcall(function()
	execBtn.Activated:Connect(function()
		if execBtn.Active then
			hideAllAndRun()
		end
	end)
end)

print("[FlexusHub] loader listo | elige script manualmente (sin auto Universal)")
