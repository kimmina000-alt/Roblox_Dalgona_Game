-- 가게 부지 6칸 (Phase 2, 2026-11-20)
-- 들어오면 빈 부지 하나를 배정하고, 나가면 돌려받는다. 부지마다:
--  - 이름 간판 (앞, 골목 쪽)
--  - 손 작업대 자리 (D10: 끝까지 남음)
--  - 기계 1자리 (D10: 설비 2~4단계를 여기서 교체)
--  - 가게 뒤 공장 문 자리 (D11: 지금은 문만, 누르면 "준비 중")
-- 손 작업대 (17b, 2026-11-21): 부지를 배정하면 그 부지의 작업대 자리에 WorkstationBuilder로 작업대를 만들고
-- StallDecor 꾸미기(1단계·PackArea)를 붙인다. 반환하면 치운다. 두 세션이 같이 쓰는 규칙:
--   모델 = 부지 안 "Workstation", 속성 OwnerUserId = 주인, 연탄 CoalLeft는 작업대마다 따로.
-- 스폰 앞 공용 DalgonaWorkstation은 그대로 둔다 (사용자 결정 대기). 수치·위치는 GrowthConfig.Plots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local P = G.Plots
local WorkstationBuilder = require(script.Parent:WaitForChild("WorkstationBuilder"))
local StallDecor = require(script.Parent:WaitForChild("StallDecor"))

local PlotService = {}

local plots = {} -- [i] = { model, owner, cframe, signLabel }
local byPlayer = {} -- [player] = i
local notify = nil -- function(player, text)

local WOOD = Color3.fromRGB(176, 124, 80)
local DARK_WOOD = Color3.fromRGB(110, 72, 44)
local FLOOR = Color3.fromRGB(226, 208, 176)
local EMPTY_TEXT = "빈 가게"

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function spotLabel(parent, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.5
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(90, 60, 40)
	t.TextTransparency = 0.25
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = t
	t.Parent = gui
	gui.Parent = parent
end

-- 바닥에 그린 자리 표시 (밟고 지나갈 수 있음)
local function spot(m, name, cf, size, color, text)
	-- Top 면 글씨는 부품의 Z축을 따라 써진다: 90° 돌리고 X·Z 크기를 바꿔서 골목(앞) 쪽에서 가로로 읽히게
	local p = part(m, name, Vector3.new(size.Z, size.Y, size.X), cf * CFrame.new(0, size.Y / 2 + P.size.Y, 0) * CFrame.Angles(0, math.pi * 0.5, 0), color, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		Transparency = 0.35,
	})
	spotLabel(p, text)
	return p
end

