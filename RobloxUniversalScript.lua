-- Исправленный скрипт с рабочим ТП на место смерти
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local camera = workspace.CurrentCamera

-- Состояние (State)
local S = {
	fly = false, flySpeed = 50,
	bhop = false, bhopSpeed = 35,
	infJump = false,
	noclip = false,
	esp = false,
	espR = 255, espG = 50, espB = 50,
	speedOn = false, walkSpeed = 16,
	jumpOn = false, jumpPower = 50,
	fullbright = false,
	nightmode = false,
	aimbot = false,
	aimFov = 100,
	showFov = true,
	teamCheck = true,
	visCheck = true,
	spinbot = false, spinSpeed = 30,
	antiAfk = false,
	dashPower = 100,
	showDashBtn = true,
	dashLocked = false,
	themeMode = "Rainbow",
	customR = 255, customG = 255, customB = 255,
	fpsPingMode = "FPS & Ping"
}

-- Переменная для сохранения координат смерти
local lastDeathPosition = nil

local connections = {}

local function getChar() return player.Character end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- Очистка старого GUI
if playerGui:FindFirstChild("KrytoiMenu") then
	playerGui.KrytoiMenu:Destroy()
end

-- Создание GUI
local gui = Instance.new("ScreenGui")
gui.Name = "KrytoiMenu"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = playerGui

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end

local function bindClick(btn, callback)
	if btn.Activated then
		btn.Activated:Connect(callback)
	else
		btn.MouseButton1Click:Connect(callback)
	end
end

-- Перетаскивание (Drag)
local function makeDraggable(topBar, object)
	local dragging, dragStart, startPos
	topBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = object.Position
		end
	end)
	table.insert(connections, UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(connections, UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

-- Надежное отслеживание смерти и координат
local function setupDeathListener(char)
	local hum = char:WaitForChild("Humanoid", 5)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if hum and root then
		table.insert(connections, hum.Died:Connect(function()
			if root and root.Parent then
				lastDeathPosition = root.CFrame + Vector3.new(0, 3, 0) -- Чуть выше, чтобы не застрять в полу
			end
		end))
	end
end

if player.Character then
	setupDeathListener(player.Character)
end
table.insert(connections, player.CharacterAdded:Connect(function(newChar)
	task.wait(0.5) -- Ждем полной загрузки персонажа после респавна
	setupDeathListener(newChar)
end))

-- Функция телепортации на место смерти
local function tpToDeath()
	if not lastDeathPosition then
		return
	end
	
	local root = getRoot()
	local hum = getHum()
	
	if root and hum and hum.Health > 0 then
		-- Сбрасываем скорость падения/физику перед телепортом
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = lastDeathPosition
	end
end

-- Логика Дэша
local function doDash()
	local root = getRoot()
	local hum = getHum()
	if root and hum then
		local dir = hum.MoveDirection.Magnitude > 0 and hum.MoveDirection or camera.CFrame.LookVector
		root.AssemblyLinearVelocity = Vector3.new(dir.X * S.dashPower, root.AssemblyLinearVelocity.Y, dir.Z * S.dashPower)
	end
end

-- Логика Server Hop
local function serverHop(mode)
	pcall(function()
		local servers = {}
		local cursor = ""
		local maxPages = 5
		
		for i = 1, maxPages do
			local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			if cursor ~= "" then
				url = url .. "&cursor=" .. cursor
			end
			
			local reqFunc = (syn and syn.request) or (http and http.request) or http_request or request
			local rawData
			if reqFunc then
				local res = reqFunc({Url = url, Method = "GET"})
				if res and res.Body then rawData = res.Body end
			else
				rawData = game:HttpGet(url)
			end

			if rawData then
				local success, result = pcall(function()
					return HttpService:JSONDecode(rawData)
				end)
				if success and result and result.data then
					for _, s in ipairs(result.data) do
						if type(s) == "table" and s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
							table.insert(servers, s)
						end
					end
					cursor = result.nextPageCursor
					if not cursor then break end
				else
					break
				end
			else
				break
			end
		end

		if #servers > 0 then
			if mode == "min" then
				table.sort(servers, function(a, b) return a.playing < b.playing end)
			elseif mode == "max" then
				table.sort(servers, function(a, b) return a.playing > b.playing end)
			else
				for i = #servers, 2, -1 do
					local j = math.random(i)
					servers[i], servers[j] = servers[j], servers[i]
				end
			end
			TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, player)
		else
			TeleportService:Teleport(game.PlaceId, player)
		end
	end)
end

-- Плавающий информер FPS & Ping
local infoFrame = Instance.new("Frame")
infoFrame.Name = "FPSPingInfo"
infoFrame.Size = UDim2.new(0, 130, 0, 32)
infoFrame.Position = UDim2.new(1, -140, 0, 10)
infoFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
infoFrame.BackgroundTransparency = 0.3
infoFrame.Visible = true
infoFrame.Parent = gui
corner(infoFrame, 6)

local infoStroke = Instance.new("UIStroke")
infoStroke.Thickness = 1.5
infoStroke.Color = Color3.fromRGB(255, 255, 255)
infoStroke.Parent = infoFrame

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, 0, 1, 0)
infoText.BackgroundTransparency = 1
infoText.TextColor3 = Color3.new(1, 1, 1)
infoText.Font = Enum.Font.GothamBold
infoText.TextSize = 12
infoText.Text = "FPS: 60 | Ping: 40ms"
infoText.Parent = infoFrame

