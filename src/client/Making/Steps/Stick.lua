-- 막대 꽂기 (사용자 요청 2026-11-19: 달고나에 손잡이 만들기). 누르기 바로 전에 한다.
-- 조사(레시피 여러 곳): 반죽이 굳기 전, 부은 직후 말랑할 때 막대를 가장자리에서 가운데 쪽으로 얹고 그 위로 눌러 편다.
--   나무젓가락(둥글고 두꺼움)보다 얇고 납작한 아이스크림 막대가 얇은 달고나(약 3mm) 속에 잘 묻히고 구르지 않아서 이걸 씀.
-- 조작: 철판 오른쪽에 놓인 막대를 끌어 반죽 위에 놓기 (반죽 쪽 끝이 반죽 안에 들어가면 쏙 박힘). 막대를 한 번 누르기만 해도 알아서 꽂힘.

local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))
local Toon = require(script.Parent.Parent:WaitForChild("Toon"))
local Stir = require(script.Parent.Parent:WaitForChild("Stir")) -- 기본 꽂는 방향 (화면 오른쪽 아래)

local Stick = {}

local LEN, WIDTH, THICK = 1.7, 0.17, 0.035
local WOOD = Color3.fromRGB(232, 204, 156)
local GRAB_PX = 130
local HEM_TOP = 0.065 -- 철판 윗면에서 접은 테두리 꼭대기까지 (StallDecor galvanizedBoard)

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

-- 막대가 쉬는 자리: 철판 오른쪽 테이블 위에 세로(앞뒤)로. 그 자리에 누름판 같은 물건이 있으면 (가게 작업대: 누름판 밑에 깔려
-- 안 보였음, 2026-11-21) 철판 앞 → 왼쪽 순서로 빈 자리를 찾음
local function restOf(S)
	-- 새 배치: 달고나 막대 네모 통(속성 StackUp)이 있으면 그 통 맨 위에 길게 놓인 막대를 꺼냄 (2026-11-21 사용자)
	local decor = S.model:FindFirstChild("Stage1Decor")
	local box = decor and decor:FindFirstChild("StickCup", true) -- 묶음(모델) 안에 있을 수 있음
	if box and box:GetAttribute("StackUp") then
		local pos = box.Position + Vector3.new(0, box:GetAttribute("StackUp") + THICK / 2, 0)
		return CFrame.new(pos) * S.rot * CFrame.Angles(0, math.rad(90), 0)
	end
	local plate = S.Plate
	local top = S.plateTop
	local half = plate.Size.X / 2
	local spots = { { half + 0.45, 0.5, 90 }, { 0.3, half + 0.45, 0 }, { -half - 0.45, 0.5, 90 } }
	local olp = OverlapParams.new()
	olp.FilterType = Enum.RaycastFilterType.Include
	olp.FilterDescendantsInstances = { S.model }
	local restCF
	for _, sp in ipairs(spots) do
		local pos = Vector3.new(plate.Position.X, top + THICK / 2, plate.Position.Z) + S:dir(sp[1], 0, sp[2])
		local cf = CFrame.new(pos) * S.rot * CFrame.Angles(0, math.rad(sp[3]), 0)
		local blocked = false
		for _, p in ipairs(workspace:GetPartBoundsInBox(cf * CFrame.new(0, 0.3, 0), Vector3.new(LEN, 0.5, WIDTH * 2), olp)) do
			if p ~= plate and p.Transparency < 1 and p.LocalTransparencyModifier < 1 and p.Name:sub(1, 8) ~= "TableTop" then
				blocked = true
				break
			end
		end
		restCF = restCF or cf
		if not blocked then
			return cf
		end
	end
	return restCF
end

-- 철판 위 설탕 꾸밈(결정·가루)이 막대를 뚫고 나와 구멍 난 것처럼 보임 (2026-11-21) → 막대가 놓인 줄 위의 것만 내 화면에서 숨김
local hiddenSugar = {}
local function restoreSugar()
	for _, p in ipairs(hiddenSugar) do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	table.clear(hiddenSugar)
