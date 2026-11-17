-- 3. 소다: ① 나무젓가락 끝에 소다를 묻혀(소다 통 → 국자로 끌기) 톡. 넣은 횟수 = 양 (2~3번이 알맞음, 실제 영상 YqKNy2l802c 1:17)
--          ② 불에서 떼고 빠르게 젓기 (이번엔 FAST 쪽이 정답, 불 가까이 저으면 금방 탐) → 실제 영상처럼 3.5초 S곡선으로 부풀어 오름
--             (docs/MOTION_REFERENCE_ANALYSIS.md 7장: 느린 시작 1.1초 → 빠른 상승 1.5초 → 멈춤 0.9초 → 유지)
-- 점수: 넣은 타이밍(투명해진 직후) + 양 + 부푼 정도

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Making = script.Parent.Parent
local Stir = require(Making:WaitForChild("Stir"))
local Heat = require(Making:WaitForChild("Heat"))
local Fx = require(Making:WaitForChild("Fx"))
local Sfx = require(Making:WaitForChild("Sfx"))

local Soda = {}

local HEAP_MAX = 1.2
local DIP_AMOUNT = 0.21 -- 한 번 찍을 때 양: 1번 0.21(적음) · 2~3번 0.42~0.63(알맞음) · 4번 0.84(많음)
local MAX_DIPS = 5
local FOAM = Color3.fromRGB(214, 160, 92)
local FOAM_DARK = Color3.fromRGB(140, 86, 40)
local CREAM = Color3.fromRGB(226, 182, 118)

local function bubbles(S, on)
	local att = S.Bowl:FindFirstChild("FxBubbleAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "FxBubbleAtt"
		att.Position = Vector3.new(0.45, 0, 0)
		att.Parent = S.Bowl
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Bubbles"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 240, 210))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 0.18) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(0.3, 0.5)
		pe.Speed = NumberRange.new(0.3, 0.8)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.EmissionDirection = Enum.NormalId.Right
		pe.Shape = Enum.ParticleEmitterShape.Cylinder
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Rate = 40
		pe.Enabled = false
		pe.Parent = att
	end
	att.Bubbles.Enabled = on
end

-- ── 부풀기 (YTN 사이언스 영상 30~35초 프레임 분석) ──
-- 시계 u: 0 → 1 (빠르게 저으면 PUFF_TIME초). 높이는 S곡선: A(느린 시작) 15% · B(빠른 상승) 65% · C(멈춤) 20%
local PUFF_TIME = 3.5
local HOLD_TIME = 0.6
local PUFF_DRIVE = { [1] = 0.08, [2] = 0.35, [3] = 1 } -- 젓는 속도 구간별 시계 속도
local CURVE = { { 0, 0, 0 }, { 0.314, 0.15, 0.9 }, { 0.743, 0.80, 1.3 }, { 1, 1, 0 } } -- (u, 높이, 기울기)
-- 영상 색 (가운데 평균 RGB)을 마지막 색에 대한 비율로: 29.4s → 30.6 → 31.4 → 32.2 → 33.0
local COLOR_RAMP = {
	{ 0, Vector3.new(121, 81, 28) / Vector3.new(162, 128, 63) },
	{ 0.34, Vector3.new(135, 96, 39) / Vector3.new(162, 128, 63) },
	{ 0.57, Vector3.new(149, 112, 50) / Vector3.new(162, 128, 63) },
	{ 0.8, Vector3.new(160, 125, 62) / Vector3.new(162, 128, 63) },
	{ 1, Vector3.one },
}

local function puffCurve(u)
	u = math.clamp(u, 0, 1)
	for i = 1, #CURVE - 1 do
		local a, b = CURVE[i], CURVE[i + 1]
		if u <= b[1] then
			local dx = b[1] - a[1]
			local t = (u - a[1]) / dx
			local t2, t3 = t * t, t * t * t
			return (2 * t3 - 3 * t2 + 1) * a[2] + (t3 - 2 * t2 + t) * dx * a[3] + (-2 * t3 + 3 * t2) * b[2] + (t3 - t2) * dx * b[3]
		end
	end
	return 1
end

local function rampAt(u)
	for i = 1, #COLOR_RAMP - 1 do
		local a, b = COLOR_RAMP[i], COLOR_RAMP[i + 1]
		if u <= b[1] then
			return a[2]:Lerp(b[2], (u - a[1]) / (b[1] - a[1]))
		end
	end
	return Vector3.one
end

local function scaleColor(c, v)
	return Color3.new(math.min(1, c.R * v.X), math.min(1, c.G * v.Y), math.min(1, c.B * v.Z))
end

local function smooth01(x, a, b)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function speck(parent, props)
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

local function newPuff(S, amount, baseThick)
	local cfg = Config.Soda
	local dark = math.clamp((amount - cfg.idealMax) / 0.85, 0, 1)
	local final = FOAM:Lerp(CREAM, 0.3):Lerp(FOAM_DARK, dark)
	local pf = { u = 0, hold = 0, done = false, final = final, yaw = math.random() * 6, baseThick = baseThick, holes = {}, gloss = {}, pops = {}, popAcc = 0 }
	local start = scaleColor(final, COLOR_RAMP[1][2])
	S:setContents({ Material = Enum.Material.SmoothPlastic, Transparency = 0, Color = start })
	-- 시작 덩어리: 접힌 주름 언덕 (번들번들). 없으면 거품 돔만
	pf.mass = Fx.mesh("DalgonaMound", S.Ladle, { Name = "FxFoamMass", Color = start, Material = Enum.Material.SmoothPlastic })
	pf.foam = Fx.mesh("FoamPuff", S.Ladle, { Name = "FxFoam", Color = start, Material = Enum.Material.SmoothPlastic, Transparency = pf.mass and 1 or 0 })
		or S:fxPart(S.Ladle, { Name = "FxFoam", Shape = Enum.PartType.Ball, Color = start, Size = Vector3.one * 0.1 })
	if pf.mass then
		pf.mass.Parent = pf.foam -- 붓기 때 FxFoam과 같이 사라지게
	end
	-- 바늘구멍·작은 분화구: 30.4초(u≈0.23)부터 생기기 시작, B에서 빠르게 늘어남
	for i = 1, 42 do
		local d = (i % 7 == 0) and math.random(70, 100) / 1000 or math.random(25, 60) / 1000
		table.insert(pf.holes, {
			u0 = 0.23 + 0.52 * math.random() ^ 0.7,
			r = math.sqrt(math.random()) * 0.82,
			a = math.random() * 2 * math.pi,
			d = d,
			part = speck(pf.foam, { Name = "Hole", Shape = Enum.PartType.Cylinder, Transparency = 1, Size = Vector3.new(0.008, d, d) }),
		})
	end
	-- 처음의 번들거림: 밝은 하이라이트 점 몇 개, 무광이 되며 사라짐
	for _ = 1, 6 do
		local w = math.random(40, 90) / 1000
		table.insert(pf.gloss, {
			r = 0.15 + math.random() * 0.5,
			a = math.random() * 2 * math.pi,
			part = speck(pf.foam, { Name = "Gloss", Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 236, 200), Transparency = 1, Size = Vector3.new(0.006, w, w * 2.2) }),
		})
	end
	return pf
