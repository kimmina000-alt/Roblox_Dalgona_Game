-- 자리 비운 동안 만든 것 요약 팝업 (D29, 2026-11-22). 서버 OfflineService가 Remotes.OfflineReport로 보냄

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CREAM = Color3.fromRGB(255, 247, 232)
local BROWN = Color3.fromRGB(92, 58, 36)
local SOFT = Color3.fromRGB(150, 110, 80)
local GREEN = Color3.fromRGB(110, 190, 90)
local RED = Color3.fromRGB(200, 70, 60)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = touch and 0.85 or 1

local function timeText(sec)
	sec = math.floor(sec or 0)
	local h = sec // 3600
	local m = (sec % 3600) // 60
	if h > 0 then
		return string.format("%d시간 %d분", h, m)
	end
	return string.format("%d분", math.max(m, 1))
end

local function show(r)
	local old = playerGui:FindFirstChild("OfflineReport")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OfflineReport"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = playerGui

	local lines = {}
	local away = timeText(r.away)
	if r.away > r.seconds then
		away = away .. string.format(" (최대 %d시간까지 셈)", r.maxHours)
	end
	table.insert(lines, "자리 비운 시간: " .. away)
	local parts = {}
	if r.made.helper > 0 then
		table.insert(parts, "알바생 " .. r.made.helper)
	end
	if r.made.machine > 0 then
		table.insert(parts, "기계 " .. r.made.machine)
	end
	if r.made.factory > 0 then
		table.insert(parts, "공장 " .. r.made.factory)
	end
	if #parts > 0 then
		table.insert(lines, "만든 것: " .. table.concat(parts, " · "))
	end
	local used = {}
	for _, ing in ipairs(G.Ingredients) do
		local n = r.used[ing.id]
		if n and n > 0 then
			table.insert(used, ing.name .. " " .. n)
		end
	end
	if #used > 0 then
		table.insert(lines, "쓴 재료: " .. table.concat(used, ", "))
	end
	local costs = {}
	if r.wages > 0 then
		table.insert(costs, "알바 급여 " .. r.wages)
	end
	if r.factoryCoins > 0 then
		table.insert(costs, "공장 운영비 " .. r.factoryCoins)
	end
	if #costs > 0 then
		table.insert(lines, "나간 코인: " .. table.concat(costs, ", "))
	end
	if r.exp > 0 then
		table.insert(lines, "EXP +" .. r.exp)
	end
	local stops = {}
	local full = false
	for who, why in pairs(r.stops) do
		table.insert(stops, who .. " - " .. why)
		if why == "보관함 가득" then
			full = true
		end
	end
	table.sort(stops)
	-- 판매가 없어서 대개 보관함이 먼저 참 (D29): 눈에 띄게 따로 알림
	local fullText = nil
	if full and r.total <= 0 then -- 하나도 못 만들었을 때만 "이미 가득"
		fullText = "📦 보관함이 이미 가득 차 있어서 못 만들었어요!\n진열대에 놓고 팔아서 자리를 비워 주세요"
	elseif full then
		fullText = string.format("📦 %s 만에 보관함이 가득 차서 멈췄어요!\n진열대에 놓고 팔아서 자리를 비워 주세요", timeText(r.worked or r.seconds))
	end

	local height = (110 + #lines * 24 + (fullText and 60 or 0) + (#stops > 0 and (26 + #stops * 22) or 0) + 56) * S
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(360 * S, height)
	frame.BackgroundColor3 = CREAM
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(222, 150, 70)
	stroke.Thickness = 3
	stroke.Parent = frame

	local function text(t, y, size, color, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(18 * S, y)
		l.Size = UDim2.new(1, -36 * S, 0, size + 6)
		l.Font = font or Enum.Font.GothamBold
		l.TextSize = size
		l.TextColor3 = color or BROWN
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.Text = t
		l.Parent = frame
	end
	text("🌙 자리 비운 동안", 16 * S, 22 * S, BROWN, Enum.Font.GothamBlack)
	text(r.total > 0 and string.format("달고나 %d개를 만들었어요!", r.total) or "아무것도 만들지 못했어요", 50 * S, 18 * S, r.total > 0 and GREEN or RED, Enum.Font.GothamBlack)
	local y = 90 * S
	for _, l in ipairs(lines) do
		text(l, y, 15 * S, SOFT)
		y += 24 * S
	end
	if fullText then
		y += 6 * S
		local box = Instance.new("Frame")
		box.Position = UDim2.fromOffset(12 * S, y - 4 * S)
		box.Size = UDim2.new(1, -24 * S, 0, 52 * S)
		box.BackgroundColor3 = Color3.fromRGB(255, 226, 200)
		box.Parent = frame
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = box
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(8 * S, 2 * S)
		l.Size = UDim2.new(1, -16 * S, 1, -4 * S)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = 14 * S
		l.TextColor3 = RED
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = fullText
		l.Parent = box
		y += 60 * S
	end
	if #stops > 0 then
		y += 4 * S
		text("멈춘 이유", y, 15 * S, RED, Enum.Font.GothamBlack)
		y += 24 * S
		for _, l in ipairs(stops) do
			text("· " .. l, y, 14 * S, SOFT, Enum.Font.Gotham)
			y += 22 * S
		end
	end
	local ok = Instance.new("TextButton")
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -14 * S)
	ok.Size = UDim2.fromOffset(140 * S, 38 * S)
	ok.BackgroundColor3 = GREEN
	ok.Font = Enum.Font.GothamBlack
	ok.TextSize = 16 * S
	ok.TextColor3 = Color3.new(1, 1, 1)
	ok.Text = "좋아요"
	ok.Parent = frame
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0, 10)
	oc.Parent = ok
	ok.Activated:Connect(function()
		gui:Destroy()
	end)
end

Remotes:WaitForChild("OfflineReport").OnClientEvent:Connect(function(r)
	if type(r) == "table" and type(r.made) == "table" then
		show(r)
	end
end)
