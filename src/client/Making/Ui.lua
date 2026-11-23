-- 제작 화면 (DEVELOPMENT_PLAN.md 4-1, 영상 1식 배치)
-- 위: 단계 칩 / 왼쪽: 다음 단계 카드 / 오른쪽: QUALITY 링 + 별 3개 / 아래: 지시문 알약 + 부제(실수하면 빨강)
-- 왼쪽 아래 ✕, 오른쪽 위 진동 토글. 1280x720 기준으로 그리고 UIScale로 줄인다.
-- 2026-11-22 새 스타일(shared/UiStyle): 크림 판 + 나무 테두리, 진한 나무색 안내판, 사탕색 버튼, 둥근 굵은 글꼴. 자리·크기·동작은 그대로.

local GuiService = game:GetService("GuiService")
local HapticService = game:GetService("HapticService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DalgonaConfig"))
local UI = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiStyle"))

local Ui = {}
Ui.__index = Ui

local FONT = Enum.Font.GothamBold -- 표시용: label()이 FontFace(UI.F.heavy)로 바꿈
local FONT_REG = Enum.Font.Gotham -- 표시용: label()이 FontFace(UI.F.bold)로 바꿈
local INK = UI.C.woodDark -- 안내판·바늘·말풍선 바탕 (예전 검정 → 진한 나무색)
local PAPER = UI.C.cream
local RED = UI.C.bad
local GOLD = UI.C.gold
local GREY = UI.C.grey
local SOFT = UI.C.soft -- 보조 글씨
local SUB_INK = UI.C.ink -- 아래 설명 글씨

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	o.Parent = props.Parent
	return o
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = (props.Font == FONT_REG) and UI.F.bold or UI.F.heavy
	props.Font = nil
	props.TextColor3 = props.TextColor3 or INK
	props.TextScaled = false
	return new("TextLabel", props)
end

