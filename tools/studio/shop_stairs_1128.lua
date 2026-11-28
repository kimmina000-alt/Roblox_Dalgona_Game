-- 가게 2층 바깥 계단 충돌 (2026-11-28 사용자 "발이 계단에 묻히거나 뜸"). Studio 편집 모드에서 한 번 실행. shop_swap_1127.lua 다음.
-- 예전: 계단 전체를 매끈한 비탈(StairRamp) 하나로 → 발이 디딤판 앞쪽에서는 묻히고 뒤쪽에서는 뜸.
-- 지금: Blender 원본(store-1.blend "2-1 계단")의 디딤판 13장 + 층계참 윗면 높이 그대로 안 보이는 판(StairStep)을 놓고,
--       판과 판 사이 턱(1.97)은 앞 판 끝 0.9 구간에만 짧은 비탈(StairRiser)로 이어 걸어 오를 수 있게.
-- 좌표: Blender (x, y, z) → 부지 로컬 x = -(x - 46.03) × 1.56, y = (z + 0.768) × 1.56 + 0.4, z = (y + 2.485) × 1.56 - 18
local pl = workspace.PlotLayout
local plotCF = pl:GetAttribute("PlotCFrame")
local shell = pl.ShopModel.Shell1127
local S = 1.56
-- 디딤판 윗면: { y0, y1, z } (Blender, x는 모두 59.394 ~ 65.603)
local TREADS = {
	{ -2.485, -1.129, 0.396 }, { -1.129, 0.228, 1.660 }, { 0.228, 1.584, 2.925 }, { 1.584, 2.941, 4.189 },
	{ 2.941, 4.297, 5.453 }, { 4.297, 5.654, 6.717 }, { 5.654, 7.010, 7.981 }, { 7.010, 8.367, 9.245 },
	{ 8.367, 9.723, 10.510 }, { 9.723, 11.080, 11.774 }, { 11.080, 12.436, 13.038 }, { 12.436, 13.793, 14.302 },
	{ 13.793, 15.149, 15.566 }, { 15.149, 20.575, 16.830 },
}
local X0, X1 = -(59.394 - 46.03) * S, -(65.603 - 46.03) * S
local function lz(by)
	return (by + 2.485) * S - 18
end
local function ly(bz)
	return (bz + 0.768) * S + 0.4
end
for _, d in ipairs(shell:GetChildren()) do
	if d.Name == "StairRamp" or d.Name == "StairStep" or d.Name == "StairRiser" then
		d:Destroy()
	end
end
local GROUND = 0 -- 계단 밑은 부지 바닥(36×36) 밖이라 골목 바닥 높이
local RISE_RUN = 0.9
local cx, w = (X0 + X1) / 2, math.abs(X1 - X0) - 0.2
local prevTop = GROUND
for i, t in ipairs(TREADS) do
	local z0, z1, top = lz(t[1]), lz(t[2]), ly(t[3])
	-- 판: 바닥부터 윗면까지 꽉 찬 상자 (밑으로 빠지거나 걸리지 않게)
	local p = Instance.new("Part")
	p.Name = "StairStep"
	p.Anchored = true
	p.Transparency = 1
	p.CanQuery = false
	p.Size = Vector3.new(w, top - GROUND, z1 - z0)
	p.CFrame = plotCF * CFrame.new(cx, GROUND + (top - GROUND) / 2, (z0 + z1) / 2)
	p:SetAttribute("Role", "2층 계단 디딤판 " .. i .. " (안 보임)")
	p.Parent = shell
	-- 턱 비탈: 앞 판(또는 땅) 끝 RISE_RUN 구간, 높이 prevTop → top (Wedge 높은 쪽 = +Z)
	local r = Instance.new("WedgePart")
	r.Name = "StairRiser"
	r.Anchored = true
	r.Transparency = 1
	r.CanQuery = false
	r.Size = Vector3.new(w, top - prevTop, RISE_RUN)
	r.CFrame = plotCF * CFrame.new(cx, prevTop + (top - prevTop) / 2, z0 - RISE_RUN / 2)
	r.Parent = shell
	prevTop = top
end
return "steps " .. #TREADS
