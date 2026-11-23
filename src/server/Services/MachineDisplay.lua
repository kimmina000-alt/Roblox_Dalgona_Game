-- 가게 기계 1자리 모습 (20번 기계 2~4단계, 2026-11-21)
-- 서버 생산 로직(GrowthService, 저장·부지 세션)이 부지의 MachineSlot 파트에 속성을 쓰고, 여기서는 모습만 맞춘다.
--   MachineSlot 속성: Stage(1 없음·2 철제 판매기·3 분홍 자판기·4 연속 생산 설비), MachineId, Running, Status, Shape,
--   CycleStart·CycleSeconds, MadeAt·MadeCount·MadeSlots → 움직임·배출·진열 연출은 클라이언트 MachineClient가 그림
-- 모델은 부지 모델 바로 아래 "Machine" (앞 = 골목 쪽). 부품 속성 Anim으로 클라이언트가 움직일 곳을 찾음:
--   "spin"(돌아감) · "press"(위아래) · "lampRun"(돌 때 켜짐) · "lampStop"(멈추면 빨강) · "outlet"(배출구) · "window"(창 속 달고나)
-- 기계 앞에 ProximityPrompt "MachinePrompt" (주인만 보임: 클라이언트가 숨김) → 도안 고르기·다음 기계 사기 화면
--
-- D32 (2026-11-23, 기계 쌓기): 단계마다 고정 자리 MachineSlot2·3·4 (PlotService). 산 기계는 모두 자기 자리에 남아 같이 돎.
--   슬롯 속성 Owned = 샀는지, Stage = 샀으면 그 단계 번호(아니면 1), SlotStage = 자리 번호. 모델 = Plot.Machine<n>
--   (속성 Stage·SlotName, 프롬프트 속성 MachineStage = n). 아직 안 산 다음 단계 자리에는 "기계 보기" 안내만 둠.
--   새 슬롯이 있으면 옛 MachineSlot(가장 높은 단계 하나)은 그리지 않음

local ServerStorage = game:GetService("ServerStorage")
local PROMPT_DISTANCE = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GrowthConfig")).PromptDistance or 6 -- 기계·가구 버튼이 뜨는 거리 (2026-11-24)

local FactoryBuilder = require(script.Parent:WaitForChild("FactoryBuilder"))

local Display = {}

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function cyl(parent, name, len, dia, cf, color, props)
	-- 원기둥 길이 축 = X. cf는 가운데, 기본은 위(+Y)로 세움
	local p = part(parent, name, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, 0, math.rad(90)), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local DALGONA = Color3.fromRGB(222, 156, 76)

-- 작은 달고나 하나 (창 속 진열·배출구용): 납작한 원기둥 + 별 자국 대신 진한 점
local function miniDalgona(parent, name, cf, d)
	local p = cyl(parent, name, 0.06, d, cf, DALGONA)
	part(parent, name .. "Mark", Vector3.new(d * 0.28, 0.01, d * 0.28), cf * CFrame.new(0, -0.035, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 90, 40))
	return p
end

