-- 만화 같은 외곽선 (사용자 요청 2026-11-19 "3D 더 귀엽고 입체적이고"):
-- 작업대 도구마다 Highlight(외곽선만)를 붙여 둥글둥글한 그림책 느낌으로. 채움 없음, 가려진 부분은 안 그림.
-- 국자를 숨길 때(붓기)는 Pour가 외곽선도 끈다 (이름 "ToonOutline").

local Toon = {}

local OUTLINE = Color3.fromRGB(92, 52, 34) -- 짙은 초콜릿색 (검정보다 부드러움)
local TOOLS = { "Ladle", "Presser", "Cutter", "SodaTub", "ChopstickCup","WoodSpoon", "SugarBowlWhite", "SugarBowlBrown", "Brazier", "IronPlate" }

function Toon.apply(model)
	for _, name in ipairs(TOOLS) do
		local inst = model:FindFirstChild(name)
		if inst and not inst:FindFirstChild("ToonOutline") then
			local h = Instance.new("Highlight")
			h.Name = "ToonOutline"
			h.FillTransparency = 1
			h.OutlineColor = OUTLINE
			h.OutlineTransparency = 0.15
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = inst
			h.Parent = inst
		end
	end
end

-- 도구 하나에 외곽선 (반죽처럼 나중에 생기는 것, 2026-11-20 "얘는 왜 외곽선 없어")
function Toon.outline(inst)
	if inst:FindFirstChild("ToonOutline") then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "ToonOutline"
	h.FillTransparency = 1
	h.OutlineColor = OUTLINE
	h.OutlineTransparency = 0.15
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = inst
	h.Parent = inst
end

return Toon
