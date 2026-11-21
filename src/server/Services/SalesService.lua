-- 판매: 진열대 + 손님 NPC (Phase 3, 2026-11-20)
--  - 부지마다 진열대 10칸. 보관함(저장 데이터 stock) 앞쪽 10개가 진열되고, 먼저 만든 것부터 팔린다 (FIFO).
--  - 주인이 접속해 있고 진열대에 달고나가 있으면 손님이 골목에서 걸어와(웨이포인트) 사 간다. 가게당 동시 3명.
--  - 방문 간격·1명당 개수는 설비 단계(machineStage)와 1단계 국자 수로 정해진다 (D12, GrowthConfig.salesDemand).
--  - 중복 판매 방지: 손님이 나타날 때 살 개수를 "예약"하고(예약 합 ≤ 진열 개수), 진열대에 닿으면
--    EconomyService.sell이 한 번에 꺼내고 지운다. 그 사이 yield가 없어서 같은 달고나가 두 번 팔리지 않는다.
-- 손님은 Humanoid 없이 부품으로 만든 작은 인형(서버가 위치를 옮김) — 폰 부담을 줄이려고.
-- 2026-11-21 사용자: 진열대에는 내가 만든 완성품 모양 그대로 (Shared.DalgonaLook, 없으면 원판),
--   손님은 산 달고나를 손에 들고 입에 가져다 대며 먹으면서 걸어감.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local ShapeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShapeCatalog"))
local SALES = G.Sales

local SalesService = {}

local Data, Economy, Plots = nil, nil, nil
local shops = {} -- [plotIndex] = { shelf, slots = {}, customers = {}, reserved, nextVisit, owner }
local walkers = {} -- 움직이는 손님 { model, path, seg, t, onArrive }

local DALGONA = Color3.fromRGB(214, 150, 70)
local GRADE_RIM = {
	Perfect = Color3.fromRGB(255, 205, 40),
	Excellent = Color3.fromRGB(120, 200, 90),
	Good = Color3.fromRGB(80, 160, 230),
	Normal = Color3.fromRGB(170, 170, 170),
	Poor = Color3.fromRGB(190, 120, 70),
	Fail = Color3.fromRGB(120, 90, 70),
	Burnt = Color3.fromRGB(50, 34, 26),
}
local SHIRTS = {
	Color3.fromRGB(255, 150, 160), Color3.fromRGB(140, 200, 255), Color3.fromRGB(255, 210, 110),
	Color3.fromRGB(160, 220, 150), Color3.fromRGB(200, 160, 240), Color3.fromRGB(255, 180, 120),
}
local SKINS = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(235, 190, 150), Color3.fromRGB(190, 140, 100) }
local LINES = { "맛있겠다!", "이거 주세요!", "달고나다~", "하나 더!", "냄새 좋다" }

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------- 완성품 모양 (Shared.DalgonaLook)
-- DalgonaLook.build(item, size) → Model. 피벗 = 원판 가운데, 넓은 면 = 로컬 +Y, 막대 = 로컬 +Z, size = 지름
-- 모듈이 없거나 실패하면 원판(+ 등급 테두리)으로 대신함

local lookMod = nil -- nil 아직 안 찾음, false 없음

local function dalgonaLook()
	if lookMod == nil then
		local m = ReplicatedStorage.Shared:FindFirstChild("DalgonaLook")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		lookMod = (ok and type(mod) == "table" and mod.build) and mod or false
	end
	return lookMod or nil
end

