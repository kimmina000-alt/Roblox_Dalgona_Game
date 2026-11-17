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
-- 금속 광택 텍스처 (금속도 0.95 · 거칠기 0.25, 사용자 승인 후 올림)
local METALNESS_MAP = "rbxassetid://75555295293901"
local ROUGHNESS_MAP = "rbxassetid://116334782975968"

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

-- 예전 Part 화로 (메시 에셋이 없을 때)
local function buildBrazierParts(ws)
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

-- 사용자가 만든 화로·연탄 메시(레퍼런스/dalgona_wharo.glb → ServerStorage.Assets)
-- glb 분석: 연탄과 연탄2(다 탄 연탄)는 바닥 높이가 같고, 연탄 바닥은 화로 바닥에서 화로 높이의 8.3% 위.
local COAL_BOTTOM = 0.185 / 2.2193
local BRAZIER_HEIGHT = 1.88 -- 화로 윗면이 철망(테이블 위 1.98) 바로 아래에 오게
local COAL_BLACK = Color3.fromRGB(30, 28, 28)
local COAL_ASH = Color3.fromRGB(196, 192, 186) -- 잿더미 같은 밝은 회색

local function brazierTemplates()
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local b, c, c2 = assets:FindFirstChild("BrazierMesh"), assets:FindFirstChild("CoalMesh"), assets:FindFirstChild("CoalBurntMesh")
	if b and c and c2 then
		return b, c, c2
	end
	return nil
end

local function addFire(parent, offset, direction)
	local fire = Instance.new("Attachment")
	fire.Name = "FireAtt"
	fire.Position = offset
	fire.Parent = parent
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
	pe.EmissionDirection = direction
	pe.Parent = fire
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 9
	light.Brightness = 2
	light.Parent = fire
	return fire
end

local function buildBrazierMesh(ws, bT, cT, c2T)
	local m = model(ws, "Brazier")
	local cx = -3.2
	local s = BRAZIER_HEIGHT / bT.Size.Y
	local function clone(tpl, name)
		local p = tpl:Clone()
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = tpl.Size * s
		p.Parent = m
		return p
	end
	-- 낡은 금속 화로
	local body = clone(bT, "Body")
	body.Material = Enum.Material.CorrodedMetal
	body.Color = Color3.fromRGB(104, 88, 74)
	body.CFrame = CFrame.new(at(cx, TABLE_TOP + body.Size.Y / 2, 0))
	-- 연탄 (쓸수록 연탄2처럼 낮아지고 잿빛이 됨: Builder.setCoal)
	local bottomY = TABLE_TOP + BRAZIER_HEIGHT * COAL_BOTTOM
	local coal = clone(cT, "Briquette")
	coal.Material = Enum.Material.Slate
	coal.Color = COAL_BLACK
	coal:SetAttribute("FullHeight", coal.Size.Y)
	coal:SetAttribute("BottomY", bottomY)
	coal.CFrame = CFrame.new(at(cx, 0, 0).X, bottomY + coal.Size.Y / 2, at(cx, 0, 0).Z)
	local burnt = clone(c2T, "BriquetteBurnt")
	burnt.Material = Enum.Material.Slate
	burnt.Color = COAL_ASH
	burnt.Transparency = 1
	burnt.CFrame = CFrame.new(coal.Position.X, bottomY + burnt.Size.Y / 2, coal.Position.Z)
	-- 연탄 구멍 사이로만 보이는 불씨 (윗면 바로 아래에 깔린 빛나는 원판)
	local ember = vcyl(m, "Ember", coal.Size.X * 0.9, 0.02, coal.Position + Vector3.new(0, coal.Size.Y / 2 - 0.04, 0), Color3.fromRGB(255, 110, 30), Enum.Material.Neon, { Transparency = 0.35 })
	ember.CastShadow = false
	addFire(coal, Vector3.new(0, coal.Size.Y / 2 + 0.05, 0), Enum.NormalId.Top)
	local grillY = TABLE_TOP + 1.98
	for i = -2, 2 do
		part(m, "Grill", Vector3.new(2.5, 0.06, 0.06), CFrame.new(at(cx, grillY, i * 0.4)), Color3.fromRGB(70, 70, 72), Enum.Material.Metal)
	end
	for _, x in ipairs({ -0.6, 0.6 }) do
		part(m, "Grill", Vector3.new(0.06, 0.06, 2.0), CFrame.new(at(cx + x, grillY, 0)), Color3.fromRGB(70, 70, 72), Enum.Material.Metal)
	end
	m:SetAttribute("GrillTopY", grillY + 0.03)