-- 2단계 철제 판매기: 낡은 회색 금속 상자 + 유리창(달고나 3줄) + 동전 넣는 곳 + 아래 배출구 + 위 빨간 표시등
local function buildSteel(m, base)
	local W, D, H = 3.4, 2.4, 5.2
	local steel = Color3.fromRGB(150, 156, 160)
	local dark = Color3.fromRGB(80, 84, 90)
	part(m, "Body", Vector3.new(W, H, D), base * CFrame.new(0, H / 2, 0), steel, { Material = Enum.Material.DiamondPlate })
	part(m, "Roof", Vector3.new(W + 0.2, 0.25, D + 0.2), base * CFrame.new(0, H + 0.12, 0), dark, { Material = Enum.Material.Metal })
	part(m, "Plinth", Vector3.new(W + 0.1, 0.3, D + 0.1), base * CFrame.new(0, 0.15, 0), dark, { Material = Enum.Material.Metal })
	-- 앞 = -Z
	local front = base * CFrame.new(0, 0, -D / 2)
	part(m, "WindowFrame", Vector3.new(W - 0.6, 2.7, 0.1), front * CFrame.new(-0.3, 3.2, -0.04), dark, { Material = Enum.Material.Metal })
	part(m, "Window", Vector3.new(W - 0.85, 2.45, 0.06), front * CFrame.new(-0.3, 3.2, -0.26), Color3.fromRGB(210, 235, 245), { Material = Enum.Material.Glass, Transparency = 0.78 })
	for row = 0, 2 do
		local y = 2.3 + row * 0.8
		-- 창과 몸통 사이 얕은 칸에 달고나를 세워 둠 (몸통 안쪽에 넣으면 안 보임)
		part(m, "Shelf", Vector3.new(W - 0.9, 0.06, 0.2), front * CFrame.new(-0.3, y - 0.27, -0.12), dark)
		for col = -1, 1 do
			local p = miniDalgona(m, "WindowDalgona", front * CFrame.new(-0.3 + col * 0.75, y, -0.15) * CFrame.Angles(math.rad(80), 0, 0), 0.55)
			p:SetAttribute("Anim", "window")
		end
	end
	-- 오른쪽 조작판: 동전 넣는 곳 · 단추 · 표시등
	part(m, "Panel", Vector3.new(0.5, 2.4, 0.08), front * CFrame.new(W / 2 - 0.42, 3.2, -0.05), Color3.fromRGB(60, 62, 66))
	part(m, "CoinSlot", Vector3.new(0.08, 0.35, 0.06), front * CFrame.new(W / 2 - 0.42, 3.8, -0.1), Color3.fromRGB(20, 20, 20))
	for i = 0, 2 do
		cyl(m, "Button", 0.08, 0.22, front * CFrame.new(W / 2 - 0.42, 3.2 - i * 0.35, -0.1) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(230, 200, 80), { Material = Enum.Material.Neon })
	end
	local lamp = cyl(m, "LampRun", 0.25, 0.4, base * CFrame.new(-0.8, H + 0.38, -D / 2 + 0.4), Color3.fromRGB(90, 200, 110), { Material = Enum.Material.Neon })
	lamp:SetAttribute("Anim", "lampRun")
	local stop = cyl(m, "LampStop", 0.25, 0.4, base * CFrame.new(0.8, H + 0.38, -D / 2 + 0.4), Color3.fromRGB(220, 60, 50), { Material = Enum.Material.Neon })
	stop:SetAttribute("Anim", "lampStop")
	-- 배출구 (아래)
	part(m, "Outlet", Vector3.new(1.6, 0.7, 0.3), front * CFrame.new(-0.3, 0.9, -0.12), Color3.fromRGB(35, 35, 40)):SetAttribute("Anim", "outlet")
	part(m, "OutletFlap", Vector3.new(1.5, 0.6, 0.05), front * CFrame.new(-0.3, 0.92, -0.3), Color3.fromRGB(200, 220, 230), { Material = Enum.Material.Glass, Transparency = 0.5 })
	-- 옆 손잡이 톱니 (돌아감)
	local gear = cyl(m, "Gear", 0.15, 1.0, base * CFrame.new(W / 2 + 0.08, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-90)), Color3.fromRGB(190, 150, 70), { Material = Enum.Material.Metal })
	gear:SetAttribute("Anim", "spin")
	part(m, "Sign", Vector3.new(W - 0.4, 0.6, 0.08), front * CFrame.new(0, H - 0.45, -0.06), Color3.fromRGB(240, 230, 210))
	return W, D, H
end

