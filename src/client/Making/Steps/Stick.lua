-- 막대 꽂기 (사용자 요청 2026-11-19: 달고나에 손잡이 만들기). 누르기 바로 전에 한다.
-- 조사(레시피 여러 곳): 반죽이 굳기 전, 부은 직후 말랑할 때 막대를 가장자리에서 가운데 쪽으로 얹고 그 위로 눌러 편다.
--   나무젓가락(둥글고 두꺼움)보다 얇고 납작한 아이스크림 막대가 얇은 달고나(약 3mm) 속에 잘 묻히고 구르지 않아서 이걸 씀.
-- 조작: 철판 오른쪽에 놓인 막대를 끌어 반죽 위에 놓기 (반죽 쪽 끝이 반죽 안에 들어가면 쏙 박힘). 막대를 한 번 누르기만 해도 알아서 꽂힘.

local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))

local Stick = {}

local LEN, WIDTH, THICK = 1.7, 0.17, 0.035
local WOOD = Color3.fromRGB(232, 204, 156)
local GRAB_PX = 130

local function build(S)
	local m = Instance.new("Model")
	m.Name = "DalgonaStick"
	local body = S:fxPart(m, { Name = "Body", Size = Vector3.new(LEN - WIDTH, THICK, WIDTH), Color = WOOD, Material = Enum.Material.Wood })
	local e1 = S:fxPart(m, { Name = "End1", Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK, WIDTH, WIDTH), Color = WOOD, Material = Enum.Material.Wood })
	local e2 = S:fxPart(m, { Name = "End2", Shape = Enum.PartType.Cylinder, Size = Vector3.new(THICK, WIDTH, WIDTH), Color = WOOD, Material = Enum.Material.Wood })
	m.PrimaryPart = body
	m.Parent = S.fx
	local function place(cf)
		body.CFrame = cf
		local half = (LEN - WIDTH) / 2
		e1.CFrame = cf * CFrame.new(half, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		e2.CFrame = cf * CFrame.new(-half, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	return m, place
end

-- 막대 놓기. 성공하면 st.stick = { dir, inner } 에 기록 (누르기·찍기 동안 Stick.follow로 반죽 높이에 맞춰 묻힘)
function Stick.place(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local dal = st.dalgona
	local plate = S.Plate
	local top = S.plateTop
	local half = plate.Size.X / 2
	local m, place = build(S)
	-- 철판 오른쪽 테이블 위에 세로(앞뒤)로 놓여 있음
	local restPos = Vector3.new(plate.Position.X + half + 0.45, top + THICK / 2, plate.Position.Z + 0.5)
	local restCF = CFrame.new(restPos) * CFrame.Angles(0, math.rad(90), 0)
	local cf = restCF
	place(cf)
	st.stickModel = m
	st.stickPlace = place
	ui:say("아이스크림 막대를 반죽에 꽂아요", "막대를 끌어 반죽 가장자리에 얹어요 · 눌러만 줘도 꽂혀요")
	local cam = workspace.CurrentCamera
	local seen = P.presses
	local grabbing, anchor, cf0, t0 = false, nil, nil, 0
	local liftY = dal:topY() + 0.25
	while true do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		if P.down and not grabbing and P.presses ~= seen then
			seen = P.presses
			local sp = cam:WorldToScreenPoint(cf.Position)
			if (Vector2.new(sp.X, sp.Y) - P.pos).Magnitude < GRAB_PX then
				grabbing = true
				anchor = P.toPlane(liftY)
				cf0 = cf
				t0 = os.clock()
				Sfx.play("pop", 0.5, 1.2)
			else
				ui:hint("오른쪽의 나무 막대를 끌어요")
			end
		end
		local c = dal.center
		local r = dal:radius()
		if grabbing then
			local d = P.toPlane(liftY) - anchor
			local pos = Vector3.new(cf0.Position.X + d.X, liftY, cf0.Position.Z + d.Z)
			-- 반죽 가까이 오면 막대가 반죽 가운데를 향하게 돌아감
			local toC = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
			local rot = cf0 - cf0.Position
			if toC.Magnitude < r + LEN then
				rot = CFrame.lookAt(Vector3.zero, Vector3.new(toC.Unit.Z, 0, -toC.Unit.X)) -- 길이 축(X) = 가운데 → 바깥
			end
			cf = cf:Lerp(CFrame.new(pos) * rot, 1 - math.exp(-25 * dt))
			place(cf)
			if not P.down then
				grabbing = false
				local quick = os.clock() - t0 < 0.3 and d.Magnitude < 0.15
				-- 반죽 쪽 끝이 반죽 안이면 꽂힘. 짧게 누르기만 하면 오른쪽 아래에서 알아서 꽂힘
				local inner = cf.Position - cf.RightVector * (LEN / 2) * (cf.RightVector:Dot(Vector3.new(cf.Position.X - c.X, 0, cf.Position.Z - c.Z)) > 0 and 1 or -1)
				local dir
				if quick then
					dir = Vector3.new(0.6, 0, 0.8).Unit
				elseif Vector3.new(inner.X - c.X, 0, inner.Z - c.Z).Magnitude < r * 0.85 then
					dir = Vector3.new(cf.Position.X - c.X, 0, cf.Position.Z - c.Z)
					dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0.6, 0, 0.8).Unit
				end
				if dir then
					st.stick = { dir = dir }
					Stick.follow(st)
					Sfx.play("pressSticky", 0.4, 1.4)
					ui:buzz(0.3, 0.05)
					ui:toast("막대 쏙!", 0.7)
					return true
				end
				ui:hint("막대 끝을 반죽 위에 얹어요")
			end
		else
			cf = cf:Lerp(restCF, 1 - math.exp(-18 * dt))
			place(cf)
		end
	end
end

-- 막대를 반죽 두께·크기에 맞춰 놓음: 반죽 가운데 쪽 끝은 반죽 속(가운데에서 반지름 35% 지점), 나머지는 바깥으로 삐져나옴
function Stick.follow(st)
	local s = st.stick
	local dal = st.dalgona
	if not (s and dal and st.stickPlace) then
		return
	end
	local r = dal:radius()
	local c = dal.center
	local innerDist = r * 0.35
	local mid = c + s.dir * (innerDist + LEN / 2)
	-- 철판 위에 납작하게 누움: 반죽 쪽은 반죽 속에 묻히고(반죽이 퍼질수록 더 덮임), 바깥쪽은 철판 위로 삐져나옴
	local y = c.Y + THICK / 2 + 0.004
	local look = Vector3.new(s.dir.Z, 0, -s.dir.X)
	st.stickPlace(CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + look))
end

return Stick
