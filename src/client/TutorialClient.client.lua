-- 첫 60초 안내 화면 (21번, 2026-11-22). 서버 TutorialService가 플레이어 속성 Tutorial(단계, 0 = 없음)을 정함
--  - (2026-11-25부터 안 씀) 할아버지 NPC — 사용자 "할아버지 삭제하고 그냥 텍스트랑 화살표로만 안내"
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
-- 2026-11-23 새 스타일(shared/UiStyle): 크림 말풍선 판 + 나무 테두리, 이름은 나무 리본, 할아버지 얼굴은 동그란 액자
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local CREAM = UI.C.cream
local BROWN = UI.C.ink
local CARAMEL = UI.C.woodLight
local GLOW = Color3.fromRGB(255, 214, 90)
local PANEL_W, PANEL_H = 580, 104 -- 폰에서도 글씨가 읽히게 (예전 520x92)

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
panel.Size = UDim2.fromOffset(PANEL_W * S, PANEL_H * S)
panel.BackgroundColor3 = CREAM
panel.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 18)
	c.Parent = panel
	local st = Instance.new("UIStroke")
	st.Color = UI.C.woodDark
	st.Thickness = 3.5
	st.Parent = panel
end
-- 할아버지 얼굴: 판 왼쪽에 걸친 동그란 나무 액자
local faceRing = Instance.new("Frame")
faceRing.AnchorPoint = Vector2.new(0, 0.5)
faceRing.Position = UDim2.new(0, 10 * S, 0.5, 0)
faceRing.Size = UDim2.fromOffset(70 * S, 70 * S)
faceRing.BackgroundColor3 = UI.C.tan
faceRing.Parent = panel
UI.corner("round").Parent = faceRing
UI.stroke(UI.C.woodDark, 3).Parent = faceRing
local face = Instance.new("TextLabel")
face.BackgroundTransparency = 1
face.Position = UDim2.fromScale(0.12, 0.12)
face.Size = UDim2.fromScale(0.76, 0.76)
face.Text = "👴"
face.TextScaled = true
face.Parent = faceRing
faceRing.Visible = false -- 2026-11-25: 할아버지 없이 글씨·화살표로만 안내
-- 이름: 판 위 모서리에 걸친 나무 리본
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0, 0.5)
title.Position = UDim2.fromOffset(88 * S, 0)
title.Size = UDim2.fromOffset(0, 26 * S)
title.AutomaticSize = Enum.AutomaticSize.X
title.BackgroundColor3 = UI.C.wood
title.FontFace = UI.F.heavy
title.TextSize = 16 * S
title.TextColor3 = UI.C.cream
title.Text = "달고나 할아버지"
title.Visible = false -- 2026-11-25: 할아버지 없이 (이름 리본도 숨김)
title.Parent = panel
UI.corner(8).Parent = title
UI.stroke(UI.C.woodDark, 2.5).Parent = title
UI.stroke(UI.C.woodDark, 1.8, true).Parent = title
do
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12 * S)
	pad.PaddingRight = UDim.new(0, 12 * S)
	pad.Parent = title
end
local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(92 * S, 18 * S)
body.Size = UDim2.new(1, -210 * S, 1, -24 * S)
body.FontFace = UI.F.heavy
body.TextSize = 18 * S
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
count.FontFace = UI.F.round
count.TextSize = 15 * S
count.TextColor3 = UI.C.soft
count.TextXAlignment = Enum.TextXAlignment.Right
count.Parent = panel
local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -12 * S, 1, -10 * S)
skip.Size = UDim2.fromOffset(104 * S, 44 * S)
skip.BackgroundColor3 = UI.C.grey
skip.FontFace = UI.F.heavy
skip.TextSize = 16 * S
skip.TextColor3 = Color3.new(1, 1, 1)
skip.Text = "건너뛰기"
skip.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = skip
	UI.stroke(UI.C.woodDark, 2.5).Parent = skip
	UI.stroke(UI.darker(UI.C.grey, 0.45), 1.8, true).Parent = skip
	UI.gloss(0.2).Parent = skip
end

-- 상점 버튼을 가리키는 화면 화살표
local uiArrow = Instance.new("TextLabel")
uiArrow.BackgroundTransparency = 1
uiArrow.Size = UDim2.fromOffset(40 * S, 40 * S)
uiArrow.AnchorPoint = Vector2.new(0.5, 0)
uiArrow.FontFace = UI.F.heavy
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
	t.BackgroundColor3 = CREAM
	t.TextColor3 = BROWN
	t.FontFace = UI.F.heavy
	UI.stroke(UI.C.woodDark, 3).Parent = t
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
arrowText.FontFace = UI.F.heavy
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
	-- 2026-11-25 사용자 "처음 시작할 때 할아버지 삭제하고 그냥 텍스트랑 화살표로만 안내하기":
	-- 할아버지 NPC(buildNpc)·얼굴 액자·이름 리본은 안 씀. 아래 안내 판 글씨 + 물건 위 화살표/빛 + 버튼 화살표만.
	gui.Enabled = true
	-- 만드는 동안(3단계): 아래 가운데에 작게, 건너뛰기 없이, 입력을 막지 않게 (누르기·찍기는 화면 어디를 눌러도 되는 단계)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	if st.key == "make" then
		local mp = T.makePanel
		local w = math.min(mp.width * S, gui.AbsoluteSize.X * mp.maxWidthScale)
		panel.Size = UDim2.fromOffset(w, mp.height * S)
		panel.Position = UDim2.new(0.5, 0, 1, -mp.bottom * S)
		panel.Active = false
		skip.Visible = false
		-- 작은 판: 글씨를 판 전체 폭으로
		body.Position = UDim2.fromOffset(14 * S, 16 * S)
		body.Size = UDim2.new(1, -28 * S, 1, -20 * S)
		body.TextSize = 15 * S
	else
		panel.Size = UDim2.fromOffset(PANEL_W * S, PANEL_H * S)
		panel.Position = UDim2.new(0.5, 0, 1, -16 * S)
		skip.Visible = true
		body.Position = UDim2.fromOffset(18 * S, 14 * S)
		body.Size = UDim2.new(1, -140 * S, 1, -20 * S)
		body.TextSize = 18 * S
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
local lastMaking = 0
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
	if current > 0 and current <= 2 then
		local ms = playerGui:FindFirstChild("MakingScreen")
		if ms and ms.Enabled and os.clock() - lastMaking > 1 then
			lastMaking = os.clock()
			remote:FireServer("making") -- 제작 화면이 열리면 3단계 (도안 고르기부터, 서버 시작은 고른 뒤)
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
