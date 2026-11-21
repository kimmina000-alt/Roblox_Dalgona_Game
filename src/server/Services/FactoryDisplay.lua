-- 5단계 공장 모습 (2026-11-22 D11 변경: 공장은 가게 건물 뒤에 바로 붙고, 뒷문으로 걸어 들어감)
-- 서버 생산·해금·영역 판정은 FactoryService(저장·부지 세션). 연결 규칙:
--   상태 신호: workspace.Factories.Factory<i> 속성 (i = 부지 번호): OwnerUserId, Unlocked, On, Status, Mode, Lines,
--     Line<k>Start·Line<k>Seconds·Line<k>Count·Line<k>Shape, MadeAt·MadeCount·MadeSlots
--   모습 (여기서 만듦):
--     ShopPlots.Plot<i>.FactoryLot (Model): 뒷문 바깥 폭 28 × 깊이 44 울타리 친 "공장 부지". 바닥 "Ground"(속성 Area = true)가 공장 영역.
--       6칸 모두 처음부터 있음 (가벼움). 피벗 = 바닥 가운데, -Z = 가게 뒷문 쪽
--     FactoryLot.Building: 해금된 가게에만 공장 3D (ServerStorage.Assets.Factory, 90° 돌려 열린 면이 뒷문 쪽). 잠기면 지움 (폰 성능)
--       부품 속성 Anim(press·spin·belt·hopper·kettle·lampRun·lampStop·lampIdle·outlet) → 클라이언트 FactoryClient가 움직임
--       제어대(콘솔) 앞 ProximityPrompt "ControlPrompt" → FACTORY CONTROL 화면 (주인만)
--     가게 뒷문 FactoryDoor.Door: 잠김 = 닫힘·자물쇠 "DoorLock"·간판 "Lv25 해금" / 열림 = 문짝이 열리고 안 부딪힘 → 걸어서 들어감

local ServerStorage = game:GetService("ServerStorage")

local FactoryBuilder = require(script.Parent:WaitForChild("FactoryBuilder"))

local Display = {}

local LOT_W, LOT_D = 28, 44 -- 공장 부지 폭(가게와 나란한 쪽) · 깊이(가게에서 멀어지는 쪽)
local GAP = 0.6 -- 가게 뒷벽과 부지 사이
local GATE_W = 8 -- 뒷문 앞 울타리 틈
-- 공장 3D를 부지 기준으로 돌리는 각도 (원래 44×28 → 90° 돌려 28×44). 열린 면이 뒷문(-Z)을 보도록 화면으로 확인해 정함
local BUILD_YAW = 90

local ANIM = {
	Line_PressHead_Node = "press",
	Line_PressStamps_Node = "press",
	Line_PressCylinders_Node = "press",
	Line_TunnelFans_Node = "spin",
	Line_Dalgona_Node = "belt",
	Line_HopperSugar_Node = "hopper",
	Deco_HopperBalls_Node = "hopper",
	Line_Kettles_Node = "kettle",
	Deco_KettleBalls_Node = "kettle",
	Line_TowerG_Node = "lampRun",
	Line_PressBeacons_Node = "lampRun",
	Line_TowerR_Node = "lampStop",
	Line_TowerY_Node = "lampIdle",
	Line_Chute_Node = "outlet",
}

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- 부지 기준 CFrame: 가게 바닥 높이, 뒷문 바깥 가운데. -Z = 가게(뒷문) 쪽
local function lotFrame(plot)
	local door = plot:FindFirstChild("FactoryDoor")
	local panel = door and door:FindFirstChild("Door")
	local floor = plot:FindFirstChild("Floor")
	if not (panel and floor) then
		return nil
	end
	local back = Vector3.new(panel.Position.X - floor.Position.X, 0, panel.Position.Z - floor.Position.Z).Unit
	local topY = floor.Position.Y + floor.Size.Y / 2
	local c = Vector3.new(panel.Position.X, topY, panel.Position.Z) + back * (GAP + LOT_D / 2)
	return CFrame.lookAt(c, c - back)
end

