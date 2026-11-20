-- 다 만든 달고나 보여 주기 + 포장 (2026-11-20 사용자 요청)
--   ① 철판 위 달고나(막대·금·자국 포함)가 화면 가운데 쪽으로 천천히 떠올라 크게 보이고, 좌우로 살짝 돌며 옆면이 보임
--   ② 투명 비닐 포장지가 위에서 씌워지고, 막대 쪽 목이 오므라든 뒤 빵끈(금색 철사 끈)이 감겨 묶임
--   ③ 그다음 완성 창 (MakingClient가 띄움). 돌아가는 움직임은 완성 창이 떠 있는 동안 계속
-- 결과 창이 화면 오른쪽에 뜨므로 달고나는 화면 왼쪽 가운데(가로 32%)에 둠

local RunService = game:GetService("RunService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local CameraRig = require(script.Parent:WaitForChild("CameraRig"))

local Showcase = {}

local MOVE_T = 1.3 -- 떠올라 오는 시간
local ROCK_A = math.rad(22) -- 좌우로 도는 각도
local WRAP_T = 0.55 -- 포장지 씌우는 시간
local TIE_T = 0.5 -- 빵끈 감는 시간
local BAG = Color3.fromRGB(248, 250, 255)
local TIE = Color3.fromRGB(226, 176, 52)

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local AssetService = game:GetService("AssetService")

-- 입체 비닐 포장 (2026-11-20 "납작한 비닐 씌워서 빵끈으로 아래 묶으면 입체감"):
-- 달고나를 감싸 볼록하게 부푼 비닐 자루. 위는 둥글게 닫히고, 막대 쪽으로 갈수록 좁아져 목에서 주름지며 오므라들고,
-- 빵끈 아래로 비닐 끝자락이 살짝 퍼짐. gather(0~1)로 목이 오므라드는 정도를 바꿈. EditableMesh가 안 되면 nil
local NA, NS = 40, 44 -- 둘레 · 길이 방향 조각
local function buildBag(parent, R, zNeck)
	local ok, res = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local zTop = R * 1.15
		local zEnd = zNeck - 0.3
		local zBody = -R * 0.72 -- 여기서부터 목 쪽으로 좁아짐
		local yc = 0.05
		local verts = {}
		for i = 1, NS do
			verts[i] = {}
			for j = 1, NA do
				verts[i][j] = em:AddVertex(Vector3.zero)
			end
		end
		for i = 1, NS - 1 do
			for j = 1, NA do
				local j2 = j % NA + 1
				local a, b, c, d = verts[i][j], verts[i][j2], verts[i + 1][j], verts[i + 1][j2]
				-- 바깥 면 한 겹만 (2026-11-20 "비닐 무늬 안 보이게": 앞뒤 두 겹이 같은 자리에 겹쳐 얼룩무늬가 보였음)
				em:AddTriangle(a, d, b)
				em:AddTriangle(a, c, d)
			end
		end
		-- 경계 고정 (꼭짓점이 움직여도 크기 기준이 안 바뀌게)
		-- 메시 좌표는 가운데(center) 기준: 경계 상자의 가운데가 원점이어야 MeshPart 위치와 맞음
		local center = Vector3.new(0, yc, (zTop + 0.05 + zEnd - 0.05) / 2)
		local B = R * 1.25
		local p1 = em:AddVertex(Vector3.new(-B, yc - 0.3, zEnd - 0.05) - center)
		local p2 = em:AddVertex(Vector3.new(-B + 0.001, yc - 0.3, zEnd - 0.05) - center)
		local p3 = em:AddVertex(Vector3.new(B, yc + 0.3, zTop + 0.05) - center)
		local p4 = em:AddVertex(Vector3.new(B - 0.001, yc + 0.3, zTop + 0.05) - center)
		em:AddTriangle(p1, p2, p1)
		em:AddTriangle(p3, p4, p3)
		local self = {}
		function self.shape(g)
			for i = 1, NS do
				local s = (i - 1) / (NS - 1)
				local z, w, t, amp
				local wn = R * 0.55 + (0.07 - R * 0.55) * g -- 목 너비 (오므라들수록 좁음)
				local tn = 0.14 + (0.05 - 0.14) * g
				if s <= 0.82 then
					z = zTop + (zNeck - zTop) * (s / 0.82)
					-- 위쪽 둥근 끝
					local capLen = R * 0.95 -- 위쪽은 반달처럼 둥글게 (네모난 어깨 없이)
					local d = zTop - z
					local f = d < capLen and math.sqrt(math.max(0, 1 - (1 - d / capLen) ^ 2)) or 1
					local W, T = R * 1.12 * f, 0.17 * math.sqrt(f)
					if z < zBody then
						local u = smooth((zBody - z) / (zBody - zNeck))
						w = W + (wn - W) * u
						t = T + (tn - T) * u
						amp = g * 0.22 * u
					else
						w, t, amp = W, T, 0
					end
				else
					local v = (s - 0.82) / 0.18
					z = zNeck + (zEnd - zNeck) * v
					local we = R * 0.5 + (0.2 - R * 0.5) * g
					w = wn + (we - wn) * v ^ 0.7
					t = tn + ((0.12 + (0.08 - 0.12) * g) - tn) * v
					amp = g * 0.25
				end
				for j = 1, NA do
					local a = (j - 1) / NA * 2 * math.pi
					local m = 1 + amp * math.sin(8 * a + i * 0.35) -- 오므린 곳의 비닐 주름
					em:SetPosition(verts[i][j], Vector3.new(w * math.cos(a) * m, yc + t * math.sin(a) * m, z) - center)
				end
			end
		end
		self.shape(0)
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = "WrapBag3D"
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.CastShadow = false
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = BAG
		mp.Reflectance = 0.3
		mp.Transparency = 1
		mp.Parent = parent
		self.part = mp
		self.center = center
		self.em = em
		return self
	end)
	if ok then
		return res
	end
	warn("[Showcase] 입체 포장지를 만들 수 없어요:", res)
	return nil
