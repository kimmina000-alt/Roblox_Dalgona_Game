-- 국자 속 설탕이 녹는 모습 4단계 (실제 영상 YqKNy2l802c 0:54~1:16 분석, docs/MOTION_REFERENCE_ANALYSIS.md 8장)
--   A 가루      (녹은 정도 p < 0.3) : 흰 무광 가루 판. 젓가락이 지나간 자리에 소용돌이 홈이 패이고 그대로 남음
--   B 결정      (0.3 ~ 0.5)       : 가루가 갑자기 2~4 mm 흰 덩어리로 뭉침, 덩어리 사이로 구리 바닥이 보임.
--                                   p 0.42부터 가운데에 맑은 액체 웅덩이가 생김
--   B→C 반쯤    (0.5 ~ 0.72)      : 웅덩이가 바깥으로 번지고, 덩어리는 유리처럼 비치며 작아져 사라짐 (가운데·젓가락 근처 먼저)
--   C 액체      (0.72 ~ 1)        : 투명한 호박색, 구리 바닥이 비침, 작은 기포 점, 남은 흰 실 몇 개가 떠다니다 사라짐
--   끝: 젓가락을 들면 끈적한 실이 늘어났다 끊김
-- Melt.lua가 매 프레임 update를 부른다.

local Making = script.Parent
local Fx = require(Making:WaitForChild("Fx"))
local Heat = require(Making:WaitForChild("Heat"))

local SugarLook = {}
SugarLook.__index = SugarLook

local POWDER = Color3.fromRGB(246, 244, 240)
local GROOVE = Color3.fromRGB(184, 176, 166)
local LUMP = Color3.fromRGB(250, 250, 248)
local MAX_GROOVES = 90
local LUMPS = 90

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