local function settle(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	return model
end

local function buildLook(item, size)
	local L = dalgonaLook()
	if L then
		local ok, model = pcall(L.build, item, size)
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			if not model.PrimaryPart then
				model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
			end
			model.Name = "DalgonaLook"
			return settle(model)
		end
		warn("[Sales] DalgonaLook.build failed", model)
	end
	-- 대신: 원판 + 등급 테두리 + 막대
	local m = Instance.new("Model")
	m.Name = "DalgonaLook"
	local burnt = item and item.g == "Burnt"
	local disc = part(m, "Disc", Vector3.new(size * 0.12, size, size), CFrame.Angles(0, 0, math.rad(90)), burnt and Color3.fromRGB(60, 40, 28) or DALGONA, nil, { Shape = Enum.PartType.Cylinder })
	part(m, "Rim", Vector3.new(size * 0.08, size * 1.08, size * 1.08), CFrame.Angles(0, 0, math.rad(90)), GRADE_RIM[item and item.g] or GRADE_RIM.Normal, nil, { Shape = Enum.PartType.Cylinder })
	if not (item and item.plain) then
		part(m, "Stick", Vector3.new(size * 0.07, size * 0.07, size * 0.75), CFrame.new(0, 0, size * 0.75), Color3.fromRGB(235, 215, 170))
	end
	m.PrimaryPart = disc
	disc.PivotOffset = disc.CFrame:Inverse() -- 피벗 = 원판 가운데, 돌리지 않은 방향 (넓은 면 +Y)
	return settle(m)
end

local function lookKey(item)
	return table.concat({ tostring(item.id), tostring(item.s), tostring(item.g), tostring(item.pk), tostring(item.plain), tostring(item.br) }, "|")
end

---------------------------------------------------------------- 진열대

local function slotCFrame(shop, i)
	-- 2줄 × 5칸, 앞줄(골목 쪽)부터 채움. 앞줄 = 먼저 팔리는 것
	local row = (i - 1) // 5 -- 0 앞줄, 1 뒷줄
	local col = (i - 1) % 5
	local w = SALES.shelf.size.X
	local x = -w / 2 + w / 10 + col * (w / 5)
	local z = row == 0 and -0.5 or 0.5
	return shop.top * CFrame.new(x, 0.12 + row * 0.35, z)
end

local function buildShelf(shop, plot)
	local cf = plot.cframe * CFrame.new(SALES.shelf.pos)
	local size = SALES.shelf.size
	local m = Instance.new("Model")
	m.Name = "DisplayShelf"
	local wood = Color3.fromRGB(176, 124, 80)
	local body = part(m, "Body", Vector3.new(size.X, size.Y - 0.3, size.Z), cf * CFrame.new(0, (size.Y - 0.3) / 2 + G.Plots.size.Y, 0), wood, Enum.Material.WoodPlanks, { CanCollide = true, CanQuery = true })
	-- 계단처럼 뒷줄이 조금 높은 판
	local topY = G.Plots.size.Y + size.Y - 0.3
	part(m, "TopFront", Vector3.new(size.X, 0.15, size.Z / 2), cf * CFrame.new(0, topY + 0.075, -size.Z / 4), Color3.fromRGB(250, 240, 225))
	part(m, "TopBack", Vector3.new(size.X, 0.5, size.Z / 2), cf * CFrame.new(0, topY + 0.25, size.Z / 4), Color3.fromRGB(240, 226, 205))
	shop.top = cf * CFrame.new(0, topY + 0.15, 0)
	-- 앞면 글씨 "진열대 n/10"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.45)
	label.Position = UDim2.fromScale(0, 0.1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 246, 225)
	label.TextStrokeTransparency = 0.5
	label.Text = "진열대 0/" .. SALES.shelfSlots
	label.Parent = gui
	gui.Parent = body
	shop.label = label
	-- 진열 칸 (비어 있으면 숨김)
	for i = 1, SALES.shelfSlots do
		local d = part(m, "Slot" .. i, Vector3.new(0.18, 1.3, 1.3), slotCFrame(shop, i) * CFrame.new(0, 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), DALGONA, Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 1,
		})
		local rim = part(m, "Rim" .. i, Vector3.new(0.1, 1.42, 1.42), d.CFrame * CFrame.new(-0.05, 0, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 1,
		})
		-- 진열대에 직접 놓기 (2026-11-21): 빈 칸을 누르면 들고 있는 달고나(없으면 보관함 것)를 그 칸에 놓음.
		-- 클라이언트 ShelfClient가 내 가게 칸만 보이게 함
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PlacePrompt"
		prompt.ActionText = "여기에 놓기"
		prompt.ObjectText = "진열대 " .. i .. "번"
		prompt.KeyboardKeyCode = Enum.KeyCode.R
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Default
		prompt.Enabled = false
		prompt:SetAttribute("Slot", i)
		prompt.Parent = d
		prompt.Triggered:Connect(function(player)
			if shop.owner ~= player then
				return
			end
			local ok, msg = Economy.place(player, i)
			Economy.notify(player, msg)
		end)
		shop.slots[i] = { disc = d, rim = rim, prompt = prompt }
	end
	m.Parent = plot.model
	shop.shelf = m