---------------------------------------------------------------- 편집 화면에서 고친 부지 모양 (2026-11-22 사용자 "부지 수정할 수 있게")
-- Studio 편집 모드 Workspace.PlotLayout(부지 하나, 속성 PlotCFrame = 그 부지의 기준 CFrame)을 틀로 씀.
-- 서버는 지금처럼 코드로 6칸을 만든 뒤, 부품마다 붙인 속성 LayoutKey(경로#번째)로 틀의 같은 부품을 찾아
-- 위치(부지 기준)·크기·색·재질·투명도를 6칸 모두에 옮김. 틀에서 지운 부품은 지우고(꼭 필요한 부품은 숨김),
-- 틀에 새로 넣은 부품(LayoutKey 없음)은 6칸 모두에 복제. 진열대·작업대·공장 부지·기계는 다른 코드가 붙여서 틀 밖.

local KEEP_ALWAYS = { HandStationSpot = true, HandStationInside = true, Floor = true, Entry = true, Sign = true, Shutter = true, Header = true, RentPaper = true, MachineSlot = true, Door = true }
local layoutTemplate = nil -- { model, cf }

local Layout = require(script.Parent:WaitForChild("LayoutTemplate"))
-- 나중에 다른 코드가 붙이는 묶음 중 틀로 고칠 수 있는 것 (틀 PlotLayout 안 같은 이름 자식, PlotService.applyChild로 옮김)
local CHILD_LAYOUTS = { DisplayShelf = true }

local function keepPart(d)
	return KEEP_ALWAYS[d.Name] or d.Name:match("^Slot%d+$") ~= nil
end

local function findLayoutTemplate()
	local src = workspace:FindFirstChild("PlotLayout")
	if src then
		-- 게임에서는 보이지 않게 ServerStorage로 옮겨 둠 (편집 모드의 원본은 그대로)
		local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
		src.Parent = assets or game:GetService("ServerStorage")
	else
		local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
		src = assets and assets:FindFirstChild("PlotLayout")
	end
	local cf = src and src:GetAttribute("PlotCFrame")
	if src and typeof(cf) == "CFrame" then
		return { model = src, cf = cf }
	end
	return nil
end

-- 틀(templateCF 기준)의 모양을 부지 plotCF로 옮김 (나중에 붙는 묶음 CHILD_LAYOUTS는 빼고)
local function applyLayout(m, plotCF)
	local T = layoutTemplate
	if not T then
		return
	end
	Layout.apply(m, T.model, T.cf, plotCF, {
		keep = keepPart,
		skip = function(tp)
			local a = tp
			while a.Parent and a.Parent ~= T.model do
				a = a.Parent
			end
			return CHILD_LAYOUTS[a.Name] == true
		end,
	})
end

-- 다른 코드가 부지에 붙인 묶음(child, 예: 진열대 DisplayShelf)을 틀의 같은 이름 자식 모양으로. 부지 Parent 전에 불러도 됨
function PlotService.applyChild(plotModel, child)
	Layout.tag(plotModel, child)
	local T = layoutTemplate
	local tc = T and T.model:FindFirstChild(child.Name)
	local cf = plotModel:GetAttribute("PlotCFrame")
	if tc and typeof(cf) == "CFrame" then
		Layout.apply(child, tc, T.cf, cf, { keep = keepPart })
	end
end

local function buildPlot(index, parent)
	local cf
	local slot = P.slots and P.slots[index]
	if slot then
		-- 마주 보는 두 줄 (2026-11-23): 남쪽 줄은 앞이 +Z, 북쪽 줄은 앞이 -Z. 가게 안 모든 것은 이 CFrame 기준
		if slot[2] == "N" then
			cf = CFrame.new(slot[1] * P.spacing, 0, P.rowZNorth)
		else
			cf = CFrame.new(slot[1] * P.spacing, 0, P.rowZ) * CFrame.Angles(0, math.pi, 0)
		end
	else
		local x = (index - (P.count + 1) / 2) * P.spacing
		cf = CFrame.new(x, 0, P.rowZ) * CFrame.Angles(0, math.pi, 0) -- 로컬 -Z(앞) = 월드 +Z (스폰 쪽)
	end
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m:SetAttribute("PlotIndex", index)
	m:SetAttribute("OwnerUserId", 0)

	local floor = part(m, "Floor", P.size, cf * CFrame.new(0, P.size.Y / 2, 0), FLOOR, Enum.Material.WoodPlanks)
	m.PrimaryPart = floor
	-- 낮은 울타리 (앞은 입구로 비움)
	local half = P.size.X / 2
	for _, side in ipairs({ -1, 1 }) do
		part(m, "Fence", Vector3.new(0.4, 1.6, P.size.Z), cf * CFrame.new(side * (half - 0.2), P.size.Y + 0.8, 0), DARK_WOOD, Enum.Material.Wood)
	end
	-- 뒤 울타리: 가운데 공장 뒷문 앞은 비움 (D11 2026-11-22: 공장은 가게 뒤에 붙고 뒷문으로 걸어 들어감)
	local gap = P.factoryDoor.gap
	local backW = (P.size.X - gap) / 2
	for _, side in ipairs({ -1, 1 }) do
		part(m, "Fence", Vector3.new(backW, 1.6, 0.4), cf * CFrame.new(side * (gap / 2 + backW / 2), P.size.Y + 0.8, half - 0.2), DARK_WOOD, Enum.Material.Wood)
	end

	-- 손 작업대 자리 (D10)
	local hs = spot(m, "HandStationSpot", cf * CFrame.new(P.handStation.pos), P.handStation.size, Color3.fromRGB(255, 214, 150), "손 작업대 자리")
	hs:SetAttribute("Spot", "HandStation")
	-- 월세를 내고 가게가 열리면 작업대가 옮겨 가는 가게 안 자리 (2026-11-22 사용자: "시작할 때는 밖, 월세 사면 안"). 게임에서는 안 보임
	local hi = spot(m, "HandStationInside", cf * CFrame.new(P.handStation.pos), P.handStation.size, Color3.fromRGB(255, 190, 120), "손 작업대 자리 (월세 낸 뒤)")
	hi:SetAttribute("Spot", "HandStationInside")
	-- 기계 1자리 (D10)
	local ms = spot(m, "MachineSlot", cf * CFrame.new(P.machineSlot.pos), P.machineSlot.size, Color3.fromRGB(170, 210, 255), "기계 자리")
	ms:SetAttribute("Spot", "Machine")
	ms:SetAttribute("Stage", 1)

	-- 가게 뒤 공장 문 (D11, 자리만): 문틀 + 닫힌 문 + "준비 중" 안내
	local dcf = cf * CFrame.new(P.factoryDoor.pos)
	local door = Instance.new("Model")
	door.Name = "FactoryDoor"
	door.Parent = m
	part(door, "Frame", Vector3.new(0.6, 9, 0.8), dcf * CFrame.new(-3.3, P.size.Y + 4.5, 0), DARK_WOOD, Enum.Material.Wood)
	part(door, "Frame", Vector3.new(0.6, 9, 0.8), dcf * CFrame.new(3.3, P.size.Y + 4.5, 0), DARK_WOOD, Enum.Material.Wood)
	part(door, "Frame", Vector3.new(7.2, 0.6, 0.8), dcf * CFrame.new(0, P.size.Y + 9.3, 0), DARK_WOOD, Enum.Material.Wood)
	local panel = part(door, "Door", Vector3.new(6, 8.6, 0.3), dcf * CFrame.new(0, P.size.Y + 4.3, 0), Color3.fromRGB(150, 160, 170), Enum.Material.DiamondPlate)
	panel:SetAttribute("Spot", "FactoryDoor")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FactoryPrompt"
	prompt.ActionText = "공장 들어가기"
	prompt.ObjectText = "달고나 공장"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	prompt.Triggered:Connect(function(player)
		-- 내 가게 문만 (D11: 남의 공장에는 못 들어감). 들어가기는 FactoryService가 PlotService.onFactoryDoor로 연결
		if m:GetAttribute("OwnerUserId") ~= player.UserId then
			if notify then
				notify(player, "다른 사람의 공장이에요")
			end
			return
		end
		if PlotService.onFactoryDoor then
			PlotService.onFactoryDoor(player)
		elseif notify then
			notify(player, "공장은 나중에 열려요")
		end
	end)

	-- 이름 간판 (앞, 골목 쪽을 봄)
	local scf = cf * CFrame.new(P.sign.pos)
	for _, sx in ipairs({ -7, 7 }) do
		part(m, "SignPost", Vector3.new(0.5, P.sign.height, 0.5), scf * CFrame.new(sx, P.size.Y + P.sign.height / 2, 0), DARK_WOOD, Enum.Material.Wood)
	end
	local board = part(m, "Sign", Vector3.new(15, 3, 0.4), scf * CFrame.new(0, P.size.Y + P.sign.height - 1.2, 0), WOOD, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- 로컬 -Z 면 = 골목 쪽
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 246, 225)
	label.TextStrokeTransparency = 0.4
	label.Text = EMPTY_TEXT
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = board

	-- 가게 건물 (D21): 작업대 뒤, 앞면 셔터. 노점일 때는 셔터를 내리고 "임대 문의" 종이
	local B = P.building
	local bm = Instance.new("Model")
	bm.Name = "ShopBuilding"
	bm.Parent = m
	local wallColor = Color3.fromRGB(214, 178, 150)
	local depth = B.back - B.front
	local midZ = (B.front + B.back) / 2
	local base = P.size.Y
	part(bm, "WallL", Vector3.new(0.6, B.height, depth), cf * CFrame.new(-B.halfWidth, base + B.height / 2, midZ), wallColor, Enum.Material.Brick)
	part(bm, "WallR", Vector3.new(0.6, B.height, depth), cf * CFrame.new(B.halfWidth, base + B.height / 2, midZ), wallColor, Enum.Material.Brick)
	-- 뒷벽은 공장 문 자리를 비워 둠
	local doorHalf = 3.7
	local sideW = B.halfWidth - doorHalf
	part(bm, "WallBack", Vector3.new(sideW, B.height, 0.6), cf * CFrame.new(-(doorHalf + sideW / 2), base + B.height / 2, B.back), wallColor, Enum.Material.Brick)
	part(bm, "WallBack", Vector3.new(sideW, B.height, 0.6), cf * CFrame.new(doorHalf + sideW / 2, base + B.height / 2, B.back), wallColor, Enum.Material.Brick)
	part(bm, "WallBack", Vector3.new(doorHalf * 2, B.height - 9.6, 0.6), cf * CFrame.new(0, base + 9.6 + (B.height - 9.6) / 2, B.back), wallColor, Enum.Material.Brick)
	part(bm, "Roof", Vector3.new(B.halfWidth * 2 + 1.6, 0.6, depth + 2.4), cf * CFrame.new(0, base + B.height + 0.3, midZ - 0.6), Color3.fromRGB(150, 90, 80), Enum.Material.SmoothPlastic)
	local header = part(bm, "Header", Vector3.new(B.halfWidth * 2, 1.4, 0.6), cf * CFrame.new(0, base + B.height - 0.7, B.front), Color3.fromRGB(120, 76, 50), Enum.Material.Wood)
	local hgui = Instance.new("SurfaceGui")
	hgui.Face = Enum.NormalId.Front
	hgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	hgui.PixelsPerStud = 30
	local htext = Instance.new("TextLabel")
	htext.Name = "Text"
	htext.Size = UDim2.fromScale(1, 1)
	htext.BackgroundTransparency = 1
	htext.Font = Enum.Font.GothamBlack
	htext.TextScaled = true
	htext.TextColor3 = Color3.fromRGB(255, 240, 210)
	htext.Text = "달고나"
	htext.Parent = hgui
	hgui.Parent = header
	-- 셔터 (내림: 입구를 덮음 / 올림: 윗부분에 말려 있음)
	local openH = B.height - 1.4
	local shutter = part(bm, "Shutter", Vector3.new(B.halfWidth * 2 - 0.8, openH, 0.25), cf * CFrame.new(0, base + openH / 2, B.front - 0.1), Color3.fromRGB(190, 196, 204), Enum.Material.DiamondPlate)
	shutter:SetAttribute("DownCF", shutter.CFrame)
	shutter:SetAttribute("UpCF", cf * CFrame.new(0, base + openH - 0.6, B.front - 0.1))
	-- "임대 문의" 종이
	local paper = part(bm, "RentPaper", Vector3.new(3.2, 2.2, 0.05), cf * CFrame.new(2.5, base + 4.2, B.front - 0.3), Color3.fromRGB(252, 250, 240), Enum.Material.SmoothPlastic)
	local pgui = Instance.new("SurfaceGui")
	pgui.Face = Enum.NormalId.Front
	pgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	pgui.PixelsPerStud = 60
	local ptext = Instance.new("TextLabel")
	ptext.Name = "Text"
	ptext.Size = UDim2.fromScale(1, 1)
	ptext.BackgroundTransparency = 1
	ptext.Font = Enum.Font.GothamBlack
	ptext.TextScaled = true
	ptext.TextColor3 = Color3.fromRGB(200, 40, 40)
	ptext.Text = "임대 문의"
	ptext.Parent = pgui
	pgui.Parent = paper

	-- 노점 파라솔 (작업대 위)
	local PS = P.parasol
	local pcf = cf * CFrame.new(PS.pos)
	part(m, "ParasolPole", Vector3.new(0.3, PS.height, 0.3), pcf * CFrame.new(0, base + PS.height / 2, 0), Color3.fromRGB(240, 240, 240), Enum.Material.Metal)
	local canopy = part(m, "ParasolCanopy", Vector3.new(0.5, PS.radius * 2, PS.radius * 2), pcf * CFrame.new(0, base + PS.height, -PS.radius * 0.55) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 120), Enum.Material.Fabric)
	canopy.Shape = Enum.PartType.Cylinder

	-- 들어오는 자리 (스폰을 부지로 옮길 때 씀)
	part(m, "Entry", Vector3.new(4, 0.2, 4), cf * CFrame.new(P.entry or Vector3.new(0, 0, -12)) * CFrame.new(0, P.size.Y + 0.1, 0), FLOOR, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
	})

	Layout.tag(m)
	applyLayout(m, cf)
	m:SetAttribute("PlotCFrame", cf)
	-- 셔터: 편집 화면에서 옮긴 자리(내린 모습)를 기준으로 올림·내림 자리를 다시 계산 (2026-11-22 사용자 "철문 위치 옮겼으니 함께 이동")
	local sh = m:FindFirstChild("ShopBuilding") and m.ShopBuilding:FindFirstChild("Shutter")
	if sh then
		sh:SetAttribute("DownCF", sh.CFrame)
		sh:SetAttribute("ClosedH", sh.Size.Y)
		sh:SetAttribute("UpCF", sh.CFrame * CFrame.new(0, sh.Size.Y / 2 - 0.6, 0))
	end
	hi.Transparency = 1
	for _, c in ipairs(hi:GetChildren()) do
		if c:IsA("SurfaceGui") then
			c.Enabled = false
		end
	end
	m.Parent = parent
	return { model = m, owner = nil, cframe = cf, signLabel = label }
