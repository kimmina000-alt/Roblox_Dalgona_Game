-- 포장 (2026-11-20 사용자 요청): 모양 찍기까지 끝나고 결과를 본 뒤 플레이어가 포장할지 고르면,
-- 테이블 오른쪽 포장 공간(StallDecor.packArea: 포장 매트 + 네모 비닐 통 + 빵끈 통)에서 직접 포장.
--   ① 달고나가 철판에서 포장 매트로 옮겨지며 정방향으로 놓임 (달고나 위, 막대 아래 = ㅇ / ㅣ)
--   ② 비닐 통(매트 오른쪽)을 누르면 비닐이 달고나 위쪽에 놓이고, 아래로 끌어 씌움 (사선으로 틀지 않음).
--      비닐 크기는 달고나 실제 외곽선에 맞춤 (길쭉하거나 큰 달고나도 비닐 밖으로 안 나옴, 2026-11-20)
--   ③ 빵끈 통을 눌러 끈을 집어 빙글 돌리거나 쓱 끌기 두 번으로 묶음
--      (참고 사진: 네모난 비닐 윗부분은 그대로, 막대 쪽 아랫부분이 모여 금색 끈으로 감기고 끈 끝이 양옆으로 뻗음)
-- 실패·점수 없음. 손을 안 대고 있으면 IDLE_T초 뒤 알아서 마저 함. 다 되면 비닐·끈 부품 목록을 돌려줌 (Showcase가 같이 띄움)