makeDraggable(infoFrame, infoFrame)

-- Перемещаемая кнопка DASH
local mobileDashBtn = Instance.new("TextButton")
mobileDashBtn.Name = "MobileDashButton"
mobileDashBtn.Size = UDim2.new(0, 65, 0, 65)
mobileDashBtn.Position = UDim2.new(0.85, -35, 0.55, -35)
mobileDashBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
mobileDashBtn.BackgroundTransparency = 0.2
mobileDashBtn.TextColor3 = Color3.new(1, 1, 1)
mobileDashBtn.Font = Enum.Font.GothamBold
mobileDashBtn.TextSize = 14
mobileDashBtn.Text = "DASH"
mobileDashBtn.Parent = gui
corner(mobileDashBtn, 33)

local dashStroke = Instance.new("UIStroke")
dashStroke.Thickness = 2
dashStroke.Color = Color3.fromRGB(255, 255, 255)
dashStroke.Parent = mobileDashBtn

local dashDragging = false
local dashDragStart, dashStartPos

mobileDashBtn.InputBegan:Connect(function(i)
	if not S.dashLocked and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
		dashDragging = true
		dashDragStart = i.Position
		dashStartPos = mobileDashBtn.Position
	end
end)

table.insert(connections, UIS.InputChanged:Connect(function(i)
	if not S.dashLocked and dashDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dashDragStart
		mobileDashBtn.Position = UDim2.new(dashStartPos.X.Scale, dashStartPos.X.Offset + d.X, dashStartPos.Y.Scale, dashStartPos.Y.Offset + d.Y)
	end
end))

table.insert(connections, UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dashDragging = false
	end
end))

bindClick(mobileDashBtn, doDash)

-- Круг FOV
local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.BackgroundTransparency = 1
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.Visible = false
fovCircle.Parent = gui

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1.5
fovStroke.Parent = fovCircle

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

-- Кнопка Открыть/Закрыть меню
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 80, 0, 32)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -16)
toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.Text = "Close"
toggleBtn.Parent = gui
corner(toggleBtn)

-- Главное окно
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 380)
main.Position = UDim2.new(0, 100, 0.5, -190)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
main.Active = true
main.Parent = gui
corner(main, 12)

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "MENU"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = main

bindClick(toggleBtn, function()
	main.Visible = not main.Visible
	toggleBtn.Text = main.Visible and "Close" or "Open"
end)

makeDraggable(toggleBtn, toggleBtn)
makeDraggable(title, main)

