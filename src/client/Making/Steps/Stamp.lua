-- 6. 모양: ① 별 틀을 끌어서 원판 가운데에 놓기 ② 누름판을 살살 짧게 누르기
-- 점수: 중심 거리 + 각도 + 누른 세기(적당). 세게 누르면 틀이 끝까지 박혀 금이 감.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Stamp = {}

local HALF_WIRE = 0.14

function Stamp.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Stamp
	local rec = { t0 = ctx.now(), dist = 10, angle = 0, hold = 0 }
	local dal = st.dalgona
	local cutter = S.StarCutter
	local presser = S.Presser
	local pRot = S.rest.Presser - S.rest.Presser.Position
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
	local holding, contact, holdT = false, false, 0
	local pBottom = 0

	ui:say("별 틀을 끌어 원판 가운데에 놓아요", "가운데에, 반듯하게")

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
						presser.Disc.Transparency = 0.55
						pBottom = top + 0.6 + 0.8
						seenPress = P.presses
						ui:buzz(0.3, 0.05)
						if rec.dist > 0.3 then
							ui:hint("가운데에서 조금 벗어났어요")
						end
						ui:say("누름판으로 살살 눌러요", "짧게 톡! 세게 누르면 금이 가요")
					else
						ui:hint("달고나 위에 올려요")
					end
				end
			else
				yaw += (0 - yaw) * (1 - math.exp(-10 * dt))
				S:springTo(cutter, S.rest.StarCutter, dt, 22)
			end
		elseif phase == "press" then
			local contactY = placed.Position.Y + 0.42 + 0.05
			if P.down and not holding and P.presses ~= seenPress then
				seenPress = P.presses
				holding = true
				contact = false
				holdT = 0
			end
			if holding then
				if not contact then
					pBottom -= 8 * dt
					if pBottom <= contactY then
						pBottom = contactY
						contact = true
					end
				else
					holdT += dt
					local depth = math.min(holdT / 1.0, 1) * 0.2
					cutter:PivotTo(placed - Vector3.new(0, depth, 0))
					pBottom = contactY - depth
				end
				if not P.down then
					holding = false
					if contact and holdT > 0.03 then
						rec.hold = holdT
						phase = "lift"
					else
						ui:hint("조금만 더 꾹")
					end
				end
			else
				local hover = contactY + 0.6
				pBottom += (hover - pBottom) * (1 - math.exp(-22 * dt))
			end
			presser:PivotTo(CFrame.new(placed.X, pBottom + discHalf, placed.Z) * pRot)
		else
			break
		end
	end

	-- 결과: 틀 아래로 선이 파이고, 틀을 들면 자국이 남음
	local clarity = Scoring.stampForce(rec.hold) / 100
	dal:engrave(wires, clarity)
	if rec.hold > cfg.crackHold then
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
			S:springTo(cutter, S.rest.StarCutter, dt, 16)
		end
	end
	presser:PivotTo(S.rest.Presser)
	presser.Disc.Transparency = 0
	cutter:PivotTo(S.rest.StarCutter)
	rec.t1 = ctx.now()
	return rec
end

return Stamp