-- 크림 판 테두리 (나무색)
local function edge(th)
	return new("UIStroke", { Color = UI.C.woodDark, Thickness = th or 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- 글자 테두리 (진한 바탕 위 흰 글자, 밝은 바탕 위 진한 글자를 또렷하게)
local function outline(color, th)
	return new("UIStroke", { Color = color, Thickness = th or 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

-- 사탕 버튼 꾸미기 (TextButton 그대로 두고 색·글꼴·테두리·윤기만): .Text를 바꾸는 코드가 그대로 동작
local function candy(b, color)
	b.AutoButtonColor = true
	b.FontFace = UI.F.heavy
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	edge(3).Parent = b
	outline(UI.darker(color, 0.45), 2).Parent = b
	UI.gloss(0.2).Parent = b
end
local function plain(b)
	b.FontFace = UI.F.heavy
	b.BackgroundColor3 = UI.C.cream
	b.TextColor3 = UI.C.ink
	edge(3).Parent = b
	UI.gloss(0.12).Parent = b
end

function Ui.new(player, steps)
	local self = setmetatable({}, Ui)
	self.steps = steps
	self.vibration = true
	self.onExit = nil
	self.hintUntil = 0
	self.baseSub = ""
	-- 아래 작은 설명 글씨 (2026-11-20 사용자 선택 "처음 몇 판 + 막혔을 때"): 처음 판들은 늘 보이고,
	-- 그 뒤에는 SUB_IDLE초 동안 화면을 안 만지면(막힘) 다시 보임. 실수 힌트(빨간 글씨)는 언제나 보임
	self.subAlways = true
	self.lastInput = os.clock()
	local function touched()
		self.lastInput = os.clock()
	end
	UserInputService.InputBegan:Connect(touched)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			touched()
		end
	end)
	-- 폰: 기준 해상도를 작게 잡고 버튼을 키워서 실제 화면에서 64px 이상이 되게
	self.touch = UserInputService.TouchEnabled
	self.ref = self.touch and Vector2.new(820, 460) or Vector2.new(1280, 720)
	self.btn = self.touch and 96 or 76

	local gui = new("ScreenGui", {
		Name = "MakingScreen",
		ResetOnSpawn = false,
		IgnoreGuiInset = false, -- Roblox 위쪽 메뉴 줄 아래부터 그림 (폰에서 단계 칩과 겹치지 않게)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	self.scale = new("UIScale", { Parent = root })
	self.root = root

	self:_buildChips()
	self:_buildQuality()
	self:_buildBottom()
	self:_buildCorners()
	self:_buildGauge()
	self:_buildMeter()
	self:_buildHeight()
	self:_buildThick()
	self:_buildResult()

	local function rescale()
		local v = gui.AbsoluteSize
		if v.X < 1 or v.Y < 1 then
			v = workspace.CurrentCamera.ViewportSize
		end
		local s = math.clamp(math.min(v.X / self.ref.X, v.Y / self.ref.Y), 0.5, 1.25)
		self.scale.Scale = s
		-- 작업 순서 줄은 Roblox 위쪽 메뉴 줄 높이까지 올림 (메뉴 버튼은 왼쪽 끝이라 안 겹침)
		self.topRow.Position = UDim2.new(0.5, 0, 0, -GuiService:GetGuiInset().Y / s + 20) -- 2026-11-20: 조금 내림
		-- QUALITY 창과 세로 막대는 위 줄 아래 왼쪽에 (위쪽 여백이 0인 기기에서도 안 겹치게)
		local rowBottom = -GuiService:GetGuiInset().Y / s + 20 + (self.touch and 52 or 44)
		local qy = math.max(16, rowBottom + 10)
		-- (사용자 요청 2026-11-19) 왼쪽 아래는 국자 높이를 끄는 손가락에 가려짐 → 온도·높이 막대는 왼쪽 위로, QUALITY는 오른쪽 위로
		self.qualityBox.AnchorPoint = Vector2.new(1, 0)
		-- 오른쪽에는 누름판·틀 같은 도구가 있어서 작게 (72%)
		if not self.qualityBox:FindFirstChild("Shrink") then
			new("UIScale", { Name = "Shrink", Scale = 0.72, Parent = self.qualityBox })
		end
		self.qualityBox.Position = UDim2.new(1, -20, 0, qy)
		self.qualityBox.Visible = false -- 2026-11-20 "오른쪽 상단에 퍼센트 보여 주는 거 삭제"
		-- 2026-11-20 사용자 사진: 온도 막대는 국자 왼쪽, 속도 막대는 국자 오른쪽 (녹이기 화면에서 국자가 가운데)
		-- 위 끝을 안내 문구(검은 칸)와 같은 높이로 (2026-11-20 사진: 빨간 선까지 올림)
		self.meter.AnchorPoint = Vector2.new(0.5, 0)
		self.meter.Position = UDim2.new(0.23, 0, 0, qy)
		self.vgauge.AnchorPoint = Vector2.new(0.5, 0)
		self.vgauge.Position = UDim2.new(0.76, 0, 0, qy)
		-- 국자 들기 화살표는 온도 막대 바로 왼쪽 (2026-11-20 "온도 옆에 붙이고 바 더 두껍게")
		-- 2026-11-20 (폰 사진): 화면 왼쪽 아래 (설명 말풍선은 그 위)
		self.coach.AnchorPoint = Vector2.new(0, 1)
		self.coach.Position = UDim2.new(0, 34, 1, -28)
		self.heightBox.Position = UDim2.fromOffset(76, qy)
		-- 안내 문구(검은 글씨 칸 + 아래 설명)는 위 단계 줄 바로 아래 (2026-11-20)
		self.pill.AnchorPoint = Vector2.new(0.5, 0)
		self.pill.Position = UDim2.new(0.5, 0, 0, qy)
		self.sub.AnchorPoint = Vector2.new(0.5, 0)
		self.sub.Position = UDim2.new(0.5, 0, 0, qy + 62)
		-- 누르기 두께 가로 게이지는 안내 문구 아래 (아래쪽은 누르는 손가락에 가려짐)
		self.gauge.AnchorPoint = Vector2.new(0.5, 0)
		self.gauge.Position = UDim2.new(0.5, 0, 0, qy + 96)
		-- 누르기 두께 세로 막대는 철판 왼쪽 (안내 문구와 같은 높이에서 시작)
		self.pgauge.Position = UDim2.new(0.25, 0, 0, qy + 20)
		if self.toastLabel then
			self.toastLabel.Position = UDim2.new(0.5, 0, 0, qy + 162)
		end
		root.Size = UDim2.fromOffset(v.X / s, v.Y / s)
	end
	rescale()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	return self
end

function Ui:_buildChips()
	-- 위 가운데 줄: [작업 순서 칩] [X]
	self.topRow = new("Frame", {
		Name = "TopRow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = self.root,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local bar = new("Frame", {
		Name = "Chips",
		Size = UDim2.fromOffset(0, self.touch and 52 or 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.05,
		LayoutOrder = 1,
		Parent = self.topRow,
	}, {
		corner(22),
		edge(2.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self.chips = {}
	for i, step in ipairs(self.steps) do
		if i > 1 then
			label({ Text = "—", TextSize = 16, TextColor3 = GREY, Size = UDim2.fromOffset(16, 32), LayoutOrder = i * 2 - 1, Parent = bar })
		end
		local chip = label({
			Text = step.label,
			TextSize = 18,
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = PAPER,
			LayoutOrder = i * 2,
			Parent = bar,
		}, nil)
		corner(16).Parent = chip
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = chip })
		self.chips[i] = chip
	end
end

function Ui:_buildQuality()
	local box = new("Frame", {
		Name = "Quality",
		Position = UDim2.fromOffset(20, 16), -- 왼쪽 위
		Size = UDim2.fromOffset(190, self.touch and 180 or 232),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Parent = self.root,
	}, { corner(18), edge() })
	self.qualityBox = box
	local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1, Parent = box })
	self.dots = {}
	local n = 40
	for i = 1, n do
		local a = math.rad(-90 + (i - 0.5) * 360 / n)
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * 54, 0.5, math.sin(a) * 54),
			Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = GREY,
			BorderSizePixel = 0,
			Parent = ring,
		}, { corner(5) })
		self.dots[i] = dot
	end
	label({ Text = "완성도", TextSize = 13, TextColor3 = SOFT, Position = UDim2.new(0, 0, 0.5, -26), Size = UDim2.new(1, 0, 0, 14), Parent = ring })
	self.qText = label({ Text = "100%", TextSize = 30, Position = UDim2.new(0, 0, 0.5, -10), Size = UDim2.new(1, 0, 0, 34), Parent = ring })
	self.stars = {}
	for i = 1, 3 do
		self.stars[i] = label({ Text = "★", TextSize = 30, TextColor3 = GREY, Position = UDim2.new(0.5, (i - 2) * 36 - 15, 0, 140), Size = UDim2.fromOffset(30, 32), Parent = box })
	end
	label({ Text = "고르게 녹일수록\n황금 달고나 확률↑", Visible = not self.touch, TextSize = 13, Font = FONT_REG, TextColor3 = Color3.fromRGB(110, 100, 90), Position = UDim2.fromOffset(8, 180), Size = UDim2.new(1, -16, 0, 40), Parent = box })
end

function Ui:_buildBottom()
	local pill
	pill = new("Frame", {
		Name = "Instruction",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104), -- 2026-11-20: 위로 올림 (아래 끝은 손가락·홈 바에 가려짐)
		Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.C.wood,
		Parent = self.root,
	}, {
		corner(29),
		edge(3.5),
		UI.gloss(0.25),
		new("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 30) }),
	})
	self.main = label({ Text = "", TextSize = 26, TextColor3 = UI.C.cream, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
	outline(UI.C.woodDark, 2.2).Parent = self.main
	self.pill = pill
	self.sub = label({
		Name = "Sub",
		Text = "",
		TextSize = self.touch and 22 or 18,
		TextColor3 = SUB_INK,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		-- 가운데 칸(온도·속도 막대 사이)에만: 넘치면 두 줄로 (2026-11-20 플레이 테스트: 막대 밑으로 지나감)
		Size = UDim2.new(0.48, 0, 0, 46),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.root,
	})
	-- 크림색 글자 테두리: 분홍 바닥·철판 어디서나 읽히게 (예전 흰 TextStroke 대신)
	outline(UI.C.cream, 2.4).Parent = self.sub
end

function Ui:_buildCorners()
	-- X는 작업 순서 칩 바로 오른쪽, 같은 높이 (2026-11-17 사용자 요청)
	local size = self.touch and 52 or 44 -- 작업 순서 창 높이에 맞춤
	local x = new("TextButton", {
		Name = "Exit",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UI.C.red,
		Text = "X",
		TextSize = self.touch and 26 or 22,
		FontFace = UI.F.round,
		TextColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 2,
		Parent = self.topRow,
	}, { corner(size / 2), new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), outline(UI.darker(UI.C.red, 0.45), 2), UI.gloss(0.2) })
	x.Activated:Connect(function()
		if self.onExit then
			self.onExit()
		end
	end)
	-- 진동 켜기/끄기 버튼은 뺐음 (진동은 항상 켜짐, 나중에 설정 메뉴로)
end

function Ui:_buildGauge()
	local g = new("Frame", {
		Name = "StirGauge",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -132),
		Size = UDim2.fromOffset(380, 58),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = self.root,
	}, { corner(14), edge() })
	self.gaugeTitle = label({ Text = "젓기 속도", TextSize = 13, TextColor3 = SOFT, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Parent = g })
	local track = new("Frame", { Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1, Parent = g })
	local segs = {
		{ "느림", Color3.fromRGB(80, 140, 230) },
		{ "딱 좋아", Color3.fromRGB(80, 190, 90) },
		{ "빠름", Color3.fromRGB(230, 80, 70) },
	}
	self.gaugeSegs = {}
	for i, s in ipairs(segs) do
		local f = new("Frame", { BackgroundColor3 = s[2], BorderSizePixel = 0, Parent = track }, {
			label({ Text = s[1], TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1) }),
		})
		self.gaugeSegs[i] = f
	end
	self.needle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 36), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 3, Parent = track }, { corner(3) })
	self.gauge = g
	-- 젓기 속도 (2026-11-20 사용자 요청): 왼쪽 세로 막대, 거품·온도 창과 같은 길이. 아래 느림 → 위 빠름
	local v = new("Frame", {
		Name = "StirGaugeV",
		Position = UDim2.fromOffset(76, 16),
		Size = UDim2.fromOffset(46, self.touch and 150 or 200),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = self.root,
	}, { corner(12), edge() })
	label({ Text = "속도", TextSize = 13, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 16), Parent = v }) -- 위에 이름 (2026-11-20)
	local vt = new("Frame", { Position = UDim2.fromOffset(13, 26), Size = UDim2.new(1, -26, 1, -54), BackgroundTransparency = 1, Parent = v })
	self.vSegs = {}
	for i, c in ipairs({ Color3.fromRGB(80, 140, 230), Color3.fromRGB(80, 190, 90), Color3.fromRGB(230, 80, 70) }) do
		self.vSegs[i] = new("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, Parent = vt })
	end
	self.vNeedle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 14, 0, 6), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 3, Parent = vt }, { corner(3) })
	self.vTitle = label({ Text = "속도", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(80, 16), Parent = v })
	self.vgauge = v
	-- 누르기 두께 (2026-11-20 폰 사진: 가로 게이지가 반죽을 가림 → 왼쪽 세로 막대). 위 두꺼움 → 아래 너무 얇음,
	-- 누를수록 바늘이 아래로 내려감. 칸 이름은 막대 왼쪽에 (오른쪽은 설명 글씨와 겹침)
	local pg = new("Frame", {
		Name = "PressGaugeV",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(58, self.touch and 190 or 230),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = self.root,
	}, { corner(12), edge() })
	label({ Text = "두께", TextSize = 13, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 16), Parent = pg })
	local pt = new("Frame", { Position = UDim2.fromOffset(15, 26), Size = UDim2.new(1, -30, 1, -54), BackgroundTransparency = 1, Parent = pg })
	self.pSegs = {}
	for i, s in ipairs({ { "두꺼움", Color3.fromRGB(80, 140, 230) }, { "딱 좋아", Color3.fromRGB(80, 190, 90) }, { "너무 얇음", Color3.fromRGB(230, 80, 70) } }) do
		local f = new("Frame", { BackgroundColor3 = s[2], BorderSizePixel = 0, Parent = pt })
		local tag = label({ Text = s[1], TextSize = 13, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = s[2], BackgroundTransparency = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -22, 0.5, 0), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Parent = f })
		corner(8).Parent = tag
		new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = tag })
		self.pSegs[i] = f
	end
	self.pNeedle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 14, 0, 6), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 3, Parent = pt }, { corner(3) })
	self.pTitle = label({ Text = "", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(80, 16), Parent = pg })
	self.pgauge = pg
