-- 5. 누르기 (사용자 요청 2026-11-19 다시 정리):
--   ① 막대 꽂기 (Stick) ② 누름판을 클릭하면 손에 들고 반죽 위에 떠 있음 (끌고 올 필요 없음)
--   ③ 화면을 누르고 있는 동안 눌림: 처음엔 천천히, 오래 누를수록 빨라짐(꾹 누르면 훅). 떼면 멈추고 올라옴
--   ④ 아래 게이지 바늘이 초록 칸(이번 목표 두께)에 들어갔을 때 떼면 1번 성공 → 3번. 초록 전에 떼면 이어서 더 누르면 됨
-- 점수: 3번 모두 목표 두께 근처에서 멈췄는지 (±18% 안이면 만점). 너무 얇으면 가장자리가 갈라짐.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local PresserGrab = require(script.Parent.Parent:WaitForChild("PresserGrab"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))
local Stick = require(script.Parent:WaitForChild("Stick"))

local Press = {}

local HOVER = 0.7
local PICK_PX = 150
local BAND = 0.18 -- 목표 두께 ±18% = 초록 칸 (Scoring.pressOne과 같음)
local RING_COLOR = Color3.fromRGB(150, 255, 140) -- 연두색
local RING_SEGMENTS = 48

-- 누름판에 가려도 달고나가 퍼지는 크기가 보이게: 반투명 연두색 원 선
local function makeRing(S)
	local folder = Instance.new("Folder")
	folder.Name = "PressRing"
	for _ = 1, RING_SEGMENTS do
		S:fxPart(folder, { Name = "Seg", Material = Enum.Material.Neon, Color = RING_COLOR, Transparency = 0.25, Size = Vector3.new(0.09, 0.03, 0.1) })
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

-- 누르고 있는 시간 → 얇아지는 빠르기 (두께 비율/초). 0.35에서 시작해 1초 뒤 약 2.6
local function rateFor(holdT)
	return 0.35 + 2.2 * holdT * holdT
end

