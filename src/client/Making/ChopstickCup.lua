-- 0. 나무젓가락 꺼내기 (사용자 요청 2026-11-19)
-- 통(서버 StallDecor가 만든 ChopstickCup)에 포장된 나무젓가락이 꽂혀 있음. 통을 누르면 하나가 쏙 뽑혀 올라오고,
-- 그 자리에서 예전 고르기 연출(ChopstickPicker: 포장지 찢기 → 꺼내기 → 쪼개기 → 한 짝 고르기)로 이어짐.
-- 반환값은 ChopstickPicker와 같음 { pair, side } → Station:useChopstick

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Picker = require(script.Parent:WaitForChild("ChopstickPicker"))

local Cup = {}

local RISE = 0.35 -- 뽑혀 올라오는 시간

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
		return Picker.run(ctx) -- 통이 없으면 예전처럼 테이블 위 포장 젓가락
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
		local tipPos = s.Position + s.CFrame.UpVector * (s.Size.Y / 2)
		local sp = cam:WorldToScreenPoint(tipPos)
		local d = (Vector2.new(sp.X, sp.Y) - P.pos).Magnitude + math.random() * 20
		if d < bestD then
			best, bestD = s, d
		end
	end
	Sfx.play("pop", 0.7, 1.0)
	ui:buzz(0.3, 0.05)
	-- 뽑기: 통에서 위로 쏙 (똑바로 세우며)
	local start = best.CFrame
	local up = CFrame.new(start.Position + Vector3.new(0, best.Size.Y * 0.9, 0)) * CFrame.Angles(0, select(2, start:ToEulerAnglesYXZ()), 0)
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
	-- 그 자리에서 포장지 찢기부터 (Picker가 이 젓가락을 숨기고 같은 자리에서 크게 보여 줌)
	local result = Picker.run(ctx, { from = best })
	best.CFrame = start
	best.LocalTransparencyModifier = 1 -- 통에서는 빠진 것처럼 (다음 판에 다시 채움)
	return result
end

return Cup
