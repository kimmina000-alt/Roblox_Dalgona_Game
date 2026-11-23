-- 가게 천장 조명 (2026-11-24 사용자 "가게 천장에 조명 설치 좀", 판매 세션)
-- 가게 부지마다 천장 아래 매다는 전등 (전선 + 갓 + 전구 Neon + PointLight). 자리·밝기는 GrowthConfig.ShopLights
-- 제작 화면 카메라를 가리면 ViewClear가 숨길 수 있게 CanQuery = true, 속성 ShopLamp = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local ShopLights = {}

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p:SetAttribute("ShopLamp", true)
	p.Parent = parent
	return p
end

-- plot = { model, cframe } (PlotService 부지)
function ShopLights.build(plot)
	local L = G.ShopLights
	if not L or not plot or not plot.model then
		return
	end
	local old = plot.model:FindFirstChild("ShopLights")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "ShopLights"
	for i, s in ipairs(L.spots) do
		local top = plot.cframe * CFrame.new(s[1], L.ceilingY, s[2])
		local lamp = Instance.new("Model")
		lamp.Name = "Lamp" .. i
		part(lamp, "Cord", Vector3.new(L.cord, 0.08, 0.08), top * CFrame.new(0, -L.cord / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 45, 35), nil, Enum.PartType.Cylinder)
		local shadeCF = top * CFrame.new(0, -L.cord - 0.35, 0)
		part(lamp, "Shade", Vector3.new(0.7, 1.6, 1.6), shadeCF * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(214, 150, 92), Enum.Material.Wood, Enum.PartType.Cylinder)
		local bulb = part(lamp, "Bulb", Vector3.new(0.7, 0.7, 0.7), shadeCF * CFrame.new(0, -0.45, 0), L.color, Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = L.color
		light.Range = L.range
		light.Brightness = L.brightness
		light.Shadows = false
		light.Parent = bulb
		lamp.Parent = folder
	end
	folder.Parent = plot.model
end

return ShopLights
