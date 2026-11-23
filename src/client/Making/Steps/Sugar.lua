-- 1. 설탕 넣기: 나무 숟가락 손잡이를 잡고 국자 위로 옮긴 뒤 잠깐 멈추면 기울어지며 쏟아짐 (40° 넘으면 알갱이)
-- 백설탕 2스푼 → 황설탕 1/4스푼. 국자 위에 쏟은 양만 센다. 밖에 흘리면 알갱이가 남음(감점).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local Fx = require(script.Parent.Parent:WaitForChild("Fx"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))
local Stir = require(script.Parent.Parent:WaitForChild("Stir")) -- Stir.screenUp: 화면 위쪽 방향

local Sugar = {}

local WHITE = Color3.fromRGB(252, 252, 252)
local BROWN = Color3.fromRGB(214, 168, 92)
local MAX_TILT = math.rad(78)
local SPOON_GRIP = 2.0 -- 손가락(손잡이 끝)에서 숟가락 머리까지 수평 거리 (숟가락 길이 2.7)
local GRAINS = 16
local STILL_SPEED = 140 -- 손가락이 이보다 느리면(픽셀/초) 멈춘 것으로 봄 → 숟가락이 기울어짐
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
	local top = S.Bowl.Position.Y + S.floor + 0.15
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

