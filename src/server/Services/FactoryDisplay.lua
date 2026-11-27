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
local PROMPT_DISTANCE = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GrowthConfig")).PromptDistance or 6 -- 기계·가구 버튼이 뜨는 거리 (2026-11-24)

local FactoryBuilder = require(script.Parent:WaitForChild("FactoryBuilder"))
local FactoryLine5 = require(script.Parent:WaitForChild("FactoryLine5"))
local Layout = require(script.Parent:WaitForChild("LayoutTemplate"))
local layout = nil -- 편집 화면에서 고친 공장 틀 (아래 factoryLayout)

local Display = {}

local LOT_W, LOT_D = 28, 44 -- 공장 부지 폭(가게와 나란한 쪽) · 깊이(가게에서 멀어지는 쪽)
local GAP = 0.6 -- 가게 뒷벽과 부지 사이
local GATE_W = 8 -- 뒷문 앞 울타리 틈
-- 공장 3D를 부지 기준으로 돌리는 각도 (원래 44×28 → 90° 돌려 28×44). 공장 모델은 뒤·왼쪽에만 벽이 있고 오른쪽 짧은 끝
-- (나오는 곳·상자 쪽, 모델 -X)이 열려 있음 → -90°로 돌려 그 끝이 뒷문(-Z)을 보게 함 (2026-11-22 화면으로 확인: 90°면 벽이 문 앞)
local BUILD_YAW = -90

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
	-- 아늑한 가게 그림체 공장 기계 (tools/blender/cozy_factory.py, 2026-11-23 사용자: 기존 기계 백업하고 교체)
	Fac_Press_Node = "press",
	Fac_Fan_Node = "spin",
	Fac_BeltDalgona_Node = "belt",
	Fac_Sugar_Node = "hopper",
	Fac_Kettle_Node = "kettle",
	Fac_Lights_Node = "lampRun",
	Fac_StartButton_Node = "lampRun",
	Fac_StopButton_Node = "lampStop",
	Fac_Chute_Node = "outlet",
	-- 공정별로 나눈 새 기계 (3D 모델 세션 3af0f81, 2026-11-23, 기획 D36): 공정마다 움직임 (FactoryClient가 그림)
	Fac_FeedPipe_Node = "feed", -- ① 공급관 흔들림
	Fac_Stirrer_Node = "stir", -- ② 솥 젓개 (세로축 회전)
	Fac_Gauge_Node = "gauge", -- ② 계기 바늘
	Fac_HeatBand_Node = "heat", -- ② 가열 띠 (돌 때 빨강)
	Fac_Nozzle_Node = "nozzle", -- ③ 노즐 (붓는 순간 내려옴)
	Fac_Drop_Node = "drip", -- ③ 노즐 끝 방울
	Fac_Lever_Node = "lever", -- ③ 조작대 레버 (프레스 박자)
	Fac_Curtain_1_Node = "curtain", -- ④ 비닐 커튼
	Fac_Curtain_2_Node = "curtain",
	Fac_Curtain_3_Node = "curtain",
	Fac_Curtain_4_Node = "curtain",
	Fac_CrateLid_Node = "lid", -- ⑤ 상자 뚜껑
}
-- 공정 키 (알바생 D30 / 공정 표시등 / 빈 작업복 걸이)
local STATION_KEYS = { "sugar", "boil", "press", "inspect", "pack" }
local CONSOLE = { Line_ConsolePanel_Node = true, Fac_Console_Node = true, Fac_Console = true } -- 제어대 ProximityPrompt를 붙일 부품
-- 공장 공정 (알바생 자리·공정 옷·기계 앞 "내가 하기")
local STATIONS = {
	-- 공장 모델 기준 자리 (x = 라인 따라, z = 앞 통로 STAND_Z, 라인을 보고 섬). 옷 색
	{ key = "sugar", n = 1, name = "설탕 넣기", x = 18.5, color = Color3.fromRGB(250, 250, 250) },
	{ key = "boil", n = 2, name = "끓이기", x = 10.5, color = Color3.fromRGB(220, 70, 70) },
	{ key = "press", n = 3, name = "붓기·찍기", x = 1.5, color = Color3.fromRGB(255, 205, 60) },
	{ key = "inspect", n = 4, name = "식히기·검사", x = -9, color = Color3.fromRGB(140, 200, 240) },
	{ key = "pack", n = 5, name = "포장", x = -16, color = Color3.fromRGB(80, 130, 220) },
}
local STAND_Z = -3.2

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
	-- 편집 화면에서 고친 울타리·바닥·표지판 (FactoryLayout 안 Lot, 판매 세션 2026-11-22). 바닥·표지판은 지워도 숨김만
	local lotT = layout and layout:FindFirstChild("Lot")
	if lotT then
		Layout.tag(lot)
		Layout.apply(lot, lotT, layout:GetAttribute("LotCFrame"), cf, {
			keep = function(d)
				return d.Name == "Ground" or d.Name == "LotSign"
			end,
		})
	end
	lot.PrimaryPart = ground
	lot:SetAttribute("LotCFrame", cf)
	lot.Parent = plot
	return lot