-- 울타리 친 공장 부지 (6칸 모두)
local FENCE = Color3.fromRGB(240, 226, 206)
local function buildLot(plot)
	if plot:FindFirstChild("FactoryLot") then
		return plot.FactoryLot
	end
	local cf = lotFrame(plot)
	if not cf then
		return nil
	end
	local lot = Instance.new("Model")
	lot.Name = "FactoryLot"
	local ground = part(lot, "Ground", Vector3.new(LOT_W, 0.3, LOT_D), cf * CFrame.new(0, -0.14, 0), Color3.fromRGB(214, 226, 196), Enum.Material.Grass, { CanCollide = true })
	ground:SetAttribute("Area", true)
	-- 울타리: 기둥 + 가로대 두 줄. 뒷문 쪽(-Z) 가운데는 비움
	local H = 2.2
	local function rail(a, b)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		if len < 0.1 then
			return
		end
		for _, y in ipairs({ 0.8, 1.7 }) do
			part(lot, "FenceRail", Vector3.new(0.18, 0.25, len), CFrame.lookAt(mid + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)), FENCE, Enum.Material.Wood, { CanCollide = y > 1 })
		end
	end
	local hw, hd = LOT_W / 2, LOT_D / 2
	local function at(x, z)
		return (cf * CFrame.new(x, 0, z)).Position
	end
	local corners = { at(-hw, -hd), at(-hw, hd), at(hw, hd), at(hw, -hd) }
	for _, p in ipairs(corners) do
		part(lot, "FencePost", Vector3.new(0.4, H, 0.4), CFrame.new(p + Vector3.new(0, H / 2, 0)), FENCE, Enum.Material.Wood)
	end
	rail(corners[1], corners[2])
	rail(corners[2], corners[3])
	rail(corners[3], corners[4])
	-- 뒷문 쪽: 문 앞 GATE_W 만큼 비우고 양쪽만
	local g1, g2 = at(-GATE_W / 2, -hd), at(GATE_W / 2, -hd)
	rail(corners[1], g1)
	rail(g2, corners[4])
	for _, p in ipairs({ g1, g2 }) do
		part(lot, "FencePost", Vector3.new(0.4, H, 0.4), CFrame.new(p + Vector3.new(0, H / 2, 0)), FENCE, Enum.Material.Wood)
	end
	-- 가운데 표지판 (해금 전): "공장 부지"
	local sign = part(lot, "LotSign", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(0, 4, 0), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Name = "LotLabel"
	bb.Size = UDim2.fromOffset(220, 56)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(120, 90, 60)
	t.Text = "공장 부지\nLv25에 공장을 지어요"
	t.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = t
	bb.Parent = sign
	lot.PrimaryPart = ground
	lot:SetAttribute("LotCFrame", cf)
	lot.Parent = plot
	return lot
end

-- 해금된 가게에만 공장 3D
local function buildBuilding(lot)
	if lot:FindFirstChild("Building") then
		return
	end
	local cf = lot:GetAttribute("LotCFrame")
	local assets = ServerStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Factory")
	if not (cf and src) then
		warn("[Factory] 공장 3D를 못 만들어요 (Assets.Factory / LotCFrame)")
		return
	end
	local b = src:Clone()
	b.Name = "Building"
	FactoryBuilder.style(b)
	-- 피벗 = 바닥 가운데 (예전 공용 공장과 같은 기준). 부지 기준으로 BUILD_YAW 돌림
	b:PivotTo(cf * CFrame.Angles(0, math.rad(BUILD_YAW), 0))
	local console
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			local key = ANIM[d.Name] or (d.Parent and ANIM[d.Parent.Name])
			if key then
				d:SetAttribute("Anim", key)
			end
			if d.Name == "Line_ConsolePanel_Node" or (d.Parent and d.Parent.Name == "Line_ConsolePanel_Node") then
				console = console or d
			end
		end
	end
	if console then
		local att = Instance.new("Attachment")
		att.Name = "ControlAtt"
		att.Parent = console -- 부모를 먼저 정해야 WorldPosition이 맞게 들어감
		att.WorldPosition = console.Position + Vector3.new(0, 1.2, 0)
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "ControlPrompt"
		pr.ObjectText = "공장 제어대"
		pr.ActionText = "제어대 열기"
		pr.KeyboardKeyCode = Enum.KeyCode.F
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = att
	end
	b.Parent = lot
	local sign = lot:FindFirstChild("LotSign")
	if sign then
		sign.LotLabel.Enabled = false
	end
end

local function clearBuilding(lot)
	local b = lot:FindFirstChild("Building")
	if b then
		b:Destroy()
	end
	local sign = lot:FindFirstChild("LotSign")
	if sign then
		sign.LotLabel.Enabled = true
	end
end

-- 가게 뒷문: 잠김(닫힘 + 자물쇠 + "Lv25 해금") / 열림(문짝이 바깥으로 열리고 안 부딪힘)
local function doorLook(plot, unlocked)
	local door = plot:FindFirstChild("FactoryDoor")
	local panel = door and door:FindFirstChild("Door")
	if not panel then
		return
	end
	if panel:GetAttribute("ClosedCFrame") == nil then
		panel:SetAttribute("ClosedCFrame", panel.CFrame)
	end
	local closed = panel:GetAttribute("ClosedCFrame")
	local sign = panel:FindFirstChild("DoorSign")
	if not sign then
		sign = Instance.new("BillboardGui")
		sign.Name = "DoorSign"
		sign.Size = UDim2.fromOffset(180, 46)
		sign.StudsOffset = Vector3.new(0, 5.4, 0)
		sign.MaxDistance = 60
		sign.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
		t.BackgroundTransparency = 0.05
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = sign
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = t
		sign.Parent = panel
	end
	local t = sign:FindFirstChild("Text")
	t.Text = unlocked and "달고나 공장" or "달고나 공장 · Lv25 해금"
	t.TextColor3 = unlocked and Color3.fromRGB(70, 140, 80) or Color3.fromRGB(150, 90, 60)
	panel.Color = unlocked and Color3.fromRGB(255, 196, 214) or Color3.fromRGB(150, 160, 170)
	-- 문짝: 열리면 한쪽 끝을 축으로 공장 쪽(바깥)으로 100° 돌림, 안 부딪힘
	local plotFloor = plot:FindFirstChild("Floor")
	local out = plotFloor and Vector3.new(closed.Position.X - plotFloor.Position.X, 0, closed.Position.Z - plotFloor.Position.Z).Unit or closed.LookVector
	if unlocked then
		local hinge = closed * CFrame.new(-panel.Size.X / 2, 0, 0)
		local sign2 = (hinge.RightVector:Cross(Vector3.yAxis)):Dot(out) > 0 and 1 or -1
		panel.CFrame = hinge * CFrame.Angles(0, math.rad(100) * sign2, 0) * CFrame.new(panel.Size.X / 2, 0, 0)
		panel.CanCollide = false
	else
		panel.CFrame = closed
		panel.CanCollide = true
	end
	local lock = door:FindFirstChild("DoorLock")
	if unlocked and lock then
		lock:Destroy()
	elseif not unlocked and not lock then
		lock = Instance.new("Model")
		lock.Name = "DoorLock"
		local c = closed
		for _, a in ipairs({ 35, -35 }) do
			part(lock, "Chain", Vector3.new(panel.Size.X * 1.05, 0.18, panel.Size.Z + 0.25), c * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(a)), Color3.fromRGB(120, 120, 126), Enum.Material.Metal, { CanCollide = false, CanQuery = false })
		end
		part(lock, "Body", Vector3.new(0.9, 0.8, panel.Size.Z + 0.5), c * CFrame.new(0, 0.1, 0), Color3.fromRGB(230, 190, 70), Enum.Material.Metal, { CanCollide = false, CanQuery = false })
		part(lock, "Shackle", Vector3.new(panel.Size.Z + 0.45, 0.7, 0.7), c * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(180, 180, 186), Enum.Material.Metal, { CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder })
		lock.Parent = door
	end
