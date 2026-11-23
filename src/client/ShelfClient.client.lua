-- 진열하기: 가구를 눌러서 (2026-11-24 사용자 "진열대 3종에서 버튼 없애기", 판매 세션)
--  - 유리 진열장을 누르면 누른 곳에 가까운 빈 칸, 벽 걸이판을 누르면 누른 자리에 걸고, 작은 탁자를 누르면 그 탁자 위
--  - 내 가게이고, 들고 있는 달고나(속성 Carrying)나 보관함에 안 놓은 것(속성 Unshelved)이 있을 때만
--  - 놓을 수 있는 동안 그 가구들에 은은한 테두리(Highlight)를 내 화면에만 보여 줌
--  - 서버: Remotes.ShelfPlace:InvokeServer(area, 세계 좌표) → SalesService가 칸을 고르고 Economy.place
--  - 가구는 가게 3D 부품 속성 Role로 찾음 (SalesService.AREA_ROLES와 같은 이름)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ROLE_AREA = {
	["유리 진열장"] = "case",
	["진열장 받침 (금속)"] = "case",
	["진열 이름표 띠"] = "case",
	["달고나 걸이판"] = "peg",
	["작은 탁자"] = "table1",
	["작은 탁자 2"] = "table2",
}
local MAX_DISTANCE = 40 -- 너무 멀리서는 안 됨 (가게 안이나 앞에서)

local function canPlace()
	return (player:GetAttribute("Carrying") or 0) ~= 0 or (player:GetAttribute("Unshelved") or 0) > 0
end

local function myPlot()
	local idx = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("ShopPlots")
	local plot = idx and plots and plots:FindFirstChild("Plot" .. idx)
	if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
		return plot
	end
	return nil
end

-- 내 가게의 진열 가구 부품 목록
local function furniture(plot)
	local list = {}
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("BasePart") and ROLE_AREA[d:GetAttribute("Role") or ""] then
			table.insert(list, d)
		end
	end
	return list
end

local function making()
	local ms = playerGui:FindFirstChild("MakingScreen")
	return ms and ms.Enabled
end

-- 놓을 수 있을 때 가구 테두리
local glows = {}
local function setGlow(on)
	local plot = on and myPlot() or nil
	local want = {}
	if plot then
		for _, p in ipairs(furniture(plot)) do
			local role = p:GetAttribute("Role")
			if role ~= "진열장 받침 (금속)" and role ~= "진열 이름표 띠" then
				want[p] = true
			end
		end
	end
	for p, h in pairs(glows) do
		if not want[p] then
			h:Destroy()
			glows[p] = nil
		end
	end
	for p in pairs(want) do
		if not glows[p] then
			local h = Instance.new("Highlight")
			h.Name = "ShelfGlow"
			h.Adornee = p
			h.FillTransparency = 0.85
			h.FillColor = Color3.fromRGB(255, 226, 120)
			h.OutlineColor = Color3.fromRGB(255, 206, 60)
			h.OutlineTransparency = 0.2
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = workspace.CurrentCamera -- 내 화면에만
			glows[p] = h
		end
	end
end

local function refresh()
	setGlow(canPlace() and not making())
end

local busy = false
local function tryPlace(screenPos)
	if busy or not canPlace() or making() then
		return
	end
	local plot = myPlot()
	if not plot then
		return
	end
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = furniture(plot)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not hit then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - hit.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local area = ROLE_AREA[hit.Instance:GetAttribute("Role") or ""]
	if not area then
		return
	end
	busy = true
	task.spawn(function()
		pcall(function()
			Remotes:WaitForChild("ShelfPlace"):InvokeServer(area, hit.Position)
		end)
		busy = false
	end)
end

-- 마우스: 누른 자리에서 거의 안 움직이고 뗐을 때 (카메라 돌리기와 구분)
local downAt = nil
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		downAt = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and downAt then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local moved = (p - downAt).Magnitude
		downAt = nil
		if not processed and moved < 8 then
			tryPlace(p)
		end
	end
end)
-- 터치: 화면을 톡 친 자리
UserInputService.TouchTapInWorld:Connect(function(pos, processedByUI)
	if not processedByUI then
		tryPlace(pos)
	end
end)

player:GetAttributeChangedSignal("Carrying"):Connect(refresh)
player:GetAttributeChangedSignal("Unshelved"):Connect(refresh)
player:GetAttributeChangedSignal("PlotIndex"):Connect(refresh)
task.spawn(function()
	while true do
		task.wait(1)
		pcall(refresh) -- 제작 화면 열고 닫기·가게 주인 바뀜 등
	end
end)
refresh()
