-- 6. 모양: ① 고른 도안 틀을 끌어서 원판 가운데에 놓기 ② 누름판을 잡아 틀 위로 가져와 꾹 짧게 누르기
-- 점수: 중심 거리 + 각도 + 누른 세기(적당). 세게 누르면 틀이 끝까지 박혀 금이 감.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local PresserGrab = require(script.Parent.Parent:WaitForChild("PresserGrab"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))

local Stamp = {}

local HALF_WIRE = 0.14
-- 찍힐 자리 미리 보기 (사용자 요청 2026-11-19): 틀이 반죽 위에 떠 있어서 실제로 찍힐 자리와 달라 보임 →
-- 틀을 들고 있는 동안 반죽 윗면에 찍힐 선을 연두색으로, 반죽 밖으로 나가는 부분은 빨간색으로 보여 줌
local PREVIEW_IN = Color3.fromRGB(150, 255, 120)
local PREVIEW_OUT = Color3.fromRGB(255, 70, 70)

-- 누른 시간 → 홈 깊이 (0 안 보임 · 1 또렷 · 1.3 너무 깊어 금 감)
local function depthFor(hold, cfg)
	if hold < cfg.holdMin then
		return 0.6 * hold / cfg.holdMin
	elseif hold <= cfg.holdMax then
		return 0.6 + 0.4 * (hold - cfg.holdMin) / (cfg.holdMax - cfg.holdMin)
	end
	return 1 + 0.3 * math.clamp((hold - cfg.holdMax) / (cfg.crackHold - cfg.holdMax), 0, 1)
end

-- 틀 손잡이 자국: 실제 손잡이가 붙은 자리에서 원판 가장자리까지 곧은 홈 (사용자 요청 2026-11-19: 손잡이 위치와 자국 위치 통일).
-- 손잡이는 틀 가운데 세로선(Root의 x=0)이 외곽선과 만나는 가장 아래(+Z) 점에서 +Z로 뻗음 (CutterRig·cutters.py와 같은 규칙)
local function handleLine(wires, root, c, R)
	local d = root.CFrame:VectorToWorldSpace(Vector3.zAxis)
	d = Vector3.new(d.X, 0, d.Z).Unit
	-- 손잡이가 붙은 자리: 도안마다 세로 가운데 선에서 조금 옆일 수 있음 (CutterRig가 HandleX 속성에 넣어 둠)
	local hx = root.Parent and root.Parent:GetAttribute("HandleX") or 0
	local base = root.Position + root.CFrame.XVector * hx
	local best, bestT = nil, -math.huge
	for _, w in ipairs(wires) do
		local a = w.Position - w.CFrame.LookVector * (w.Size.Z / 2)
		local b = w.Position + w.CFrame.LookVector * (w.Size.Z / 2)
		local ex, ez = b.X - a.X, b.Z - a.Z
		local det = -d.X * ez + ex * d.Z
		if math.abs(det) > 1e-6 then
			local rx, rz = a.X - base.X, a.Z - base.Z
			local t = (-rx * ez + ex * rz) / det
			local s = (d.X * rz - d.Z * rx) / det
			if s >= -0.02 and s <= 1.02 and t > bestT then
				bestT = t
				best = Vector3.new(base.X + d.X * t, w.Position.Y, base.Z + d.Z * t)
			end
		end
	end
	if not best then
		return nil
	end
	local rel = Vector3.new(best.X - c.X, 0, best.Z - c.Z)
	local b = rel:Dot(d)
	local disc = b * b - (rel:Dot(rel) - R * R)
	if disc <= 0 then
		return nil
	end
	local t = -b + math.sqrt(disc)
	if t < 0.05 then
		return nil
	end
	return { a = best, b = best + d * t }
end