end

-- 오른쪽 세로 막대: 누르기 두께 / 소다 양 같은 "얼마나"를 보여 줌
function Ui:_buildMeter()
	local m = new("Frame", {
		Name = "Meter",
		Position = UDim2.fromOffset(222, 16), -- QUALITY 창 오른쪽 옆
		Size = UDim2.fromOffset(46, self.touch and 150 or 200),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = self.root,
	}, { corner(12), edge() })
	-- 위에 이름 (2026-11-20 "속도 옆에 온도 표시": 속도 막대처럼 맨 위에 무엇인지 적음)
	self.meterTitle = label({ Text = "", TextSize = 13, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 16), Parent = m })
	local track = new("Frame", { Position = UDim2.fromOffset(13, 26), Size = UDim2.new(1, -26, 1, -54), BackgroundColor3 = Color3.fromRGB(220, 214, 205), BorderSizePixel = 0, Parent = m }, { corner(6) })
	self.meterBand = new("Frame", { BackgroundColor3 = Color3.fromRGB(80, 190, 90), BorderSizePixel = 0, Parent = track })
	self.meterFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = track }, { corner(6) })
	self.meterLabel = label({ Text = "", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(80, 16), Parent = m })
	self.meterTrack = track
	-- 온도일 때는 온도계 모양 (2026-11-20 "온도 팝업 온도계 모양으로"): 유리관 + 아래 빨간 구 + 눈금, 초록 = 알맞은 온도
	local thermo = new("Frame", { Name = "Thermo", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = m })
	local tube = new("Frame", {
		Name = "Tube",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.new(0, 14, 1, -74),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = thermo,
	}, { corner(7), new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(150, 138, 126), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	self.thermoBand = new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 205, 120), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3, Parent = tube })
	self.thermoFill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(1, -4, 0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = tube,
	}, {
		corner(5),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 120, 70), Color3.fromRGB(220, 40, 40)) }),
	})
	-- 알맞은 온도 칸 옆 표시 (관 왼쪽 초록 괄호)
	self.thermoBracket = new("Frame", { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(60, 170, 75), BorderSizePixel = 0, ZIndex = 3, Parent = thermo }, { corner(2) })
	-- 눈금 (관 오른쪽)
	local ticks = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -78), Parent = thermo })
	for i = 0, 5 do
		new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.5, 9, i / 5, 0),
			Size = UDim2.fromOffset(i % 5 == 0 and 7 or 4, 2),
			BackgroundColor3 = Color3.fromRGB(150, 138, 126),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = ticks,
		})
	end
	-- 아래 빨간 구 (관과 이어짐)
	new("Frame", {
		Name = "Bulb",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(225, 50, 45),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = thermo,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(150, 138, 126) }) })
	self.thermo = thermo
	self.thermoTube = tube
	-- 국자 높이 ↔ 온도 연결 (2026-11-20 사용자 요청 "국자 올리면 온도 바 내려가는 거 한눈에"):
	-- 온도 막대 오른쪽 옆 화살표. 국자를 올리는 동안 파란 ▼(온도 내려감), 내리는 동안 빨간 ▲.
	-- 국자 들기 안내(왼쪽 아래 ▲)가 떠 있으면 그 화살표와 같은 박자로 ▼가 내려감
	self.meterTrend = label({
		Name = "TempTrend",
		Text = "▼",
		TextSize = 56,
		TextColor3 = Color3.fromRGB(70, 140, 235),
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 4, 0.3, 0),
		Size = UDim2.fromOffset(60, 60),
		Visible = false,
		ZIndex = 6,
		Parent = m,
	})
	-- 국자 높이를 바꾸는 동안 온도 창 테두리가 잠깐 빛남 (2026-11-20 "온도 팝업에 테두리 넣어서 잠시 강조")
	self.meterStroke = new("UIStroke", { Name = "TrendStroke", Thickness = 4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = m })
	self.meter = m
end

-- 국자 높이 막대 (녹이기·소다): 화면 왼쪽 구역을 위아래로 끌면 국자가 오르내림. 아래 = 불 가까이(빨강)
function Ui:_buildHeight()
	local h = self.touch and 200 or 240
	local box = new("Frame", {
		Name = "Height",
		Position = UDim2.fromOffset(76, 16),
		Size = UDim2.fromOffset(64, h),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = self.root,
	}, { corner(12), edge() })
	label({ Text = "▲ 멀리", TextSize = 12, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 14), Parent = box })
	label({ Text = "불 가까이", TextSize = 11, TextColor3 = RED, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 14), Parent = box })
	local track = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.new(0, 12, 1, -52), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = box }, { corner(6) })
	self.heightTrack = track
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 170, 230)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(80, 190, 90)),
			ColorSequenceKeypoint.new(0.7, GOLD),
			ColorSequenceKeypoint.new(1, RED),
		}),
		Parent = track,
	})
	-- 알맞은 높이 칸 (사용자 요청 2026-11-19: 국자를 적당한 높이로 들라는 안내)
	self.heightBand = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.new(0, 34, 0.35, 0), BackgroundColor3 = Color3.fromRGB(80, 200, 90), BackgroundTransparency = 0.55, Parent = track }, {
		corner(8),
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 150, 60) }),
	})
	label({ Text = "적당", TextSize = 11, TextColor3 = Color3.fromRGB(20, 110, 40), Position = UDim2.new(1, 2, 0.5, -7), Size = UDim2.fromOffset(28, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = self.heightBand })
	self.heightGuide = label({ Text = "", TextSize = 15, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1, BackgroundColor3 = INK, Position = UDim2.new(1, 8, 0.5, -16), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4, Parent = track })
	corner(12).Parent = self.heightGuide
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = self.heightGuide })
	self.heightKnob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	self.heightStroke = new("UIStroke", { Thickness = 3, Color = INK, Parent = self.heightKnob })
	self.heightBox = box
	-- 처음 하는 사람 안내 (사용자 요청 2026-11-20): 손가락이 막대를 따라 위로 끄는 모습 + 말풍선
	-- 높이 막대를 없앤 뒤(2026-11-20)에는 화면 왼쪽(팔이 있는 곳)에서 손가락이 위로 끄는 모습
	-- 2026-11-20: 화면 왼쪽 아래(폰에서 이동 버튼이 있던 자리)에 화살표가 아래에서 위로 올라가는 모습
	-- 2026-11-20 (다시): 화살표는 국자 손잡이 자리에서 위로 (setCoach에 손잡이 화면 위치를 넘김)
	-- 2026-11-20 (세 번째): 온도 막대 바로 왼쪽에 붙은 두꺼운 세로 길 + 아래에서 위로 올라가는 화살표 (위치는 rescale)
	-- 2026-11-20 (네 번째, 폰 사진): 화면 왼쪽 아래로, 길과 화살표를 훨씬 두껍게. 글씨는 길 위에 크게 (위치는 rescale)
	local coach = new("Frame", { Name = "Coach", BackgroundTransparency = 1, Size = UDim2.fromOffset(120, self.touch and 210 or 250), Visible = false, ZIndex = 6, Parent = self.root })
	new("Frame", { Name = "Track", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0, 70, 1, -8), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, ZIndex = 6, Parent = coach }, { corner(35) })
	self.coachFinger = label({ Text = "▲", TextSize = 96, TextColor3 = Color3.fromRGB(255, 120, 160), TextStrokeColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.88, 0), Size = UDim2.fromOffset(110, 100), ZIndex = 7, Parent = coach })
	local bubble = label({
		-- PC는 W/S 키로도 (2026-11-21)
		Text = self.touch and "이 줄을 위로 끌면 국자가 올라가고\n온도가 내려가요 ▼" or "이 줄을 위로 끌거나 W 키 → 국자가 올라가고\n온도가 내려가요 ▼ (S 키는 내림)",
		TextSize = 21,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = Color3.fromRGB(40, 150, 60),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -8),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = coach,
	})
	corner(12).Parent = bubble
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = bubble })
	self.coach = coach
	-- 높이 글씨 안내
	local msg = label({
		Name = "HeightMsg",
		Text = "",
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = INK,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 8,
		Parent = self.root,
	})
	corner(20).Parent = msg
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = msg })
	self.heightMsg = msg
	-- 도구 바로 위에 붙는 안내 글씨 (소다통 등, 2026-11-20)
	local wt = label({
		Name = "WorldTip",
		Text = "",
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = INK,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 8,
		Parent = self.root,
	})
	corner(17).Parent = wt
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = wt })
	self.worldTip = wt
	-- 도구를 가리키는 통통 튀는 화살표 (2026-11-20 "누름판 선택하라고 할 때 화살표로 가리키기")
	local arrow = new("Frame", { Name = "PointArrow", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(120, 96), BackgroundTransparency = 1, Visible = false, ZIndex = 9, Parent = self.root })
	self.arrowTag = label({ Text = "", TextSize = 16, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05, BackgroundColor3 = INK, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 9, Parent = arrow })
	corner(16).Parent = self.arrowTag
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = self.arrowTag })
	label({ Text = "▼", TextSize = 52, TextColor3 = Color3.fromRGB(255, 120, 160), TextStrokeColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(60, 56), ZIndex = 9, Parent = arrow })
	self.arrow = arrow
