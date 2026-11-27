-- 골목 슈퍼·문구사 고침 (2026-11-28 사용자 요청). Studio 편집 모드에서 한 번 실행 (MCP execute_luau). alley_shops_1127.lua 다음.
--   ① 슈퍼 문 판: 안쪽에서도 바깥과 같은 그림 (DoubleSided)
--   ② 슈퍼 선반을 키워 봉지가 칸 안에 다 들어가게 (칸 높이 2.9 → 4.2 이상, 깊이 2.6 → 3.2). 봉지마다 속성 ItemId(sugar/soda)
--   ④ 문구사 훌라후프·공·오락기 단추: Blender 원본 재질 색 (가져오면 흰색이 됨). 같은 메시(MeshId)로 원본 부품을 찾아 색을 칠함
--   ⑤ 문구사 양옆 벽: 지붕·뒷벽 메시를 뺄 때 안쪽 옆벽 면도 같이 빠져서 안에서 뚫려 보임 → 안쪽 옆벽 파트
local SS = game:GetService("ServerStorage")
local assets = SS.Assets
local kit = assets.StoreKit
local S = 1.56

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(1, 1, 1)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Blender 재질 색 (선형 → sRGB). 원본 부품 이름(가져온 이름) → 색
local function srgb(r, g, b)
	local function f(c)
		c = c <= 0.0031308 and c * 12.92 or 1.055 * c ^ (1 / 2.4) - 0.055
		return math.clamp(math.floor(c * 255 + 0.5), 0, 255)
	end
	return Color3.fromRGB(f(r), f(g), f(b))
end
local RED, YELLOW, GREEN, WHITE, BLUE = srgb(0.8, 0.006, 0.025), srgb(0.8, 0.72, 0), srgb(0, 0.8, 0.001), srgb(0.8, 0.8, 0.8), srgb(0, 0.003, 0.8)
local DARK, BTN = srgb(0.009, 0.009, 0.009), srgb(0.004, 0.141, 0)
-- 가져오기는 재질마다 메시를 나눔 (재질 번호 순: 이름, 이름2, 이름3 …)
local COLORS = {
	Circle = RED, Circle2 = YELLOW, Circle3 = GREEN, Circle4 = WHITE,
	["Circle.001"] = RED, ["Circle.0012"] = YELLOW, ["Circle.0013"] = GREEN, ["Circle.0014"] = WHITE,
	Icosphere = BLUE, Icosphere2 = YELLOW, Icosphere3 = RED,
	["Icosphere.001"] = GREEN, ["Icosphere.0012"] = RED,
	["Icosphere.002"] = GREEN, ["Icosphere.0022"] = RED,
	["Icosphere.003"] = BLUE, ["Icosphere.0032"] = YELLOW, ["Icosphere.0033"] = RED,
	["Cube.0992"] = DARK, ["Cube.0993"] = BTN, ["Cube.0994"] = DARK, ["Cube.0995"] = BTN,
}
local byMesh = {}
for _, d in ipairs(kit:GetDescendants()) do
	if d:IsA("MeshPart") and COLORS[d.Name] then
		byMesh[d.MeshId] = COLORS[d.Name]
	end
end

-------------------------------------------------------------------- 문구사
do
	local m = assets.AlleyStationery
	local look = m.Mk_Look
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("MeshPart") and byMesh[d.MeshId] then
			d.Color = byMesh[d.MeshId]
			d.Material = Enum.Material.SmoothPlastic
			n += 1
		end
	end
	-- 안쪽 옆벽 (겉 메시 옆벽 안쪽 면 자리)
	local big
	for _, d in ipairs(look:GetChildren()) do
		if d.Name == "Cube.052" and (not big or d.Size.Z > big.Size.Z) then
			big = d
		end
	end
	for _, d in ipairs(look:GetChildren()) do
		if d.Name == "St_SideWall" then
			d:Destroy()
		end
	end
	local front = big.Position.Z - big.Size.Z / 2 + 2.73 * S
	local back = big.Position.Z + big.Size.Z / 2
	local wall = 0.25 * S
	for _, sx in ipairs({ -1, 1 }) do
		part(look, "St_SideWall", Vector3.new(0.3, big.Size.Y, back - front), CFrame.new(big.Position.X + sx * (big.Size.X / 2 - wall - 0.15), big.Position.Y, (front + back) / 2), Color3.fromRGB(232, 232, 228), Enum.Material.Concrete, { CanCollide = false, CanQuery = false })
	end
	print("[fix] 문구사 색 칠한 부품", n)
