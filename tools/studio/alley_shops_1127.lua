-- 골목 슈퍼·문구사 3D 교체 (2026-11-27 사용자 8.png·9.png, 레퍼런스/store-1.blend → ServerStorage.Assets.StoreKit)
-- Studio 편집 모드에서 한 번 실행 (MCP execute_luau). 결과:
--   ServerStorage.Assets.AlleyMarket    = 슈퍼마켙 (AlleyBuilder.marketSpot이 골목 동쪽 끝 남쪽 첫 칸에 놓음, 예전 것은 Backup_1127)
--   ServerStorage.Assets.AlleyStationery = 문구사 (AlleyBuilder가 서쪽 끝 남쪽 첫 칸, 예전 꾸미기 "행복문방구" 자리)
-- 두 모델 모두: 원점 = 앞벽 바깥 가운데 바닥, 앞 = -Z, 크기 1.56배 (가게 3D와 같은 비율).
--   겉(텍스처 메시)은 안 부딪히고, 안 보이는 벽(Mk_Wall)으로 막음. 문 판 하나(문구사는 가운데 두 장)를 빼서 출입구.
--   안: 바닥(Mk_Shell), 계산대, 선반. 슈퍼 선반 = 설탕·백설탕·식소다 봉지 3D (가져온 봉지 메시 복제, Mk_Goods),
--   문구사 선반 = 빈 판(속성 Display = "cutters" / "ladles") → AlleyBuilder가 도안 모양틀(Cutter_<id>)·국자를 놓음.
--   자리 표시(투명): Mk_Pt_Door(문 바깥 1.5), Mk_Pt_Customer(계산대 앞), Mk_Pt_Owner(계산대 뒤)

local SS = game:GetService("ServerStorage")
local assets = SS.Assets
local kit = assets.StoreKit
local S = 1.56
local backup = SS:FindFirstChild("Backup_1127") or Instance.new("Folder")
backup.Name = "Backup_1127"
backup.Parent = SS

local function src(name)
	local n = kit:FindFirstChild(name)
	return n and n:GetDescendants() or {}