end

-- 반죽 붓기 판 (2026-11-20 사용자 요청): 화면 오른쪽에 철판과 같은 비율의 반투명 어두운 네모. 이 위를 누르고 끌면
-- 철판의 같은 자리(위 = 철판 안쪽, 오른쪽 = 철판 오른쪽)에 반죽이 떨어짐. 가운데 원 = 설탕 원, 분홍 점 = 떨어지는 자리
function Ui:setPad(visible, u, v, active, ringFrac)
	if not self.pad then
		local pad = new("Frame", { Name = "PourPad", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.56, 0), Size = UDim2.fromOffset(self.touch and 230 or 260, self.touch and 230 or 260), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Visible = false, ZIndex = 5, Parent = self.root }, { corner(16) })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.5, Thickness = 2, Parent = pad })
		self.padRing = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.69, 0.69), BackgroundTransparency = 1, ZIndex = 5, Parent = pad }, { corner(999) })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.35, Thickness = 2, Parent = self.padRing })
		-- 2026-11-20 "오른쪽 분홍 버튼 삭제": 판 위 점은 숨김 (링 = 설탕 원만 남김)
		self.padDot = new("Frame", { Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(255, 120, 160), ZIndex = 6, Parent = pad }, { corner(11) })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = self.padDot })
		label({ Text = "여기를 누르고 끌어요", TextSize = 15, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(1, 0, 0, 20), ZIndex = 5, Parent = pad })
		self.pad = pad
	end
	self.pad.Visible = visible
	if not visible then
		return
	end
	if ringFrac then
		self.padRing.Size = UDim2.fromScale(ringFrac, ringFrac)
	end
	self.padDot.Position = UDim2.fromScale(u or 0.5, v or 0.5)
	self.padDot.Size = active and UDim2.fromOffset(28, 28) or UDim2.fromOffset(22, 22)
	self.padDot.BackgroundTransparency = active and 0 or 0.25
end

-- 화면 점 → 판 위 (u, v) 0~1. 판 밖이면 nil (clamp면 판 끝에 붙여서 돌려줌)
function Ui:padAt(pos, clamp)
	local pad = self.pad
	if not (pad and pad.Visible) then
		return nil
	end
	local p, sz = pad.AbsolutePosition, pad.AbsoluteSize
	local u, v = (pos.X - p.X) / sz.X, (pos.Y - p.Y) / sz.Y
	if clamp then
		return math.clamp(u, 0, 1), math.clamp(v, 0, 1)
	end
	local m = 0.08
	if u < -m or u > 1 + m or v < -m or v > 1 + m then
		return nil
	end
	return math.clamp(u, 0, 1), math.clamp(v, 0, 1)
end

-- 뽑기 판 (2026-11-23 사용자 요청: 붓기 판처럼 뽑기에도 따로 판, 손가락이 도안을 가리지 않게). 붓기 판(PourPad)은
-- 고정 기능이라 건드리지 않고 같은 자리·모양으로 따로 만듦. 판 안 = 화면에 보이는 달고나 둘레를 그대로 줄인 것:
-- 점선(도안)을 작은 점으로 그리고, 판을 누르고 끌면 바늘이 달고나의 같은 자리를 긁음 (Ppopgi가 씀)
function Ui:setPpPad(visible)
	if not self.ppPad then
		local pad = new("Frame", { Name = "PpopgiPad", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.56, 0), Size = UDim2.fromOffset(self.touch and 230 or 260, self.touch and 230 or 260), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ClipsDescendants = true, Visible = false, ZIndex = 5, Parent = self.root }, { corner(16) })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.5, Thickness = 2, Parent = pad })
		label({ Text = "여기를 누르고 따라 그려요", TextSize = 15, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(1, 0, 0, 20), ZIndex = 5, Parent = pad })
		-- 바늘 자리
		self.ppNeedle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(255, 90, 90), ZIndex = 7, Parent = pad }, { corner(7) })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = self.ppNeedle })
		self.ppDots = {}
		self.ppPad = pad
	end
	self.ppPad.Visible = visible
end

-- 판 위 점선 점들 (uv 목록, 0~1)과 바늘 자리. done[i] = 이미 긁은 점
function Ui:setPpPadDots(uvs, done, nu, nv, active)
	local pad = self.ppPad
	if not pad then
		return
	end
	for i, uv in ipairs(uvs) do
		local d = self.ppDots[i]
		if not d then
			d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BorderSizePixel = 0, ZIndex = 6, Parent = pad }, { corner(3) })
			self.ppDots[i] = d
		end
		d.Visible = true
		d.Position = UDim2.fromScale(uv[1], uv[2])
		d.BackgroundColor3 = (done and done[i]) and Color3.fromRGB(255, 200, 90) or Color3.new(1, 1, 1)
		d.BackgroundTransparency = (done and done[i]) and 0 or 0.2
	end
	for i = #uvs + 1, #self.ppDots do
		self.ppDots[i].Visible = false
	end
	self.ppNeedle.Visible = nu ~= nil
	if nu then
		self.ppNeedle.Position = UDim2.fromScale(nu, nv)
		self.ppNeedle.Size = active and UDim2.fromOffset(18, 18) or UDim2.fromOffset(14, 14)
	end
end

-- 화면 점 → 뽑기 판 위 (u, v) 0~1. 판 밖이면 nil (clamp면 판 끝에 붙여서 돌려줌)
function Ui:ppPadAt(pos, clamp)
	local pad = self.ppPad
	if not (pad and pad.Visible) then
		return nil
	end
	local p, sz = pad.AbsolutePosition, pad.AbsoluteSize
	local u, v = (pos.X - p.X) / sz.X, (pos.Y - p.Y) / sz.Y
	if clamp then
		return math.clamp(u, 0, 1), math.clamp(v, 0, 1)
	end
	if u < -0.05 or u > 1.05 or v < -0.05 or v > 1.05 then
		return nil
	end
	return math.clamp(u, 0, 1), math.clamp(v, 0, 1)
end

-- pos = 가리킬 화면 좌표 (nil이면 숨김). 화살표 끝이 pos 바로 위에 오고 위아래로 통통 튐
function Ui:setArrow(pos, text)
	if not pos then
		self.arrow.Visible = false
		return
	end
	local sc = self.scale.Scale
	local bob = math.abs(math.sin(os.clock() * 6)) * 12
	self.arrowTag.Text = text or ""
	self.arrowTag.Visible = text ~= nil and text ~= ""
	self.arrow.Position = UDim2.fromOffset(pos.X / sc, pos.Y / sc - 8 - bob)
	self.arrow.Visible = true
end

-- text가 nil이면 숨김. pos = 화면 좌표(도구 위)
function Ui:setWorldTip(text, pos)
	local wt = self.worldTip
	if not text then
		wt.Visible = false
		return
	end
	local sc = self.scale.Scale
	wt.Text = text
	wt.Position = UDim2.fromOffset(pos.X / sc, pos.Y / sc - 6)
	wt.Visible = true
end

-- 처음 하는 사람에게 국자 높이 끄는 법 보여 주기 (손가락이 막대 아래 → 위로 반복)
function Ui:setCoach(on, pos)
	if not self.coach then
		return
	end
	if self.coach.Visible == on then
		return
	end
	self.coach.Visible = on
	if self.coachTween then
		self.coachTween:Cancel()
		self.coachTween = nil
	end
	if on then
		self.coachFinger.Position = UDim2.new(0.5, 0, 0.88, 0)
		self.coachFinger.TextTransparency = 0
		self.coachTween = TweenService:Create(self.coachFinger, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, 0.25), { Position = UDim2.new(0.5, 0, 0.12, 0), TextTransparency = 0.7 })
		self.coachTween:Play()
		-- 온도 옆 ▼도 같은 순간에 다시 시작 (같은 박자)
		if self.trendTween then
			self.trendTween:Cancel()
			self.trendTween = nil
		end
	end
