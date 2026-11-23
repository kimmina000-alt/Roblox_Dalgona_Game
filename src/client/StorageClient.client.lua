-- 가게 냉장고·서랍장 (2026-11-24 사용자 "냉장고랑 냉장고 옆 서랍장 기능 구현", 판매 세션)
--  - 내 가게의 냉장고(Role "냉장고")를 누르면 식재료(설탕·소다), 서랍장(Role "서랍장")을 누르면 그 밖의 재료 창
--  - 칸마다 보유 수 / 최대, 묶음 1·5·10개 사기 버튼 3개 (Remotes.BuyIngredient, 재료 상점과 같은 값, G.BuyPacks). 묶음 목록은 GrowthConfig.StorageGroups
--  - 제작 화면이 열려 있으면 안 열림. 너무 멀리서(40칸 밖)는 안 됨
--  - 가까이 가면 "냉장고 열기"·"서랍장 열기" 버튼(ProximityPrompt, 내 화면에만)도 뜸 (2026-11-24 사용자 요청)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local UI = require(Shared:WaitForChild("UiStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = UI.C
local new = UI.new

local MAX_DISTANCE = 40

local ING = {}
for _, ing in ipairs(G.Ingredients) do
	ING[ing.id] = ing
end
local GROUP_BY_ROLE = {}
for _, g in ipairs(G.StorageGroups) do
	GROUP_BY_ROLE[g.role] = g
end

local gui = UI.screen("StorageUi", 7, playerGui)
local root = UI.root(gui)
local fit = UI.fitter(root)
local BUY_PACKS = G.BuyPacks or { 1, 5, 10 }
local win = UI.window({ Name = "Window", Title = "냉장고", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(640, 340), ZIndex = 10, Parent = root })
fit(win, 640, 365, true) -- 화면 비율 창 (2026-11-24)
win.Visible = false
local body = win.Body
body.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local msg = UI.text({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = win })
local function setMsg(text, good)
	msg.Text = text
	local s = msg:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = good and C.good or C.bad
	end
end
local grid = new("Frame", { Name = "Grid", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1, ZIndex = 12, Parent = body }, {
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 1, -4), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local state = nil
local current = nil -- 지금 연 묶음
local haveText, buyButtons = {}, {}
local busy = false

local function refresh()
	for id, t in pairs(haveText) do
		local n = state and state.ingredients and state.ingredients[id] or 0
		t.Text = string.format("보유 %d / %d", n, G.IngredientMax)
	end
	for _, info in ipairs(buyButtons) do
		UI.setButton(info.button, { Enabled = state ~= nil and state.coins >= info.price })
	end
end

local function build(group)
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	haveText, buyButtons = {}, {}
	for i, id in ipairs(group.ids) do
		local ing = ING[id]
		if ing then
			local card = UI.card({ Name = id, LayoutOrder = i, ZIndex = 13, Parent = grid })
			local iconBox = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.tan, ZIndex = 14, Parent = card }, { UI.corner(12), UI.stroke(C.line, 2) })
			UI.text({ Text = ing.icon, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = iconBox })
			UI.text({ Text = ing.name, Position = UDim2.fromOffset(4, 66), Size = UDim2.new(1, -8, 0, 22), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = card })
			haveText[id] = UI.text({ Text = "", Position = UDim2.fromOffset(4, 88), Size = UDim2.new(1, -8, 0, 18), TextSize = 14, FontFace = UI.F.bold, TextColor3 = C.soft, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = card })
			-- 묶음 버튼 3개 (위에서 아래로 ×1 / ×5 / ×10)
			for k, packs in ipairs(BUY_PACKS) do
				local units, price = ing.pack * packs, ing.price * packs
				local b = UI.button({
					Name = string.format("Buy_%s_%d", id, units),
					Text = string.format("+%d · %d코인", units, price),
					Color = k == 1 and C.yellow or (k == 2 and C.green or C.cyan),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 110 + (k - 1) * 40),
					Size = UDim2.new(1, -14, 0, 36),
					TextSize = 16,
					ZIndex = 14,
					Parent = card,
				})
				table.insert(buyButtons, { button = b, price = price })
				b.Activated:Connect(function()
					if busy or not b:GetAttribute("Enabled") then
						return
					end
					busy = true
					local ok, res = pcall(function()
						return Remotes.BuyIngredient:InvokeServer(id, packs)
					end)
					if ok and type(res) == "table" and res.ok then
						UI.coinSound()
						setMsg(string.format("%s %d개를 넣었어요", ing.name, units), true)
					else
						setMsg((ok and type(res) == "table" and res.reason) or "살 수 없어요", false)
					end
					busy = false
				end)
			end
		end
	end
	refresh()
