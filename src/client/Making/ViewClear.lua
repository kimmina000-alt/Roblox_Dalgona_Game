-- 만드는 동안 카메라와 작업대 사이를 가리는 가게 부품(천장·지붕·벽·간판 등)을 내 화면에서만 숨김
-- (2026-11-22 버그 "가게 안 작업대에서 제작 화면이 분홍 단색": 제작 카메라가 가게 천장 위·안에 걸림).
-- 층고·작업대 자리와 상관없이 동작하도록 상자 겹침·레이캐스트로 찾음. 숨기는 건 이 가게 부지(Plot<n>) 안의 부품만:
-- 작업대 자체와 제작 도구(클라이언트가 만든 국자·반죽·도구 등)는 건드리지 않음. 끝나면 되돌림.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ViewClear = {}

local hidden = {} -- 부품 → 숨기기 전 LocalTransparencyModifier
local conn = nil
local model = nil
local points = nil -- 기계 만들기: 카메라가 봐야 하는 자리 목록을 돌려주는 함수 (있으면 테이블 위 기둥 검사 없이 가린 것만 숨김)
local acc = 0

local SCAN_EVERY = 0.15 -- 초. 카메라가 단계마다 옮겨 가서 계속 다시 봄

local guis = {} -- 숨긴 부품에 붙은 글씨판·그림 → 되돌릴 값 (LocalTransparencyModifier로는 안 숨겨짐)
local function hide(p)
	if hidden[p] == nil then
		hidden[p] = p.LocalTransparencyModifier
		p.LocalTransparencyModifier = 1
		-- 간판 글씨(SurfaceGui "…의 달고나 가게") 등이 부품 없이 떠 보임 (2026-11-22 2인 테스트)
		for _, d in ipairs(p:GetChildren()) do
			if guis[d] == nil then
				if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
					guis[d] = d.Enabled
					d.Enabled = false
				elseif d:IsA("Decal") or d:IsA("Texture") then
					guis[d] = d.Transparency
					d.Transparency = 1
				end
			end
		end
	end
end

-- 기계 만들기에서 숨기지 않는 큰 부품 (가게 건물 통메시 등)
local BIG = 20
local function big(p)
	local s = p.Size
	return math.max(s.X, s.Y, s.Z) > BIG
end

-- 이 부품을 숨겨도 되나: 같은 가게 부지 안이고 작업대 밖
local function hideable(p, plot)
	return p:IsA("BasePart") and plot ~= nil and p:IsDescendantOf(plot) and not p:IsDescendantOf(model)
end

-- 작업대 상자: 테이블 상판·다리·화로(서버 부품)만으로 잼. 클라이언트가 만든 부품(설탕 더미·손·효과)은
-- 작업대가 가게 안↔밖으로 옮겨져도 옛 자리에 남을 수 있어서 뺌 (2026-11-22)
local function aabb(p)
	local h, r = p.Size / 2, p.CFrame
	local rx, ry, rz = r.RightVector * h.X, r.UpVector * h.Y, r.LookVector * h.Z
	local ext = Vector3.new(
		math.abs(rx.X) + math.abs(ry.X) + math.abs(rz.X),
		math.abs(rx.Y) + math.abs(ry.Y) + math.abs(rz.Y),
		math.abs(rx.Z) + math.abs(ry.Z) + math.abs(rz.Z)
	)
	return p.Position - ext, p.Position + ext
end
local function tableBox()
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	local function add(p)
		local a, b = aabb(p)
		mn, mx = mn:Min(a), mx:Max(b)
	end
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and (d.Name == "TableTop" or d.Name == "TableLeg") then
			add(d)
		end
	end
	local br = model:FindFirstChild("Brazier")
	if br then
		for _, d in ipairs(br:GetDescendants()) do
			if d:IsA("BasePart") then
				add(d)
			end
		end
	end
	if mn.X == math.huge then
		return model:GetBoundingBox()
	end
	return CFrame.new((mn + mx) / 2), mx - mn
end

-- 카메라가 봐야 하는 자리: 작업대 가운데·윗면·화로 + 네 귀퉁이 쪽
local function targets()
	local pts = {}
	local cf, size = tableBox()
	table.insert(pts, cf.Position)
	local top = model:FindFirstChild("TableTop")
	if top and top:IsA("BasePart") then
		table.insert(pts, top.Position + Vector3.new(0, top.Size.Y / 2, 0))
	end
	local br = model:FindFirstChild("Brazier")
	if br then
		table.insert(pts, br:GetPivot().Position)
	end
	for _, sx in ipairs({ -0.4, 0.4 }) do
		for _, sz in ipairs({ -0.4, 0.4 }) do
			table.insert(pts, (cf * CFrame.new(size.X * sx, 0, size.Z * sz)).Position)
		end
	end
	return pts
end