end

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
local function mark(parent, name, cf)
	return part(parent, name, Vector3.new(1, 0.2, 1), cf, Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- body = 건물 상자 이름. 그 메시의 앞 아래 가운데가 원점
local function build(modelName, body, keep, opts)
	local bodyPart
	for _, d in ipairs(src(body)) do
		if d:IsA("BasePart") and (not bodyPart or d.Size.Z > bodyPart.Size.Z) then
			bodyPart = d
		end
	end
	local F = Vector3.new(bodyPart.Position.X, bodyPart.Position.Y - bodyPart.Size.Y / 2, bodyPart.Position.Z - bodyPart.Size.Z / 2)
	local function L(p)
		return (p - F) * S
	end
	local m = Instance.new("Model")
	m.Name = modelName
	local shell = Instance.new("Model")
	shell.Name = "Mk_Look"
	shell.Parent = m
	for _, name in ipairs(keep) do
		for _, d in ipairs(src(name)) do
			if d:IsA("BasePart") then
				local c = d:Clone()
				c.Name = name
				c.Size = d.Size * S
				c.CFrame = CFrame.new(L(d.Position)) * (d.CFrame - d.Position)
				c.Anchored = true
				c.CanCollide = opts.solid and opts.solid[name] or false
				c.CanQuery = c.CanCollide
				c.CastShadow = true
				if opts.double and opts.double[name] and c:IsA("MeshPart") then
					c.DoubleSided = true
				end
				c.Parent = shell
			end
		end
	end
	local W = bodyPart.Size.X * S
	local D = bodyPart.Size.Z * S
	local H = bodyPart.Size.Y * S
	local wall = 0.25 * S -- 겉 상자 벽 두께쯤
	-- 바닥 (안)
	part(m, "Mk_Shell", Vector3.new(W - 2 * wall, 0.3, D - 2 * wall), CFrame.new(0, 0.15, D / 2), opts.floor, opts.floorMat)
	-- 안 보이는 벽: 양옆·뒤·앞(문 구멍 빼고)
	local inv = { Transparency = 1, CanQuery = false }
	part(m, "Mk_Wall", Vector3.new(1, H, D), CFrame.new(-W / 2 + 0.5, H / 2, D / 2), nil, nil, inv)
	part(m, "Mk_Wall", Vector3.new(1, H, D), CFrame.new(W / 2 - 0.5, H / 2, D / 2), nil, nil, inv)
	part(m, "Mk_Wall", Vector3.new(W, H, 1), CFrame.new(0, H / 2, D - 0.5), nil, nil, inv)
	local dx0, dx1 = opts.door[1], opts.door[2] -- 문 구멍 x 범위 (모델 로컬)
	local fz = opts.frontZ
	local leftW = dx0 - (-W / 2)
	local rightW = W / 2 - dx1
	part(m, "Mk_Wall", Vector3.new(leftW, H, 1), CFrame.new(-W / 2 + leftW / 2, H / 2, fz), nil, nil, inv)
	part(m, "Mk_Wall", Vector3.new(rightW, H, 1), CFrame.new(W / 2 - rightW / 2, H / 2, fz), nil, nil, inv)
	part(m, "Mk_Wall", Vector3.new(dx1 - dx0, H - opts.doorH, 1), CFrame.new((dx0 + dx1) / 2, opts.doorH + (H - opts.doorH) / 2, fz), nil, nil, inv)
	mark(m, "Mk_Pt_Door", CFrame.new((dx0 + dx1) / 2, 0.1, -1.5))
	return m, L, W, D, H
end

local WOOD = Color3.fromRGB(176, 124, 82)
local WOOD_L = Color3.fromRGB(214, 172, 122)

-- 선반 한 칸: 뒤판 + 판 n장 + 옆 기둥. at = 앞 가운데 바닥 CFrame(앞 = -Z), 판 윗면 높이 목록을 돌려줌
local function shelfUnit(parent, name, at, w, d, h, n)
	local u = Instance.new("Model")
	u.Name = name
	part(u, "Back", Vector3.new(w, h, 0.25), at * CFrame.new(0, h / 2, d - 0.125), WOOD, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		part(u, "Side", Vector3.new(0.3, h, d), at * CFrame.new(sx * (w / 2 - 0.15), h / 2, d / 2), WOOD, Enum.Material.Wood)
	end
	local tops = {}
	for i = 0, n - 1 do
		local y = 0.4 + i * ((h - 0.8) / (n - 1))
		local b = part(u, "Board", Vector3.new(w - 0.6, 0.25, d - 0.25), at * CFrame.new(0, y, (d - 0.25) / 2), WOOD_L, Enum.Material.Wood)
		table.insert(tops, b)
	end
	u.Parent = parent
	return tops
end

-------------------------------------------------------------------- 슈퍼마켙
do
	local m, L, W, D, H = build("AlleyMarket", "Cube.066", { "Cube.066", "Cube.053", "Cube.069", "Cube.070", "Plane.002", "Cube.065" }, {
		floor = Color3.fromRGB(236, 232, 222),
		floorMat = Enum.Material.Marble,
		solid = { ["Cube.065"] = true },
		-- 문 = 빼낸 판 Cube.0542 자리
		door = (function()
			local p = kit["Cube.0542"]:FindFirstChildWhichIsA("BasePart", true)
			local body = kit["Cube.066"]:FindFirstChildWhichIsA("BasePart", true)
			local x = (p.Position.X - body.Position.X) * S
			return { x - p.Size.X * S / 2, x + p.Size.X * S / 2 }
		end)(),
		doorH = 8.72 * S,
		frontZ = 2.73 * S, -- 문 판이 있던 면 (앞면에서 안쪽 2.73)
	})
	-- 계산대: 가져온 안쪽 상자(Cube.079)를 나무색으로
	local cp = kit["Cube.079"]:FindFirstChildWhichIsA("BasePart", true)
	local counter = part(m, "Mk_Counter", cp.Size * S, CFrame.new(L(cp.Position)), WOOD, Enum.Material.Wood)
	part(m, "Mk_CounterTop", Vector3.new(counter.Size.X + 0.4, 0.3, counter.Size.Z + 0.4), counter.CFrame * CFrame.new(0, counter.Size.Y / 2 + 0.15, 0), WOOD_L, Enum.Material.Wood)
	-- 계산대는 문 들어가서 왼쪽(+X) 벽 옆, 앞뒤로 긺 → 손님은 안쪽(-X)에서, 주인은 벽 쪽(+X)에서 서로 봄
	local cpos = counter.Position
	mark(m, "Mk_Pt_Customer", CFrame.lookAt(Vector3.new(cpos.X - counter.Size.X / 2 - 1.6, 0.4, cpos.Z), Vector3.new(cpos.X, 0.4, cpos.Z)))
	mark(m, "Mk_Pt_Owner", CFrame.lookAt(Vector3.new(cpos.X + counter.Size.X / 2 + 1.4, 0.4, cpos.Z), Vector3.new(cpos.X - 5, 0.4, cpos.Z)))
	part(m, "Mk_Register", Vector3.new(1.4, 1, 1.2), counter.CFrame * CFrame.new(0, counter.Size.Y / 2 + 0.8, -1), Color3.fromRGB(90, 96, 104), Enum.Material.Metal)
	-- 선반 (뒷벽 한 줄 + 오른쪽(-X) 벽 한 줄) 위에 봉지
	local goods = Instance.new("Model")
	goods.Name = "Mk_Goods"
	goods.Parent = m
	local bags = {}
	for _, n in ipairs({ "Cube.038", "Cube.039", "Cube.040" }) do
		table.insert(bags, kit[n]:FindFirstChildWhichIsA("BasePart", true))
	end
	local function fill(tops, kinds)
		for i, board in ipairs(tops) do
			local bag = bags[kinds[(i - 1) % #kinds + 1]]
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
				c.CanQuery = false
				c.CFrame = board.CFrame * CFrame.new(x, board.Size.Y / 2 + size.Y / 2, -board.Size.Z / 2 + size.Z / 2 + 0.3)
				c.Parent = goods
			end
		end
	end
	local backZ = D - 0.25 * S
	local tops = shelfUnit(goods, "BackShelf", CFrame.new(-W * 0.12, 0.3, backZ - 2.6), W * 0.62, 2.6, 9.5, 4)
	table.remove(tops, #tops) -- 맨 위 판은 비움 (위에서 보면 판만)
	fill(tops, { 1, 2, 1 })
	local sideAt = CFrame.new(-W / 2 + 0.25 * S + 2.6 / 2 + 0.1, 0.3, D * 0.55) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(0, 0, -1.3)
	local tops2 = shelfUnit(goods, "SideShelf", sideAt, D * 0.55, 2.6, 7.5, 3)
	fill(tops2, { 3, 2, 3 })
	-- 선반 위 이름표
	m:SetAttribute("Market", true)
	m:SetAttribute("Note", "슈퍼마켙 (store-1.blend 2026-11-27, tools/studio/alley_shops_1127.lua). 원점 = 앞벽 바깥 가운데 바닥, 앞 = -Z, 1.56배")
	local old = assets:FindFirstChild("AlleyMarket")
	if old then
		old.Name = "AlleyMarketOld"
		old.Parent = backup
	end
	m.Parent = assets
end

-------------------------------------------------------------------- 문구사
do
	local p48 = kit["Cube.048"]:FindFirstChildWhichIsA("BasePart", true)
	local p49 = kit["Cube.049"]:FindFirstChildWhichIsA("BasePart", true)
	local bodyP
	for _, d in ipairs(src("Cube.052")) do
		if d:IsA("BasePart") and (not bodyP or d.Size.Z > bodyP.Size.Z) then
			bodyP = d
		end
	end
	local x0 = (math.min(p48.Position.X, p49.Position.X) - p48.Size.X / 2 - bodyP.Position.X) * S
	local x1 = (math.max(p48.Position.X, p49.Position.X) + p48.Size.X / 2 - bodyP.Position.X) * S
	local keep = { "Cube.052", "Cube.050", "Cube.051", "Cube.072", "Cube.067", "Circle_Node", "Circle.001_Node", "Icosphere_Node", "Icosphere.001_Node", "Icosphere.002_Node", "Icosphere.003_Node" }
	local m, L, W, D, H = build("AlleyStationery", "Cube.052", keep, {
		floor = Color3.fromRGB(226, 206, 176),
		floorMat = Enum.Material.WoodPlanks,
		solid = { ["Cube.072"] = true },
		double = { ["Cube.050"] = true, ["Cube.051"] = true },
		door = { x0, x1 },
		doorH = 8.72 * S,
		frontZ = 2.73 * S,
	})
	-- 계산대 (가져온 안쪽 상자 Cube.073)
	local cp = kit["Cube.073"]:FindFirstChildWhichIsA("BasePart", true)
	local counter = part(m, "St_Counter", cp.Size * S, CFrame.new(L(cp.Position)), WOOD, Enum.Material.Wood)
	part(m, "St_CounterTop", Vector3.new(counter.Size.X + 0.4, 0.3, counter.Size.Z + 0.4), counter.CFrame * CFrame.new(0, counter.Size.Y / 2 + 0.15, 0), WOOD_L, Enum.Material.Wood)
	-- 뒷벽 모양틀 선반 (판 4장, 판마다 속성 Display = "cutters"), 가운데 국자 탁자 (Display = "ladles")
	local disp = Instance.new("Model")
	disp.Name = "St_Display"
	disp.Parent = m
	local backZ = D - 0.25 * S
	local tops = shelfUnit(disp, "CutterShelf", CFrame.new(-W * 0.05, 0.3, backZ - 2.4), W * 0.8, 2.4, 10, 4)
	for _, b in ipairs(tops) do
		b:SetAttribute("Display", "cutters")
	end
	local tbl = Instance.new("Model")
	tbl.Name = "LadleTable"
	local top = part(tbl, "Top", Vector3.new(9, 0.4, 4.2), CFrame.new(-W * 0.08, 3.2, D * 0.5), WOOD_L, Enum.Material.Wood)
	top:SetAttribute("Display", "ladles")
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(tbl, "Leg", Vector3.new(0.4, 3, 0.4), CFrame.new(top.Position.X + sx * 4.1, 1.5, top.Position.Z + sz * 1.7), WOOD, Enum.Material.Wood)
		end
	end
	tbl.Parent = disp
	-- 오른쪽 벽 쪽 작은 선반 (모양틀 더)
	local sideAt = CFrame.new(-W / 2 + 0.25 * S + 1.2, 0.3, D * 0.5) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(0, 0, -1.2)
	local tops2 = shelfUnit(disp, "SideShelf", sideAt, D * 0.5, 2.4, 7, 3)
	for _, b in ipairs(tops2) do
		b:SetAttribute("Display", "cutters")
	end
	-- 지붕·뒷벽 메시(Cube.052 중 작은 쪽)에 앞을 가리는 뒤집힌 회색 면이 같이 있어서 빼고, 지붕·뒷벽은 파트로
	do
		local look = m.Mk_Look
		local small, big
		for _, d in ipairs(look:GetChildren()) do
			if d.Name == "Cube.052" then
				if not big or d.Size.Z > big.Size.Z then
					small, big = big, d
				else
					small = d
				end
			end
		end
		if small then
			small:Destroy()
		end
		local front = big.Position.Z - big.Size.Z / 2 + 2.73 * S
		local back = big.Position.Z + big.Size.Z / 2
		local top = big.Position.Y + big.Size.Y / 2
		local inv = { CanCollide = false, CanQuery = false }
		part(look, "St_Roof", Vector3.new(big.Size.X, 0.4, back - front), CFrame.new(big.Position.X, top - 0.8, (front + back) / 2), Color3.fromRGB(232, 232, 228), Enum.Material.Concrete, inv)
		part(look, "St_BackWall", Vector3.new(big.Size.X, big.Size.Y, 0.4), CFrame.new(big.Position.X, big.Position.Y, back - 0.2), Color3.fromRGB(232, 232, 228), Enum.Material.Concrete, inv)
	end
	m:SetAttribute("Stationery", true)
	m:SetAttribute("Note", "문구사 (store-1.blend 2026-11-27, tools/studio/alley_shops_1127.lua). 원점 = 앞벽 바깥 가운데 바닥, 앞 = -Z, 1.56배. 선반 판 속성 Display = cutters/ladles → AlleyBuilder가 모양틀·국자를 놓음")
	local old = assets:FindFirstChild("AlleyStationery")
	if old then
		old:Destroy()
	end
	m.Parent = assets
end
return "ok"
