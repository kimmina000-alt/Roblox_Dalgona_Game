-- 공통 UI 스타일 (2026-11-22, 사용자 참고 그림: 아늑한 나무 가게 + 통통한 사탕 버튼)
-- 나무 판 테두리, 크림색 카드, 아래 그림자가 있는 두툼한 버튼, 빨간 동그라미 닫기, 나무 리본 제목판,
-- 어두운 반투명 자원 알약, 빨간 ! 알림 배지.
-- 폰 우선: 화면 크기에 맞춰 UIScale(폰 가로 ≈ 0.78), 노치·Roblox 메뉴는 ScreenInsets로 피한다.
-- 쓰는 법: local UI = require(ReplicatedStorage.Shared.UiStyle)
--   local gui = UI.screen("ShopHud", 5, playerGui); local root = UI.root(gui); local fit = UI.fitter(root); fit(frame)  -- 크기 맞춤
--   UI.button({ Text = "사기", Color = UI.C.yellow, Size = ..., Parent = ... }) / UI.setButton(btn, {...})
--   local outer, body = UI.window({ Title = "재료 상점", Size = ..., Parent = gui, OnClose = fn })

local UserInputService = game:GetService("UserInputService")

local UI = {}

---------------------------------------------------------------- 색
UI.C = {
	woodDark = Color3.fromRGB(78, 46, 26), -- 테두리 선·진한 글자
	wood = Color3.fromRGB(150, 96, 56), -- 창 나무 판
	woodLight = Color3.fromRGB(196, 136, 82), -- 리본 제목판·탭
	woodInner = Color3.fromRGB(104, 66, 38), -- 창 안쪽 바탕
	cream = Color3.fromRGB(255, 246, 226), -- 카드
	tan = Color3.fromRGB(240, 220, 186), -- 카드 안 칸·아이콘 받침
	line = Color3.fromRGB(214, 176, 128), -- 카드 테두리
	ink = Color3.fromRGB(74, 44, 24), -- 본문 글자
	soft = Color3.fromRGB(150, 110, 80), -- 보조 글자
	white = Color3.new(1, 1, 1),
	-- 버튼 (사탕 색)
	yellow = Color3.fromRGB(255, 196, 46),
	red = Color3.fromRGB(240, 82, 70),
	green = Color3.fromRGB(116, 200, 66),
	cyan = Color3.fromRGB(60, 196, 228),
	blue = Color3.fromRGB(74, 112, 232),
	pink = Color3.fromRGB(255, 128, 160),
	grey = Color3.fromRGB(176, 164, 150),
	-- 상태
	good = Color3.fromRGB(70, 160, 50),
	bad = Color3.fromRGB(214, 64, 52),
	gold = Color3.fromRGB(255, 206, 60),
	pill = Color3.fromRGB(60, 36, 20), -- 자원 알약 바탕 (반투명)
}

---------------------------------------------------------------- 글꼴
-- 한글은 Roblox가 굵기에 맞는 한글 글꼴로 대신 그린다. 숫자·영문은 둥근 Fredoka.
UI.F = {
	bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	heavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
	regular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	round = Font.new("rbxasset://fonts/families/FredokaOne.json"),
}

UI.touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

---------------------------------------------------------------- 기본 만들기
function UI.new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	o.Parent = props and props.Parent
	return o
end
local new = UI.new

function UI.corner(r)
	if r == "round" then
		return new("UICorner", { CornerRadius = UDim.new(0.5, 0) })
	end
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

function UI.stroke(color, th, contextual)
	return new("UIStroke", {
		Color = color or UI.C.woodDark,
		Thickness = th or 2,
		ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- 위가 밝고 아래가 살짝 어두운 그라데이션 (사탕·나무 볼륨감)
function UI.gloss(amount)
	amount = amount or 0.25
	return new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - amount, 1 - amount, 1 - amount)),
	})
end