end

-- 화면 점이 높이 막대 위인가 (막대 상자 + 둘레 여유, 막대를 직접 잡아 끌 수 있게)
function Ui:heightHit(pos)
	local box = self.heightBox
	if not (box and box.Visible) then
		return false
	end
	local p, s = box.AbsolutePosition, box.AbsoluteSize
	local m = 24
	return pos.X > p.X - m and pos.X < p.X + s.X + m and pos.Y > p.Y - m and pos.Y < p.Y + s.Y + m
end

-- 화면 높이 → 막대 위치 (1 = 맨 위 멀리, 0 = 불 가까이)
function Ui:heightAt(y)
	local t = self.heightTrack
	return math.clamp(1 - (y - t.AbsolutePosition.Y) / math.max(t.AbsoluteSize.Y, 1), 0, 1)
end

-- h01: 1 = 가장 높이(불에서 멀리), 0 = 불 바로 위. danger면 빨갛게, active(끄는 중)면 크게
-- band = { lo, hi } 알맞은 높이 (h01 기준)
-- 2026-11-20 (사용자 요청): 높이 막대 대신 글씨로만 알려 줌. 너무 가깝다·적당하다·너무 멀다를 국자 위에 띄웠다가 서서히 사라짐.
-- anchor = 국자의 화면 위치 (없으면 화면 위쪽 가운데)
function Ui:setHeight(visible, h01, danger, active, band, anchor)
	self.heightBox.Visible = false
	if not visible then
		self.coach.Visible = false
		if self.coachTween then
			self.coachTween:Cancel()
			self.coachTween = nil
		end
		self.heightState = nil
		self.heightMsg.Visible = false
		return
	end
	local state
	if danger or (band and h01 < band[1]) then
		state = "near"
	elseif band and h01 > band[2] then
		state = "far"
	else
		state = "ok"
	end
	local now = os.clock()
	local msg = self.heightMsg
	if anchor then
		local sc = self.scale.Scale
		-- 국자 아래에 (위쪽은 안내 문구와 겹침, 2026-11-20 플레이 테스트)
		msg.Position = UDim2.fromOffset(anchor.X / sc, anchor.Y / sc + 110)
	else
		msg.Position = UDim2.new(0.5, 0, 0.3, 0)
	end
	-- 상태가 바뀌거나, 끄는 중이거나, 너무 가까운 채로 1.6초가 지나면 다시 띄움
	if state ~= self.heightState or (active and now - (self.heightShown or 0) > 0.4) or (state == "near" and now - (self.heightShown or 0) > 1.6) then
		self.heightState = state
		self.heightShown = now
		local info = {
			near = { "너무 가까워요! 위로 들어요", RED },
			ok = { "적당해요!", Color3.fromRGB(40, 150, 60) },
			far = { "너무 멀어요 · 조금 내려요", Color3.fromRGB(70, 120, 210) },
		}
		msg.Text = info[state][1]
		msg.BackgroundColor3 = info[state][2]
		msg.Visible = true
		msg.TextTransparency = 0
		msg.BackgroundTransparency = 0.05
		if self.heightTween then
			self.heightTween:Cancel()
		end
		self.heightTween = TweenService:Create(msg, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		self.heightTween:Play()
	end
	do
		return -- 아래는 예전 높이 막대 (안 보임)
	end
	if band then
		self.heightBand.Visible = true
		self.heightBand.Position = UDim2.fromScale(0.5, 1 - band[2])
		self.heightBand.Size = UDim2.new(0, 34, band[2] - band[1], 0)
		local g = self.heightGuide
		if h01 < band[1] then
			g.Text = danger and "▲ 위로 끌어 국자를 들어요!" or "▲ 조금 더 들어요"
			g.BackgroundColor3 = danger and RED or INK
		elseif h01 > band[2] then
			g.Text = "▼ 너무 높아요 · 조금 내려요"
			g.BackgroundColor3 = INK
		else
			g.Text = "좋아요! 이 높이"
			g.BackgroundColor3 = Color3.fromRGB(40, 150, 60)
		end
		g.Position = UDim2.new(1, 34, 1 - math.clamp(h01, 0, 1), 0)
		g.AnchorPoint = Vector2.new(0, 0.5)
		g.Visible = true
	else
		self.heightBand.Visible = false
		self.heightGuide.Visible = false
	end
	self.heightKnob.Position = UDim2.fromScale(0.5, 1 - math.clamp(h01, 0, 1))
	local s = active and 36 or 30
	self.heightKnob.Size = UDim2.fromOffset(s, s)
	self.heightKnob.BackgroundColor3 = danger and RED or Color3.new(1, 1, 1)
	self.heightStroke.Color = danger and RED or INK
end

function Ui:_buildResult()
	local pop = new("Frame", {
		Name = "Result",
		AnchorPoint = self.touch and Vector2.new(1, 0.5) or Vector2.new(0.5, 1),
		Position = self.touch and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(self.touch and 420 or 560, 224 + 132 + self.btn),
		BackgroundColor3 = PAPER,
		Visible = false,
		ZIndex = 10,
		Parent = self.root,
	}, { corner(22), edge(4) })
	self.resTitle = label({ Text = "달고나 완성!", TextSize = 30, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 36), ZIndex = 11, Parent = pop })
	self.resGrade = label({
		Text = "",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		-- 2026-11-20 "노멀·페일 창 더 위로, 베이지 팝업에 반 걸치게": 팝업 위 테두리에 가운데가 오게
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.fromOffset(130, 40),
		Rotation = 8,
		ZIndex = 12,
		Parent = pop,
	})
	corner(10).Parent = self.resGrade
	-- 뽑기 배지 (15번): 왼쪽 위에 걸침 "완벽 뽑기!" / "뽑기 성공", 그 아래 "도감 등록!" (도감은 19번)
	self.resPp = label({
		Text = "",
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(226, 92, 120),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0, 0),
		Size = UDim2.fromOffset(136, 38),
		Rotation = -7,
		Visible = false,
		ZIndex = 12,
		Parent = pop,
	})
	corner(10).Parent = self.resPp
	self.resDex = label({
		Text = "도감 등록!",
		TextSize = 16,
		TextColor3 = INK,
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 26, 0, 36),
		Size = UDim2.fromOffset(104, 28),
		Rotation = -7,
		Visible = false,
		ZIndex = 12,
		Parent = pop,
	})
	corner(9).Parent = self.resDex
	self.resLine = label({ Text = "", TextSize = 17, Font = FONT_REG, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), ZIndex = 11, Parent = pop })
	self.resPrice = label({ Text = "", TextSize = 15, Font = FONT_REG, TextColor3 = Color3.fromRGB(120, 100, 70), Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 20), ZIndex = 11, Parent = pop })
	self.resStars = {}
	for i = 1, 3 do
		self.resStars[i] = label({ Text = "★", TextSize = 48, TextColor3 = GREY, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (i - 2) * 64, 0, 102), Size = UDim2.fromOffset(56, 56), ZIndex = 11, Parent = pop })
	end
	self.resBreak = label({ Text = "", TextSize = 14, Font = FONT_REG, TextColor3 = Color3.fromRGB(110, 100, 90), Position = UDim2.fromOffset(0, 162), Size = UDim2.new(1, 0, 0, 20), ZIndex = 11, Parent = pop })
	-- 단계별 점수 (사용자 요청 2026-11-19: 어디에서 몇 점인지)
	self.resRows = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 186), Size = UDim2.new(1, -40, 0, 126), ZIndex = 11, Parent = pop }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local row = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(self.touch and 400 or 520, self.btn + 8), ZIndex = 11, Parent = pop }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function btn(text, primary, order, name)
		local b = new("TextButton", {
			Name = name,
			Text = text,
			TextSize = 22,
			Size = UDim2.fromOffset(self.touch and (primary and 170 or 105) or (primary and 200 or 140), self.btn),
			LayoutOrder = order,
			ZIndex = 12,
			Parent = row,
		}, { corner(18) })
		if primary then
			candy(b, UI.C.green)
		else
			plain(b)
		end
		return b
	end
	self.btnRetry = btn("다시 하기", true, 1, "Retry")
	self.btnOther = btn("다른 도안", false, 2, "Other")
	self.btnLeave = btn("나가기", false, 3, "Leave")
	self.result = pop

	self.toastLabel = label({
		Text = "",
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = INK,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 20,
		Parent = self.root,
	})
	corner(18).Parent = self.toastLabel
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = self.toastLabel })
end