end

local function buildBrazier(ws)
	local bT, cT, c2T = brazierTemplates()
	if bT then
		buildBrazierMesh(ws, bT, cT, c2T)
	else
		buildBrazierParts(ws)
	end
end

-- 연탄 남은 양 (1 = 새 연탄, 0 = 다 탐). 높이는 연탄 → 연탄2 높이로, 색은 검정 → 잿빛으로.
-- 서버에서 부르면 모두에게 보인다. 작업대 속성 "CoalLeft"에도 남김.
function Builder.setCoal(ws, left)
	left = math.clamp(left, 0, 1)
	ws:SetAttribute("CoalLeft", left)
	local b = ws:FindFirstChild("Brazier")
	local coal = b and b:FindFirstChild("Briquette")
	local burnt = b and b:FindFirstChild("BriquetteBurnt")
	if not (coal and burnt and coal:GetAttribute("FullHeight")) then
		return
	end
	local full, small = coal:GetAttribute("FullHeight"), burnt.Size.Y
	local bottomY = coal:GetAttribute("BottomY")
	local h = small + (full - small) * left
	local useBurnt = left < 0.25
	local color = COAL_ASH:Lerp(COAL_BLACK, left)
	coal.Size = Vector3.new(coal.Size.X, h, coal.Size.Z)
	coal.CFrame = CFrame.new(coal.Position.X, bottomY + h / 2, coal.Position.Z)
	coal.Color = color
	coal.Transparency = useBurnt and 1 or 0
	burnt.Color = color
	burnt.Transparency = useBurnt and 0 or 1
	local top = bottomY + (useBurnt and small or h)
	local fire = coal:FindFirstChild("FireAtt")
	if fire then
		fire.Position = Vector3.new(0, top - coal.Position.Y + 0.05, 0)
		local light = fire:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 0.8 + 1.2 * left
		end
	end
	local ember = b:FindFirstChild("Ember")
	if ember then
		ember.CFrame = CFrame.new(coal.Position.X, top - 0.04, coal.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		ember.Transparency = 0.35 + 0.45 * (1 - left)
	end
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
	-- 광택은 템플릿 안의 SurfaceAppearance "CopperShine"(금속도 0.95 · 거칠기 0.25 텍스처)이 낸다. 아래 색·재질은 그게 없을 때 대신 쓰는 값.
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
	Builder.attachWrappedChopsticks(m)
end

-- 사용자가 만든 나무젓가락·포장지 메시(dalgona_joggalack.glb → ReplicatedStorage.Assets.Chopsticks)가 있으면
-- 테이블 위에는 포장된 나무젓가락(포장지1 + 포장지2)을 눕혀 두고, Stick1/Stick2는 보이지 않는 판정용으로만 쓴다.
-- 실제로 젓는 젓가락은 제작 시작 때 고른 한 짝 (클라이언트 Station:useChopstick).
function Builder.attachWrappedChopsticks(m)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local cs = assets and assets:FindFirstChild("Chopsticks")
	if not cs then
		return false
	end
	local s1 = m:FindFirstChild("Stick1")
	s1.Transparency = 1
	m:FindFirstChild("Stick2").Transparency = 1
	for _, p in ipairs(m:GetChildren()) do
		if p.Name:sub(1, 7) == "Wrapped" then
			p:Destroy()
		end
	end
	-- 메시 길이(Y) = 테이블 위 젓가락 방향, 두께(Z) = 위
	local d = s1.CFrame.LookVector
	local up = Vector3.yAxis
	local rot = CFrame.fromMatrix(Vector3.zero, d:Cross(up), d, up)
	local base = CFrame.new(s1.Position.X, TABLE_TOP + cs.Wrap1.Size.Z / 2, s1.Position.Z) * rot
	for _, name in ipairs({ "Wrap1", "Wrap2" }) do
		local p = cs[name]:Clone()
		p.Name = "Wrapped" .. name:sub(5)
		p.CFrame = base * CFrame.new(p:GetAttribute("Offset"))
		p.Parent = m
	end
	return true
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
	local pos = at(7.1, TABLE_TOP + 0.06, -1.35)
	local disc = vcyl(m, "Disc", 2.2, 0.1, pos, STEEL, Enum.Material.Metal, { Reflectance = 0.15 })
	vcyl(m, "Handle", 0.32, 1.0, pos + Vector3.new(0, 0.55, 0), LIGHT_WOOD, Enum.Material.Wood)
	ball(m, "Knob", 0.5, pos + Vector3.new(0, 1.1, 0), LIGHT_WOOD, Enum.Material.Wood)
	m.PrimaryPart = disc
	Builder.attachPresserMesh(m)
end

-- 사용자가 만든 누름판 메시(dalgona_nulumpan.glb → ServerStorage.Assets.PresserMesh), 금속 재질.
-- 판정용 원판 Disc(지름 2.2)는 투명하게 두고 메시를 원판 지름에 맞춰 붙인다 (메시 맨 아래 = 원판 아랫면).
function Builder.attachPresserMesh(m)
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local tpl = assets and assets:FindFirstChild("PresserMesh")
	if not tpl then
		return false
	end
	local disc = m:FindFirstChild("Disc")
	for _, name in ipairs({ "Mesh", "Handle", "Knob" }) do
		local p = m:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	disc.Transparency = 1
	local mesh = tpl:Clone()
	mesh.Name = "Mesh"
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.Size = tpl.Size * (disc.Size.Y / tpl.Size.X)
	mesh.Material = Enum.Material.Metal
	mesh.Color = Color3.fromRGB(205, 207, 212)
	local sa = Instance.new("SurfaceAppearance")
	sa.Name = "SteelShine"
	sa.Color = Color3.fromRGB(214, 216, 222)
	sa.MetalnessMap = METALNESS_MAP
	sa.RoughnessMap = ROUGHNESS_MAP
	sa.Parent = mesh
	local bottom = disc.Position.Y - disc.Size.X / 2
	mesh.CFrame = CFrame.new(disc.Position.X, bottom + mesh.Size.Y / 2, disc.Position.Z)
	mesh.Parent = m
	return true
end

local function buildStarCutter(ws)
	local m = model(ws, "StarCutter")
	local center = at(7.1, TABLE_TOP + 0.14, 0.6) -- 손잡이가 플레이어 쪽(+Z)으로 뻗어도 테이블 안에 들어오게
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
	Builder.attachCutterMesh(m)
end

-- Claude가 Blender 스크립트로 만든 별 틀 메시(tools/blender/star_cutter.py → ServerStorage.Assets.StarCutterMesh).
-- 크기는 게임 외곽선과 같다(1:1). 투명한 Wire 부품은 그대로 두고 각인 자국·판정에 쓴다.
-- glb에서 별 중심은 메시 가운데에서 손잡이 반대쪽으로 길이의 21.6%(0.6 stud) 떨어져 있다.
-- Roblox로 가져오면 별 꼭짓점이 메시 +Z, 손잡이가 -Z → 180° 돌려서 손잡이가 플레이어 쪽(+Z)을 향하게.
local CUTTER_CENTER_Z = 0.6 / 2.7807
function Builder.attachCutterMesh(m)
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local tpl = assets and assets:FindFirstChild("StarCutterMesh")
	if not tpl then
		return false
	end
	local old = m:FindFirstChild("Mesh")
	if old then
		old:Destroy()
	end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			p.Transparency = 1 -- Wire는 각인용으로 남김, Bar/Post는 메시 손잡이로 대신
		end
	end
	local root = m:FindFirstChild("Root")
	local mesh = tpl:Clone()
	mesh.Name = "Mesh"
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.Material = Enum.Material.Metal
	mesh.Color = Color3.fromRGB(205, 207, 212)
	local sa = Instance.new("SurfaceAppearance")
	sa.Name = "SteelShine"
	sa.Color = Color3.fromRGB(214, 216, 222)
	sa.MetalnessMap = METALNESS_MAP
	sa.RoughnessMap = ROUGHNESS_MAP
	sa.Parent = mesh
	mesh.CFrame = root.CFrame * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -mesh.Size.Z * CUTTER_CENTER_Z)
	mesh.Parent = m
	return true
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
	Builder.setCoal(ws, 1)
	ws.WorldPivot = CFrame.new(ORIGIN)
	ws.Parent = parent or workspace
	return ws
end

return Builder
