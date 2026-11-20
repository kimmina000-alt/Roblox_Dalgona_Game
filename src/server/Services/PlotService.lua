-- 가게 부지 6칸 (Phase 2, 2026-11-20)
-- 들어오면 빈 부지 하나를 배정하고, 나가면 돌려받는다. 부지마다:
--  - 이름 간판 (앞, 골목 쪽)
--  - 손 작업대 자리 (D10: 끝까지 남음)
--  - 기계 1자리 (D10: 설비 2~4단계를 여기서 교체)
--  - 가게 뒤 공장 문 자리 (D11: 지금은 문만, 누르면 "준비 중")
-- 지금 실제 작업대는 스폰 앞 하나(DalgonaWorkstation)뿐이라, 부지의 작업대 자리는 표시만 한다.
-- 수치·위치는 GrowthConfig.Plots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local P = G.Plots

local PlotService = {}

local plots = {} -- [i] = { model, owner, cframe, signLabel }
local byPlayer = {} -- [player] = i
local notify = nil -- function(player, text)

local WOOD = Color3.fromRGB(176, 124, 80)
local DARK_WOOD = Color3.fromRGB(110, 72, 44)
local FLOOR = Color3.fromRGB(226, 208, 176)
local EMPTY_TEXT = "빈 가게"

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function spotLabel(parent, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.5
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(90, 60, 40)
	t.TextTransparency = 0.25
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = t
	t.Parent = gui
	gui.Parent = parent
end

-- 바닥에 그린 자리 표시 (밟고 지나갈 수 있음)
local function spot(m, name, cf, size, color, text)
	-- Top 면 글씨는 부품의 Z축을 따라 써진다: 90° 돌리고 X·Z 크기를 바꿔서 골목(앞) 쪽에서 가로로 읽히게
	local p = part(m, name, Vector3.new(size.Z, size.Y, size.X), cf * CFrame.new(0, size.Y / 2 + P.size.Y, 0) * CFrame.Angles(0, math.pi * 0.5, 0), color, Enum.Material.SmoothPlastic, {
		CanCollide = false,
		Transparency = 0.35,
	})
	spotLabel(p, text)
	return p
end

local function buildPlot(index, parent)
	local x = (index - (P.count + 1) / 2) * P.spacing
	local cf = CFrame.new(x, 0, P.rowZ) * CFrame.Angles(0, math.pi, 0) -- 로컬 -Z(앞) = 월드 +Z (스폰 쪽)
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m:SetAttribute("PlotIndex", index)
	m:SetAttribute("OwnerUserId", 0)

	local floor = part(m, "Floor", P.size, cf * CFrame.new(0, P.size.Y / 2, 0), FLOOR, Enum.Material.WoodPlanks)
	m.PrimaryPart = floor
	-- 낮은 울타리 (앞은 입구로 비움)
	local half = P.size.X / 2
	for _, side in ipairs({ -1, 1 }) do
		part(m, "Fence", Vector3.new(0.4, 1.6, P.size.Z), cf * CFrame.new(side * (half - 0.2), P.size.Y + 0.8, 0), DARK_WOOD, Enum.Material.Wood)
	end
	part(m, "Fence", Vector3.new(P.size.X, 1.6, 0.4), cf * CFrame.new(0, P.size.Y + 0.8, half - 0.2), DARK_WOOD, Enum.Material.Wood)

	-- 손 작업대 자리 (D10)
	local hs = spot(m, "HandStationSpot", cf * CFrame.new(P.handStation.pos), P.handStation.size, Color3.fromRGB(255, 214, 150), "손 작업대 자리")
	hs:SetAttribute("Spot", "HandStation")
	-- 기계 1자리 (D10)
	local ms = spot(m, "MachineSlot", cf * CFrame.new(P.machineSlot.pos), P.machineSlot.size, Color3.fromRGB(170, 210, 255), "기계 자리")
	ms:SetAttribute("Spot", "Machine")
	ms:SetAttribute("Stage", 1)

	-- 가게 뒤 공장 문 (D11, 자리만): 문틀 + 닫힌 문 + "준비 중" 안내
	local dcf = cf * CFrame.new(P.factoryDoor.pos)
	local door = Instance.new("Model")
	door.Name = "FactoryDoor"
	door.Parent = m
	part(door, "Frame", Vector3.new(0.6, 9, 0.8), dcf * CFrame.new(-3.3, P.size.Y + 4.5, 0), DARK_WOOD, Enum.Material.Wood)
	part(door, "Frame", Vector3.new(0.6, 9, 0.8), dcf * CFrame.new(3.3, P.size.Y + 4.5, 0), DARK_WOOD, Enum.Material.Wood)
	part(door, "Frame", Vector3.new(7.2, 0.6, 0.8), dcf * CFrame.new(0, P.size.Y + 9.3, 0), DARK_WOOD, Enum.Material.Wood)
	local panel = part(door, "Door", Vector3.new(6, 8.6, 0.3), dcf * CFrame.new(0, P.size.Y + 4.3, 0), Color3.fromRGB(150, 160, 170), Enum.Material.DiamondPlate)
	panel:SetAttribute("Spot", "FactoryDoor")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FactoryPrompt"
	prompt.ActionText = "공장 들어가기"
	prompt.ObjectText = "공장 (준비 중)"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	prompt.Triggered:Connect(function(player)
		if notify then
			notify(player, "공장은 나중에 열려요 (Lv5 공장 단계)")
		end
	end)

	-- 이름 간판 (앞, 골목 쪽을 봄)
	local scf = cf * CFrame.new(P.sign.pos)
	for _, sx in ipairs({ -7, 7 }) do
		part(m, "SignPost", Vector3.new(0.5, P.sign.height, 0.5), scf * CFrame.new(sx, P.size.Y + P.sign.height / 2, 0), DARK_WOOD, Enum.Material.Wood)
	end
	local board = part(m, "Sign", Vector3.new(15, 3, 0.4), scf * CFrame.new(0, P.size.Y + P.sign.height - 1.2, 0), WOOD, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- 로컬 -Z 면 = 골목 쪽
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 246, 225)
	label.TextStrokeTransparency = 0.4
	label.Text = EMPTY_TEXT
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = board

	-- 들어오는 자리 (스폰을 부지로 옮길 때 씀)
	part(m, "Entry", Vector3.new(4, 0.2, 4), cf * CFrame.new(0, P.size.Y + 0.1, -12), FLOOR, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
	})

	m.Parent = parent
	return { model = m, owner = nil, cframe = cf, signLabel = label }
