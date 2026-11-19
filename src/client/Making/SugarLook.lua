-- 국자 속 설탕이 녹는 모습 (실제 영상 YqKNy2l802c 0:54~1:16 분석 + 사용자 요청 2026-11-18)
--   A 가루      (녹은 정도 p < 0.3) : 고운 흰 가루. 동그라미 홈 없이 아주 작은 점들로 표현하고, 젓가락이 지나가면 점이 밀려남
--   B 결정      (0.3 ~ 0.5)       : 가루가 많은 흰 결정으로 뭉침. 밑에 갈색 설탕물이 살짝 깔림
--   B→C 녹는 중 (0.5 ~ 0.72)      : 결정이 유리처럼 비치며 작아지고, 갈색 물이 점점 차오름
--   C 액체      (0.72 ~ 1)        : 투명한 갈색 물이 가득, 작은 기포 점, 남은 흰 실 몇 개가 떠다니다 사라짐
--   젓가락 끝: 녹기 시작하면 설탕물이 묻어 점점 맺힘 (소다 단계까지 그대로)
--   끝: 젓가락을 들면 끈적한 실이 늘어났다 끊김
-- Melt.lua가 매 프레임 update를 부른다.

local Making = script.Parent
local Fx = require(Making:WaitForChild("Fx"))
local Heat = require(Making:WaitForChild("Heat"))

local SugarLook = {}
SugarLook.__index = SugarLook

local POWDER = Color3.fromRGB(246, 244, 240)
local DOT_COLORS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(236, 233, 228), Color3.fromRGB(222, 218, 212) }
local LUMP = Color3.fromRGB(250, 250, 248)
local SYRUP_BROWN = Color3.fromRGB(118, 60, 20)
local STICK_DIR = Vector3.new(0.35, 1, 0.55).Unit -- Stir.placeChopsticksAt와 같은 젓가락 방향
local DOTS = 340
local LUMPS = 560 -- 결정 많이 (2026-11-19 "결정이 더 많으면 좋겠음")
-- 가루 → 결정은 녹은 정도 TRANS_A ~ TRANS_B 사이에서 서서히 (사용자 요청 2026-11-18: 너무 갑자기 바뀜).
-- 점 하나하나·결정 하나하나가 자기 차례(문턱)에 천천히 사라지고/생겨서, 가루 사이로 결정이 조금씩 늘어남
local TRANS_A, TRANS_B = 0.2, 0.48
local FADE = 0.07 -- 점·결정 하나가 사라지거나 자라는 데 걸리는 녹은 정도 폭
-- 젓는 자국: 가루 위에 젓가락이 지나간 골 (잠깐 남았다가 가루가 덮음)
local FURROW_MAX = 70
local FURROW_STEP = 0.035
local FURROW_LIFE = 0.9
local FURROW_COLOR = Color3.fromRGB(214, 206, 196)

local function smooth01(x, a, b)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- 설탕물 색 (갈색 물, 탈수록 진함)
function SugarLook.syrupColor(p, burn)
	return Heat.meltColor(math.max(p, 0.85), burn):Lerp(SYRUP_BROWN, 0.6)
end

