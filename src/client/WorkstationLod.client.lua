-- 남의 가게 작업대 소품은 멀면 숨기기 (성능 개선 3, 2026-11-22, docs/PERFORMANCE_BUDGET.md)
--  - 화면 삼각형의 약 70%가 가게 손 작업대 6개 (작업대 하나 약 3만 5천, 그중 약 3만 1천이 꾸미기 소품)
--  - 남의 가게 작업대(Plot<i>.Workstation)가 카메라에서 G.Perf.workstationLodDistance 밖이면, 그 바로 아래 자식 중
--    G.Perf.workstationHide 이름(설탕 그릇·숟가락·깡통·젓가락 통·꾸미기 Stage1Decor·포장 소품)만 내 화면에서 안 그림
--    (BasePart.LocalTransparencyModifier = 1, 서버·다른 사람 화면은 그대로). 화로·테이블·국자·철판·누름판·틀·러그는 남김
--  - 가까워지면(거리 - 여유) 원래대로. 내 가게 작업대는 건드리지 않음
--  - 알바생 미니미·HelperLadles 국자는 작업대 밖이거나 이름이 달라서 건드리지 않음
--  - 제작 세션 파일(WorkstationBuilder·StallDecor·Making/**)은 고치지 않음. 이름으로만 고름

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local P = G.Perf

local HIDE = {}
for _, name in ipairs(P.workstationHide) do
	HIDE[name] = true
end
local KEEP_IN_PACK = {}
for _, name in ipairs(P.workstationPackKeep) do
	KEEP_IN_PACK[name] = true
end

local states = {} -- [Workstation] = { far, parts }

-- 숨길 부품 목록 (작업대 바로 아래 자식 이름으로 고름, PackArea는 매트만 남김)
local function propParts(ws)
	local list = {}
	local function addAll(inst)
		if inst:IsA("BasePart") then
			table.insert(list, inst)
		end
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	for _, c in ipairs(ws:GetChildren()) do
		if HIDE[c.Name] then
			addAll(c)
		elseif c.Name == "PackArea" then
			for _, k in ipairs(c:GetChildren()) do
				if not KEEP_IN_PACK[k.Name] then
					addAll(k)
				end
			end
		end
	end
	return list
end

-- 숨길 때 내가 숨겼다는 표시(LodHidden, 내 화면에서만)를 남기고, 되돌릴 때는 그 표시가 있는 것만 0으로.
-- 제작 쪽 Making/Supplies가 숨긴 빈 통 내용물(속성 SupplyHidden)은 건드리지 않음 (가게 주인이 바뀌는 순간 등)
local function apply(st, far)
	for _, p in ipairs(st.parts) do
		if far then
			if p.LocalTransparencyModifier < 1 then
				p.LocalTransparencyModifier = 1
				p:SetAttribute("LodHidden", true)
			end
		elseif p:GetAttribute("LodHidden") then
			p:SetAttribute("LodHidden", nil)
			if not p:GetAttribute("SupplyHidden") then
				p.LocalTransparencyModifier = 0
			end
		end
	end
end

local function step()
	local cam = workspace.CurrentCamera
	local plots = workspace:FindFirstChild("ShopPlots")
	if not cam or not plots then
		return
	end
	local camPos = cam.CFrame.Position
	local seen = {}
	for _, plot in ipairs(plots:GetChildren()) do
		local ws = plot:FindFirstChild("Workstation")
		if ws and plot:GetAttribute("OwnerUserId") ~= player.UserId then
			seen[ws] = true
			local st = states[ws]
			if not st then
				st = { far = false, parts = {} }
				states[ws] = st
			end
			local d = (ws:GetPivot().Position - camPos).Magnitude
			local far = st.far
			if workspace:GetAttribute("WorkstationLodOff") then
				far = false -- 시험용: 전·후 비교 (Workspace 속성)
			elseif d > P.workstationLodDistance then
				far = true
			elseif d < P.workstationLodDistance - P.workstationLodMargin then
				far = false
			end
			if far ~= st.far then
				st.far = far
				st.parts = propParts(ws)
				apply(st, far)
			elseif far then
				-- 멀리 있는 동안 소품이 새로 생기거나(스트리밍으로 받음) 바뀌면 다시
				local list = propParts(ws)
				if #list ~= #st.parts then
					st.parts = list
					apply(st, true)
				end
			end
		end
	end
	-- 없어진 작업대(가게 비움·내 가게가 됨) 정리
	for ws, st in pairs(states) do
		if not seen[ws] then
			if ws.Parent and st.far then
				apply(st, false)
			end
			states[ws] = nil
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(step)
		if not ok then
			warn("[WorkstationLod]", err)
		end
		task.wait(P.lodCheckSeconds)
	end
end)