-- 숟가락 생김새 (처음 자리에서 잼): 피벗 기준 머리 위치·손잡이 방향·길이
local function measureSpoon(spoon)
	local mesh, best = nil, 0
	for _, p in ipairs(spoon:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local m = math.max(p.Size.X, p.Size.Y, p.Size.Z)
			if m > best then
				best, mesh = m, p
			end
		end
	end
	local scoop = spoon:FindFirstChild("Scoop")
	if not mesh or not scoop then
		return nil
	end
	local cf, s = mesh.CFrame, mesh.Size
	local axis, len = cf.RightVector, s.X
	if s.Y > len then
		axis, len = cf.UpVector, s.Y
	end
	if s.Z > len then
		axis, len = cf.LookVector, s.Z
	end
	local a, b = cf.Position + axis * len / 2, cf.Position - axis * len / 2
	local hend = ((a - scoop.Position).Magnitude > (b - scoop.Position).Magnitude) and a or b
	local pv = spoon:GetPivot()
	return {
		scoopLocal = pv:PointToObjectSpace(scoop.Position),
		handleLocal = pv:VectorToObjectSpace((hend - scoop.Position).Unit),
		len = (hend - scoop.Position).Magnitude,
	}
end

-- 손잡이를 잡은 숟가락: 머리 = head, 손잡이 끝 = 손가락 시선 위 (머리에서 len 떨어진 점), 기울기 = 손잡이 축으로 굴림
local function gripSpoonCFrame(geo, restRot, head, tilt, P)
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(P.pos.X, P.pos.Y)
	local o, u = ray.Origin, ray.Direction.Unit
	local w = o - head
	local b = w:Dot(u)
	local disc = b * b - (w:Dot(w) - geo.len * geo.len)
	local hand = disc > 0 and (o + u * (-b - math.sqrt(disc))) or (head + Vector3.new(0, 0.6, 0) - Stir.screenUp() * SPOON_GRIP)
	local hd = (hand - head).Unit
	local hr = restRot:VectorToWorldSpace(geo.handleLocal)
	local ax = hr:Cross(hd)
	local align = ax.Magnitude > 1e-4 and CFrame.fromAxisAngle(ax.Unit, math.acos(math.clamp(hr:Dot(hd), -1, 1))) or CFrame.new()
	local rot = CFrame.fromAxisAngle(hd, tilt) * align * restRot
	return rot + (head - rot:VectorToWorldSpace(geo.scoopLocal))
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

-- 처음 하는 사람 안내 (2026-11-21 사용자: "설탕 숟가락 드래그해서 국자에 붓는 그림 반투명하게"):
-- 반투명한 숟가락이 그릇 → 국자 위로 옮겨 가 기울어져 붓는 모습을 되풀이. 직접 숟가락을 잡으면 사라짐
local DEMO_T = 2.6
local function makeDemo(S, spoon, geo, restCF, ladle, carryY)
	if not geo then
		return nil
	end
	local ghost = spoon:Clone()
	ghost.Name = "SugarDemoSpoon"
	local parts = {}
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				table.insert(parts, d)
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local restRot = restCF - restCF.Position
	local hr = restRot:VectorToWorldSpace(geo.handleLocal)
	local head0 = restCF:PointToWorldSpace(geo.scoopLocal)
	local head1 = Vector3.new(ladle.X, carryY, ladle.Z)
	local t = 0
	local shown = false
	local demo = {}
	function demo.update(dt, on)
		if not on then
			if shown then
				ghost.Parent = nil
				shown = false
			end
			t = 0
			return
		end
		if not shown then
			ghost.Parent = S.fx
			shown = true
		end
		t = (t + dt) % DEMO_T
		local function sm(a)
			a = math.clamp(a, 0, 1)
			return a * a * (3 - 2 * a)
		end
		local move = sm((t - 0.3) / 1.0)
		local tilt = math.rad(70) * sm((t - 1.45) / 0.5)
		local head = head0:Lerp(head1, move) + Vector3.new(0, math.sin(math.pi * move) * 0.6, 0)
		local rot = CFrame.fromAxisAngle(hr, tilt) * restRot
		ghost:PivotTo(rot + (head - rot:VectorToWorldSpace(geo.scoopLocal)))
		-- 나타났다가(처음 0.3초) 다 붓고 사라짐(마지막 0.4초)
		local fade = math.max(1 - t / 0.3, (t - (DEMO_T - 0.4)) / 0.4, 0)
		for _, p in ipairs(parts) do
			p.Transparency = 0.55 + 0.45 * math.clamp(fade, 0, 1)
		end
	end
	function demo.destroy()
		ghost:Destroy()
	end
	return demo
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
	local spoonGeo = measureSpoon(spoon)
	local carryY = S.Bowl.Position.Y + S.bowlHalf + 0.9
	local ladle = S.Bowl.Position
	local demo = makeDemo(S, spoon, spoonGeo, restWhite, ladle, carryY) -- 붓는 모습 안내 (파티클 붙이기 전에 복제)
	local emitter = S:pourEmitter(spoon, WHITE)

	local phase = "white"
	local onSpoon = cfg.scoopWhite
	local grabbing = false
	local seenPress = P.presses
	local tilt = 0
	local spillAcc = 0
	local lastFinger, fingerSpeed, dwell = nil, 0, 0
	st.grains = {}

	ui:say("숟가락을 국자 위로 옮겨 잠깐 멈춰요", "멈춰 있으면 기울어져 쏟아져요 · 백설탕 2스푼 (0 / 2)")

	while true do
		local dt = ctx.frame()
		if not dt then
			emitter.Enabled = false
			if demo then
				demo.destroy()
			end
			return nil
		end
		if P.down and not grabbing and P.presses ~= seenPress then
			seenPress = P.presses
			grabbing = onSpoon > 0
		end
		if grabbing and not P.down then
			grabbing = false
		end
		if not grabbing then
			lastFinger, fingerSpeed, dwell = nil, 0, 0
		end
		if demo then
			-- 안내 글씨가 보이는 처음 판들, 아직 한 번도 안 부었을 때만
			demo.update(dt, not grabbing and ui:subShown() and rec.white + rec.brown < 0.05)
		end

		local pouring = false
		if grabbing then
			-- 손잡이를 잡고 끌기: 손가락 = 손잡이, 숟가락 머리는 화면 위쪽(-Z)으로 떨어진 곳 (손가락이 국자를 안 가림)
			local w = P.toPlane(carryY) + Stir.screenUp() * SPOON_GRIP
			local flat = Vector3.new(ladle.X - w.X, 0, ladle.Z - w.Z)
			local d = flat.Magnitude
			-- 기울이기 (사용자 요청 2026-11-18: 국자까지 가기 전에 다 흘림 → 끌 때는 수평으로 들고 감).
			-- 숟가락 머리가 국자 위에 있고 손가락을 잠깐 멈추면(꾹 대고 있기) 천천히 기울어져 쏟아짐.
			-- 다시 움직이면 바로 수평으로 돌아옴 → 원하는 만큼만 붓고, 옮기는 동안엔 안 흘림.
			-- (모바일 요리 게임의 "대고 있으면 붓기" 방식. 손목 돌리기·두 손가락 돌리기는 한 손 조작에 어려움)
			local fv = lastFinger and (P.pos - lastFinger).Magnitude / math.max(dt, 1e-3) or 0
			lastFinger = P.pos
			fingerSpeed += (fv - fingerSpeed) * (1 - math.exp(-dt / 0.08))
			local overLadle = d < S.bowlRadius * 0.85
			if overLadle and fingerSpeed < STILL_SPEED then
				dwell += dt
			else
				dwell = math.max(0, dwell - dt * 4)
			end
			-- 멈추면 0.05초 뒤부터 0.3초 만에 다 기울어짐 (2026-11-19 "조금 더 빨리 기울어졌으면")
			local target = overLadle and MAX_TILT * math.clamp((dwell - 0.05) / 0.3, 0, 1) or math.rad(6) -- 옮길 땐 살짝만 (흔들림)
			tilt += (target - tilt) * (1 - math.exp(-(target < tilt and 14 or 12) * dt))
			local toward = d > 0.05 and flat.Unit or Vector3.new(-1, 0, 0)
			local axis = Vector3.yAxis:Cross(toward)
			if spoonGeo then
				spoon:PivotTo(gripSpoonCFrame(spoonGeo, restRot, w, tilt, P))
			else
				spoon:PivotTo(CFrame.new(w) * CFrame.fromAxisAngle(axis, tilt) * restRot)
			end
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
					ui:hint("국자 위에서 멈춰서 부어요")
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
			ui:say("숟가락을 국자 위로 옮겨 잠깐 멈춰요", string.format("멈춰 있으면 기울어져 쏟아져요 · 백설탕 2스푼 (%.1f / 2)", rec.white))
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
	if demo then
		demo.destroy()
	end
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
