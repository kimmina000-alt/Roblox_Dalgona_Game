-- 작업대 1개를 Part로 만든다 (Phase 1 프로토타입, Phase 6에서 Blender 모델로 교체)
-- 연탄 화로 + 철망, 구리 국자, 나무젓가락, 나무 숟가락, 설탕 그릇 2개(흰 / 노란),
-- 소다 통 + 분홍 숟가락, 검은 철판 + 설탕 원, 둥근 누름판(세운 손잡이), 모양 틀(도안은 CutterRig)
-- 클라이언트 스크립트는 아래 이름으로 부품을 찾는다. 이름을 바꾸면 Making/Station.lua도 같이 바꾼다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CutterRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CutterRig"))

local Builder = {}

local ORIGIN = Vector3.new(0, 0, -14)
local TABLE_TOP = 3.5
local HANDLE_YAW = 205 -- 국자 손잡이 방향: 왼쪽 앞 (붓기는 오른쪽 철판 쪽으로 기울임)
-- 연탄 화로: 처음 크기(높이 1.88)의 1.5배. 커진 만큼 왼쪽으로 옮겨 설탕 그릇과 안 닿게
local BRAZIER_SCALE = 1.95 -- 1.5배에서 다시 1.3배 (사용자 요청 2026-11-18)
local BRAZIER_X = -4.4 -- 폭 5.1: 설탕 그릇(왼쪽 끝 x -1.57)과 안 닿게
local BRAZIER_HEIGHT = 1.88 * BRAZIER_SCALE
local GRILL_Y = TABLE_TOP + BRAZIER_HEIGHT + 0.1 -- 철망: 화로 윗면 바로 위

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
	-- 테이블 22 × 7 (처음 16 × 5.2에서 키움: 화로 1.5배 + 왼쪽 끝에 나무젓가락 자리)
	local top = part(ws, "TableTop", Vector3.new(22, 0.6, 7), CFrame.new(at(0.5, TABLE_TOP - 0.3, 0)), WOOD, Enum.Material.WoodPlanks, { CanCollide = true })
	for _, x in ipairs({ -10.0, 11.0 }) do
		for _, z in ipairs({ -3.1, 3.1 }) do
			part(ws, "TableLeg", Vector3.new(0.5, TABLE_TOP - 0.6, 0.5), CFrame.new(at(x, (TABLE_TOP - 0.6) / 2, z)), WOOD, Enum.Material.Wood, { CanCollide = true })
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "PromptAtt"
	att.Position = Vector3.new(0, 0.6, 3.5)
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

-- 철망 (화로 크기에 맞춰 늘어남). 속성 GrillTopY = 국자를 올려놓는 높이 (클라이언트 Heat가 씀)
local function buildGrill(m, cx)
	local k = BRAZIER_SCALE
	for i = -2, 2 do
		part(m, "Grill", Vector3.new(2.5 * k, 0.06, 0.06), CFrame.new(at(cx, GRILL_Y, i * 0.4 * k)), Color3.fromRGB(70, 70, 72), Enum.Material.Metal)
	end
	for _, x in ipairs({ -0.6, 0.6 }) do
		part(m, "Grill", Vector3.new(0.06, 0.06, 2.0 * k), CFrame.new(at(cx + x * k, GRILL_Y, 0)), Color3.fromRGB(70, 70, 72), Enum.Material.Metal)
	end
	m:SetAttribute("GrillTopY", GRILL_Y + 0.03)
end

-- 예전 Part 화로 (메시 에셋이 없을 때)
local function buildBrazierParts(ws)
	local m = model(ws, "Brazier")
	local cx = BRAZIER_X
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
	buildGrill(m, cx)

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

local EMBER_T = 0.6 -- 연탄 윗면 불씨 원판 투명도 (클수록 붉은빛이 옅음)

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
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.25, 0.45)
	pe.Rate = 30
	pe.Speed = NumberRange.new(1.2, 2)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = direction
	pe.Parent = fire
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 9
	light.Brightness = 1.4
	light.Parent = fire
	return fire
end

