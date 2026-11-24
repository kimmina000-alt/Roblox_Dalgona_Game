-- 손 제작 "수제" 도장 (D58, 2026-11-26 확정: 손으로 만든 진열 달고나는 판매가 ×1.5)
--   진열된 달고나 위에 작은 빨간 동그라미 도장 "수제", 유리 진열장 앞 이름표 카드(Card1~4)에도 "수제 ×1.5".
--   내 화면에서만 그림 (모든 가게). 서버 SalesService가 진열 칸 부품 Slot<i>에 속성 Hand = true를 넣음
--   (진열 아이템 hand, 저장·부지 세션 feat/shop-1127 형식). 칸이 비면 Hand = nil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local C = UI.C
local new = UI.new

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local folder = new("Folder", { Name = "HandStamps", Parent = playerGui })
local MULT = G.HandMadeMult or 1.5

local stamps = {} -- [slot part] = BillboardGui
local cardStamps = {} -- [card label] = TextLabel

local function lookOf(shelf, i)
	local look = shelf:FindFirstChild("Look" .. i)
	if look then
		return look:IsA("Model") and (look.PrimaryPart or look:FindFirstChildWhichIsA("BasePart", true)) or (look:IsA("BasePart") and look) or nil
	end
	return nil
end

local function stampFor(adornee)
	local bb = new("BillboardGui", {
		Name = "HandStamp",
		Adornee = adornee,
		Size = UDim2.fromOffset(34, 34),
		StudsOffsetWorldSpace = Vector3.new(0.5, 0.9, 0),
		LightInfluence = 0,
		MaxDistance = 40,
		ResetOnSpawn = false,
		Parent = folder,
	})
	local t = UI.text({
		Text = "수제",
		TextSize = 11,
		TextColor3 = C.red,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = C.cream,
		Rotation = -14,
		Size = UDim2.fromScale(1, 1),
		Parent = bb,
	})
	UI.corner("round").Parent = t
	UI.stroke(C.red, 2).Parent = t
	return bb
end

local function cardStamp(card)
	local t = UI.text({
		Name = "HandStamp",
		Text = string.format("수제 ×%.1f", MULT),
		TextSize = 12,
		TextColor3 = C.white,
		BackgroundTransparency = 0,
		BackgroundColor3 = C.red,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.new(0.45, 0, 0.4, 0),
		TextScaled = true,
		ZIndex = (card.ZIndex or 1) + 2,
		Parent = card,
	})
	UI.corner(6).Parent = t
	return t
end

local function syncPlot(plot)
	local shelf = plot:FindFirstChild("DisplayShelf")
	if not shelf then
		return
	end
	local cards = plot:FindFirstChild("CardNames", true)
	for i = 1, (G.Sales and G.Sales.shelfSlots) or 70 do
		local slot = shelf:FindFirstChild("Slot" .. i)
		if not slot then
			if i > 80 then
				break
			end
		else
			local hand = slot:GetAttribute("Hand") == true
			local look = hand and lookOf(shelf, i) or nil
			local bb = stamps[slot]
			if look then
				if not bb or bb.Adornee ~= look then
					if bb then
						bb:Destroy()
					end
					stamps[slot] = stampFor(look)
				end
			elseif bb then
				bb:Destroy()
				stamps[slot] = nil
			end
			-- 유리 진열장 앞 이름표 (1~4칸)
			if i <= 4 and cards then
				local card = cards:FindFirstChild("Card" .. i, true)
				if card and card:IsA("TextLabel") then
					local cs = cardStamps[card]
					local show = hand and card.Text ~= ""
					if show and not cs then
						cardStamps[card] = cardStamp(card)
					elseif not show and cs then
						cs:Destroy()
						cardStamps[card] = nil
					end
				end
			end
		end
	end
end

-- 진열은 자주 바뀌니 0.5초마다 다시 맞춤 (칸 61~70개 × 가게 6칸)
task.spawn(function()
	local plots = workspace:WaitForChild("ShopPlots")
	while true do
		for _, p in ipairs(plots:GetChildren()) do
			pcall(syncPlot, p)
		end
		for slot, bb in pairs(stamps) do
			if not slot.Parent then
				bb:Destroy()
				stamps[slot] = nil
			end
		end
		task.wait(0.5)
	end
end)