end

---------------------------------------------------------------- 손 작업대

-- 바닥 높이(Y)로 저장된 속성: 작업대를 올리면 같이 올려야 함 (WorkstationBuilder·StallDecor가 씀)
local Y_ATTRS = { "GrillTopY", "BottomY", "TopY" }
-- 틀: 꾸며진 작업대(ServerStorage.Assets.WorkstationTemplate, 없으면 공용 DalgonaWorkstation)를 서버 시작 때 복제해 둠.
-- WorkstationBuilder.build는 실행 중에 국자 광택 텍스처(SurfaceAppearance)를 못 써서 실패하므로 복제해 씀.
local template = nil

-- 작업대를 지금 가게 상태에 맞는 자리 표시로 옮김 (노점·월세 밀림 = 밖 HandStationSpot, 열림 = 안 HandStationInside).
-- 높이 속성(Y_ATTRS)·알바생 국자 자리(Center)·알바생 미니미(Helper<n>)도 같이 옮김
local function placeWorkstation(i, first)
	local plot = plots[i]
	local ws = plot and plot.model:FindFirstChild("Workstation")
	local rel = ws and ws:GetAttribute("SpotRel")
	if typeof(rel) ~= "CFrame" then
		return
	end
	local state = plot.model:GetAttribute("ShopState")
	local open = state == "owned" or (state == "rented" and not plot.model:GetAttribute("ShopClosed"))
	local spotPart = (open and plot.model:FindFirstChild("HandStationInside")) or plot.model:FindFirstChild("HandStationSpot")
	if not spotPart then
		return
	end
	local target = CFrame.new(spotPart.Position - spotPart.CFrame.UpVector * (spotPart.Size.Y / 2)) * spotPart.CFrame.Rotation
	-- 내 화면 크기 줄이기(클라이언트 Making/ViewScale)가 쓰는 값: 가게 안 자리인지, 작업대 바닥 가운데(원래 크기 기준)
	ws:SetAttribute("AtInside", open and spotPart.Name == "HandStationInside")
	ws:SetAttribute("ViewOrigin", target.Position)
	local old = ws:GetPivot()
	local new = target * rel
	if (new.Position - old.Position).Magnitude < 1e-3 and new.LookVector:Dot(old.LookVector) > 0.99999 then
		return
	end
	local delta = new * old:Inverse()
	local dy = new.Y - old.Y
	ws:PivotTo(new)
	for _, d in ipairs(ws:GetDescendants()) do
		for _, name in ipairs(Y_ATTRS) do
			local v = d:GetAttribute(name)
			if type(v) == "number" then
				d:SetAttribute(name, v + dy)
			end
		end
		local ctr = d:GetAttribute("Center")
		if typeof(ctr) == "Vector3" then
			d:SetAttribute("Center", delta * ctr)
		end
	end
	for _, h in ipairs(first and {} or plot.model:GetChildren()) do
		if h:IsA("Model") and h.Name:match("^Helper%d+$") then
			h:PivotTo(delta * h:GetPivot())
		end
	end
