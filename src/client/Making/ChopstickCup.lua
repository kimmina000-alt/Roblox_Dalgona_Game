-- 0. 나무젓가락 꺼내기 (사용자 요청 2026-11-19: 포장 찢기·쪼개기 대신, 나무젓가락이 잔뜩 든 통에서 눌러서 하나 꺼냄)
-- 통(서버 StallDecor가 만든 ChopstickCup)을 누르면 젓가락 한 짝이 쏙 뽑혀 올라왔다가 테이블 위 자리(Stick1)에 눕고,
-- 그 짝으로 제작을 시작한다. 반환값은 예전 ChopstickPicker와 같음 { pair, side } → Station:useChopstick

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Cup = {}

local RISE = 0.3 -- 뽑혀 올라오는 시간
local LAY = 0.32 -- 테이블 위 자리로 눕는 시간

function Cup.run(ctx)
	local S, P, ui = ctx.station, ctx.pointer, ctx.ui
	local cup = S.model:FindFirstChild("ChopstickCup")
	local sticks = {}
	if cup then
		for _, c in ipairs(cup:GetChildren()) do
			if c.Name == "CupStick" then
				c.LocalTransparencyModifier = 0
				table.insert(sticks, c)
			end
		end
	end
	if #sticks == 0 then
		return { pair = 1, side = "A" } -- 통이 없으면 건너뜀
	end
	ui:say("나무젓가락 통에서 하나 꺼내요", "통을 눌러요")
	local seen = P.presses
	local cam = workspace.CurrentCamera
	local center = cup:GetPivot().Position
	while true do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		if P.down and P.presses ~= seen then
			seen = P.presses
			local sp = cam:WorldToScreenPoint(center + Vector3.new(0, 1, 0))
			if (Vector2.new(sp.X, sp.Y) - P.pos).Magnitude < 200 then
				break
			end
			ui:hint("나무젓가락 통을 눌러요")
		end
	end
	-- 누른 자리에서 가장 가까운 젓가락 (화면 기준, 윗끝)
	local best, bestD = sticks[1], math.huge
	for _, s in ipairs(sticks) do
		local tipPos = s.Position + s.CFrame.RightVector * (s.Size.X / 2)
		local sp = cam:WorldToScreenPoint(tipPos)
		local d = (Vector2.new(sp.X, sp.Y) - P.pos).Magnitude + math.random() * 20
		if d < bestD then
			best, bestD = s, d
		end
	end
	local name = best:GetAttribute("Tpl") or "Stick1A"
	local pair, side = tonumber(name:sub(6, 6)) or 1, name:sub(7, 7)
	if side ~= "A" and side ~= "B" then
		side = "A"
	end
	Sfx.play("pop", 0.7, 1.0)
	ui:buzz(0.3, 0.05)
	-- 뽑기: 통에서 위로 쏙
	local start = best.CFrame
	local up = start + Vector3.new(0, best.Size.X * 0.85, 0)
	local t = 0
	while t < RISE do
		local dt = ctx.frame()
		if not dt then
			best.CFrame = start
			return nil
		end
		t += dt
		local k = 1 - (1 - math.min(t / RISE, 1)) ^ 3
		best.CFrame = start:Lerp(up, k)
	end
	-- 눕기: Station:useChopstick이 놓는 자리와 같은 자세로 (그 자리에 Chosen이 생기면서 바꿔치기)
	local lie = S.Chopsticks.Stick1.CFrame * CFrame.Angles(math.rad(90), 0, 0)
	if best.Size.X > best.Size.Y * 2 then
		lie = lie * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.pi, 0, 0)
	end
	t = 0
	while t < LAY do
		local dt = ctx.frame()
		if not dt then
			best.CFrame = start
			return nil
		end
		t += dt
		local k = math.min(t / LAY, 1)
		local e = k * k * (3 - 2 * k)
		local cf = up:Lerp(lie, e)
		best.CFrame = cf + Vector3.new(0, math.sin(k * math.pi) * 0.6, 0) -- 살짝 포물선
	end
	best.CFrame = start
	best.LocalTransparencyModifier = 1 -- 통에서는 빠진 것처럼 (다음 판에 다시 채움)
	Sfx.play("pop", 0.5, 1.3)
	return { pair = pair, side = side }
end

return Cup