end

-- 달고나에 딸린 부품 모으기 (3D 반죽, 예전 원판 부품, 표면 무늬, 금, 자국, 막대)
local function collect(S, dal, st)
	local parts, seen = {}, {}
	local function add(p)
		if p and p:IsA("BasePart") and not seen[p] and p.Parent then
			seen[p] = true
			table.insert(parts, p)
		end
	end
	if dal.batter then
		add(dal.batter.part)
	end
	for _, p in ipairs({ dal.body, dal.rim, dal.rim2, dal.dome }) do
		add(p)
	end
	for _, l in ipairs(dal.lumps or {}) do
		add(l.part)
	end
	for _, p in pairs(dal.meshes or {}) do
		add(p)
	end
	for _, d in ipairs(dal.details or {}) do
		add(d.part)
	end
	for _, c in ipairs(dal.cracks or {}) do
		add(c.part)
	end
	local NAMES = { Crack = true, Engrave = true, EngraveShadow = true, EngraveLight = true, DalgonaSwirl = true }
	for _, p in ipairs(S.fx:GetChildren()) do
		if NAMES[p.Name] then
			add(p)
		end
	end
	if st.stickModel then
		for _, p in ipairs(st.stickModel:GetDescendants()) do
			add(p)
		end
	end
	return parts
end

