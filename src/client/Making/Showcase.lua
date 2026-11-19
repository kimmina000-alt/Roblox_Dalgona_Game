-- 다 만든 달고나 보여 주기 + 포장 (2026-11-20 사용자 요청)
--   ① 철판 위 달고나(막대·금·자국 포함)가 화면 가운데 쪽으로 천천히 떠올라 크게 보이고, 좌우로 살짝 돌며 옆면이 보임
--   ② 투명 비닐 포장지가 위에서 씌워지고, 막대 쪽 목이 오므라든 뒤 빵끈(금색 철사 끈)이 감겨 묶임
--   ③ 그다음 완성 창 (MakingClient가 띄움). 돌아가는 움직임은 완성 창이 떠 있는 동안 계속
-- 결과 창이 화면 오른쪽에 뜨므로 달고나는 화면 왼쪽 가운데(가로 32%)에 둠

local RunService = game:GetService("RunService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))

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
		if state.wrap >= 0 then
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
	-- ② 포장지 씌우기 → 빵끈
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
		if not (parts[1] and parts[1].Parent) or not bag.Parent then
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
