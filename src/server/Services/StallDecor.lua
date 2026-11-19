-- 작업대 꾸미기 (사용자 요청 2026-11-19 "3D 더 귀엽고 입체적이고"):
--   분홍 깅엄 체크 식탁보 + 늘어진 가장자리 + 방울 장식, 바닥 둥근 러그, 따뜻하고 산뜻한 색감 보정.
-- 작업대(Studio에 저장된 것 포함)에 한 번만 붙인다. 부품은 모두 클릭·충돌 없음 (도구 판정에 안 걸리게).

local Lighting = game:GetService("Lighting")

local Decor = {}

local CLOTH = Color3.fromRGB(255, 249, 240)
local GINGHAM = Color3.fromRGB(255, 160, 185)
local TRIM = Color3.fromRGB(255, 130, 165)
local RUG = { Color3.fromRGB(190, 232, 214), Color3.fromRGB(255, 246, 228), Color3.fromRGB(255, 200, 214) }

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Fabric
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

local function tablecloth(ws, top)
	local f = Instance.new("Model")
	f.Name = "Tablecloth"
	local cf = top.CFrame
	local sx, sz = top.Size.X + 0.3, top.Size.Z + 0.3
	local y = top.Size.Y / 2
	local DROP = 0.75
	part(f, "Cloth", Vector3.new(sx, 0.04, sz), cf * CFrame.new(0, y + 0.0, 0), CLOTH)
	-- 깅엄: 가로·세로 반투명 줄이 겹치는 곳이 진해짐
	local stripe = { Transparency = 0.45, Material = Enum.Material.SmoothPlastic }
	local nz = math.floor(sz)
	for i = 0, nz - 1 do
		local z = -sz / 2 + 0.25 + i + (sz - nz) / 2
		part(f, "StripeX", Vector3.new(sx, 0.01, 0.5), cf * CFrame.new(0, y + 0.025, z), GINGHAM, stripe)
	end
	local nx = math.floor(sx)
	for i = 0, nx - 1 do
		local x = -sx / 2 + 0.25 + i + (sx - nx) / 2
		part(f, "StripeZ", Vector3.new(0.5, 0.01, sz), cf * CFrame.new(x, y + 0.03, 0), GINGHAM, stripe)
		-- 앞뒤로 늘어진 천 위 세로 줄
		for _, s in ipairs({ -1, 1 }) do
			part(f, "DrapeStripe", Vector3.new(0.5, DROP, 0.01), cf * CFrame.new(x, y - DROP / 2 + 0.02, s * (sz / 2 + 0.035)), GINGHAM, stripe)
		end
	end
	-- 늘어진 가장자리 (앞뒤·양옆)
	for _, s in ipairs({ -1, 1 }) do
		part(f, "Drape", Vector3.new(sx, DROP, 0.04), cf * CFrame.new(0, y - DROP / 2 + 0.02, s * (sz / 2 + 0.01)), CLOTH)
		part(f, "Drape", Vector3.new(0.04, DROP, sz), cf * CFrame.new(s * (sx / 2 + 0.01), y - DROP / 2 + 0.02, 0), CLOTH)
	end
	-- 아랫단 방울 장식
	local by = y - DROP + 0.02
	local function bobble(x, z)
		local b = part(f, "Bobble", Vector3.one * 0.22, cf * CFrame.new(x, by, z), TRIM, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic })
		return b
	end
	for x = -sx / 2 + 0.25, sx / 2 - 0.2, 0.5 do
		bobble(x, -sz / 2 - 0.03)
		bobble(x, sz / 2 + 0.03)
	end
	for z = -sz / 2 + 0.25, sz / 2 - 0.2, 0.5 do
		bobble(-sx / 2 - 0.03, z)
		bobble(sx / 2 + 0.03, z)
	end
	f.Parent = ws
end

local function rug(ws, top)
	local f = Instance.new("Model")
	f.Name = "Rug"
	local c = top.Position
	local ground = 0.0
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		ground = base.Position.Y + base.Size.Y / 2
	end
	local d = top.Size.X + 8
	for i, col in ipairs(RUG) do
		local dd = d * (1 - (i - 1) * 0.12)
		local p = part(f, "Rug" .. i, Vector3.new(0.04, dd, dd), CFrame.new(c.X, ground + 0.02 + i * 0.012, c.Z) * CFrame.Angles(0, 0, math.rad(90)), col)
		p.Shape = Enum.PartType.Cylinder
	end
	f.Parent = ws
end