function SugarLook.new(S, st)
	local self = setmetatable({}, SugarLook)
	self.S, self.st = S, st
	self.Ri = S.bowlRadius - 0.12
	self.stirred = 0
	self.lastTip = nil
	self.dots = {}
	self.lumps = {}
	self.threads = {}
	self.bubbles = {}
	self.bubbleAcc = 0
	self.fullThick = math.max(S.Contents.Size.X, 0.05) -- 다 녹았을 때 설탕물 높이 = 처음 설탕 높이
	self.folder = Instance.new("Folder")
	self.folder.Name = "FxSugarLook"
	self.folder.Parent = S.Ladle
	-- 가루: 아주 작은 점들 (흰색·연회색)
	for i = 1, DOTS do
		local r = math.sqrt(math.random()) * self.Ri * 0.97
		local a = math.random() * 2 * math.pi
		local s = 0.012 + math.random() * 0.014
		table.insert(self.dots, {
			part = part(self.folder, { Name = "Dot", Shape = Enum.PartType.Ball, Color = DOT_COLORS[i % 3 + 1], Transparency = 1, Size = Vector3.new(s, s * 0.6, s) }),
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			h = 0, -- 젓가락에 튀어 오른 높이 (금방 가라앉음)
			out = TRANS_A + (TRANS_B - FADE - TRANS_A) * math.random(), -- 이 녹은 정도부터 사라짐
		})
	end
	-- 설탕물 (국자 바닥 전체, 원기둥 축 = X = 위). 결정 단계부터 얇게 깔렸다가 차오름
	self.pool = part(self.folder, {
		Name = "Pool",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 1,
		Size = Vector3.new(0.01, self.Ri * 2, self.Ri * 2),
	})
	-- 결정: 많고 작게. 가운데·젓가락 근처부터 녹고, 몇 개는 끝까지 남음
	for i = 1, LUMPS do
		local r = math.sqrt(math.random()) * self.Ri * 0.95
		local a = math.random() * 2 * math.pi
		local s = 0.045 + math.random() * 0.05
		local p = Fx.mesh("SugarCrystal", self.folder, { Name = "Lump", Color = LUMP, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
			or part(self.folder, { Name = "Lump", Color = LUMP, Transparency = 1 })
		table.insert(self.lumps, {
			part = p,
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			s = s,
			squash = 0.6 + math.random() * 0.4,
			rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			pm = 0.52 + 0.3 * math.random() + 0.12 * (r / self.Ri),
			ap = TRANS_A + 0.02 + (TRANS_B - FADE - TRANS_A - 0.02) * math.random() ^ 0.8, -- 이 녹은 정도부터 자라남
			extra = 0,
		})
	end
	-- 액체 단계에 떠다니는 흰 실 (남은 결정)
	for _ = 1, 4 do
		local a = math.random() * 2 * math.pi
		table.insert(self.threads, {
			part = part(self.folder, { Name = "Thread", Color = LUMP, Transparency = 1, Size = Vector3.new(0.014, 0.008, 0.12 + math.random() * 0.16) }),
			a = a,
			r = (0.25 + math.random() * 0.5) * self.Ri,
			yaw = math.random() * 6,
			spin = (math.random() - 0.5) * 0.6,
		})
	end
	-- 젓는 자국 조각 (재사용)
	self.furrows = {}
	self.furrowNext = 1
	self.furrowDist = 0
	for _ = 1, FURROW_MAX do
		table.insert(self.furrows, { part = part(self.folder, { Name = "Furrow", Color = FURROW_COLOR, Transparency = 1, Size = Vector3.new(0.05, 0.004, 0.05) }), t = math.huge })
	end
	-- 젓가락 끝에서 피어오르는 고운 가루 (빠르게 저을 때)
	self.dust = part(self.folder, { Name = "DustAnchor", Transparency = 1, Size = Vector3.one * 0.05 })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Dust"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	pe.LightEmission = 0.2
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.025), NumberSequenceKeypoint.new(1, 0.06) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.25, 0.5)
	pe.Speed = NumberRange.new(0.15, 0.4)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Acceleration = Vector3.new(0, -0.6, 0)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rate = 0
	pe.Parent = self.dust
	self.dustPe = pe
	return self
end

-- 젓는 자국 하나 (from → to, 가루 윗면 y)
function SugarLook:addFurrow(from, to, y)
	local f = self.furrows[self.furrowNext]
	self.furrowNext = self.furrowNext % FURROW_MAX + 1
	local len = (to - from).Magnitude
	if len < 1e-3 then
		return
	end
	f.t = 0
	f.len = len + 0.03
	f.cf = CFrame.lookAt(Vector3.new((from.X + to.X) / 2, y, (from.Z + to.Z) / 2), Vector3.new(to.X, y, to.Z))
