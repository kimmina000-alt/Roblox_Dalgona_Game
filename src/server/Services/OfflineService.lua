-- 오프라인 생산 정산 (D29, 2026-11-22): 알바생·기계·공장은 자리 비운 동안에도 만든다. 손 제작은 안 됨
-- D42 (2026-11-24): 절반 속도 (G.Offline.speed)
-- 수치는 GrowthConfig.Offline (임시값)
--  - 저장할 때마다 lastSeen = 지금 (PlayerDataService, 정산이 끝난 뒤부터). 들어오면 지금 - lastSeen (최대 maxHours)을 한 번에 정산
--  - 각자 온라인과 같은 규칙으로 step초씩 시뮬레이션 (GrowthService·MachineService·FactoryService의 offline 함수).
--    재료·보관함·코인이 같은 데이터라 시간 순서대로 번갈아 진행하고, 모두 멈추면 그만 셈
--  - 판매 없음, 월세 없음. 나갈 때 가게 문이 닫혀 있었으면 알바생·기계·공장 모두 멈춘 채 (가게 문 규칙)
--  - 두 번 정산 방지: 정산과 lastSeen = 지금을 같은 데이터 변경 안에서 함. 세션 잠금으로 다른 서버가 같은 데이터를 동시에 못 가짐.
--    서버가 정산 뒤 저장 전에 꺼지면 정산 결과도 같이 사라지므로 다음 접속에 다시 정산해도 한 번만 받음
--  - 요약: Remotes.OfflineReport (RemoteEvent) → 클라이언트 OfflineClient가 팝업
--  - Studio 전용 시험 장치: ServerStorage.DevOffline:Invoke(userId, 초) → lastSeen을 그만큼 당기고 바로 정산

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local O = G.Offline

local OfflineService = {}

local Data, Economy, hooks = nil, nil, nil
local reportEvent = nil

local function simulate(dd, seconds)
	local rep = { seconds = seconds, made = { helper = 0, machine = 0, factory = 0 }, used = {}, wages = 0, factoryCoins = 0, exp = 0, stops = {}, ups = {} }
	local helperState = {}
	for i = 1, #dd.partTimers do
		helperState[i] = { t = 0 }
	end
	local dt = O.step
	local t = 0
	while t < seconds do
		local step = math.min(dt, seconds - t)
		t += step
		local work = step * (O.speed or 1) -- 자리 비운 동안은 절반 속도 (D42)
		local active = false
		for i = 1, #dd.partTimers do
			if hooks.helper(dd, i, helperState[i], work, rep) then
				active = true
			end
		end
		if hooks.machine(dd, work, rep) then
			active = true
		end
		if hooks.factory(dd, work, rep) then
			active = true
		end
		if not active then
			break -- 판매가 없으니 한 번 멈추면 다시 안 돎
		end
	end
	rep.worked = t
	return rep
end

-- 들어올 때 한 번. lastSeen이 없으면(새 플레이어) 정산 없이 시작
function OfflineService.settle(player, forceFrom)
	local d = Data.get(player)
	if not d then
		return nil
	end
	local now = os.time()
	local from = forceFrom or tonumber(d.lastSeen) or 0
	local rep, newShapes = nil, {}
	Data.update(player, function(dd)
		dd.lastSeen = now -- 먼저 지금으로: 같은 시간을 두 번 세지 않음
		if from <= 0 or now - from < O.minSeconds then
			return
		end
		local seconds = math.min(now - from, O.maxHours * 3600)
		rep = simulate(dd, seconds)
		dd.offline = { settledAt = now, from = from, seconds = seconds }
		if #rep.ups > 0 and hooks.refreshUnlocks then
			newShapes = hooks.refreshUnlocks(dd)
		end
	end)
	Data.allowSeen(player)
	if not rep then
		return nil
	end
	local total = rep.made.helper + rep.made.machine + rep.made.factory
	print(string.format("[Offline] %s away %ds (counted %d): made helper=%d machine=%d factory=%d wages=%d exp=%d stops=%d", player.Name, now - from, rep.seconds, rep.made.helper, rep.made.machine, rep.made.factory, rep.wages, rep.exp, (function()
		local n = 0
		for _ in pairs(rep.stops) do
			n += 1
		end
		return n
	end)()))
	if total <= 0 and next(rep.stops) == nil then
		return rep
	end
	Economy.announceLevels(player, rep.ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
	Economy.push(player)
	local payload = {
		away = now - from,
		seconds = rep.seconds,
		worked = rep.worked, -- 모두 멈출 때까지 돈 시간 (보관함이 차는 데 걸린 시간)
		maxHours = O.maxHours,
		made = rep.made,
		total = total,
		used = rep.used,
		wages = rep.wages,
		factoryCoins = rep.factoryCoins,
		exp = rep.exp,
		stops = rep.stops,
	}
	task.delay(O.reportDelay, function()
		if player.Parent then
			reportEvent:FireClient(player, payload)
		end
	end)
	return rep
end

function OfflineService.init(dataService, economyService, offlineHooks)
	Data, Economy, hooks = dataService, economyService, offlineHooks
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	reportEvent = remotes:FindFirstChild("OfflineReport")
	if not reportEvent then
		reportEvent = Instance.new("RemoteEvent")
		reportEvent.Name = "OfflineReport"
		reportEvent.Parent = remotes
	end
	-- Studio 전용: 자리 비운 시간을 당겨서 바로 정산해 보기
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevOffline"
		dev.OnInvoke = function(userId, seconds)
			local p = Players:GetPlayerByUserId(userId)
			if not p then
				return "no player"
			end
			local rep = OfflineService.settle(p, os.time() - math.floor(tonumber(seconds) or 0))
			if not rep then
				return "nothing"
			end
			local used = {}
			for id, n in pairs(rep.used) do
				table.insert(used, id .. "=" .. n)
			end
			local stops = {}
			for k, v in pairs(rep.stops) do
				table.insert(stops, k .. ":" .. v)
			end
			return string.format("counted=%d worked=%d helper=%d machine=%d factory=%d wages=%d factoryCoins=%d exp=%d used=[%s] stops=[%s]", rep.seconds, rep.worked, rep.made.helper, rep.made.machine, rep.made.factory, rep.wages, rep.factoryCoins, rep.exp, table.concat(used, ","), table.concat(stops, "; "))
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

return OfflineService
