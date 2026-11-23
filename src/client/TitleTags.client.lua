-- 머리 위 칭호 (D38, 2026-11-24): 플레이어 속성 Title(서버 CollectionService가 넣음, "" = 없음)을
-- 이름 위에 작은 리본 판으로 띄움. 나와 다른 플레이어 모두. 이 화면에서만 만드는 BillboardGui.
-- 만드는 동안은 숨김 (2026-11-24 사용자 요청): 플레이어 속성 Making = true (서버 제작 세션이 넣음, 다른 사람 화면에도),
-- 내 칭호는 내 제작 화면(PlayerGui.MakingScreen)이 켜져 있을 때도 바로 숨김.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local C = UI.C

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")
local myMaking = false -- 내 제작 화면이 켜져 있나
local holder = Instance.new("Folder")
holder.Name = "TitleTags"
holder.Parent = playerGui

local tags = {} -- [player] = BillboardGui

local function build(player)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Title_" .. player.UserId
	bb.Size = UDim2.fromOffset(200, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0) -- 이름표 위
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Enabled = false
	bb.Parent = holder
	-- 크림 리본 + 나무 테 (UiStyle 색)
	local plate = UI.new("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 1, -4),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.cream,
		Parent = bb,
	}, {
		UI.corner("round"),
		UI.stroke(C.gold, 2.5),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	UI.text({
		Name = "Label",
		Text = "",
		TextSize = 16,
		TextColor3 = C.woodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Parent = plate,
	})
	return bb
end

local function refresh(player)
	local bb = tags[player]
	if not bb then
		return
	end
	local title = player:GetAttribute("Title")
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local has = type(title) == "string" and title ~= ""
	local making = player:GetAttribute("Making") == true or (player == me and myMaking)
	bb.Plate.Label.Text = has and ("🏅 " .. title) or ""
	bb.Adornee = head
	bb.Enabled = has and head ~= nil and not making
end

local function watch(player)
	tags[player] = build(player)
	player:GetAttributeChangedSignal("Title"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("Making"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		refresh(player)
	end)
	refresh(player)
end

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(watch, p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
	if tags[p] then
		tags[p]:Destroy()
		tags[p] = nil
	end
end)

-- 내 제작 화면
local function watchMaking(screen)
	local function sync()
		myMaking = screen.Enabled
		refresh(me)
	end
	screen:GetPropertyChangedSignal("Enabled"):Connect(sync)
	sync()
end
local making = playerGui:FindFirstChild("MakingScreen")
if making then
	watchMaking(making)
else
	playerGui.ChildAdded:Connect(function(c)
		if c.Name == "MakingScreen" and c:IsA("ScreenGui") then
			watchMaking(c)
		end
	end)
end
