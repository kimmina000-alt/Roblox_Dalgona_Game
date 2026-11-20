-- 포장 (2026-11-20 사용자 요청): 모양 찍기까지 끝나고 결과를 본 뒤 플레이어가 포장할지 고르면,
-- 테이블 오른쪽 포장 공간(StallDecor.packArea: 포장 매트 + 네모 비닐 통 + 빵끈 통)에서 직접 포장.
--   ① 달고나가 철판에서 포장 매트로 옮겨짐 (막대가 앞쪽을 향하게 놓임)
--   ② 비닐 통에서 네모난 투명 비닐을 끌어 달고나 위에 놓으면 쏙 씌워짐 (통을 톡 누르기만 해도 됨)
--   ③ 빵끈 통을 눌러 금색 끈을 집고, 쓱 끌기 두 번: 한 번에 비닐 아랫부분이 반쯤 오므라들고, 두 번째에 꽉 묶임
--      (참고 사진: 네모난 비닐 윗부분은 그대로, 막대 쪽 아랫부분이 모여 금색 끈으로 감기고 끈 끝이 양옆으로 뻗음)
-- 실패·점수 없음. 손을 안 대고 있으면 IDLE_T초 뒤 알아서 마저 함. 다 되면 비닐·끈 부품 목록을 돌려줌 (Showcase가 같이 띄움)