local function scan()
	local cam = workspace.CurrentCamera
	if not (cam and model and model.Parent) then
		return
	end
	local plot = model.Parent
	local origin = cam.CFrame.Position
	local ex = { model }
	local ch = Players.LocalPlayer.Character
	if ch then
		table.insert(ex, ch)
	end
	for p in pairs(hidden) do
		table.insert(ex, p)
	end
	-- 공간 검색(GetPartBounds*)과 레이캐스트는 CanQuery=false 부품을 못 잡음 (가게 꾸미기 차양·천장판·들보·창은 전부 false).
	-- 그래서 이 가게 부지 부품을 직접 돌며 축 정렬 상자로 겹침을 잼:
	--   ① 카메라 둘레(1 stud)에 걸친 부품  ② 테이블 바로 위 기둥(작업대 바닥 넓이 + 여유, 테이블 윗면 ~ 카메라 위)과 겹치는 부품
	-- 알바생 미니미(모델 속성 Minime)는 카운터 위에 서 있어도 남김 (카메라를 직접 가리면 아래 레이캐스트가 숨김)
	if points then
		-- 기계 만들기 (2026-11-27 사용자 "배경 날아감"): 기계 위 기둥 검사는 기계 뒤 벽·천장까지 통째로 숨겨서 뺌.
		-- 카메라와 볼 자리 사이를 실제로 가리는 것(레이캐스트)·카메라에 걸친 것만 숨김.
		-- 가게 건물 통메시(ShopModel.Plane 42×26×77 — 벽·천장이 한 덩어리)처럼 큰 부품은 카메라가 그 상자 안이라 통째로 숨겨져
		-- "배경이 날아감" → 큰 부품(BIG 넘게)은 숨기지 않음
		local omin, omax = origin - Vector3.one, origin + Vector3.one
		for _, p in ipairs(plot:GetDescendants()) do
			if p:IsA("BasePart") and hidden[p] == nil and not p:IsDescendantOf(model) and not big(p) then
				local pmin, pmax = aabb(p)
				if pmax.X > omin.X and pmin.X < omax.X and pmax.Y > omin.Y and pmin.Y < omax.Y and pmax.Z > omin.Z and pmin.Z < omax.Z then
					hide(p)
					table.insert(ex, p)
				end
			end
		end
	else
		local top = model:FindFirstChild("TableTop")
		local cf, size = tableBox()
		local y0 = (top and top:IsA("BasePart")) and (top.Position.Y + top.Size.Y / 2 + 0.3) or (cf.Position.Y + size.Y / 2)
		local y1 = math.max(origin.Y + 1, y0 + 1)
		local half = (cf - cf.Position):VectorToWorldSpace(size / 2)
		local hx, hz = math.abs(half.X) + 0.5, math.abs(half.Z) + 0.5
		local cmin = Vector3.new(cf.Position.X - hx, y0, cf.Position.Z - hz)
		local cmax = Vector3.new(cf.Position.X + hx, y1, cf.Position.Z + hz)
		local omin, omax = origin - Vector3.one, origin + Vector3.one
		for _, p in ipairs(plot:GetDescendants()) do
			if p:IsA("BasePart") and hidden[p] == nil and not p:IsDescendantOf(model) then
				local mm = p:FindFirstAncestorWhichIsA("Model")
				local isMinime = mm ~= nil and (mm:GetAttribute("Minime") == true or (mm.Parent ~= nil and mm.Parent:GetAttribute("Minime") == true))
				if not isMinime then
					local pmin, pmax = aabb(p)
					local inColumn = pmax.X > cmin.X and pmin.X < cmax.X and pmax.Y > cmin.Y and pmin.Y < cmax.Y and pmax.Z > cmin.Z and pmin.Z < cmax.Z
					local atCam = pmax.X > omin.X and pmin.X < omax.X and pmax.Y > omin.Y and pmin.Y < omax.Y and pmax.Z > omin.Z and pmin.Z < omax.Z
					if inColumn or atCam then
						hide(p)
						table.insert(ex, p)
					end
				end
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, t in ipairs(points and points() or targets()) do
		for _ = 1, 10 do
			params.FilterDescendantsInstances = ex
			local r = workspace:Raycast(origin, t - origin, params)
			if not r then
				break
			end
			local p = r.Instance
			if hideable(p, plot) and not (points and big(p)) then
				hide(p)
			end
			-- 숨길 수 없는 것(다른 곳·제작 도구)도 지나서 그 뒤를 봄
			table.insert(ex, p)
		end
	end
end

-- pts (선택): 볼 자리 목록을 돌려주는 함수 (기계 만들기)
function ViewClear.start(m, pts)
	ViewClear.stop()
	model = m
	points = pts
	acc = SCAN_EVERY
	conn = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= SCAN_EVERY then
			acc = 0
			scan()
		end
	end)
end

function ViewClear.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for p, v in pairs(hidden) do
		if p.Parent then
			p.LocalTransparencyModifier = v
		end
	end
	table.clear(hidden)
	for d, v in pairs(guis) do
		if d.Parent then
			if d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = v
			else
				d.Enabled = v
			end
		end
	end
	table.clear(guis)
	model = nil
	points = nil
end

return ViewClear
