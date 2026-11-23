-- 가게 안 약한 조명 (2026-11-24 사용자 "따뜻한 색감의 약한 조명", 판매 세션)
-- 예전 천장 등(전구 Neon + 밝기 1.3)은 너무 밝아서 화면이 안 보였음 → 전구 모양 없이 안 보이는 점에 약한 PointLight만.
-- 세기는 GrowthConfig.ShopLight.strength 하나로 (0 = 끔). 밝기 = strength × 1.3 (1이면 예전 밝기쯤)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local ShopLights = {}

-- plot = { model, cframe } (PlotService 부지)
function ShopLights.build(plot)
	local L = G.ShopLight
	if not plot or not plot.model then
		return
	end
	local old = plot.model:FindFirstChild("ShopLights")
	if old then
		old:Destroy()
	end
	if not L or (L.strength or 0) <= 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "ShopLights"
	for i, s in ipairs(L.spots) do
		local p = Instance.new("Part")
		p.Name = "Glow" .. i
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = plot.cframe * CFrame.new(s[1], L.y, s[2])
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = L.color
		light.Range = L.range
		light.Brightness = L.strength * 1.3
		light.Shadows = false
		light.Parent = p
		p.Parent = folder
	end
	folder.Parent = plot.model
end

return ShopLights
