-- 골목 슈퍼 너구리 사장님 동작 (2026-11-25, D54): 서버 AlleyBuilder가 Workspace.Alley.AlleyMarket.Shopkeeper에 세운 부품을
-- 내 화면에서만 움직임. 리그·동작 값 = Shared.ShopkeeperRig (NPC 세션 shopkeeper.py가 만든 값)
--   부품 CFrame = Root * CFrame.new(Joint) * 회전 * CFrame.new(Center - Joint)   (Root = 모델 속성, Joint·Center = 부품 속성)
--   서 있기: 몸이 아주 조금 위아래로 숨쉬기
--   가끔(8~14초마다): 손 흔들기(오른팔 wave) 또는 고개 끄덕(nod)
--   손님 인사: 누가 계산대 앞(MarketCounter 둘레 GREET_R)에 새로 오면 손 흔들고 끄덕이며 말풍선 "어서 와요!"
--   멀면(FAR) 움직이지 않음 (폰 성능)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopkeeperRig"))

local FAR = 80
local GREET_R = 7
local WAVE_T = 2.2 -- 손 흔드는 시간
local NOD_T = 1.0 -- 끄덕이는 시간
local SAY = { "어서 와요!", "뭐 찾아요?", "설탕 새로 들어왔어요~", "또 왔네!" }

local npc, root, parts, counter = nil, nil, {}, nil
local act, actT, nextIdle = nil, 0, os.clock() + 4
local near = {} -- [player] = 계산대 앞에 있었나
local bubble = nil

local function find()
	local alley = workspace:FindFirstChild("Alley")
	local market = alley and alley:FindFirstChild("AlleyMarket")
	local m = market and market:FindFirstChild("Shopkeeper")
	if m == npc then
		return
	end
	npc = m
	parts = {}
	counter = market and market:FindFirstChild("MarketCounter")
	if not m then
		return
	end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and typeof(p:GetAttribute("Joint")) == "Vector3" then
			parts[p.Name] = { p = p, joint = p:GetAttribute("Joint"), center = p:GetAttribute("Center") }
		end
	end
end

local function pose(name, rot, lift)
	local e = parts[name]
	if not e or not root then
		return
	end
	local r = root
	if lift then
		r = r + Vector3.new(0, lift, 0)
	end
	e.p.CFrame = r * CFrame.new(e.joint) * rot * CFrame.new(e.center - e.joint)
end

local function say(text)
	local head = parts.Head and parts.Head.p
	if not head then
		return
	end
	if not bubble or not bubble.Parent then
		bubble = Instance.new("BillboardGui")
		bubble.Name = "ShopkeeperSay"
		bubble.Size = UDim2.fromOffset(150, 34)
		bubble.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
		bubble.MaxDistance = 40
		bubble.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 246, 226)
		t.TextColor3 = Color3.fromRGB(74, 44, 24)
		t.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		t.TextScaled = true
		t.Parent = bubble
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = t
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.Parent = t
		bubble.Parent = head
	end
	bubble.Text.Text = text
	bubble.Enabled = true
	local mine = bubble
	task.delay(2.5, function()
		if mine == bubble and mine.Parent then
			mine.Enabled = false
		end
	end)
end

local function start(kind)
	act, actT = kind, 0
end

RunService.Heartbeat:Connect(function(dt)
	find()
	if not npc or not npc.Parent then
		return
	end
	root = npc:GetAttribute("Root")
	if typeof(root) ~= "CFrame" then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - root.Position).Magnitude > FAR then
		return
	end
	local now = os.clock()
	-- 손님 인사: 계산대 앞에 새로 온 사람
	if counter then
		for _, plr in ipairs(Players:GetPlayers()) do
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local inside = hrp ~= nil and (Vector3.new(hrp.Position.X - counter.Position.X, 0, hrp.Position.Z - counter.Position.Z)).Magnitude < GREET_R
			if inside and not near[plr] then
				start("greet")
				say(SAY[math.random(1, #SAY)])
			end
			near[plr] = inside or nil
		end
	end
	-- 가끔 혼자 손 흔들기·끄덕
	if not act and now > nextIdle then
		start(math.random() < 0.5 and "wave" or "nod")
		nextIdle = now + 8 + math.random() * 6
	end
	local armR, head = CFrame.identity, CFrame.identity
	if act then
		actT += dt
		local w = Rig.wave
		if act == "wave" or act == "greet" then
			-- 팔 올리기(0.25초) → 흔들기 → 내리기(마지막 0.25초)
			local up = math.clamp(math.min(actT, WAVE_T - actT) / 0.25, 0, 1)
			armR = CFrame.Angles(0, 0, math.rad((w.raise + math.sin(actT * w.speed) * w.swing) * up))
		end
		if act == "nod" or (act == "greet" and actT > 0.6) then
			local k = act == "nod" and actT or (actT - 0.6)
			if k < NOD_T then
				head = CFrame.Angles(math.rad(-Rig.nod * math.sin(k / NOD_T * math.pi * 2) ^ 2), 0, 0)
			end
		end
		if actT >= (act == "nod" and NOD_T or WAVE_T) then
			act = nil
		end
	end
	local breathe = math.sin(now * 2) * 0.03
	pose("Body", CFrame.identity, breathe)
	pose("Head", head, breathe)
	pose("ArmR", armR, breathe)
	pose("ArmL", CFrame.identity, breathe)
	pose("LegL", CFrame.identity)
	pose("LegR", CFrame.identity)
end)