end

local function refreshShelf(index)
	local shop = shops[index]
	if not shop or not shop.shelf then
		return
	end
	local data = shop.owner and Data.get(shop.owner)
	local stock = data and data.stock or {}
	local slots = data and G.shelfSlots(data) or G.Shop.stallSlots
	-- 칸마다 놓인 달고나 (item.sl)
	local bySlot = {}
	local n = 0
	for _, it in ipairs(stock) do
		if it.sl and it.sl <= slots and not bySlot[it.sl] then
			bySlot[it.sl] = it
			n += 1
		end
	end
	for i, s in ipairs(shop.slots) do
		local item = bySlot[i]
		-- 빈 칸(열린 칸 안)에만 "여기에 놓기"
		local open = shop.owner ~= nil and i <= slots and item == nil
		s.prompt:SetAttribute("Open", open) -- 클라이언트 ShelfClient가 이 값 + 내 가게 + 놓을 것으로 거름
		s.prompt.Enabled = open
		if item then
			s.disc.Transparency = 0
			s.rim.Transparency = 0
			s.rim.Color = GRADE_RIM[item.g] or GRADE_RIM.Normal
			s.disc.Color = (item.g == "Burnt") and Color3.fromRGB(60, 40, 28) or DALGONA
			local shape = ShapeCatalog.get(item.s)
			s.disc:SetAttribute("Shape", shape and shape.name or item.s)
			-- 완성품 모양으로 진열: 원판·테두리는 숨기고(칸 안내 자리로만 씀) 모양 모델을 눕혀 둠
			local key = lookKey(item)
			if s.lookKey ~= key then
				if s.look then
					s.look:Destroy()
				end
				local look = buildLook(item, SALES.lookSize)
				-- 넓은 면이 골목 쪽으로 조금 기울고, 막대는 뒤로
				look:PivotTo(slotCFrame(shop, i) * CFrame.new(0, 0.12, 0) * CFrame.Angles(math.rad(-SALES.lookTilt), 0, 0))
				look.Name = "Look" .. i
				look.Parent = shop.shelf
				s.look, s.lookKey = look, key
			end
			s.disc.Transparency = 1
			s.rim.Transparency = 1
		else
			s.disc.Transparency = 1
			s.rim.Transparency = 1
			if s.look then
				s.look:Destroy()
				s.look, s.lookKey = nil, nil
			end
		end
	end
	shop.label.Text = string.format(slots < SALES.shelfSlots and "쟁반 %d/%d" or "진열대 %d/%d", n, slots) -- 노점은 쟁반 5칸 (D21)
end

---------------------------------------------------------------- 들고 있는 달고나 (속성 Carrying, 2026-11-21)

local function updateCarried(player)
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local old = char and char:FindFirstChild("CarriedDalgona")
	local id = player:GetAttribute("Carrying") or 0
	if id == 0 or not hand then
		if old then
			old:Destroy()
		end
		return
	end
	local data = Data.get(player)
	local item = nil
	for _, it in ipairs(data and data.stock or {}) do
		if it.id == id then
			item = it
		end
	end
	if old then
		old:Destroy()
	end
	local d = Instance.new("Part")
	d.Name = "CarriedDalgona"
	d.Shape = Enum.PartType.Cylinder
	d.Size = Vector3.new(0.16, 1.2, 1.2)
	d.Color = (item and item.g == "Burnt") and Color3.fromRGB(60, 40, 28) or DALGONA
	d.Material = Enum.Material.SmoothPlastic
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.Massless = true
	-- 손 앞에 세워 듦 (원판 면이 앞을 봄)
	d.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.7) * CFrame.Angles(0, math.rad(90), 0)
	if item and item.pk then
		local bag = Instance.new("SelectionBox") -- 포장한 것은 비닐 느낌 테두리
		bag.Adornee = d
		bag.Color3 = Color3.fromRGB(240, 245, 255)
		bag.LineThickness = 0.03
		bag.Transparency = 0.4
		bag.Parent = d
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = d
	w.Parent = d
	d.Parent = char
