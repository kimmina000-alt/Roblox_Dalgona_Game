-- 가게 3D 교체 (2026-11-27 사용자 7.png, 레퍼런스/store-1.blend → 사용자가 Studio로 가져온 Workspace "Scene")
-- Studio 편집 모드에서 한 번 실행 (MCP execute_luau). 저장소 코드가 아니라 Studio 틀(Workspace.PlotLayout)을 고침.
--   - 기능이 걸린 가구(속성 Role: 앞 카운터·유리 진열장·걸이판·작은 탁자·냉장고·서랍장·간판 판·걸이 간판 …)는 그대로 둠
--   - 건물 껍데기(벽·바닥·지붕·차양·뒤 공장 방 창)만 새 3D로: 1 = 1층 가게, 2 = 2층(바깥 계단·옆문), 3 = 뒤 큰 건물(공장동)
--   - 크기 1.56배: 1층 폭 26.7 → 41.7 (예전 가게 폭 42와 같음), 1층 앞 열린 면 = 부지 로컬 z -18 (가게 앞선), 바닥 윗면 = 0.4
--     → 1층 뒷벽 = z 18 (예전 공장 문 자리 17.5), 3번 건물 = z 18 ~ 90 (공장 부지 28 × 44가 안에 들어감)
--   - 공장 문(PlotLayout.FactoryDoor)을 1층 뒷벽 문 구멍(부지 로컬 x -14)으로 옮김. 공장 부지는 FactoryDisplay.lotFrame이 가게 가운데 뒤로 놓음
--   - 옛 껍데기는 ServerStorage.Backup_1127.ShopShellOld 로 옮겨 둠 (되돌리기용)
--   - 가져온 Scene(슈퍼·문구사 3D 포함)은 ServerStorage.Assets.StoreKit 으로 옮김 (게임에서 길 한가운데 보이지 않게, AlleyBuilder가 씀)

local SS = game:GetService("ServerStorage")
local pl = workspace:FindFirstChild("PlotLayout")
local kit = SS:FindFirstChild("Assets") and SS.Assets:FindFirstChild("StoreKit")
if not kit then
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("Model") and c.Name == "Scene" and c:FindFirstChild("1-1") and c:FindFirstChild("3") then
			kit = c
		end
	end
end
assert(pl and kit, "PlotLayout / Scene(store-1) 없음")
-- 가져온 이름의 한글이 "간판" 글자 그대로 들어와 있음 → 한글로
for _, d in ipairs(kit:GetDescendants()) do
	if d.Name:find("\\u%x%x%x%x") then
		d.Name = d.Name:gsub("\\u(%x%x%x%x)", function(h)
			return utf8.char(tonumber(h, 16))
		end)
	end
end
local plotCF = pl:GetAttribute("PlotCFrame")
local shop = pl.ShopModel

local S = 1.56
local one = kit["1-1"]:FindFirstChildWhichIsA("BasePart", true)
-- 기준점: 1층 상자의 가로 가운데 · 안 바닥(아래 끝 + 0.1) · 앞 열린 면
local A = Vector3.new(one.Position.X, one.Position.Y - one.Size.Y / 2 + 0.1, one.Position.Z - one.Size.Z / 2)
local B = Vector3.new(0, 0.4, -18)
local function toLocal(p)
	return (p - A) * S + B
end

-- 이름 → { 쓰임, 색, 재질, 부딪힘, 층 }
local PALETTE = {
	["1-1"] = { "1층 건물", Color3.fromRGB(242, 230, 210), Enum.Material.Plaster, "precise", 1 },
	["1-1 front"] = { "1층 앞 테", Color3.fromRGB(176, 120, 78), Enum.Material.Wood, false, 1 },
	["1-1 차양"] = { "1층 차양", Color3.fromRGB(238, 170, 118), Enum.Material.Fabric, false, 1 },
	["2-1 벽.001"] = { "2층 건물", Color3.fromRGB(196, 224, 210), Enum.Material.Plaster, "precise", 2 },
	["2-1 벽"] = { "2층 안 벽", Color3.fromRGB(196, 224, 210), Enum.Material.Plaster, false, 2 },
	["2-1 창문"] = { "2층 창문", Color3.fromRGB(214, 170, 120), Enum.Material.Wood, false, 2 },
	["2-1 문"] = { "2층 옆문", Color3.fromRGB(176, 120, 78), Enum.Material.Wood, false, 2 },
	["2-1 계단"] = { "2층 바깥 계단", Color3.fromRGB(200, 194, 186), Enum.Material.Concrete, false, 2 },
	["2-1 계단 난간"] = { "2층 계단 난간", Color3.fromRGB(96, 88, 84), Enum.Material.Metal, false, 2 },
	["3"] = { "공장 건물", Color3.fromRGB(214, 204, 228), Enum.Material.Plaster, "precise", 3 },
	["3 지붕"] = { "지붕", Color3.fromRGB(150, 98, 66), Enum.Material.Wood, true, 3 },
	["3 창문 1"] = { "공장 창문", Color3.fromRGB(214, 170, 120), Enum.Material.Wood, false, 3 },
	["3 창문2"] = { "공장 창문", Color3.fromRGB(214, 170, 120), Enum.Material.Wood, false, 3 },
	["Cube.0862"] = { "공장 뒤 셔터", Color3.fromRGB(176, 178, 184), Enum.Material.DiamondPlate, false, 3 },
}
-- 안 쓰는 것: 새 카운터·진열장(예전 Role 가구가 같은 자리), 간판 판(예전 간판 판·이름판을 새 자리로), 2층 걸이 간판(예전 걸이 간판을 그 자리로),
-- 2-1 지붕(3 지붕과 겹침), 1층 뒤 문짝 두 장(FactoryDoor가 문), 전봇대(옆 가게 계단과 겹침)

