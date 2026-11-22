-- 첫 60초 안내 (21번, 2026-11-22): 처음 온 사람이 1분 안에 첫 달고나를 만들어 팔게 (DEVELOPMENT_PLAN 6장 Phase 6)
-- 단계 (GrowthConfig.Tutorial.steps): 1 작업대로 가기 → 2 E → 3 만들기 → 4 진열대에 놓기 → 5 손님이 사 감 → 6 재료 상점 열기 → 끝
--  - 새 플레이어(저장 데이터 tutorialDone = false)만. 지금 단계 = 플레이어 속성 Tutorial (0 = 안 함/끝)
--  - 서버가 단계를 넘김: 제작 시작(Economy "started"), 다 만듦("handMade"), 진열("placed" → 손님 바로 오게), 팔림("sold")
--  - 클라이언트(TutorialClient)가 알리는 것: "near"(작업대에 가까이 감), "shop"(상점 열었음), "skip"(건너뛰기)
--    → Remotes.Tutorial (RemoteEvent)
--  - 끝나거나 건너뛰면 tutorialDone = true (저장)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local T = G.Tutorial

local TutorialService = {}

local Data, Economy = nil, nil
local Sales = nil

local function step(player)
	return player:GetAttribute("Tutorial") or 0
end

local function setStep(player, n)
	if step(player) ~= n then
		player:SetAttribute("Tutorial", n)
		print(string.format("[Tutorial] %s step %d", player.Name, n))
	end
end

local function finish(player, skipped)
	Data.update(player, function(d)
		d.tutorialDone = true
	end)
	setStep(player, 0)
	print(string.format("[Tutorial] %s %s", player.Name, skipped and "skipped" or "done"))
end

-- n단계에서 다음으로 (지금 단계가 n 이하일 때만: 순서를 건너뛰어도 앞으로만 감)
local function advance(player, upTo, nextStep)
	local s = step(player)
	if s > 0 and s <= upTo then
		setStep(player, nextStep)
	end
end

function TutorialService.init(dataService, economyService, remotes)
	Data, Economy = dataService, economyService
	local ok, mod = pcall(require, script.Parent:WaitForChild("SalesService"))
	Sales = ok and mod or nil

	local ev = remotes:FindFirstChild("Tutorial")
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = "Tutorial"
		ev.Parent = remotes
	end

	-- 처음 불러올 때: 새 플레이어면 1단계부터
	local seen = {}
	Data.Changed:Connect(function(player)
		if seen[player] then
			return
		end
		local d = Data.get(player)
		if not d then
			return
		end
		seen[player] = true
		if not d.tutorialDone then
			setStep(player, 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		seen[p] = nil
	end)

	Economy.on("started", function(player)
		advance(player, 3, 3) -- 작업대로 가기·E를 건너뛰고 바로 시작해도 만들기 단계로
	end)
	Economy.on("handMade", function(player)
		advance(player, 3, 4)
	end)
	Economy.on("placed", function(player)
		local s = step(player)
		if s > 0 and s <= 4 then
			setStep(player, 5)
			if T.hurryCustomer and Sales and Sales.hurry then
				Sales.hurry(player) -- 첫 판은 손님이 바로 오게
			end
		end
	end)
	Economy.on("sold", function(player)
		advance(player, 5, 6)
	end)

	-- Studio 전용: 안내를 처음부터 다시 (ServerStorage.DevTutorial:Invoke(userId))
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevTutorial"
		dev.OnInvoke = function(userId)
			local p = Players:GetPlayerByUserId(userId)
			if not p then
				return "no player"
			end
			Data.update(p, function(d)
				d.tutorialDone = false
			end)
			setStep(p, 1)
			return "restarted"
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	ev.OnServerEvent:Connect(function(player, what)
		local s = step(player)
		if s <= 0 then
			return
		end
		if what == "skip" then
			finish(player, true)
		elseif what == "near" then
			advance(player, 1, 2)
		elseif what == "making" then
			advance(player, 2, 3) -- 제작 화면이 열림 (도안 고르기부터)
		elseif what == "shop" and s == 6 then
			finish(player, false)
		end
	end)
end

return TutorialService