function Press.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local cfg = Config.Press
	local rec = { t0 = ctx.now(), thick = {}, cracked = false }
	local dal = st.dalgona
	local presser = S.Presser
	local discHalf = presser.Disc.Size.X / 2
	local c = dal.center
	-- 0. 막대 꽂기 (반죽이 말랑할 때)
	if not st.stick then
		if not Stick.place(ctx) then
			return nil
		end
	end
	S:presserSeeThrough(true)
	local ring = makeRing(S)
	placeRing(S, ring, dal)
	local pv = presser:GetPivot()
	local grab = PresserGrab.new(S, P, pv.Position - Vector3.new(0, discHalf, 0))
	local cam = workspace.CurrentCamera
	local h = dal.h
	local hMin = cfg.crack * 0.8

	-- ① 누름판 집기: 누르면 손에 들고 반죽 위로 날아옴
	ui:say("누름판을 눌러 들어요", "누름판을 누르면 손에 들려요")
	local seen = P.presses
	local missed = false
	while true do
		local dt = ctx.frame()
		if not dt then
			ui:setArrow(nil)
			return nil
		end
		-- 안내가 보일 때(처음 판들 · 막혔을 때 · 한 번 빗나갔을 때) 누름판을 화살표로 가리킴 (2026-11-20)
		local ap = cam:WorldToScreenPoint(grab:worldBottom() + Vector3.new(0, discHalf * 2 + 0.3, 0))
		ui:setArrow((ui:subShown() or missed) and Vector2.new(ap.X, ap.Y) or nil, "누름판")
		if P.down and P.presses ~= seen then
			seen = P.presses
			local sp = cam:WorldToScreenPoint(grab:worldBottom() + Vector3.new(0, discHalf * 2, 0))
			if (Vector2.new(sp.X, sp.Y) - P.pos).Magnitude < PICK_PX or missed then
				break
			end
			missed = true -- 한 번 빗나가면 다음엔 어디를 눌러도 들림
			ui:hint("누름판을 눌러요")
		end
		grab:draw()
	end
	ui:setArrow(nil)
	Sfx.play("pop", 0.6, 1.0)
	ui:buzz(0.3, 0.05)
	-- 반죽 위로 날아와 떠 있음
	local hover = dal:topY() + HOVER
	local t = 0
	local fromPos, fromBottom = grab.pos, grab.bottom
	while t < 0.3 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		local k = 1 - (1 - math.min(t / 0.3, 1)) ^ 3
		grab.pos = fromPos:Lerp(Vector3.new(c.X, 0, c.Z), k)
		grab.bottom = fromBottom + (hover - fromBottom) * k + math.sin(k * math.pi) * 0.5
		grab:draw()
		placeRing(S, ring, dal)
	end
	seen = P.presses -- 집을 때 누른 것은 누르기로 치지 않음

	-- ② 3번 나눠 누르기
	-- 2026-11-20 (사용자 요청): 누름판은 드는 것까지만 보이고, 누르는 동안엔 사라져서 반죽이 눌려 퍼지는 게 보임
	local presserParts = {}
	for _, d in ipairs(S.Presser:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(presserParts, d)
		end
	end
	local presserOutline = S.Presser:FindFirstChild("ToonOutline")
	local fade = 0
	local pressedOnce = false
	local function fadePresser(k)
		for _, d in ipairs(presserParts) do
			d.LocalTransparencyModifier = k
		end
		if presserOutline then
			presserOutline.Enabled = k < 0.5
		end
	end
	local count = 0
	local holding, contact, holdT = false, false, 0
	local hStart = h
	local bottom = hover
	while count < 3 do
		local dt = ctx.frame()
		if not dt then
			ui:setGauge(false)
			fadePresser(0)
			return nil
		end
		local target = cfg.targets[count + 1]
		local lo, hi = target * (1 - BAND), target * (1 + BAND)
		hover = dal:topY() + HOVER
		if P.down and not holding and P.presses ~= seen then
			seen = P.presses
			holding = true
			contact = false
			holdT = 0
		end
		if holding then
			local surface = c.Y + h * 0.75
			if not contact then
				bottom = math.max(bottom - 7 * dt, surface)
				if bottom <= surface + 1e-3 then
					contact = true
					ui:buzz(0.3, 0.05)
					Sfx.play("pressSticky", 0.7, 1.0)
				end
			else
				holdT += dt
				h = math.max(h - rateFor(holdT) * h * dt, hMin)
				bottom = c.Y + h * 0.75
				dal:setThickness(h)
				Stick.follow(st)
				if h < cfg.crack and not rec.cracked then
					rec.cracked = true
					dal:crack(6, 0.5)
					Sfx.play("pressSticky", 0.8, 0.7) -- 누르고 있는 그 순간 "쩍" (2026-11-20)
					ui:hint("너무 얇아서 가장자리가 갈라졌어요")
					ui:buzz(0.8, 0.15)
				end
			end
			if not P.down then
				holding = false
				if contact then
					Sfx.play("pressSticky", 0.45, 1.3)
				end
				-- 2026-11-20 "녹색까지 못 갔어도 한 번 누르면 차감": 닿았다가 떼면 초록 칸이든 아니든 한 번으로 침
				-- (덜 눌렀으면 두꺼운 만큼 점수가 깎임)
				if contact then
					count += 1
					rec.thick[count] = h
					print(string.format("[Press] %d번째 두께 %.3f (목표 %.3f)", count, h, target))
					local sc = Scoring.pressOne(count, h)
					if sc >= 95 then
						ui:toast(count < 3 and "딱 좋아요!" or "완벽해요!", 0.8)
					elseif h < lo then
						ui:hint("조금 너무 눌렀어요 (바늘이 초록 칸일 때 떼요)")
					elseif h > hi then
						ui:hint("덜 눌렸어요 (바늘이 초록 칸에 오면 떼요)")
					else
						ui:toast("좋아요!", 0.7)
					end
					hStart = h
					ui:buzz(0.3, 0.05)
				end
				contact = false
			end
		else
			bottom += (hover - bottom) * (1 - math.exp(-22 * dt))
		end
		grab.bottom = bottom
		grab:draw()
		-- 한 번 눌러 닿은 뒤로는 누르기가 끝날 때까지 계속 숨김 (2026-11-20: 누르는 중간중간 다시 보이지 않게)
		if contact then
			pressedOnce = true
		end
		fade += ((pressedOnce and 1 or 0) - fade) * (1 - math.exp(-14 * dt))
		fadePresser(fade)
		placeRing(S, ring, dal)
		local nt = cfg.targets[math.min(count + 1, 3)]
		if count < 3 then
			ui:setPressGauge(true, h, hStart, hMin, nt * (1 - BAND), nt * (1 + BAND))
			if holding and contact then
				ui:say(string.format("꾹! (%d / 3)", count + 1), "바늘이 초록 칸에 오면 손을 떼요 · 오래 누를수록 빨라져요")
			else
				ui:say(string.format("화면을 누르고 있으면 눌려요 (%d / 3)", count + 1), count == 0 and "천천히! 3번 나눠서 넓고 얇게" or (count == 1 and "조금 더 얇게" or "마지막! 넓고 얇게"))
			end
		end
		local partial = { thick = {}, cracked = rec.cracked }
		for i = 1, 3 do
			partial.thick[i] = rec.thick[i] or cfg.targets[i]
		end
		ctx.live("press", Scoring.press(partial))
	end

	ui:setGauge(false)
	fadePresser(0)
	ui:say("넓고 얇게 잘 펴졌어요!", "")
	t = 0
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
