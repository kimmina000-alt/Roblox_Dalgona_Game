-- 작업대의 모양 틀(모델 "Cutter")에 도안 하나를 끼운다. 서버(처음 만들 때)와 클라이언트(고른 도안으로 바꿀 때)가 같이 쓴다.
-- 모델 구성: Root(투명, 틀 중심·바닥에서 0.14 위) + Mesh(ReplicatedStorage.Assets.Cutters.Cutter_<id>)
--           + Wire 부품들(투명, 속성 Outline) = 달고나에 찍히는 자국 선. 바깥선·안쪽 구멍·장식선 모두.
-- 좌표: CutterShapes의 (x, y)는 y가 화면 위쪽 = 월드 -Z. 손잡이는 플레이어 쪽(+Z).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CutterShapes = require(script.Parent:WaitForChild("CutterShapes"))

local Rig = {}

local METALNESS_MAP = "rbxassetid://75555295293901"
local ROUGHNESS_MAP = "rbxassetid://116334782975968"
local WIRE_H = 0.28
local MIN_SEG = 0.05 -- 이보다 짧은 마디는 합쳐서 부품 수를 줄인다
-- 틀 크기 배율 (사용자 요청 2026-11-18: 달고나 반죽에 비해 너무 큼 → 전체 65%). 바닥 크기만 줄이고 높이는 그대로
local SCALE = 0.65
Rig.SCALE = SCALE

local function find(id)
	for _, s in ipairs(CutterShapes) do
		if s.id == id then
			return s
		end
	end
	return nil
end

local function template(id)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Cutters")
	return folder and folder:FindFirstChild("Cutter_" .. id)
end

-- 점들을 간추림: 앞 점과 MIN_SEG 이상 떨어진 점만
local function simplify(pts)
	local out = {}
	for _, p in ipairs(pts) do
		local last = out[#out]
		if not last or math.abs(p[1] - last[1]) + math.abs(p[2] - last[2]) >= MIN_SEG then
			table.insert(out, p)
		end
	end
	return out
end

local function addWires(m, root, pts, closed, width, visible)
	pts = simplify(pts)
	local n = #pts
	local last = closed and n or n - 1
	for i = 1, last do
		local a, b = pts[i], pts[i % n + 1]
		local wa = root.CFrame:PointToWorldSpace(Vector3.new(a[1] * SCALE, 0, -a[2] * SCALE))
		local wb = root.CFrame:PointToWorldSpace(Vector3.new(b[1] * SCALE, 0, -b[2] * SCALE))
		local len = (wb - wa).Magnitude
		if len > 1e-3 then
			local w = Instance.new("Part")
			w.Name = "Wire"
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = visible
			w.Material = Enum.Material.Metal
			w.Color = Color3.fromRGB(200, 202, 208)
			w.Transparency = visible and 0 or 1
			w.Size = Vector3.new(width, WIRE_H, len + width * 0.6)
			w.CFrame = CFrame.lookAt((wa + wb) / 2, wb)
			w:SetAttribute("Outline", true)
			w:SetAttribute("Width", width)
			w.Parent = m
		end
	end
end

-- 반환: 도안 데이터 (없는 id면 nil, 아무것도 안 바꿈)
function Rig.apply(m, id)
	local shape = find(id)
	local root = m and m:FindFirstChild("Root")
	if not shape or not root then
		return nil
	end
	for _, c in ipairs(m:GetChildren()) do
		if c ~= root and (c:IsA("BasePart") or c:IsA("Model")) then
			c:Destroy()
		end
	end
	local tpl = template(id)
	local visibleWires = tpl == nil -- 메시가 없으면 철사 부품을 보이게 (대신 보여 줌)
	addWires(m, root, shape.outline, true, 0.07, visibleWires)
	for _, h in ipairs(shape.holes or {}) do
		addWires(m, root, h, true, 0.07, visibleWires)
	end
	for _, ln in ipairs(shape.lines or {}) do
		addWires(m, root, ln, ln.closed == true, 0.05, visibleWires)
	end
	if tpl then
		local mesh = tpl:Clone()
		mesh.Name = "Mesh"
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		if not mesh:FindFirstChildOfClass("SurfaceAppearance") then
			local sa = Instance.new("SurfaceAppearance")
			sa.Name = "SteelShine"
			sa.Color = Color3.fromRGB(214, 216, 222)
			sa.MetalnessMap = METALNESS_MAP
			sa.RoughnessMap = ROUGHNESS_MAP
			sa.Parent = mesh
		end
		local c = shape.center
		mesh.Size = Vector3.new(mesh.Size.X * SCALE, mesh.Size.Y, mesh.Size.Z * SCALE)
		mesh.CFrame = root.CFrame * CFrame.new(c.X * SCALE, 0, -c.Y * SCALE) * CFrame.Angles(0, math.pi, 0)
		mesh.Parent = m
	end
	m:SetAttribute("ShapeId", id)
	return shape
end

return Rig
