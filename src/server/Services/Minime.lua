-- 알바생 미니미 (D19, 2026-11-20): 가게 주인 아바타를 복제해 작게 만든 알바생
--  - 주인의 HumanoidDescription(접속 중이면 캐릭터에 입은 것, 아니면 userId)으로 R15 모델을 만들고 0.6배, 머리 조금 크게
--  - 옷·얼굴·피부·액세서리 그대로 (폰 부담 때문에 액세서리는 최대 G.Helper.minime.maxAccessories개), 스크립트·이름표 없음
--  - 구별: 앞치마 색(1 빨강 / 2 파랑 / 3 노랑) + 머리 위 번호표. 숙련도 = 모자 (0 없음 / 1 두건 / 2 요리사 모자)
--  - 오른손(RightHand.RightGripAttachment)에 작은 구리 국자 (ServerStorage.Assets.LadleMesh 복제, 2026-11-21 제작 세션과 정함).
--    손 작업대가 부지로 옮겨지면 제작 세션이 HelperLadles 국자를 이 손에 맞춤. 모델 속성 Minime = true, HelperIndex, OwnerUserId
-- 만들 수 없으면 nil을 돌려주고, GrowthService가 예전 부품 인형을 씀.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local CFG = G.Helper.minime

local Minime = {}

local descCache = {} -- [userId] = HumanoidDescription (원본, 쓸 때 Clone)

local function ownerDescription(player)
	local cached = descCache[player.UserId]
	if cached then
		return cached:Clone()
	end
	local desc = nil
	-- 접속 중: 지금 입은 모습 (Studio 테스트 플레이어도 됨)
	local t = 0
	while not player.Character and t < 5 and player.Parent do
		task.wait(0.2)
		t += 0.2
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local ok, d = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if ok then
			desc = d
		end
	end
	-- 아니면 userId로 (주인이 없을 때)
	if not desc and player.UserId > 0 then
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then
			desc = d
		end
	end
	if desc then
		descCache[player.UserId] = desc
		return desc:Clone()
	end
	return nil
end

local function weldTo(part, target)
	local w = Instance.new("WeldConstraint")
	w.Part0 = target
	w.Part1 = part
	w.Parent = part
end

local function deco(parent, name, size, cf, color, shape, target)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	weldTo(p, target)
	return p
end