function UI.darker(c, k)
	k = k or 0.7
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- 글자. Outline = 색이면 글자 외곽선 (나무·버튼 위 흰 글자용)
function UI.text(props)
	local outline = props.Outline
	props.Outline = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or UI.F.heavy
	props.TextColor3 = props.TextColor3 or UI.C.ink
	props.TextSize = props.TextSize or 18
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	local t = new("TextLabel", props)
	if outline then
		UI.stroke(outline, props.TextSize >= 24 and 2.5 or 1.8, true).Parent = t
	end
	return t
end

---------------------------------------------------------------- 화면 + 크기 맞춤
-- 노치·Roblox 메뉴 버튼을 피하는 ScreenGui
function UI.screen(name, order, parent)
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 5,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = parent,
	})
end

-- 배율 두 가지 (2026-11-24 사용자 "ui 줄이기"·실제 폰 사진: HUD가 너무 큼)
--   HUD 조각(레벨판·코인·메뉴 버튼 등, fit(obj)): 기준 1350x560 → 폰 가로(약 750x300) ≈ 0.54, PC는 1.0까지
--   창(fit(obj, w, h)): 기준 800x360 → 폰 ≈ 0.84 (글씨가 읽혀야 해서 HUD보다 크게), PC는 1.15까지 + 화면 안에 다 들어오게
function UI.scaleFor(size)
	return math.clamp(math.min(size.X / 1350, size.Y / 560), 0.5, 1.0)
end
function UI.windowScaleFor(size)
	return math.clamp(math.min(size.X / 800, size.Y / 360), 0.7, 1.15)
end

-- 비율 창 (fit(obj, w, h, true)): 화면 가로 92% × 세로 88%, 아주 큰 모니터에서는 화면 픽셀 1700 × 940까지
UI.WindowFill = Vector2.new(0.92, 0.88)
UI.WindowMax = Vector2.new(1700, 940)

-- UIGridLayout 칸을 줄 너비에 꽉 차게 (남는 오른쪽 빈칸 없이). minW = 칸 최소 너비(설계 px), ratio = 높이 / 너비,
-- extraH = 칸 높이에 더할 고정 px. 창 배율(UIScale)은 grid.AbsoluteSize에서 거꾸로 계산.
function UI.fillGrid(gridLayout, minW, ratio, extraH)
	local frame = gridLayout.Parent
	local pad = gridLayout.CellPadding.X.Offset
	local function update()
		local abs = frame.AbsoluteSize.X
		if abs < 10 then
			return
		end
		-- 설계 단위 너비: AbsoluteSize ÷ 배율 (배율 = 조상 UIScale들의 곱)
		local k = 1
		local p = frame
		while p do
			local sc = p:FindFirstChildOfClass("UIScale")
			if sc then
				k *= sc.Scale
			end
			p = p.Parent
			if p and p:IsA("LayerCollector") then
				break
			end
		end
		local padR = 0
		local up = frame:FindFirstChildOfClass("UIPadding")
		if up then
			padR = up.PaddingLeft.Offset + up.PaddingRight.Offset
		end
		local bar = frame:IsA("ScrollingFrame") and frame.ScrollBarThickness or 0
		local width = abs / k - padR - bar - 2
		local cols = math.max(1, math.floor((width + pad) / (minW + pad)))
		local cell = (width - pad * (cols - 1)) / cols
		gridLayout.CellSize = UDim2.fromOffset(math.floor(cell), math.floor(cell * ratio + (extraH or 0)))
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	task.defer(update)
	return update
end

-- 화면 전체를 덮는 투명 Root (fitter가 이 크기로 배율을 잰다. 폰 미리보기 때 Root만 줄이면 됨)
function UI.root(gui)
	return new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
end