end

-------------------------------------------------------------------- 슈퍼
do
	local m = assets.AlleyMarket
	for _, d in ipairs(m.Mk_Look:GetChildren()) do
		if d:IsA("MeshPart") and (d.Name == "Cube.053" or d.Name == "Cube.069" or d.Name == "Cube.070") then
			d.DoubleSided = true
		end
	end
	-- 선반 다시 (봉지는 칸 안에)
	local old = m:FindFirstChild("Mk_Goods")
	if old then
		old:Destroy()
	end
	local shellBody
	for _, d in ipairs(m.Mk_Look:GetChildren()) do
		if d.Name == "Cube.066" then
			shellBody = d
		end
	end
	local W, D = shellBody.Size.X, shellBody.Size.Z
	local WOOD = Color3.fromRGB(176, 124, 82)
	local WOOD_L = Color3.fromRGB(214, 172, 122)
	local goods = Instance.new("Model")
	goods.Name = "Mk_Goods"
	goods.Parent = m
	local function shelfUnit(name, at, w, d, h, n)
		local u = Instance.new("Model")
		u.Name = name
		part(u, "Back", Vector3.new(w, h, 0.25), at * CFrame.new(0, h / 2, d - 0.125), WOOD, Enum.Material.Wood)
		for _, sx in ipairs({ -1, 1 }) do
			part(u, "Side", Vector3.new(0.3, h, d), at * CFrame.new(sx * (w / 2 - 0.15), h / 2, d / 2), WOOD, Enum.Material.Wood)
		end
		local tops = {}
		for i = 0, n - 1 do
			local y = 0.4 + i * ((h - 0.8) / (n - 1))
			table.insert(tops, part(u, "Board", Vector3.new(w - 0.6, 0.25, d - 0.25), at * CFrame.new(0, y, (d - 0.25) / 2), WOOD_L, Enum.Material.Wood))
		end
		u.Parent = goods
		return tops
	end
	local BAG = {
		sugar = kit["Cube.038"]:FindFirstChildWhichIsA("BasePart", true),
		sugar2 = kit["Cube.039"]:FindFirstChildWhichIsA("BasePart", true),
		soda = kit["Cube.040"]:FindFirstChildWhichIsA("BasePart", true),
	}
	local slot = 0
	local function fill(tops, kinds)
		for i, board in ipairs(tops) do
			local key = kinds[i]
			if key then
				local bag = BAG[key]
				local size = bag.Size * S
				local wide = board.Size.X - 0.6
				local n = math.max(1, math.floor(wide / (size.X + 0.35)))
				for k = 1, n do
					local x = -wide / 2 + (k - 0.5) * (wide / n)
					local c = bag:Clone()
					c.Name = "Bag"
					c.Size = size
					c.Anchored = true
					c.CanCollide = false
					c.CanQuery = true -- 눌러서 사기 (ClickDetector)
					c.CFrame = board.CFrame * CFrame.new(x, board.Size.Y / 2 + size.Y / 2 + 0.02, -board.Size.Z / 2 + size.Z / 2 + 0.35)
					slot += 1
					c:SetAttribute("ItemId", key == "soda" and "soda" or "sugar")
					c:SetAttribute("Slot", slot)
					c.Parent = goods
				end
			end
		end
	end
	local backZ = D - 0.25 * S
	-- 뒷벽: 판 4장(칸 높이 약 4.2), 아래 세 칸에 설탕·백설탕·설탕
	fill(shelfUnit("BackShelf", CFrame.new(-W * 0.12, 0.3, backZ - 3.2), W * 0.62, 3.2, 13.5, 4), { "sugar", "sugar2", "sugar" })
	-- 오른쪽(-X) 벽: 판 3장(칸 높이 약 4.9), 소다·백설탕
	local sideAt = CFrame.new(-W / 2 + 0.25 * S + 1.7, 0.3, D * 0.55) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(0, 0, -1.6)
	fill(shelfUnit("SideShelf", sideAt, D * 0.55, 3.2, 10.5, 3), { "soda", "sugar2" })
	print("[fix] 슈퍼 봉지", slot)
end
return "ok"