-- 반환: Model 또는 nil. footCF = 발이 닿을 자리 (앞 = 골목 쪽)
function Minime.build(player, parent, footCF, index, skill)
	local desc = ownerDescription(player)
	if not desc then
		return nil
	end
	desc.HeadScale = (desc.HeadScale or 1) * CFG.headScale
	-- 액세서리 줄이기 (폰 부담)
	local ok = pcall(function()
		local acc = desc:GetAccessories(true)
		if #acc > CFG.maxAccessories then
			local keep = {}
			for k = 1, CFG.maxAccessories do
				keep[k] = acc[k]
			end
			desc:SetAccessories(keep, true)
		end
	end)
	if not ok then
		warn("[Minime] accessory trim failed")
	end
	local okModel, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not okModel or not model then
		warn("[Minime] create failed", model)
		return nil
	end
	model.Name = "Helper" .. index
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- Animate 등 스크립트 없음
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- 이름표 없음
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.PlatformStand = true
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	pcall(function()
		model:ScaleTo(CFG.scale)
	end)

	-- 앞치마 (번호마다 색)
	local color = CFG.apron[index] or CFG.apron[#CFG.apron]
	local torso = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	if torso then
		local s = torso.Size
		deco(model, "Apron", Vector3.new(s.X * 0.8, s.Y * 0.85, 0.06), torso.CFrame * CFrame.new(0, -s.Y * 0.05, -s.Z / 2 - 0.03), color, nil, torso)
	end
	if lower then
		local s = lower.Size
		deco(model, "ApronSkirt", Vector3.new(s.X * 0.95, s.Y * 1.6, 0.06), lower.CFrame * CFrame.new(0, -s.Y * 0.4, -s.Z / 2 - 0.03), color, nil, lower)
	end
	-- 숙련도 모자
	local head = model:FindFirstChild("Head")
	if head and (skill or 0) >= 1 then
		local hs = head.Size
		if skill == 1 then
			deco(model, "SkillBandana", Vector3.new(hs.X * 1.05, hs.Y * 0.25, hs.Z * 1.05), head.CFrame * CFrame.new(0, hs.Y * 0.32, 0), color, Enum.PartType.Block, head)
		else
			deco(model, "SkillChefHat", Vector3.new(hs.Y * 0.9, hs.X * 0.95, hs.X * 0.95), head.CFrame * CFrame.new(0, hs.Y * 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), Enum.PartType.Cylinder, head)
		end
	end
	-- 머리 위 번호표 + 상태 글 (GrowthService가 Status.TextLabel을 바꿈)
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Status"
		bb.Size = UDim2.fromOffset(190, 46)
		bb.StudsOffset = Vector3.new(0, 1.6, 0)
		bb.MaxDistance = 70
		local badge = Instance.new("TextLabel")
		badge.Name = "Number"
		badge.Size = UDim2.fromOffset(40, 40)
		badge.Position = UDim2.fromOffset(0, 3)
		badge.BackgroundColor3 = color
		badge.TextColor3 = Color3.new(1, 1, 1)
		badge.Font = Enum.Font.GothamBlack
		badge.TextScaled = true
		badge.Text = tostring(index)
		local c1 = Instance.new("UICorner")
		c1.CornerRadius = UDim.new(1, 0)
		c1.Parent = badge
		badge.Parent = bb
		local t = Instance.new("TextLabel")
		t.Name = "TextLabel"
		t.Size = UDim2.new(1, -46, 1, 0)
		t.Position = UDim2.fromOffset(46, 0)
		t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
		t.BackgroundTransparency = 0.1
		t.TextColor3 = Color3.fromRGB(92, 58, 36)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(0.3, 0)
		c2.Parent = t
		t.Parent = bb
		bb.Parent = head
	end

	-- 발을 바닥에 맞춤
	local bbCF, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local lift = pivot.Position.Y - (bbCF.Position.Y - size.Y / 2)
	model:PivotTo(footCF + Vector3.new(0, lift, 0))

	model:SetAttribute("Minime", true)
	model:SetAttribute("HelperIndex", index)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = parent
	task.wait()
	-- 넣은 뒤 Humanoid가 크기·관절을 다시 맞춰 발 높이가 바뀜 → 발(·종아리) 아래끝을 바닥에 한 번 더 맞춤
	-- (2026-11-24 사용자: 알바들이 땅에 박혀 있음, 발이 바닥보다 약 1.2 아래였음)
	local low = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name:find("Foot") or p.Name:find("LowerLeg")) then
			local corner = p.CFrame:PointToWorldSpace(Vector3.new(0, -p.Size.Y / 2, 0))
			low = math.min(low, corner.Y)
		end
	end
	if low < math.huge and math.abs(footCF.Y - low) > 0.02 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, footCF.Y - low, 0))
	end
	-- 오른손에 작은 국자 (모델을 놓은 뒤 붙임: 그 전에 붙이면 Humanoid가 크기를 다시 맞추며 같이 줄어듦): 손잡이 끝(+Z)을 그립에, 그릇(-Z)은 앞쪽 조금 아래로
	local hand = model:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGripAttachment")
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local tpl = assets and assets:FindFirstChild("LadleMesh")
	if hand and grip and tpl then
		local ladle = tpl:Clone()
		ladle.Name = "HandLadle"
		ladle.Size = tpl.Size * (CFG.ladleLength / tpl.Size.Z)
		ladle.Anchored = false
		ladle.CanCollide = false
		ladle.CanQuery = false
		ladle.CanTouch = false
		ladle.Massless = true
		local dir = (footCF.LookVector + Vector3.new(0, -CFG.ladleTilt, 0)).Unit
		local center = grip.WorldPosition + dir * (ladle.Size.Z / 2 - 0.05)
		ladle.CFrame = CFrame.lookAt(center, center + dir)
		ladle.Parent = model
		weldTo(ladle, hand)
	end

	return model
end

Players.PlayerRemoving:Connect(function(p)
	descCache[p.UserId] = nil
end)

return Minime
