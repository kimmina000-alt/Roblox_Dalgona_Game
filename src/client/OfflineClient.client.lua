-- 자리 비운 동안 만든 것 요약 팝업 (D29, 2026-11-22). 서버 OfflineService가 Remotes.OfflineReport로 보냄

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
-- 2026-11-23 새 스타일(shared/UiStyle): 폰 가로 화면에 맞춘 넓고 낮은 나무 판 창, 왼쪽 결과 · 오른쪽 경고·멈춘 이유
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local C = UI.C

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
	local gui = UI.screen("OfflineReport", 20, playerGui)
	local root = UI.root(gui)
	local fit = UI.fitter(root)

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

	local win, body = UI.window({ Name = "Window", Title = "🌙 자리 비운 동안", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(760, 330), ZIndex = 10, Visible = true, Parent = root, OnClose = function()
		gui:Destroy()
	end })
	fit(win, 760, 355)

	-- 왼쪽: 결과 카드 (크게 몇 개 만들었는지 + 줄마다 요약)
	local left = UI.card({ Position = UDim2.fromOffset(10, 10), Size = UDim2.new(0.5, -15, 1, -20), ZIndex = 12, Parent = body })
	UI.text({
		Text = r.total > 0 and string.format("달고나 %d개를 만들었어요!", r.total) or "아무것도 만들지 못했어요",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 30),
		TextSize = 24,
		TextColor3 = r.total > 0 and C.good or C.bad,
		TextWrapped = true,
		ZIndex = 13,
		Parent = left,
	})
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 46)
	list.Size = UDim2.new(1, -20, 1, -54)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = C.line
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 13
	list.Parent = left
	UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, l in ipairs(lines) do
		UI.text({ LayoutOrder = i, Text = l, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 17, FontFace = UI.F.bold, TextColor3 = C.ink, TextWrapped = true, ZIndex = 14, Parent = list })
	end

	-- 오른쪽: 보관함 가득 경고 + 멈춘 이유 + 좋아요 버튼
	local right = UI.new("Frame", { Position = UDim2.new(0.5, 5, 0, 10), Size = UDim2.new(0.5, -15, 1, -20), BackgroundTransparency = 1, ZIndex = 12, Parent = body })
	local y = 0
	if fullText then
		local box = UI.card({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(255, 226, 200), ZIndex = 13, Parent = right })
		box:FindFirstChildOfClass("UIStroke").Color = C.bad
		UI.text({ Text = fullText, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), TextSize = 16, TextColor3 = C.bad, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 14, Parent = box })
		y = 82
	end
	if #stops > 0 then
		local sc = UI.card({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 1, -y - 66), ZIndex = 13, Parent = right })
		UI.text({ Text = "멈춘 이유", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), TextSize = 18, TextColor3 = C.bad, ZIndex = 14, Parent = sc })
		local sl = Instance.new("ScrollingFrame")
		sl.Position = UDim2.fromOffset(10, 30)
		sl.Size = UDim2.new(1, -20, 1, -36)
		sl.BackgroundTransparency = 1
		sl.BorderSizePixel = 0
		sl.ScrollBarThickness = 5
		sl.ScrollBarImageColor3 = C.line
		sl.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sl.CanvasSize = UDim2.new()
		sl.ZIndex = 14
		sl.Parent = sc
		UI.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sl })
		for i, l in ipairs(stops) do
			UI.text({ LayoutOrder = i, Text = "· " .. l, Size = UDim2.new(1, -8, 0, 22), TextSize = 16, FontFace = UI.F.bold, TextColor3 = C.soft, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15, Parent = sl })
		end
	end
	local ok = UI.button({ Name = "Ok", Text = "좋아요", Color = C.green, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 56), TextSize = 24, ZIndex = 13, Parent = right })
	ok.Activated:Connect(function()
		gui:Destroy()
	end)
end

Remotes:WaitForChild("OfflineReport").OnClientEvent:Connect(function(r)
	if type(r) == "table" and type(r.made) == "table" then
		show(r)
	end
end)
