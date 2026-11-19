-- 3. 소다: ① 나무젓가락 손잡이를 잡고 끌어 끝을 소다 통에 찍을 때마다 한 겹씩 묻고(흰 껍질이 두꺼워짐), 국자로 끌고 와 놓으면 톡. 넣은 양 합계 = 양 (0.35~0.65가 알맞음)
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
local TUB_R = 0.75 -- 젓가락 끝이 소다 통 가운데에서 이만큼 안이면 통 위 (쿡 잠김)
-- 찍을 때마다 한 겹씩 (사용자 요청 2026-11-19): 1번 찍으면 얇게, 2번이면 더 두껍게, 3번이면 더 두껍게
local DIP_LAYER = 0.17 -- 한 번 찍을 때 묻는 양 (1번 0.17 적음 · 2~3번 0.34~0.51 알맞음 · 4번 0.68 많음)
local LAYERS_MAX = 4 -- 한 번 들고 갈 때 최대 겹 수
local LOAD_MAX = DIP_LAYER * LAYERS_MAX
local STICK_DIR = Vector3.new(0.35, 1, 0.55).Unit
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

local function newPuff(S, amount, baseThick)
	local cfg = Config.Soda
	-- 넣은 소다 양에 따라 다르게 부풂 (사용자 요청 2026-11-19):
	--   적게: 덜 부풀고(낮고 작음) 진하고 번들번들 (기포가 적어 단단함)
	--   알맞게: 크림색으로 높고 둥글게
	--   많이: 국자 밖까지 크게 부풀었다가 가운데가 꺼지고, 진한 갈색 (쓴맛)
	local low = math.clamp((cfg.idealMin - amount) / cfg.idealMin, 0, 1)
	local high = math.clamp((amount - cfg.idealMax) / 0.45, 0, 1)
	local dark = math.max(high, 0.45 * low)
	local final = FOAM:Lerp(CREAM, 0.3 * (1 - low)):Lerp(FOAM_DARK, dark)
	local pf = {
		u = 0, hold = 0, done = false, final = final, yaw = math.random() * 6, baseThick = baseThick,
		size = 1 - 0.45 * low + 0.25 * high, -- 높이 배율
		wide = 1 - 0.12 * low + 0.18 * high, -- 지름 배율 (많으면 국자 밖으로)
		collapse = 0.3 * high, -- 다 부푼 뒤 꺼지는 정도
		glossy = low > 0.3, -- 적으면 끝까지 번들번들
	}
	local start = scaleColor(final, COLOR_RAMP[1][2])
	S:setContents({ Material = Enum.Material.SmoothPlastic, Transparency = 0, Color = start })
	-- 국자 속 반죽 하나만 부풀어 오름 (표면에 붙는 점·동그라미 없음, 사용자 요청 2026-11-18)
	-- 접힌 주름 언덕 메시가 번들거리다 무광이 되며 커짐. 없으면 거품 돔, 그것도 없으면 공
	pf.foam = Fx.mesh("DalgonaMound", S.Ladle, { Name = "FxFoam", Color = start, Material = Enum.Material.SmoothPlastic })
		or Fx.mesh("FoamPuff", S.Ladle, { Name = "FxFoam", Color = start, Material = Enum.Material.SmoothPlastic })
		or S:fxPart(S.Ladle, { Name = "FxFoam", Shape = Enum.PartType.Ball, Color = start, Size = Vector3.one * 0.1 })
	return pf
end