local AssetService = game:GetService("AssetService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local CameraRig = require(script.Parent:WaitForChild("CameraRig"))
local Showcase = require(script.Parent:WaitForChild("Showcase"))
local Stick = require(script.Parent:WaitForChild("Steps"):WaitForChild("Stick"))

local Pack = {}

local BAG = Color3.fromRGB(248, 250, 255)
local TIE = Color3.fromRGB(226, 176, 52)
local GRAB_PX = 130 -- 통 화면 위치에서 이만큼 안을 누르면 집음
local DRAG_PX = 110 -- 끈 묶기: 한 번에 이만큼 이상 끌어야 한 번으로 침
local IDLE_T = 8
local MOVE_T = 0.8

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 네모난 투명 비닐 (EditableMesh). 기준 틀: 가운데 = 달고나 가운데(놓인 면), -Z = 막대 쪽, +Y = 위.
-- gather(0~1): 0 = 막 씌운 네모 봉투, 1 = 막대 쪽 아랫부분이 모여 꽉 묶임 (윗부분 네모는 그대로)
-- D (2026-11-20 "포장 후 비닐 밖으로 튀어나오는 달고나"): 달고나 실제 외곽선에 맞춘 크기
--   hw = 비닐 반폭, zTop = 비닐 윗끝, zNeck = 끈 자리, zc·rz = 달고나 세로 가운데·반길이, rx = 달고나 반폭, xoff = 가로 치우침
local NA, NS = 40, 44
local function buildBag(parent, D)
	local ok, res = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local W0, zTop, zNeck, zc, rz, rx, xoff = D.hw, D.zTop, D.zNeck, D.zc, D.rz, D.rx, D.xoff
		local zEnd = zNeck - 0.45
		local yc = 0.1
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
				-- 바깥 면 한 겹만 (두 겹이면 얼룩무늬)
				em:AddTriangle(a, d, b)
				em:AddTriangle(a, c, d)
			end
		end
		-- 경계 고정 (가운데 기준 좌표)
		local center = Vector3.new(xoff, yc, (zTop + 0.05 + zEnd - 0.05) / 2)
		local B = W0 * 1.1
		local p1 = em:AddVertex(Vector3.new(xoff - B, yc - 0.3, zEnd - 0.05) - center)
		local p2 = em:AddVertex(Vector3.new(xoff - B + 0.001, yc - 0.3, zEnd - 0.05) - center)
		local p3 = em:AddVertex(Vector3.new(xoff + B, yc + 0.3, zTop + 0.05) - center)
		local p4 = em:AddVertex(Vector3.new(xoff + B - 0.001, yc + 0.3, zTop + 0.05) - center)
		em:AddTriangle(p1, p2, p1)
		em:AddTriangle(p3, p4, p3)
		local self = {}
		function self.shape(g)
			-- 묶었을 때 폭 (2026-11-20 "달고나 모양에 맞춰서 비닐 아래 좁아지게, 너무 사각임"):
			-- 위쪽 절반은 네모 그대로, 가운데 아래로는 달고나 가장자리(타원)를 따라 좁아지다가 막대 쪽 끈에서 꽉 모임
			local zLow = zc - rz * 0.55
			local function tiedW(z)
				local q = math.clamp((z - zc) / rz, -1, 1)
				local round = (rx * 1.07 + 0.08) * math.sqrt(math.max(0, 1 - q * q))
				local neckU = smooth((z - zNeck) / (zLow - zNeck))
				round = math.max(round, 0.07 + rx * 0.3 * neckU)
				local k = smooth((zc + rz * 0.3 - z) / (rz * 0.3))
				return W0 + (math.min(round, W0) - W0) * k
			end
			for i = 1, NS do
				local s = (i - 1) / (NS - 1)
				local z, w, t, amp
				if s <= 0.8 then
					z = zTop + (zNeck - zTop) * (s / 0.8)
					-- 네모 봉투: 위쪽 모서리만 살짝 둥글고 옆은 곧음. 맨 위 이음매는 얇게
					local d = zTop - z
					local capLen = W0 * 0.14
					local f = d < capLen and math.sqrt(math.max(0, 1 - (1 - d / capLen) ^ 2)) or 1
					local W, T = W0 * (1 - 0.14 * (1 - f)), 0.23 * math.sqrt(f)
					local u = smooth((zc - rz * 0.6 - z) / (zc - rz * 0.6 - zNeck)) -- 끈 가까이 (주름·얇아짐)
					w = W + (math.min(tiedW(z), W) - W) * g
					t = T + (0.05 - T) * u * g
					amp = g * 0.22 * u
				else
					-- 끈 아래 끝자락: 묶으면 짧게 퍼진 주름, 안 묶었으면 네모 그대로
					local v = (s - 0.8) / 0.2
					z = zNeck + (zEnd - zNeck) * v
					local wt = 0.07 + (W0 * 0.35 - 0.07) * v ^ 0.7
					local tt = 0.05 + (0.1 - 0.05) * v
					w = W0 + (wt - W0) * g
					t = 0.23 + (tt - 0.23) * g
					amp = g * 0.25
				end
				-- 묶이는 쪽은 막대(가로 0) 쪽으로 모임
				local x0 = xoff * (1 - g * smooth((zc - z) / math.max(zc - zNeck, 0.1)))
				for j = 1, NA do
					local a = (j - 1) / NA * 2 * math.pi
					local m = 1 + amp * math.sin(8 * a + i * 0.35) -- 모인 곳의 비닐 주름
					-- 단면은 납작한 둥근 사각형: 가장자리까지 두께가 남아서 달고나가 비닐을 뚫고 나오지 않음
					local ca, sa = math.cos(a), math.sin(a)
					ca = (ca < 0 and -1 or 1) * math.abs(ca) ^ 0.5
					sa = (sa < 0 and -1 or 1) * math.abs(sa) ^ 0.6
					em:SetPosition(verts[i][j], Vector3.new(x0 + w * ca * m, yc + t * sa * m, z) - center)
				end
			end
		end
		self.shape(0)
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = "PackBag"
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.CastShadow = false
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = BAG
		mp.Reflectance = 0.04 -- 0.3이면 하늘이 비쳐 달고나가 보라색으로 보임 (2026-11-20 플레이 테스트)
		mp.Transparency = 1
		mp.Parent = parent
		mp.Destroying:Connect(function()
			em:Destroy()
		end)
		self.part = mp
		self.center = center
		return self
	end)
	if ok then
		return res
	end
	warn("[Pack] 비닐을 만들 수 없어요:", res)
	return nil
end

local function screenOf(p)
	local v, vis = workspace.CurrentCamera:WorldToScreenPoint(p)
	return Vector2.new(v.X, v.Y), vis
end

