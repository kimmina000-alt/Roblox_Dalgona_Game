-- Lv5 달고나 공장 (docs/MACHINE_ERAS.md "Lv5 달고나 공장").
-- 원본: ServerStorage.Assets.Factory (tools/blender/factory.py → dalgona_factory.glb 를 Studio로 가져온 것, 부품 45개).
-- glb 금속도·거칠기·투명도는 Roblox로 안 넘어와서 여기서 부품마다 재질·색을 칠한다 (factory_parts.txt 와 같은 값).
-- 가져온 방향: Blender (x, y, z) → 모델 기준 (-x, z, y). 앞(제어대 쪽) = 모델 -Z.
local ServerStorage = game:GetService("ServerStorage")

local FactoryBuilder = {}

-- 재질키 → { Roblox 재질, 색, 투명도 } (파스텔 사탕 공장, 2026-11-19. factory_parts.txt 에서 자동으로 옮김)
local KINDS = {
	BeaconG = { Enum.Material.Neon, Color3.fromRGB(120, 230, 170) },
	BeaconR = { Enum.Material.Neon, Color3.fromRGB(255, 120, 160) },
	BeaconY = { Enum.Material.Neon, Color3.fromRGB(255, 220, 110) },
	Belt = { Enum.Material.Rubber, Color3.fromRGB(62, 70, 110) },
	Bush = { Enum.Material.SmoothPlastic, Color3.fromRGB(150, 220, 150) },
	Concrete = { Enum.Material.SmoothPlastic, Color3.fromRGB(252, 238, 190) },
	Copper = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 200, 120) },
	Crate = { Enum.Material.Wood, Color3.fromRGB(214, 160, 110) },
	Curtain = { Enum.Material.Glass, Color3.fromRGB(220, 210, 255), 0.55 },
	Dalgona = { Enum.Material.SmoothPlastic, Color3.fromRGB(232, 166, 80) },
	Frame = { Enum.Material.SmoothPlastic, Color3.fromRGB(150, 205, 240) },
	Glass = { Enum.Material.Glass, Color3.fromRGB(225, 240, 255), 0.6 },
	Grass = { Enum.Material.Grass, Color3.fromRGB(170, 225, 140) },
	Green = { Enum.Material.SmoothPlastic, Color3.fromRGB(120, 220, 160) },
	Hazard = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 150, 190) },
	LampOn = { Enum.Material.Neon, Color3.fromRGB(255, 244, 210) },
	Lemon = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 235, 140) },
	Lilac = { Enum.Material.SmoothPlastic, Color3.fromRGB(210, 180, 250) },
	Mint = { Enum.Material.SmoothPlastic, Color3.fromRGB(165, 232, 200) },
	Panel = { Enum.Material.SmoothPlastic, Color3.fromRGB(96, 84, 140) },
	Pink = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 182, 210) },
	Red = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 140, 170) },
	Sky = { Enum.Material.SmoothPlastic, Color3.fromRGB(160, 210, 250) },
	Steel = { Enum.Material.SmoothPlastic, Color3.fromRGB(236, 234, 246) },
	SteelDark = { Enum.Material.SmoothPlastic, Color3.fromRGB(196, 198, 240) },
	Sugar = { Enum.Material.Sand, Color3.fromRGB(255, 252, 250) },
	Wall = { Enum.Material.SmoothPlastic, Color3.fromRGB(196, 236, 218) },
	White = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 255, 255) },
	Window = { Enum.Material.Glass, Color3.fromRGB(190, 225, 245), 0.15 },
	Yellow = { Enum.Material.SmoothPlastic, Color3.fromRGB(255, 228, 120) },
}

local PART_KIND = {
	Factory_Floor = "Concrete", Factory_FloorLines = "Yellow", Factory_Walls = "Wall", Factory_Windows = "Window",
	Factory_Beams = "Frame", Factory_Lamps = "SteelDark", Factory_LampLight = "LampOn", Factory_Railing = "White",
	Line_HopperFrame = "Frame", Line_Ladder = "Yellow", Line_Deck = "Hazard", Line_Hoppers = "Glass",
	Line_HopperSugar = "Sugar", Line_FeedPipes = "Steel", Line_Kettles = "Steel", Line_KettleJacket = "Red",
	Line_KettleGauge = "White", Line_KettleValves = "Red", Line_Belt = "Belt", Line_ConveyorFrame = "SteelDark",
	Line_Trays = "Steel", Line_Dalgona = "Dalgona", Line_DepositorFrame = "Frame", Line_Depositor = "Steel",
	Line_PressColumns = "Hazard", Line_PressBody = "Frame", Line_PressCylinders = "Steel", Line_PressHead = "SteelDark",
	Line_PressStamps = "Copper", Line_PressBeacons = "BeaconY", Line_Tunnel = "Steel", Line_TunnelFans = "SteelDark",
	Line_Curtains = "Curtain", Line_Chute = "Steel", Line_Crates = "Crate", Line_CrateDalgona = "Dalgona",
	Line_ConsoleBody = "SteelDark", Line_ConsolePanel = "Panel", Line_ConsoleRim = "Steel", Line_StartButton = "Green",
	Line_StopButton = "Red", Line_TowerPole = "SteelDark", Line_TowerG = "BeaconG", Line_TowerY = "BeaconY",
	Line_TowerR = "BeaconR", Deco_HopperBalls = "Pink", Deco_KettleBalls = "Lemon", Deco_PressBall = "Mint",
	Deco_Lolli1_Stick = "White", Deco_Lolli1_Candy = "Pink", Deco_Lolli1_Swirl = "White", Deco_Lolli2_Stick = "White",
	Deco_Lolli2_Candy = "Sky", Deco_Lolli2_Swirl = "White", Deco_Lolli3_Stick = "White", Deco_Lolli3_Candy = "Lemon",
	Deco_Lolli3_Swirl = "White", Deco_Lawn = "Grass", Deco_Bushes = "Bush", Deco_FlowerBushes = "Lilac",
	Deco_SwirlL_Pink = "Pink", Deco_SwirlL_Lemon = "Lemon", Deco_SwirlL_Mint = "Mint", Deco_SwirlL_Sky = "Sky",
	Deco_SwirlL_Lilac = "Lilac", Deco_SwirlL_Top = "White", Deco_SwirlR_Pink = "Pink", Deco_SwirlR_Lemon = "Lemon",
	Deco_SwirlR_Mint = "Mint", Deco_SwirlR_Sky = "Sky", Deco_SwirlR_Lilac = "Lilac", Deco_SwirlR_Top = "White",
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
