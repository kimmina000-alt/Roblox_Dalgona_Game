-- 2. 녹이기: 국자 안에서 원을 그리며 드래그 = 나무젓가락이 저음.
-- 원을 그리는 화면 높이 = 국자 높이 (위로 올려 저으면 불에서 멀어져 덜 뜨거움).
-- STIR SPEED 게이지(SLOW / JUST RIGHT / FAST) + 온도. 너무 뜨거우면 갈색 → 검정 → Burnt(그 자리에서 끝).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Making = script.Parent.Parent
local Stir = require(Making:WaitForChild("Stir"))
local Heat = require(Making:WaitForChild("Heat"))
local SugarLook = require(Making:WaitForChild("SugarLook"))
local Sfx = require(Making:WaitForChild("Sfx"))

local Melt = {}

local STIR_FACTOR = { 0.35, 1, 0.8 }

local function sampler(rec)
	local s = { interval = 0.2, acc = 0 }
	function s.push(dt, zone, temp)
		s.acc += dt
		if s.acc < s.interval then
			return
		end
		s.acc = 0
		table.insert(rec.samples, { zone, math.floor(temp + 0.5) })
		if #rec.samples >= Config.Server.maxSamples then
			-- 60개를 넘지 않게 절반으로 솎고 간격을 두 배로
			local kept = {}
			for i = 1, #rec.samples, 2 do
				table.insert(kept, rec.samples[i])
			end
			rec.samples = kept
			s.interval *= 2
		end
	end
	return s
end

function Melt.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Melt
	local rec = { t0 = ctx.now(), green = 0, tempOk = 0, scorch = 0, burn = 0, burnt = false, samples = {} }
	local stir = Stir.new()
	local samp = sampler(rec)
	st.h = 1.0 -- 처음엔 불에서 조금 띄워 둠 (가만히 두면 천천히 녹음)
	st.temp = st.temp or 30
	st.burn = 0
	st.melt = 0
	local tTotal, tGreen, tOkCount, tOkAll = 0, 0, 0, 0
	local hotSeen = false
	local started = false
	local elapsed = 0
	local look = SugarLook.new(S, st)
	local stage = "가루"
	local tip = nil

	Stir.placeChopsticks(S, S.Bowl.Position)
	ui:say("국자 안에서 원을 그리며 저어요", "초록(JUST RIGHT)에 맞춰요 · 위로 올려 저으면 덜 뜨거워요")

	while true do
		local dt = ctx.frame()
		if not dt then
			look:destroy()
			return nil
		end
		elapsed += dt
		local speed = stir:update(dt)
		local zone = Stir.zone(speed, cfg.slow, cfg.fast)
		if stir.active then
			started = true
			local y01 = stir:centerHeight01()
			if y01 then
				local target = Heat.heightFromScreen(y01)
				st.h += (target - st.h) * (1 - math.exp(-10 * dt))
			end
		end
		S.Ladle:PivotTo(S:ladleAt(st.h))
		tip = nil
		if stir.active then
			tip = Stir.placeChopsticks(S, P.toPlane(S:contentsTopY()))
		elseif started then
			Stir.placeChopsticks(S, S.Chopsticks.Stick1.Position + S.Chopsticks.Stick1.CFrame.LookVector * 1.3)
		end

		Heat.step(st, dt)
		Heat.flame(S, st.h)

		if stir.active then -- 저을 때만 속도 비율을 잼 (손을 잠깐 떼는 건 눌어붙음 감점으로만)
			tTotal += dt
			if zone == 2 then
				tGreen += dt
			end
			samp.push(dt, zone, st.temp)
		end
		if st.temp >= cfg.tempLow - 5 then
			hotSeen = true
		end
		if hotSeen then
			tOkAll += dt
			if st.temp >= cfg.tempLow - 5 and st.temp <= cfg.tempHigh + 3 then
				tOkCount += dt
			end
		end

		if st.temp >= 140 then
			local rate = cfg.rate * math.clamp((st.temp - 130) / 40, 0, 1.3) * STIR_FACTOR[zone]
			if not stir.active then
				rate *= 0.3
			end
			st.melt = math.min(1, st.melt + rate * dt)
		end
		if st.temp > 160 and zone == 1 and started then
			rec.scorch += dt * 0.15
			ui:hint("멈추지 말고 계속 저어요 (바닥이 눌어붙어요)")
		end
		if st.temp > cfg.tempHigh + 1 then
			ui:hint("불에서 조금 떨어뜨려요 (위로 올려 저어요)")
		elseif zone == 3 and stir.active then
			ui:hint("너무 빨라요! 초록에 맞춰요")
		end

		-- 보이는 변화 4단계: 가루 → 결정 → 반쯤 녹음 → 맑은 호박색 액체 (SugarLook). 타면 갈색 → 검정 + 연기
		local p = st.melt
		stage = look:update(dt, p, tip, st.burn)
		Sfx.stir(stage == "가루" and "stirDry" or (stage == "결정" and "stirCrystal" or "stirLiquid"), speed, stir.active)
		Heat.smoke(S, st.burn > 0.2, st.burn)

		ui:setGauge(true, speed, cfg.slow, cfg.fast)
		ui:setMeter(true, (st.temp - 20) / 220, (cfg.tempLow - 20) / 220, (cfg.tempHigh - 20) / 220, string.format("%d°", math.floor(st.temp + 0.5)))
		rec.green = tTotal > 0 and tGreen / tTotal or 0
		rec.tempOk = tOkAll > 0 and tOkCount / tOkAll or 1
		rec.burn = st.burn
		ctx.live("melt", Scoring.melt(rec))
		ui:say("국자 안에서 원을 그리며 저어요", string.format("%s · 녹은 정도 %d%% · 위로 올려 저으면 덜 뜨거워요", stage, math.floor(p * 100)))
		if not started and elapsed > 1.5 then
			ui:say("국자 안에서 원을 그리며 저어요", "손가락으로 국자 위에 동그라미를 그려요")
		end

		if st.burn >= 1 then
			rec.burnt = true
			break
		end
		if st.melt >= 1 then
			break
		end
	end

	ui:setGauge(false)
	ui:setMeter(false)
	Sfx.stir(nil, 0, false)
	for _, g in ipairs(st.grains) do
		g.Transparency = 1
	end
	if st.pile then
		st.pile.Transparency = 1
	end
	look:finish(st.burn, tip)
	rec.burn = st.burn
	if rec.burnt then
		Heat.smoke(S, true, 1)
		ui:hint("타 버렸어요…")
		ui:say("앗, 까맣게 탔어요", "다음엔 불에서 조금 띄워서 저어요")
	else
		ui:buzz(0.4, 0.08)
		ui:say("다 녹았어요! 바로 소다!", "투명해진 직후가 가장 좋아요")
	end
	st.meltDoneAt = ctx.now()
	rec.t1 = ctx.now()
	return rec
end

return Melt
