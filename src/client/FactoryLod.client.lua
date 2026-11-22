-- 남의 공장은 멀면 단순한 상자로 (성능 개선 1, 2026-11-22, docs/PERFORMANCE_BUDGET.md)
--  - 공장 3D(Plot<i>.FactoryLot.Building, 약 6만 삼각형)와 공정 알바생(FactoryLot.Staff)을, 카메라에서 G.Perf.factoryLodDistance 밖이면
--    내 화면에서만 안 그림 (BasePart.LocalTransparencyModifier = 1, 서버·다른 사람 화면은 그대로)
--  - 대신 공장 크기·색을 딴 낮은 상자 2개를 내 화면에만 놓음 (workspace.CurrentCamera 아래)
--  - 가까워지면(경계 - 여유) 원래대로. 내 공장은 건드리지 않음
--  - 공장 모습·연출은 제작 세션의 FactoryDisplay·FactoryClient (Transparency를 안 건드림을 확인, 2026-11-22)
--  - 신호: 멀어서 숨기면 Building 속성 LodFar = true (내 화면에서만 바꾼 값). FactoryClient가 상태판·알바생 움직임을 멈출 때 씀

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local P = G.Perf

local states = {} -- [Building] = { far, parts, proxy }

local function partsOf(lot)
	local list = {}
	for _, name in ipairs({ "Building", "Staff" }) do
		local m = lot:FindFirstChild(name)
		if m then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

-- 공장 크기·색을 딴 상자 (가장 큰 부품 두 개의 색)
local function makeProxy(building)
	local cf, size = building:GetBoundingBox()
	local colors = {}
	for _, d in ipairs(building:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.5 then
			table.insert(colors, { v = d.Size.X * d.Size.Y * d.Size.Z, c = d.Color })
		end
	end
	table.sort(colors, function(a, b)
		return a.v > b.v
	end)
	local c1 = colors[1] and colors[1].c or Color3.fromRGB(240, 200, 210)
	local c2 = colors[2] and colors[2].c or c1
	local m = Instance.new("Model")
	m.Name = "FactoryProxy"
	local h = size.Y * P.factoryProxyHeight
	local bottom = cf.Position.Y - size.Y / 2
	local function box(name, s, at, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = s
		p.CFrame = at
		p.Color = color
		p.Parent = m
	end
	local base = CFrame.new(cf.Position.X, bottom + h / 2, cf.Position.Z) * (cf - cf.Position)
	box("Body", Vector3.new(size.X, h, size.Z), base, c1)
	box("Roof", Vector3.new(size.X * 0.92, h * 0.25, size.Z * 0.92), base * CFrame.new(0, h * 0.625, 0), c2)
	m.Parent = workspace.CurrentCamera
	return m
end

local function setFar(st, building, lot, far)
	if st.far == far then
		return
	end
	st.far = far
	building:SetAttribute("LodFar", far) -- 내 화면에만 (FactoryClient가 상태판·움직임을 멈추는 데 씀)
	st.parts = partsOf(lot)
	for _, p in ipairs(st.parts) do
		p.LocalTransparencyModifier = far and 1 or 0
	end
	if far then
		st.proxy = st.proxy or makeProxy(building)
	elseif st.proxy then
		st.proxy:Destroy()
		st.proxy = nil
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
		local lot = plot:FindFirstChild("FactoryLot")
		local building = lot and lot:FindFirstChild("Building")
		if building and plot:GetAttribute("OwnerUserId") ~= player.UserId then
			seen[building] = true
			local st = states[building]
			if not st then
				st = { far = false }
				states[building] = st
			end
			local d = (building:GetPivot().Position - camPos).Magnitude
			local far = st.far
			if workspace:GetAttribute("FactoryLodOff") then
				far = false -- 시험용: 전·후 비교 (Workspace 속성)
			elseif d > P.factoryLodDistance then
				far = true
			elseif d < P.factoryLodDistance - P.factoryLodMargin then
				far = false
			end
			setFar(st, building, lot, far)
			-- 멀리 있는 동안 새로 생긴 부품(공정 알바생 고용 등)도 숨김
			if st.far then
				local n = #partsOf(lot)
				if n ~= #st.parts then
					st.parts = partsOf(lot)
					for _, p in ipairs(st.parts) do
						p.LocalTransparencyModifier = 1
					end
				end
			end
		end
	end
	-- 없어진 공장(잠김·주인 나감·내 공장이 됨) 정리
	for building, st in pairs(states) do
		if not seen[building] then
			if st.proxy then
				st.proxy:Destroy()
			end
			if building.Parent then
				for _, p in ipairs(st.parts or {}) do
					p.LocalTransparencyModifier = 0
				end
			end
			states[building] = nil
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(step)
		if not ok then
			warn("[FactoryLod]", err)
		end
		task.wait(P.lodCheckSeconds)
	end
end)