-- 1) 옛 껍데기 → 백업
local OLD_SHELL = { "Plane_Node", "ShopFloor_Node", "Cube.0142", "Cube.024", "Cube.019", "Cube.020", "Cube.022", "WindowGlass_1_Node", "WindowGlass_2_Node", "Plane.003_Node" }
local backup = SS:FindFirstChild("Backup_1127") or Instance.new("Folder")
backup.Name = "Backup_1127"
backup.Parent = SS
local oldShell = backup:FindFirstChild("ShopShellOld") or Instance.new("Model")
oldShell.Name = "ShopShellOld"
oldShell.Parent = backup
for _, n in ipairs(OLD_SHELL) do
	local c = shop:FindFirstChild(n)
	if c then
		c.Parent = oldShell
	end
end

-- 2) 새 껍데기
local old = shop:FindFirstChild("Shell1127")
if old then
	old:Destroy()
end
local shell = Instance.new("Model")
shell.Name = "Shell1127"
local count = 0
for _, node in ipairs(kit:GetChildren()) do
	local spec = PALETTE[node.Name]
	if spec then
		for _, d in ipairs(node:GetDescendants()) do
			if d:IsA("BasePart") then
				local c = d:Clone()
				c.Name = node.Name
				local rot = d.CFrame - d.Position
				c.Size = d.Size * S
				c.CFrame = plotCF * (CFrame.new(toLocal(d.Position)) * rot)
				c.Anchored = true
				c.Color = spec[2]
				c.Material = spec[3]
				if c:IsA("MeshPart") then
					c.TextureID = ""
				end
				c:SetAttribute("Role", spec[1])
				c:SetAttribute("ShopFloor", spec[5])
				c.CanCollide = spec[4] ~= false
				c.CanQuery = spec[4] ~= false
				if spec[4] == "precise" and c:IsA("MeshPart") then
					c.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
				end
				c.Parent = shell
				count += 1
			end
		end
	end
end
shell.Parent = shop

-- 3) 바깥 계단: 계단 메시는 안 부딪히고, 안 보이는 비탈(Wedge)로 오르내림. 2층 옆문은 잠김(층 확장 전)
local stair = shell:FindFirstChild("2-1 계단")
if stair then
	local sl = plotCF:PointToObjectSpace(stair.Position)
	local lo = sl - stair.Size / 2
	local hi = sl + stair.Size / 2
	local w = Instance.new("WedgePart")
	w.Name = "StairRamp"
	w.Anchored = true
	w.Transparency = 1
	w.CanQuery = false
	w.Size = Vector3.new(hi.X - lo.X - 0.4, hi.Y - lo.Y, hi.Z - lo.Z)
	-- Wedge: 높은 쪽 = +Z(뒤, 2층 옆문 쪽). 낮은 쪽 = 앞(골목)
	w.CFrame = plotCF * CFrame.new((lo + hi) / 2)
	w:SetAttribute("Role", "2층 계단 비탈 (안 보임)")
	w.Parent = shell
end
local door2 = shell:FindFirstChild("2-1 문")
if door2 then
	local block = Instance.new("Part")
	block.Name = "Floor2Lock"
	block.Anchored = true
	block.Transparency = 1
	block.Size = Vector3.new(1, door2.Size.Y, door2.Size.Z + 1)
	block.CFrame = door2.CFrame
	block:SetAttribute("Role", "2층 옆문 잠금 (층 확장 전)")
	local bb = Instance.new("BillboardGui")
	bb.Name = "Floor2Sign"
	bb.Size = UDim2.fromOffset(170, 44)
	bb.StudsOffset = Vector3.new(0, door2.Size.Y / 2 + 1.2, 0)
	bb.MaxDistance = 50
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(150, 90, 60)
	t.Text = "2층 · 층 확장 준비 중"
	t.Parent = bb
	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(0, 10)
	uc.Parent = t
	bb.Parent = block
	block.Parent = shell