-- 3단계 분홍 자판기: 둥근 분홍 상자 + 큰 창(달고나 4×3) + 반짝이 단추 + 위 하트 간판 + 배출구
local function buildPink(m, base)
	local W, D, H = 4.0, 2.6, 5.8
	local pink = Color3.fromRGB(255, 170, 200)
	local cream = Color3.fromRGB(255, 244, 236)
	part(m, "Body", Vector3.new(W, H, D), base * CFrame.new(0, H / 2, 0), pink)
	-- 둥근 모서리 느낌: 옆 기둥
	for _, s in ipairs({ -1, 1 }) do
		cyl(m, "Corner", H, 0.7, base * CFrame.new(s * W / 2, H / 2, -D / 2 + 0.35), pink)
	end
	local front = base * CFrame.new(0, 0, -D / 2)
	part(m, "WindowFrame", Vector3.new(W - 1.2, 3.2, 0.1), front * CFrame.new(-0.4, 3.4, -0.04), cream)
	part(m, "Window", Vector3.new(W - 1.45, 2.95, 0.06), front * CFrame.new(-0.4, 3.4, -0.26), Color3.fromRGB(225, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.78 })
	for row = 0, 2 do
		local y = 2.35 + row * 0.95
		part(m, "Shelf", Vector3.new(W - 1.5, 0.06, 0.2), front * CFrame.new(-0.4, y - 0.3, -0.12), Color3.fromRGB(255, 214, 228))
		for col = 0, 3 do
			local p = miniDalgona(m, "WindowDalgona", front * CFrame.new(-0.4 - 1.05 + col * 0.7, y, -0.15) * CFrame.Angles(math.rad(80), 0, 0), 0.55)
			p:SetAttribute("Anim", "window")
		end
	end
	-- 오른쪽 단추판 (사탕 단추)
	part(m, "Panel", Vector3.new(0.75, 3.0, 0.08), front * CFrame.new(W / 2 - 0.55, 3.3, -0.05), cream)
	local candy = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(140, 220, 140) }
	for i = 0, 3 do
		cyl(m, "Button", 0.1, 0.32, front * CFrame.new(W / 2 - 0.55, 4.3 - i * 0.55, -0.12) * CFrame.Angles(math.rad(90), 0, 0), candy[i + 1], { Material = Enum.Material.Neon })
	end
	-- 위 하트 간판 + 표시등
	part(m, "Roof", Vector3.new(W + 0.3, 0.3, D + 0.3), base * CFrame.new(0, H + 0.15, 0), cream)
	local heart = part(m, "SignHeart", Vector3.new(1.3, 1.3, 0.25), base * CFrame.new(0, H + 1.0, -D / 2 + 0.4) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 90, 140), { Material = Enum.Material.Neon })
	heart:SetAttribute("Anim", "lampRun")
	local stop = cyl(m, "LampStop", 0.25, 0.4, base * CFrame.new(W / 2 - 0.4, H + 0.45, -D / 2 + 0.4), Color3.fromRGB(220, 60, 50), { Material = Enum.Material.Neon })
	stop:SetAttribute("Anim", "lampStop")
	-- 배출구
	part(m, "Outlet", Vector3.new(2.0, 0.8, 0.3), front * CFrame.new(-0.4, 0.95, -0.12), Color3.fromRGB(120, 60, 80)):SetAttribute("Anim", "outlet")
	part(m, "OutletFlap", Vector3.new(1.9, 0.7, 0.05), front * CFrame.new(-0.4, 0.97, -0.3), Color3.fromRGB(255, 230, 240), { Material = Enum.Material.Glass, Transparency = 0.45 })
	-- 위 바람개비 (돌아감)
	local fan = part(m, "Pinwheel", Vector3.new(0.9, 0.9, 0.06), base * CFrame.new(-W / 2 + 0.5, H + 0.9, -D / 2 + 0.4) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 240, 120), { Material = Enum.Material.Neon })
	fan:SetAttribute("Anim", "spin")
	fan:SetAttribute("Axis", "Z")
	part(m, "Plinth", Vector3.new(W + 0.2, 0.3, D + 0.2), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(230, 130, 165))
	return W, D, H
end