end

local function open(group)
	current = group
	local plank = win:FindFirstChild("Title")
	local title = plank and plank:FindFirstChild("Text")
	if title and title:IsA("TextLabel") then
		title.Text = group.title
	end
	build(group)
	setMsg("", true)
	win.Visible = true
end

win.Close.Activated:Connect(function()
	win.Visible = false
end)

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(s)
	state = s
	if win.Visible then
		refresh()
	end
end)
task.spawn(function()
	local ok, s = pcall(function()
		return Remotes.GetPlayerState:InvokeServer()
	end)
	if ok and s then
		state = s
	end
end)

local function myPlot()
	local idx = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("ShopPlots")
	local plot = idx and plots and plots:FindFirstChild("Plot" .. idx)
	if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
		return plot
	end
	return nil
end

local function making()
	local ms = playerGui:FindFirstChild("MakingScreen")
	return ms and ms.Enabled
end

local function targets(plot)
	local list = {}
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("BasePart") and GROUP_BY_ROLE[d:GetAttribute("Role") or ""] then
			table.insert(list, d)
		end
	end
	return list
end

local function tryOpen(screenPos)
	if making() then
		return
	end
	local plot = myPlot()
	if not plot then
		return
	end
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets(plot)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not hit then
		return
	end
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if rootPart and (rootPart.Position - hit.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local group = GROUP_BY_ROLE[hit.Instance:GetAttribute("Role") or ""]
	if group then
		open(group)
	end
end

-- 가까이 가면 뜨는 열기 버튼 (내 가게 냉장고·서랍장에만, 이 화면에서만 만듦)
local prompts = {}
local function syncPrompts()
	local plot = myPlot()
	local want = {}
	if plot then
		for _, part in ipairs(targets(plot)) do
			want[part] = true
		end
	end
	for part, pr in pairs(prompts) do
		if not want[part] or not part.Parent then
			pr:Destroy()
			prompts[part] = nil
		end
	end
	for part in pairs(want) do
		if not prompts[part] then
			local group = GROUP_BY_ROLE[part:GetAttribute("Role")]
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "StoragePrompt"
			pr.ActionText = group.role .. " 열기"
			pr.ObjectText = group.title
			pr.KeyboardKeyCode = Enum.KeyCode.E
			pr.HoldDuration = 0
			pr.MaxActivationDistance = 8
			pr.RequiresLineOfSight = false
			pr.Parent = part
			pr.Triggered:Connect(function()
				if not making() then
					open(group)
				end
			end)
			prompts[part] = pr
		end
	end
end
player:GetAttributeChangedSignal("PlotIndex"):Connect(syncPrompts)

-- 마우스: 거의 안 움직이고 뗐을 때 (카메라 돌리기와 구분). 터치: 톡 친 자리
local downAt = nil
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		downAt = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and downAt then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local moved = (p - downAt).Magnitude
		downAt = nil
		if not processed and moved < 8 then
			tryOpen(p)
		end
	end
end)
UserInputService.TouchTapInWorld:Connect(function(pos, processedByUI)
	if not processedByUI then
		tryOpen(pos)
	end
end)

-- 제작 화면이 열리면 닫음, 열기 버튼은 제작 중에 숨김. 가게가 바뀌거나 부품이 늦게 와도(스트리밍) 버튼을 다시 맞춤
task.spawn(function()
	local n = 0
	while true do
		task.wait(0.5)
		local mk = making()
		if win.Visible and mk then
			win.Visible = false
		end
		for _, pr in pairs(prompts) do
			pr.Enabled = not mk
		end
		n += 1
		if n % 6 == 1 then
			pcall(syncPrompts)
		end
	end
end)
