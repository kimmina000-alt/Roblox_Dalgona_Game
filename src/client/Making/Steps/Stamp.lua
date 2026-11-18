-- 6. 모양: ① 고른 도안 틀을 끌어서 원판 가운데에 놓기 ② 누름판을 잡아 틀 위로 가져와 꾹 짧게 누르기
-- 점수: 중심 거리 + 각도 + 누른 세기(적당). 세게 누르면 틀이 끝까지 박혀 금이 감.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local PresserGrab = require(script.Parent.Parent:WaitForChild("PresserGrab"))

local Stamp = {}

local HALF_WIRE = 0.14

-- 누른 시간 → 홈 깊이 (0 안 보임 · 1 또렷 · 1.3 너무 깊어 금 감)
local function depthFor(hold, cfg)
	if hold < cfg.holdMin then
		return 0.6 * hold / cfg.holdMin
	elseif hold <= cfg.holdMax then
		return 0.6 + 0.4 * (hold - cfg.holdMin) / (cfg.holdMax - cfg.holdMin)
	end
	return 1 + 0.3 * math.clamp((hold - cfg.holdMax) / (cfg.crackHold - cfg.holdMax), 0, 1)
end

-- 틀 손잡이 자국: 손잡이 쪽(틀의 +Z)으로 가장 튀어나온 철사 끝에서 원판 가장자리까지 곧은 홈
local function handleLine(wires, placed, c, R)
	local d = placed:VectorToWorldSpace(Vector3.zAxis)
	d = Vector3.new(d.X, 0, d.Z).Unit
	local best, bestDot = nil, -math.huge
	for _, w in ipairs(wires) do
		for _, sgn in ipairs({ -1, 1 }) do
			local p = w.Position + w.CFrame.LookVector * (w.Size.Z / 2) * sgn
			local dot = (p - placed.Position):Dot(d)
			if dot > bestDot then
				best, bestDot = p, dot
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
	local cfg = Config.Stamp
	local rec = { t0 = ctx.now(), dist = 10, angle = 0, hold = 0 }
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

	local phase = "place"
	local grabbing = false
	local seenPress = P.presses
	local yaw = 0
	local lastPos = nil
	local placed = nil -- 놓은 자리 CFrame (틀 Root)
	local contact, holdT = false, 0
	local grab = nil -- 누름판 손으로 들기 (PresserGrab)
	local groove = nil

	ui:say(shapeName .. " 틀을 끌어 원판 가운데에 놓아요", "가운데에, 반듯하게")

	while true do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		if phase == "place" then
			if P.down and not grabbing and P.presses ~= seenPress then
				seenPress = P.presses
				grabbing = true
				lastPos = nil
			end
			if grabbing then
				local w = P.toPlane(top + 0.7)
				if lastPos and dt > 0 then
					local vx = (w.X - lastPos.X) / dt
					local target = math.clamp(vx * 4, -25, 25)
					yaw += (target - yaw) * (1 - math.exp(-10 * dt))
				end
				lastPos = w
				cutter:PivotTo(CFrame.new(w) * CFrame.Angles(0, math.rad(yaw), 0))
				local flat = Vector3.new(w.X - c.X, 0, w.Z - c.Z)
				rec.dist = flat.Magnitude
				ctx.live("stamp", Scoring.stamp({ dist = rec.dist, angle = yaw, hold = 0.3 }))
				if not P.down then
					grabbing = false
					if rec.dist < dal:radius() then
						rec.angle = yaw
						placed = CFrame.new(w.X, top + HALF_WIRE - 0.02, w.Z) * CFrame.Angles(0, math.rad(yaw), 0)
						cutter:PivotTo(placed)
						phase = "press"
						S:presserSeeThrough(true)
						local pv = presser:GetPivot()
						grab = PresserGrab.new(S, P, pv.Position - Vector3.new(0, discHalf, 0))
						ui:buzz(0.3, 0.05)
						if rec.dist > 0.3 then
							ui:hint("가운데에서 조금 벗어났어요")
						end
						ui:say("누름판을 잡아 틀 위로 가져와요", "틀 위에서 꾹 멈추면 눌려요 · 짧게! 오래 누르면 금이 가요")
					else
						ui:hint("달고나 위에 올려요")
					end
				end
			else
				yaw += (0 - yaw) * (1 - math.exp(-10 * dt))
				S:springTo(cutter, S.rest.Cutter, dt, 22)
			end
		elseif phase == "press" then
			-- 누름판은 손으로 가져와 틀 위에서 꾹 멈춰야 눌림 (사용자 요청 2026-11-18). 떼거나 옆으로 끌면 끝
			local contactY = placed.Position.Y + 0.42 + 0.05
			local hover = contactY + 0.6
			local ended, why = grab:update(dt, hover, function(pos)
				return Vector3.new(pos.X - placed.X, 0, pos.Z - placed.Z).Magnitude < 0.6
			end)
			if why == "miss" then
				ui:hint("누름판을 눌러 잡아요")
			end
			if grab.pressing then
				if not contact then
					grab.bottom -= 8 * dt
					if grab.bottom <= contactY then
						grab.bottom = contactY
						contact = true
						holdT = 0
						if not groove then
							-- 닿는 순간부터 홈이 파이기 시작 (누를수록 깊고 또렷)
							groove = dal:groove(wires, handleLine(wires, placed, c, dal:radius() * 0.98))
						end
					end
				else
					holdT += dt
					groove:setDepth(depthFor(holdT, cfg))
					local depth = math.min(holdT / 1.0, 1) * 0.2
					cutter:PivotTo(placed - Vector3.new(0, depth, 0))
					grab.bottom = contactY - depth
				end
			else
				grab.bottom += (hover - grab.bottom) * (1 - math.exp(-22 * dt))
			end
			if ended then
				if contact and holdT > 0.03 then
					rec.hold = holdT
					phase = "lift"
				else
					contact = false
					ui:hint("틀 위에서 꾹 멈춰요")
				end
			end
			grab:draw()
		else
			break
		end
	end

	-- 결과: 틀 아래로 선이 파이고, 틀을 들면 자국이 남음
	if not groove then
		groove = dal:groove(wires, handleLine(wires, placed, c, dal:radius() * 0.98))
	end
	groove:setDepth(depthFor(rec.hold, cfg))
	if (dal.e or 0) + 1 > Config.Pour.failSpread then
		-- 길쭉하게 부은 반죽: 틀이 원판을 벗어나 제대로 안 찍히고 갈라짐
		groove:setDepth(0.35)
		dal:crack(5, 0.8)
		ui:hint("반죽이 길쭉해서 틀이 제대로 안 찍혀요")
		ui:buzz(0.8, 0.15)
	elseif rec.hold > cfg.crackHold then
		dal:crack(4, 0.7)
		ui:hint("너무 세게 눌러서 금이 갔어요")
		ui:buzz(0.8, 0.15)
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
	rec.t1 = ctx.now()
	return rec
end

return Stamp