end

-- 3-2) 부딪힘: 속이 빈 메시를 PreciseConvexDecomposition으로 두면 공장 문 구멍이 메워져 못 지나감(2026-11-27 Play 확인)
--      → 1층·2층·공장동 메시는 안 부딪히고, 안 보이는 벽 파트(Collide)로 막음. 1층 뒷벽에만 공장 문 구멍(x -17.05 ~ -10.85, 높이 11.3)
for _, d in ipairs(shell:GetChildren()) do
	if d.Name == "1-1" or d.Name == "3" or d.Name == "2-1 벽.001" then
		d.CanCollide = false
	end
end
local function collide(x0, x1, y0, y1, z0, z1)
	local p = Instance.new("Part")
	p.Name = "Collide"
	p.Anchored = true
	p.Transparency = 1
	p.CanQuery = false
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	p.CFrame = plotCF * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Parent = shell
end
collide(-21.15, -20.55, 0.4, 55, -18, 90.1) -- 옆벽 (계단 쪽)
collide(20.55, 21.15, 0.4, 55, -18, 90.1) -- 옆벽
collide(-21.15, 21.15, 0.4, 55, 89.5, 90.1) -- 공장동 뒷벽
collide(-20.85, -17.05, 0.4, 27.6, 17.7, 18.4) -- 1층 뒷벽 (문 왼쪽)
collide(-10.85, 20.85, 0.4, 27.6, 17.7, 18.4) -- 1층 뒷벽 (문 오른쪽)
collide(-17.05, -10.85, 11.3, 27.6, 17.7, 18.4) -- 문 위
collide(-20.85, 20.85, 27.3, 27.9, -18, 18.4) -- 1층 천장 = 2층 바닥
collide(-20.85, 20.85, 27.9, 55, -18.6, -18) -- 2층 앞벽

-- 4) 예전 간판 판·이름판을 새 간판 자리로, 걸이 간판을 2층 걸이 간판 자리로
local function moveModel(m, dLocal)
	if m then
		local cf = m:GetPivot()
		local lcf = plotCF:ToObjectSpace(cf)
		m:PivotTo(plotCF * (CFrame.new(dLocal) * lcf))
	end
end
local newSign = kit:FindFirstChild("간판") and kit["간판"]:FindFirstChildWhichIsA("BasePart", true)
local board = shop:FindFirstChild("Cube.0162")
if newSign and board then
	local target = toLocal(newSign.Position)
	local bp = board:FindFirstChildWhichIsA("BasePart", true)
	local cur = plotCF:PointToObjectSpace(bp.Position)
	local d = Vector3.new(target.X - cur.X, target.Y - cur.Y, (target.Z - newSign.Size.Z * S / 2) - (cur.Z - bp.Size.Z / 2))
	moveModel(board, d)
	moveModel(shop:FindFirstChild("SignPanel_Node"), d)
end
local hang = kit:FindFirstChild("2-1 간판") and kit["2-1 간판"]:FindFirstChildWhichIsA("BasePart", true)
local hs = shop:FindFirstChild("HangingSign")
if hang and hs then
	local target = toLocal(hang.Position)
	local cur = plotCF:PointToObjectSpace(hs:GetPivot().Position)
	local hb = hs:FindFirstChild("HSign_Frame", true)
	local curC = hb and plotCF:PointToObjectSpace(hb.Position) or cur
	moveModel(hs, Vector3.new(0, target.Y - curC.Y, target.Z - curC.Z))
end

-- 5) 공장 문 → 1층 뒷벽 문 구멍
local doorHole = kit:FindFirstChild("Cube.0472") and kit["Cube.0472"]:FindFirstChildWhichIsA("BasePart", true)
local fd = pl:FindFirstChild("FactoryDoor")
if doorHole and fd and fd:FindFirstChild("Door") then
	local target = toLocal(doorHole.Position)
	local cur = plotCF:PointToObjectSpace(fd.Door.Position)
	moveModel(fd, Vector3.new(target.X - cur.X, 0, target.Z - cur.Z))
end

-- 6) 가져온 Scene → ServerStorage.Assets.StoreKit
if kit.Parent == workspace then
	kit.Name = "StoreKit"
	kit.Parent = SS:FindFirstChild("Assets") or SS
end
shop:SetAttribute("Note", "사용자 가게 3D 3판 (store-1.blend 2026-11-27, 1.56배): 1 = 1층 가게, 2 = 2층(바깥 계단, 층 확장 전 잠김), 3 = 뒤 공장동(공장 부지·5단계 라인이 안). 껍데기 = Shell1127 (tools/studio/shop_swap_1127.lua), 가구(Role)는 예전 그대로")
return "shell parts " .. count