end

-- 편집 화면에서 고친 공장 (2026-11-22 사용자 "공장 디자인부터 세부 위치 수정하게", 판매 세션이 넣음):
-- 편집 모드 Workspace.FactoryLayout = 칠한 공장을 Plot1 공장 부지에 놓은 것 (속성 LotCFrame = 그 부지 기준).
-- 서버 시작 때 ServerStorage.Assets.FactoryLayout으로 옮기고, 있으면 Assets.Factory 대신 이걸 복제 (style()·BUILD_YAW 안 함)
local function factoryLayout()
	local assets = ServerStorage:FindFirstChild("Assets")
	local src = workspace:FindFirstChild("FactoryLayout")
	if src then
		src.Parent = assets or ServerStorage
	else
		src = assets and assets:FindFirstChild("FactoryLayout")
	end
	if src and typeof(src:GetAttribute("LotCFrame")) == "CFrame" then
		return src
	end
	return nil
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
	local b
	if layout then
		-- 편집 화면에서 고친 공장: 그 부지 기준 자리 그대로 이 부지로
		b = layout:Clone()
		b.Name = "Building"
		b:SetAttribute("LotCFrame", nil)
		b:PivotTo(cf * layout:GetAttribute("LotCFrame"):ToObjectSpace(layout:GetPivot()))
		local lotPart = b:FindFirstChild("Lot")
		if lotPart then
			lotPart:Destroy() -- 울타리 틀은 buildLot이 씀
		end
		-- 2026-11-27 사용자 참고 사진 "스테인리스 생산 라인": 틀의 예전 파스텔 라인(Line_·Deco_ 부품)은 지우고
		-- 같은 자리에 코드로 세운 라인(FactoryLine5, S5_ 부품)을 놓음. 틀에 이미 S5_ 라인이 있으면(편집 화면에서 새로 고친 틀) 그대로
		if not b:FindFirstChild("S5_Line", true) then
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("Model") and d.Parent and (d.Name:match("^Line_") or d.Name:match("^Deco_")) then
					d:Destroy()
				end
			end
			FactoryLine5.build(b, cf)
		end
	else
		b = src:Clone()
		b.Name = "Building"
		FactoryBuilder.style(b)
		-- 피벗 = 바닥 가운데 (예전 공용 공장과 같은 기준). 부지 기준으로 BUILD_YAW 돌림
		b:PivotTo(cf * CFrame.Angles(0, math.rad(BUILD_YAW), 0))
	end
	local console
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if string.sub(d.Name, 1, 10) == "Fac_Stand_" then
				d.Transparency = 1 -- 알바생 자리 표시는 안 보이게
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
			local key = ANIM[d.Name] or (d.Parent and ANIM[d.Parent.Name])
			if key then
				d:SetAttribute("Anim", key)
			end
			-- 공정 표시등 Fac_Lamp_<key> (알바 일하면 켜짐) · 빈 작업복 걸이 Fac_Hanger_<key> (고용하면 숨김)
			for _, k in ipairs(STATION_KEYS) do
				if d.Name == "Fac_Lamp_" .. k or (d.Parent and d.Parent.Name == "Fac_Lamp_" .. k .. "_Node") then
					d:SetAttribute("Anim", "stationLamp")
					d:SetAttribute("StationKey", k)
				elseif d.Name == "Fac_Hanger_" .. k or (d.Parent and d.Parent.Name == "Fac_Hanger_" .. k .. "_Node") then
					d:SetAttribute("Anim", "hanger")
					d:SetAttribute("StationKey", k)
				end
			end
			-- 컨베이어 달고나 길·솥 김 자리 표시 (작은 상자): 건물 기준 자리만 속성으로 남기고 안 보이게
			local mark = ({ Fac_Pt_BeltStart = "BeltStart", Fac_Pt_BeltEnd = "BeltEnd", Fac_Pt_Steam = "SteamAt" })[d.Name]
				or (d.Parent and ({ Fac_Pt_BeltStart_Node = "BeltStart", Fac_Pt_BeltEnd_Node = "BeltEnd", Fac_Pt_Steam_Node = "SteamAt" })[d.Parent.Name])
			if mark then
				b:SetAttribute(mark, b:GetPivot():ToObjectSpace(d.CFrame))
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
			-- 옛 5개 묶음 달고나: 클라이언트가 길 위에 6~8개를 돌려 쓰면 숨김 (길 표시가 있을 때만)
			if d.Name == "Fac_BeltDalgona" or (d.Parent and d.Parent.Name == "Fac_BeltDalgona_Node") then
				d:SetAttribute("BeltBundle", true)
			end
			if CONSOLE[d.Name] or (d.Parent and CONSOLE[d.Parent.Name]) then
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
		pr.MaxActivationDistance = PROMPT_DISTANCE
		pr.RequiresLineOfSight = false
		pr.Parent = att
	end
	-- 공정 기계 앞 "내가 하기" (2026-11-24 사용자): 공정마다 알바생 자리(Fac_Stand_<key>)에 버튼. 누르면 제어대 [내가 하기]와 같은 서버 동작
	-- (Display.onSelfPrompt = FactoryService가 넣음). 주인이 아니면·알바생이 있으면 클라이언트 ShopWorld가 내 화면에서 숨김
	for _, st in ipairs(STATIONS) do
		local mark = b:FindFirstChild("Fac_Stand_" .. st.key, true)
		if mark and not mark:IsA("BasePart") then
			mark = mark:FindFirstChildWhichIsA("BasePart", true)
		end
		local pos = mark and (mark.Position + Vector3.new(0, 2.5, 0)) or (b:GetPivot() * CFrame.new(st.x, 2.5, STAND_Z)).Position
		local holder = part(b, "SelfSpot_" .. st.key, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "SelfPrompt"
		pr:SetAttribute("StationKey", st.key)
		pr.ObjectText = st.n .. " " .. st.name
		pr.ActionText = "내가 하기"
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.HoldDuration = 0
		pr.MaxActivationDistance = PROMPT_DISTANCE
		pr.RequiresLineOfSight = false
		pr.Parent = holder
		pr.Triggered:Connect(function(player)
			local plot = lot.Parent
			if not (plot and plot:GetAttribute("OwnerUserId") == player.UserId) then
				return
			end
			if Display.onSelfPrompt then
				Display.onSelfPrompt(player, st.key)
			end
		end)
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

-- ── 공장 공정 알바생 (D30, 2026-11-22): 고용한 공정마다 주인 미니미를 공정 옆 통로에 세움, 공정별 옷 ──
-- 신호: Factory<i> 속성 Staff_<key>(고용) · StaffOn_<key>(지금 일함, 클라이언트가 움직임). key = sugar·boil·press·inspect·pack
-- 모습: FactoryLot.Staff.Staff_<key> (Minime.build 복제 + 공정 옷). 한 가게 미니미 최대 8명 (가게 알바생 포함)
local Minime = require(script.Parent:WaitForChild("Minime"))
local Players = game:GetService("Players")
Display.STATIONS = STATIONS
local MAX_MINIME = 8

local function weldPart(model, name, size, cf, color, target, props)
	local q = Instance.new("Part")
	q.Name = name
	q.Size = size
	q.CFrame = cf
	q.Color = color
	q.Material = Enum.Material.SmoothPlastic
	q.CanCollide = false
	q.CanQuery = false
	q.CanTouch = false
	q.Massless = true
	q.Anchored = false
	for k, v in pairs(props or {}) do
		q[k] = v
	end
	q.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0 = target
	w.Part1 = q
	w.Parent = q
	return q
end

-- 공정별 옷 (D30 표): ① 흰 두건 + 마스크 ② 빨간 앞치마 + 오븐 장갑 ③ 노란 안전모 ④ 하늘색 위생모 + 돋보기 ⑤ 파란 앞치마 + 빵끈
local function dress(model, st)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	local rh, lh = model:FindFirstChild("RightHand"), model:FindFirstChild("LeftHand")
	local function apron(color)
		if torso then
			local s = torso.Size
			weldPart(model, "Apron", Vector3.new(s.X * 0.8, s.Y * 0.85, 0.06), torso.CFrame * CFrame.new(0, -s.Y * 0.05, -s.Z / 2 - 0.03), color, torso)
		end
		if lower then
			local s = lower.Size
			weldPart(model, "ApronSkirt", Vector3.new(s.X * 0.95, s.Y * 1.6, 0.06), lower.CFrame * CFrame.new(0, -s.Y * 0.4, -s.Z / 2 - 0.03), color, lower)
		end
	end
	local hs = head and head.Size
	if st.key == "sugar" and head then
		weldPart(model, "Bandana", Vector3.new(hs.X * 1.06, hs.Y * 0.32, hs.Z * 1.06), head.CFrame * CFrame.new(0, hs.Y * 0.3, 0), st.color, head)
		weldPart(model, "Mask", Vector3.new(hs.X * 0.62, hs.Y * 0.26, 0.05), head.CFrame * CFrame.new(0, -hs.Y * 0.18, -hs.Z / 2 - 0.02), Color3.fromRGB(235, 240, 245), head)
	elseif st.key == "boil" then
		apron(st.color)
		for _, h in ipairs({ rh, lh }) do
			if h then
				weldPart(model, "OvenMitt", h.Size * 1.35, h.CFrame, Color3.fromRGB(200, 60, 60), h, { Material = Enum.Material.Fabric })
			end
		end
	elseif st.key == "press" and head then
		weldPart(model, "HardHat", Vector3.new(hs.X * 1.1, hs.Y * 0.55, hs.Z * 1.1), head.CFrame * CFrame.new(0, hs.Y * 0.42, 0), st.color, head, { Shape = Enum.PartType.Ball })
		weldPart(model, "HardHatBrim", Vector3.new(hs.X * 1.25, 0.04, hs.Z * 1.25), head.CFrame * CFrame.new(0, hs.Y * 0.3, -hs.Z * 0.08), st.color, head)
	elseif st.key == "inspect" then
		if head then
			weldPart(model, "HygieneCap", Vector3.new(hs.X * 1.08, hs.Y * 0.45, hs.Z * 1.08), head.CFrame * CFrame.new(0, hs.Y * 0.4, 0), st.color, head, { Shape = Enum.PartType.Ball })
		end
		if rh then
			local ring = weldPart(model, "MagnifierRing", Vector3.new(0.05, 0.5, 0.5), rh.CFrame * CFrame.new(0, -0.15, -0.35) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 70, 80), rh, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
			weldPart(model, "MagnifierGlass", Vector3.new(0.03, 0.42, 0.42), ring.CFrame, Color3.fromRGB(200, 230, 255), rh, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.4 })
		end
	elseif st.key == "pack" then
		apron(st.color)
		if rh then
			weldPart(model, "TwistTie", Vector3.new(0.05, 0.05, 0.6), rh.CFrame * CFrame.new(0, -0.1, -0.2), Color3.fromRGB(230, 180, 50), rh, { Material = Enum.Material.Metal })
		end
	end
