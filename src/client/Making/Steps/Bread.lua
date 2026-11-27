-- 달고나빵 (2026-11-27 사용자 "누르지 않은 반죽 위에 설탕가루 뿌린 게 달고나빵, 메뉴에 추가하고 가격 책정"):
-- 붓기 뒤 "누르기 / 달고나빵" 중 달고나빵을 고르면 누르기·모양 찍기 대신 이 단계.
-- 화면을 누르고 있으면 봉긋한 반죽 위로 설탕 가루가 솔솔 떨어져 쌓임 → 알맞게 덮이면 손을 뗌.
-- 기록 rec = { t0, t1, amount } (amount 1 = 알맞게 덮임, 0.65~1.0이 가장 좋음). 점수는 Scoring.bread, 값은 G.BreadBasePrice.
-- 반죽 모양(붓기 뒤 그대로, BatterMesh)은 건드리지 않음 — 설탕 결정만 얹음.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Scoring = require(Shared:WaitForChild("Scoring"))
local Making = script.Parent.Parent
local Fx = require(Making:WaitForChild("Fx"))
local Sfx = require(Making:WaitForChild("Sfx"))

local Bread = {}

local FULL = 1.6 -- 이 초 동안 누르고 있으면 amount 1 (알맞게 덮임)
local GRAINS = 240 -- amount 1일 때 결정 수 (고운 가루라 작고 많이)
local WHITE = Color3.fromRGB(252, 252, 250)
Bread.LO, Bread.HI = 0.65, 1.0

-- 반죽 윗면 높이: 3D 반죽 메시에 위에서 광선을 쏴서 실제로 그려진 표면 (2026-11-27 Studio 확인: BatterMesh.surfaceY는
-- 정점 계산값이라 화면에 보이는 표면보다 낮게 나와 설탕이 반죽 속에 묻혔음). 안 맞으면 계산값·꼭대기
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function surfaceAt(dal, p)
	local b = dal.batter
	if b and b.part then
		local hit = workspace:Raycast(Vector3.new(p.X, dal.center.Y + 4, p.Z), Vector3.new(0, -6, 0), rayParams)
		if hit then
			return hit.Position.Y
		end
	end
	local y = b and b:surfaceY(p)
	return y or dal:topY()
end

function Bread.run(ctx)
	local ui, S, P = ctx.ui, ctx.station, ctx.pointer
	local dal = ctx.state.dalgona
	if not dal then
		return nil
	end
	local t0 = ctx.now()
	ui:say("설탕 가루를 솔솔 뿌려요", "화면을 누르고 있으면 뿌려져요 · 위가 하얗게 덮이면 손을 떼요")
	local amount, pressed, grains = 0, false, {}
	ctx.state.breadGrains = grains
	local seen = P.presses
	local R = dal:radius() * 0.85 -- 뿌리는 범위 = 반죽 반지름의 85%
	local c = dal.center
	-- 반죽 부품은 평소 CanQuery = false → 뿌리는 동안만 광선이 맞게
	local bpart = dal.batter and dal.batter.part
	if bpart then
		bpart.CanQuery = true
		rayParams.FilterDescendantsInstances = { bpart }
	end
	local function done()
		if bpart and bpart.Parent then
			bpart.CanQuery = false
		end
	end
	while true do
		local dt = ctx.frame()
		if not dt then
			Sfx.loop("sugarPour", 0, 1)
			done()
			return nil
		end
		local down = P.down and (pressed or P.presses ~= seen)
		if down then
			pressed = true
			amount = math.min(1.6, amount + dt / FULL)
			Sfx.loop("sugarPour", 0.35, 1.1)
			-- 반죽 위에 결정 낱알 (가운데 쪽이 조금 더 많이)
			while #grains < math.floor(GRAINS * math.min(amount, 1.6)) do
				local a = math.random() * 2 * math.pi
				local r = math.random() ^ 0.85 * R -- 가운데 쪽이 더 촘촘
				local p = Vector3.new(c.X + math.cos(a) * r, 0, c.Z + math.sin(a) * r)
				local sz = 0.016 + math.random() * 0.016
				local y = surfaceAt(dal, p) + sz * 0.3
				local props = {
					Name = "BreadSugar",
					Size = Vector3.one * sz,
					Color = WHITE,
					Material = Enum.Material.SmoothPlastic,
					Reflectance = 0.08,
					CFrame = CFrame.new(p.X, y, p.Z) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3),
				}
				local g = Fx.template("SugarCrystal") and Fx.mesh("SugarCrystal", S.fx, props) or S:fxPart(S.fx, props)
				table.insert(grains, g)
			end
		elseif pressed then
			break
		else
			Sfx.loop("sugarPour", 0, 1)
		end
		local pct = math.floor(amount * 100 + 0.5)
		ui:setMeter(true, amount / 1.6, Bread.LO / 1.6, Bread.HI / 1.6, string.format("%d%%", pct), "설탕")
		ctx.live("bread", Scoring.bread({ amount = amount }))
	end
	Sfx.stopLoop("sugarPour")
	done()
	ui:setMeter(false)
	if amount >= Bread.LO and amount <= Bread.HI then
		ui:toast("설탕이 딱 알맞아요!", 0.8)
	elseif amount < Bread.LO then
		ui:toast("설탕이 조금 적어요", 0.8)
	else
		ui:toast("설탕이 너무 많아요", 0.8)
	end
	return { t0 = t0, t1 = ctx.now(), amount = amount }
end

return Bread
