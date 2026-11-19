-- 제작 화면 (DEVELOPMENT_PLAN.md 4-1, 영상 1식 배치)
-- 위: 단계 칩 / 왼쪽: 다음 단계 카드 / 오른쪽: QUALITY 링 + 별 3개 / 아래: 지시문 알약 + 부제(실수하면 빨강)
-- 왼쪽 아래 ✕, 오른쪽 위 진동 토글. 1280x720 기준으로 그리고 UIScale로 줄인다.

local GuiService = game:GetService("GuiService")
local HapticService = game:GetService("HapticService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DalgonaConfig"))

local Ui = {}
Ui.__index = Ui

local FONT = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham
local INK = Color3.fromRGB(24, 22, 22)
local PAPER = Color3.fromRGB(255, 250, 240)
local RED = Color3.fromRGB(230, 60, 50)
local GOLD = Color3.fromRGB(255, 190, 30)
local GREY = Color3.fromRGB(175, 170, 165)

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
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or INK
	props.TextScaled = false
	return new("TextLabel", props)
end

function Ui.new(player, steps)
	local self = setmetatable({}, Ui)
	self.steps = steps
	self.vibration = true
	self.onExit = nil
	self.hintUntil = 0
	self.baseSub = ""
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
		self.meter.Position = UDim2.fromOffset(20, qy)
		self.heightBox.Position = UDim2.fromOffset(76, qy)
		self.vgauge.Position = UDim2.fromOffset(76, qy) -- 젓기 속도: 거품·온도 창 오른쪽 옆, 같은 길이
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
		BackgroundTransparency = 0.1,
		LayoutOrder = 1,
		Parent = self.topRow,
	}, {
		corner(22),
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
	}, { corner(18) })
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
	label({ Text = "QUALITY", TextSize = 12, TextColor3 = GREY, Position = UDim2.new(0, 0, 0.5, -26), Size = UDim2.new(1, 0, 0, 14), Parent = ring })
	self.qText = label({ Text = "100%", TextSize = 30, Position = UDim2.new(0, 0, 0.5, -10), Size = UDim2.new(1, 0, 0, 34), Parent = ring })
	self.stars = {}
	for i = 1, 3 do
		self.stars[i] = label({ Text = "★", TextSize = 30, TextColor3 = GREY, Position = UDim2.new(0.5, (i - 2) * 36 - 15, 0, 140), Size = UDim2.fromOffset(30, 32), Parent = box })
	end
	label({ Text = "고르게 녹일수록\n황금 달고나 확률↑", Visible = not self.touch, TextSize = 13, Font = FONT_REG, TextColor3 = Color3.fromRGB(110, 100, 90), Position = UDim2.fromOffset(8, 180), Size = UDim2.new(1, -16, 0, 40), Parent = box })
end

function Ui:_buildBottom()
	local pill = new("Frame", {
		Name = "Instruction",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -58),
		Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = INK,
		Parent = self.root,
	}, {
		corner(29),
		new("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 30) }),
	})
	self.main = label({ Text = "", TextSize = 26, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
	self.sub = label({
		Name = "Sub",
		Text = "",
		TextSize = self.touch and 22 or 18,
		TextColor3 = Color3.fromRGB(70, 66, 62),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(700, 26),
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		Parent = self.root,
	})
end

function Ui:_buildCorners()
	-- X는 작업 순서 칩 바로 오른쪽, 같은 높이 (2026-11-17 사용자 요청)
	local size = self.touch and 52 or 44 -- 작업 순서 창 높이에 맞춤
	local x = new("TextButton", {
		Name = "Exit",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.1,
		Text = "X",
		TextSize = self.touch and 26 or 22,
		Font = FONT,
		TextColor3 = INK,
		LayoutOrder = 2,
		Parent = self.topRow,
	}, { corner(size / 2) })
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
	}, { corner(14) })
	self.gaugeTitle = label({ Text = "STIR SPEED", TextSize = 12, TextColor3 = GREY, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Parent = g })
	local track = new("Frame", { Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1, Parent = g })
	local segs = {
		{ "SLOW", Color3.fromRGB(80, 140, 230) },
		{ "JUST RIGHT", Color3.fromRGB(80, 190, 90) },
		{ "FAST", Color3.fromRGB(230, 80, 70) },
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
	}, { corner(12) })
	local vt = new("Frame", { Position = UDim2.fromOffset(13, 12), Size = UDim2.new(1, -26, 1, -40), BackgroundTransparency = 1, Parent = v })
	self.vSegs = {}
	for i, c in ipairs({ Color3.fromRGB(80, 140, 230), Color3.fromRGB(80, 190, 90), Color3.fromRGB(230, 80, 70) }) do
		self.vSegs[i] = new("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, Parent = vt })
	end
	self.vNeedle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 14, 0, 6), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 3, Parent = vt }, { corner(3) })
	self.vTitle = label({ Text = "속도", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(80, 16), Parent = v })
	self.vgauge = v
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
	}, { corner(12) })
	local track = new("Frame", { Position = UDim2.fromOffset(13, 12), Size = UDim2.new(1, -26, 1, -40), BackgroundColor3 = Color3.fromRGB(220, 214, 205), BorderSizePixel = 0, Parent = m }, { corner(6) })
	self.meterBand = new("Frame", { BackgroundColor3 = Color3.fromRGB(80, 190, 90), BorderSizePixel = 0, Parent = track })
	self.meterFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = track }, { corner(6) })
	self.meterLabel = label({ Text = "", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(80, 16), Parent = m })
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
	}, { corner(12) })
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
	local coach = new("Frame", { Name = "Coach", BackgroundTransparency = 1, Position = UDim2.new(0, 60, 0.35, 0), Size = UDim2.new(0, 300, 0.4, 0), Visible = false, ZIndex = 6, Parent = self.root })
	self.coachFinger = label({ Text = "👆", TextSize = 40, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -40, 0.85, 0), Size = UDim2.fromOffset(44, 44), ZIndex = 7, Parent = coach })
	local bubble = label({
		Text = "왼쪽(팔)을 잡고 위로 끌면\n국자가 올라가요!",
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = Color3.fromRGB(40, 150, 60),
		Position = UDim2.new(0, 30, 0, -6),
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
function Ui:setCoach(on)
	if not self.coach or self.coach.Visible == on then
		return
	end
	self.coach.Visible = on
	if self.coachTween then
		self.coachTween:Cancel()
		self.coachTween = nil
	end
	if on then
		self.coachFinger.Position = UDim2.new(0, -40, 0.85, 0)
		self.coachTween = TweenService:Create(self.coachFinger, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 0.35), { Position = UDim2.new(0, -40, 0.2, 0) })
		self.coachTween:Play()
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
		msg.Position = UDim2.fromOffset(anchor.X / sc, anchor.Y / sc - 70)
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
	}, { corner(22) })
	self.resTitle = label({ Text = "달고나 완성!", TextSize = 30, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 36), ZIndex = 11, Parent = pop })
	self.resGrade = label({
		Text = "",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(130, 40),
		Rotation = 8,
		ZIndex = 12,
		Parent = pop,
	})
	corner(10).Parent = self.resGrade
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
			TextSize = 20,
			Font = FONT,
			TextColor3 = primary and Color3.new(1, 1, 1) or INK,
			BackgroundColor3 = primary and INK or Color3.fromRGB(232, 226, 216),
			Size = UDim2.fromOffset(self.touch and (primary and 170 or 105) or (primary and 200 or 140), self.btn),
			LayoutOrder = order,
			ZIndex = 12,
			Parent = row,
		}, { corner(18) })
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
		BackgroundTransparency = 0.15,
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
		self.meter.Visible = false
	end