-- 포장하기. 돌려줌: 같이 띄울 부품 목록 (취소되면 nil). 포장 공간이 없으면 빈 목록
function Pack.run(ctx, dal, st)
	local S, P, ui = ctx.station, ctx.pointer, ctx.ui
	local ws = workspace:FindFirstChild("DalgonaWorkstation")
	local area = ws and ws:FindFirstChild("PackArea")
	local mat = area and area:FindFirstChild("Mat")
	local bagBox = area and area:FindFirstChild("BagTop")
	local cup = area and area:FindFirstChild("TieCup")
	if not (mat and bagBox and cup) then
		return {}
	end
	local function wait(sec)
		local t = 0
		while t < sec do
			local dt = ctx.frame()
			if not dt then
				return false
			end
			t += dt
		end
		return true
	end
	-- 2026-11-20 (폰 사진): 달고나는 처음부터 정방향 (ㅇ 위, ㅣ 막대 아래 = 화면 아래·플레이어 쪽)으로 매트에 놓고,
	-- 비닐은 위(화면 위쪽)에서 내려와 씌움. 사선으로 틀지 않음
	local pivot = ws:GetPivot()
	local down = pivot:VectorToWorldSpace(Vector3.new(0, 0, 1)) -- 막대 방향 = 화면 아래
	down = Vector3.new(down.X, 0, down.Z).Unit
	local up = -down -- 비닐이 내려오는 쪽
	local m = mat.Position + Vector3.new(0, mat.Size.Y / 2, 0)

	-- 달고나 실제 외곽선 (매트에 놓인 틀 기준). 비닐 크기를 여기에 맞춰서 길쭉하거나 큰 달고나도 비닐 밖으로 안 나옴
	local R = dal:radius()
	local c = dal.center
	local dir = (st.stick and st.stick.dir) or down
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or down
	local R0 = CFrame.lookAt(c, c + dir)
	local x0, x1, z0, z1 = -R, R, -R, R
	local outline = dal.dropOutline
	local bat = dal.batter
	if outline and bat and bat.cos and #outline > 0 then
		x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for k, o in ipairs(outline) do
			local q = R0:PointToObjectSpace(c + Vector3.new(bat.cos[k] * o * R, 0, bat.sin[k] * o * R))
			x0, x1 = math.min(x0, q.X), math.max(x1, q.X)
			z0, z1 = math.min(z0, q.Z), math.max(z1, q.Z)
		end
	end

	-- ① 카메라를 포장 공간으로, 달고나를 매트로 (살짝 들어 올려 옮기며 정방향으로 돌림)
	local parts = Showcase.collect(S, dal, st)
	local R1 = CFrame.lookAt(m, m + down)
	-- 매트 위에서 달고나+막대가 가운데 오게 (막대가 길어서 조금 위로)
	local stickLen = 0
	for _, p in ipairs(parts) do
		if st.stickModel and p:IsDescendantOf(st.stickModel) then
			local q = R0:PointToObjectSpace(p.Position)
			stickLen = math.max(stickLen, -q.Z + math.max(p.Size.X, p.Size.Y, p.Size.Z) / 2 - (-z0))
		end
	end
	R1 = R1 + up * math.clamp(stickLen * 0.35, 0, 1.0)
	m = R1.Position
	local rel = {}
	for i, p in ipairs(parts) do
		rel[i] = R0:ToObjectSpace(p.CFrame)
		p.Anchored = true
	end

	-- 비닐 (막대 쪽 -Z가 목)
	local xoff = (x0 + x1) / 2
	local hw = math.max((x1 - x0) / 2 + 0.3, R * 1.15) -- 동그란 달고나면 예전 크기(1.2 R) 그대로
	local zTop = z1 + 0.35
	local neckZ = math.min(-(R * 1.2 + 0.18), z0 - 0.35)
	local D = { hw = hw, zTop = zTop, zNeck = neckZ, zc = (z0 + z1) / 2, rz = (z1 - z0) / 2, rx = (x1 - x0) / 2, xoff = xoff }
	-- 비닐이 처음 놓이는 자리: 달고나 위쪽(화면 위)으로 조금, 그리고 공중에 LIFT만큼 떠 있음.
	-- 아래로 끌면 내려오면서 씌워짐 (2026-11-20 "위에서 비닐 내려와서 씌우는"). 테이블 밖으로 안 나가게 짧게
	local OUT = math.max(R * 0.7, 1.2)
	local LIFT = 1.4
	-- 카메라: 막대 끝 ~ 처음 비닐 윗끝이 다 보이게. 빵끈 통(매트 오른쪽 아래)도 안 잘리게 (2026-11-20 사용자 요청)
	local lowZ = z0 - stickLen - 0.4
	local cupZ = (cup.Position - m):Dot(up) - 0.7
	lowZ = math.min(lowZ, cupZ)
	local highZ = zTop + OUT
	local span = highZ - lowZ
	local camH = math.clamp(span / (2 * math.tan(math.rad(20)) * 0.74), 11, 20)
	CameraRig.goPoint(m + up * ((highZ + lowZ) / 2), camH, 0.3)

	local t = 0
	while t < MOVE_T do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		local k = smooth(t / MOVE_T)
		local frame = R0:Lerp(R1, k) + Vector3.new(0, math.sin(math.pi * k) * 1.2, 0)
		for i, p in ipairs(parts) do
			if p.Parent then
				p.CFrame = frame * rel[i]
			end
		end
	end
	for i, p in ipairs(parts) do
		if p.Parent then
			p.CFrame = R1 * rel[i]
		end
	end
	dal.center = m
	if st.stick then
		st.stick.dir = down
		-- 철판에서 테두리에 걸치느라 살짝 들렸던 막대를 매트 위에 평평하게 (2026-11-20 "막대 끝이 끊겨 보임")
		Stick.follow(st, true)
	end
	Sfx.play("pop", 0.4, 0.9)
	-- 이제부터 달고나(+막대)는 R1 기준
	parts = Showcase.collect(S, dal, st)
	local rel1 = {}
	for i, p in ipairs(parts) do
		rel1[i] = R1:ToObjectSpace(p.CFrame)
	end
	local function placeDal(frame)
		for i, p in ipairs(parts) do
			if p.Parent then
				p.CFrame = frame * rel1[i]
			end
		end
	end

	local bag3 = buildBag(S.fx, D)
	if not bag3 then
		return {}
	end
	local rot = R1 - R1.Position
	local function bagAt(pos, lift)
		bag3.part.CFrame = (rot + pos + Vector3.new(0, lift or 0, 0)) * CFrame.new(bag3.center)
	end

	-- ② 비닐 씌우기: 비닐 통을 누르면 비닐 한 장이 달고나 위쪽(화면 위)에 놓이고, 아래로 끌어 달고나에 씌움.
	--    손을 안 대면 IDLE_T초 뒤 알아서
	local slide = OUT -- 지금 비닐 자리 (위로 떨어진 거리, 0 = 다 씌움)
	local function flyTo(from, toSlide, lift0, dur)
		local tt = 0
		local s0 = slide
		while tt < dur do
			local dt = ctx.frame()
			if not dt then
				return false
			end
			tt += dt
			local k = smooth(tt / dur)
			local to = m + up * toSlide
			bagAt(from:Lerp(to, k), (lift0 or 0) * (1 - k) + LIFT * toSlide / OUT * k + math.sin(math.pi * k) * 0.25)
			slide = s0 + (toSlide - s0) * k
			Sfx.loop("bagRustle", 0.5, 1.1)
		end
		Sfx.loop("bagRustle", 0, 1)
		slide = toSlide
		bagAt(m + up * toSlide, LIFT * toSlide / OUT)
		return true
	end
	ui:say("비닐에 넣어요", "비닐 통을 눌러 비닐을 꺼내요")
	local seen = P.presses
	local idle = 0
	local out = false
	while not out do
		local dt = ctx.frame()
		if not dt then
			ui:setWorldTip(nil)
			return nil
		end
		local boxS = screenOf(bagBox.Position)
		ui:setWorldTip("비닐", boxS - Vector2.new(0, 46))
		idle += dt
		if (P.down and P.presses ~= seen) or idle > IDLE_T then
			seen = P.presses
			if idle > IDLE_T or (P.pos - boxS).Magnitude < GRAB_PX then
				out = true
			else
				ui:hint("오른쪽 비닐 통을 눌러요")
			end
		end
	end
	ui:setWorldTip(nil)
	Sfx.play("bagYank", 0.7, 1.1)
	bag3.part.Transparency = 0.68
	-- 비닐은 화면 밖 위쪽에서 내려와 달고나 위에 떠 있음 (2026-11-20 "포장 비닐 화면 밖 상단에서부터 내려오기")
	local startPos
	do
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		local sx = screenOf(m + up * OUT).X
		local ray = cam:ViewportPointToRay(sx, -vp.Y * 0.3)
		local y = m.Y + LIFT
		local dy = ray.Direction.Y
		local tHit = (math.abs(dy) > 1e-3) and (y - ray.Origin.Y) / dy or 20
		startPos = ray.Origin + ray.Direction * math.max(tHit, 1)
		startPos = Vector3.new(startPos.X, m.Y, startPos.Z)
	end
	if not flyTo(startPos, OUT, LIFT, 0.6) then
		return nil
	end
	ui:say("비닐에 넣어요", "비닐을 아래로 끌어 달고나에 씌워요")
	seen = P.presses
	idle = 0
	local grab = nil -- 누른 순간의 (손가락 자리 - 비닐 자리) 거리
	while slide > 0.001 do
		local dt = ctx.frame()
		if not dt then
			ui:setWorldTip(nil)
			return nil
		end
		-- 끌기 안내는 비닐 가운데쯤 (위쪽 끝은 안내 문구와 겹침)
		local bagS = screenOf(m + up * (slide + zTop * 0.2))
		ui:setWorldTip(not grab and "↓ 끌어요" or nil, bagS)
		if P.down and P.presses ~= seen and not grab then
			seen = P.presses
			local at = P.toPlane(m.Y)
			grab = (at - m):Dot(up) - slide
		end
		if grab then
			idle = 0
			local at = P.toPlane(m.Y)
			local want = math.clamp((at - m):Dot(up) - grab, 0, OUT)
			local before = slide
			slide += (want - slide) * (1 - math.exp(-dt / 0.05))
			bagAt(m + up * slide, LIFT * slide / OUT)
			-- 끄는 빠르기만큼 바스락
			Sfx.loop("bagRustle", math.clamp(math.abs(slide - before) / math.max(dt, 1e-3) * 0.25, 0, 0.8), 1)
			if not P.down then
				grab = nil
				if slide < OUT * 0.35 then
					-- 거의 다 씌웠으면 쏙 들어감
					if not flyTo(m + up * slide, 0, LIFT * slide / OUT, 0.15) then
						return nil
					end
					slide = 0
				end
			end
		else
			Sfx.loop("bagRustle", 0, 1)
			idle += dt
			if idle > IDLE_T then
				if not flyTo(m + up * slide, 0, LIFT * slide / OUT, 0.5) then
					return nil
				end
				slide = 0
			end
		end
	end
	Sfx.stop("bagRustle")
	ui:setWorldTip(nil)
	bagAt(m, 0)
	placeDal(R1)
	Sfx.play("pop", 0.35, 1.5)
	ui:buzz(0.3, 0.05)

	-- ③ 빵끈: 끈 통을 눌러 집기 → 쓱 끌기 두 번
	local tieZ = neckZ
	local tie = S:fxPart(S.fx, { Name = "PackTie", Shape = Enum.PartType.Cylinder, Color = TIE, Material = Enum.Material.Metal, Transparency = 1, Size = Vector3.new(0.09, 0.3, 0.3) })
	local tails = {}
	for i = 1, 2 do
		tails[i] = S:fxPart(S.fx, { Name = "PackTieEnd", Color = TIE, Material = Enum.Material.Metal, Transparency = 1, Size = Vector3.new(0.12, 0.025, 0.36) })
	end
	local held = S:fxPart(S.fx, { Name = "PackTieHeld", Color = TIE, Material = Enum.Material.Metal, Transparency = 1, Size = Vector3.new(0.1, 0.025, 0.8) })
	local function drawTie(g)
		-- g: 0 = 목에 느슨하게 걸침, 1 = 꽉 감겨 끝이 양옆으로 뻗음
		local spin = (1 - g) * math.pi * 3
		local ring = 0.3 - 0.16 * g
		tie.Size = Vector3.new(0.09, ring, ring)
		tie.CFrame = R1 * CFrame.new(0, 0.1, tieZ) * CFrame.Angles(0, math.rad(90), 0)
		for i, e in ipairs(tails) do
			local side = i == 1 and 1 or -1
			e.CFrame = R1 * CFrame.new(0, 0.1, tieZ) * CFrame.Angles(0, 0, spin) * CFrame.Angles(0, side * math.rad(60 + 20 * g), 0) * CFrame.new(0, 0, -0.18 - 0.04 * g)
		end
	end
	ui:say("포장끈을 골라요", "빵끈 통을 눌러 금색 끈을 집어요")
	seen = P.presses
	idle = 0
	local picked = false
	while not picked do
		local dt = ctx.frame()
		if not dt then
			ui:setWorldTip(nil)
			return nil
		end
		local cupS = screenOf(cup.Position)
		ui:setWorldTip("빵끈", cupS - Vector2.new(0, 46))
		idle += dt
		if (P.down and P.presses ~= seen) or idle > IDLE_T then
			seen = P.presses
			if idle > IDLE_T or (P.pos - cupS).Magnitude < GRAB_PX then
				picked = true
			else
				ui:hint("오른쪽 뒤 빵끈 통을 눌러요")
			end
		end
	end
	ui:setWorldTip(nil)
	Sfx.play("metalClink", 0.35, 1.6)
	-- 집은 끈이 통에서 비닐 목으로 날아가 느슨하게 걸쳐짐
	do
		local neckW = (R1 * CFrame.new(0, 0.1, tieZ)).Position
		local tt = 0
		held.Transparency = 0
		while tt < 0.35 do
			local dt = ctx.frame()
			if not dt then
				return nil
			end
			tt += dt
			local k = smooth(tt / 0.35)
			local p = cup.Position:Lerp(neckW, k) + Vector3.new(0, math.sin(math.pi * k) * 0.8, 0)
			held.CFrame = CFrame.new(p) * CFrame.Angles(0, k * math.pi, 0)
		end
		held:Destroy()
		tie.Transparency = 0
		for _, e in ipairs(tails) do
			e.Transparency = 0
		end
		drawTie(0)
	end
	ui:say("빵끈을 돌려 묶어요", "빙글 돌리거나 쓱 끌기 두 번! 비닐 아래가 모이며 묶여요")
	local done = 0 -- 끝낸 끌기 수 (0~2)
	local dragStart = nil
	local dragLen, lastPos = 0, nil -- 이번에 끈(돌린) 길이: 직선이든 동그라미든 움직인 만큼
	local gNow, gShown = 0, -1
	seen = P.presses
	idle = 0
	while done < 2 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		local target = done * 0.5
		if P.down then
			idle = 0
			if not dragStart or P.presses ~= seen then
				seen = P.presses
				dragStart = P.pos
				dragLen, lastPos = 0, P.pos
			end
			local moved = (P.pos - lastPos).Magnitude
			dragLen += moved
			lastPos = P.pos
			-- 돌리는(끄는) 빠르기만큼 비닐이 바스락
			Sfx.loop("bagRustle", math.clamp(moved / math.max(dt, 1e-3) / 900, 0, 0.8), 1.15)
			local d = dragLen
			target = (done + math.min(d / DRAG_PX, 1) * 0.9) * 0.5
		elseif dragStart then
			Sfx.loop("bagRustle", 0, 1)
			local d = dragLen
			dragStart = nil
			if d >= DRAG_PX * 0.8 then
				done += 1
				target = done * 0.5
				Sfx.play("metalClink", 0.3, 1.4 + 0.3 * done)
				ui:buzz(0.35, 0.06)
				ui:toast(done == 1 and "한 번 더!" or "꽉 묶었어요!", 0.6)
			end
		else
			idle += dt
			if idle > IDLE_T then
				done = math.min(2, done + 1)
				idle = IDLE_T - 0.5
			end
		end
		gNow += (target - gNow) * (1 - math.exp(-dt / 0.06))
		if math.abs(gNow - gShown) > 0.015 then
			gShown = gNow
			bag3.shape(gNow)
		end
		drawTie(gNow)
	end
	-- 마저 꽉
	Sfx.stop("bagRustle")
	Sfx.play("bagYank", 0.4, 1.6)
	while gNow < 0.995 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		gNow = math.min(1, gNow + dt * 3)
		bag3.shape(gNow)
		drawTie(gNow)
	end
	Sfx.play("pop", 0.5, 1.3)
	ui:say("포장 완료!", "")
	if not wait(0.4) then
		return nil
	end
	local out = { bag3.part, tie }
	for _, e in ipairs(tails) do
		table.insert(out, e)
	end
	return out
end

return Pack