end

local function buildWorkstation(i, player)
	local plot = plots[i]
	local old = plot.model:FindFirstChild("Workstation")
	if old then
		old:Destroy()
	end
	local ok, ws = pcall(function()
		-- 원래 자리(공용 작업대와 같은 좌표)의 복제를 옮김. 틀이 없으면(공용 작업대가 없을 때) 새로 만듦
		local w
		if template then
			w = template:Clone()
			w.Name = "Workstation"
			w:SetAttribute("OwnerUserId", player.UserId)
			w:SetAttribute("PlotIndex", i)
			w.Parent = plot.model
			StallDecor.watchOwners(w) -- 식탁보: 이 가게 주인 것만
		else
			w = WorkstationBuilder.build(plot.model)
			w.Name = "Workstation"
			w:SetAttribute("OwnerUserId", player.UserId)
			w:SetAttribute("PlotIndex", i)
			StallDecor.dress(w)
		end
		return w
	end)
	if not ok then
		warn("[Plot] workstation build failed", ws)
		return nil
	end
	-- 장식용 계단 진열대는 뺌 (진짜 진열대가 옆에 있음, 2026-11-21)
	if P.removeDecorDisplay then
		local decor = ws:FindFirstChild("Stage1Decor")
		if decor then
			for _, d in ipairs(decor:GetDescendants()) do
				if d:IsA("BasePart") and d.Name:sub(1, 4) == "Show" then
					d:Destroy()
				end
			end
		end
	end
	-- 180° 돌림: 주인이 작업대 뒤(건물 쪽)에서 간판을 보고 만듦, 간판에서 보면 화로가 오른쪽 (2026-11-21)
	if (P.workstationTurn or 0) ~= 0 then
		ws:PivotTo(ws:GetPivot() * CFrame.Angles(0, math.rad(P.workstationTurn), 0))
	end
	-- 꾸미기까지 포함한 크기(러그 빼고)의 가운데를 자리 표시 가운데에 맞춤 (2026-11-22 사용자가 편집 화면에서 자리를 옮김).
	-- 노점이면 HandStationSpot(가게 밖), 월세를 내고 열면 HandStationInside(가게 안): placeWorkstation
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(ws:GetDescendants()) do
		if d:IsA("BasePart") and not d:FindFirstAncestor("Rug") then
			mn = mn:Min(d.Position - d.Size / 2)
			mx = mx:Max(d.Position + d.Size / 2)
		end
	end
	local c = (mn + mx) / 2
	-- 틀 바닥 = y 0, 방향 = 자리 표시 기본 방향(부지 방향에서 90° 돈 것)
	local f0 = CFrame.new(c.X, 0, c.Z) * plot.cframe.Rotation * CFrame.Angles(0, math.pi * 0.5, 0)
	ws:SetAttribute("SpotRel", f0:ToObjectSpace(ws:GetPivot()))
	placeWorkstation(i, true) -- 처음 놓기 (알바생 미니미는 아직 없음)
	WorkstationBuilder.setCoal(ws, 1) -- 연탄은 작업대마다 (CoalLeft)
	WorkstationBuilder.watchLadles(ws) -- 국자 자리(Center 속성)를 옮긴 뒤 계산
	-- 바닥 표시는 숨김 (진짜 작업대가 있음)
	local spot = plot.model:FindFirstChild("HandStationSpot")
	if spot then
		spot.Transparency = 1
		for _, c in ipairs(spot:GetChildren()) do
			if c:IsA("SurfaceGui") then
				c.Enabled = false
			end
		end
	end
	return ws