function Ui:show(on)
	self.gui.Enabled = on
	if not on then
		self.result.Visible = false
		self.gauge.Visible = false
		self.pgauge.Visible = false
		if self.skipBtn then
			self.skipBtn.Visible = false
		end
		self.meter.Visible = false
	end
end

function Ui:setStep(i)
	for j, chip in ipairs(self.chips) do
		local step = self.steps[j]
		if j < i then
			chip.Text = "✓" .. step.label
			chip.BackgroundColor3 = UI.C.tan
			chip.TextColor3 = UI.C.good
		elseif j == i then
			-- 지금 단계 = 노란 사탕
			chip.Text = step.label
			chip.BackgroundColor3 = UI.C.yellow
			chip.TextColor3 = UI.C.woodDark
		else
			chip.Text = step.label
			chip.BackgroundColor3 = PAPER
			chip.TextColor3 = GREY
		end
	end
	local nxt = self.steps[i + 1]
	if not self.cardIcon then
		return -- 다음 단계 카드는 뺐음 (2026-11-17 사용자 요청)
	end
	if nxt then
		self.cardIcon.Text = nxt.icon
		self.cardTitle.Text = nxt.title
		self.cardDesc.Text = nxt.desc
	else
		self.cardIcon.Text = "🎉"
		self.cardTitle.Text = "완성!"
		self.cardDesc.Text = "마지막 단계 · 다 하면 결과를 봐요"
	end
end

local SUB_IDLE = 5
function Ui:subShown()
	return self.subAlways or os.clock() - self.lastInput > SUB_IDLE
end

function Ui:setSubAlways(on)
	self.subAlways = on
end

function Ui:say(main, sub)
	self.main.Text = main
	self.baseSub = sub or ""
	if os.clock() >= self.hintUntil then
		self.sub.Text = self:subShown() and self.baseSub or ""
		self.sub.TextColor3 = SUB_INK
	end
end

-- 실수 힌트: 부제가 1.6초 동안 빨간 글씨
function Ui:hint(text)
	local now = os.clock()
	if self.sub.Text ~= text or now > self.hintUntil - 1.2 then
		self:buzz(0.4, 0.08)
	end
	self.hintUntil = now + 1.6
	self.sub.Text = text
	self.sub.TextColor3 = RED
end

function Ui:tick()
	if self.hintUntil > 0 and os.clock() >= self.hintUntil then
		self.hintUntil = 0
		self.sub.TextColor3 = SUB_INK
	end
	if self.hintUntil == 0 then
		local want = self:subShown() and self.baseSub or ""
		if self.sub.Text ~= want then
			self.sub.Text = want
		end
	end
end

function Ui:setQuality(pct, starCuts)
	pct = math.clamp(pct, 0, 100)
	self.qText.Text = string.format("%d%%", math.floor(pct + 0.5))
	local lit = math.floor(#self.dots * pct / 100 + 0.5)
	local col = pct >= 70 and Color3.fromRGB(80, 190, 90) or (pct >= 50 and GOLD or RED)
	for i, d in ipairs(self.dots) do
		d.BackgroundColor3 = i <= lit and col or Color3.fromRGB(225, 220, 212)
	end
	for i, s in ipairs(self.stars) do
		s.TextColor3 = pct >= starCuts[i] and GOLD or Color3.fromRGB(215, 210, 200)
	end
end

-- 젓기 속도 게이지: speed(rad/s), slow/fast 경계, 오른쪽 끝 = maxSpeed
function Ui:setGauge(visible, speed, slow, fast, title)
	-- 젓기 속도는 왼쪽 세로 막대로 (누르기 게이지는 그대로 가로)
	self.gauge.Visible = false
	self.pgauge.Visible = false -- 누르기 단계도 끝날 때 setGauge(false)로 숨김
	self.vgauge.Visible = visible
	if not visible then
		self.needleX = nil
		return
	end
	do
		local maxS = fast * 1.6
		local a, b = slow / maxS, fast / maxS
		local sg = self.vSegs
		sg[1].Position, sg[1].Size = UDim2.fromScale(0, 1 - a), UDim2.fromScale(1, a)
		sg[2].Position, sg[2].Size = UDim2.fromScale(0, 1 - b), UDim2.fromScale(1, b - a)
		sg[3].Position, sg[3].Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1 - b)
		local now = os.clock()
		local dt = math.min(now - (self.needleT or now), 0.1)
		self.needleT = now
		local target = math.clamp(speed / maxS, 0, 1)
		local x = self.needleX or target
		x += (target - x) * (1 - math.exp(-3 * dt)) -- 2026-11-20 "바가 너무 빨리 움직임": 느긋하게 따라감
		self.needleX = x
		self.vNeedle.Position = UDim2.fromScale(0.5, 1 - x)
		self.vTitle.Text = speed < slow and "느림" or (speed > fast and "빠름" or "적당")
		return
	end
	local maxS = fast * 1.6
	local a, b = slow / maxS, fast / maxS
	local segs = self.gaugeSegs
	segs[1].Position, segs[1].Size = UDim2.fromScale(0, 0), UDim2.fromScale(a, 1)
	segs[2].Position, segs[2].Size = UDim2.fromScale(a, 0), UDim2.fromScale(b - a, 1)
	segs[3].Position, segs[3].Size = UDim2.fromScale(b, 0), UDim2.fromScale(1 - b, 1)
	-- 바늘은 부드럽게 따라감 (약 0.15초). 판정은 그대로 실제 속도로 함
	local now = os.clock()
	local dt = math.min(now - (self.needleT or now), 0.1)
	self.needleT = now
	local target = math.clamp(speed / maxS, 0, 1)
	local x = self.needleX or target
	x += (target - x) * (1 - math.exp(-3 * dt)) -- 2026-11-20 "바가 너무 빨리 움직임": 느긋하게 따라감
	self.needleX = x
	self.needle.Position = UDim2.fromScale(x, 0.5)
	self.gaugeTitle.Text = title or "젓기 속도"
	for i, t in ipairs({ "느림", "딱 좋아", "빠름" }) do
		segs[i]:FindFirstChildOfClass("TextLabel").Text = t
	end
end

-- 누르기 게이지 (사용자 요청 2026-11-19): 이번 누르기 시작 두께(왼쪽) → 가장 얇게(오른쪽). 초록 = 멈출 두께.
-- 바늘이 초록 칸에 있을 때 손을 떼면 됨. 처음엔 천천히, 오래 누를수록 빨리 움직임
function Ui:setPressGauge(visible, h, hStart, hMin, lo, hi)
	self.gauge.Visible = false
	self.pgauge.Visible = visible
	if not visible then
		return
	end
	local span = math.max(hStart - hMin, 1e-3)
	local function x(v)
		return math.clamp((hStart - v) / span, 0, 1)
	end
	local a, b = x(hi), x(lo)
	local segs = self.pSegs
	segs[1].Position, segs[1].Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, a)
	segs[2].Position, segs[2].Size = UDim2.fromScale(0, a), UDim2.fromScale(1, math.max(b - a, 0.02))
	segs[3].Position, segs[3].Size = UDim2.fromScale(0, b), UDim2.fromScale(1, 1 - b)
	self.pNeedle.Position = UDim2.fromScale(0.5, x(h))
	self.pTitle.Text = string.format("%.1fmm", h / Config.Press.h0 * 10)
end