end

local function sync(plot, fac)
	local lot = buildLot(plot)
	local unlocked = fac ~= nil and fac:GetAttribute("Unlocked") == true
	if lot then
		if unlocked then
			buildBuilding(lot)
		else
			clearBuilding(lot)
		end
	end
	doorLook(plot, unlocked)
end

function Display.init()
	task.spawn(function()
		local plots = workspace:WaitForChild("ShopPlots", 60)
		if not plots then
			return
		end
		local function facFor(i)
			local folder = workspace:FindFirstChild("Factories")
			return folder and folder:FindFirstChild("Factory" .. i)
		end
		local function hookPlot(plot)
			local i = tonumber(plot.Name:match("%d+"))
			if not i then
				return
			end
			plot:WaitForChild("FactoryDoor", 10)
			sync(plot, facFor(i))
		end
		for _, plot in ipairs(plots:GetChildren()) do
			task.spawn(hookPlot, plot)
		end
		plots.ChildAdded:Connect(function(plot)
			task.spawn(hookPlot, plot)
		end)
		-- 공장 상태(Unlocked)가 바뀌면 그 가게만 다시 맞춤
		local folder = workspace:WaitForChild("Factories", 120)
		if not folder then
			return
		end
		local function hookFac(fac)
			local i = tonumber(fac.Name:match("%d+"))
			local plot = i and plots:FindFirstChild("Plot" .. i)
			if plot then
				sync(plot, fac)
			end
			fac:GetAttributeChangedSignal("Unlocked"):Connect(function()
				local p = i and plots:FindFirstChild("Plot" .. i)
				if p then
					sync(p, fac)
				end
			end)
		end
		for _, f in ipairs(folder:GetChildren()) do
			task.spawn(hookFac, f)
		end
		folder.ChildAdded:Connect(function(f)
			task.spawn(hookFac, f)
		end)
	end)
end

return Display