end

function SugarLook:base()
	local b = self.S.Bowl.Position
	return Vector3.new(b.X, b.Y + self.S.floor, b.Z)
end

function SugarLook:center()
	local b = self.S.Bowl.Position
	return Vector3.new(b.X, self.S:contentsTopY(), b.Z)
end

-- 젓가락 끝에 묻는 설탕 (고른 젓가락에 붙어서 같이 움직임). 사용자 요청 2026-11-19:
-- 녹이는 동안 설탕에 담긴 끝부분에 설탕이 묻어 색이 점점 진해짐 — 흰 가루 → 반투명 결정 → 맑은 호박색 → (탈수록) 진한 갈색
local COAT_POWDER = Color3.fromRGB(250, 248, 242)
local COAT_CRYSTAL = Color3.fromRGB(240, 214, 160)
function SugarLook:coatTip(tip, amount, burn, p)
	local st, S = self.st, self.S
	local stick = S.Chopsticks:FindFirstChild("Chosen") or S.Chopsticks:FindFirstChild("Stick1")
	if not stick then
		return
	end
	local coat = st.tipCoat
	if not coat or not coat.Parent then
		local dir = S.stickDir or STICK_DIR
		local center = tip + dir * 0.12 -- 끝에서 젓가락 위쪽으로 묻음
		coat = Instance.new("Part")
		coat.Name = "FxTipCoat"
		coat.Shape = Enum.PartType.Ball
		coat.Material = Enum.Material.Glass
		coat.Transparency = 0.25
		coat.CanCollide, coat.CanQuery, coat.CanTouch, coat.CastShadow = false, false, false, false
		coat.Massless = true
		coat.Anchored = false
		coat.Size = Vector3.new(0.02, 0.02, 0.05)
		coat.CFrame = CFrame.lookAt(center, center + dir)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = stick
		weld.Part1 = coat
		weld.Parent = coat
		coat.Parent = S.fx
		st.tipCoat = coat
	end
	p = p or 1
	local col
	if p < 0.3 then
		col = COAT_POWDER
		coat.Material = Enum.Material.Sand
		coat.Transparency = 0
	elseif p < 0.6 then
		col = COAT_POWDER:Lerp(COAT_CRYSTAL, (p - 0.3) / 0.3)
		coat.Material = Enum.Material.Glass
		coat.Transparency = 0.15
	else
		col = COAT_CRYSTAL:Lerp(SugarLook.syrupColor(1, burn), math.clamp((p - 0.6) / 0.4, 0, 1))
		coat.Material = Enum.Material.Glass
		coat.Transparency = 0.2
	end
	if burn > 0 then
		col = col:Lerp(SugarLook.syrupColor(1, burn), math.min(1, burn * 2))
	end
	coat.Color = col
	-- 위에서도 보이게 굵고 길게 (2026-11-19 "설탕 묻은 게 안 보임")
	local w = 0.06 + 0.06 * amount
	coat.Size = Vector3.new(w, w, 0.14 + 0.2 * amount)
end