end

local function clearWorkstation(i)
	local plot = plots[i]
	local ws = plot.model:FindFirstChild("Workstation")
	if ws then
		ws:Destroy()
	end
	local spot = plot.model:FindFirstChild("HandStationSpot")
	if spot then
		spot.Transparency = 0.35
		for _, c in ipairs(spot:GetChildren()) do
			if c:IsA("SurfaceGui") then
				c.Enabled = true
			end
		end
	end
end

-- 가게 모습 (D21): state = "stall" | "rented" | "owned", closed = 월세 밀림
function PlotService.setShopState(i, state, closed, ownerName)
	local plot = plots[i]
	if not plot then
		return
	end
	local bm = plot.model:FindFirstChild("ShopBuilding")
	if not bm then
		return
	end
	local open = state == "owned" or (state == "rented" and not closed)
	local shutter = bm:FindFirstChild("Shutter")
	if shutter then
		local target = shutter:GetAttribute(open and "UpCF" or "DownCF")
		if target then
			shutter.CFrame = target
		end
		shutter.Size = Vector3.new(shutter.Size.X, open and 1.2 or (shutter:GetAttribute("ClosedH") or (P.building.height - 1.4)), shutter.Size.Z)
	end
	local paper = bm:FindFirstChild("RentPaper")
	if paper then
		local text = state == "stall" and "임대 문의" or (closed and "월세 밀림" or nil)
		paper.Transparency = text and 0 or 1
		paper.SurfaceGui.Enabled = text ~= nil
		if text then
			paper.SurfaceGui.Text.Text = text
		end
	end
	local header = bm:FindFirstChild("Header")
	if header then
		header.SurfaceGui.Text.Text = state == "owned" and "내 가게" or (state == "rented" and "달고나 가게" or "임대")
	end
	plot.model:SetAttribute("ShopState", state)
	plot.model:SetAttribute("ShopClosed", closed == true)
	placeWorkstation(i) -- 월세를 내면 가게 안으로, 노점·월세 밀림이면 밖으로
	if ownerName then
		plot.signLabel.Text = ownerName .. (state == "stall" and "의 달고나 노점" or "의 달고나 가게")
	end
