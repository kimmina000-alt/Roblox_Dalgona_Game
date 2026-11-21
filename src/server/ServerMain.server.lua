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
local MachineDisplay = require(Services:WaitForChild("MachineDisplay"))

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
-- 2026-11-21 사용자 "기존 작업대 백업해 놓고 ㄷ자 작업대로 교체": 틀 = Studio 편집 모드 Workspace의 WorkstationLayout
-- (ㄷ자 카운터, 사용자가 물건 자리를 직접 옮겨 둠). 게임이 시작되면 Workspace에서 빼서 틀 자리로 옮기므로 게임 안에는 안 보임.
-- 예전 노점 틀은 ServerStorage.Backup.WorkstationTemplate_Old 에 백업만 해 둠 (안 씀).
-- WorkstationLayout이 없을 때만 예전처럼 ServerStorage.Assets.WorkstationTemplate을 꾸며서 씀
do
	local ServerStorage = game:GetService("ServerStorage")
	local assets = ServerStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ServerStorage
	end
	local layout = workspace:FindFirstChild("WorkstationLayout") or workspace:FindFirstChild("WorkstationPreviewV3")
	local shared = workspace:FindFirstChild("DalgonaWorkstation")
	if layout then
		if shared then
			shared:Destroy()
		end
		local old = assets:FindFirstChild("WorkstationTemplate")
		if old then
			old:Destroy() -- 이번 게임에서만 (편집 모드 원본은 그대로)
		end
		for _, d in ipairs(layout:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Name == "PreviewLabel" then
				d:Destroy()
			end
		end
		WorkstationBuilder.syncCounter(layout) -- 모양 틀 기울기(RestYaw) 다시 읽기
		layout.Name = "WorkstationTemplate"
		layout.Parent = assets
		StallDecor.grade() -- 색감 보정 (예전에는 꾸미기 dress가 넣었음)
		if layout:GetAttribute("CoalLeft") == nil then
			WorkstationBuilder.setCoal(layout, 1)
		end
	else
		local tpl = assets:FindFirstChild("WorkstationTemplate")
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
			warn("[Server] 작업대 틀(Workspace.WorkstationLayout / ServerStorage.Assets.WorkstationTemplate)이 없어요 — 가게 작업대를 만들 수 없음")
		end
	end
end

-- Lv5 달고나 공장: 스폰 뒤쪽(+Z)에 앞(제어대)이 스폰을 보게 놓는다. 자동 생산 연결은 다음 단계.
FactoryBuilder.place(workspace, CFrame.new(0, 0, 30))
-- Lv4 연속 생산 설비는 시험 자리(28,0,-14)에서 빼고 가게 기계 자리로 (20번, 2026-11-21: MachineDisplay)

-- 경제(HUD·상점) → 성장(데이터를 처음 불러올 때 듣기 위해 저장보다 먼저) → 저장 → 가게 부지 6칸 → 판매 → 제작 결과 연결
EconomyService.init(PlayerDataService, remotes)
GrowthService.init(PlayerDataService, EconomyService, PlotService, remotes) -- 해금·도감·장비·국자·알바생·일일 목표 (Phase 4)
PlayerDataService.init()
PlotService.init({ notify = EconomyService.notify })
SalesService.init(PlayerDataService, EconomyService, PlotService) -- 진열대 + 손님 (Phase 3)
MachineDisplay.init() -- 가게 기계 자리 모습 (2~4단계 기계, MachineSlot 속성 Stage를 따라 바꿈, 20번)
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
