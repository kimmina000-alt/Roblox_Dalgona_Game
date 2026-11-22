-- 첫 60초 안내 화면 (21번, 2026-11-22). 서버 TutorialService가 플레이어 속성 Tutorial(단계, 0 = 없음)을 정함
--  - 할아버지 NPC (이 화면에만 보이는 부품 인형): 내 가게 입구 옆에 서서 머리 위 말풍선으로 지금 단계를 말함
--  - 아래 안내 판 (제작 화면 위에도 보이게 DisplayOrder 높게): 할아버지 말 + 단계 n/6 + 건너뛰기
--  - 가리킬 곳: 작업대·진열대는 빛나는 테두리(Highlight) + 위에서 통통 튀는 화살표, 상점 버튼은 화면 화살표
--  - 알림: 작업대에 가까이 가면 "near", 상점 창을 열면 "shop", 건너뛰기 "skip" → Remotes.Tutorial

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local T = G.Tutorial
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Remotes:WaitForChild("Tutorial")

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = touch and 0.85 or 1
local CREAM = Color3.fromRGB(255, 247, 232)
local BROWN = Color3.fromRGB(92, 58, 36)
local CARAMEL = Color3.fromRGB(222, 150, 70)
local GLOW = Color3.fromRGB(255, 214, 90)

---------------------------------------------------------------- 화면 판

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50 -- 제작 화면(MakingScreen) 위
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -16 * S)
panel.Size = UDim2.fromOffset(520 * S, 92 * S)
panel.BackgroundColor3 = CREAM
panel.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = panel
	local st = Instance.new("UIStroke")
	st.Color = CARAMEL
	st.Thickness = 3
	st.Parent = panel
end
local face = Instance.new("TextLabel")
face.BackgroundTransparency = 1
face.Position = UDim2.fromOffset(10 * S, 10 * S)
face.Size = UDim2.fromOffset(60 * S, 60 * S)
face.Text = "👴"
face.TextScaled = true
face.Parent = panel
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(78 * S, 8 * S)
title.Size = UDim2.new(1, -190 * S, 0, 20 * S)
title.Font = Enum.Font.GothamBlack
title.TextSize = 14 * S
title.TextColor3 = CARAMEL
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "달고나 할아버지"
title.Parent = panel
local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(78 * S, 28 * S)
body.Size = UDim2.new(1, -190 * S, 1, -34 * S)
body.Font = Enum.Font.GothamBold
body.TextSize = 15 * S
body.TextColor3 = BROWN
body.TextWrapped = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Parent = panel
local count = Instance.new("TextLabel")
count.BackgroundTransparency = 1
count.AnchorPoint = Vector2.new(1, 0)
count.Position = UDim2.new(1, -12 * S, 0, 8 * S)
count.Size = UDim2.fromOffset(90 * S, 20 * S)
count.Font = Enum.Font.GothamBold
count.TextSize = 13 * S
count.TextColor3 = CARAMEL
count.TextXAlignment = Enum.TextXAlignment.Right
count.Parent = panel
local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -12 * S, 1, -10 * S)
skip.Size = UDim2.fromOffset(92 * S, 32 * S)
skip.BackgroundColor3 = Color3.fromRGB(200, 190, 180)
skip.Font = Enum.Font.GothamBlack
skip.TextSize = 13 * S
skip.TextColor3 = Color3.new(1, 1, 1)
skip.Text = "건너뛰기"
skip.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = skip
end

-- 상점 버튼을 가리키는 화면 화살표
local uiArrow = Instance.new("TextLabel")
uiArrow.BackgroundTransparency = 1
uiArrow.Size = UDim2.fromOffset(40 * S, 40 * S)
uiArrow.AnchorPoint = Vector2.new(0.5, 0)
uiArrow.Font = Enum.Font.GothamBlack
uiArrow.TextScaled = true
uiArrow.TextColor3 = GLOW
uiArrow.TextStrokeTransparency = 0.2
uiArrow.Text = "⬆"
uiArrow.Visible = false
uiArrow.Parent = gui

