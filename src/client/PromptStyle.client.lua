-- 상호작용 버튼(ProximityPrompt) 모양 (2026-11-25 사용자 "기계 근처 갔을 때 뜨는 버튼 ui 게임 ui에 맞춰서 디자인 작업 크기 조금 줄이기")
-- 기본 Roblox 모양 대신 UiStyle: 크림 판 + 나무 테두리, 왼쪽 노란 사탕 동그라미에 키(E / 탭 손가락 / 패드 버튼), 오른쪽 행동·물건 이름.
-- 기본 모양보다 조금 작게 (높이 72 → 54). 길게 누르는 프롬프트는 동그라미 아래 초록 막대가 참.
-- 내 화면에서만 Style = Custom으로 바꿔 그림 (서버 값은 그대로). 원래 Custom인 프롬프트(다른 스크립트가 직접 그림)는 건드리지 않음.
-- E 키(KeyboardKeyCode)·패드는 ProximityPromptService가 그대로 처리, 탭·클릭은 판을 누르면 InputHoldBegin/End.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local C = UI.C
local new = UI.new

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local folder = new("Folder", { Name = "PromptGuis", Parent = playerGui })

local H = 54 -- 판 높이 (기본 72보다 작게, 폰에서 누르기엔 충분)
local KEY = 42 -- 키 동그라미

local mine = setmetatable({}, { __mode = "k" }) -- 이 스크립트가 Custom으로 바꾼 프롬프트

local function adopt(p)
	if p:IsA("ProximityPrompt") and p.Style == Enum.ProximityPromptStyle.Default then
		mine[p] = true
		p.Style = Enum.ProximityPromptStyle.Custom
	end
end
for _, d in ipairs(workspace:GetDescendants()) do
	adopt(d)
end
workspace.DescendantAdded:Connect(adopt)

local GAMEPAD = {
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
}

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "👆"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD[prompt.GamepadKeyCode] or "●"
	end
	local k = prompt.KeyboardKeyCode
	local s = UserInputService:GetStringForKeyCode(k)
	if s == nil or s == "" then
		s = k.Name
	end
	return string.upper(s)
end

local function textWidth(text, size)
	-- 대략 (한글 1자 ≈ 글자 크기, 영숫자 ≈ 0.55배)
	local w = 0
	for _, cp in utf8.codes(text) do
		w += (cp > 127) and size or size * 0.55
	end
	return w
end

local function build(prompt, inputType)
	local action = prompt.ActionText ~= "" and prompt.ActionText or "누르기"
	local object = prompt.ObjectText
	local textW = math.max(textWidth(action, 19), object ~= "" and textWidth(object, 13) or 0)
	local W = math.floor(KEY + 22 + textW + 18)
	local bb = new("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = true,
		Size = UDim2.fromOffset(W, H + 8),
		SizeOffset = Vector2.new(prompt.UIOffset.X / W, prompt.UIOffset.Y / (H + 8)),
		Parent = folder,
	})
	local plate = new("TextButton", {
		Name = "Plate",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C.cream,
		Parent = bb,
	}, { UI.corner(14), UI.stroke(C.woodDark, 3) })
	local scale = new("UIScale", { Scale = 0.6, Parent = plate })
	-- 키 동그라미 (노란 사탕)
	local key = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(KEY, KEY),
		BackgroundColor3 = C.yellow,
		Parent = plate,
	}, { UI.corner("round"), UI.stroke(C.woodDark, 2.5), UI.gloss(0.22) })
	UI.text({ Text = keyText(prompt, inputType), FontFace = UI.F.round, TextSize = 22, TextColor3 = C.white, Outline = UI.darker(C.yellow, 0.45), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = key })
	-- 길게 누르기 막대
	local barBack, barFill
	if prompt.HoldDuration > 0 then
		barBack = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.new(1, 4, 0, 7), BackgroundColor3 = C.woodDark, Parent = key }, { UI.corner("round") })
		barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, Parent = barBack }, { UI.corner("round") })
	end
	-- 글자
	local tx = KEY + 16
	if object ~= "" then
		UI.text({ Text = object, Position = UDim2.fromOffset(tx, 5), Size = UDim2.new(1, -tx - 8, 0, 16), TextSize = 13, FontFace = UI.F.bold, TextColor3 = C.soft, Parent = plate })
		UI.text({ Text = action, Position = UDim2.fromOffset(tx, 20), Size = UDim2.new(1, -tx - 8, 0, 26), TextSize = 19, TextColor3 = C.ink, Parent = plate })
	else
		UI.text({ Text = action, Position = UDim2.fromOffset(tx, 0), Size = UDim2.new(1, -tx - 8, 1, 0), TextSize = 19, TextColor3 = C.ink, Parent = plate })
	end
	-- 나타날 때 톡
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local conns = {}
	-- 탭·클릭 (E 키·패드는 서비스가 처리)
	table.insert(conns, plate.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
			scale.Scale = 0.94
		end
	end))
	table.insert(conns, plate.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
			scale.Scale = 1
		end
	end))
	local holdTween
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if barFill then
			barFill.Size = UDim2.fromScale(0, 1)
			holdTween = TweenService:Create(barFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			holdTween:Play()
		end
		key.BackgroundColor3 = UI.darker(C.yellow, 0.85)
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		if barFill then
			barFill.Size = UDim2.fromScale(0, 1)
		end
		key.BackgroundColor3 = C.yellow
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.9 }):Play()
		task.delay(0.08, function()
			if scale.Parent then
				TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end)
	end))
	return function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		bb:Destroy()
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if not mine[prompt] then
		return
	end
	local cleanup = build(prompt, inputType)
	local hiddenConn
	hiddenConn = prompt.PromptHidden:Connect(function()
		hiddenConn:Disconnect()
		cleanup()
	end)
end)