end
local function hideSugarUnder(S, c, dir)
	local decor = S.model:FindFirstChild("Stage1Decor")
	if not decor then
		return
	end
	local olp = OverlapParams.new()
	olp.FilterType = Enum.RaycastFilterType.Include
	olp.FilterDescendantsInstances = { decor }
	local L = 3.2 -- 반죽 가운데부터 막대 바깥 끝까지 넉넉히
	local box = CFrame.lookAt(c, c + dir) * CFrame.new(0, 0, -L / 2)
	for _, p in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(WIDTH + 0.14, 0.6, L), olp)) do
		if p.Name:sub(1, 5) == "Sugar" and p.LocalTransparencyModifier < 1 then
			p.LocalTransparencyModifier = 1
			table.insert(hiddenSugar, p)
		end
	end
end

-- 막대를 미리 쉬는 자리에 꺼내 둠 (새 배치: 반죽 붓는 화면부터 보이게, 2026-11-21 사용자). 이어서 Stick.place가 이 막대를 씀
function Stick.show(ctx)
	local S, st = ctx.station, ctx.state
	if st.stickPre then
		return
	end
	restoreSugar()
	local m, place = build(S)
	place(restOf(S))
	st.stickPre = { m, place }
end

-- 막대 놓기. 성공하면 st.stick = { dir, inner } 에 기록 (누르기·찍기 동안 Stick.follow로 반죽 높이에 맞춰 묻힘)
function Stick.place(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local dal = st.dalgona
	local restCF = restOf(S)
	local m, place
	if st.stickPre and st.stickPre[1].Parent then
		m, place = st.stickPre[1], st.stickPre[2]
	else
		restoreSugar()
		m, place = build(S)
		place(restCF)
	end
	st.stickPre = nil
	local cf = m.PrimaryPart.CFrame
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
					dir = Stir.screenDir(0.6, 0, 0.8)
				elseif Vector3.new(inner.X - c.X, 0, inner.Z - c.Z).Magnitude < r * 0.85 then
					dir = Vector3.new(cf.Position.X - c.X, 0, cf.Position.Z - c.Z)
					dir = dir.Magnitude > 1e-3 and dir.Unit or Stir.screenDir(0.6, 0, 0.8)
				end
				if dir then
					st.stick = { dir = dir }
					Stick.follow(st)
					hideSugarUnder(S, Vector3.new(c.X, S.plateTop, c.Z), dir)
					-- 꽂은 뒤로는 막대도 다른 도구처럼 만화 외곽선 (2026-11-20)
					if st.stickModel then
						Toon.outline(st.stickModel)
					end
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
-- flat = true면 철판 테두리 걸침(살짝 들기) 없이 평평하게 (포장 매트로 옮긴 뒤: 2026-11-20 "막대 끝이 끊겨 보임")
function Stick.follow(st, flat)
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
	-- 철판 가장자리 접은 테두리(높이 약 0.06)에 막대가 묻혀 가려지지 않게 (2026-11-20 "막대기는 설탕판에 가려짐"):
	-- 막대 바깥쪽이 테두리에 닿으면 반죽 속 끝을 축으로 살짝 들어 테두리 위로 걸침
	local plate = dal.S and dal.S.Plate
	local tilt = 0
	if plate and not flat then
		local d = s.dir
		local hx, hz = plate.Size.X / 2, plate.Size.Z / 2
		local ox, oz = c.X - plate.Position.X, c.Z - plate.Position.Z
		local tx = math.abs(d.X) > 1e-3 and ((d.X > 0 and hx or -hx) - ox) / d.X or math.huge
		local tz = math.abs(d.Z) > 1e-3 and ((d.Z > 0 and hz or -hz) - oz) / d.Z or math.huge
		local tEdge = math.min(tx, tz) - 0.07 -- 테두리 안쪽 면
		if innerDist + LEN > tEdge and tEdge > innerDist + 0.2 then
			tilt = math.atan2(HEM_TOP - THICK / 2 - 0.004 + 0.008, tEdge - innerDist)
		end
	end
	if tilt > 0 then
		local up = Vector3.yAxis
		local ax = (s.dir * math.cos(tilt) + up * math.sin(tilt)).Unit
		local ay = (up * math.cos(tilt) - s.dir * math.sin(tilt)).Unit
		local p0 = Vector3.new(c.X, y, c.Z) + s.dir * innerDist
		st.stickPlace(CFrame.fromMatrix(p0 + ax * (LEN / 2), ax, ay))
		return
	end
	local look = Vector3.new(s.dir.Z, 0, -s.dir.X)
	st.stickPlace(CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + look))
end

return Stick