-- 4단계 연속 생산 설비: ServerStorage.Assets.MachineLine (부품 이름으로 움직일 곳 표시). 자리(9칸)에 맞게 줄임
local LINE_ANIM = {
	L4_CoolFan_Node = "spin",
	L4_PressHead_Node = "press",
	L4_PressStamps_Node = "press",
	L4_TowerG_Node = "lampRun",
	L4_TowerR_Node = "lampStop",
	L4_Chute_Node = "outlet",
	L4_Dalgona_Node = "window",
}
local function buildLine(m, base)
	local assets = ServerStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("MachineLine")
	if not src then
		warn("[Machine] ServerStorage.Assets.MachineLine 없음")
		return nil
	end
	local line = src:Clone()
	FactoryBuilder.style(line)
	local cf, size = line:GetBoundingBox()
	local k = math.min(1, 8.6 / math.max(size.X, size.Z))
	if k < 1 then
		line:ScaleTo(line:GetScale() * k)
		cf, size = line:GetBoundingBox()
	end
	-- 바닥에 놓고 가운데 맞춤 (모델 앞 = -Z 그대로)
	local pv = line:GetPivot()
	local offset = pv:ToObjectSpace(CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)))
	line:PivotTo(base * offset:Inverse())
	for _, d in ipairs(line:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			local a = LINE_ANIM[d.Name] or (d.Parent and LINE_ANIM[d.Parent.Name])
			if a then
				d:SetAttribute("Anim", a)
			end
		end
	end
	for _, c in ipairs(line:GetChildren()) do
		c.Parent = m
	end
	line:Destroy()
	return size.X, size.Z, size.Y
end

local BUILDERS = { [2] = buildSteel, [3] = buildPink, [4] = buildLine }
local NAMES = { [2] = "철제 판매기", [3] = "분홍 자판기", [4] = "연속 생산 설비" }

-- 편집 화면에서 고친 기계 모양 (판매 세션 2026-11-22, 사용자 "기계도 고치게"):
-- 편집 모드 Workspace.MachineLayout 안 Stage2·Stage3·Stage4 (Model). 각 단계 모델 안 부품 "SlotAnchor" = 기계 자리 윗면(top) 기준.
-- 서버 시작 때 ServerStorage.Assets.MachineLayout으로 옮기고, 그 단계를 만들 때 부품 LayoutKey로 위치·크기·색을 옮김.
-- 기계 위치(가게 안 자리)는 PlotLayout의 MachineSlot을 옮기면 됨
local Layout = require(script.Parent:WaitForChild("LayoutTemplate"))
local machineLayout = nil

local function findMachineLayout()
	local SS = game:GetService("ServerStorage")
	local assets = SS:FindFirstChild("Assets")
	local src = workspace:FindFirstChild("MachineLayout")
	if src then
		src.Parent = assets or SS
	else
		src = assets and assets:FindFirstChild("MachineLayout")
	end
	return src
end

local function applyMachineLayout(m, stage, top)
	local t = machineLayout and machineLayout:FindFirstChild("Stage" .. stage)
	local anchor = t and t:FindFirstChild("SlotAnchor")
	if not anchor then
		return
	end
	Layout.tag(m)
	Layout.apply(m, t, anchor.CFrame, top, {
		skip = function(tp)
			return tp == anchor
		end,
	})
end

local function addPrompt(attachTo, objectText, actionText)
	local att = Instance.new("Attachment")
	att.Name = "PromptAtt"
	att.Parent = attachTo
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "MachinePrompt"
	pr.ObjectText = objectText
	pr.ActionText = actionText
	pr.KeyboardKeyCode = Enum.KeyCode.F
	pr.HoldDuration = 0
	pr.MaxActivationDistance = PROMPT_DISTANCE
	pr.RequiresLineOfSight = false
	pr.Parent = att
	return pr
end

-- 기계 하나 만들기 (top = 자리 윗면, 앞 = 골목 쪽 -Z)
local function buildMachine(plot, name, stage, top, slotName)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Stage", stage)
	m:SetAttribute("MachineName", NAMES[stage])
	m:SetAttribute("SlotName", slotName)
	local ok, w, d, h = pcall(BUILDERS[stage], m, top)
	if not ok then
		warn("[Machine] 모델을 못 만들었어요:", w)
		m:Destroy()
		return nil
	end
	applyMachineLayout(m, stage, top)
	local anchor = part(m, "PromptAnchor", Vector3.new(0.2, 0.2, 0.2), top * CFrame.new(0, 2.2, -(d or 2.4) / 2 - 0.3), Color3.new(1, 1, 1), { Transparency = 1, CanQuery = false, CastShadow = false })
	local pr = addPrompt(anchor, NAMES[stage], "도안 고르기")
	pr:SetAttribute("MachineStage", stage)
	m:SetAttribute("Height", h or 5)
	m.PrimaryPart = anchor
	return m
end

-- 자리 파트는 글씨 방향 때문에 90° 돌아가 있음 → 부지 방향(앞 = 골목 쪽 -Z)으로 되돌림
local function slotTop(slot)
	return slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0) * CFrame.Angles(0, -math.pi * 0.5, 0)
end

-- 새로 산 기계가 나타날 때: 작게 시작해서 0.4초 동안 커짐 (서버에서 크기를 바꾸면 모두에게 보임).
-- 커지는 동안 속성 Popping = true → MachineClient는 끝난 뒤에 움직일 부품의 처음 자리(AnimBase)를 잼
-- 부지에 넣기 전에 부름 (처음 한 프레임이 큰 채로 보이지 않게)
local function popIn(m)
	local ok = pcall(function()
		m:ScaleTo(0.05)
	end)
	if not ok then
		return
	end
	m:SetAttribute("Popping", true)
	task.defer(function() -- 부지에 넣은 뒤에 시작
		local t = 0
		while t < 0.4 do
			t += task.wait()
			if not m.Parent then
				return
			end
			local k = math.min(t / 0.4, 1)
			local e = 1 - (1 - k) ^ 3 -- 끝에서 부드럽게
			m:ScaleTo(math.max(0.05, e * (1 + 0.12 * math.sin(math.pi * k))))
		end
		if m.Parent then
			m:ScaleTo(1)
			m:SetAttribute("Popping", nil)
		end
	end)
end