-- p = 녹은 정도 0~1, tip = 젓는 중이면 젓가락 끝 (Vector3), 아니면 nil
function SugarLook:update(dt, p, tip, burn)
	local S, st = self.S, self.st
	local c = self:center()
	local vel = Vector3.zero
	if tip then
		self.stirred += dt
		if self.lastTip then
			vel = Vector3.new(tip.X - self.lastTip.X, 0, tip.Z - self.lastTip.Z)
		end
		self.lastTip = tip
	else
		self.lastTip = nil
	end
	-- A: 저을수록 쌓인 더미가 평평한 가루가 되고, 떨어진 알갱이도 가루에 섞임
	local flat = smooth01(self.stirred, 0, 2.5)
	local toLumps = smooth01(p, TRANS_A, TRANS_B) -- A → B 결정으로 서서히 뭉침
	if st.pile and st.pileD then
		local k = (1 - flat * 0.85) * (1 - toLumps)
		Fx.placeDome(st.pile, Vector3.new(c.X, c.Y - 0.01, c.Z), st.pileD * (1 + 0.15 * flat), math.max(st.pileH * k, 0.005), 0.7)
		st.pile.Transparency = (k < 0.03) and 1 or 0
		if burn > 0 then -- 불에 너무 가까우면 더미도 갈색 → 검게
			st.pile.Color = POWDER:Lerp(Heat.meltColor(0.3, burn), math.min(1, burn * 1.5))
		end
	end
	local visible = math.ceil(#st.grains * (1 - flat) * (1 - toLumps))
	for i, g in ipairs(st.grains) do
		g.Transparency = i <= visible and 0 or 1
	end
	S:setContents({
		Color = POWDER:Lerp(Heat.meltColor(0.3, burn), burn > 0 and 0.6 or 0),
		Material = Enum.Material.Sand,
		Transparency = math.min(0.999, toLumps), -- 1이면 국자 위치 계산이 바뀌어서 0.999까지만
	})
	-- 가루 점: 젓가락이 지나가면 앞쪽 가루는 밀려 나가고 옆으로 갈라져 쌓임(쟁기질), 살짝 튀었다 가라앉음.
	-- 지나간 자리에는 골(젓는 자국)이 잠깐 남음. 빠르게 저으면 고운 가루가 피어오름
	local speed = dt > 0 and vel.Magnitude / dt or 0
	local inPowder = toLumps < 0.8
	if tip and inPowder then
		if self.lastFurrow then
			local seg = Vector3.new(tip.X - self.lastFurrow.X, 0, tip.Z - self.lastFurrow.Z)
			if seg.Magnitude >= FURROW_STEP then
				self:addFurrow(self.lastFurrow, tip, c.Y + 0.002)
				self.lastFurrow = tip
			end
		else
			self.lastFurrow = tip
		end
		self.dust.CFrame = CFrame.new(tip.X, c.Y + 0.02, tip.Z)
		self.dustPe.Rate = math.clamp((speed - 0.8) * 25, 0, 60) * (1 - toLumps)
	else
		self.lastFurrow = nil
		self.dustPe.Rate = 0
	end
	for _, f in ipairs(self.furrows) do
		if f.t < FURROW_LIFE then
			f.t += dt
			local k = f.t / FURROW_LIFE
			f.part.Transparency = math.min(1, 0.3 + 0.7 * k + toLumps)
			f.part.Size = Vector3.new(0.055 * (1 - 0.4 * k), 0.004, f.len)
			f.part.CFrame = f.cf
		elseif f.part.Transparency < 1 then
			f.part.Transparency = 1
		end
	end
	local vmag = vel.Magnitude
	local vdir = vmag > 1e-4 and vel / vmag or nil
	local parts, cfs = {}, {}
	for _, d in ipairs(self.dots) do
		local gone = smooth01(p, d.out, d.out + FADE)
		if gone >= 1 then
			d.part.Transparency = 1
		else
			if tip then
				local dx, dz = c.X + d.x - tip.X, c.Z + d.z - tip.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				local R0 = 0.17
				if dist < R0 then
					local f = (R0 - dist) / R0
					local nx, nz = dist > 1e-3 and dx / dist or 1, dist > 1e-3 and dz / dist or 0
					if vdir then
						-- 앞에 있는 가루는 같이 밀리고, 옆의 가루는 바깥으로 갈라짐
						local ahead = nx * vdir.X + nz * vdir.Z
						local sx, sz = nx - ahead * vdir.X, nz - ahead * vdir.Z
						local push = math.min(vmag, 0.12)
						d.x += vdir.X * push * f * (0.5 + 0.5 * math.max(ahead, 0)) + sx * push * f * 1.1
						d.z += vdir.Z * push * f * (0.5 + 0.5 * math.max(ahead, 0)) + sz * push * f * 1.1
						d.h = math.max(d.h, f * math.min(speed, 4) * 0.012)
					else
						d.x += nx * f * 0.004
						d.z += nz * f * 0.004
					end
					local rr = math.sqrt(d.x * d.x + d.z * d.z)
					if rr > self.Ri * 0.97 then
						d.x, d.z = d.x / rr * self.Ri * 0.97, d.z / rr * self.Ri * 0.97
					end
				end
			end
			d.h *= math.exp(-dt * 12)
			d.part.Transparency = math.max(flat < 0.05 and 0.6 or 0, gone)
			table.insert(parts, d.part)
			table.insert(cfs, CFrame.new(c.X + d.x, c.Y + 0.003 + d.h, c.Z + d.z))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	-- 설탕물: 결정 단계부터 바닥에 얇게 → 녹을수록 차오름
	local base = self:base()
	local level = self.fullThick * (0.12 + 0.88 * smooth01(p, 0.32, 1))
	local syrup = SugarLook.syrupColor(p, burn)
	if toLumps > 0 then
		self.pool.Transparency = 1 - 0.85 * toLumps -- 구리 바닥이 살짝만 비치게 (갈색이 보이도록)
		self.pool.Color = syrup
		self.pool.Size = Vector3.new(level, self.Ri * 2, self.Ri * 2)
		self.pool.CFrame = CFrame.new(base + Vector3.new(0, level / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	else
		self.pool.Transparency = 1
	end
	local surface = base.Y + level
	-- 결정: 바닥에 깔려 있다가 젓가락에 밀리고, 물이 차오르며 유리처럼 비치고 작아져 사라짐
	local lumpCol = LUMP:Lerp(Heat.meltColor(0.5, burn), burn > 0 and 0.7 or 0)
	for _, l in ipairs(self.lumps) do
		if tip then
			local dx, dz = c.X + l.x - tip.X, c.Z + l.z - tip.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < 0.14 then
				local push = (0.14 - dist)
				local nx, nz = dist > 1e-3 and dx / dist or 1, dist > 1e-3 and dz / dist or 0
				l.x += nx * push + vel.X * 0.4
				l.z += nz * push + vel.Z * 0.4
				local rr = math.sqrt(l.x * l.x + l.z * l.z)
				if rr > self.Ri * 0.95 then
					l.x, l.z = l.x / rr * self.Ri * 0.95, l.z / rr * self.Ri * 0.95
				end
				l.rot = l.rot * CFrame.Angles(nz * push * 8, 0, -nx * push * 8)
				l.extra += dt * 0.08 -- 젓가락 근처가 먼저 녹음
			end
		end
		local g = smooth01(p + l.extra, l.pm - 0.14, l.pm)
		local grow = smooth01(p, l.ap, l.ap + FADE) -- 자기 차례에 작게 생겨 천천히 커짐
		if grow <= 0 or g >= 1 then
			l.part.Transparency = 1
		else
			l.part.Transparency = math.max(1 - grow, 0.55 * g)
			l.part.Material = g > 0.15 and Enum.Material.Glass or Enum.Material.SmoothPlastic
			l.part.Color = lumpCol:Lerp(syrup, 0.45 * g)
			local s = l.s * (0.25 + 0.75 * grow) * (1 - 0.85 * g)
			l.part.Size = Vector3.new(s, s * l.squash, s)
			l.part.CFrame = CFrame.new(c.X + l.x, base.Y + s * l.squash * 0.5, c.Z + l.z) * l.rot
		end
	end
	-- 젓가락 끝 설탕: 저으면 처음부터 가루가 묻고, 녹을수록 색이 진해지며 두껍게 맺힘
	if tip and (self.stirred > 0.3 or p > 0.05) then
		self:coatTip(tip, 0.25 + 0.75 * smooth01(p, 0.05, 1), burn, p)
	end
	-- C: 남은 흰 실이 떠다니다 사라지고, 작은 기포 점이 생겼다 꺼짐 (물 위에)
	local thr = (p >= 0.66) and smooth01(p, 0.7, 0.9) or 1
	for _, t in ipairs(self.threads) do
		t.a += dt * 0.25
		t.yaw += dt * t.spin
		if p < 0.66 then
			t.part.Transparency = 1
		else
			t.part.Transparency = 0.25 + 0.75 * thr
			t.part.CFrame = CFrame.new(c.X + math.cos(t.a) * t.r, surface + 0.004, c.Z + math.sin(t.a) * t.r) * CFrame.Angles(0, t.yaw, 0)
		end
	end
	self.bubbleAcc += (p > 0.78 and 5 or 0) * dt
	while self.bubbleAcc >= 1 do
		self.bubbleAcc -= 1
		local a, r = math.random() * 2 * math.pi, math.sqrt(math.random()) * self.Ri * 0.9
		table.insert(self.bubbles, {
			t = 0,
			life = 0.5 + math.random() * 0.4,
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			d = 0.012 + math.random() * 0.015,
			part = part(self.folder, { Name = "Bubble", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 236, 190), Transparency = 1 }),
		})
	end
	for i = #self.bubbles, 1, -1 do
		local b = self.bubbles[i]
		b.t += dt
		local k = b.t / b.life
		if k >= 1 then
			b.part:Destroy()
			table.remove(self.bubbles, i)
		else
			local s = b.d * math.min(1, k * 3)
			b.part.Size = Vector3.one * math.max(s, 0.005)
			b.part.Transparency = 0.35 + 0.65 * math.max(0, (k - 0.7) / 0.3)
			b.part.CFrame = CFrame.new(c.X + b.x, surface + 0.003, c.Z + b.z)
		end
	end
	if p < 0.3 then
		return "가루"
	elseif p < 0.5 then
		return "결정"
	elseif p < 0.72 then
		return "녹는 중"
	end
	return "액체"
end

-- 다 녹음: 국자 속은 투명한 갈색 설탕물 하나로. 젓가락을 들면 끈적한 실이 늘어났다 끊김
function SugarLook:finish(burn, tip)
	local S = self.S
	S:setContents({ Color = SugarLook.syrupColor(1, burn), Material = Enum.Material.Glass, Transparency = 0.3 })
	local c = self:center()
	local from = tip and Vector3.new(tip.X, c.Y, tip.Z) or c
	self.folder:Destroy()
	local thread = Instance.new("Part")
	thread.Name = "FxSyrupThread"
	thread.Anchored, thread.CanCollide, thread.CanQuery, thread.CanTouch, thread.CastShadow = true, false, false, false, false
	thread.Material = Enum.Material.Glass
	thread.Color = SugarLook.syrupColor(1, burn)
	thread.Transparency = 0.2
	thread.Parent = S.fx
	task.spawn(function()
		local t = 0
		while t < 0.45 and thread.Parent do
			t += task.wait()
			local k = math.min(t / 0.35, 1)
			local top = from + Vector3.new(0.1 * k, 0.6 * k, 0.05 * k)
			local len = (top - from).Magnitude
			local w = 0.035 * (1 - 0.8 * k)
			thread.Size = Vector3.new(w, math.max(len, 0.01), w)
			thread.CFrame = CFrame.lookAt((from + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0)
			if t > 0.35 then
				thread.Transparency = 0.2 + 0.8 * (t - 0.35) / 0.1
			end
		end
		thread:Destroy()
	end)
end

function SugarLook:destroy()
	if self.folder then
		self.folder:Destroy()
	end
end

return SugarLook