end

local function countMinimes(plot, lot)
	local n = 0
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("Minime") and not d:IsDescendantOf(lot) then
			n += 1
		end
	end
	return n
end

local staffBusy = {} -- [lot] = true / "again" (Minime.build가 기다리는 동안 또 불리면 끝나고 한 번 더)
local function syncStaff(plot, fac)
	local lot = plot:FindFirstChild("FactoryLot")
	if not lot then
		return
	end
	local folder = lot:FindFirstChild("Staff")
	local b = lot:FindFirstChild("Building")
	local owner = fac and Players:GetPlayerByUserId(fac:GetAttribute("OwnerUserId") or 0)
	if not (b and owner and fac:GetAttribute("Unlocked")) then
		if folder then
			folder:Destroy()
		end
		return
	end
	if staffBusy[lot] then
		staffBusy[lot] = "again"
		return
	end
	staffBusy[lot] = true
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Staff"
		folder.Parent = lot
	end
	local pv = b:GetPivot()
	local floorY = pv.Position.Y
	local fl = b:FindFirstChild("Factory_Floor_Node", true)
	if fl and fl:IsA("BasePart") then
		floorY = fl.Position.Y + fl.Size.Y / 2
	end
	local others = countMinimes(plot, lot)
	for _, st in ipairs(STATIONS) do
		local name = "Staff_" .. st.key
		local have = folder:FindFirstChild(name)
		local want = fac:GetAttribute("Staff_" .. st.key) == true
		if want and not have then
			if others + #folder:GetChildren() < MAX_MINIME then -- 폰 성능: 한 가게 미니미 8명까지
				local spot = pv * CFrame.new(st.x, 0, STAND_Z)
				local pos = Vector3.new(spot.Position.X, floorY, spot.Position.Z)
				local facing = pv:VectorToWorldSpace(Vector3.new(0, 0, 1)) -- 라인(모델 +Z) 쪽을 봄
				-- 새 기계(cozy_factory.py)는 공정마다 자리 표시 Fac_Stand_<key>가 있음: 그 바닥 가운데에 서서 기계 안쪽(-LookVector)을 봄
				local mark = b:FindFirstChild("Fac_Stand_" .. st.key, true)
				if mark and not mark:IsA("BasePart") then
					mark = mark:FindFirstChildWhichIsA("BasePart", true)
				end
				if mark then
					pos = mark.Position - Vector3.new(0, mark.Size.Y / 2, 0)
					local f = -mark.CFrame.LookVector
					facing = Vector3.new(f.X, 0, f.Z).Unit
				end
				local ok, m = pcall(Minime.build, owner, folder, CFrame.lookAt(pos, pos + facing), st.n, 0)
				if ok and m then
					m.Name = name
					m:SetAttribute("StaffKey", st.key)
					m:SetAttribute("StationName", st.name) -- 클라이언트가 머리 위 글에 "· 일하는 중"을 붙일 때 씀
					m:SetAttribute("HelperIndex", nil)
					for _, n in ipairs({ "Apron", "ApronSkirt", "HandLadle" }) do
						local x = m:FindFirstChild(n)
						if x then
							x:Destroy()
						end
					end
					dress(m, st)
					-- 머리 위 표: 공정 번호(색) + 공정 이름 (일하는 중/쉬는 중은 클라이언트가 붙임)
					local bb = m:FindFirstChild("Status", true)
					if bb then
						local num = bb:FindFirstChild("Number")
						if num then
							num.Text = tostring(st.n)
							num.BackgroundColor3 = st.color
							num.TextColor3 = st.key == "sugar" and Color3.fromRGB(92, 58, 36) or Color3.new(1, 1, 1)
						end
						local t = bb:FindFirstChild("TextLabel")
						if t then
							t.Text = st.name
						end
					end
				end
			end
		elseif not want and have then
			have:Destroy()
		end
	end
	local again = staffBusy[lot] == "again"
	staffBusy[lot] = nil
	if again then
		task.defer(syncStaff, plot, fac)
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
	task.spawn(syncStaff, plot, fac)
end

function Display.init()
	layout = factoryLayout()
	if layout then
		print("[Factory] 편집 화면에서 고친 공장(FactoryLayout)을 씀")
	end
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
			-- 공정 알바생 고용·해고, 주인이 바뀜 → 알바생만 다시 맞춤
			for _, st in ipairs(STATIONS) do
				fac:GetAttributeChangedSignal("Staff_" .. st.key):Connect(function()
					local p = i and plots:FindFirstChild("Plot" .. i)
					if p then
						task.spawn(syncStaff, p, fac)
					end
				end)
			end
			fac:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				local p = i and plots:FindFirstChild("Plot" .. i)
				if p then
					task.spawn(syncStaff, p, fac)
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
