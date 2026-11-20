-- 진열대 "여기에 놓기" 안내 (2026-11-21 사용자 결정 "들고 가서 놓기")
-- 서버는 빈 칸마다 PlacePrompt를 켜고 속성 Open = 빈 칸으로 둔다. 이 스크립트는 내 화면에서만 걸러 보여 준다:
--   내 가게(부지 OwnerUserId = 나) 진열대이고, 들고 있는 달고나(속성 Carrying)나 보관함에 안 놓은 것(속성 Unshelved)이 있을 때만.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local watched = {} -- [prompt] = plot

local function canPlace()
	return (player:GetAttribute("Carrying") or 0) ~= 0 or (player:GetAttribute("Unshelved") or 0) > 0
end

local function plotOf(prompt)
	local m = prompt:FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("PlotIndex") == nil do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return m
end

local function apply(prompt)
	local plot = watched[prompt]
	local want = prompt:GetAttribute("Open") == true and plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId and canPlace()
	if prompt.Enabled ~= want then
		prompt.Enabled = want
	end
end

local function watch(prompt)
	if watched[prompt] ~= nil or prompt.Name ~= "PlacePrompt" then
		return
	end
	watched[prompt] = plotOf(prompt) or false
	prompt:GetAttributeChangedSignal("Open"):Connect(function()
		apply(prompt)
	end)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		apply(prompt) -- 서버가 다시 켜거나 꺼도 내 화면 기준으로 되돌림
	end)
	local plot = watched[prompt]
	if plot then
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			apply(prompt)
		end)
	end
	apply(prompt)
end

local function refreshAll()
	for prompt in pairs(watched) do
		if prompt.Parent then
			apply(prompt)
		else
			watched[prompt] = nil
		end
	end
end

local plots = workspace:WaitForChild("ShopPlots")
for _, d in ipairs(plots:GetDescendants()) do
	if d:IsA("ProximityPrompt") then
		watch(d)
	end
end
plots.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		watch(d)
	end
end)
player:GetAttributeChangedSignal("Carrying"):Connect(refreshAll)
player:GetAttributeChangedSignal("Unshelved"):Connect(refreshAll)