end

local function setOwner(i, player)
	local plot = plots[i]
	plot.owner = player
	plot.model:SetAttribute("OwnerUserId", player and player.UserId or 0)
	plot.model:SetAttribute("OwnerName", player and player.DisplayName or "")
	plot.signLabel.Text = player and (player.DisplayName .. "의 달고나 가게") or EMPTY_TEXT
end

local function teleport(player, i)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local entry = plots[i] and plots[i].model:FindFirstChild("Entry")
	if root and entry then
		char:PivotTo(CFrame.lookAt(entry.Position + Vector3.new(0, 3, 0), entry.Position + Vector3.new(0, 3, 0) + (entry.Position - plots[i].model.Floor.Position).Unit * -1))
	end
end

-- 빈 부지 배정 (이미 있으면 그 번호). 꽉 차면 nil
function PlotService.assign(player)
	if byPlayer[player] then
		return byPlayer[player]
	end
	for i, plot in ipairs(plots) do
		if not plot.owner then
			byPlayer[player] = i
			setOwner(i, player)
			if typeof(player) == "Instance" then
				player:SetAttribute("PlotIndex", i)
				if P.buildWorkstation then
					buildWorkstation(i, player)
				end
			end
			print(string.format("[Plot] %s -> Plot%d", player.Name, i))
			return i
		end
	end
	warn("[Plot] no free plot for", player.Name)
	return nil