-- 누르기 두께 (사용자 요청 2026-11-19: 두께를 표시하고 점점 얇아지는 게 눈에 보이게).
-- 옆에서 본 반죽 단면: 철판 위 캐러멜색 판이 눌릴수록 낮아짐. 초록 띠 = 이번에 멈출 두께, 숫자 = mm
function Ui:_buildThick()
	local box = new("Frame", {
		Name = "Thick",
		-- 왼쪽 가운데 (가운데 아래는 철판·반죽이라 가림)
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.55, 0),
		Size = UDim2.fromOffset(300, 104),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = self.root,
	}, { corner(16), edge() })
	label({ Text = "두께 (옆에서 본 모습)", TextSize = 13, TextColor3 = SOFT, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Parent = box })
	local area = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 20), Size = UDim2.new(1, -110, 1, -28), Parent = box })
	new("Frame", { Name = "Plate", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(40, 40, 44), BorderSizePixel = 0, Parent = area }, { corner(3) })
	self.thickBand = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, 8, 0, 10), BackgroundColor3 = Color3.fromRGB(80, 200, 90), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 3, Parent = area }, {
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 150, 60), Transparency = 0.2 }),
	})
	self.thickSlab = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.6, 0, 0, 60), BackgroundColor3 = Color3.fromRGB(216, 146, 62), BorderSizePixel = 0, ZIndex = 2, Parent = area }, {
		new("UICorner", { CornerRadius = UDim.new(0, 10) }),
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(150, 80, 30) }),
	})
	self.thickText = label({ Text = "", TextSize = 24, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 4), Size = UDim2.fromOffset(86, 30), TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
	self.thickSub = label({ Text = "", TextSize = 11, TextColor3 = Color3.fromRGB(40, 150, 60), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0.5, 20), Size = UDim2.fromOffset(86, 14), TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
	self.thickBox = box
end

-- h·h0·lo·hi = 반죽 두께(스터드), color = 반죽 색. 처음 두께 h0 = 10mm로 보여 줌
function Ui:setThick(visible, h, h0, lo, hi, color)
	self.thickBox.Visible = visible
	if not visible then
		return
	end
	local H = 64 -- 처음 두께일 때 단면 높이(px)
	local k = math.clamp(h / h0, 0.03, 1.2)
	-- 얇아질수록 옆으로 넓게 퍼짐 (부피 그대로)
	self.thickSlab.Size = UDim2.new(math.clamp(0.42 / math.sqrt(k), 0.3, 1), 0, 0, math.max(2, H * k))
	if color then
		self.thickSlab.BackgroundColor3 = color
	end
	if lo and hi then
		self.thickBand.Visible = true
		self.thickBand.Position = UDim2.new(0.5, 0, 1, -6 - H * lo / h0)
		self.thickBand.Size = UDim2.new(1, 8, 0, math.max(4, H * (hi - lo) / h0))
		self.thickBand.AnchorPoint = Vector2.new(0.5, 1)
		self.thickSub.Text = string.format("목표 %.1fmm", (lo + hi) / 2 / h0 * 10)
	else
		self.thickBand.Visible = false
		self.thickSub.Text = ""
	end
	self.thickText.Text = string.format("%.1fmm", h / h0 * 10)
end

-- title = 막대 위 이름 (온도·소다·거품), text = 아래 값 (151° 등)
-- 온도 막대 옆 화살표 (국자 높이 ↔ 온도). dir: -1 = 국자를 올리는 중(온도 ↓), 1 = 내리는 중(온도 ↑), 0 = 손 안 댐.
-- 매 프레임 부름. 손을 안 대고 국자 들기 안내가 떠 있으면 안내 화살표와 같은 박자로 ▼가 내려가는 모습
local TREND_BLUE, TREND_RED = Color3.fromRGB(70, 140, 235), Color3.fromRGB(230, 70, 60)
function Ui:setTempTrend(dir)
	local a = self.meterTrend
	if not a then
		return
	end
	local now = os.clock()
	if dir ~= 0 then
		self.trendUntil = now + 0.5
		self.trendDir = dir
	end
	local live = self.trendUntil and now < self.trendUntil
	local coach = self.coach and self.coach.Visible
	-- 온도 막대일 때만 (소다 단계 막대는 거품 양이라 국자 높이와 상관없음)
	local isTemp = self.meter.Visible and self.meterTitle.Text == "온도"
	-- 테두리 강조: 끄는 동안 진하게, 손을 떼면 0.4초에 걸쳐 사라짐
	local st = self.meterStroke
	if st then
		local fdt = math.min(now - (self.strokeT or now), 0.1)
		self.strokeT = now
		local k = self.strokeK or 0
		if isTemp and live then
			k = 1
			st.Color = self.trendDir < 0 and TREND_BLUE or TREND_RED
		else
			k = math.max(0, k - fdt / 0.4)
		end
		self.strokeK = k
		st.Transparency = 1 - k
		st.Thickness = 3 + 2 * k
	end
	local mode = (not isTemp) and "off" or (live and "live" or (coach and "coach" or "off"))
	if mode ~= "coach" and self.trendTween then
		self.trendTween:Cancel()
		self.trendTween = nil
	end
	if mode == "off" then
		a.Visible = false
	elseif mode == "live" then
		a.Visible = true
		a.TextTransparency = 0
		a.Text = self.trendDir < 0 and "▼" or "▲"
		a.TextColor3 = self.trendDir < 0 and TREND_BLUE or TREND_RED
		a.Position = UDim2.new(1, 4, 0.5, 0)
	elseif not self.trendTween then
		a.Visible = true
		a.Text = "▼"
		a.TextColor3 = TREND_BLUE
		a.Position = UDim2.new(1, 4, 0.2, 0)
		a.TextTransparency = 0
		-- 국자 들기 안내 화살표(setCoach)와 같은 길이·박자
		self.trendTween = TweenService:Create(a, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, 0.25), { Position = UDim2.new(1, 4, 0.8, 0), TextTransparency = 0.7 })
		self.trendTween:Play()
	end
end

function Ui:setMeter(visible, value01, lo01, hi01, text, title)
	self.meter.Visible = visible
	if not visible then
		return
	end
	-- 온도는 온도계 모양, 다른 것(거품 양 등)은 예전 막대
	local isTemp = title == "온도"
	if self.thermo then
		self.thermo.Visible = isTemp
		self.meterTrack.Visible = not isTemp
		if isTemp then
			local v = math.clamp(value01, 0, 1)
			self.thermoFill.Size = UDim2.new(1, -4, v, 2)
			self.thermoBand.Position = UDim2.fromScale(0, 1 - hi01)
			self.thermoBand.Size = UDim2.fromScale(1, hi01 - lo01)
			-- 관 밖 왼쪽 초록 괄호: 관과 같은 높이 칸
			local tube = self.thermoTube
			local th = tube.AbsoluteSize.Y / math.max(self.scale.Scale, 0.01)
			self.thermoBracket.Position = UDim2.new(0.5, -10, 0, 28 + th * (1 - hi01))
			self.thermoBracket.Size = UDim2.fromOffset(3, math.max(th * (hi01 - lo01), 2))
		end
	end
	self.meterFill.Size = UDim2.fromScale(1, math.clamp(value01, 0, 1))
	self.meterBand.Position = UDim2.fromScale(0, 1 - hi01)
	self.meterBand.Size = UDim2.fromScale(1, hi01 - lo01)
	self.meterLabel.Text = text or ""
	self.meterTitle.Text = title or ""
end

function Ui:toast(text, seconds)
	self.toastLabel.Text = text
	self.toastLabel.Visible = true
	local token = {}
	self.toastToken = token
	task.delay(seconds or 1.8, function()
		if self.toastToken == token then
			self.toastLabel.Visible = false
		end
	end)
end

function Ui:buzz(strength, duration)
	if not self.vibration or not UserInputService.TouchEnabled then
		return
	end
	task.spawn(function()
		pcall(function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, strength)
			task.wait(duration)
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
		end)
	end)
end

