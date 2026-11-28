-- 가게 뒷벽 메뉴판에 "달고나빵" 줄 (2026-11-27 사용자 "달고나빵 메뉴에 추가하고 가격 책정").
-- 메뉴판 그림(SurfaceGui MenuArt의 ImageLabel, 기본 달고나 2,000 · 모양 달고나 2,500 · 세트 6,000 · 맨 아래 하트)은
-- 올린 그림이라 글씨를 못 바꿈 → 맨 아래 하트 자리를 판 색으로 덮고 같은 줄 간격으로 "달고나빵  1,500"을 얹음 (내 화면에서만, 모든 가게).
-- 값은 GrowthConfig.BreadMenuWon (게임 안 판매가는 G.BreadBasePrice 코인).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local BOARD = Color3.fromRGB(92, 57, 40) -- 메뉴판 그림 바탕 (어두운 갈색, 그림은 빛을 받아 어두워져서 조금 밝게 맞춤)
local CHALK = Color3.fromRGB(238, 216, 186) -- 그림 글씨 색 (크림)
local ROW_Y = 0.898 -- 그림 안 줄 높이 (기본 0.34 · 모양 0.527 · 세트 0.712 → 다음 줄)
local ROW_H = 0.11

local function comma(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function decorate(img)
	if not (img:IsA("ImageLabel") and img.Parent and img.Parent:IsA("SurfaceGui") and img.Parent.Name == "MenuArt") then
		return
	end
	if img:FindFirstChild("BreadRow") then
		return
	end
	-- 하트 덮기
	local patch = Instance.new("Frame")
	patch.Name = "BreadPatch"
	patch.BackgroundColor3 = BOARD
	patch.BorderSizePixel = 0
	patch.Position = UDim2.fromScale(0.03, 0.825)
	patch.Size = UDim2.fromScale(0.94, 0.165)
	patch.ZIndex = 2
	patch.Parent = img
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = patch
	local fade = Instance.new("UIGradient") -- 양옆 끝을 흐리게 (그림 바탕 결과 이어지게)
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.06, 0), NumberSequenceKeypoint.new(0.94, 0), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = patch
	local row = Instance.new("Frame")
	row.Name = "BreadRow"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0, 0.5)
	row.Position = UDim2.fromScale(0.05, ROW_Y)
	row.Size = UDim2.fromScale(0.915, ROW_H)
	row.ZIndex = 3
	row.Parent = img
	local function label(text, x, align)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.6, 1)
		t.Position = UDim2.fromScale(x, 0)
		t.AnchorPoint = Vector2.new(x, 0)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = CHALK
		t.TextXAlignment = align
		t.Text = text
		t.ZIndex = 3
		t.Parent = row
		return t
	end
	label("달고나빵", 0, Enum.TextXAlignment.Left)
	label(comma(G.BreadMenuWon or 1500), 1, Enum.TextXAlignment.Right)
end

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ImageLabel") then
		decorate(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ImageLabel") then
		task.defer(decorate, d)
	end
end)