-- Вкладки
local tabHolder = Instance.new("Frame")
tabHolder.Size = UDim2.new(1, -20, 0, 28)
tabHolder.Position = UDim2.new(0, 10, 0, 36)
tabHolder.BackgroundTransparency = 1
tabHolder.Parent = main

local pagesHolder = Instance.new("Frame")
pagesHolder.Size = UDim2.new(1, -20, 0, 270)
pagesHolder.Position = UDim2.new(0, 10, 0, 70)
pagesHolder.BackgroundTransparency = 1
pagesHolder.Parent = main

local tabs, pages = {}, {}

local function createTab(name, index)
	local tabBtn = Instance.new("TextButton")
	tabBtn.Size = UDim2.new(0.23, 0, 1, 0)
	tabBtn.Position = UDim2.new((index - 1) * 0.255, 0, 0, 0)
	tabBtn.BackgroundColor3 = index == 1 and Color3.fromRGB(60, 60, 80) or Color3.fromRGB(40, 40, 50)
	tabBtn.TextColor3 = Color3.new(1, 1, 1)
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextSize = 11
	tabBtn.Text = name
	tabBtn.Parent = tabHolder
	corner(tabBtn, 6)

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = (index == 1)
	page.Parent = pagesHolder

	tabs[name] = tabBtn
	pages[name] = page

	bindClick(tabBtn, function()
		for _, btn in pairs(tabs) do btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50) end
		for _, p in pairs(pages) do p.Visible = false end
		tabBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		page.Visible = true
	end)

	return page
end

local aimPage = createTab("Combat", 1)
local movementPage = createTab("Movement", 2)
local visualPage = createTab("Visual", 3)
local miscPage = createTab("Misc", 4)

-- UI Конструкторы
local function makeToggle(parent, y, text, default, onChange)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -6, 0, 28)
	b.Position = UDim2.new(0, 0, 0, y)
	b.BackgroundColor3 = default and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(50, 50, 62)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.Text = text .. (default and ": ON" or ": OFF")
	b.Parent = parent
	corner(b, 6)
	local on = default or false
	bindClick(b, function()
		on = not on
		b.Text = text .. (on and ": ON" or ": OFF")
		b.BackgroundColor3 = on and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(50, 50, 62)
		onChange(on)
	end)
end