end

-- 돔 표면 위 점 (r = 반지름 비율, a = 각도) → 위치, 법선
local function surfaceAt(base, R, H, r, a)
	r = math.min(r, 0.97)
	local y = H * math.sqrt(1 - r * r)
	local pos = base + Vector3.new(math.cos(a) * r * R, y + 0.004, math.sin(a) * r * R)
	-- 타원 돔 법선
	local n = Vector3.new(math.cos(a) * r / R, math.sqrt(1 - r * r) / H, math.sin(a) * r / R)
	return pos, n.Unit
end

local function onSurface(part, pos, n)
	part.CFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, math.rad(90), 0)
end

local function popRate(u, done)
	if done then
		return 1.5
	end
	if u < 0.15 then
		return 0
	elseif u < 0.314 then
		return 5
	elseif u < 0.743 then
		return 20
	end
	return 7
end

local function drawPuff(S, pf, dt, speed)
	local u = pf.u
	local h = puffCurve(u)
	local R = S.bowlRadius - 0.08
	local Hf = 2 * R * Fx.HEIGHT.FoamPuff
	-- 덩어리 → 둥근 돔: 높이(Y)는 많이, 지름(X/Z)은 조금. 마지막엔 국자 테두리를 살짝 넘음. 튀거나 꺼지지 않음
	local height = Hf * (0.42 + 0.58 * h)
	local diam = 2 * R * (0.84 + 0.2 * h)
	local base = Vector3.new(S.Bowl.Position.X, S:contentsTopY() - 0.04, S.Bowl.Position.Z)
	if not pf.done then
		pf.yaw += math.min(speed, 20) * dt * 0.04
	end
	-- 색: 영상 비율 그대로 (+33% 밝아짐, 대부분 B 구간). 유지 단계에서 틈이 아주 살짝 진해짐
	local col = scaleColor(pf.final, rampAt(u))
	if pf.done then
		col = col:Lerp(Color3.new(0, 0, 0), 0.03 * math.min(pf.hold / HOLD_TIME, 1))
	end
	S:setContents({ Color = col, thickness = pf.baseThick * (1 + 0.8 * h) })
	local foam = pf.foam
	-- 주름 언덕은 A~B 초반에 둥글게 뭉개지며 돔으로 바뀜
	local massFade = smooth01(u, 0.2, 0.55)
	if pf.mass then
		foam.Transparency = 1 - smooth01(u, 0.08, 0.4)
		pf.mass.Transparency = massFade
		pf.mass.Color = col:Lerp(Color3.new(0, 0, 0), 0.06)
		local mh = height * (1.15 - 0.2 * massFade)
		pf.mass.Size = Vector3.new(diam * 0.95, math.max(mh, 0.01), diam * 0.85)
		pf.mass.CFrame = CFrame.new(base + Vector3.new(0, mh / 2, 0)) * CFrame.Angles(0, pf.yaw, 0)
	end
	foam.Color = col
	-- 광택 → 무광: B에 들어서면 결이 있는 재질로
	foam.Material = u > 0.45 and Enum.Material.Sand or Enum.Material.SmoothPlastic
	if foam:IsA("MeshPart") then
		Fx.placeDome(foam, base, diam, height, pf.yaw)
	else
		foam.Size = Vector3.new(diam, height * 2, diam)
		foam.CFrame = CFrame.new(base)
	end
	local H = height * 0.9 -- 메시 돔 표면 높이 (기포 혹 제외)
	-- 바늘구멍: 생기면서 커지고, C에서 대비가 1/3 줄어듦 (더 고운 스펀지)
	local soften = smooth01(u, 0.75, 1)
	local holeCol = col:Lerp(Color3.fromRGB(70, 38, 14), 0.55 * (1 - soften / 3))
	for _, ho in ipairs(pf.holes) do
		local g = smooth01(u, ho.u0, ho.u0 + 0.08)
		if g <= 0 then
			ho.part.Transparency = 1
		else
			ho.part.Transparency = 0.15 + 0.85 * (1 - g)
			ho.part.Color = holeCol
			local d = ho.d * (0.4 + 0.6 * g) * (1 - 0.15 * soften)
			ho.part.Size = Vector3.new(0.008, d, d)
			local pos, n = surfaceAt(base, diam / 2, H, ho.r, ho.a + pf.yaw)
			onSurface(ho.part, pos, n)
		end
	end
	-- 번들거림: 처음엔 또렷, u 0.45까지 사라짐
	local shine = 1 - smooth01(u, 0.05, 0.45)
	for _, gl in ipairs(pf.gloss) do
		gl.part.Transparency = 1 - 0.55 * shine
		local pos, n = surfaceAt(base, diam / 2, (pf.mass and height * 1.1 or H), gl.r, gl.a + pf.yaw)
		onSurface(gl.part, pos + Vector3.new(0, 0.01, 0), n)
	end
	-- 이산화탄소 기포: 표면에 작게 솟았다 톡 터짐 (B에서 가장 많음)
	pf.popAcc += popRate(u, pf.done) * dt
	while pf.popAcc >= 1 do
		pf.popAcc -= 1
		local d = math.random(30, 85) / 1000
		table.insert(pf.pops, {
			t = 0,
			life = 0.25 + math.random() * 0.2,
			d = d,
			r = math.sqrt(math.random()) * 0.85,
			a = math.random() * 2 * math.pi,
			part = speck(foam, { Name = "Pop", Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.one * 0.01 }),
		})
	end
	for i = #pf.pops, 1, -1 do
		local b = pf.pops[i]
		b.t += dt
		local k = b.t / b.life
		if k >= 1 then
			b.part:Destroy()
			table.remove(pf.pops, i)
		else
			local pos, n = surfaceAt(base, diam / 2, H, b.r, b.a + pf.yaw)
			local s, tr
			if k < 0.7 then
				s = b.d * (k / 0.7) ^ 0.6
				tr = 0.2
			else
				local q = (k - 0.7) / 0.3
				s = b.d * (1 + 0.4 * q)
				tr = 0.2 + 0.8 * q
			end
			b.part.Size = Vector3.one * math.max(s, 0.005)
			b.part.Color = col:Lerp(Color3.fromRGB(255, 240, 205), 0.35)
			b.part.Transparency = tr
			b.part.CFrame = CFrame.new(pos + n * s * 0.25)
		end
	end