-- res = Scoring.compute 결과 (서버 점수), handlers = { retry, other, leave }
function Ui:showResult(res, shape, handlers)
	local GradeColor = {
		Perfect = GOLD,
		Excellent = Color3.fromRGB(110, 190, 80),
		Good = Color3.fromRGB(70, 150, 225),
		Normal = Color3.fromRGB(140, 140, 140),
		Poor = Color3.fromRGB(190, 120, 70),
		Burnt = Color3.fromRGB(60, 40, 30),
	}
	self.gauge.Visible = false
	self.pgauge.Visible = false
	self.meter.Visible = false
	if self.touch then
		-- 폰: 팝업을 오른쪽에 두고 카드·링을 숨겨 달고나가 보이게
		self.topRow.Visible = false
		self.root.Quality.Visible = false
		self.root.Instruction.Visible = false
		self.sub.Visible = false
	end
	self.resTitle.Text = res.burnt and "앗, 타 버렸어요"
		or (res.misshaped and "실패 · 모양이 망가졌어요")
		or (res.cracked and "달고나 완성! (금이 갔어요)" or "달고나 완성!")
	self.resGrade.Text = res.grade
	self.resGrade.BackgroundColor3 = GradeColor[res.grade] or INK
	self.resLine.Text = string.format("%s 달고나 · 완성도 %d%%", shape.name, res.Q)
	self.resPrice.Text = string.format("한 개 %d코인부터 · Perfect면 %d코인", math.floor(shape.price * 0.2 + 0.5), math.floor(shape.price * 1.7 + 0.5))
	-- 뽑기 결과 (15번)
	local pp = res.ppopgi
	self.resPp.Visible = false
	self.resDex.Visible = false
	if pp then
		local priceTxt = pp.price and string.format(" → %d코인", pp.price) or ""
		if pp.broken then
			self.resPrice.Text = "뽑다가 쪼개졌어요 · 팔 수 없어요"
			self.resPp.Text = "쪼개짐"
			self.resPp.BackgroundColor3 = Color3.fromRGB(150, 120, 110)
			self.resPp.Visible = true
		elseif pp.done then
			self.resPrice.Text = string.format("뽑기 성공 · 덤으로 달고나 %d개 더!%s", pp.extraAdded or pp.extra or 1, (pp.extraAdded and pp.extraAdded < (pp.extra or 0)) and " (보관함이 가득 차서 일부만)" or "")
			self.resPp.Text = pp.perfect and "완벽 뽑기!" or "뽑기 성공"
			self.resPp.BackgroundColor3 = pp.perfect and Color3.fromRGB(226, 92, 120) or Color3.fromRGB(110, 170, 120)
			self.resPp.Visible = true
			self.resDex.Visible = pp.dexNew == true
		else
			self.resPrice.Text = string.format("뽑기 %d%%에서 그만둠 · 보너스 없음", math.floor((pp.coverage or 0) / 0.96 * 100))
		end
	end
	self.resBreak.Text = string.format("온도 %d · 소다 %d · 누르기 %d · 모양 %d%s", res.T, res.M, res.P, res.S, res.verified and "  (서버 판정)" or "")
	for _, c in ipairs(self.resRows:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, d in ipairs(res.details or {}) do
		local col = d.score >= 85 and Color3.fromRGB(60, 160, 70) or (d.score >= 60 and Color3.fromRGB(200, 140, 30) or RED)
		local line = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 19), LayoutOrder = i, ZIndex = 11, Parent = self.resRows })
		label({ Text = d.label, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0, 64, 1, 0), ZIndex = 11, Parent = line })
		label({ Text = d.score .. "점", TextSize = 15, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(64, 0), Size = UDim2.new(0, 48, 1, 0), ZIndex = 11, Parent = line })
		local bits = {}
		for _, p in ipairs(d.parts) do
			table.insert(bits, string.format("%s %d", p[1], p[2]))
		end
		-- 한 줄 조언(너무 오래 눌렀어요 등)을 먼저, 없으면 세부 점수
		label({ Text = (d.tip and d.tip ~= "") and d.tip or table.concat(bits, " · "), TextSize = 13, Font = FONT_REG, TextColor3 = Color3.fromRGB(110, 100, 90), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(124, 0), Size = UDim2.new(1, -124, 1, 0), ZIndex = 11, Parent = line })
	end
	for _, s in ipairs(self.resStars) do
		s.TextColor3 = Color3.fromRGB(215, 210, 200)
		s.TextSize = 48
	end
	self.result.Visible = true
	-- 별이 0.2초 간격으로 채워짐
	task.spawn(function()
		task.wait(0.3)
		for i = 1, res.stars do
			if not self.result.Visible then
				return
			end
			local s = self.resStars[i]
			s.TextColor3 = GOLD
			s.TextSize = 64
			Sfx.play("pop", 0.7, 1 + 0.18 * i) -- 별 하나마다 "뽁" (점점 높게)
			TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 48 }):Play()
			self:buzz(0.3, 0.05)
			task.wait(0.2)
		end
	end)
	if self.resConns then
		for _, c in ipairs(self.resConns) do
			c:Disconnect()
		end
	end
	self.resConns = {
		self.btnRetry.Activated:Connect(function()
			Sfx.play("pop", 0.6, 1.1)
			handlers.retry()
		end),
		self.btnOther.Activated:Connect(function()
			Sfx.play("pop", 0.6, 1.1)
			handlers.other()
		end),
		self.btnLeave.Activated:Connect(function()
			Sfx.play("pop", 0.6, 0.9)
			handlers.leave()
		end),
	}
end

-- 고르기 창 (2026-11-20 "결과에 따라 포장할지 말지 플레이어가 선택"): 제목 + 설명 + 버튼 두 개.
-- 돌려준 표의 choice가 1(첫 버튼) 또는 2가 되면 고른 것. 고르면 창이 닫힘
function Ui:ask(title, sub, first, second)
	if not self.askPop then
		local pop = new("Frame", {
			Name = "Ask",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.fromOffset(self.touch and 400 or 480, 132 + self.btn),
			BackgroundColor3 = PAPER,
			Visible = false,
			ZIndex = 10,
			Parent = self.root,
		}, { corner(22), edge(4) })
		self.askTitle = label({ Text = "", TextSize = 24, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), ZIndex = 11, Parent = pop })
		self.askSub = label({ Text = "", TextSize = 16, Font = FONT_REG, TextColor3 = Color3.fromRGB(110, 100, 90), Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, ZIndex = 11, Parent = pop })
		local row = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -36, 0, self.btn), ZIndex = 11, Parent = pop }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local function btn(primary, order, name)
			local b = new("TextButton", {
				Name = name,
				Text = "",
				TextSize = 22,
				Size = UDim2.new(0.5, -6, 1, 0),
				LayoutOrder = order,
				ZIndex = 12,
				Parent = row,
			}, { corner(18) })
			if primary then
				candy(b, UI.C.yellow)
			else
				plain(b)
			end
			return b
		end
		self.askA = btn(true, 1, "First")
		self.askB = btn(false, 2, "Second")
		self.askPop = pop
	end
	if self.askConns then
		for _, c in ipairs(self.askConns) do
			c:Disconnect()
		end
	end
	local state = { choice = nil }
	self.askTitle.Text = title
	self.askSub.Text = sub or ""
	self.askA.Text = first
	self.askB.Text = second
	self.askPop.Visible = true
	local function pick(i)
		if state.choice then
			return
		end
		state.choice = i
		self.askPop.Visible = false
		Sfx.play("pop", 0.6, i == 1 and 1.1 or 0.9)
	end
	self.askConns = {
		self.askA.Activated:Connect(function()
			pick(1)
		end),
		self.askB.Activated:Connect(function()
			pick(2)
		end),
	}
	function state.close()
		self.askPop.Visible = false
	end
	return state
end

-- 모양 찍기를 건너뛰는 버튼 (2026-11-20 "모양틀 안 찍을 수도 있게, 깜빡하고 못 찍는 상황도 있음. 그럼 감점").
-- 화면 오른쪽 아래. 보이게 하면 상태 { clicked } 를 돌려줌
function Ui:setSkip(visible, text)
	if not self.skipBtn then
		self.skipBtn = new("TextButton", {
			Name = "SkipStamp",
			Text = "",
			TextSize = 18,
			FontFace = UI.F.heavy,
			TextColor3 = UI.C.ink,
			BackgroundColor3 = PAPER,
			BackgroundTransparency = 0.05,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -20),
			Size = UDim2.fromOffset(0, 46),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = false,
			ZIndex = 8,
			Parent = self.root,
		}, { corner(23), new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }), edge(3) })
	end
	if self.skipConn then
		self.skipConn:Disconnect()
		self.skipConn = nil
	end
	self.skipBtn.Visible = visible
	if not visible then
		return nil
	end
	self.skipBtn.Text = text or "건너뛰기"
	local state = { clicked = false }
	self.skipConn = self.skipBtn.Activated:Connect(function()
		state.clicked = true
		Sfx.play("pop", 0.5, 0.9)
	end)
	return state
end

function Ui:hideResult()
	self.result.Visible = false
	self.topRow.Visible = true
	self.root.Quality.Visible = false -- 퍼센트 창은 안 씀 (2026-11-20)
	self.root.Instruction.Visible = true
	self.sub.Visible = true
end

return Ui