local function makeSlider(parent, y, text, min, max, default, onChange)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 16)
	label.Position = UDim2.new(0, 0, 0, y)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -6, 0, 8)
	bar.Position = UDim2.new(0, 0, 0, y + 20)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	bar.Parent = parent
	corner(bar, 4)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(90, 140, 255)
	fill.Parent = bar
	corner(fill, 4)

	local function set(v)
		v = math.clamp(math.floor(v + 0.5), min, max)
		label.Text = text .. ": " .. v
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		onChange(v)
	end
	set(default)

	local dragging = false
	local function update(i)
		local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		set(min + rel * (max - min))
	end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(i)
		end
	end)
	table.insert(connections, UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			update(i)
		end
	end))
	table.insert(connections, UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

local function makeButton(parent, y, text, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -6, 0, 28)
	b.Position = UDim2.new(0, 0, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	bindClick(b, onClick)
end

-- Наполнение вкладок
makeToggle(aimPage, 0, "Aimbot", false, function(v) S.aimbot = v end)
makeToggle(aimPage, 34, "Show FOV Circle", true, function(v) S.showFov = v end)
makeToggle(aimPage, 68, "Team Check", true, function(v) S.teamCheck = v end)
makeToggle(aimPage, 102, "Visible Check", true, function(v) S.visCheck = v end)
makeSlider(aimPage, 138, "FOV Size", 30, 400, 100, function(v) S.aimFov = v end)

makeToggle(movementPage, 0, "Fly", false, function(v) S.fly = v end)
makeSlider(movementPage, 34, "Fly Speed", 1, 250, 50, function(v) S.flySpeed = v end)

makeToggle(movementPage, 70, "BunnyHop", false, function(v) S.bhop = v end)
makeSlider(movementPage, 104, "BHop Speed", 16, 120, 35, function(v) S.bhopSpeed = v end)

makeToggle(movementPage, 140, "Infinite Jump", false, function(v) S.infJump = v end)

makeButton(movementPage, 174, "Dash (Q)", doDash)
makeSlider(movementPage, 208, "Dash Power", 50, 300, 100, function(v) S.dashPower = v end)
makeToggle(movementPage, 244, "Mobile Dash Button", true, function(v)
	S.showDashBtn = v
	mobileDashBtn.Visible = v
end)
makeToggle(movementPage, 278, "Lock Dash Button", false, function(v)
	S.dashLocked = v
end)

makeToggle(movementPage, 314, "Spinbot", false, function(v) S.spinbot = v end)
makeSlider(movementPage, 348, "Spin Speed", 5, 100, 30, function(v) S.spinSpeed = v end)

makeToggle(movementPage, 384, "Custom Speed", false, function(v)
	S.speedOn = v
	if not v then local h = getHum(); if h then h.WalkSpeed = 16 end end
end)
makeSlider(movementPage, 418, "Walk Speed", 1, 200, 16, function(v) S.walkSpeed = v end)

makeToggle(movementPage, 454, "Custom Jump Power", false, function(v)
	S.jumpOn = v
	if not v then local h = getHum(); if h then h.JumpPower = 50 end end
end)
makeSlider(movementPage, 488, "Jump Power", 1, 200, 50, function(v) S.jumpPower = v end)

makeToggle(visualPage, 0, "ESP (Box)", false, function(v) 
	S.esp = v 
	if not v then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then
				local old = plr.Character:FindFirstChild("KrytoiESPHolder")
				if old then old:Destroy() end
			end
		end
	end
end)

makeSlider(visualPage, 36, "ESP Red", 0, 255, 255, function(v) S.espR = v end)
makeSlider(visualPage, 70, "ESP Green", 0, 255, 50, function(v) S.espG = v end)
makeSlider(visualPage, 104, "ESP Blue", 0, 255, 50, function(v) S.espB = v end)

makeToggle(visualPage, 142, "Fullbright", false, function(v) S.fullbright = v end)
makeToggle(visualPage, 176, "Nightmode", false, function(v) 
	S.nightmode = v
	if not v then
		Lighting.Brightness = 1
		Lighting.ClockTime = 14.5
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = true
	end
end)

makeToggle(miscPage, 0, "Noclip", false, function(v) S.noclip = v end)
makeToggle(miscPage, 34, "Anti-AFK", false, function(v) S.antiAfk = v end)
makeButton(miscPage, 68, "TP to Death Location", tpToDeath)

-- Настройки тем
local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -6, 0, 20)
themeLabel.Position = UDim2.new(0, 0, 0, 106)
themeLabel.BackgroundTransparency = 1
themeLabel.TextColor3 = Color3.new(1, 1, 1)
themeLabel.Font = Enum.Font.GothamBold
themeLabel.TextSize = 12
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.Text = "Theme: Rainbow"
themeLabel.Parent = miscPage

local themes = {"Rainbow", "Red", "Green", "Blue", "Purple", "Custom"}
local themeIndex = 1
makeButton(miscPage, 130, "Change Theme (Cycle)", function()
	themeIndex = themeIndex % #themes + 1
	S.themeMode = themes[themeIndex]
	themeLabel.Text = "Theme: " .. S.themeMode
end)

makeSlider(miscPage, 164, "Custom R", 0, 255, 255, function(v) S.customR = v end)
makeSlider(miscPage, 198, "Custom G", 0, 255, 255, function(v) S.customG = v end)
makeSlider(miscPage, 232, "Custom B", 0, 255, 255, function(v) S.customB = v end)

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -6, 0, 20)
fpsLabel.Position = UDim2.new(0, 0, 0, 268)
fpsLabel.BackgroundTransparency = 1
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 12
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Text = "FPS & Ping Display: FPS & Ping"
fpsLabel.Parent = miscPage