local function drawPuff(S, pf, dt, speed)
	local u = pf.u
	local h = puffCurve(u)
	local R = S.bowlRadius - 0.08
	local Hf = 2 * R * Fx.HEIGHT.FoamPuff
	-- 덩어리 → 둥근 돔: 높이(Y)는 많이, 지름(X/Z)은 조금. 마지막엔 국자 테두리를 살짝 넘음. 튀거나 꺼지지 않음
	local height = Hf * (0.42 + 0.58 * h) * (1 + (pf.size - 1) * h)
	local diam = 2 * R * (0.84 + 0.2 * h) * (1 + (pf.wide - 1) * h)
	if pf.done and pf.collapse > 0 then
		-- 너무 많이 넣음: 크게 부풀었다가 꺼짐
		local c = math.min(pf.hold / HOLD_TIME, 1)
		height *= 1 - pf.collapse * c
		diam *= 1 + 0.05 * c
	end
	local base = Vector3.new(S.Bowl.Position.X, S:contentsTopY() - 0.04, S.Bowl.Position.Z)
	if not pf.done then
		pf.yaw += math.min(speed, 20) * dt * 0.04
	end
	-- 색: 영상 비율 그대로 (+33% 밝아짐, 대부분 빠른 상승 구간). 유지 단계에서 아주 살짝 진해짐
	local col = scaleColor(pf.final, rampAt(u))
	if pf.done then
		col = col:Lerp(Color3.new(0, 0, 0), 0.03 * math.min(pf.hold / HOLD_TIME, 1))
	end
	S:setContents({ Color = col, thickness = pf.baseThick * (1 + 0.8 * h) })
	local foam = pf.foam
	foam.Color = col
	-- 광택 → 무광: 빠르게 부풀기 시작하면 고운 결이 있는 재질로
	foam.Material = (u > 0.45 and not pf.glossy) and Enum.Material.Sand or Enum.Material.SmoothPlastic
	if foam:IsA("MeshPart") then
		local mh = height * (1.15 - 0.1 * h)
		foam.Size = Vector3.new(diam * (0.95 + 0.03 * h), math.max(mh, 0.01), diam * (0.85 + 0.1 * h)) -- 커질수록 둥글게
		foam.CFrame = CFrame.new(base + Vector3.new(0, foam.Size.Y / 2, 0)) * CFrame.Angles(0, pf.yaw, 0)
	else
		foam.Size = Vector3.new(diam, height * 2, diam)
		foam.CFrame = CFrame.new(base)
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
	local dipK = 0 -- 젓가락 끝이 소다에 잠긴 정도 0~1
	local load = 0 -- 지금 젓가락 끝에 묻은 소다 양
	local dipped = false -- 지금 통에 담겨 있음 (빼야 다음 찍기)
	local falling = {}
	local firstDrop = nil
	local puffed = false
	local puff = nil
	local drive, idle = 0, 0
	local tStir, tFast = 0, 0
	local sampleAcc = 0
	local baseThick = S.Contents.Size.X

	ui:say("나무젓가락 끝에 소다를 묻혀 국자에 톡!", "끝을 소다 통에 콕 찍었다 빼요 · 찍을수록 두껍게 묻어요")
	P.sideZone = Heat.sideZone -- 왼쪽 구역 위아래로 끌기 = 국자 높이 (녹이기와 같음)

	while true do
		local dt = ctx.frame()
		if not dt then
			bubbles(S, false)
			P.sideZone = nil
			return nil
		end

		-- 국자는 아직 불 위: 오래 끌면 탐 (너무 늦게 넣음). 높이는 왼쪽 막대로
		local danger = Heat.control(st, P, ui)
		S.Ladle:PivotTo(S:ladleAt(st.h))
		Heat.flame(S, st.h)
		Heat.step(st, dt)
		if danger then
			ui:hint("불에 너무 가까워요! 왼쪽을 위로 끌어 국자를 올려요")
		end
		if st.burn >= 1 then
			bubbles(S, false)
			P.sideZone = nil
			ui:setHeight(false)
			ctx.markBurnt()
			ui:hint("너무 늦었어요, 타 버렸어요…")
			rec.t1 = ctx.now()
			return rec
		end
		Heat.smoke(S, st.burn > 0.03, st.burn)

		if phase == "drop" then
			-- 나무젓가락 손잡이를 잡고 끌어서(사용자 요청 2026-11-18) 끝을 소다 통에 넣었다 빼면 흰 소다가 묻고,
			-- 그대로 국자 위로 끌고 와서 놓으면 톡. 넣은 횟수 = 양 (실제 영상: "2~3번").
			-- 다 넣었으면 국자 안에서 그대로 원을 그리면 젓기로 넘어감
			local tubPos = S.SodaTub.Soda.Position
			if P.down and P.presses ~= seenPress then
				seenPress = P.presses
				carrying = true
				dipK = 0
				stir = Stir.new()
				ui:buzz(0.2, 0.04)
			end
			if carrying then
				local liftY = S:contentsTopY() + 0.35
				local surface = tubPos.Y + 0.02
				-- 끝이 소다 통 위에 있으면 쑥 내려가 소다에 잠김 (손가락은 그대로 손잡이).
				-- 통은 국자보다 훨씬 낮아서, 통 높이에서 본 끝 자리(atTub)로 통 위인지 보고 그 자리로 곧게 내려감
				local atLift = Stir.grip(liftY)
				local atTub = Stir.grip(surface)
				local overTub = Vector3.new(atTub.X - tubPos.X, 0, atTub.Z - tubPos.Z).Magnitude < TUB_R
				dipK += ((overTub and 1 or 0) - dipK) * (1 - math.exp(-14 * dt))
				local tip = atLift:Lerp(atTub, dipK)
				local hnd = Stir.handleFor(tip)
				Stir.placeChopsticksAt(S, tip, hnd)
				-- 소다 묻히기 (사용자 요청 2026-11-19): 끝을 통에 넣었다 뺄 때마다(찍을 때마다) 한 겹씩 묻음.
				-- 젓가락 끝부분에 흰 소다 껍질이 보이고, 겹이 많을수록 두껍고 길어짐 = 넣을 양
				if dipK > 0.8 and not dipped then
					dipped = true
					if load < LOAD_MAX - 1e-3 then
						load = math.min(LOAD_MAX, load + DIP_LAYER)
						ui:buzz(0.2, 0.04)
					end
				elseif dipK < 0.3 then
					dipped = false -- 빼면 다음 찍기 준비
				end
				if load > 0.005 and not tipPowder then
					tipPowder = S:fxPart(S.fx, { Name = "FxSodaTip", Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand, Size = Vector3.new(0.1, 0.06, 0.06) })
				end
				if tipPowder then
					local layers = load / DIP_LAYER
					local len = 0.1 + 0.05 * layers
					local d = 0.05 + 0.028 * layers
					local dir = S.stickDir or STICK_DIR
					local center = tip + dir * (len / 2 - 0.015)
					tipPowder.Size = Vector3.new(len, d, d)
					-- 원기둥 축(X)을 젓가락 방향으로
					tipPowder.CFrame = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0)
					tipPowder.Transparency = 0
				end
				local bowl = S.Bowl.Position
				local flat = Vector3.new(tip.X - bowl.X, 0, tip.Z - bowl.Z)
				local inLadle = flat.Magnitude < S.bowlRadius
				-- 소다를 다 넣은 뒤: 빈 젓가락으로 국자 안에서 원을 그리면 젓기 시작
				local spd = stir:update(dt)
				if dips > 0 and not tipPowder and inLadle and spd > 2.5 then
					phase = "stir"
					carrying = false
					ui:say("빠르게 저어요!", "FAST 쪽이 정답 · 불에서 떼고 저어요")
				end
				if not P.down then
					carrying = false
					dipped = false
					if tipPowder and inLadle then
						dips += 1
						local amt = load
						rec.amount = math.min(HEAP_MAX, rec.amount + load)
						load = 0
						if not firstDrop then
							firstDrop = ctx.now()
							rec.delay = firstDrop - (st.meltDoneAt or firstDrop)
						end
						if flat.Magnitude > S.bowlRadius - 0.3 then
							flat = flat.Unit * (S.bowlRadius - 0.3)
						end
						-- 젓가락 끝의 소다가 설탕물 위로 툭 떨어짐 (떨어진 뒤 흰 점이 됨)
						table.insert(falling, { part = tipPowder, from = tipPowder.Position, to = Vector3.new(bowl.X + flat.X, S:contentsTopY(), bowl.Z + flat.Z), t = 0, amt = amt })
						tipPowder = nil
						ui:buzz(0.35, 0.06)
						if rec.amount > cfg.idealMax then
							ui:hint("소다가 너무 많아요 (쓴맛, 너무 부풀다 꺼져요)")
						end
					elseif tipPowder then
						ui:hint("국자 위에서 놓아요")
						tipPowder:Destroy()
						tipPowder = nil
						load = 0
					end
				end
			elseif dips > 0 then
				Stir.placeChopsticks(S, S.Bowl.Position + Vector3.new(0.3, 0, 0.2))
			end
			for i = #falling, 1, -1 do
				local f = falling[i]
				f.t += dt
				local k = math.min(f.t / 0.22, 1)
				f.part.CFrame = CFrame.new(f.from:Lerp(f.to, k * k))
				if k >= 1 then
					f.part:Destroy()
					table.remove(falling, i)
					local spot = Fx.mesh("SodaMound", S.Ladle, { Name = "FxSoda", Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand })
						or S:fxPart(S.Ladle, { Name = "FxSoda", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand, Size = Vector3.new(0.2, 0.06, 0.2) })
					local base = f.to - Vector3.new(0, 0.01, 0)
					if spot:IsA("MeshPart") then
						local sd = 0.16 + 0.22 * math.sqrt((f.amt or DIP_LAYER) / (DIP_LAYER * 3)) -- 많이 찍을수록 큰 흰 점
						Fx.placeDome(spot, base, sd, sd * Fx.HEIGHT.SodaMound * 0.6, math.random() * 6)
					else
						spot.CFrame = CFrame.new(base)
					end
					table.insert(spots, spot)
				end
			end
			local sub
			if load > 0.005 then
				sub = string.format("%d번 찍었어요 · 더 찍으면 두껍게 · 국자 위에서 손을 떼면 톡", math.floor(load / DIP_LAYER + 0.5))
			elseif dips == 0 then
				sub = "끝을 소다 통에 콕 찍었다 빼요 · 찍을수록 두껍게 묻어요 · 초록 칸까지"
			else
				sub = rec.amount < cfg.idealMin and "조금 더 넣어요 (초록 칸까지) · 다 넣었으면 국자 안에서 저어요" or "다 넣었으면 국자 안에서 저어요"
			end
			ui:say("나무젓가락 끝에 소다를 묻혀 국자에 톡!", sub)
			ui:setMeter(true, math.min(1, (rec.amount + load) / HEAP_MAX), cfg.idealMin / HEAP_MAX, cfg.idealMax / HEAP_MAX, "소다")
		else
			if tipPowder then
				tipPowder:Destroy()
				tipPowder = nil
			end
			for _, f in ipairs(falling) do
				f.part:Destroy()
			end
			table.clear(falling)
			S:springTo(spoon, rest, dt, 22)
			local speed = stir:update(dt)
			local zone = Stir.zone(speed, mcfg.slow, cfg.fastMin)
			local target = 0
			if stir.active then
				local t, hnd = Stir.grip(S:contentsTopY())
				Stir.placeChopsticks(S, t, hnd)
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
					ui:hint("불에서 떼고 저어요! 왼쪽을 위로 끌어 국자를 올려요")
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
	P.sideZone = nil
	ui:setHeight(false)
	Sfx.stopStir()
	Sfx.stop("fire") -- 소다 다음부터는 불을 안 씀
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
