-- 서버 진입점 (Phase 1 제작 프로토타입 + Phase 2 저장·가게 부지·재료 상점)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent:WaitForChild("Services")
local WorkstationBuilder = require(Services:WaitForChild("WorkstationBuilder"))
local ProductionService = require(Services:WaitForChild("ProductionService"))
local FactoryBuilder = require(Services:WaitForChild("FactoryBuilder"))
local StallDecor = require(Services:WaitForChild("StallDecor"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local SalesService = require(Services:WaitForChild("SalesService"))
local GrowthService = require(Services:WaitForChild("GrowthService"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
for _, name in ipairs({ "StartProduction", "SubmitProduction", "BuyIngredient", "GetPlayerState", "PackDalgona", "GrowthAction", "SubmitPpopgi" }) do
	if not remotes:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotes
	end
end
for _, name in ipairs({ "PlayerState", "Notify" }) do
	if not remotes:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
	end
end

-- 손 작업대 틀 (17b·U8, 2026-11-21): 스폰 앞 공용 작업대는 없애고, 가게 부지마다 작업대를 둠 (PlotService).
-- 틀 = ServerStorage.Assets.WorkstationTemplate (Studio에 저장된 꾸며진 작업대). 예전 장소처럼 공용 작업대가
-- workspace에 남아 있으면 틀 자리로 옮김. 꾸미기(StallDecor.dress)는 틀에 한 번 해 두고 PlotService가 복제함
do
	local ServerStorage = game:GetService("ServerStorage")
	local assets = ServerStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ServerStorage
	end
	local tpl = assets:FindFirstChild("WorkstationTemplate")
	local shared = workspace:FindFirstChild("DalgonaWorkstation")
	if not tpl and shared then
		shared.Name = "WorkstationTemplate"
		shared.Parent = assets
		tpl = shared
	elseif shared then
		shared:Destroy()
	end
	if tpl then
		if not tpl:FindFirstChild("Cutter") then
			WorkstationBuilder.buildCutter(tpl) -- 예전 별 전용 틀 → 도안을 바꿔 끼우는 틀
		end
		StallDecor.dress(tpl) -- 식탁보·러그·색감·포장 공간 (2026-11-19~20)
		WorkstationBuilder.streetLayout(tpl) -- 노점 배치: 화로는 테이블 옆 땅 위, 테이블 짧게, 젓가락은 소다 통 옆 (2026-11-21)
		if tpl:GetAttribute("CoalLeft") == nil then
			WorkstationBuilder.setCoal(tpl, 1)
		end
	else
		warn("[Server] ServerStorage.Assets.WorkstationTemplate 이 없어요 — 가게 작업대를 만들 수 없음")
	end
end

-- 새 작업대 배치 미리 보기 (2026-11-21 사용자 그림 "작업대 별도 공간에 사진처럼 구현해"):
-- 스폰 옆 빈 곳(-50, 0, 10)에 틀 복제를 ㄷ자 카운터 배치로 놓아 둠. E로 여기서도 만들 수 있음 (재료·연탄은 내 가게 것)
do
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local tpl = assets and assets:FindFirstChild("WorkstationTemplate")
	if tpl then
		local ok, err = pcall(function()
			local prev = tpl:Clone()
			prev.Name = "WorkstationPreviewV3"
			for _, c in ipairs(prev:GetChildren()) do
				if c.Name:sub(1, 11) == "HelperLadle" then
					c:Destroy()
				end
			end
			WorkstationBuilder.counterLayout(prev)
			local top = prev:FindFirstChild("TableTop")
			local target = Vector3.new(-50, 0, 10)
			prev:PivotTo(prev:GetPivot() + Vector3.new(target.X - top.Position.X, 0, target.Z - top.Position.Z))
			local bb = Instance.new("BillboardGui")
			bb.Name = "PreviewLabel"
			bb.Size = UDim2.fromOffset(260, 50)
			bb.StudsOffset = Vector3.new(0, 7, 0)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 120
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
			t.TextColor3 = Color3.fromRGB(92, 58, 36)
			t.Font = Enum.Font.GothamBold
			t.TextScaled = true
			t.Text = "새 작업대 배치 (미리 보기)"
			t.Parent = bb
			bb.Parent = top
			prev.Parent = workspace
		end)
		if not ok then
			warn("[Server] 작업대 미리 보기를 못 만들었어요:", err)
		end
	end
end

-- Lv5 달고나 공장: 스폰 뒤쪽(+Z)에 앞(제어대)이 스폰을 보게 놓는다. 자동 생산 연결은 다음 단계.
FactoryBuilder.place(workspace, CFrame.new(0, 0, 30))
-- Lv4 연속 생산 설비: 작업대 오른쪽 옆 시험 자리, 조작판이 스폰 쪽(+Z)을 보게 180° 돌림
FactoryBuilder.placeLine(workspace, CFrame.new(28, 0, -14) * CFrame.Angles(0, math.pi, 0)) -- 테이블 오른쪽 포장 공간(+6) 만큼 더 오른쪽 (2026-11-20)

-- 경제(HUD·상점) → 성장(데이터를 처음 불러올 때 듣기 위해 저장보다 먼저) → 저장 → 가게 부지 6칸 → 판매 → 제작 결과 연결
EconomyService.init(PlayerDataService, remotes)
GrowthService.init(PlayerDataService, EconomyService, PlotService, remotes) -- 해금·도감·장비·국자·알바생·일일 목표 (Phase 4)
PlayerDataService.init()
PlotService.init({ notify = EconomyService.notify })
SalesService.init(PlayerDataService, EconomyService, PlotService) -- 진열대 + 손님 (Phase 3)
ProductionService.hooks.mods = GrowthService.mods
ProductionService.hooks.canStart = EconomyService.canMake
ProductionService.hooks.onStart = EconomyService.onStart -- 나무젓가락 1쌍
ProductionService.hooks.onResult = EconomyService.onMade
ProductionService.hooks.workstation = PlotService.workstation -- 내 가게 작업대 (17b)
ProductionService.hooks.onPpopgi = EconomyService.onPpopgi -- 뽑기 보너스·쪼개짐 (15번)

ProductionService.init({
	StartProduction = remotes.StartProduction,
	SubmitProduction = remotes.SubmitProduction,
	SubmitPpopgi = remotes.SubmitPpopgi,
})
