-- 5. 누르기: 누름판을 잡아 반죽 위로 가져와 꾹 멈추고 있으면 내려가고, 떼거나 옆으로 끌면 올라감. "확! 누르지 말고 3번 나눠서"
-- 매번 원판이 넓어지고 얇아짐. 점수: 3번 모두 목표 두께 구간에 멈췄는지. 너무 얇으면 가장자리가 갈라짐.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local PresserGrab = require(script.Parent.Parent:WaitForChild("PresserGrab"))

local Press = {}

local HOVER = 0.7
local RING_COLOR = Color3.fromRGB(150, 255, 140) -- 연두색
local RING_SEGMENTS = 48

-- 누름판에 가려도 달고나가 퍼지는 크기가 보이게: 반투명 연두색 원 선.
-- 얇은 네온 조각 48개를 누름판 원판 바로 위 높이에 띄움 (카메라가 위에서 보므로 누름판에 안 가림)
local function makeRing(S)
	local folder = Instance.new("Folder")
	folder.Name = "PressRing"
	for _ = 1, RING_SEGMENTS do
		S:fxPart(folder, {
			Name = "Seg",
			Material = Enum.Material.Neon,
			Color = RING_COLOR,
			Transparency = 0.25,
			Size = Vector3.new(0.09, 0.03, 0.1),
		})
	end
	folder.Parent = S.fx
	return folder
end

local function placeRing(S, ring, dal)
	local r = dal:radius()
	local c = dal.center
	local disc = S.Presser.Disc
	local y = math.max(dal:topY() + 0.02, disc.Position.Y + disc.Size.X / 2 + 0.03)
	for i, seg in ipairs(ring:GetChildren()) do
		local a0 = (i - 1) / RING_SEGMENTS * 2 * math.pi
		local a1 = i / RING_SEGMENTS * 2 * math.pi
		local p0 = Vector3.new(c.X + math.cos(a0) * r, y, c.Z + math.sin(a0) * r)
		local p1 = Vector3.new(c.X + math.cos(a1) * r, y, c.Z + math.sin(a1) * r)
		seg.Size = Vector3.new(0.09, 0.03, (p1 - p0).Magnitude + 0.02)
		seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
	end
end

function Press.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Press
	local rec = { t0 = ctx.now(), thick = {}, cracked = false }
	local dal = st.dalgona
	local presser = S.Presser
	local discHalf = presser.Disc.Size.X / 2
	local c = dal.center
	S:presserSeeThrough(true)
	local ring = makeRing(S)
	placeRing(S, ring, dal)

	-- 누름판은 손으로 가져와서 누름 (사용자 요청 2026-11-18, PresserGrab): 잡아서 반죽 위로 끌고 와
	-- 손가락을 꾹 멈추면 내려가 누르고, 떼거나 옆으로 끌면 올라옴. 누르는 횟수는 예전처럼 3번
	local pv = presser:GetPivot()
	local grab = PresserGrab.new(S, P, pv.Position - Vector3.new(0, discHalf, 0))
	if st.presserInHand and P.down then
		-- 붓기 뒤 도구 고르기에서 누름판을 잡고 넘어옴 → 잡은 채로 시작 (사용자 요청 2026-11-19)
		grab.grabbed = true
		grab.seen = P.presses
	end
	st.presserInHand = nil
	local function canPress(pos)
		return Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude < math.max(dal:radius() * 0.7, 0.35)
	end

	local count = 0
	local wasPressing = false
	local contact = false
	local hStart = dal.h
	local bottom = grab.bottom
	local overHinted = false
	local h = dal.h
	local everGrabbed = false

	ui:say("누름판을 잡아 반죽 위로 가져와요", "반죽 위에서 꾹 누르고 있으면 눌려요 (1 / 3)")

	while count < 3 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		local target = cfg.targets[count + 1]
		local carryY = dal:topY() + HOVER
		local ended, why = grab:update(dt, carryY, canPress)
		if why == "miss" then
			ui:hint("누름판을 눌러 잡아요")
		end
		if grab.grabbed then
			everGrabbed = true
		end
		if grab.pressing and not wasPressing then
			contact = false
			hStart = h
			overHinted = false
		end
		wasPressing = grab.pressing
		if grab.pressing then
			local surface = c.Y + h * 0.75
			if not contact then
				bottom = math.max(bottom - 7 * dt, surface)
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
		else
			-- 들고 있거나 놓아 둔 누름판은 반죽 위 높이에 떠 있음 (떼면 0.1~0.2초 스프링으로 올라옴)
			bottom += (carryY - bottom) * (1 - math.exp(-22 * dt))
		end
		if ended then
			-- 이미 가장 얇아졌으면 더 줄지 않아도 누른 것으로 셈 (안 그러면 단계가 안 끝남)
			if hStart - h > 0.02 or (contact and h <= cfg.crack * 0.81) then
				count += 1
				h = h * 1.04 -- 떼면 살짝 되돌아옴
				dal:setThickness(h)
				rec.thick[count] = h
				print(string.format("[Press] %d번째 두께 %.3f (목표 %.3f)", count, h, target))
				local sc = Scoring.pressOne(count, h)
				if h > target * 1.25 then
					ui:hint("조금 더 길게 꾹 눌러요")
				elseif sc >= 80 then
					ui:toast(count < 3 and "좋아요!" or "딱 좋아요!", 0.8)
				end
				ui:buzz(0.3, 0.05)
			elseif contact then
				ui:hint("조금 더 길게 꾹 눌러요")
			end
			contact = false
		end
		grab.bottom = bottom
		grab:draw()
		if count < 3 then
			if not everGrabbed then
				ui:say("누름판을 잡아 반죽 위로 가져와요", string.format("반죽 위에서 꾹 누르고 있으면 눌려요 (%d / 3)", count + 1))
			elseif grab.pressing then
				ui:say(string.format("꾹! (%d / 3)", count + 1), "떼거나 옆으로 끌면 올라와요")
			else
				ui:say(string.format("반죽 위에서 꾹 멈춰요 (%d / 3)", count + 1), count == 0 and "확! 누르지 말고 3번 나눠서" or (count == 1 and "두꺼운 원판 → 조금 더" or "마지막! 넓고 얇게"))
			end
		end
		placeRing(S, ring, dal)
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
	local t = 0
	while t < 0.4 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		S:springTo(presser, S.rest.Presser, dt, 16)
	end
	presser:PivotTo(S.rest.Presser)
	S:presserSeeThrough(false)
	ring:Destroy()
	rec.t1 = ctx.now()
	return rec
end

return Press