function SugarLook.new(S, st)
	local self = setmetatable({}, SugarLook)
	self.S, self.st = S, st
	self.Ri = S.bowlRadius - 0.12
	self.stirred = 0
	self.grooves = {}
	self.lastTip = nil
	self.lumps = {}
	self.threads = {}
	self.bubbles = {}
	self.bubbleAcc = 0
	self.folder = Instance.new("Folder")
	self.folder.Name = "FxSugarLook"
	self.folder.Parent = S.Ladle
	-- 웅덩이 (원기둥, 축 = X = 위)
	self.pool = part(self.folder, {
		Name = "Pool",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 1,
		Size = Vector3.new(0.02, 0.01, 0.01),
	})
	-- 결정 덩어리: 가운데에서 가까운 것부터 녹음 (+ 약간 무작위)
	for i = 1, LUMPS do
		local r = math.sqrt(math.random()) * self.Ri * 0.95
		local a = math.random() * 2 * math.pi
		local s = 0.06 + math.random() * 0.05
		local p = Fx.mesh("SugarCrystal", self.folder, { Name = "Lump", Color = LUMP, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
			or part(self.folder, { Name = "Lump", Color = LUMP, Transparency = 1 })
		table.insert(self.lumps, {
			part = p,
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			s = s,
			squash = 0.6 + math.random() * 0.4,
			rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			pm = 0.55 + 0.17 * (r / self.Ri) + (math.random() - 0.5) * 0.08,
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
	return self
end

function SugarLook:center()
	local b = self.S.Bowl.Position
	return Vector3.new(b.X, self.S:contentsTopY(), b.Z)
end

-- 가루 단계: 젓가락 끝이 지나간 자리에 홈을 남김
function SugarLook:addGroove(tip)
	local c = self:center()
	local rel = Vector3.new(tip.X - c.X, 0, tip.Z - c.Z)
	if rel.Magnitude > self.Ri then
		rel = rel.Unit * self.Ri
	end
	if self.lastTip and (rel - self.lastTip).Magnitude < 0.06 then
		return
	end
	if self.lastTip and (rel - self.lastTip).Magnitude < 0.4 then
		local g
		if #self.grooves >= MAX_GROOVES then
			g = table.remove(self.grooves, 1)
		else
			g = { part = part(self.folder, { Name = "Groove", Color = GROOVE, Material = Enum.Material.Sand }) }
		end
		g.a, g.b = self.lastTip, rel
		table.insert(self.grooves, g)
	end
	self.lastTip = rel
end

-- p = 녹은 정도 0~1, tip = 젓는 중이면 젓가락 끝 (Vector3), 아니면 nil
function SugarLook:update(dt, p, tip, burn)
	local S, st = self.S, self.st
	local c = self:center()
	if tip then
		self.stirred += dt
	else
		self.lastTip = nil
	end
	-- A: 저을수록 쌓인 더미가 평평한 가루 판이 되고, 떨어진 알갱이도 가루에 섞임
	local flat = smooth01(self.stirred, 0, 2.5)
	local toLumps = smooth01(p, 0.28, 0.36) -- A → B 갑자기 뭉침
	if st.pile and st.pileD then
		local k = (1 - flat * 0.85) * (1 - toLumps)
		Fx.placeDome(st.pile, Vector3.new(c.X, c.Y - 0.01, c.Z), st.pileD * (1 + 0.15 * flat), math.max(st.pileH * k, 0.005), 0.7)
		st.pile.Transparency = (k < 0.03) and 1 or 0
	end
	local visible = math.ceil(#st.grains * (1 - flat))
	for i, g in ipairs(st.grains) do
		g.Transparency = (i <= visible and toLumps < 0.5) and 0 or 1
	end
	S:setContents({
		Color = POWDER:Lerp(Heat.meltColor(0.3, burn), burn > 0 and 0.6 or 0),
		Material = Enum.Material.Sand,
		Transparency = math.min(0.999, toLumps), -- 1이면 국자 위치 계산이 바뀌어서 0.999까지만
	})
	if tip and toLumps < 0.5 then
		self:addGroove(tip)
	end
	for _, g in ipairs(self.grooves) do
		local a, b = c + g.a, c + g.b
		local mid = (a + b) / 2 + Vector3.new(0, 0.004, 0)
		local len = (b - a).Magnitude
		g.part.Size = Vector3.new(0.055, 0.012, len + 0.03)
		g.part.CFrame = CFrame.lookAt(mid, mid + (b - a))
		g.part.Transparency = toLumps
	end
	-- 웅덩이: B 후반 가운데에서 생겨 바깥으로 번짐
	local liquidCol = Heat.meltColor(math.max(p, 0.85), burn) -- 맑은 호박색 (구리 바닥이 비침)
	local pr = self.Ri * smooth01(p, 0.42, 0.72)
	if pr > 0.01 then
		self.pool.Transparency = 0.4
		self.pool.Color = liquidCol
		self.pool.Size = Vector3.new(0.02, pr * 2, pr * 2)
		self.pool.CFrame = CFrame.new(c + Vector3.new(0, 0.006, 0)) * CFrame.Angles(0, 0, math.rad(90))
	else
		self.pool.Transparency = 1
	end
	-- 결정 덩어리: 젓가락에 밀려 굴러다니고, 유리처럼 비치며 작아지다 사라짐
	local lumpCol = LUMP:Lerp(Heat.meltColor(0.5, burn), burn > 0 and 0.7 or 0)
	for _, l in ipairs(self.lumps) do
		if tip then
			local d = Vector3.new(c.X + l.x - tip.X, 0, c.Z + l.z - tip.Z)
			if d.Magnitude < 0.16 then
				local push = (d.Magnitude > 1e-3 and d.Unit or Vector3.xAxis) * (0.16 - d.Magnitude)
				l.x += push.X
				l.z += push.Z
				local rr = math.sqrt(l.x * l.x + l.z * l.z)
				if rr > self.Ri * 0.95 then
					l.x, l.z = l.x / rr * self.Ri * 0.95, l.z / rr * self.Ri * 0.95
				end
				l.rot = l.rot * CFrame.Angles(push.Z * 8, 0, -push.X * 8)
				l.extra += dt * 0.08 -- 젓가락 근처가 먼저 녹음
			end
		end
		local g = smooth01(p + l.extra, l.pm - 0.12, l.pm)
		if toLumps <= 0 or g >= 1 then
			l.part.Transparency = 1
		else
			l.part.Transparency = math.max(1 - toLumps, 0.5 * g)
			l.part.Material = g > 0.15 and Enum.Material.Glass or Enum.Material.SmoothPlastic
			l.part.Color = lumpCol:Lerp(liquidCol, 0.4 * g)
			local s = l.s * (0.6 + 0.4 * toLumps) * (1 - 0.85 * g)
			l.part.Size = Vector3.new(s, s * l.squash, s)
			l.part.CFrame = CFrame.new(c.X + l.x, c.Y + s * l.squash * 0.35, c.Z + l.z) * l.rot
		end
	end
	-- C: 남은 흰 실이 떠다니다 사라지고, 작은 기포 점이 생겼다 꺼짐
	local thr = (p >= 0.66) and smooth01(p, 0.7, 0.9) or 1
	for _, t in ipairs(self.threads) do
		t.a += dt * 0.25
		t.yaw += dt * t.spin
		if p < 0.66 then
			t.part.Transparency = 1
		else
			t.part.Transparency = 0.25 + 0.75 * thr
			t.part.CFrame = CFrame.new(c + Vector3.new(math.cos(t.a) * t.r, 0.01, math.sin(t.a) * t.r)) * CFrame.Angles(0, t.yaw, 0)
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
			d = 0.015 + math.random() * 0.02,
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
			b.part.CFrame = CFrame.new(c + Vector3.new(b.x, 0.008, b.z))
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

-- 다 녹음: 국자 속은 투명한 호박색 액체 하나로. 젓가락을 들면 끈적한 실이 늘어났다 끊김
function SugarLook:finish(burn, tip)
	local S = self.S
	S:setContents({ Color = Heat.meltColor(1, burn), Material = Enum.Material.Glass, Transparency = 0.3 })
	local c = self:center()
	local from = tip and Vector3.new(tip.X, c.Y, tip.Z) or c
	self.folder:Destroy()
	local thread = Instance.new("Part")
	thread.Name = "FxSyrupThread"
	thread.Anchored, thread.CanCollide, thread.CanQuery, thread.CanTouch, thread.CastShadow = true, false, false, false, false
	thread.Material = Enum.Material.Glass
	thread.Color = Heat.meltColor(1, burn)
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
