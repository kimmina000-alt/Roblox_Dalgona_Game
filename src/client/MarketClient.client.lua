-- 골목 슈퍼 (D54, 2026-11-25): 재료는 슈퍼에 걸어가서 사 온다.
--   [슈퍼 가기] (Hud) → 바닥에 길 안내 점 (내 화면에서만, PathfindingService). 슈퍼 입구에 닿거나 다시 누르면 꺼짐.
--   슈퍼 계산대의 ProximityPrompt(속성 Market = true) → Hud 상점 창을 "market"으로 엶 (지금 상점 창 그대로, 10/50/100).
--   계산대에서 멀어지면 장보기 창을 닫음.
-- 자리 (제작 세션 feat/alley-market-1125, AlleyBuilder): Workspace.Alley.AlleyMarket 안
--   MarketDoor = 문 가운데 (길 안내 목표), MarketSpot = 바닥 앞 가운데 (문이 없으면 이것), MarketCounter = 계산대.
--   계산대에 [장보기] 프롬프트가 없으면 이 화면이 내 화면에만 붙임.
-- 다른 스크립트에서: MarketClient.Guide:Fire(true 켜기 / false 끄기 / nil 바꾸기)

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")

local GUIDE_COLOR = Color3.fromRGB(255, 206, 60)
local DOT_GAP = 3 -- 점 사이 (스터드)
local ARRIVE = 10 -- 입구에서 이만큼 가까우면 끝
local COUNTER_LEAVE = 16 -- 계산대에서 이만큼 멀어지면 장보기 창 닫음

local function hud()
	return script.Parent:FindFirstChild("Hud")
end
local function toast(text)
	local h = hud()
	local ev = h and h:FindFirstChild("Toast")
	if ev then
		ev:Fire(text)
	end
end

local function market()
	local alley = workspace:FindFirstChild("Alley")
	return alley and alley:FindFirstChild("AlleyMarket")
end
local function findTarget()
	local m = market()
	local p = m and (m:FindFirstChild("MarketDoor", true) or m:FindFirstChild("MarketSpot", true))
	return p and p:IsA("BasePart") and p or nil
end

---------------------------------------------------------------- 길 안내 점
local folder = Instance.new("Folder")
folder.Name = "MarketGuide"
local dots = {}
local function clearDots()
	for _, d in ipairs(dots) do
		d:Destroy()
	end
	table.clear(dots)
end
local function dot(pos, big)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GUIDE_COLOR
	p.Size = big and Vector3.new(0.2, 3, 3) or Vector3.new(0.15, 1.1, 1.1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = folder
	table.insert(dots, p)
	return p
end

local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
local guiding = false
local target = nil
local lastCalc = 0

local function draw(root)
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target.Position)
	end)
	clearDots()
	local points = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, w in ipairs(path:GetWaypoints()) do
			table.insert(points, w.Position)
		end
	else
		-- 길을 못 찾으면 곧장 (바닥 높이는 출발점 기준)
		points = { root.Position - Vector3.new(0, 3, 0), target.Position }
	end
	-- 점을 DOT_GAP마다 (캐릭터 바로 앞 2스터드는 건너뜀)
	local carry = 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local t = carry
		while t < len do
			dot(a + (b - a).Unit * t, false)
			t += DOT_GAP
		end
		carry = t - len
	end
	dot(target.Position - Vector3.new(0, target.Size.Y / 2, 0), true)
	folder.Parent = workspace
end

local function setGuide(on)
	if on == nil then
		on = not guiding
	end
	if on then
		target = findTarget()
		if not target then
			toast("슈퍼 길을 아직 찾을 수 없어요")
			on = false
		end
	end
	guiding = on
	lastCalc = 0
	if not on then
		clearDots()
	else
		toast("🏪 노란 점을 따라 슈퍼에 가요")
	end
end

local guideEv = Instance.new("BindableEvent")
guideEv.Name = "Guide"
guideEv.Parent = script
guideEv.Event:Connect(setGuide)