local function grade()
	if Lighting:FindFirstChild("CuteGrade") then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CuteGrade"
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 240)
	cc.Parent = Lighting
	-- 그림자 속도 따뜻하고 밝게 (둥글둥글한 파스텔 느낌, 너무 어두운 그늘 없이)
	Lighting.Ambient = Color3.fromRGB(118, 106, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 138, 132)
end

-- 도구 사이 간격 넓히기 (사용자 요청 2026-11-19: 화로 · 설탕 그릇 · 철판 사이를 더 떨어뜨리고 테이블은 길어져도 됨).
-- Studio에 저장된 작업대도 실행할 때 옮긴다. 카메라 자리(CameraRig POSES)는 옮긴 뒤 기준.
-- WorkstationBuilder.rebuildBrazier는 옛 자리(BRAZIER_X)에 다시 만드니, 쓸 때는 이것도 다시 부른다.
local SPREAD = 1.5
local LEFT = { "Brazier", "Ladle", "Chopsticks" }
local RIGHT = { "IronPlate", "SugarRing", "SugarRingInner", "Presser", "Cutter" }

local function layout(ws, top)
	if ws:GetAttribute("LayoutV2") then
		return
	end
	ws:SetAttribute("LayoutV2", true)
	local function shift(name, dx)
		local inst = ws:FindFirstChild(name)
		if inst and inst:IsA("Model") then
			inst:PivotTo(inst:GetPivot() + Vector3.new(dx, 0, 0))
		elseif inst and inst:IsA("BasePart") then
			inst.CFrame += Vector3.new(dx, 0, 0)
		end
	end
	for _, n in ipairs(LEFT) do
		shift(n, -SPREAD)
	end
	for _, n in ipairs(RIGHT) do
		shift(n, SPREAD)
	end
	-- 모양틀 손잡이가 길어져서(CutterRig 손잡이 연장) 테이블 밖으로 안 나가게 안쪽으로
	local cutter = ws:FindFirstChild("Cutter")
	if cutter then
		cutter:PivotTo(cutter:GetPivot() + Vector3.new(0, 0, -0.2))
	end
	top.Size += Vector3.new(SPREAD * 2, 0, 0)
	for _, leg in ipairs(ws:GetChildren()) do
		if leg.Name == "TableLeg" then
			leg.CFrame += Vector3.new(leg.Position.X < top.Position.X and -SPREAD or SPREAD, 0, 0)
		end
	end
end

-- 기본은 낡은 나무 테이블 (사용자 요청 2026-11-19): 바랜 색 + 얼룩 몇 군데
local OLD_WOOD = Color3.fromRGB(116, 86, 62)
local STAIN = Color3.fromRGB(70, 48, 34)
local function wornTable(ws, top)
	if ws:FindFirstChild("Stains") then
		return
	end
	top.Color = OLD_WOOD
	top.Material = Enum.Material.WoodPlanks
	for _, leg in ipairs(ws:GetChildren()) do
		if leg.Name == "TableLeg" then
			leg.Color = OLD_WOOD:Lerp(STAIN, 0.25)
		end
	end
	local f = Instance.new("Model")
	f.Name = "Stains"
	local rng = Random.new(7)
	local y = top.Size.Y / 2 + 0.006
	for _ = 1, 9 do
		local d = rng:NextNumber(0.5, 1.4)
		local x = rng:NextNumber(-top.Size.X / 2 + 1, top.Size.X / 2 - 1)
		local z = rng:NextNumber(-top.Size.Z / 2 + 0.6, top.Size.Z / 2 - 0.6)
		local p = part(f, "Stain", Vector3.new(0.01, d, d * rng:NextNumber(0.6, 1)), top.CFrame * CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)), STAIN, { Transparency = 0.7, Material = Enum.Material.SmoothPlastic })
		p.Shape = Enum.PartType.Cylinder
	end
	-- 모서리가 닳아 밝아진 가장자리
	for _, s in ipairs({ -1, 1 }) do
		part(f, "WornEdge", Vector3.new(top.Size.X, 0.05, 0.12), top.CFrame * CFrame.new(0, y - 0.02, s * (top.Size.Z / 2 - 0.05)), OLD_WOOD:Lerp(Color3.fromRGB(200, 170, 130), 0.35), { Transparency = 0.3, Material = Enum.Material.Wood })
	end
	f.Parent = ws
end