end

local function setOwner(i, player)
	local plot = plots[i]
	plot.owner = player
	plot.model:SetAttribute("OwnerUserId", player and player.UserId or 0)
	plot.model:SetAttribute("OwnerName", player and player.DisplayName or "")
	plot.signLabel.Text = player and (player.DisplayName .. "의 달고나 가게") or EMPTY_TEXT
end

local function teleport(player, i)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local entry = plots[i] and plots[i].model:FindFirstChild("Entry")
	if root and entry then
		char:PivotTo(CFrame.lookAt(entry.Position + Vector3.new(0, 3, 0), entry.Position + Vector3.new(0, 3, 0) + (entry.Position - plots[i].model.Floor.Position).Unit * -1))
	end
end

-- 빈 부지 배정 (이미 있으면 그 번호). 꽉 차면 nil
function PlotService.assign(player)
	if byPlayer[player] then
		return byPlayer[player]
	end
	for i, plot in ipairs(plots) do
		if not plot.owner then
			byPlayer[player] = i
			setOwner(i, player)
			if typeof(player) == "Instance" then
				player:SetAttribute("PlotIndex", i)
			end
			print(string.format("[Plot] %s -> Plot%d", player.Name, i))
			return i
		end
	end
	warn("[Plot] no free plot for", player.Name)
	return nil
end

function PlotService.release(player)
	local i = byPlayer[player]
	if not i then
		return
	end
	byPlayer[player] = nil
	setOwner(i, nil)
	print(string.format("[Plot] %s released Plot%d", player.Name, i))
end

function PlotService.get(player)
	local i = byPlayer[player]
	return i and plots[i] or nil, i
end

function PlotService.init(opts)
	notify = opts and opts.notify
	local folder = workspace:FindFirstChild("ShopPlots")
	if folder then
		folder:Destroy() -- 서버가 새로 만든다 (Studio에 남은 것 정리)
	end
	folder = Instance.new("Folder")
	folder.Name = "ShopPlots"
	folder.Parent = workspace
	for i = 1, P.count do
		plots[i] = buildPlot(i, folder)
	end

	local function onAdded(player)
		local i = PlotService.assign(player)
		if i and P.teleportOnSpawn then
			player.CharacterAdded:Connect(function()
				task.wait(0.2)
				teleport(player, i)
			end)
			if player.Character then
				teleport(player, i)
			end
		end
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		onAdded(p)
	end
	Players.PlayerRemoving:Connect(PlotService.release)
end

return PlotService