---------------------------------------------------------------- 할아버지 NPC (내 화면에만)

local function myPlot()
	local idx = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("ShopPlots")
	return idx and plots and plots:FindFirstChild("Plot" .. idx) or nil
end

local npc = nil
local npcBubble = nil

local function buildNpc()
	local plot = myPlot()
	local entry = plot and plot:FindFirstChild("Entry")
	if not entry then
		return
	end
	-- 입구 옆 (골목 쪽을 봄): 입구에서 부지 오른쪽으로 3칸
	local floor = plot:FindFirstChild("Floor")
	local toward = floor and (entry.Position - floor.Position) or Vector3.new(0, 0, -1)
	toward = Vector3.new(toward.X, 0, toward.Z).Unit
	local side = toward:Cross(Vector3.yAxis).Unit
	local base = entry.Position + side * 3.5 + Vector3.new(0, entry.Size.Y / 2, 0)
	local cf = CFrame.lookAt(base, base + toward)
	local m = Instance.new("Model")
	m.Name = "TutorialGrandpa"
	local function p(name, size, off, color, shape)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CanTouch = false
		x.Size = size
		x.CFrame = cf * off
		x.Color = color
		x.Material = Enum.Material.SmoothPlastic
		if shape then
			x.Shape = shape
		end
		x.Parent = m
		return x
	end
	p("Legs", Vector3.new(0.9, 1.1, 0.5), CFrame.new(0, 0.55, 0), Color3.fromRGB(90, 80, 70))
	p("Body", Vector3.new(1.4, 1.4, 0.9), CFrame.new(0, 1.8, 0), Color3.fromRGB(150, 110, 80)) -- 조끼
	local head = p("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 3.1, 0), Color3.fromRGB(240, 205, 175), Enum.PartType.Ball)
	p("Hair", Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, 3.55, 0.12), Color3.fromRGB(235, 235, 235), Enum.PartType.Ball)
	p("Beard", Vector3.new(0.9, 0.6, 0.4), CFrame.new(0, 2.75, -0.5), Color3.fromRGB(245, 245, 245), Enum.PartType.Ball)
	p("EyeL", Vector3.new(0.14, 0.12, 0.06), CFrame.new(-0.24, 3.18, -0.63), Color3.fromRGB(30, 25, 25))
	p("EyeR", Vector3.new(0.14, 0.12, 0.06), CFrame.new(0.24, 3.18, -0.63), Color3.fromRGB(30, 25, 25))
	p("Cane", Vector3.new(0.15, 2.4, 0.15), CFrame.new(0.95, 1.2, -0.3), Color3.fromRGB(120, 80, 50))
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(240, 70)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.MaxDistance = 120
	bb.AlwaysOnTop = true
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
	t.TextColor3 = BROWN
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextWrapped = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.25, 0)
	c.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = t
	t.Parent = bb
	bb.Parent = head
	m.Parent = workspace
	npc = m
	npcBubble = t
end

---------------------------------------------------------------- 가리키기 (빛나는 테두리 + 통통 튀는 화살표)

local highlight = Instance.new("Highlight")
highlight.Name = "TutorialGlow"
highlight.FillColor = GLOW
highlight.FillTransparency = 0.75
highlight.OutlineColor = GLOW
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = workspace.CurrentCamera -- 내 화면에만, Adornee로 가리킴

local arrow = Instance.new("BillboardGui")
arrow.Name = "TutorialArrow"
arrow.Size = UDim2.fromOffset(60, 60)
arrow.AlwaysOnTop = true
arrow.Enabled = false
arrow.Parent = gui
local arrowText = Instance.new("TextLabel")
arrowText.BackgroundTransparency = 1
arrowText.Size = UDim2.fromScale(1, 1)
arrowText.Font = Enum.Font.GothamBlack
arrowText.TextScaled = true
arrowText.TextColor3 = GLOW
arrowText.TextStrokeTransparency = 0.2
arrowText.Text = "⬇"
arrowText.Parent = arrow

