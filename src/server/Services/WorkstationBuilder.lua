-- 작업대 1개를 Part로 만든다 (Phase 1 프로토타입, Phase 6에서 Blender 모델로 교체)
-- 연탄 화로 + 철망, 구리 국자, 나무젓가락, 나무 숟가락, 설탕 그릇 2개(흰 / 노란),
-- 소다 통 + 분홍 숟가락, 검은 철판 + 설탕 원, 둥근 누름판(세운 손잡이), 별 철사 틀
-- 클라이언트 스크립트는 아래 이름으로 부품을 찾는다. 이름을 바꾸면 Making/Station.lua도 같이 바꾼다.

local Builder = {}

local ORIGIN = Vector3.new(0, 0, -14)
local TABLE_TOP = 3.5
local HANDLE_YAW = 205 -- 국자 손잡이 방향: 왼쪽 앞 (붓기는 오른쪽 철판 쪽으로 기울임)

local WOOD = Color3.fromRGB(132, 92, 58)
local LIGHT_WOOD = Color3.fromRGB(214, 176, 120)
local COPPER = Color3.fromRGB(190, 110, 60)
local STEEL = Color3.fromRGB(196, 198, 204)

local function at(x, y, z)
	return ORIGIN + Vector3.new(x, y, z)
end

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- 세운 원기둥 (Cylinder의 축은 X라서 Z축으로 90도 돌린다)
local function vcyl(parent, name, d, h, pos, color, material, props)
	local cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	local p = part(parent, name, Vector3.new(h, d, d), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, d, pos, color, material, props)
	local p = part(parent, name, Vector3.new(d, d, d), CFrame.new(pos), color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function buildTable(ws)
	local top = part(ws, "TableTop", Vector3.new(16, 0.6, 5.2), CFrame.new(at(0.5, TABLE_TOP - 0.3, 0)), WOOD, Enum.Material.WoodPlanks, { CanCollide = true })
	for _, x in ipairs({ -7.1, 8.1 }) do
		for _, z in ipairs({ -2.2, 2.2 }) do
			part(ws, "TableLeg", Vector3.new(0.5, TABLE_TOP - 0.6, 0.5), CFrame.new(at(x, (TABLE_TOP - 0.6) / 2, z)), WOOD, Enum.Material.Wood, { CanCollide = true })
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "PromptAtt"
	att.Position = Vector3.new(0, 0.6, 2.6)
	att.Parent = top
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MakePrompt"
	prompt.ActionText = "달고나 만들기"
	prompt.ObjectText = "작업대"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = att
end

local function buildBrazier(ws)
	local m = model(ws, "Brazier")
	local cx = -3.2
	vcyl(m, "Body", 2.5, 1.8, at(cx, TABLE_TOP + 0.9, 0), Color3.fromRGB(168, 96, 62), Enum.Material.Concrete)
	vcyl(m, "Band", 2.6, 0.22, at(cx, TABLE_TOP + 0.55, 0), Color3.fromRGB(60, 58, 56), Enum.Material.Metal)
	vcyl(m, "Band2", 2.6, 0.22, at(cx, TABLE_TOP + 1.55, 0), Color3.fromRGB(60, 58, 56), Enum.Material.Metal)
	local coal = vcyl(m, "Briquette", 1.9, 0.2, at(cx, TABLE_TOP + 1.8, 0), Color3.fromRGB(28, 26, 26), Enum.Material.Slate)
	local holes = { Vector3.new(0, 0, 0) }
	for i = 0, 7 do
		local a = i * math.pi / 4
		table.insert(holes, Vector3.new(math.cos(a) * 0.58, 0, math.sin(a) * 0.58))
	end
	for i, o in ipairs(holes) do
		vcyl(m, "Hole" .. i, 0.24, 0.21, at(cx, TABLE_TOP + 1.8, 0) + o, Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	end
	local grillY = TABLE_TOP + 1.98
	for i = -2, 2 do
		part(m, "Grill", Vector3.new(2.5, 0.06, 0.06), CFrame.new(at(cx, grillY, i * 0.4)), Color3.fromRGB(70, 70, 72), Enum.Material.Metal)
	end
	for _, x in ipairs({ -0.6, 0.6 }) do
		part(m, "Grill", Vector3.new(0.06, 0.06, 2.0), CFrame.new(at(cx + x, grillY, 0)), Color3.fromRGB(70, 70, 72), Enum.Material.Metal)
	end
	m:SetAttribute("GrillTopY", grillY + 0.03)

	local fire = Instance.new("Attachment")
	fire.Name = "FireAtt"
	fire.Position = Vector3.new(0.12, 0, 0) -- 원기둥 축(X)이 위쪽
	fire.Parent = coal
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Flame"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.25, 0.45)
	pe.Rate = 30
	pe.Speed = NumberRange.new(1.2, 2)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Right -- 원기둥 +X = 위
	pe.Parent = fire
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 9
	light.Brightness = 2
	light.Parent = fire
end

local function buildLadle(ws)
	local m = model(ws, "Ladle")
	local center = at(-3.2, TABLE_TOP + 1.98 + 0.03 + 0.6 + 0.225, 0)
	local bowl = vcyl(m, "Bowl", 1.7, 0.45, center, COPPER, Enum.Material.Metal)
	vcyl(m, "Inner", 1.5, 0.02, center + Vector3.new(0, 0.226, 0), Color3.fromRGB(120, 62, 32), Enum.Material.Metal)
	vcyl(m, "Contents", 1.42, 0.05, center + Vector3.new(0, 0.25, 0), Color3.fromRGB(250, 250, 250), Enum.Material.Sand, { Transparency = 1 })
	local base = CFrame.new(center) * CFrame.Angles(0, math.rad(HANDLE_YAW), 0)
	part(m, "Handle", Vector3.new(3.4, 0.12, 0.22), base * CFrame.new(0.85 + 1.6, 0.42, 0) * CFrame.Angles(0, 0, math.rad(14)), COPPER, Enum.Material.Metal)
	part(m, "Grip", Vector3.new(1.1, 0.2, 0.3), base * CFrame.new(0.85 + 3.0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(14)), Color3.fromRGB(80, 50, 30), Enum.Material.Wood)
	m.PrimaryPart = bowl
	Builder.attachLadleMesh(m)
end

-- 사용자가 만든 국자 메시(레퍼런스/dalgona_gukja.glb → ServerStorage.Assets.LadleMesh)가 있으면 그걸 쓴다.
-- 게임 코드는 그대로 투명한 원기둥 "Bowl"(피벗, 크기 = 판정용 그릇)을 기준으로 움직이고, 메시는 Bowl에 맞춰 붙는다.
-- glb 분석: 그릇 지름 = 메시 X 크기, 그릇 중심은 경계 상자 중심에서 길이의 30.5%만큼 끝쪽.
-- Roblox로 가져오면 앞뒤가 뒤집혀서 그릇이 -Z 끝, 손잡이가 +Z 쪽이 된다.
local MESH_BOWL_Z = 0.305
function Builder.attachLadleMesh(m)
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local tpl = assets and assets:FindFirstChild("LadleMesh")
	if not tpl then
		return false
	end
	local bowl = m:FindFirstChild("Bowl")
	local old = m:FindFirstChild("Mesh")
	if old then
		old:Destroy()
	end
	for _, name in ipairs({ "Inner", "Handle", "Grip" }) do
		local p = m:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	bowl.Transparency = 1
	local mesh = tpl:Clone()
	mesh.Name = "Mesh"
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CastShadow = true
	-- glb의 금속(0.95)·광택(거칠기 0.25) 값은 Roblox로 안 넘어온다. 텍스처 없이 쓸 수 있는 것 중 Metal + 밝은 구리색이 가장 가깝다.
	mesh.Color = Color3.fromRGB(196, 116, 58)
	mesh.Material = Enum.Material.Metal
	local scale = bowl.Size.Y / tpl.Size.X -- 그릇 지름을 판정용 원기둥과 같게
	mesh.Size = tpl.Size * scale
	local center = bowl.Position
	local handleDir = (CFrame.Angles(0, math.rad(HANDLE_YAW), 0)).RightVector -- 손잡이 = 왼쪽 앞
	local frame = CFrame.lookAt(center, center - handleDir) -- +Z = 손잡이 쪽
	local rimAboveBowlTop = 0.08 -- 내용물(원기둥 윗면)이 그릇 가장자리보다 조금 아래에 보이게
	local dy = bowl.Size.X / 2 + rimAboveBowlTop - mesh.Size.Y / 2
	mesh.CFrame = frame * CFrame.new(0, dy, mesh.Size.Z * MESH_BOWL_Z)
	mesh.Parent = m
	return true
end

local function buildChopsticks(ws)
	local m = model(ws, "Chopsticks")
	local cf = CFrame.new(at(-1.4, TABLE_TOP + 0.04, 2.0)) * CFrame.Angles(0, math.rad(80), 0)
	local s1 = part(m, "Stick1", Vector3.new(0.07, 0.07, 2.6), cf, LIGHT_WOOD, Enum.Material.Wood)
	part(m, "Stick2", Vector3.new(0.07, 0.07, 2.6), cf * CFrame.new(0.13, 0, 0), LIGHT_WOOD, Enum.Material.Wood)
	m.PrimaryPart = s1
end

local function buildSugarBowl(ws, name, x, sugarColor)
	local m = model(ws, name)
	local pos = at(x, TABLE_TOP + 0.35, 1.3)
	local bowl = vcyl(m, "Bowl", 1.4, 0.7, pos, Color3.fromRGB(238, 238, 242), Enum.Material.SmoothPlastic)
	vcyl(m, "Stripe", 1.42, 0.08, pos + Vector3.new(0, 0.2, 0), Color3.fromRGB(70, 110, 190), Enum.Material.SmoothPlastic)
	vcyl(m, "Sugar", 1.22, 0.05, pos + Vector3.new(0, 0.34, 0), sugarColor, Enum.Material.Sand)
	m.PrimaryPart = bowl
end

local function buildWoodSpoon(ws)
	local m = model(ws, "WoodSpoon")
	local cf = CFrame.new(at(-0.8, TABLE_TOP + 0.75, 1.3))
	local scoop = vcyl(m, "Scoop", 0.62, 0.1, cf.Position, LIGHT_WOOD, Enum.Material.Wood)
	ball(m, "Heap", 0.5, cf.Position + Vector3.new(0, 0.1, 0), Color3.fromRGB(252, 252, 252), Enum.Material.Sand)
	part(m, "Handle", Vector3.new(0.13, 0.07, 1.8), cf * CFrame.new(0, 0.28, 1.15) * CFrame.Angles(math.rad(18), 0, 0), LIGHT_WOOD, Enum.Material.Wood)
	local att = Instance.new("Attachment")
	att.Name = "PourAtt"
	att.Parent = scoop
	m.PrimaryPart = scoop
end

local function buildSoda(ws)
	local tub = model(ws, "SodaTub")
	local pos = at(-1.0, TABLE_TOP + 0.3, -1.5)
	local b = vcyl(tub, "Tub", 0.95, 0.6, pos, Color3.fromRGB(245, 225, 150), Enum.Material.SmoothPlastic)
	vcyl(tub, "Soda", 0.82, 0.04, pos + Vector3.new(0, 0.3, 0), Color3.fromRGB(250, 250, 250), Enum.Material.Sand)
	tub.PrimaryPart = b

	local m = model(ws, "SodaSpoon")
	local pink = Color3.fromRGB(255, 120, 170)
	local cf = CFrame.new(pos + Vector3.new(0, 0.36, 0))
	local scoop = vcyl(m, "Scoop", 0.42, 0.08, cf.Position, pink, Enum.Material.SmoothPlastic)
	ball(m, "Heap", 0.3, cf.Position + Vector3.new(0, 0.07, 0), Color3.fromRGB(250, 250, 250), Enum.Material.Sand)
	part(m, "Handle", Vector3.new(0.11, 0.06, 1.3), cf * CFrame.new(0.55, 0.15, 0.55) * CFrame.Angles(math.rad(12), math.rad(45), 0), pink, Enum.Material.SmoothPlastic)
	local att = Instance.new("Attachment")
	att.Name = "PourAtt"
	att.Parent = scoop
	m.PrimaryPart = scoop
end

local function buildPlate(ws)
	local plate = part(ws, "IronPlate", Vector3.new(4.2, 0.15, 4.2), CFrame.new(at(3.6, TABLE_TOP + 0.075, 0)), Color3.fromRGB(32, 32, 34), Enum.Material.Metal)
	plate:SetAttribute("TopY", TABLE_TOP + 0.15)
	vcyl(ws, "SugarRing", 2.9, 0.02, at(3.6, TABLE_TOP + 0.16, 0), Color3.fromRGB(246, 244, 238), Enum.Material.Sand, { Transparency = 0.05 })
	vcyl(ws, "SugarRingInner", 2.3, 0.022, at(3.6, TABLE_TOP + 0.16, 0), Color3.fromRGB(226, 222, 214), Enum.Material.Sand, { Transparency = 0.3 })
end

local function buildPresser(ws)
	local m = model(ws, "Presser")
	local pos = at(7.1, TABLE_TOP + 0.06, -1.1)
	local disc = vcyl(m, "Disc", 2.2, 0.1, pos, STEEL, Enum.Material.Metal, { Reflectance = 0.15 })
	vcyl(m, "Handle", 0.32, 1.0, pos + Vector3.new(0, 0.55, 0), LIGHT_WOOD, Enum.Material.Wood)
	ball(m, "Knob", 0.5, pos + Vector3.new(0, 1.1, 0), LIGHT_WOOD, Enum.Material.Wood)
	m.PrimaryPart = disc
end

local function buildStarCutter(ws)
	local m = model(ws, "StarCutter")
	local center = at(7.1, TABLE_TOP + 0.14, 1.4)
	local root = part(m, "Root", Vector3.new(0.1, 0.1, 0.1), CFrame.new(center), STEEL, Enum.Material.Metal, { Transparency = 1 })
	local outer, inner = 0.8, 0.36
	local pts = {}
	for k = 0, 9 do
		local a = math.rad(-90 + k * 36)
		local r = (k % 2 == 0) and outer or inner
		pts[k + 1] = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	for k = 1, 10 do
		local a, b = pts[k], pts[k % 10 + 1]
		local len = (b - a).Magnitude
		local seg = part(m, "Wire", Vector3.new(0.06, 0.28, len + 0.04), CFrame.lookAt((a + b) / 2, b), STEEL, Enum.Material.Metal)
		seg:SetAttribute("Outline", true)
	end
	part(m, "Bar", Vector3.new(0.07, 0.07, 1.25), CFrame.new(center + Vector3.new(0, 0.42, 0)), STEEL, Enum.Material.Metal)
	part(m, "Post", Vector3.new(0.07, 0.3, 0.07), CFrame.new(center + Vector3.new(0, 0.27, 0)), STEEL, Enum.Material.Metal)
	m.PrimaryPart = root
end

function Builder.build(parent)
	local ws = Instance.new("Model")
	ws.Name = "DalgonaWorkstation"
	buildTable(ws)
	buildBrazier(ws)
	buildLadle(ws)
	buildChopsticks(ws)
	buildSugarBowl(ws, "SugarBowlWhite", -0.8, Color3.fromRGB(252, 252, 252))
	buildSugarBowl(ws, "SugarBowlBrown", 0.8, Color3.fromRGB(214, 168, 92))
	buildWoodSpoon(ws)
	buildSoda(ws)
	buildPlate(ws)
	buildPresser(ws)
	buildStarCutter(ws)
	ws.WorldPivot = CFrame.new(ORIGIN)
	ws.Parent = parent or workspace
	return ws
end

return Builder