end

function Ui:setStep(i)
	for j, chip in ipairs(self.chips) do
		local step = self.steps[j]
		if j < i then
			chip.Text = "✓" .. step.label
			chip.BackgroundColor3 = Color3.fromRGB(236, 230, 220)
			chip.TextColor3 = Color3.fromRGB(90, 150, 80)
		elseif j == i then
			chip.Text = step.label
			chip.BackgroundColor3 = INK
			chip.TextColor3 = Color3.new(1, 1, 1)
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

function Ui:say(main, sub)
	self.main.Text = main
	self.baseSub = sub or ""
	if os.clock() >= self.hintUntil then
		self.sub.Text = self.baseSub
		self.sub.TextColor3 = Color3.fromRGB(70, 66, 62)
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
		self.sub.Text = self.baseSub
		self.sub.TextColor3 = Color3.fromRGB(70, 66, 62)
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
		x += (target - x) * (1 - math.exp(-7 * dt))
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
	x += (target - x) * (1 - math.exp(-7 * dt))
	self.needleX = x
	self.needle.Position = UDim2.fromScale(x, 0.5)
	self.gaugeTitle.Text = title or "STIR SPEED"
	for i, t in ipairs({ "SLOW", "JUST RIGHT", "FAST" }) do
		segs[i]:FindFirstChildOfClass("TextLabel").Text = t
	end
end

-- 누르기 게이지 (사용자 요청 2026-11-19): 이번 누르기 시작 두께(왼쪽) → 가장 얇게(오른쪽). 초록 = 멈출 두께.
-- 바늘이 초록 칸에 있을 때 손을 떼면 됨. 처음엔 천천히, 오래 누를수록 빨리 움직임
function Ui:setPressGauge(visible, h, hStart, hMin, lo, hi)
	self.gauge.Visible = visible
	if not visible then
		return
	end
	local span = math.max(hStart - hMin, 1e-3)
	local function x(v)
		return math.clamp((hStart - v) / span, 0, 1)
	end
	local a, b = x(hi), x(lo)
	local segs = self.gaugeSegs
	segs[1].Position, segs[1].Size = UDim2.fromScale(0, 0), UDim2.fromScale(a, 1)
	segs[2].Position, segs[2].Size = UDim2.fromScale(a, 0), UDim2.fromScale(math.max(b - a, 0.02), 1)
	segs[3].Position, segs[3].Size = UDim2.fromScale(b, 0), UDim2.fromScale(1 - b, 1)
	for i, t in ipairs({ "두꺼움", "딱 좋아", "너무 얇음" }) do
		segs[i]:FindFirstChildOfClass("TextLabel").Text = t
	end
	self.needle.Position = UDim2.fromScale(x(h), 0.5)
	self.gaugeTitle.Text = string.format("두께 %.1fmm · 오래 누를수록 빨라져요", h / Config.Press.h0 * 10)
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
	}, { corner(16) })
	label({ Text = "두께 (옆에서 본 모습)", TextSize = 12, TextColor3 = GREY, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Parent = box })
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

function Ui:setMeter(visible, value01, lo01, hi01, text)
	self.meter.Visible = visible
	if not visible then
		return
	end
	self.meterFill.Size = UDim2.fromScale(1, math.clamp(value01, 0, 1))
	self.meterBand.Position = UDim2.fromScale(0, 1 - hi01)
	self.meterBand.Size = UDim2.fromScale(1, hi01 - lo01)
	self.meterLabel.Text = text or ""
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

function Ui:hideResult()
	self.result.Visible = false
	self.topRow.Visible = true
	self.root.Quality.Visible = true
	self.root.Instruction.Visible = true
	self.sub.Visible = true
end

return Ui