local fpsPingModes = {"FPS & Ping", "Off"}
local fpsModeIndex = 1
makeButton(miscPage, 292, "Toggle Display Mode", function()
	fpsModeIndex = fpsModeIndex % #fpsPingModes + 1
	S.fpsPingMode = fpsPingModes[fpsModeIndex]
	fpsLabel.Text = "FPS & Ping Display: " .. S.fpsPingMode
	infoFrame.Visible = (S.fpsPingMode ~= "Off")
end)

makeButton(miscPage, 328, "Server Hop (Normal)", function() serverHop("normal") end)
makeButton(miscPage, 362, "Server Hop (Few)", function() serverHop("min") end)
makeButton(miscPage, 396, "Server Hop (Full)", function() serverHop("max") end)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(1, -6, 0, 28)
unloadBtn.Position = UDim2.new(0, 0, 0, 434)
unloadBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
unloadBtn.TextColor3 = Color3.new(1, 1, 1)
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 13
unloadBtn.Text = "Unload Script"
unloadBtn.Parent = miscPage
corner(unloadBtn, 6)

local credit = Instance.new("TextLabel")
credit.Size = UDim2.new(1, 0, 0, 20)
credit.Position = UDim2.new(0, 0, 1, -22)
credit.BackgroundTransparency = 1
credit.Text = "made by @KrytoiBlotnoi"
credit.Font = Enum.Font.GothamBold
credit.TextSize = 13
credit.Parent = main

-- Клавиша Q на ПК
table.insert(connections, UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Q then doDash() end
end))

-- Infinite Jump
table.insert(connections, UIS.JumpRequest:Connect(function()
	if S.infJump then
		local hum = getHum()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end))

-- Anti-AFK
table.insert(connections, player.Idled:Connect(function()
	if S.antiAfk then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.zero)
		end)
	end
end))

-- Fly логика
local bv, bg
local function stopFly()
	if bv then bv:Destroy(); bv = nil end
	if bg then bg:Destroy(); bg = nil end
	local h = getHum()
	if h then h.PlatformStand = false end
end

-- ESP
local function removeEsp(char)
	if not char then return end
	local old = char:FindFirstChild("KrytoiESPHolder")
	if old then old:Destroy() end
end

local function updateEsp(plr)
	if plr == player then return end
	local char = plr.Character
	if not char then return end
	
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		removeEsp(char)
		return
	end

	local holder = char:FindFirstChild("KrytoiESPHolder")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "KrytoiESPHolder"

		local bb = Instance.new("BillboardGui")
		bb.Name = "ESP_Billboard"
		bb.Adornee = root
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(4, 0, 5.5, 0)
		bb.Parent = holder

		local box = Instance.new("Frame")
		box.Name = "BoxFrame"
		box.Size = UDim2.new(1, 0, 1, 0)
		box.BackgroundTransparency = 1
		box.Parent = bb

		local s = Instance.new("UIStroke")
		s.Name = "BoxStroke"
		s.Thickness = 2
		s.Parent = box

		holder.Parent = char
	end

	local bb = holder:FindFirstChild("ESP_Billboard")
	if bb then
		local box = bb:FindFirstChild("BoxFrame")
		if box then
			local strokeObj = box:FindFirstChild("BoxStroke")
			if strokeObj then strokeObj.Color = Color3.fromRGB(S.espR, S.espG, S.espB) end
		end
	end
end

-- Aimbot Visible Check
local function isVisible(targetPart)
	local origin = camera.CFrame.Position
	local targetPos = targetPart.Position
	local params = RaycastParams.new()
	params.FilterType = RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignoreList = { camera }
	if player.Character then table.insert(ignoreList, player.Character) end
	if targetPart.Parent then table.insert(ignoreList, targetPart.Parent) end
	params.FilterDescendantsInstances = ignoreList
	return workspace:Raycast(origin, targetPos - origin, params) == nil
end

local function getBestTarget()
	local bestTarget = nil
	local lowestDist = S.aimFov
	local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Character then
			if not (S.teamCheck and player.Team and plr.Team == player.Team) then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				local head = plr.Character:FindFirstChild("Head")

				if hum and hum.Health > 0 and head then
					local pos, onScreen = camera:WorldToViewportPoint(head.Position)
					if onScreen then
						local distFromCenter = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
						if distFromCenter <= S.aimFov then
							if not S.visCheck or isVisible(head) then
								if distFromCenter < lowestDist then
									lowestDist = distFromCenter
									bestTarget = head
								end
							end
						end
					end
				end
			end
		end
	end
	return bestTarget