local AssetService = game:GetService("AssetService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local CameraRig = require(script.Parent:WaitForChild("CameraRig"))
local Showcase = require(script.Parent:WaitForChild("Showcase"))

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
local NA, NS = 40, 44
local function buildBag(parent, R, zNeck)
	local ok, res = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local zTop = R * 1.18
		local zEnd = zNeck - 0.45
		local zBody = -R * 0.9 -- 여기서부터 목 쪽으로 모임 (달고나 아래 끝 바로 밑)
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
		local center = Vector3.new(0, yc, (zTop + 0.05 + zEnd - 0.05) / 2)
		local B = R * 1.3
		local p1 = em:AddVertex(Vector3.new(-B, yc - 0.3, zEnd - 0.05) - center)
		local p2 = em:AddVertex(Vector3.new(-B + 0.001, yc - 0.3, zEnd - 0.05) - center)
		local p3 = em:AddVertex(Vector3.new(B, yc + 0.3, zTop + 0.05) - center)
		local p4 = em:AddVertex(Vector3.new(B - 0.001, yc + 0.3, zTop + 0.05) - center)
		em:AddTriangle(p1, p2, p1)
		em:AddTriangle(p3, p4, p3)
		local self = {}
		function self.shape(g)
			local W0 = R * 1.2
			for i = 1, NS do
				local s = (i - 1) / (NS - 1)
				local z, w, t, amp
				if s <= 0.8 then
					z = zTop + (zNeck - zTop) * (s / 0.8)
					-- 네모 봉투: 위쪽 모서리만 살짝 둥글고 옆은 곧음. 맨 위 이음매는 얇게
					local d = zTop - z
					local capLen = R * 0.16
					local f = d < capLen and math.sqrt(math.max(0, 1 - (1 - d / capLen) ^ 2)) or 1
					local W, T = W0 * (1 - 0.14 * (1 - f)), 0.23 * math.sqrt(f)
					if z < zBody then
						local u = smooth((zBody - z) / (zBody - zNeck))
						w = W + (0.07 - W) * u * g
						t = T + (0.05 - T) * u * g
						amp = g * 0.22 * u
					else
						w, t, amp = W, T, 0
					end
				else
					-- 끈 아래 끝자락: 묶으면 짧게 퍼진 주름, 안 묶었으면 네모 그대로
					local v = (s - 0.8) / 0.2
					z = zNeck + (zEnd - zNeck) * v
					local wt = 0.07 + (R * 0.42 - 0.07) * v ^ 0.7
					local tt = 0.05 + (0.1 - 0.05) * v
					w = W0 + (wt - W0) * g
					t = 0.23 + (tt - 0.23) * g
					amp = g * 0.25
				end
				for j = 1, NA do
					local a = (j - 1) / NA * 2 * math.pi
					local m = 1 + amp * math.sin(8 * a + i * 0.35) -- 모인 곳의 비닐 주름
					-- 단면은 납작한 둥근 사각형: 가장자리까지 두께가 남아서 달고나가 비닐을 뚫고 나오지 않음
					local ca, sa = math.cos(a), math.sin(a)
					ca = (ca < 0 and -1 or 1) * math.abs(ca) ^ 0.5
					sa = (sa < 0 and -1 or 1) * math.abs(sa) ^ 0.6
					em:SetPosition(verts[i][j], Vector3.new(w * ca * m, yc + t * sa * m, z) - center)
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
		mp.Reflectance = 0.3
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
	local fwd = ws:GetPivot():VectorToWorldSpace(Vector3.new(0, 0, 1)) -- 테이블 앞(플레이어 쪽, 화면 아래)
	fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
	local m = mat.Position + Vector3.new(0, mat.Size.Y / 2, 0)

	-- ① 카메라를 포장 공간으로, 달고나를 매트로 (살짝 들어 올려 옮김. 막대가 앞쪽(화면 아래)을 향하게)
	CameraRig.goPoint(m + Vector3.new(0, 0, -0.9), 11.5, 0.3)
	local parts = Showcase.collect(S, dal, st)
	local c = dal.center
	local dir = (st.stick and st.stick.dir) or fwd
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or fwd
	local R0 = CFrame.lookAt(c, c + dir)
	local R1 = CFrame.lookAt(m, m + fwd)
	local rel = {}
	for i, p in ipairs(parts) do
		rel[i] = R0:ToObjectSpace(p.CFrame)
		p.Anchored = true
	end
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
		st.stick.dir = fwd
	end
	Sfx.play("pop", 0.4, 0.9)

	-- 비닐 (막대 쪽 -Z가 목)
	local R = dal:radius()
	local reach = 1
	for _, v in ipairs(dal.dropOutline or {}) do
		reach = math.max(reach, v)
	end
	local Rb = R * reach * 1.04
	local neckZ = -(Rb * 1.2 + 0.18)
	local bag3 = buildBag(S.fx, Rb, neckZ)
	if not bag3 then
		return {}
	end
	local rot = R1 - R1.Position
	local function bagAt(pos, lift)
		bag3.part.CFrame = (rot + pos + Vector3.new(0, lift or 0, 0)) * CFrame.new(bag3.center)
	end

	-- ② 비닐 씌우기: 비닐 통에서 끌어 달고나 위에 놓기 (통을 톡 누르기만 해도 날아가 씌워짐)
	ui:say("비닐에 넣어요", "비닐 통에서 비닐을 끌어 달고나 위에 놓아요")
	local seen = P.presses
	local grab = nil -- { start = 화면 위치, moved = bool }
	local idle = 0
	local placed = false
	local function flyBag(from)
		-- from(세계) → 달고나 위로 날아와 내려앉음
		local tt = 0
		bag3.part.Transparency = 0.68
		while tt < 0.35 do
			local dt = ctx.frame()
			if not dt then
				return false
			end
			tt += dt
			local k = smooth(tt / 0.35)
			bagAt(from:Lerp(m, k), (1 - k) * 0.5 + math.sin(math.pi * k) * 0.3)
		end
		bagAt(m, 0)
		Sfx.play("pop", 0.35, 1.5)
		ui:buzz(0.3, 0.05)
		return true
	end
	while not placed do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		local boxS = screenOf(bagBox.Position)
		ui:setWorldTip(not grab and "비닐" or nil, boxS - Vector2.new(0, 46))
		if P.down and P.presses ~= seen and not grab then
			seen = P.presses
			if (P.pos - boxS).Magnitude < GRAB_PX then
				grab = { start = P.pos, moved = false }
				bag3.part.Transparency = 0.68
				Sfx.play("pop", 0.3, 1.3)
			else
				ui:hint("뒤쪽 비닐 통을 눌러요")
			end
		end
		if grab then
			idle = 0
			if (P.pos - grab.start).Magnitude > 20 then
				grab.moved = true
			end
			local at = P.toPlane(m.Y + 0.5)
			bagAt(Vector3.new(at.X, m.Y, at.Z), 0.5)
			if not P.down then
				local fromPos = Vector3.new(at.X, m.Y, at.Z)
				local near = Vector3.new(at.X - m.X, 0, at.Z - m.Z).Magnitude < Rb * 1.8
				if near or not grab.moved then
					-- 달고나 위에 놓았거나, 톡 누르기만 함 → 씌워짐
					if not flyBag(grab.moved and fromPos or bagBox.Position) then
						return nil
					end
					placed = true
				else
					ui:hint("달고나 위에 놓아요")
					bag3.part.Transparency = 1
				end
				grab = nil
			end
		else
			idle += dt
			if idle > IDLE_T then
				if not flyBag(bagBox.Position) then
					return nil
				end
				placed = true
			end
		end
	end
	ui:setWorldTip(nil)

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
	ui:say("끈으로 묶어요", "쓱 끌기 두 번! 비닐 아래가 모이며 묶여요")
	local done = 0 -- 끝낸 끌기 수 (0~2)
	local dragStart = nil
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
			end
			local d = (P.pos - dragStart).Magnitude
			target = (done + math.min(d / DRAG_PX, 1) * 0.9) * 0.5
		elseif dragStart then
			local d = (P.pos - dragStart).Magnitude
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