-- 나무젓가락 통 (사용자 요청 2026-11-19): 낡은 양철 통에 나무젓가락이 잔뜩. 누르면 한 짝을 꺼냄 (클라이언트 ChopstickCup)
local function chopstickCup(ws)
	if ws:FindFirstChild("ChopstickCup") then
		return
	end
	local chop = ws:FindFirstChild("Chopsticks")
	local top = ws:FindFirstChild("TableTop")
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local tplFolder = assets and assets:FindFirstChild("Chopsticks")
	if not (chop and top and tplFolder) then
		return
	end
	-- 포장된 젓가락은 숨김 (이제 통에서 꺼냄)
	for _, p in ipairs(chop:GetChildren()) do
		if p:IsA("BasePart") and p.Name:sub(1, 7) == "Wrapped" then
			p.Transparency = 1
		end
	end
	local m = Instance.new("Model")
	m.Name = "ChopstickCup"
	local tableY = top.Position.Y + top.Size.Y / 2
	local base = Vector3.new(chop:GetPivot().Position.X, tableY, top.Position.Z - 2.2)
	local CUP_D, CUP_H = 1.0, 1.25
	local tin = { Material = Enum.Material.CorrodedMetal, CanQuery = false }
	local body = part(m, "Cup", Vector3.new(CUP_H, CUP_D, CUP_D), CFrame.new(base + Vector3.new(0, CUP_H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(168, 172, 168), tin)
	body.Shape = Enum.PartType.Cylinder
	local rim = part(m, "Rim", Vector3.new(0.08, CUP_D + 0.06, CUP_D + 0.06), CFrame.new(base + Vector3.new(0, CUP_H, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 122, 118), tin)
	rim.Shape = Enum.PartType.Cylinder
	local band = part(m, "Label", Vector3.new(0.4, CUP_D + 0.02, CUP_D + 0.02), CFrame.new(base + Vector3.new(0, CUP_H * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 90, 80), { Material = Enum.Material.SmoothPlastic })
	band.Shape = Enum.PartType.Cylinder
	-- 포장지에 싸인 채로 꽂혀 있음 (사용자 요청 2026-11-19: 꺼내면 포장 찢기부터)
	local names = { "Wrap1" }
	local rng = Random.new(11)
	for i = 1, 12 do
		local name = names[(i - 1) % #names + 1]
		local tpl = tplFolder:FindFirstChild(name)
		if tpl then
			local s = tpl:Clone()
			s.Name = "CupStick"
			s:SetAttribute("Tpl", name)
			s.Anchored = true
			s.CanCollide = false
			s.CanTouch = false
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * 0.3
			local len = s.Size.Y -- 포장 젓가락은 길이 축이 Y
			local pos = base + Vector3.new(math.cos(a) * r, 0.1 + len / 2 + rng:NextNumber(0, 0.15), math.sin(a) * r)
			-- 세워서 바깥쪽으로 살짝 벌어지게
			s.CFrame = CFrame.new(pos) * CFrame.Angles(math.sin(a) * 0.12, rng:NextNumber(0, 6), -math.cos(a) * 0.12)
			s.Parent = m
		end
	end
	m.Parent = ws
end

-- 식탁보는 상점에서 산 사람만 (사용자 요청 2026-11-19). 지금은 플레이어 속성 OwnsTablecloth로 판정 (상점은 다음 단계).
-- 작업대에 있는 플레이어 중 한 명이라도 가지고 있으면 깔림.
local clothStore = nil
function Decor.setTablecloth(ws, on)
	local cloth = ws:FindFirstChild("Tablecloth") or clothStore
	if not cloth then
		local top = ws:FindFirstChild("TableTop")
		if not top then
			return
		end
		tablecloth(ws, top)
		cloth = ws:FindFirstChild("Tablecloth")
	end
	clothStore = cloth
	cloth.Parent = on and ws or game:GetService("ServerStorage")
end

function Decor.watchOwners(ws)
	local Players = game:GetService("Players")
	local function refresh()
		local any = false
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("OwnsTablecloth") then
				any = true
			end
		end
		Decor.setTablecloth(ws, any)
	end
	Players.PlayerAdded:Connect(function(p)
		p:GetAttributeChangedSignal("OwnsTablecloth"):Connect(refresh)
		refresh()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	refresh()
end

function Decor.dress(ws)
	local top = ws:FindFirstChild("TableTop")
	if not top then
		return
	end
	layout(ws, top)
	wornTable(ws, top)
	-- 소다 통 숟가락 숨김 (사용자 요청 2026-11-19). 클라이언트 Station이 찾는 모델이라 지우지는 않음
	local spoon = ws:FindFirstChild("SodaSpoon")
	if spoon then
		for _, p in ipairs(spoon:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
	end
	chopstickCup(ws)
	if not ws:FindFirstChild("Rug") then
		rug(ws, top)
	end
	grade()
	Decor.watchOwners(ws)
end

return Decor
