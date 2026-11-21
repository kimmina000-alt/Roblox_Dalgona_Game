-- 5단계 공장 모습 (2026-11-21): 플레이어별 공장 공간에 공장 건물을 놓고, 가게 뒤 공장 문 모습을 잠김/열림으로 맞춤.
-- 서버 생산·해금·순간이동은 FactoryService(저장·부지 세션). 연결 규칙:
--   workspace.Factories.Factory<i> (i = 부지 번호) Model, 속성 Origin(CFrame, 바닥 가운데, 앞 = -Z), Unlocked, On, Status,
--   Line<k>Start·Line<k>Seconds·Line<k>Count·Line<k>Shape, MadeAt·MadeCount·MadeSlots ...
--   건물 = Factory<i>.Building (ServerStorage.Assets.Factory 복제). 부품 속성 Anim으로 클라이언트 FactoryClient가 움직임:
--     press(찍는 기계) · spin(팬) · belt(컨베이어 위 달고나) · hopper(설탕 호퍼) · kettle(주전자) · lampRun · lampStop · lampIdle · outlet(배출 슈트)
--   제어대(콘솔) 앞 ProximityPrompt "ControlPrompt" → 제어대 화면 (주인만 보임: 클라이언트가 숨김)
--   가게 문: ShopPlots.Plot<i>.FactoryDoor.Door 위 BillboardGui "DoorSign" + 잠김일 때 자물쇠 "DoorLock"

local ServerStorage = game:GetService("ServerStorage")

local FactoryBuilder = require(script.Parent:WaitForChild("FactoryBuilder"))

local Display = {}

local ANIM = {
	Line_PressHead_Node = "press",
	Line_PressStamps_Node = "press",
	Line_PressCylinders_Node = "press",
	Line_TunnelFans_Node = "spin",
	Line_Dalgona_Node = "belt",
	Line_HopperSugar_Node = "hopper",
	Deco_HopperBalls_Node = "hopper",
	Line_Kettles_Node = "kettle",
	Deco_KettleBalls_Node = "kettle",
	Line_TowerG_Node = "lampRun",
	Line_PressBeacons_Node = "lampRun",
	Line_TowerR_Node = "lampStop",
	Line_TowerY_Node = "lampIdle",
	Line_Chute_Node = "outlet",
}

local function placeBuilding(fac)
	if fac:FindFirstChild("Building") then
		return
	end
	local origin = fac:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Factory")
	if not src then
		warn("[Factory] ServerStorage.Assets.Factory 없음")
		return
	end
	local b = src:Clone()
	b.Name = "Building"
	FactoryBuilder.style(b)
	-- 예전 (0,0,30) 자리와 같은 방식: 모델 피벗 = 바닥 가운데, 앞(제어대) = -Z
	b:PivotTo(origin)
	local console
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			local key = ANIM[d.Name] or (d.Parent and ANIM[d.Parent.Name])
			if key then
				d:SetAttribute("Anim", key)
			end
			if d.Name == "Line_ConsolePanel_Node" or (d.Parent and d.Parent.Name == "Line_ConsolePanel_Node") then
				console = console or d
			end
		end
	end
	if console then
		local att = Instance.new("Attachment")
		att.Name = "ControlAtt"
		att.WorldPosition = console.Position + Vector3.new(0, 1.2, 0)
		att.Parent = console
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "ControlPrompt"
		pr.ObjectText = "공장 제어대"
		pr.ActionText = "제어대 열기"
		pr.KeyboardKeyCode = Enum.KeyCode.F
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = att
		b:SetAttribute("ConsolePos", console.Position)
	end
	b.Parent = fac
end

-- 가게 뒤 공장 문: 잠김(자물쇠 + "Lv25 해금") / 열림("공장 들어가기")
local function doorLook(plot, unlocked)
	local door = plot:FindFirstChild("FactoryDoor")
	local panel = door and door:FindFirstChild("Door")
	if not panel then
		return
	end
	local sign = panel:FindFirstChild("DoorSign")
	if not sign then
		sign = Instance.new("BillboardGui")
		sign.Name = "DoorSign"
		sign.Size = UDim2.fromOffset(180, 46)
		sign.StudsOffset = Vector3.new(0, 5.4, 0)
		sign.MaxDistance = 60
		sign.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
		t.BackgroundTransparency = 0.05
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = sign
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = t
		sign.Parent = panel
	end
	local t = sign:FindFirstChild("Text")
	t.Text = unlocked and "달고나 공장 · 들어가기" or "달고나 공장 · Lv25 해금"
	t.TextColor3 = unlocked and Color3.fromRGB(70, 140, 80) or Color3.fromRGB(150, 90, 60)
	panel.Color = unlocked and Color3.fromRGB(255, 196, 214) or Color3.fromRGB(150, 160, 170)
	local lock = door:FindFirstChild("DoorLock")
	if unlocked and lock then
		lock:Destroy()
	elseif not unlocked and not lock then
		-- 문 가운데 자물쇠 + 사슬 두 줄 (양쪽 면에 다 보이게 문 두께보다 두껍게)
		lock = Instance.new("Model")
		lock.Name = "DoorLock"
		local function p(name, size, cf, color, mat, shape)
			local q = Instance.new("Part")
			q.Name = name
			q.Size = size
			q.CFrame = cf
			q.Color = color
			q.Material = mat
			q.Anchored = true
			q.CanCollide = false
			q.CanQuery = false
			q.CanTouch = false
			if shape then
				q.Shape = shape
			end
			q.Parent = lock
			return q
		end
		local c = panel.CFrame
		for _, a in ipairs({ 35, -35 }) do
			p("Chain", Vector3.new(panel.Size.X * 1.05, 0.18, panel.Size.Z + 0.25), c * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(a)), Color3.fromRGB(120, 120, 126), Enum.Material.Metal)
		end
		p("Body", Vector3.new(0.9, 0.8, panel.Size.Z + 0.5), c * CFrame.new(0, 0.1, 0), Color3.fromRGB(230, 190, 70), Enum.Material.Metal)
		p("Shackle", Vector3.new(panel.Size.Z + 0.45, 0.7, 0.7), c * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(180, 180, 186), Enum.Material.Metal, Enum.PartType.Cylinder)
		lock.Parent = door
	end
end

local function hookFactory(fac)
	placeBuilding(fac)
	fac:GetAttributeChangedSignal("Origin"):Connect(function()
		placeBuilding(fac)
	end)
	local i = tonumber(fac.Name:match("%d+"))
	local function door()
		local plots = workspace:FindFirstChild("ShopPlots")
		local plot = plots and i and plots:FindFirstChild("Plot" .. i)
		if plot then
			doorLook(plot, fac:GetAttribute("Unlocked") == true)
		end
	end
	door()
	fac:GetAttributeChangedSignal("Unlocked"):Connect(door)
end

function Display.init()
	task.spawn(function()
		-- 가게 문은 공장 공간이 아직 없어도 잠김 모습으로
		local plots = workspace:WaitForChild("ShopPlots", 60)
		if plots then
			for _, plot in ipairs(plots:GetChildren()) do
				local i = tonumber(plot.Name:match("%d+"))
				local folder = workspace:FindFirstChild("Factories")
				if not (folder and i and folder:FindFirstChild("Factory" .. i)) then
					doorLook(plot, false)
				end
			end
		end
		local folder = workspace:WaitForChild("Factories", 120)
		if not folder then
			return
		end
		for _, f in ipairs(folder:GetChildren()) do
			task.spawn(hookFactory, f)
		end
		folder.ChildAdded:Connect(function(f)
			task.spawn(hookFactory, f)
		end)
	end)
end

return Display
