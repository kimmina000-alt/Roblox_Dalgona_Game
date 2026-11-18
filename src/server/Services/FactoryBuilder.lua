-- Lv5 달고나 공장 (docs/MACHINE_ERAS.md "Lv5 달고나 공장").
-- 원본: ServerStorage.Assets.Factory (tools/blender/factory.py → dalgona_factory.glb 를 Studio로 가져온 것, 부품 45개).
-- glb 금속도·거칠기·투명도는 Roblox로 안 넘어와서 여기서 부품마다 재질·색을 칠한다 (factory_parts.txt 와 같은 값).
-- 가져온 방향: Blender (x, y, z) → 모델 기준 (-x, z, y). 앞(제어대 쪽) = 모델 -Z.
local ServerStorage = game:GetService("ServerStorage")

local FactoryBuilder = {}

-- 재질키 → { Roblox 재질, 색, 투명도 }
local KINDS = {
	Concrete = { Enum.Material.Concrete, Color3.fromRGB(150, 148, 142) },
	Yellow = { Enum.Material.SmoothPlastic, Color3.fromRGB(250, 200, 30) },
	Wall = { Enum.Material.SmoothPlastic, Color3.fromRGB(226, 220, 202) },
	Window = { Enum.Material.Glass, Color3.fromRGB(170, 205, 225), 0.15 },
	Frame = { Enum.Material.Metal, Color3.fromRGB(60, 92, 140) },
	SteelDark = { Enum.Material.Metal, Color3.fromRGB(110, 114, 120) },
	Steel = { Enum.Material.Metal, Color3.fromRGB(200, 203, 208) },
	LampOn = { Enum.Material.Neon, Color3.fromRGB(255, 236, 190) },
	Hazard = { Enum.Material.SmoothPlastic, Color3.fromRGB(250, 200, 30) },
	Glass = { Enum.Material.Glass, Color3.fromRGB(215, 235, 242), 0.6 },
	Sugar = { Enum.Material.Sand, Color3.fromRGB(250, 250, 248) },
	Red = { Enum.Material.Metal, Color3.fromRGB(190, 40, 40) },
	White = { Enum.Material.SmoothPlastic, Color3.fromRGB(240, 238, 232) },
	Belt = { Enum.Material.Rubber, Color3.fromRGB(46, 46, 50) },
	Dalgona = { Enum.Material.SmoothPlastic, Color3.fromRGB(214, 150, 70) },
	Copper = { Enum.Material.Metal, Color3.fromRGB(196, 116, 58) },
	BeaconY = { Enum.Material.Neon, Color3.fromRGB(255, 190, 30) },
	BeaconG = { Enum.Material.Neon, Color3.fromRGB(60, 220, 90) },
	BeaconR = { Enum.Material.Neon, Color3.fromRGB(255, 60, 40) },
	Curtain = { Enum.Material.Glass, Color3.fromRGB(200, 220, 230), 0.55 },
	Crate = { Enum.Material.SmoothPlastic, Color3.fromRGB(60, 120, 200) },
	Panel = { Enum.Material.SmoothPlastic, Color3.fromRGB(58, 64, 72) },
	Green = { Enum.Material.SmoothPlastic, Color3.fromRGB(50, 180, 80) },
}

local PART_KIND = {
	Factory_Floor = "Concrete", Factory_FloorLines = "Yellow", Factory_Walls = "Wall", Factory_Windows = "Window",
	Factory_Beams = "Frame", Factory_Lamps = "SteelDark", Factory_LampLight = "LampOn", Factory_Railing = "Yellow",
	Line_HopperFrame = "Frame", Line_Ladder = "Yellow", Line_Deck = "Hazard", Line_Hoppers = "Glass",
	Line_HopperSugar = "Sugar", Line_FeedPipes = "Steel", Line_Kettles = "Steel", Line_KettleJacket = "Red",
	Line_KettleGauge = "White", Line_KettleValves = "Red", Line_Belt = "Belt", Line_ConveyorFrame = "SteelDark",
	Line_Trays = "Steel", Line_Dalgona = "Dalgona", Line_DepositorFrame = "Frame", Line_Depositor = "Steel",
	Line_PressColumns = "Hazard", Line_PressBody = "Frame", Line_PressCylinders = "Steel", Line_PressHead = "SteelDark",
	Line_PressStamps = "Copper", Line_PressBeacons = "BeaconY", Line_Tunnel = "Steel", Line_TunnelFans = "SteelDark",
	Line_Curtains = "Curtain", Line_Chute = "Steel", Line_Crates = "Crate", Line_CrateDalgona = "Dalgona",
	Line_ConsoleBody = "SteelDark", Line_ConsolePanel = "Panel", Line_ConsoleRim = "Steel", Line_StartButton = "Green",
	Line_StopButton = "Red", Line_TowerPole = "SteelDark", Line_TowerG = "BeaconG", Line_TowerY = "BeaconY", Line_TowerR = "BeaconR",
}

-- 사람이 지나가야 하는 얇은 것·빛은 부딪히지 않게
local NO_COLLIDE = { Line_Curtains = true, Factory_LampLight = true, Factory_Lamps = true, Line_Dalgona = true, Line_CrateDalgona = true }

-- 매달린 조명 6개 (Blender x ∈ {-14,0,14}, y ∈ {-3,6}, 높이 11.45) → 모델 기준 (-x, 11.45, y)
local LAMPS = {}
for _, x in ipairs({ -14, 0, 14 }) do
	for _, y in ipairs({ -3, 6 }) do
		table.insert(LAMPS, Vector3.new(-x, 11.45, y))
	end
end

local function style(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			local kind = KINDS[PART_KIND[p.Name] or ""]
			if kind then
				p.Material = kind[1]
				-- 텍스처가 있으면 색은 흰색(텍스처 그대로), 없으면 재질 색
				p.Color = (p:IsA("MeshPart") and p.TextureID ~= "") and Color3.new(1, 1, 1) or kind[2]
				p.Transparency = kind[3] or 0
			end
			if NO_COLLIDE[p.Name] then
				p.CanCollide = false
			end
		end
	end
	local light = model:FindFirstChild("Factory_LampLight", true)
	if light then
		local pivot = model:GetPivot()
		for i, pos in ipairs(LAMPS) do
			local a = Instance.new("Attachment")
			a.Name = "Lamp" .. i
			a.Parent = light
			a.WorldCFrame = pivot * CFrame.new(pos - Vector3.new(0, 0.2, 0))
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Bottom
			l.Angle = 110
			l.Range = 22
			l.Brightness = 2.5
			l.Color = Color3.fromRGB(255, 236, 200)
			l.Shadows = true
			l.Parent = a
		end
	end
end
FactoryBuilder.style = style

-- 공장을 월드에 놓는다. cf = 바닥 가운데 (앞 = cf 의 -Z). 이미 있으면 그대로 돌려줌.
function FactoryBuilder.place(parent, cf)
	local existing = parent:FindFirstChild("DalgonaFactory")
	if existing then
		return existing
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Factory")
	if not src then
		warn("[Factory] ServerStorage.Assets.Factory 없음")
		return nil
	end
	local m = src:Clone()
	m.Name = "DalgonaFactory"
	m:PivotTo(cf)
	style(m)
	m.Parent = parent
	return m
end

return FactoryBuilder