end

local function watchCarry(player)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		updateCarried(player)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("RightHand", 5)
		updateCarried(player)
	end)
end

---------------------------------------------------------------- 손님

local function buildCustomer(cf)
	local m = Instance.new("Model")
	m.Name = "Customer"
	local shirt = SHIRTS[math.random(#SHIRTS)]
	local skin = SKINS[math.random(#SKINS)]
	local root = part(m, "Root", Vector3.new(1, 1, 1), cf, Color3.new(), nil, { Transparency = 1 })
	m.PrimaryPart = root
	local function at(name, size, offset, color, shape)
		return part(m, name, size, cf * offset, color, Enum.Material.SmoothPlastic, shape and { Shape = shape } or nil)
	end
	at("LegL", Vector3.new(0.45, 1.1, 0.5), CFrame.new(-0.28, 0.55, 0), Color3.fromRGB(70, 80, 110))
	at("LegR", Vector3.new(0.45, 1.1, 0.5), CFrame.new(0.28, 0.55, 0), Color3.fromRGB(70, 80, 110))
	at("Body", Vector3.new(1.3, 1.3, 0.8), CFrame.new(0, 1.75, 0), shirt)
	at("ArmL", Vector3.new(0.36, 1.1, 0.4), CFrame.new(-0.84, 1.8, 0), shirt)
	at("ArmR", Vector3.new(0.36, 1.1, 0.4), CFrame.new(0.84, 1.8, 0), shirt)
	local head = at("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 3.05, 0), skin, Enum.PartType.Ball)
	at("Hair", Vector3.new(1.36, 0.6, 1.36), CFrame.new(0, 3.5, 0.08), Color3.fromRGB(60, 40, 30), Enum.PartType.Ball)
	at("EyeL", Vector3.new(0.14, 0.2, 0.06), CFrame.new(-0.24, 3.12, -0.63), Color3.fromRGB(30, 25, 25))
	at("EyeR", Vector3.new(0.14, 0.2, 0.06), CFrame.new(0.24, 3.12, -0.63), Color3.fromRGB(30, 25, 25))
	-- 말풍선
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(150, 40)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 80
	bb.Enabled = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
	t.TextColor3 = Color3.fromRGB(92, 58, 36)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.4, 0)
	c.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = t
	t.Parent = bb
	bb.Parent = head
	return m
end

local function say(model, text, seconds)
	local head = model:FindFirstChild("Head")
	local bb = head and head:FindFirstChild("Bubble")
	if not bb then
		return
	end
	bb.TextLabel.Text = text
	bb.Enabled = true
	task.delay(seconds or 2, function()
		if bb.Parent and bb.TextLabel.Text == text then
			bb.Enabled = false
		end
	end)
end

-- 웨이포인트를 따라 걷기 (Heartbeat에서 옮김). 도착하면 onArrive()
local function walk(model, points, onArrive)
	table.insert(walkers, { model = model, points = points, seg = 1, dist = 0, onArrive = onArrive, t = 0 })
end

local function stepWalkers(dt)
	for i = #walkers, 1, -1 do
		local w = walkers[i]
		if not w.model.Parent then
			table.remove(walkers, i)
			continue
		end
		local a, b = w.points[w.seg], w.points[w.seg + 1]
		local len = (b - a).Magnitude
		w.dist += SALES.walkSpeed * dt
		w.t += dt
		while w.dist >= len and w.seg < #w.points - 1 do
			w.dist -= len
			w.seg += 1
			a, b = w.points[w.seg], w.points[w.seg + 1]
			len = (b - a).Magnitude
		end
		local done = w.dist >= len
		local alpha = len > 0 and math.min(w.dist / len, 1) or 1
		local pos = a:Lerp(b, alpha)
		local bob = done and 0 or math.abs(math.sin(w.t * 9)) * 0.18
		local dir = (b - a)
		local look = dir.Magnitude > 0.01 and CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)) or CFrame.new(pos)
		w.model:PivotTo(look + Vector3.new(0, bob, 0))
		if done then
			table.remove(walkers, i)
			if w.onArrive then
				task.spawn(w.onArrive)
			end
		end
	end
end

---------------------------------------------------------------- 산 달고나 먹으며 가기
-- 손님 모델에 달고나 모양을 넣고, 매 프레임(걷기 다음) 오른팔·달고나를 몸 기준으로 다시 놓음.
-- 한 입 주기: 들고 있다 → 입으로 올림 → 입 앞에서 한 입(조금 작아짐) → 내림. SALES.eat 값

local eaters = {} -- [model] = { look, arm, t, bites, scale }

local function startEating(model, item)
	local arm = model:FindFirstChild("ArmR")
	if not arm or not model.PrimaryPart then
		return
	end
	local look = buildLook(item, SALES.eat.size)
	look.Parent = model
	eaters[model] = { look = look, arm = arm, t = 0, bites = 0, scale = 1 }
end

local function stepEaters(dt)
	local E = SALES.eat
	for model, e in pairs(eaters) do
		if not model.Parent or not e.look.Parent then
			eaters[model] = nil
			continue
		end
		local before = e.t % E.cycle
		e.t += dt
		local ph = e.t % E.cycle
		-- 0 = 손에 듦, 1 = 입 앞. 올림 → 머묾 → 내림 → 쉼
		local up = E.cycle * 0.25
		local stay = E.cycle * 0.2
		local down = E.cycle * 0.2
		local k
		if ph < up then
			k = ph / up
		elseif ph < up + stay then
			k = 1
		elseif ph < up + stay + down then
			k = 1 - (ph - up - stay) / down
		else
			k = 0
		end
		k = k * k * (3 - 2 * k)
		-- 입 앞에 머무는 가운데쯤 한 입
		local biteAt = up + stay * 0.5
		if before < biteAt and ph >= biteAt then
			e.bites += 1
			if e.bites >= E.bites then
				e.look:Destroy()
				eaters[model] = nil
				model.ArmR.CFrame = model.PrimaryPart.CFrame * CFrame.new(0.84, 1.8, 0)
				say(model, E.lastLine, 1.2)
				continue
			end
			e.scale *= E.biteScale
			pcall(function()
				e.look:ScaleTo(e.scale)
			end)
			say(model, E.lines[math.random(#E.lines)], 0.8)
		end
		local root = model.PrimaryPart.CFrame
		local hold, mouth = E.hold, E.mouth
		local p = hold:Lerp(mouth, k)
		-- 원판을 세워 넓은 면이 손님 얼굴 쪽, 막대는 아래 (로컬 +Z → 아래)
		local discCF = root * CFrame.new(p) * CFrame.Angles(math.rad(90), 0, 0)
		e.look:PivotTo(discCF)
		-- 오른팔: 어깨에서 막대 쪽(원판 조금 아래)을 향함
		local shoulder = (root * CFrame.new(0.84, 2.35, 0)).Position
		local hand = discCF.Position - root.UpVector * (E.size * 0.75) -- 막대 쥔 곳
		local dir = hand - shoulder
		if dir.Magnitude > 0.05 then
			local len = e.arm.Size.Y
			local mid = shoulder + dir.Unit * (len / 2)
			e.arm.CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(-90), 0, 0)
		end
	end
end

local function demand(player)
	local data = Data.get(player)
	return G.salesDemandFor(data) -- 노점·문 닫힘이면 국자 1개 수요 (D21)
end

local function interval(player)
	local base = demand(player)
	return base * (1 + (math.random() * 2 - 1) * SALES.jitter)
end

local function local2world(plot, x, z)
	return (plot.cframe * CFrame.new(x, G.Plots.size.Y, z)).Position
end

local function spawnCustomer(index)
	local shop = shops[index]
	local plot = Plots.plotAt(index)
	local owner = shop.owner
	local available = Economy.shelfCount(owner) - shop.reserved
	if available <= 0 then
		return
	end
	local _, buyMin, buyMax = demand(owner)
	local want = math.random(buyMin, buyMax)
	local n = math.min(want, available)
	shop.reserved += n
	local sx = SALES.shelf.pos.X
	local side = math.random() < 0.5 and -1 or 1
	local startP = local2world(plot, side * SALES.streetHalf, SALES.streetZ)
	local doorP = local2world(plot, sx, SALES.streetZ)
	local standP = local2world(plot, sx + (math.random() - 0.5) * 3, SALES.standZ)
	local exitP = local2world(plot, -side * SALES.streetHalf, SALES.streetZ)
	local model = buildCustomer(CFrame.new(startP))
	model.Parent = shop.folder
	local c = { model = model, reserved = n }
	shop.customers[c] = true

	local function leave()
		walk(model, { standP, doorP, exitP }, function()
			model:Destroy()
			shop.customers[c] = nil
		end)
	end
	walk(model, { startP, doorP, standP }, function()
		-- 진열대를 보며 고름
		local shelfP = local2world(plot, sx, SALES.shelf.pos.Z)
		model:PivotTo(CFrame.lookAt(standP, Vector3.new(shelfP.X, standP.Y, shelfP.Z)))
		say(model, LINES[math.random(#LINES)], SALES.browseSeconds + 0.4)
		task.wait(SALES.browseSeconds)
		if not model.Parent then
			return
		end
		-- 예약을 풀고 한 번에 꺼내 판다 (그 사이 yield 없음)
		shop.reserved = math.max(0, shop.reserved - c.reserved)
		local reservedN = c.reserved
		c.reserved = 0
		local sold, coins, items = 0, 0, nil
		if shop.owner == owner and owner.Parent then
			sold, coins, items = Economy.sell(owner, reservedN)
		end
		if sold > 0 then
			say(model, string.format("%d개 살게요! +%d", sold, coins), 2)
			startEating(model, items and items[1] or nil)
			Economy.notify(owner, string.format("손님이 달고나 %d개를 샀어요 (+%d 코인)", sold, coins))
			print(string.format("[Sales] %s Plot%d sold %d (+%d)", owner.Name, index, sold, coins))
		else
			say(model, "다 팔렸네...", 2)
		end
		task.wait(0.6)
		if model.Parent then
			leave()
		end
	end)
end

local function clearShop(index)
	local shop = shops[index]
	if not shop then
		return
	end
	for c in pairs(shop.customers) do
		c.model:Destroy()
	end
	shop.customers = {}
	shop.reserved = 0
	shop.owner = nil
	refreshShelf(index)
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function SalesService.init(dataService, economyService, plotService)
	Data, Economy, Plots = dataService, economyService, plotService
	for i = 1, G.Plots.count do
		local plot = Plots.plotAt(i)
		local shop = { slots = {}, customers = {}, reserved = 0, nextVisit = 0, owner = nil }
		shops[i] = shop
		buildShelf(shop, plot)
		local folder = Instance.new("Folder")
		folder.Name = "Customers"
		folder.Parent = plot.model
		shop.folder = folder
	end

	Players.PlayerAdded:Connect(watchCarry)
	for _, p in ipairs(Players:GetPlayers()) do
		watchCarry(p)
	end

	-- 데이터가 바뀌면 그 플레이어 가게의 진열대를 다시 그림
	Data.Changed:Connect(function(player)
		local _, index = Plots.get(player)
		if index then
			shops[index].owner = player
			refreshShelf(index)
		end
		if (player:GetAttribute("Carrying") or 0) ~= 0 then
			updateCarried(player) -- 포장하면 들고 있는 모습도 바뀜
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for i, shop in pairs(shops) do
			if shop.owner == player then
				clearShop(i)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepWalkers(dt)
		stepEaters(dt) -- 걷기로 몸을 옮긴 다음 팔·달고나를 다시 놓음
	end)

	-- 손님 보내기
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for i, shop in pairs(shops) do
				local plot = Plots.plotAt(i)
				local owner = plot.owner
				if owner ~= shop.owner then
					clearShop(i)
					shop.owner = owner
					shop.nextVisit = now + 2
					if owner then
						refreshShelf(i)
					end
				end
				if owner and owner.Parent and Data.get(owner) and now >= shop.nextVisit then
					shop.nextVisit = now + interval(owner)
					if count(shop.customers) < SALES.maxCustomers then
						spawnCustomer(i)
					end
				end
			end
		end
	end)
end

return SalesService
