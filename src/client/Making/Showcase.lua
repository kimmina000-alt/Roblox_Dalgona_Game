-- 다 만든 달고나 보여 주기 (2026-11-20 사용자 요청)
--   ① 달고나(막대·금·자국 포함, 포장했으면 비닐·빵끈까지)가 화면 정중앙으로 천천히 떠올라 크게 보이고, 좌우로 살짝 돌며 옆면이 보임
--   ② 그다음 완성 창 (MakingClient가 띄움). 완성 창이 뜨면 창에 안 가리게 옆으로 비켜서 계속 천천히 돎
-- 포장은 Making/Pack (테이블 오른쪽 포장 공간에서 플레이어가 직접, 할지 말지 고름)

local RunService = game:GetService("RunService")

local Showcase = {}

local MOVE_T = 1.3 -- 떠올라 오는 시간
local HOLD_T = 1.2 -- 정중앙에서 보여 주는 시간
local SIDE_T = 0.5 -- 완성 창 옆으로 비키는 시간
local ROCK_A = math.rad(22) -- 좌우로 도는 각도

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 달고나에 딸린 부품 모으기 (3D 반죽, 예전 원판 부품, 표면 무늬, 금, 자국, 막대)
function Showcase.collect(S, dal, st)
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

-- ctx.frame()으로 기다리며 연출. extras = 같이 움직일 부품 (비닐·빵끈). 끝나면 계속 도는 연결을 돌려줌 (반죽이 사라지면 저절로 멈춤)
function Showcase.run(ctx, dal, st, extras)
	local S = ctx.station
	local parts = Showcase.collect(S, dal, st)
	if #parts == 0 then
		return nil
	end
	for _, p in ipairs(extras or {}) do
		if p and p:IsA("BasePart") and p.Parent then
			table.insert(parts, p)
		end
	end
	local R = dal:radius()
	local c = dal.center
	local dir = (st.stick and st.stick.dir) or Vector3.new(0, 0, 1)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, 1)
	-- 기준 틀: 가운데 = 달고나 가운데(놓인 면), 앞(-Z) = 막대 방향, 위(+Y) = 윗면
	local R0 = CFrame.lookAt(c, c + dir)
	local rel = {}
	-- 화면에 맞출 크기: 놓인 면(기준 틀 X·Z) 위 실제 상자 (막대까지, 포장했으면 비닐까지).
	-- 2026-11-20 플레이 테스트: 예전엔 2R+4로 잘라서 포장째면 위가 화면 밖으로 잘림.
	-- 3D 반죽 부품은 메시 여백이 커서 크기 대신 반지름으로 셈
	local batterPart = dal.batter and dal.batter.part
	local x0, x1, z0, z1 = -R - 0.7, R + 0.7, -R - 0.7, R + 0.7
	for i, p in ipairs(parts) do
		rel[i] = R0:ToObjectSpace(p.CFrame)
		p.Anchored = true
		if p ~= batterPart then
			local h = p.Size / 2
			for _, s in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1) }) do
				for _, sg in ipairs({ 1, -1 }) do
					local q = rel[i] * (h * s * sg)
					x0, x1 = math.min(x0, q.X), math.max(x1, q.X)
					z0, z1 = math.min(z0, q.Z), math.max(z1, q.Z)
				end
			end
		end
	end
	-- 가운데가 달고나 가운데라서 양쪽으로 같은 폭이 필요 (치우친 쪽 기준)
	local reachMax = 2 * math.max(-x0, x1, -z0, z1)

	local camera = workspace.CurrentCamera
	-- side 0 = 화면 정중앙, 1 = 완성 창 옆 (가로 화면: 왼쪽 가운데, 세로 화면(폰): 위쪽 가운데)
	local function finalBase(rock, side)
		local vp = camera.ViewportSize
		local portrait = vp.X < vp.Y
		local sx, sy = 0.5, 0.46
		if portrait then
			sy = 0.46 + (0.3 - 0.46) * side
		else
			sx = 0.5 + (0.32 - 0.5) * side
		end
		local ray = camera:ViewportPointToRay(vp.X * sx, vp.Y * sy)
		local extent = reachMax -- 막대·비닐까지 다 들어오게
		-- 화면의 좁은 쪽에 맞춤 (세로 화면에서 옆으로 넘치지 않게)
		local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
		local tanMin = math.min(tanV, tanV * vp.X / vp.Y)
		local dist = extent / (2 * tanMin * (portrait and 0.62 or 0.78))
		local camCF = camera.CFrame
		local target = ray.Origin + ray.Direction * dist + camCF.UpVector * 0.55
		local face = CFrame.lookAt(target, camCF.Position, camCF.UpVector) * CFrame.Angles(-math.pi / 2, 0, 0)
		return CFrame.new(target) * CFrame.fromAxisAngle(camCF.UpVector, rock) * (face - face.Position)
	end

	local t = 0
	local function draw()
		local k = smooth(t / MOVE_T)
		local rt = math.max(t - MOVE_T * 0.6, 0)
		local rock = math.sin(rt * 1.5) * ROCK_A * math.min(rt / 0.6, 1)
		local side = smooth((t - MOVE_T - HOLD_T) / SIDE_T)
		local base = R0:Lerp(finalBase(rock, side), k)
		for i, p in ipairs(parts) do
			if p.Parent then
				p.CFrame = base * rel[i]
			end
		end
	end

	-- ① 떠올라 와서 정중앙에서 돌기
	while t < MOVE_T + HOLD_T do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		draw()
	end
	-- ② 완성 창이 떠 있는 동안: 옆으로 비켜서 계속 천천히 돎
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not (parts[1] and parts[1].Parent) then
			conn:Disconnect()
			return
		end
		t += dt
		draw()
	end)
	return conn
end

return Showcase
