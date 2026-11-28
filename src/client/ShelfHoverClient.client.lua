-- 골목 슈퍼·문방구 선반 물건 이름표 (2026-11-28, 서버 ShelfShopService)
--   마우스를 물건에 올리면 그 위에 "설탕 10개 · 30코인" 같은 이름표 (부품 속성 ShelfLabel). 폰은 올리기가 없어서 누르면 서버 알림으로 보임
--   품절(속성 InStock = false)이면 이름표를 안 띄움

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local tag = Instance.new("BillboardGui")
tag.Name = "ShelfTag"
tag.Size = UDim2.fromOffset(190, 34)
tag.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
tag.AlwaysOnTop = true
tag.LightInfluence = 0
tag.Enabled = false
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
label.BackgroundTransparency = 0.05
label.TextColor3 = Color3.fromRGB(110, 70, 40)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Parent = tag
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 4)
pad.Parent = label
tag.Parent = player:WaitForChild("PlayerGui")

local current = nil
local function hook(cd)
	if not cd:IsA("ClickDetector") then
		return
	end
	local p = cd.Parent
	if not (p and p:IsA("BasePart") and p:GetAttribute("ItemId")) then
		return
	end
	cd.MouseHoverEnter:Connect(function(who)
		if who ~= player or p:GetAttribute("InStock") == false then
			return
		end
		current = p
		label.Text = p:GetAttribute("ShelfLabel") or ""
		tag.Adornee = p
		tag.Enabled = label.Text ~= ""
	end)
	cd.MouseHoverLeave:Connect(function(who)
		if who == player and current == p then
			current = nil
			tag.Enabled = false
		end
	end)
	p:GetAttributeChangedSignal("InStock"):Connect(function()
		if current == p and p:GetAttribute("InStock") == false then
			tag.Enabled = false
		end
	end)
end

local alley = workspace:WaitForChild("Alley", 60)
if alley then
	for _, d in ipairs(alley:GetDescendants()) do
		hook(d)
	end
	alley.DescendantAdded:Connect(hook)
end
