-- 제작 효과용 3D 메시 (tools/blender/fx.py → 레퍼런스/dalgona_fx.glb → ReplicatedStorage.Assets.Fx)
--   SugarCrystal (한 변 1), SugarPile (설탕 결정 더미, 지름 2 · 높이 0.47), SodaMound (소다 가루, 지름 2 · 높이 0.59),
--   FoamPuff (부푼 거품, 지름 2 · 높이 0.5). 모두 바닥 가운데 기준이라 Size로 크기를 맞추고 바닥을 base에 붙인다.
-- 메시가 없으면 nil을 돌려주고, 부르는 쪽은 예전 Part 모양을 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fx = {}

Fx.HEIGHT = { SugarPile = 0.47 / 2, SodaMound = 0.59 / 2, FoamPuff = 0.5 / 2 } -- 높이 / 지름

function Fx.template(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Fx")
	return folder and folder:FindFirstChild(name)
end

-- 메시 하나 복제 (fx 부품처럼 충돌·그림자 없음)
function Fx.mesh(name, parent, props)
	local tpl = Fx.template(name)
	if not tpl then
		return nil
	end
	local p = tpl:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for _, c in ipairs(p:GetChildren()) do
		c:Destroy()
	end
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- 늘어나는 공(타원체): Roblox Ball 부품은 크기를 다르게 주면 가장 작은 쪽으로 동그랗게 줄어서,
-- 네모 부품 + 구 모양 SpecialMesh로 바꿈 → Size 그대로 납작하거나 길쭉한 공이 됨
function Fx.ellipsoid(p)
	p.Shape = Enum.PartType.Block
	if not p:FindFirstChildOfClass("SpecialMesh") then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	return p
end

-- 돔 메시를 지름 d, 높이 h로, 바닥 가운데를 base(Vector3)에 맞춤. yaw는 돌림(라디안)
function Fx.placeDome(p, base, d, h, yaw)
	p.Size = Vector3.new(d, math.max(h, 0.005), d)
	p.CFrame = CFrame.new(base + Vector3.new(0, p.Size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0)
end

return Fx