-- 옛 한 자리(MachineSlot): 새 슬롯이 없는 부지(예전 저장 장소)에서만 씀
local function syncLegacy(plot)
	local slot = plot:FindFirstChild("MachineSlot")
	if not slot then
		return
	end
	local stage = slot:GetAttribute("Stage") or 1
	local old = plot:FindFirstChild("Machine")
	if old and old:GetAttribute("Stage") == stage then
		return
	end
	if old then
		old:Destroy()
	end
	-- 바닥 자리 표시: 기계가 있으면 숨기고, 없으면 "기계 사기" 안내(F)를 붙임
	local label = slot:FindFirstChildOfClass("SurfaceGui")
	local slotPrompt = slot:FindFirstChild("PromptAtt")
	if slotPrompt then
		slotPrompt:Destroy()
	end
	if not BUILDERS[stage] then
		slot.Transparency = 0.35
		if label then
			label.Enabled = true
		end
		addPrompt(slot, "기계 자리", "기계 보기")
		return
	end
	slot.Transparency = 1
	if label then
		label.Enabled = false
	end
	local m = buildMachine(plot, "Machine", stage, slotTop(slot), "MachineSlot")
	if m then
		m.Parent = plot
	end
end

local function hasStack(plot)
	return plot:FindFirstChild("MachineSlot2") ~= nil
end

-- 새 자리 3개 (D32): 산 기계는 자기 자리에, 아직 안 산 첫 단계 자리에는 "기계 보기" 안내
local function syncStack(plot, animate)
	-- 옛 한 자리 모습은 지움 (서버가 옛 슬롯을 지우기 전까지 두 번 그려지지 않게)
	local legacy = plot:FindFirstChild("Machine")
	if legacy then
		legacy:Destroy()
	end
	local oldSlot = plot:FindFirstChild("MachineSlot")
	if oldSlot then
		oldSlot.Transparency = 1
		local att = oldSlot:FindFirstChild("PromptAtt")
		if att then
			att:Destroy()
		end
		for _, c in ipairs(oldSlot:GetChildren()) do
			if c:IsA("SurfaceGui") then
				c.Enabled = false
			end
		end
	end
	local promptPlaced = false
	for n = 2, 4 do
		local slot = plot:FindFirstChild("MachineSlot" .. n)
		if slot then
			local owned = slot:GetAttribute("Owned") == true and (slot:GetAttribute("Stage") or 1) >= 2
			local name = "Machine" .. n
			local m = plot:FindFirstChild(name)
			local att = slot:FindFirstChild("PromptAtt")
			if owned then
				if att then
					att:Destroy()
				end
				if not m and BUILDERS[n] then
					m = buildMachine(plot, name, n, slotTop(slot), slot.Name)
					if m then
						if animate then
							popIn(m)
						end
						m.Parent = plot
					end
				end
			else
				if m then
					m:Destroy()
				end
				-- 아직 안 산 첫 자리: 바닥 판은 안 보이고 "기계 보기" 안내만 (다음 기계 사기 화면)
				if not promptPlaced then
					promptPlaced = true
					if not att then
						addPrompt(slot, "기계 자리", "기계 보기")
					end
				elseif att then
					att:Destroy()
				end
			end
		end
	end
end

-- 부지 하나의 기계 모습을 맞춤
function Display.sync(plot, animate)
	if hasStack(plot) then
		syncStack(plot, animate)
	else
		syncLegacy(plot)
	end
end

function Display.init()
	machineLayout = findMachineLayout()
	if machineLayout then
		print("[Machine] 편집 화면에서 고친 기계(MachineLayout)를 씀")
	end
	task.spawn(function()
		local folder = workspace:WaitForChild("ShopPlots", 60)
		if not folder then
			return
		end
		local function hook(plot)
			local slot = plot:WaitForChild("MachineSlot2", 10) or plot:FindFirstChild("MachineSlot")
			if not slot then
				return
			end
			Display.sync(plot, false)
			local function watch(s)
				for _, a in ipairs({ "Stage", "Owned" }) do
					s:GetAttributeChangedSignal(a):Connect(function()
						Display.sync(plot, true)
					end)
				end
			end
			if hasStack(plot) then
				for n = 2, 4 do
					local s = plot:FindFirstChild("MachineSlot" .. n)
					if s then
						watch(s)
					end
				end
			else
				watch(slot)
			end
		end
		for _, p in ipairs(folder:GetChildren()) do
			task.spawn(hook, p)
		end
		folder.ChildAdded:Connect(function(p)
			task.spawn(hook, p)
		end)
	end)
end

return Display