-- fit(obj, w, h): obj에 UIScale을 달고 화면이 바뀌면 같이 맞춘다.
--   w, h(설계 크기)를 주면 화면 안에 다 들어오게 더 줄인다 (창).
--   fit(obj, w, h, true): 창 크기를 화면 비율로 (2026-11-24 사용자 "남는 공간 없게 정해진 고정 사이즈 말고
--   화면에 따른 비율 사이즈로"). 화면의 UI.WindowFill만큼 차지하고, w × h는 가장 작은 크기(내용이 들어가는 최소).
--   창 안 내용은 상대 크기(UDim2 scale)나 UI.fillGrid로 넓어진 만큼 채운다.
-- 반환: fit, get(지금 배율), onChange(fn(scale, size))
function UI.fitter(area)
	local items = {}
	local listeners = {}
	local current = 1
	local function update()
		local s = area.AbsoluteSize
		if s.X < 10 then
			return
		end
		current = UI.scaleFor(s)
		local winK = UI.windowScaleFor(s)
		for _, it in ipairs(items) do
			local k = current
			if it.w then
				k = math.min(winK, (s.X - 16) / it.w, (s.Y - 12) / it.h)
				if it.fill then
					local f = UI.WindowFill
					local W = math.max(it.w, math.min(s.X * f.X, UI.WindowMax.X) / k)
					local H = math.max(it.h, math.min(s.Y * f.Y, UI.WindowMax.Y) / k)
					it.obj.Size = UDim2.fromOffset(math.floor(W), math.floor(H))
				end
			end
			it.scale.Scale = k
		end
		for _, fn in ipairs(listeners) do
			fn(current, s)
		end
	end
	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	task.defer(update)
	local function fit(obj, w, h, fill)
		local sc = new("UIScale", { Scale = current, Parent = obj })
		table.insert(items, { scale = sc, w = w, h = h, obj = obj, fill = fill == true and w ~= nil })
		task.defer(update)
		return sc
	end
	return fit, function()
		return current
	end, function(fn)
		table.insert(listeners, fn)
		task.defer(update)
	end
end

---------------------------------------------------------------- 버튼
-- 두툼한 사탕 버튼: 진한 바닥(그림자) 위에 밝은 면이 올라가 있고, 누르면 면이 내려간다.
-- props: Name, Text, Color, Size, Position, AnchorPoint, LayoutOrder, ZIndex, TextSize, Round(동그라미), Icon(앞 글자), Parent
local DEPTH = 5
function UI.button(props)
	local color = props.Color or UI.C.yellow
	local z = props.ZIndex or 1
	local r = props.Round and "round" or (props.Radius or 14)
	local btn = new("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = UI.darker(color, 0.62),
		Size = props.Size or UDim2.fromOffset(140, 52),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = z,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	}, { UI.corner(r), UI.stroke(UI.C.woodDark, 2.5) })
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -DEPTH),
		BackgroundColor3 = color,
		ZIndex = z + 1,
		Parent = btn,
	}, { UI.corner(r), UI.gloss(0.18) })
	-- 위쪽 반짝이
	new("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.new(1, -14, 0.32, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		ZIndex = z + 1,
		Parent = face,
	}, { UI.corner(r) })
	UI.text({
		Name = "Label",
		Text = (props.Icon and (props.Icon .. " ") or "") .. (props.Text or ""),
		TextSize = props.TextSize or 20,
		TextColor3 = UI.C.white,
		Outline = UI.darker(color, 0.45),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = face,
	})
	btn:SetAttribute("Color", color)
	btn:SetAttribute("Enabled", true)
	local function down(on)
		face.Position = on and UDim2.fromOffset(0, DEPTH - 1) or UDim2.new()
	end
	btn.MouseButton1Down:Connect(function()
		if btn:GetAttribute("Enabled") then
			down(true)
		end
	end)
	btn.MouseButton1Up:Connect(function()
		down(false)
	end)
	btn.MouseLeave:Connect(function()
		down(false)
	end)
	return btn
end

