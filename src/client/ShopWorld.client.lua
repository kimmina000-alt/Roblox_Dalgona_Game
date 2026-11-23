-- 골목·가게 둘레 (2026-11-24 사용자, 판매 세션). 값은 GrowthConfig.ShopWorld
--  1) 카메라: 멀리서 마을 전체를 내려다보지 못하게 최대 줌 거리·높이를 막음 (제작 화면처럼 카메라를 직접 잡을 때는 안 건드림)
--  2) 가게 출입: 내 가게, 그리고 남의 가게 중 열린 곳(ShopState owned, 또는 rented이고 월세 밀림 아님)만 들어감.
--     가게 앞선 안쪽에 안 보이는 막이를 내 화면에만 만들고 CanCollide를 맞춤 (내 캐릭터 물리는 내 화면이 계산).
--     이미 안에 있을 때 막히면 나올 때까지 열어 둠
--  3) 공장 공정 기계 앞 "내가 하기"(서버 FactoryDisplay SelfPrompt): 내 공장만, 알바생이 있는 공정은 숨김, 지금 하는 공정이면 "그만하기"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local W = G.ShopWorld or {}
local player = Players.LocalPlayer

---------------------------------------------------------------- 1) 카메라

player.CameraMaxZoomDistance = math.min(player.CameraMaxZoomDistance, W.cameraMaxZoom or 34)

-- 기본 카메라가 자리를 정한 뒤(Camera 우선순위 다음)에 높이만 낮춤: 캐릭터 쪽으로 당겨서 머리 위 cameraMaxHeight를 넘지 않게
RunService:BindToRenderStep("ShopWorldCameraCap", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local maxH = W.cameraMaxHeight or 20
	local focus = cam.Focus.Position
	local pos = cam.CFrame.Position
	local top = head.Position.Y + maxH
	if pos.Y <= top or pos.Y - focus.Y < 1e-3 then
		return
	end
	-- 초점 → 카메라 선 위에서 높이가 top이 되는 점으로
	local f = math.clamp((top - focus.Y) / (pos.Y - focus.Y), 0, 1)
	local newPos = focus:Lerp(pos, f)
	cam.CFrame = CFrame.lookAt(newPos, focus)
end)

---------------------------------------------------------------- 2) 가게 출입

local GT = W.gate or { z = -17.6, halfWidth = 21.2, depth = 60, height = 14 }
local gates = {} -- [plot] = 막이 Part

local function gateFor(plot)
	local g = gates[plot]
	if g and g.Parent then
		return g
	end
	local cf = plot:GetAttribute("PlotCFrame")
	if typeof(cf) ~= "CFrame" then
		return nil
	end
	g = Instance.new("Part")
	g.Name = "ShopGate_" .. plot.Name
	g.Size = Vector3.new(GT.halfWidth * 2, GT.height, 1)
	g.CFrame = cf * CFrame.new(0, GT.height / 2, GT.z + 0.5)
	g.Transparency = 1
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.CastShadow = false
	g.Parent = workspace -- 내 화면에만 있는 부품
	gates[plot] = g
	return g
end

local function allowed(plot)
	if plot:GetAttribute("OwnerUserId") == player.UserId then
		return true
	end
	local state = plot:GetAttribute("ShopState")
	if state == "owned" then
		return true
	end
	return state == "rented" and plot:GetAttribute("ShopClosed") ~= true
end

-- 내가 그 가게 안(막이 안쪽)에 있나
local function inside(plot)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cf = plot:GetAttribute("PlotCFrame")
	if not (root and typeof(cf) == "CFrame") then
		return false
	end
	local p = cf:PointToObjectSpace(root.Position)
	return math.abs(p.X) < GT.halfWidth + 1 and p.Z > GT.z - 0.5 and p.Z < GT.z + GT.depth + 30
end

local function syncGates()
	local plots = workspace:FindFirstChild("ShopPlots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local g = gateFor(plot)
		if g then
			local block = not allowed(plot)
			if block and inside(plot) then
				block = false -- 안에 있을 때 닫혔으면 나올 수 있게
			end
			g.CanCollide = block
		end
	end
	for plot, g in pairs(gates) do
		if not plot.Parent then
			g:Destroy()
			gates[plot] = nil
		end
	end
end

---------------------------------------------------------------- 3) 공장 기계 앞 "내가 하기"

local function syncSelfPrompts()
	local plots = workspace:FindFirstChild("ShopPlots")
	local facs = workspace:FindFirstChild("Factories")
	if not plots then
		return
	end
	local selfKey = player:GetAttribute("FactorySelf")
	for _, plot in ipairs(plots:GetChildren()) do
		local lot = plot:FindFirstChild("FactoryLot")
		local b = lot and lot:FindFirstChild("Building")
		if b then
			local mine = plot:GetAttribute("OwnerUserId") == player.UserId
			local i = tonumber(plot.Name:match("%d+"))
			local fac = facs and i and facs:FindFirstChild("Factory" .. i)
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.Name == "SelfPrompt" then
					local key = d:GetAttribute("StationKey")
					local staffed = fac and fac:GetAttribute("Staff_" .. tostring(key)) == true
					d.Enabled = mine and not staffed
					d.ActionText = (selfKey == key) and "그만하기" or "내가 하기"
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		pcall(syncGates)
		pcall(syncSelfPrompts)
		task.wait(0.5)
	end
end)