function Stamp.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	-- 누르는 시간 기준은 도안 등급별 (14번): 높은 등급일수록 오래 누르면 더 빨리 깊어지고 금이 감
	local dd = Config.difficulty(st.shape and st.shape.grade)
	local cfg = { holdMin = Config.Stamp.holdMin, holdMax = dd.holdMax, crackHold = dd.crackHold }
	-- grade: 도안 등급별 찍기 판정 폭 (14번). 서버는 세션 도안 등급으로 다시 정함
	local rec = { t0 = ctx.now(), dist = 10, angle = 0, hold = 0, grade = st.shape and st.shape.grade }
	local dal = st.dalgona
	local cutter = S.Cutter
	local shapeName = st.shape and st.shape.name or "별"
	local presser = S.Presser
	local discHalf = presser.Disc.Size.X / 2
	local top = dal:topY()
	local c = dal.center
	local wires = {}
	for _, w in ipairs(cutter:GetChildren()) do
		if w:GetAttribute("Outline") then
			table.insert(wires, w)
		end
	end

	-- 틀 손잡이 끝 자리 (틀 기준점 기준, 제자리 회전 기준): 손잡이는 플레이어 쪽(+Z)으로 가장 튀어나온 곳
	-- 쉬는 자리에서 살짝 사선으로 놓인 틀(속성 RestYaw, 새 배치 2026-11-21)은 찍을 때 똑바로
	local cutRot = CFrame.Angles(0, -math.rad(cutter:GetAttribute("RestYaw") or 0), 0) * (S.rest.Cutter - S.rest.Cutter.Position)
	local handleLocal = Vector3.new(0, 0, 0.8)
	do
		local bcf, bsz = cutter:GetBoundingBox()
		local pv = cutter:GetPivot()
		local far = bcf.Position + Vector3.new(0, 0, bsz.Z / 2 - 0.08)
		handleLocal = cutRot:VectorToObjectSpace(Vector3.new(far.X - pv.Position.X, 0, far.Z - pv.Position.Z))
	end
	local preview = {} -- 미리 보기 선 조각 (철사마다 하나)
	local function showPreview(on)
		for i, w in ipairs(wires) do
			local seg = preview[i]
			if not seg then
				seg = S:fxPart(S.fx, { Name = "StampPreview", Material = Enum.Material.Neon, Transparency = 1, Size = Vector3.new(0.05, 0.01, 0.05) })
				preview[i] = seg
			end
			if not on then
				seg.Transparency = 1
			else
				local look = w.CFrame.LookVector
				look = Vector3.new(look.X, 0, look.Z)
				if look.Magnitude > 1e-4 then
					local mid = Vector3.new(w.Position.X, top + 0.012, w.Position.Z)
					seg.Size = Vector3.new(0.045, 0.01, w.Size.Z)
					seg.CFrame = CFrame.lookAt(mid, mid + look.Unit)
					seg.Color = dal:inside(mid) and PREVIEW_IN or PREVIEW_OUT
					seg.Transparency = 0.15
				end
			end
		end
	end
	local phase = "place"
	local grabbing = false
	local seenPress = P.presses
	local yaw = 0
	local lastPos = nil
	local placed = nil -- 놓은 자리 CFrame (틀 Root)
	local contact, holdT = false, 0
	local holding = false
	local crackedLive = false -- 누르고 있는 동안 이미 금이 갔는지 (2026-11-20: 누르는 중에 "쩍")
	local grab = nil -- 누름판 손으로 들기 (PresserGrab)
	local groove = nil
	local fingerV = 0

	ui:say(shapeName .. " 틀을 끌어 원판 가운데에 놓아요", "가운데에, 반듯하게")
	-- 안 찍고 바로 포장할 수도 있음 (2026-11-20 "모양 안 찍고 끝내기 말고 포장하기 버튼으로"): 모양 점수 0점
	local skip = ui.setSkip and ui:setSkip(true, "포장하기")

	while true do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		if phase == "place" and skip and skip.clicked and not grabbing then
			ui:setSkip(false)
			showPreview(false)
			for _, seg in ipairs(preview) do
				seg:Destroy()
			end
			cutter:PivotTo(S.rest.Cutter)
			rec.skipped = 1
			rec.packNow = true -- 결과 전에 포장할지 묻지 않고 바로 포장 (MakingClient)
			rec.dist, rec.angle, rec.hold = 10, 0, 0
			ctx.live("stamp", 0)
			ui:say("모양 없이 포장해요", "모양 점수는 0점이에요")
			local t = 0
			while t < 0.8 do
				local dt2 = ctx.frame()
				if not dt2 then
					return nil
				end
				t += dt2
			end
			rec.t1 = ctx.now()
			return rec
		end
		if phase == "place" then
			if P.down and not grabbing and P.presses ~= seenPress then
				seenPress = P.presses
				grabbing = true
				Sfx.play("pop", 0.5, 1.1)
				lastPos = nil
			end
			if grabbing then
				-- 손가락 = 틀 손잡이 끝 (사용자 요청 2026-11-19: 가운데를 잡으면 손가락에 틀이 가려 안 보임).
				-- 틀 가운데 = 손가락 자리에서 손잡이 끝 → 가운데만큼 옮긴 곳
				local f = P.toPlane(top + 0.7)
				local w = f - (CFrame.Angles(0, math.rad(yaw), 0) * cutRot):VectorToWorldSpace(handleLocal)
				w = Vector3.new(w.X, top + 0.7, w.Z)
				-- 기울기는 손가락 속도로만 (틀 위치로 재면 기울기 → 위치 → 속도가 서로 되먹여 벌벌 떨림, 2026-11-20 수정)
				if lastPos and dt > 0 then
					local vx = S.rot:VectorToObjectSpace(f - lastPos).X / dt -- 화면 좌우 (돌려 놓은 작업대도 같게)
					fingerV += (vx - fingerV) * (1 - math.exp(-6 * dt))
					local target = math.clamp(fingerV * 3, -18, 18)
					yaw += (target - yaw) * (1 - math.exp(-6 * dt))
				end
				lastPos = f
				cutter:PivotTo(CFrame.new(w) * CFrame.Angles(0, math.rad(yaw), 0) * cutRot)
				showPreview(true)
				local flat = Vector3.new(w.X - c.X, 0, w.Z - c.Z)
				rec.dist = flat.Magnitude
				ctx.live("stamp", Scoring.stamp({ dist = rec.dist, angle = yaw, hold = 0.3, grade = rec.grade }))
				if not P.down then
					grabbing = false
					showPreview(false)
					if rec.dist < dal:radius() then
						rec.angle = yaw
						placed = CFrame.new(w.X, top + HALF_WIRE - 0.02, w.Z) * CFrame.Angles(0, math.rad(yaw), 0) * cutRot
						cutter:PivotTo(placed)
						ctx.state.stampRoot = cutter.Root.CFrame -- 찍은 자리·각도 (뽑기 점선, 15번)
						phase = "press"
						ui:setSkip(false) -- 틀을 올렸으면 이제 찍기만 남음
						S:presserSeeThrough(true)
						Sfx.play("metalClink", 0.25, 1.6) -- 틀 내려놓는 "땡"
						local pv = presser:GetPivot()
						-- 틀을 올리면 누름판은 틀 위로 와서 기다림 (사용자 요청 2026-11-19: 누름판을 끌고 오지 않아도 화면을 누르면 찍힘)
						grab = PresserGrab.new(S, P, pv.Position - Vector3.new(0, discHalf, 0))
						seenPress = P.presses
						ui:buzz(0.3, 0.05)
						if rec.dist > Scoring.diff(rec).stampDist * 0.5 then
							ui:hint("가운데에서 조금 벗어났어요")
						end
						ui:say("화면을 꾹 눌러 틀을 찍어요", "누르는 동안 누름판이 내려가요 · 짧게! 오래 누르면 금이 가요")
					else
						ui:hint("달고나 위에 올려요")
					end
				end
			else
				yaw += (0 - yaw) * (1 - math.exp(-10 * dt))
				S:springTo(cutter, S.rest.Cutter, dt, 22)
			end
		elseif phase == "press" then
			-- 화면 어디든 누르고 있으면 틀 위의 누름판이 내려가 찍음, 떼면 끝 (사용자 요청 2026-11-19)
			local contactY = placed.Position.Y + 0.42 + 0.05
			local hover = contactY + 0.6
			-- 누름판은 틀 위로 날아와 떠 있음
			grab.pos = grab.pos:Lerp(Vector3.new(placed.X, 0, placed.Z), 1 - math.exp(-14 * dt))
			if P.down and not holding and P.presses ~= seenPress then
				seenPress = P.presses
				holding = true
			end
			if holding then
				if not contact then
					grab.bottom = math.max(contactY, grab.bottom - 8 * dt)
					if grab.bottom <= contactY + 1e-3 then
						contact = true
						Sfx.play("pressSticky", 0.5, 1.1)
						holdT = 0
						if not groove then
							-- 닿는 순간부터 홈이 파이기 시작 (누를수록 깊고 또렷)
							groove = dal:groove(wires, handleLine(wires, cutter.Root, c, dal:radius() * 0.98))
						end
					end
				else
					holdT += dt
					groove:setDepth(depthFor(holdT, cfg))
					-- 너무 오래 누르면 누르고 있는 그 순간 쩍 갈라짐 (떼고 나서가 아니라)
					if holdT > cfg.crackHold and not crackedLive then
						crackedLive = true
						dal:crack(4, 0.7)
						Sfx.play("pressSticky", 0.8, 0.7)
						ui:hint("너무 세게 눌러서 금이 갔어요")
						ui:buzz(0.9, 0.2)
					end
					local depth = math.min(holdT / 1.0, 1) * 0.2
					cutter:PivotTo(placed - Vector3.new(0, depth, 0))
					grab.bottom = contactY - depth
				end
				if not P.down then
					holding = false
					if contact and holdT > 0.03 then
						rec.hold = holdT
						phase = "lift"
					else
						contact = false
						ui:hint("조금 더 꾹 눌러요")
					end
				end
			else
				grab.bottom += (hover - grab.bottom) * (1 - math.exp(-22 * dt))
			end
			grab:draw()
		else
			break
		end
	end

	-- 결과: 틀 아래로 선이 파이고, 틀을 들면 자국이 남음
	if not groove then
		groove = dal:groove(wires, handleLine(wires, cutter.Root, c, dal:radius() * 0.98))
	end
	groove:setDepth(depthFor(rec.hold, cfg))
	if (dal.e or 0) + 1 > Config.Pour.failSpread then
		-- 길쭉하게 부은 반죽: 틀이 원판을 벗어나 제대로 안 찍히고 갈라짐
		groove:setDepth(0.35)
		dal:crack(5, 0.8)
		ui:hint("반죽이 길쭉해서 틀이 제대로 안 찍혀요")
		ui:buzz(0.8, 0.15)
	elseif rec.hold > cfg.crackHold then
		if not crackedLive then
			dal:crack(4, 0.7)
			ui:hint("너무 세게 눌러서 금이 갔어요")
			ui:buzz(0.8, 0.15)
		end
	elseif rec.hold < cfg.holdMin then
		ui:hint("자국이 흐려요 (조금만 더 눌러요)")
	else
		ui:buzz(0.4, 0.08)
	end
	ctx.live("stamp", Scoring.stamp(rec))
	ui:say("모양이 찍혔어요!", "")
	local t = 0
	local lift = cutter:GetPivot()
	while t < 0.6 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		S:springTo(presser, S.rest.Presser, dt, 16)
		if t < 0.3 then
			cutter:PivotTo(lift + Vector3.new(0, 0.8 * t / 0.3, 0))
		else
			S:springTo(cutter, S.rest.Cutter, dt, 16)
		end
	end
	presser:PivotTo(S.rest.Presser)
	S:presserSeeThrough(false)
	cutter:PivotTo(S.rest.Cutter)
	for _, seg in ipairs(preview) do
		seg:Destroy()
	end
	rec.t1 = ctx.now()
	return rec
end

return Stamp