end

-- Главный цикл RenderStepped
local lastTick = tick()
local frameCount = 0
local currentFPS = 60

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
	local themeColor = Color3.new(1, 1, 1)
	if S.themeMode == "Rainbow" then
		themeColor = Color3.fromHSV((tick() * 0.4) % 1, 1, 1)
	elseif S.themeMode == "Red" then
		themeColor = Color3.fromRGB(255, 50, 50)
	elseif S.themeMode == "Green" then
		themeColor = Color3.fromRGB(50, 255, 50)
	elseif S.themeMode == "Blue" then
		themeColor = Color3.fromRGB(50, 150, 255)
	elseif S.themeMode == "Purple" then
		themeColor = Color3.fromRGB(180, 50, 255)
	elseif S.themeMode == "Custom" then
		themeColor = Color3.fromRGB(S.customR, S.customG, S.customB)
	end

	credit.TextColor3 = themeColor
	stroke.Color = themeColor
	dashStroke.Color = themeColor
	infoStroke.Color = themeColor

	frameCount += 1
	if tick() - lastTick >= 1 then
		currentFPS = math.floor(frameCount / (tick() - lastTick) + 0.5)
		frameCount = 0
		lastTick = tick()
	end

	local pingVal = 0
	pcall(function()
		pingVal = math.floor(player:GetNetworkPing() * 1000)
	end)

	if S.fpsPingMode == "FPS & Ping" then
		infoText.Text = "FPS: " .. currentFPS .. " | Ping: " .. pingVal .. "ms"
		infoFrame.Size = UDim2.new(0, 145, 0, 32)
	end

	local char, hum, root = getChar(), getHum(), getRoot()

	fovCircle.Visible = S.showFov and S.aimbot
	if S.showFov then fovCircle.Size = UDim2.new(0, S.aimFov * 2, 0, S.aimFov * 2) end

	if S.aimbot then
		local target = getBestTarget()
		if target then camera.CFrame = CFrame.new(camera.CFrame.Position, target.Position) end
	end

	if S.spinbot and root then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(S.spinSpeed), 0)
	end

	if S.bhop and hum and root then
		if hum.MoveDirection.Magnitude > 0 then
			hum.WalkSpeed = S.bhopSpeed
			if hum.FloorMaterial ~= Enum.Material.Air then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end
	end

	if S.fly and hum and root then
		if not bv then
			bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
			bv.Velocity = Vector3.zero
			bv.Parent = root
			bg = Instance.new("BodyGyro")
			bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
			bg.P = 9e4
			bg.Parent = root
		end
		hum.PlatformStand = true
		local move = camera.CFrame:VectorToObjectSpace(hum.MoveDirection)
		local dir = camera.CFrame.LookVector * -move.Z + camera.CFrame.RightVector * move.X
		if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		bv.Velocity = dir * S.flySpeed
		bg.CFrame = camera.CFrame
	elseif bv then
		stopFly()
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			if S.esp then updateEsp(plr) else removeEsp(plr.Character) end
		end
	end

	if S.fullbright then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 7863004
		Lighting.GlobalShadows = false
	elseif S.nightmode then
		Lighting.Brightness = 0.5
		Lighting.ClockTime = 0
		Lighting.FogEnd = 500
		Lighting.GlobalShadows = true
	end
end))

-- Noclip
table.insert(connections, RunService.Stepped:Connect(function()
	if S.noclip then
		local char = getChar()
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end))

-- Unload
bindClick(unloadBtn, function()
	stopFly()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then removeEsp(plr.Character) end
	end
	local h = getHum()
	if h then h.WalkSpeed = 16; h.JumpPower = 50 end
	for _, c in ipairs(connections) do c:Disconnect() end
	gui:Destroy()
end)
