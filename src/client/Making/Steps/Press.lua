-- 5. 누르기: 꾹 누르고 있으면 누름판이 내려가고, 떼면 올라감. "확! 누르지 말고 3번 나눠서"
-- 매번 원판이 넓어지고 얇아짐. 점수: 3번 모두 목표 두께 구간에 멈췄는지. 너무 얇으면 가장자리가 갈라짐.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Press = {}

local HOVER = 0.7

function Press.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Press
	local rec = { t0 = ctx.now(), thick = {}, cracked = false }
	local dal = st.dalgona
	local presser = S.Presser
	local rot = S.rest.Presser - S.rest.Presser.Position
	local discHalf = presser.Disc.Size.X / 2
	local c = dal.center
	presser.Disc.Transparency = 0.55 -- 위에서 내려다봐도 아래 반죽이 퍼지는 게 보이게

	local function presserAt(bottomY)
		return CFrame.new(c.X, bottomY + discHalf, c.Z) * rot
	end

	-- 누름판이 반죽 위로 날아옴
	local t = 0
	while t < 0.3 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		S:springTo(presser, presserAt(dal:topY() + HOVER), dt, 18)
	end

	local count = 0
	local seenPress = P.presses
	local holding = false
	local contact = false
	local hStart = dal.h
	local bottom = dal:topY() + HOVER
	local overHinted = false
	local h = dal.h

	ui:say("꾹 눌렀다 떼요 (1 / 3)", "확! 누르지 말고 3번 나눠서")

	while count < 3 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		local target = cfg.targets[count + 1]
		if P.down and not holding and P.presses ~= seenPress then
			seenPress = P.presses
			holding = true
			contact = false
			hStart = h
			overHinted = false
		end
		if holding then
			local surface = c.Y + h * 0.75
			if not contact then
				bottom -= 7 * dt
				if bottom <= surface then
					bottom = surface
					contact = true
					ui:buzz(0.3, 0.05)
				end
			else
				h = math.max(h - cfg.k * h * dt, cfg.crack * 0.8) -- 더 눌러도 이 이상 얇아지지 않음
				bottom = c.Y + h * 0.75
				dal:setThickness(h)
				local nextT = cfg.targets[count + 2]
				if nextT and h < nextT * 1.05 and not overHinted then
					overHinted = true
					ui:hint("확! 누르지 말고 나눠서 눌러요")
				end
				if h < cfg.crack and not rec.cracked then
					rec.cracked = true
					dal:crack(6, 0.5)
					ui:hint("너무 얇아서 가장자리가 갈라졌어요")
					ui:buzz(0.8, 0.15)
				end
			end
			presser:PivotTo(presserAt(bottom))
			if not P.down then
				holding = false
				-- 이미 가장 얇아졌으면 더 줄지 않아도 누른 것으로 셈 (안 그러면 단계가 안 끝남)
				if hStart - h > 0.02 or (contact and h <= cfg.crack * 0.81) then
					count += 1
					h = h * 1.04 -- 떼면 살짝 되돌아옴
					dal:setThickness(h)
					rec.thick[count] = h
					local s = Scoring.pressOne(count, h)
					if h > target * 1.25 then
						ui:hint("조금 더 길게 꾹 눌러요")
					elseif s >= 80 then
						ui:toast(count < 3 and "좋아요!" or "딱 좋아요!", 0.8)
					end
					ui:buzz(0.3, 0.05)
					if count < 3 then
						ui:say(string.format("꾹 눌렀다 떼요 (%d / 3)", count + 1), count == 1 and "두꺼운 원판 → 조금 더" or "마지막! 넓고 얇게")
					end
				elseif contact then
					ui:hint("조금 더 길게 꾹 눌러요")
				end
			end
		else
			local hover = dal:topY() + HOVER
			bottom += (hover - bottom) * (1 - math.exp(-22 * dt)) -- 떼면 0.1~0.2초 스프링 복귀
			presser:PivotTo(presserAt(bottom))
		end
		local nextTarget = cfg.targets[math.min(count + 1, 3)]
		ui:setMeter(true, h / cfg.h0, nextTarget * 0.82 / cfg.h0, nextTarget * 1.18 / cfg.h0, "두께")
		local partial = { thick = {}, cracked = rec.cracked }
		for i = 1, 3 do
			partial.thick[i] = rec.thick[i] or cfg.targets[i]
		end
		ctx.live("press", Scoring.press(partial))
	end

	ui:setMeter(false)
	ui:say("넓고 얇게 잘 펴졌어요!", "")
	t = 0
	while t < 0.4 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		if t > 0.15 then
			S:springTo(presser, S.rest.Presser, dt, 16)
		else
			presser:PivotTo(presserAt(dal:topY() + HOVER * (t / 0.15)))
		end
	end
	presser:PivotTo(S.rest.Presser)
	presser.Disc.Transparency = 0
	rec.t1 = ctx.now()
	return rec
end

return Press