-- 버튼 글자·색·켜짐 바꾸기 (꺼지면 회색, 누르는 느낌 없음)
function UI.setButton(btn, opts)
	local face = btn:FindFirstChild("Face")
	if not face then
		return
	end
	local label = face:FindFirstChild("Label")
	if opts.Text ~= nil and label then
		label.Text = opts.Text
	end
	if opts.Color then
		btn:SetAttribute("Color", opts.Color)
	end
	if opts.Enabled ~= nil then
		btn:SetAttribute("Enabled", opts.Enabled)
	end
	local color = btn:GetAttribute("Enabled") and btn:GetAttribute("Color") or UI.C.grey
	face.BackgroundColor3 = color
	btn.BackgroundColor3 = UI.darker(color, 0.62)
	if label then
		local s = label:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = UI.darker(color, 0.45)
		end
	end
end

-- 빨간 동그라미 ✕ 닫기 버튼 (오른쪽 위 모서리에 걸쳐 놓기)
function UI.closeButton(parent, onClick, z)
	local b = UI.button({
		Name = "Close",
		Text = "X",
		Color = UI.C.red,
		Round = true,
		TextSize = 26,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(52, 54),
		ZIndex = z or 20,
		Parent = parent,
	})
	b.Face.Label.FontFace = UI.F.round
	new("UIStroke", { Color = UI.C.white, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b.Face })
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- 빨간 ! 알림 배지
function UI.badge(parent, z)
	local b = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.C.red,
		ZIndex = (z or 1) + 5,
		Visible = false,
		Parent = parent,
	}, { UI.corner("round"), UI.stroke(UI.C.white, 2) })
	UI.text({ Text = "!", FontFace = UI.F.round, TextSize = 16, TextColor3 = UI.C.white, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = (z or 1) + 6, Parent = b })
	return b
end

---------------------------------------------------------------- 판·카드
-- 크림색 카드
function UI.card(props)
	local r = props.Radius or 14
	props.Radius = nil
	props.BackgroundColor3 = props.BackgroundColor3 or UI.C.cream
	local c = new("Frame", props, { UI.corner(r), UI.stroke(UI.C.line, 2) })
	return c
end

-- 나무 판 창: outer(나무 테두리) 안에 body(어두운 안쪽). 위 가운데 리본 제목판, 오른쪽 위 ✕.
-- 반환: outer, body, close
function UI.window(props)
	local z = props.ZIndex or 10
	local outer = new("Frame", {
		Name = props.Name or "Window",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.53),
		Size = props.Size or UDim2.fromOffset(640, 400),
		BackgroundColor3 = UI.C.wood,
		Visible = props.Visible == true,
		ZIndex = z,
		Parent = props.Parent,
	}, { UI.corner(22), UI.stroke(UI.C.woodDark, 4), UI.gloss(0.2) })
	-- 나무 결 (옅은 가로줄)
	for i = 1, 3 do
		new("Frame", {
			Name = "Grain",
			Position = UDim2.new(0, 18, i / 4, 0),
			Size = UDim2.new(1, -36, 0, 2),
			BackgroundColor3 = UI.C.woodDark,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = outer,
		})
	end
	local pad = props.Pad or 14
	local top = props.Title and 34 or pad
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(pad, top),
		Size = UDim2.new(1, -pad * 2, 1, -top - pad),
		BackgroundColor3 = UI.C.woodInner,
		ZIndex = z + 1,
		Parent = outer,
	}, { UI.corner(16), UI.stroke(UI.C.woodDark, 2) })
	if props.Title then
		local plank = new("Frame", {
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(0, 54),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = UI.C.woodLight,
			ZIndex = z + 3,
			Parent = outer,
		}, {
			UI.corner(12),
			UI.stroke(UI.C.woodDark, 3),
			UI.gloss(0.22),
			new("UIPadding", { PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 34) }),
		})
		UI.text({
			Name = "Text",
			Text = props.Title,
			TextSize = 30,
			TextColor3 = UI.C.cream,
			Outline = UI.C.woodDark,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = z + 4,
			Parent = plank,
		})
		-- 양 끝 못
		for _, x in ipairs({ 0, 1 }) do
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(x, x == 0 and -18 or 18, 0.5, 0),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = UI.C.woodDark,
				ZIndex = z + 4,
				Parent = plank,
			}, { UI.corner("round") })
		end
	end
	local close = UI.closeButton(outer, props.OnClose, z + 5)
	return outer, body, close