end

-- 미리 보기·테스트용 (Studio Edit에서 부풀기 장면 세우기)
Soda.newPuff = newPuff
Soda.drawPuff = drawPuff

function Soda.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Soda
	local mcfg = Config.Melt
	local rec = { t0 = ctx.now(), delay = 0, amount = 0, fastFrac = 0, puff = 0, samples = {} }
	local spoon = S.SodaSpoon
	local rest = S.rest.SodaSpoon
	local stir = Stir.new()

	local phase = "drop"
	local seenPress = P.presses
	local carrying = false
	local dips = 0
	local spots = {}
	local tipPowder = nil
	local firstDrop = nil
	local puffed = false
	local puff = nil
	local drive, idle = 0, 0
	local tStir, tFast = 0, 0
	local sampleAcc = 0
	local baseThick = S.Contents.Size.X

	ui:say("나무젓가락 끝에 소다를 묻혀 국자에 톡!", "소다 통에서 국자로 끌어요 · 2~3번")

	while true do
		local dt = ctx.frame()
		if not dt then
			bubbles(S, false)
			return nil
		end

		-- 국자는 아직 불 위: 오래 끌면 탐 (너무 늦게 넣음)
		Heat.step(st, dt)
		if st.burn >= 1 then
			bubbles(S, false)
			ctx.markBurnt()
			ui:hint("너무 늦었어요, 타 버렸어요…")
			rec.t1 = ctx.now()
			return rec
		end
		if st.burn > 0.2 then
			Heat.smoke(S, true, st.burn)
		end

		if phase == "drop" then
			-- 나무젓가락 끝에 소다를 묻혀(소다 통에서 끌어) 국자 위에서 놓으면 톡. 넣은 횟수 = 양 (실제 영상: "2~3번")
			local tubPos = S.SodaTub.Soda.Position
			if P.down and P.presses ~= seenPress then
				seenPress = P.presses
				local w = P.toPlane(tubPos.Y)
				local onTub = Vector3.new(w.X - tubPos.X, 0, w.Z - tubPos.Z).Magnitude < 1.1
				if onTub and dips < MAX_DIPS then
					carrying = true
					ui:buzz(0.2, 0.04)
				elseif dips > 0 then
					phase = "stir" -- 국자를 누르면 젓기 시작
					ui:say("빠르게 저어요!", "FAST 쪽이 정답 · 불에서 떼고 저어요")
				end
			end
			if carrying then
				local tip = P.toPlane(S:contentsTopY() + 0.35)
				Stir.placeChopsticksAt(S, tip)
				if not tipPowder then
					tipPowder = S:fxPart(S.fx, { Name = "FxSodaTip", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand, Size = Vector3.new(0.09, 0.07, 0.09) })
				end
				tipPowder.Transparency = 0
				tipPowder.CFrame = CFrame.new(tip + Vector3.new(0, 0.03, 0))
				if not P.down then
					carrying = false
					tipPowder.Transparency = 1
					local bowl = S.Bowl.Position
					local flat = Vector3.new(tip.X - bowl.X, 0, tip.Z - bowl.Z)
					if flat.Magnitude < S.bowlRadius then
						dips += 1
						rec.amount = math.min(HEAP_MAX, dips * DIP_AMOUNT)
						if not firstDrop then
							firstDrop = ctx.now()
							rec.delay = firstDrop - (st.meltDoneAt or firstDrop)
						end
						-- 액체 위에 떠 있는 흰 소다 점
						if flat.Magnitude > S.bowlRadius - 0.3 then
							flat = flat.Unit * (S.bowlRadius - 0.3)
						end
						local spot = Fx.mesh("SodaMound", S.Ladle, { Name = "FxSoda", Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand })
							or S:fxPart(S.Ladle, { Name = "FxSoda", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand, Size = Vector3.new(0.2, 0.06, 0.2) })
						local base = Vector3.new(bowl.X + flat.X, S:contentsTopY() - 0.01, bowl.Z + flat.Z)
						if spot:IsA("MeshPart") then
							Fx.placeDome(spot, base, 0.24, 0.24 * Fx.HEIGHT.SodaMound * 0.6, math.random() * 6)
						else
							spot.CFrame = CFrame.new(base)
						end
						table.insert(spots, spot)
						ui:buzz(0.35, 0.06)
						if dips >= 4 then
							ui:hint("소다가 너무 많아요 (쓴맛)")
						end
					else
						ui:hint("국자 위에서 놓아요")
					end
				end
			elseif dips > 0 then
				Stir.placeChopsticks(S, S.Bowl.Position + Vector3.new(0.3, 0, 0.2))
			end
			ui:say("나무젓가락 끝에 소다를 묻혀 국자에 톡!", dips == 0 and "소다 통에서 국자로 끌어요 · 2~3번" or string.format("%d번 넣었어요 · 2~3번이 알맞아요 · 다 넣었으면 국자를 눌러 저어요", dips))
			ui:setMeter(true, rec.amount / HEAP_MAX, cfg.idealMin / HEAP_MAX, cfg.idealMax / HEAP_MAX, "소다")
		else
			if tipPowder then
				tipPowder:Destroy()
				tipPowder = nil
			end
			S:springTo(spoon, rest, dt, 22)
			local speed = stir:update(dt)
			local zone = Stir.zone(speed, mcfg.slow, cfg.fastMin)
			local target = 0
			if stir.active then
				local y01 = stir:centerHeight01()
				if y01 then
					st.h += (Heat.heightFromScreen(y01) - st.h) * (1 - math.exp(-10 * dt))
				end
				S.Ladle:PivotTo(S:ladleAt(st.h))
				Heat.flame(S, st.h)
				Stir.placeChopsticks(S, P.toPlane(S:contentsTopY()))
				tStir += dt
				if zone == 3 then
					tFast += dt
				end
				sampleAcc += dt
				if sampleAcc >= 0.15 and #rec.samples < Config.Server.maxSamples then
					sampleAcc = 0
					table.insert(rec.samples, { zone })
				end
				target = PUFF_DRIVE[zone] or 0
				if zone < 3 and not (puff and puff.done) then
					ui:hint("더 빠르게! 쉬지 말고 저어요")
				end
				-- 소다 넣은 뒤엔 불에서 떼고 저어야 함: 불 가까이 저으면 금방 탐 (실제 영상 1:31)
				if puffed and st.h < 0.8 then
					st.burn = math.min(1, st.burn + dt * 0.2 * (0.8 - st.h) / 0.65)
					ui:hint("불에서 떼고 저어요! (위로 올려 저어요)")
				end
				if not puffed and speed > 3 then
					puffed = true
					for _, spot in ipairs(spots) do
						TweenService:Create(spot, TweenInfo.new(0.3), { Transparency = 1 }):Play()
					end
					ui:buzz(0.6, 0.12)
					puff = newPuff(S, rec.amount, baseThick)
				end
			end
			if puffed then
				-- 젓는 세기가 부풀기 시계를 밀어 줌 (빠르게 = 3.5초, 느리면 늘어남)
				drive += (target - drive) * (1 - math.exp(-dt / 0.3))
				if not puff.done then
					puff.u = math.min(1, puff.u + drive * dt / PUFF_TIME)
					if target < 0.2 then
						idle += dt
					else
						idle = 0
					end
					if puff.u >= 1 then
						puff.done = true
					elseif idle > 1.2 and puff.u > 0.25 then
						-- 너무 일찍 멈춤: 덜 부푼 채로 굳음
						puff.done = true
						ui:hint("덜 부풀었어요… 더 오래 빠르게 저어야 해요")
					end
				else
					puff.hold += dt
				end
				rec.puff = puffCurve(puff.u)
				drawPuff(S, puff, dt, speed)
			end
			Sfx.stir(puffed and "stirCream" or "stirLiquid", speed, stir.active)
			ui:setGauge(true, speed, mcfg.slow, cfg.fastMin, "STIR FAST! · 빠르게")
			ui:setMeter(true, rec.puff, 0.95, 1, "거품")
			rec.fastFrac = tStir > 0 and tFast / tStir or 0
			ui:say("빠르게 저어요!", string.format("부풀기 %d%% · 크림처럼 될 때까지", math.floor(rec.puff * 100)))
			if puff and puff.done and puff.hold >= HOLD_TIME then
				break
			end
		end
		if not firstDrop then
			rec.delay = ctx.now() - (st.meltDoneAt or rec.t0)
		end
		ctx.live("soda", Scoring.soda(rec))
	end

	bubbles(S, false)
	Sfx.stir(nil, 0, false)
	Sfx.stop("fire") -- 소다 다음부터는 불을 안 씀
	if puff then
		for _, b in ipairs(puff.pops) do
			b.part:Destroy()
		end
		puff.pops = {}
	end
	ui:setGauge(false)
	ui:setMeter(false)
	spoon:PivotTo(rest)
	S:setHeap("SodaSpoon", 1)
	st.batterColor = S.Contents.Color
	ui:buzz(0.4, 0.08)
	ui:say("크림처럼 됐어요! 부어요", "")
	rec.t1 = ctx.now()
	return rec
end

return Soda
