-- 3. 소다: ① 분홍 숟가락을 국자로 끌어 한 번 털기 (양 = 기울인 시간)
--          ② 빠르게 젓기 (이번엔 FAST 쪽이 정답) → 0.5초 만에 불투명한 연갈색으로 부풀어 오름
-- 점수: 넣은 타이밍(투명해진 직후) + 양 + 부푼 정도

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Making = script.Parent.Parent
local Stir = require(Making:WaitForChild("Stir"))
local Heat = require(Making:WaitForChild("Heat"))

local Soda = {}

local MAX_TILT = math.rad(75)
local HEAP_MAX = 1.2
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

function Soda.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Soda
	local mcfg = Config.Melt
	local rec = { t0 = ctx.now(), delay = 0, amount = 0, fastFrac = 0, puff = 0, samples = {} }
	local spoon = S.SodaSpoon
	local rest = S.rest.SodaSpoon
	local restRot = rest - rest.Position
	local emitter = S:pourEmitter(spoon, Color3.new(1, 1, 1))
	local stir = Stir.new()

	local phase = "drop"
	local grabbing = false
	local seenPress = P.presses
	local tilt = 0
	local firstDrop = nil
	local mound = nil
	local puffed = false
	local tStir, tFast = 0, 0
	local sampleAcc = 0
	local baseThick = S.Contents.Size.X

	ui:say("분홍 숟가락을 국자 가운데로 끌어 톡!", "소다는 적당히 (기울인 시간 = 양)")

	while true do
		local dt = ctx.frame()
		if not dt then
			emitter.Enabled = false
			bubbles(S, false)
			return nil
		end

		-- 국자는 아직 불 위: 오래 끌면 탐 (너무 늦게 넣음)
		Heat.step(st, dt)
		if st.burn >= 1 then
			emitter.Enabled = false
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
			if P.down and not grabbing and P.presses ~= seenPress then
				seenPress = P.presses
				grabbing = rec.amount < HEAP_MAX
			end
			if grabbing and not P.down then
				grabbing = false
				if rec.amount > 0.05 then
					phase = "stir"
					ui:say("빠르게 저어요!", "FAST 쪽이 정답 · 크림처럼 될 때까지")
				end
			end
			local pouring = false
			if grabbing then
				local center = S.Bowl.Position
				local w = P.toPlane(S:contentsTopY() + 0.8)
				local flat = Vector3.new(center.X - w.X, 0, center.Z - w.Z)
				local d = flat.Magnitude
				local target = MAX_TILT * math.clamp((1.8 - d) / 1.0, 0, 1)
				tilt += (target - tilt) * (1 - math.exp(-18 * dt))
				local toward = d > 0.05 and flat.Unit or Vector3.new(-1, 0, 0)
				spoon:PivotTo(CFrame.new(w) * CFrame.fromAxisAngle(Vector3.yAxis:Cross(toward), tilt) * restRot)
				if math.deg(tilt) > 40 and rec.amount < HEAP_MAX then
					pouring = true
					if not firstDrop then
						firstDrop = ctx.now()
						rec.delay = firstDrop - (st.meltDoneAt or firstDrop)
					end
					local amt = 0.6 * dt * (tilt / MAX_TILT)
					rec.amount = math.min(HEAP_MAX, rec.amount + amt)
					if d > S.bowlRadius then
						ui:hint("국자 가운데에 넣어요")
					end
				end
			else
				tilt = 0
				S:springTo(spoon, rest, dt, 22)
			end
			emitter.Enabled = pouring
			S:setHeap("SodaSpoon", 1 - rec.amount / HEAP_MAX)
			if rec.amount > 0 then
				if not mound then
					mound = S:fxPart(S.Ladle, { Name = "FxSoda", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(252, 252, 252), Material = Enum.Material.Sand, Size = Vector3.one * 0.1 })
				end
				local size = 0.15 + 0.4 * math.min(rec.amount, HEAP_MAX)
				mound.Size = Vector3.new(size, size * 0.55, size)
				mound.CFrame = CFrame.new(S.Bowl.Position.X, S:contentsTopY() + size * 0.15, S.Bowl.Position.Z)
				ui:say("분홍 숟가락을 국자 가운데로 끌어 톡!", string.format("소다 양 %d%%", math.floor(100 * rec.amount / cfg.idealMax * 0.75)))
				if rec.amount > 0.9 then
					ui:hint("소다가 너무 많아요 (쓴맛)")
				end
			end
			ui:setMeter(true, rec.amount / HEAP_MAX, cfg.idealMin / HEAP_MAX, cfg.idealMax / HEAP_MAX, "소다")
			if rec.amount >= HEAP_MAX - 1e-3 and not grabbing then
				phase = "stir"
			end
		else
			emitter.Enabled = false
			S:springTo(spoon, rest, dt, 22)
			local speed = stir:update(dt)
			local zone = Stir.zone(speed, mcfg.slow, cfg.fastMin)
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
				local gain = zone == 3 and 0.42 or (zone == 2 and 0.15 or 0.03)
				rec.puff = math.min(1, rec.puff + gain * dt)
				if zone < 3 then
					ui:hint("더 빠르게! 쉬지 말고 저어요")
				end
				if not puffed and speed > 3 then
					puffed = true
					-- 0.5초 만에 불투명한 연갈색으로 부풀어 오름 (부피 1.5배)
					local dark = math.clamp((rec.amount - cfg.idealMax) / 0.85, 0, 1)
					local foam = FOAM:Lerp(FOAM_DARK, dark)
					if mound then
						TweenService:Create(mound, TweenInfo.new(0.3), { Transparency = 1 }):Play()
					end
					S:setContents({ Material = Enum.Material.SmoothPlastic, Transparency = 0, Color = foam })
					local t = 0
					task.spawn(function()
						while t < 0.5 and not ctx.aborted do
							t += task.wait()
							local a = math.min(t / 0.5, 1)
							S:setContents({ thickness = baseThick * (1 + 0.8 * (1 - (1 - a) ^ 2)) })
						end
					end)
					bubbles(S, true)
					ui:buzz(0.6, 0.12)
				end
				if puffed then
					local dark = math.clamp((rec.amount - cfg.idealMax) / 0.85, 0, 1)
					S:setContents({ Color = FOAM:Lerp(CREAM, rec.puff * 0.6):Lerp(FOAM_DARK, dark) })
				end
			end
			ui:setGauge(true, speed, mcfg.slow, cfg.fastMin, "STIR FAST! · 빠르게")
			ui:setMeter(true, rec.puff, 0.95, 1, "거품")
			rec.fastFrac = tStir > 0 and tFast / tStir or 0
			ui:say("빠르게 저어요!", string.format("부풀기 %d%% · 크림처럼 될 때까지", math.floor(rec.puff * 100)))
			if rec.puff >= 1 then
				break
			end
		end
		if not firstDrop then
			rec.delay = ctx.now() - (st.meltDoneAt or rec.t0)
		end
		ctx.live("soda", Scoring.soda(rec))
	end

	bubbles(S, false)
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