local t0 = 0
RunService.Heartbeat:Connect(function(dt)
	if not guiding then
		return
	end
	local char = me.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not target or not target.Parent then
		return
	end
	-- 도착
	local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
	if flat.Magnitude < ARRIVE then
		setGuide(false)
		toast("골목 슈퍼에 왔어요! 계산대에서 장을 봐요")
		return
	end
	-- 1.5초마다 다시 계산 (걸어가면서 갱신)
	if os.clock() - lastCalc > 1.5 then
		lastCalc = os.clock()
		task.spawn(draw, root)
	end
	-- 점이 살짝 숨 쉬듯
	t0 += dt
	local tr = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(t0 * 5))
	for _, d in ipairs(dots) do
		d.Transparency = tr
	end
end)

---------------------------------------------------------------- 계산대 [장보기]
local counter = nil -- 지금 연 계산대 (멀어지면 창 닫기)
-- 계산대 = 속성 MarketCounter = true인 부품 (서버 MarketService·3D 세션), 없으면 AlleyMarket.MarketCounter
local function findCounter()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("MarketCounter") == true then
			return d
		end
	end
	local m = market()
	local c = m and m:FindFirstChild("MarketCounter", true)
	return c and c:IsA("BasePart") and c or nil
end
local function isMarketPrompt(prompt)
	if prompt:GetAttribute("Market") == true then
		return true
	end
	local p = prompt.Parent
	return p ~= nil and (p:GetAttribute("MarketCounter") == true or p.Name == "MarketCounter")
end
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= me or not isMarketPrompt(prompt) then
		return
	end
	local h = hud()
	local ev = h and h:FindFirstChild("OpenMarket")
	if ev then
		setGuide(false)
		counter = prompt.Parent
		ev:Fire("market")
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		if counter then
			local gui = playerGui:FindFirstChild("ShopHud")
			local shop = gui and gui:FindFirstChild("Shop")
			local char = me.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local pos = counter:IsA("BasePart") and counter.Position or (counter:IsA("Attachment") and counter.WorldPosition) or (counter:IsA("Model") and counter:GetPivot().Position)
			if not shop or not shop.Visible then
				counter = nil
			elseif root and pos and (root.Position - pos).Magnitude > COUNTER_LEAVE then
				shop.Visible = false
				counter = nil
			end
		end
	end
end)

-- 계산대에 [장보기] 프롬프트가 없으면 내 화면에만 붙임 (스트리밍으로 늦게 들어와도)
task.spawn(function()
	while true do
		local counter = findCounter()
		if counter and not counter:FindFirstChildWhichIsA("ProximityPrompt") then
			local pp = Instance.new("ProximityPrompt")
			pp.Name = "ShopPrompt"
			pp.ActionText = "장보기"
			pp.ObjectText = "골목 슈퍼"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 12 -- 서버 장보기 범위(G.Market.radius 14) 안
			pp.RequiresLineOfSight = false
			pp:SetAttribute("Market", true)
			pp.Parent = counter
		end
		task.wait(3)
	end
end)

---------------------------------------------------------------- 봉지·배달 알림 (가운데 위 작은 알약)
-- 플레이어 속성 (서버 MarketService): BagCount(봉지 안 개수 합), BagSize("s"/"m"/"l"), DeliveryAt(배달 도착 서버 시각)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local infoGui = UI.screen("MarketInfo", 4, playerGui)
local infoRoot = UI.root(infoGui)
local infoFit = UI.fitter(infoRoot)
local pill = UI.card({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = UI.C.cream, Visible = false, Parent = infoRoot })
UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = pill })
infoFit(pill, 400, 40)
local pillText = UI.text({ Text = "", TextSize = 18, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
local BAG_KO = { s = "작은", m = "중간", l = "큰" }
task.spawn(function()
	while true do
		local parts = {}
		local n = me:GetAttribute("BagCount")
		if type(n) == "number" and n > 0 then
			table.insert(parts, string.format("🛍 %s 봉지 %d개 · 가게에 가져가요", BAG_KO[me:GetAttribute("BagSize")] or "", n))
		end
		local at = me:GetAttribute("DeliveryAt")
		if type(at) == "number" then
			local left = at - workspace:GetServerTimeNow()
			if left > 0 then
				table.insert(parts, string.format("🛵 배달 %d:%02d", math.floor(left / 60), math.floor(left % 60)))
			end
		end
		local making = playerGui:FindFirstChild("MakingScreen")
		pill.Visible = #parts > 0 and not (making and making.Enabled)
		pillText.Text = table.concat(parts, "   ")
		task.wait(0.5)
	end
end)
