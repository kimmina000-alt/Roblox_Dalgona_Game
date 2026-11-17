-- 1. 설탕 넣기: 나무 숟가락을 그릇에서 국자 위로 끌면 기울어지며 쏟아짐 (40° 넘으면 알갱이)
-- 백설탕 2스푼 → 황설탕 1/4스푼. 국자 위에 쏟은 양만 센다. 밖에 흘리면 알갱이가 남음(감점).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Sugar = {}

local WHITE = Color3.fromRGB(252, 252, 252)
local BROWN = Color3.fromRGB(214, 168, 92)
local MAX_TILT = math.rad(78)
local GRAINS = 16

local function addGrain(S, list)
	local a = math.random() * 2 * math.pi
	local r = math.sqrt(math.random()) * (S.bowlRadius - 0.25)
	local top = S.Bowl.Position.Y + S.bowlHalf + 0.15
	local g = S:fxPart(S.Ladle, {
		Name = "FxGrain",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (0.11 + math.random() * 0.07),
		Color = WHITE,
		Material = Enum.Material.Sand,
		CFrame = CFrame.new(S.Bowl.Position.X + math.cos(a) * r, top, S.Bowl.Position.Z + math.sin(a) * r),
	})
	table.insert(list, g)
end

local function spillGrain(S, at, color)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { S.WoodSpoon, S.SodaSpoon, S.fx, S.Chopsticks }
	local origin = at + Vector3.new((math.random() - 0.5) * 0.3, 0, (math.random() - 0.5) * 0.3)
	local hit = workspace:Raycast(origin, Vector3.new(0, -10, 0), params)
	if hit then
		S:fxPart(S.fx, {
			Name = "Spill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.1,
			Color = color,
			Material = Enum.Material.Sand,
			CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.04, 0)),
		})
	end
end

function Sugar.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Sugar
	local rec = { t0 = ctx.now(), white = 0, brown = 0, spill = 0 }
	local spoon = S.WoodSpoon
	local restWhite = S.rest.WoodSpoon
	local restBrown = restWhite + (S.BrownBowl:GetPivot().Position - S.WhiteBowl:GetPivot().Position)
	local rest = restWhite
	local restRot = restWhite - restWhite.Position
	local emitter = S:pourEmitter(spoon, WHITE)
	local carryY = S.Bowl.Position.Y + S.bowlHalf + 0.9
	local ladle = S.Bowl.Position

	local phase = "white"
	local onSpoon = cfg.scoopWhite
	local grabbing = false
	local seenPress = P.presses
	local tilt = 0
	local spillAcc = 0
	st.grains = {}

	ui:say("숟가락을 국자 위로 끌어 기울여요", "백설탕 2스푼 (0 / 2)")

	while true do
		local dt = ctx.frame()
		if not dt then
			emitter.Enabled = false
			return nil
		end
		if P.down and not grabbing and P.presses ~= seenPress then
			seenPress = P.presses
			grabbing = onSpoon > 0
		end
		if grabbing and not P.down then
			grabbing = false
		end

		local pouring = false
		if grabbing then
			local w = P.toPlane(carryY)
			local flat = Vector3.new(ladle.X - w.X, 0, ladle.Z - w.Z)
			local d = flat.Magnitude
			local target = MAX_TILT * math.clamp((1.6 - d) / 0.7, 0, 1)
			tilt += (target - tilt) * (1 - math.exp(-18 * dt))
			local toward = d > 0.05 and flat.Unit or Vector3.new(-1, 0, 0)
			local axis = Vector3.yAxis:Cross(toward)
			spoon:PivotTo(CFrame.new(w) * CFrame.fromAxisAngle(axis, tilt) * restRot)
			if math.deg(tilt) > cfg.tiltPour and onSpoon > 0 then
				local amt = math.min(onSpoon, cfg.pourRate * dt * (tilt / MAX_TILT))
				onSpoon -= amt
				pouring = true
				if d < S.bowlRadius + 0.1 then
					local need = phase == "white" and (cfg.white - rec.white) or (cfg.brown - rec.brown)
					local into = math.min(amt, need)
					rec[phase] += into
				else
					rec.spill += amt
					spillAcc += amt
					while spillAcc > 0.08 do
						spillAcc -= 0.08
						spillGrain(S, w, phase == "white" and WHITE or BROWN)
					end
					ui:hint("국자 위에서 기울여요")
				end
			end
		else
			tilt = 0
			local settled = S:springTo(spoon, rest, dt, 22)
			if settled and onSpoon <= 0.001 then
				onSpoon = phase == "white" and cfg.scoopWhite or cfg.scoopBrown -- 그릇에서 다시 뜸
			end
		end
		emitter.Enabled = pouring

		local scoop = phase == "white" and cfg.scoopWhite or cfg.scoopBrown
		S:setHeap("WoodSpoon", onSpoon / scoop, phase == "white" and WHITE or BROWN)

		-- 국자 속 설탕
		local total = rec.white + rec.brown
		if total > 0 then
			local need = cfg.white + cfg.brown
			S:setContents({
				thickness = 0.04 + 0.11 * math.min(total / need, 1),
				Transparency = 0,
				Material = Enum.Material.Sand,
				Color = WHITE:Lerp(BROWN, 0.35 * rec.brown / cfg.brown),
			})
			while #st.grains < math.floor(GRAINS * math.min(total / need, 1)) do
				addGrain(S, st.grains)
			end
		end

		if total + rec.spill > 0 then
			ctx.live("sugar", 100 * total / (total + rec.spill))
		end

		if phase == "white" then
			ui:say("숟가락을 국자 위로 끌어 기울여요", string.format("백설탕 2스푼 (%.1f / 2)", rec.white))
			if rec.white >= cfg.white - 1e-3 then
				phase = "brown"
				rest = restBrown
				onSpoon = 0
				grabbing = false
				seenPress = P.presses
				emitter.Color = ColorSequence.new(BROWN)
				ui:buzz(0.3, 0.06)
				ui:say("황설탕 1/4스푼도 넣어요", "노란 그릇에서 조금만")
			end
		else
			ui:say("황설탕 1/4스푼도 넣어요", string.format("황설탕 1/4 (%d%%)", math.floor(100 * rec.brown / cfg.brown)))
			if rec.brown >= cfg.brown - 1e-3 then
				break
			end
		end
	end

	emitter.Enabled = false
	ui:buzz(0.4, 0.08)
	ui:say("좋아요! 이제 녹여요", "")
	local t = 0
	while t < 0.35 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		S:springTo(spoon, restWhite, dt, 22)
	end
	spoon:PivotTo(restWhite)
	S:setHeap("WoodSpoon", 1, WHITE)
	rec.t1 = ctx.now()
	return rec
end

return Sugar