-- ctx.frame()으로 기다리며 연출. 끝나면 계속 도는 연결을 돌려줌 (반죽이 사라지면 저절로 멈춤)
function Showcase.run(ctx, dal, st)
	local S = ctx.station
	local parts = collect(S, dal, st)
	if #parts == 0 then
		return nil
	end
	local R = dal:radius()
	local c = dal.center
	local dir = (st.stick and st.stick.dir) or Vector3.new(0, 0, 1)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, 1)
	-- 기준 틀: 가운데 = 달고나 가운데(철판 윗면), 앞(-Z) = 막대 방향, 위(+Y) = 윗면
	local R0 = CFrame.lookAt(c, c + dir)
	local rel = {}
	for i, p in ipairs(parts) do
		rel[i] = R0:ToObjectSpace(p.CFrame)
		p.Anchored = true
	end
	-- 포장지: 비닐(투명한 판) + 막대 쪽 오므린 목 + 빵끈 고리와 꼬인 두 가닥 (기준 틀 좌표)
	local bagW, bagL = 2 * R * 1.16, 2 * R * 1.2
	local bag = S:fxPart(S.fx, { Name = "WrapBag", Color = BAG, Material = Enum.Material.SmoothPlastic, Reflectance = 0.25, Transparency = 1, Size = Vector3.new(bagW, 0.22, bagL) })
	local neck = S:fxPart(S.fx, { Name = "WrapNeck", Color = BAG, Material = Enum.Material.SmoothPlastic, Reflectance = 0.25, Transparency = 1, Size = Vector3.new(0.5, 0.16, 0.42) })
	local tie = S:fxPart(S.fx, { Name = "WrapTie", Shape = Enum.PartType.Cylinder, Color = TIE, Material = Enum.Material.Metal, Transparency = 1, Size = Vector3.new(0.08, 0.24, 0.24) })
	local tails = {}
	for i = 1, 2 do
		tails[i] = S:fxPart(S.fx, { Name = "WrapTieEnd", Color = TIE, Material = Enum.Material.Metal, Transparency = 1, Size = Vector3.new(0.035, 0.035, 0.32) })
	end
	local neckZ = -(R * 1.2 + 0.18) -- 막대 쪽 (기준 틀 -Z)
	local tieZ = neckZ - 0.22
	local bag3 = buildBag(S.fx, R, neckZ)
	if bag3 then
		tieZ = neckZ -- 빵끈은 오므린 목에 감김
		bag.Size = Vector3.new(0.01, 0.01, 0.01)
		neck.Size = Vector3.new(0.01, 0.01, 0.01)
	end
	local gathered = -1

	local camera = workspace.CurrentCamera
	local function finalBase(rock)
		local vp = camera.ViewportSize
		-- 가로 화면: 완성 창이 오른쪽 → 왼쪽 가운데. 세로 화면(폰): 완성 창이 아래 → 위쪽 가운데
		local portrait = vp.X < vp.Y
		local ray = portrait and camera:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.3) or camera:ViewportPointToRay(vp.X * 0.32, vp.Y * 0.47)
		local extent = 2 * R + 1.4 -- 막대까지
		-- 화면의 좁은 쪽에 맞춤 (세로 화면에서 옆으로 넘치지 않게)
		local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
		local tanMin = math.min(tanV, tanV * vp.X / vp.Y)
		local dist = extent / (2 * tanMin * (portrait and 0.62 or 0.78))
		local camCF = camera.CFrame
		local target = ray.Origin + ray.Direction * dist + camCF.UpVector * 0.55
		local face = CFrame.lookAt(target, camCF.Position, camCF.UpVector) * CFrame.Angles(-math.pi / 2, 0, 0)
		return CFrame.new(target) * CFrame.fromAxisAngle(camCF.UpVector, rock) * (face - face.Position)
	end

	local state = { t = 0, wrap = -1, tie = -1 }
	local function draw()
		local t = state.t
		local k = smooth(t / MOVE_T)
		local rock = math.sin(math.max(t - MOVE_T * 0.6, 0) * 1.5) * ROCK_A * math.min(math.max(t - MOVE_T * 0.6, 0) / 0.6, 1)
		local base = R0:Lerp(finalBase(rock), k)
		for i, p in ipairs(parts) do
			if p.Parent then
				p.CFrame = base * rel[i]
			end
		end
		-- 포장
		if state.wrap >= 0 and bag3 then
			-- 입체 비닐: 위에서 내려와 씌워지고, 목이 주름지며 오므라듦
			local w = smooth(state.wrap / WRAP_T)
			local n = smooth((state.wrap - WRAP_T * 0.7) / (WRAP_T * 0.5))
			if math.abs(n - gathered) > 0.02 then
				gathered = n
				bag3.shape(n)
			end
			bag3.part.Transparency = 1 - 0.32 * w
			bag3.part.CFrame = base * CFrame.new(bag3.center + Vector3.new(0, 0, (1 - w) * R * 3.2))
		elseif state.wrap >= 0 then
			local w = smooth(state.wrap / WRAP_T)
			bag.Transparency = 1 - 0.3 * w
			bag.CFrame = base * CFrame.new(0, 0.02, -0.05 + (1 - w) * bagL * 1.4)
			-- 목은 씌운 뒤 오므라듦
			local n = smooth((state.wrap - WRAP_T * 0.7) / (WRAP_T * 0.5))
			neck.Transparency = 1 - 0.3 * n
			neck.Size = Vector3.new(0.5 - 0.22 * n, 0.16, 0.42)
			neck.CFrame = base * CFrame.new(0, 0.02, neckZ)
		end
		if state.tie >= 0 then
			local tk = smooth(state.tie / TIE_T)
			tie.Transparency = 1 - tk
			tie.CFrame = base * CFrame.new(0, 0.02, tieZ) * CFrame.Angles(0, math.rad(90), 0)
			-- 꼬인 두 가닥이 막대를 돌며 감김 (두 바퀴) → 양옆으로 비스듬히 뻗음
			local spin = (1 - tk) * math.pi * 4
			for i, e in ipairs(tails) do
				local side = i == 1 and 1 or -1
				e.Transparency = 1 - tk
				e.CFrame = base * CFrame.new(0, 0.02, tieZ) * CFrame.Angles(0, 0, spin) * CFrame.Angles(0, side * math.rad(55), 0) * CFrame.new(0, 0, -0.16)
			end
		end
	end

	-- ① 떠올라 와서 돌기
	while state.t < MOVE_T + 0.5 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		state.t += dt
		draw()
	end
	-- ② 포장지 씌우기 → 빵끈. 카메라는 항공뷰에서 정면으로 내려와 세운 달고나를 마주 봄 (2026-11-20)
	CameraRig.goFront(c, 0.9)
	local tc = 0
	while tc < 0.9 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		tc += dt
		state.t += dt
		draw()
	end
	Sfx.play("pop", 0.4, 0.8)
	state.wrap = 0
	while state.wrap < WRAP_T * 1.3 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		state.t += dt
		state.wrap += dt
		draw()
	end
	state.tie = 0
	Sfx.play("metalClink", 0.3, 1.8)
	while state.tie < TIE_T do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		state.t += dt
		state.wrap += dt
		state.tie += dt
		draw()
	end
	Sfx.play("pop", 0.5, 1.3)
	ctx.ui:buzz(0.3, 0.05)
	-- ③ 완성 창이 떠 있는 동안 계속 천천히 돎
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not (parts[1] and parts[1].Parent) or not bag.Parent or (bag3 and not bag3.part.Parent) then
			conn:Disconnect()
			return
		end
		state.t += dt
		state.wrap += dt
		state.tie += dt
		draw()
	end)
	return conn
end

return Showcase
