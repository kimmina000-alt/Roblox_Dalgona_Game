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

function Decor.dress(ws)
	local top = ws:FindFirstChild("TableTop")
	if not top then
		return
	end
	if not ws:FindFirstChild("Tablecloth") then
		tablecloth(ws, top)
	end
	if not ws:FindFirstChild("Rug") then
		rug(ws, top)
	end
	grade()
end

return Decor