local function targetInstance(key)
	local plot = myPlot()
	if not plot then
		return nil
	end
	if key == "workstation" then
		return plot:FindFirstChild("Workstation")
	elseif key == "shelf" then
		return plot:FindFirstChild("DisplayShelf")
	end
	return nil
end

local function shopButton()
	local hud = playerGui:FindFirstChild("ShopHud")
	return hud and hud:FindFirstChild("ShopButton", true) or nil
end

---------------------------------------------------------------- 단계 보여 주기

local current = 0

local function stepText(n)
	local st = T.steps[n]
	if not st then
		return ""
	end
	return (touch and st.touchText) or st.text
end

local function show(n)
	current = n
	local st = T.steps[n]
	if not st then
		gui.Enabled = false
		highlight.Enabled = false
		arrow.Enabled = false
		uiArrow.Visible = false
		return
	end
	if not npc or not npc.Parent then
		buildNpc()
	end
	gui.Enabled = true
	-- 만드는 동안(3단계)은 제작 화면 아래 버튼을 가리지 않게 위쪽에 둠
	if st.key == "make" then
		panel.AnchorPoint = Vector2.new(0.5, 0)
		panel.Position = UDim2.new(0.5, 0, 0, T.makePanelTop * S)
	else
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -16 * S)
	end
	body.Text = stepText(n)
	count.Text = string.format("%d / %d", n, #T.steps)
	if npcBubble then
		npcBubble.Text = stepText(n)
	end
	local target = st.target and targetInstance(st.target) or nil
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	arrow.Adornee = target
	arrow.Enabled = target ~= nil
	if target then
		local _, size = target:GetBoundingBox()
		arrow.StudsOffset = Vector3.new(0, size.Y / 2 + 2, 0)
	end
	uiArrow.Visible = st.target == "shopButton"
end

local function goodbye()
	gui.Enabled = true
	highlight.Enabled = false
	arrow.Enabled = false
	uiArrow.Visible = false
	body.Text = T.doneText
	count.Text = ""
	skip.Visible = false
	if npcBubble then
		npcBubble.Text = T.doneText
	end
	task.delay(4, function()
		if current == 0 then
			gui.Enabled = false
			if npc then
				npc:Destroy()
				npc = nil
			end
		end
	end)
end

player:GetAttributeChangedSignal("Tutorial"):Connect(function()
	local n = player:GetAttribute("Tutorial") or 0
	if n == 0 and current ~= 0 then
		current = 0
		goodbye()
		return
	end
	skip.Visible = true
	show(n)
end)
if (player:GetAttribute("Tutorial") or 0) > 0 then
	show(player:GetAttribute("Tutorial"))
end

skip.Activated:Connect(function()
	remote:FireServer("skip")
end)

-- 매 프레임: 화살표 통통, 1단계 거리, 6단계 상점 열림, 상점 버튼 화살표 위치
local sentNear, sentShop = false, false
local t = 0
RunService.RenderStepped:Connect(function(dt)
	if current == 0 then
		return
	end
	t += dt
	if arrow.Enabled then
		arrowText.Position = UDim2.fromOffset(0, math.abs(math.sin(t * 4)) * -12)
	end
	if current == 1 and not sentNear then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local ws = targetInstance("workstation")
		if root and ws then
			local d = (ws:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
			if d.Magnitude < T.nearDistance then
				sentNear = true
				remote:FireServer("near")
			end
		end
	end
	if current == 6 then
		local btn = shopButton()
		if btn and btn.Visible and btn.AbsoluteSize.X > 0 then
			uiArrow.Visible = true
			uiArrow.Position = UDim2.fromOffset(btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4 + math.abs(math.sin(t * 4)) * 8)
		else
			uiArrow.Visible = false
		end
		local hud = playerGui:FindFirstChild("ShopHud")
		local shop = hud and hud:FindFirstChild("Shop")
		if shop and shop.Visible and not sentShop then
			sentShop = true
			remote:FireServer("shop")
		end
	end
end)
