-- 1. 설탕 넣기: 나무 숟가락을 그릇에서 국자 위로 끌면 기울어지며 쏟아짐 (40° 넘으면 알갱이)
-- 백설탕 2스푼 → 황설탕 1/4스푼. 국자 위에 쏟은 양만 센다. 밖에 흘리면 알갱이가 남음(감점).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local Fx = require(script.Parent.Parent:WaitForChild("Fx"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))

local Sugar = {}

local WHITE = Color3.fromRGB(252, 252, 252)
local BROWN = Color3.fromRGB(214, 168, 92)
local MAX_TILT = math.rad(78)
local GRAINS = 16
local CRYSTALS = 90 -- 3D 설탕 결정이 있을 때 더미 위에 흩어 놓는 낱알 수 (작고 많이 = 고운 설탕)

-- 국자 속 설탕 더미: 설탕 그릇에 담긴 더미(SugarHeapMesh)와 똑같은 모양·재질 (사용자 요청 2026-11-18).
-- 그릇 더미가 없으면 3D 결정 더미(SugarPile), 그것도 없으면 예전처럼 모래 원판 + 공 알갱이
local function cupHeap(S)
	return S.WhiteBowl:FindFirstChild("SugarHeapMesh")
end

local function updatePile(S, st, fill, color)
	local cup = cupHeap(S)
	if not cup and not Fx.template("SugarPile") then
		return false
	end
	if not st.pile then
		if cup then
			local p = cup:Clone()
			p.Name = "FxPile"
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Parent = S.Ladle
			st.pile = p
			st.pileAspect = cup.Size.Y / math.max(cup.Size.X, cup.Size.Z)
		else
			st.pile = Fx.mesh("SugarPile", S.Ladle, { Name = "FxPile", Material = Enum.Material.SmoothPlastic, Reflectance = 0.05 })
			st.pileAspect = Fx.HEIGHT.SugarPile
		end
	end
	local R = (S.bowlRadius - 0.12) * (0.55 + 0.45 * fill)
	st.pileD = 2 * R
	st.pileH = st.pileD * st.pileAspect * (0.6 + 0.4 * fill)
	st.pile.Color = color
	Fx.placeDome(st.pile, Vector3.new(S.Bowl.Position.X, S:contentsTopY() - 0.01, S.Bowl.Position.Z), st.pileD, st.pileH, 0.7)
	return true
end

local function addGrain(S, list, st)
	local a = math.random() * 2 * math.pi
	if st and st.pile then
		-- 3D 결정 낱알: 더미 표면 위에 비스듬히
		local R = st.pileD / 2 * 0.92
		local r = math.sqrt(math.random()) * R
		local top = S:contentsTopY() - 0.01 + st.pileH * (1 - (r / (st.pileD / 2)) ^ 2) ^ 0.6
		local g = Fx.mesh("SugarCrystal", S.Ladle, {
			Name = "FxGrain",
			Size = Vector3.one * (0.018 + math.random() * 0.016),
			Color = WHITE,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.08,
			CFrame = CFrame.new(S.Bowl.Position.X + math.cos(a) * r, top, S.Bowl.Position.Z + math.sin(a) * r)
				* CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3),
		})
		table.insert(list, g)
		return
	end
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
	if hit and Fx.template("SugarCrystal") then
		local s = 0.018 + math.random() * 0.015
		Fx.mesh("SugarCrystal", S.fx, {
			Name = "Spill",
			Size = Vector3.one * s,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(hit.Position + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, math.random() * 6, 0),
		})
	elseif hit then
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
		-- 설탕 쏟아지는 "사르르": 기울인 만큼 크게
		Sfx.loop("sugarPour", pouring and 0.25 + 0.5 * (tilt / MAX_TILT) or 0, 0.9 + 0.25 * (tilt / MAX_TILT))

		local scoop = phase == "white" and cfg.scoopWhite or cfg.scoopBrown
		S:setHeap("WoodSpoon", onSpoon / scoop, phase == "white" and WHITE or BROWN)

		-- 국자 속 설탕
		local total = rec.white + rec.brown
		if total > 0 then
			local need = cfg.white + cfg.brown
			local fill = math.min(total / need, 1)
			local color = WHITE:Lerp(BROWN, 0.35 * rec.brown / cfg.brown)
			local hasPile = cupHeap(S) ~= nil or Fx.template("SugarPile") ~= nil
			S:setContents({
				thickness = hasPile and (0.03 + 0.04 * fill) or (0.04 + 0.11 * fill),
				Transparency = 0,
				Material = Enum.Material.Sand,
				Color = color,
			})
			updatePile(S, st, fill, color)
			local count = cupHeap(S) and 0 or (hasPile and CRYSTALS or GRAINS) -- 그릇 더미 모양이면 따로 낱알 없음
			while #st.grains < math.floor(count * fill) do
				addGrain(S, st.grains, st)
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
	Sfx.stop("sugarPour")
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