end

function PlotService.release(player)
	local i = byPlayer[player]
	if not i then
		return
	end
	byPlayer[player] = nil
	setOwner(i, nil)
	clearWorkstation(i)
	PlotService.setShopState(i, "stall", false, nil)
	print(string.format("[Plot] %s released Plot%d", player.Name, i))
end

-- 그 플레이어 가게의 손 작업대 (없으면 nil)
function PlotService.workstation(player)
	local i = byPlayer[player]
	return i and plots[i].model:FindFirstChild("Workstation") or nil
end

function PlotService.get(player)
	local i = byPlayer[player]
	return i and plots[i] or nil, i
end

-- 번호로 부지 { model, owner, cframe, signLabel }
function PlotService.plotAt(i)
	return plots[i]
end

function PlotService.init(opts)
	notify = opts and opts.notify
	-- 틀: ServerStorage.Assets.WorkstationTemplate(공용 작업대를 없앤 뒤, U8) → 없으면 스폰 앞 공용 작업대
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local shared = (assets and assets:FindFirstChild("WorkstationTemplate")) or workspace:FindFirstChild("DalgonaWorkstation")
	if shared and P.buildWorkstation then
		template = shared:Clone()
		for _, c in ipairs(template:GetChildren()) do
			if c.Name:sub(1, 11) == "HelperLadle" then
				c:Destroy() -- 알바생 국자는 옮긴 뒤 LadleCount로 다시 만듦
			end
		end
		template:SetAttribute("LadleCount", 1)
	end
	local folder = workspace:FindFirstChild("ShopPlots")
	if folder then
		folder:Destroy() -- 서버가 새로 만든다 (Studio에 남은 것 정리)
	end
	folder = Instance.new("Folder")
	folder.Name = "ShopPlots"
	folder.Parent = workspace
	layoutTemplate = findLayoutTemplate()
	if layoutTemplate then
		print("[Plot] 편집 화면에서 고친 부지 틀(PlotLayout)을 씀")
	end
	for i = 1, P.count do
		plots[i] = buildPlot(i, folder)
	end
	-- 편집 화면에서 가게 틀(PlotLayout) 옆에 놓은 보기용 모델 (2026-11-23 사용자 "1번 가게 옆으로"):
	-- Workspace 바로 아래 Model에 속성 FollowPlot = 가게 번호가 있으면, 틀과의 자리 관계 그대로 그 가게 옆으로 옮김
	if layoutTemplate then
		for _, c in ipairs(workspace:GetChildren()) do
			local n = c:IsA("Model") and c:GetAttribute("FollowPlot")
			if type(n) == "number" and plots[n] then
				c:PivotTo(plots[n].cframe * layoutTemplate.cf:ToObjectSpace(c:GetPivot()))
			end
		end
	end

	local function onAdded(player)
		local i = PlotService.assign(player)
		if i and P.teleportOnSpawn then
			player.CharacterAdded:Connect(function()
				task.wait(0.2)
				teleport(player, i)
			end)
			if player.Character then
				teleport(player, i)
			end
		end
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		onAdded(p)
	end
	Players.PlayerRemoving:Connect(PlotService.release)
end

return PlotService