local function buildBrazierMesh(ws, bT, cT, c2T)
	local m = model(ws, "Brazier")
	local cx = BRAZIER_X
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
	-- 연탄 구멍 사이로만 보이는 불씨 (2026-11-20 "붉은 불 조금만 줄여": 투명도 0.35 → EMBER_T) (윗면 바로 아래에 깔린 빛나는 원판)
	local ember = vcyl(m, "Ember", coal.Size.X * 0.9, 0.02, coal.Position + Vector3.new(0, coal.Size.Y / 2 - 0.04, 0), Color3.fromRGB(255, 110, 30), Enum.Material.Neon, { Transparency = EMBER_T })
	ember.CastShadow = false
	addFire(coal, Vector3.new(0, coal.Size.Y / 2 + 0.05, 0), Enum.NormalId.Top)
	buildGrill(m, cx)
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
			light.Brightness = 0.6 + 0.8 * left
		end
	end
	local ember = b:FindFirstChild("Ember")
	if ember then
		ember.CFrame = CFrame.new(coal.Position.X, top - 0.04, coal.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		ember.Transparency = EMBER_T + (0.85 - EMBER_T) * (1 - left)
	end
end

local function buildLadle(ws)
	local m = model(ws, "Ladle")
	local center = at(BRAZIER_X, GRILL_Y + 0.03 + 0.6 + 0.225, 0)
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
	-- 테이블 왼쪽 끝에 세로로 눕혀 둠 (제작 화면 왼쪽에 보이고, 고르기 연출이 여기서 시작)
	local cf = CFrame.new(at(-8.2, TABLE_TOP + 0.04, 0.3))
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

-- Claude가 Blender 스크립트(tools/blender/props.py → 레퍼런스/dalgona_props.glb)로 만든 소품 메시.
-- ServerStorage.Assets에 있으면 Part 대신 보이고, 게임용 부품(Scoop·Heap·Bowl 등)은 투명하게 남겨 둔다.
-- center = Blender에서 기준점(그릇 바닥 가운데 / 숟가락 머리 가운데) → 메시 경계 상자 가운데 (x, y, z)
-- Roblox: 메시 = 기준 CFrame * (x, z, -y) * 180° 회전 (glb는 앞뒤가 뒤집혀 들어옴)
local PROP_CENTER = {
	SugarBowlMesh = Vector3.new(0, 0, 0.2273),
	SugarHeapMesh = Vector3.new(0, 0, 0.2313),
	SodaCanMesh = Vector3.new(0, 0, 0.3189),
	SodaLabelMesh = Vector3.new(0, 0, 0.31),
	SodaPowderMesh = Vector3.new(0, 0, 0.5297),
	WoodSpoonMesh = Vector3.new(0, -0.9401, 0.1765),
	TinSpoonMesh = Vector3.new(0, -0.6423, 0.1083),
}

local function propTemplate(name)
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	return assets and assets:FindFirstChild(name)
end

local function hideParts(m, keep)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and not p:IsA("MeshPart") and not (keep and keep[p.Name]) then
			p.Transparency = 1
			p.CastShadow = false
		end
	end
end

-- 반환: 붙인 메시 (템플릿이 없으면 nil)
local function attachProp(m, tplName, refCF, color, material, shine, scale)
	local tpl = propTemplate(tplName)
	if not tpl then
		return nil
	end
	local old = m:FindFirstChild(tplName)
	if old then
		old:Destroy()
	end
	local mesh = tpl:Clone()
	mesh.Name = tplName
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Color = color
	mesh.Material = material
	for _, c in ipairs(mesh:GetChildren()) do
		if c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	if shine then
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = "MetalShine"
		sa.Color = shine
		sa.MetalnessMap = METALNESS_MAP
		sa.RoughnessMap = ROUGHNESS_MAP
		sa.Parent = mesh
	end
	local c = (PROP_CENTER[tplName] or Vector3.zero) * (scale or 1)
	if scale then
		mesh.Size = tpl.Size * scale
	end
	mesh.CFrame = refCF * CFrame.new(c.X, c.Z, -c.Y) * CFrame.Angles(0, math.pi, 0)
	mesh.Parent = m
	return mesh
end

local function buildSugarBowl(ws, name, x, sugarColor)
	local m = model(ws, name)
	local pos = at(x, TABLE_TOP + 0.35, 1.3)
	local bowl = vcyl(m, "Bowl", 1.4, 0.7, pos, Color3.fromRGB(238, 238, 242), Enum.Material.SmoothPlastic)
	vcyl(m, "Stripe", 1.42, 0.08, pos + Vector3.new(0, 0.2, 0), Color3.fromRGB(70, 110, 190), Enum.Material.SmoothPlastic)
	vcyl(m, "Sugar", 1.22, 0.05, pos + Vector3.new(0, 0.34, 0), sugarColor, Enum.Material.Sand)
	m.PrimaryPart = bowl
	Builder.attachSugarBowlMesh(m, sugarColor)
end

-- 양은 그릇 + 설탕 더미 (레퍼런스 사진의 납작한 노점 그릇)
function Builder.attachSugarBowlMesh(m, sugarColor)
	local bowl = m:FindFirstChild("Bowl")
	local sugar = m:FindFirstChild("Sugar")
	if not bowl or not propTemplate("SugarBowlMesh") then
		return false
	end
	local base = CFrame.new(bowl.Position - Vector3.new(0, bowl.Size.X / 2, 0))
	hideParts(m)
	attachProp(m, "SugarBowlMesh", base, Color3.fromRGB(214, 196, 140), Enum.Material.Metal, Color3.fromRGB(232, 214, 160))
	attachProp(m, "SugarHeapMesh", base, sugarColor or (sugar and sugar.Color) or Color3.fromRGB(252, 252, 252), Enum.Material.Sand)
	return true
end

local function buildWoodSpoon(ws)
	local m = model(ws, "WoodSpoon")
	local cf = CFrame.new(at(-0.8, TABLE_TOP + 0.5, 1.3)) -- 양은 그릇 설탕 위에 얹힘
	local scoop = vcyl(m, "Scoop", 0.62, 0.1, cf.Position, LIGHT_WOOD, Enum.Material.Wood)
	ball(m, "Heap", 0.5, cf.Position + Vector3.new(0, 0.1, 0), Color3.fromRGB(252, 252, 252), Enum.Material.Sand)
	part(m, "Handle", Vector3.new(0.13, 0.07, 1.8), cf * CFrame.new(0, 0.28, 1.15) * CFrame.Angles(math.rad(18), 0, 0), LIGHT_WOOD, Enum.Material.Wood)
	local att = Instance.new("Attachment")
	att.Name = "PourAtt"
	att.Parent = scoop
	m.PrimaryPart = scoop
	-- 설탕 숟가락: 쇠숟가락 (소다 티스푼 메시를 1.5배로 = 머리 0.6 × 0.78, 손잡이 약 2)
	Builder.attachSpoonMesh(m, "TinSpoonMesh", 0, 1.5, "SteelSpoonMesh")
end

-- 숟가락 메시(쇠): 머리 가운데 = Scoop 자리, 손잡이는 yaw 방향으로 (0 = 플레이어 쪽 +Z). 설탕 더미(Heap)는 그대로 보임
function Builder.attachSpoonMesh(m, tplName, yaw, scale, newName)
	local scoop = m:FindFirstChild("Scoop")
	if not scoop or not propTemplate(tplName) then
		return false
	end
	hideParts(m, { Heap = true })
	for _, name in ipairs({ "WoodSpoonMesh", "SteelSpoonMesh", newName or tplName }) do
		local old = m:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local ref = CFrame.new(scoop.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
	local mesh = attachProp(m, tplName, ref, Color3.fromRGB(205, 207, 212), Enum.Material.Metal, Color3.fromRGB(214, 216, 222), scale)
	if mesh and newName then
		mesh.Name = newName
	end
	return true
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
	Builder.attachSodaMeshes(tub, m)
end

-- 소다 깡통(빨간 띠) + 소다 가루 + 쇠 티스푼 (분홍 플라스틱 통·숟가락 대신)
function Builder.attachSodaMeshes(tub, spoon)
	local b = tub:FindFirstChild("Tub")
	if not b or not propTemplate("SodaCanMesh") then
		return false
	end
	local base = CFrame.new(b.Position - Vector3.new(0, b.Size.X / 2, 0))
	hideParts(tub)
	attachProp(tub, "SodaCanMesh", base, Color3.fromRGB(200, 202, 206), Enum.Material.Metal, Color3.fromRGB(214, 216, 222))
	attachProp(tub, "SodaLabelMesh", base, Color3.fromRGB(210, 40, 46), Enum.Material.SmoothPlastic)
	attachProp(tub, "SodaPowderMesh", base, Color3.fromRGB(250, 250, 250), Enum.Material.Sand)
	Builder.attachSpoonMesh(spoon, "TinSpoonMesh", 45)
	return true
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
	-- 2026-11-20 "누름판 메탈 너무 밝아 살짝 어둡게"
	mesh.Color = Color3.fromRGB(158, 161, 168)
	local sa = Instance.new("SurfaceAppearance")
	sa.Name = "SteelShine"
	sa.Color = Color3.fromRGB(166, 169, 176)
	sa.MetalnessMap = METALNESS_MAP
	sa.RoughnessMap = ROUGHNESS_MAP
	sa.Parent = mesh
	local bottom = disc.Position.Y - disc.Size.X / 2
	mesh.CFrame = CFrame.new(disc.Position.X, bottom + mesh.Size.Y / 2, disc.Position.Z)
	mesh.Parent = m
	return true
end

-- 모양 틀: 투명한 Root만 만들고, 도안(메시 + 각인용 Wire)은 공용 CutterRig가 끼운다.
-- 손님이 고른 도안은 클라이언트가 같은 CutterRig로 바꿔 끼운다. 처음 놓여 있는 건 별.
function Builder.buildCutter(ws)
	local old = ws:FindFirstChild("StarCutter")
	if old then
		old:Destroy() -- 예전 별 전용 틀 (Studio에 저장된 작업대)
	end
	local m = ws:FindFirstChild("Cutter")
	if m then
		m:Destroy()
	end
	m = model(ws, "Cutter")
	local center = at(7.1, TABLE_TOP + 0.14, 0.6) -- 손잡이가 플레이어 쪽(+Z)으로 뻗어도 테이블 안에 들어오게
	local root = part(m, "Root", Vector3.new(0.1, 0.1, 0.1), CFrame.new(center), STEEL, Enum.Material.Metal, { Transparency = 1 })
	m.PrimaryPart = root
	CutterRig.apply(m, "Star")
	return m
end

-- 화로·국자만 다시 만들기 (화로 크기를 바꿨을 때 Studio에서 한 번 부름. 철망 높이가 바뀌어 국자도 같이)
function Builder.rebuildBrazier(ws)
	for _, name in ipairs({ "Brazier", "Ladle" }) do
		local old = ws:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	buildBrazier(ws)
	buildLadle(ws)
	Builder.setCoal(ws, ws:GetAttribute("CoalLeft") or 1)
end

-- ── 국자 여러 개 (MACHINE_ERAS 1단계: Lv3·5·8에 하나씩, 최대 4개) ──
-- 첫 국자(Ladle)는 플레이어 손 미니게임용 그대로. 2~4번째는 알바생이 알아서 만드는 국자로, 화로 철망 위
-- 플레이어 국자 둘레(오른쪽 뒤 · 왼쪽 뒤 · 오른쪽 앞)에 손잡이가 바깥을 보게 놓인다 (참고 사진: 큰 화로 둘레에 국자 여러 개).
-- 젓가락이 저절로 젓고 설탕 → 녹음 → 부풂 → 비움을 되풀이하는 움직임은 클라이언트 Making/HelperLadles가 그림.
-- 작업대 속성 LadleCount(1~4)로 정함. 성장 시스템이 생기면 레벨에 맞춰 이 속성을 바꾸면 됨.
local HELPER_SLOTS = { Vector3.new(1.55, 0, -1.2), Vector3.new(-1.55, 0, -1.2), Vector3.new(1.55, 0, 1.2) }
function Builder.setLadleCount(ws, n)
	n = math.clamp(math.floor(n or 1), 1, 4)
	ws:SetAttribute("LadleCount", n)
	for _, c in ipairs(ws:GetChildren()) do
		if c.Name:sub(1, 11) == "HelperLadle" then
			c:Destroy()
		end
	end
	local ladle = ws:FindFirstChild("Ladle")
	local bowl = ladle and ladle:FindFirstChild("Bowl")
	local mesh = ladle and ladle:FindFirstChild("Mesh")
	local contents = ladle and ladle:FindFirstChild("Contents")
	if not (bowl and mesh and contents) then
		return
	end
	-- 플레이어 국자의 메시·내용물 자리 (손잡이 방향 기준 틀)를 그대로 옮겨 씀
	local hd0 = (CFrame.Angles(0, math.rad(HANDLE_YAW), 0)).RightVector
	local c0 = bowl.Position
	local frame0 = CFrame.lookAt(c0, c0 - hd0)
	local meshRel = frame0:ToObjectSpace(mesh.CFrame)
	local contentsRel = CFrame.new(c0):ToObjectSpace(contents.CFrame)
	for k = 2, n do
		local off = HELPER_SLOTS[k - 1]
		local c = c0 + off
		-- 알바생 국자는 철망 위에 내려놓음 (플레이어 국자는 들고 있는 높이)
		local brazier = ws:FindFirstChild("Brazier")
		local grillY = brazier and brazier:GetAttribute("GrillTopY")
		if grillY then
			c = Vector3.new(c.X, grillY + bowl.Size.X / 2 + 0.02, c.Z)
		end
		local hd = Vector3.new(off.X, 0, off.Z).Unit -- 손잡이는 화로 바깥쪽
		local m = Instance.new("Model")
		m.Name = "HelperLadle" .. k
		local frame = CFrame.lookAt(c, c - hd)
		local mm = mesh:Clone()
		mm.CFrame = frame * meshRel
		mm.Parent = m
		local cc = contents:Clone()
		cc.Name = "Contents"
		cc.CFrame = CFrame.new(c) * contentsRel
		cc.Transparency = 0
		cc.Color = Color3.fromRGB(250, 250, 250)
		cc.Material = Enum.Material.Sand
		cc:SetAttribute("BaseThick", cc.Size.X)
		cc.Parent = m
		-- 알바생 나무젓가락 (클라이언트가 국자 안에서 원을 그리며 움직임)
		local stick = Instance.new("Part")
		stick.Name = "Stick"
		stick.Shape = Enum.PartType.Cylinder
		stick.Size = Vector3.new(2.6, 0.07, 0.07)
		stick.Color = Color3.fromRGB(224, 196, 150)
		stick.Material = Enum.Material.Wood
		stick.Anchored = true
		stick.CanCollide = false
		stick.CanQuery = false
		stick.CanTouch = false
		stick.CFrame = CFrame.new(c + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		stick.Parent = m
		m:SetAttribute("Phase", (k - 1) * 0.31)
		m:SetAttribute("Center", c)
		m:SetAttribute("BowlR", bowl.Size.Y / 2)
		m.Parent = ws
	end
end

function Builder.watchLadles(ws)
	Builder.setLadleCount(ws, ws:GetAttribute("LadleCount") or 1)
	ws:GetAttributeChangedSignal("LadleCount"):Connect(function()
		local n = ws:GetAttribute("LadleCount") or 1
		local have = 1
		for _, c in ipairs(ws:GetChildren()) do
			if c.Name:sub(1, 11) == "HelperLadle" then
				have += 1
			end
		end
		if have ~= n then
			Builder.setLadleCount(ws, n)
		end
	end)
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
	Builder.buildCutter(ws)
	Builder.setCoal(ws, 1)
	ws.WorldPivot = CFrame.new(ORIGIN)
	ws.Parent = parent or workspace
	return ws
end

return Builder