end

-- 어두운 반투명 자원 알약 (아이콘 동그라미 + 숫자). 반환: pill, valueLabel, iconHolder
function UI.pill(props)
	local z = props.ZIndex or 1
	local pill = new("Frame", {
		Name = props.Name or "Pill",
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Size = props.Size or UDim2.fromOffset(170, 40),
		BackgroundColor3 = UI.C.pill,
		BackgroundTransparency = 0.08,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = z,
		Parent = props.Parent,
	}, { UI.corner("round"), UI.stroke(UI.C.woodLight, 2) })
	local icon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = props.IconColor or UI.C.cream,
		ZIndex = z + 1,
		Parent = pill,
	}, { UI.corner("round"), UI.stroke(UI.C.woodDark, 2.5), UI.gloss(0.2) })
	if props.Icon then
		UI.text({ Text = props.Icon, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = icon })
	end
	local value = UI.text({
		Name = "Value",
		Text = props.Text or "0",
		FontFace = UI.F.round,
		TextSize = props.TextSize or 22,
		TextColor3 = UI.C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -36, 1, 0),
		ZIndex = z + 1,
		Parent = pill,
	})
	return pill, value, icon
end

-- 금화 아이콘 (🪙 이모지는 Roblox 글꼴에 없어 네모로 나와서 직접 그림)
function UI.coin(parent, size, z)
	local c = new("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UI.C.gold,
		ZIndex = z or 1,
		Parent = parent,
	}, { UI.corner("round"), UI.stroke(Color3.fromRGB(176, 112, 20), math.max(1.5, size / 14)), UI.gloss(0.25) })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		ZIndex = (z or 1) + 1,
		Parent = c,
	}, { UI.corner("round"), UI.stroke(Color3.fromRGB(214, 150, 30), math.max(1, size / 18)) })
	return c
end

-- 진행 막대 (초록 채움, 어두운 홈). 반환: back, fill, label
function UI.bar(props)
	local z = props.ZIndex or 1
	local back = new("Frame", {
		Name = props.Name or "Bar",
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Size = props.Size or UDim2.fromOffset(200, 16),
		BackgroundColor3 = UI.C.woodDark,
		BackgroundTransparency = 0.15,
		ZIndex = z,
		Parent = props.Parent,
	}, { UI.corner("round") })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or UI.C.green,
		ZIndex = z + 1,
		Parent = back,
	}, { UI.corner("round"), UI.gloss(0.25) })
	local label = UI.text({
		Name = "Text",
		Text = "",
		FontFace = UI.F.round,
		TextSize = props.TextSize or 12,
		TextColor3 = UI.C.white,
		Outline = UI.C.woodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = back,
	})
	return back, fill, label
end

---------------------------------------------------------------- 소리
-- 물건을 샀을 때 코인 소리 (2026-11-24 사용자 요청). Roblox 라이선스 효과음만:
-- ProSoundEffects "Coin Throws 1 (SFX)" (동전 여러 개, 2.3초) → 앞 0.8초만 짧게 "짤랑"
local COIN_SOUND = "rbxassetid://9113849579"
local lastCoin = 0
function UI.coinSound()
	local now = os.clock()
	if now - lastCoin < 0.12 then
		return -- 연달아 누르면 한 번만
	end
	lastCoin = now
	local s = Instance.new("Sound")
	s.SoundId = COIN_SOUND
	s.Volume = 0.7
	s.PlaybackSpeed = 1.15
	s.Parent = game:GetService("SoundService")
	s:Play()
	task.delay(0.6, function()
		game:GetService("TweenService"):Create(s, TweenInfo.new(0.25), { Volume = 0 }):Play()
	end)
	task.delay(0.9, function()
		s:Destroy()
	end)
end

return UI
