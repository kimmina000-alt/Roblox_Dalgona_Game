-- 만드는 동안 카메라와 작업대 사이를 가리는 가게 부품(천장·지붕·벽·간판 등)을 내 화면에서만 숨김
-- (2026-11-22 버그 "가게 안 작업대에서 제작 화면이 분홍 단색": 제작 카메라가 가게 천장 위·안에 걸림).
-- 층고·작업대 자리와 상관없이 동작하도록 레이캐스트로 찾음. 숨기는 건 이 가게 부지(Plot<n>) 안의 부품만:
-- 작업대 자체와 제작 도구(클라이언트가 만든 국자·반죽·도구 등)는 건드리지 않음. 끝나면 되돌림.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ViewClear = {}

local hidden = {} -- 부품 → 숨기기 전 LocalTransparencyModifier
local conn = nil
local model = nil
local acc = 0

local SCAN_EVERY = 0.15 -- 초. 카메라가 단계마다 옮겨 가서 계속 다시 봄

local function hide(p)
	if hidden[p] == nil then
		hidden[p] = p.LocalTransparencyModifier
		p.LocalTransparencyModifier = 1
	end
end

-- 이 부품을 숨겨도 되나: 같은 가게 부지 안이고 작업대 밖
local function hideable(p, plot)
	return p:IsA("BasePart") and plot ~= nil and p:IsDescendantOf(plot) and not p:IsDescendantOf(model)
end

-- 카메라가 봐야 하는 자리: 작업대 가운데·윗면·화로 + 네 귀퉁이 쪽
local function targets()
	local pts = {}
	local cf, size = model:GetBoundingBox()
	table.insert(pts, cf.Position)
	local top = model:FindFirstChild("TableTop")
	if top and top:IsA("BasePart") then
		table.insert(pts, top.Position + Vector3.new(0, top.Size.Y / 2, 0))
	end
	local br = model:FindFirstChild("Brazier")
	if br then
		table.insert(pts, br:GetPivot().Position)
	end
	for _, sx in ipairs({ -0.4, 0.4 }) do
		for _, sz in ipairs({ -0.4, 0.4 }) do
			table.insert(pts, (cf * CFrame.new(size.X * sx, 0, size.Z * sz)).Position)
		end
	end
	return pts
end

local function scan()
	local cam = workspace.CurrentCamera
	if not (cam and model and model.Parent) then
		return
	end
	local plot = model.Parent
	local origin = cam.CFrame.Position
	local ex = { model }
	local ch = Players.LocalPlayer.Character
	if ch then
		table.insert(ex, ch)
	end
	for p in pairs(hidden) do
		table.insert(ex, p)
	end
	-- 카메라가 부품 안에 들어가 있으면 레이캐스트가 못 잡음 → 카메라 둘레에 겹친 부품부터
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ex
	for _, p in ipairs(workspace:GetPartBoundsInRadius(origin, 1, op)) do
		if hideable(p, plot) then
			hide(p)
			table.insert(ex, p)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, t in ipairs(targets()) do
		for _ = 1, 10 do
			params.FilterDescendantsInstances = ex
			local r = workspace:Raycast(origin, t - origin, params)
			if not r then
				break
			end
			local p = r.Instance
			if hideable(p, plot) then
				hide(p)
			end
			-- 숨길 수 없는 것(다른 곳·제작 도구)도 지나서 그 뒤를 봄
			table.insert(ex, p)
		end
	end
end

function ViewClear.start(m)
	ViewClear.stop()
	model = m
	acc = SCAN_EVERY
	conn = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= SCAN_EVERY then
			acc = 0
			scan()
		end
	end)
end

function ViewClear.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for p, v in pairs(hidden) do
		if p.Parent then
			p.LocalTransparencyModifier = v
		end
	end
	table.clear(hidden)
	model = nil
end

return ViewClear
