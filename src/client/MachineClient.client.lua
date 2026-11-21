-- 가게 기계 (20번 기계 2~4단계, 2026-11-21): 움직임 · 멈춤 표시 · 배출 · 진열 연출 · 도안 고르기/다음 기계 사기 화면
-- 서버 연결 규칙 (저장·부지 세션과 정함):
--   부지 모델 Plot<n>.MachineSlot 속성: Stage, MachineId, Running, Status("work" 또는 멈춘 이유), Shape,
--     CycleStart·CycleSeconds(서버 시각 workspace:GetServerTimeNow), MadeAt·MadeCount·MadeSlots("3,4,7")
--   모델 Plot<n>.Machine (서버 MachineDisplay): 부품 속성 Anim = spin·press·lampRun·lampStop·outlet·window, 앞 안내 MachinePrompt
--   화면 상태: GetPlayerState / PlayerState 의 growth.machine = { stage, id, name, shape, status, running, t, seconds, batch, next, shapes }
--   조작: Remotes.GrowthAction:InvokeServer("buy", "machine") · ("machineShape", shapeId) → { ok, reason, msg }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local DalgonaLook = require(Shared:WaitForChild("DalgonaLook"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = touch and 0.8 or 1
local CREAM = Color3.fromRGB(255, 247, 232)
local BROWN = Color3.fromRGB(92, 58, 36)
local SOFT = Color3.fromRGB(150, 110, 80)
local CARAMEL = Color3.fromRGB(222, 150, 70)
local GREEN = Color3.fromRGB(110, 190, 90)
local RED = Color3.fromRGB(200, 70, 60)

local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end
local function corner(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function shapeName(id)
	local e = id and ShapeCatalog.get(id)
	return e and e.name or (id or "")
end

-- ── 기계마다 기록 ──
local machines = {} -- [Machine 모델] = rec
local DIST = 140 -- 이 거리 밖 기계는 움직이지 않음 (아낌)

local function setupMachine(plot, m)
	local slot = plot:FindFirstChild("MachineSlot")
	if not slot or machines[m] then
		return
	end
	local rec = { plot = plot, slot = slot, model = m, parts = {}, lastMade = slot:GetAttribute("MadeAt") }
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local a = d:GetAttribute("Anim")
			if a then
				-- 도는 축 = 가장 얇은 축 (톱니·바람개비·팬)
				local s = d.Size
				local axis = (s.X <= s.Y and s.X <= s.Z) and Vector3.xAxis or ((s.Y <= s.Z) and Vector3.yAxis or Vector3.zAxis)
				table.insert(rec.parts, { p = d, a = a, cf = d.CFrame, color = d.Color, mat = d.Material, axis = axis })
			end
		end
	end
	-- 머리 위 상태판: 기계 이름 · 진행 막대 · 멈춘 이유
	local anchor = m.PrimaryPart or m:FindFirstChild("PromptAnchor")
	if anchor then
		local bb = new("BillboardGui", { Name = "MachineStatus", Size = UDim2.fromOffset(190, 52), StudsOffsetWorldSpace = Vector3.new(0, (m:GetAttribute("Height") or 5) - 0.6, 0), MaxDistance = 70, AlwaysOnTop = false, LightInfluence = 0, Parent = anchor })
		local box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = CREAM, BackgroundTransparency = 0.1, Parent = bb })
		corner(box, 10)
		rec.title = new("TextLabel", { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 3), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = BROWN, Text = m:GetAttribute("MachineName") or "기계", Parent = box })
		local barBg = new("Frame", { Size = UDim2.new(1, -16, 0, 8), Position = UDim2.fromOffset(8, 27), BackgroundColor3 = Color3.fromRGB(235, 220, 200), Parent = box })
		corner(barBg, 4)
		rec.bar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, Parent = barBg })
		corner(rec.bar, 4)
		rec.status = new("TextLabel", { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 36), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextScaled = true, TextColor3 = SOFT, Text = "", Parent = box })
	end
	-- 안내(F)는 이 가게 주인에게만
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			rec.prompt = d
		end
	end
	machines[m] = rec
	m.AncestryChanged:Connect(function()
		if not m:IsDescendantOf(workspace) then
			machines[m] = nil
		end
	end)
end

local function isOwner(plot)
	return plot:GetAttribute("OwnerUserId") == player.UserId
end

-- ── 배출 + 진열 연출 (D26: 만든 달고나가 진열대 칸으로 날아가 놓임) ──
local function arcFly(model, from, to, dur, spin)
	local t = 0
	while t < dur do
		t += RunService.Heartbeat:Wait()
		local k = math.min(t / dur, 1)
		local e = k * k * (3 - 2 * k)
		local pos = from:Lerp(to, e) + Vector3.new(0, math.sin(math.pi * k) * 2.2, 0)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, spin * k, 0) * CFrame.Angles(math.rad(90), 0, 0))
	end
end

local function playMade(rec)
	local slot = rec.slot
	local plot = rec.plot
	local shape = slot:GetAttribute("Shape")
	local count = slot:GetAttribute("MadeCount") or 1
	local slotsText = slot:GetAttribute("MadeSlots") or ""
	local outlet
	for _, e in ipairs(rec.parts) do
		if e.a == "outlet" then
			outlet = e.p
		end
	end
	local pivot = rec.model:GetPivot() -- 피벗 = 앞 안내 자리, LookVector = 기계 앞(골목 쪽)
	local start = outlet and outlet.Position or (pivot.Position + Vector3.new(0, 1, 0))
	local out = start + pivot.LookVector * 1.2
	local targets = {}
	local shelf = plot:FindFirstChild("DisplayShelf")
	for n in string.gmatch(slotsText, "%d+") do
		local sp = shelf and shelf:FindFirstChild("Slot" .. n)
		if sp then
			local pos = sp:IsA("BasePart") and sp.Position or (sp:IsA("Model") and sp:GetPivot().Position)
			if pos then
				table.insert(targets, pos + Vector3.new(0, 0.6, 0))
			end
		end
	end
	local shown = math.min(count, 10)
	for i = 1, shown do
		task.spawn(function()
			task.wait((i - 1) * 0.18)
			local look = DalgonaLook.build({ s = shape, g = "Good" }, 0.8)
			look.Parent = workspace
			-- 배출구에서 톡 튀어나옴
			arcFly(look, start, out, 0.35, math.pi)
			local to = targets[i]
			if to then
				task.wait(0.15)
				arcFly(look, out, to, 0.9, math.pi * 2)
			else
				-- 진열대에 빈 칸이 없으면 보관함으로: 살짝 떠올랐다 사라짐
				arcFly(look, out, out + Vector3.new(0, 1.5, 0), 0.5, math.pi)
			end
			for _, p in ipairs(look:GetDescendants()) do
				if p:IsA("BasePart") then
					TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.3)
			look:Destroy()
		end)
	end
end

-- ── 매 프레임: 움직임 · 표시등 · 상태판 ──
local OFF_DIM = 0.45
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for m, rec in pairs(machines) do
		local slot = rec.slot
		local running = slot:GetAttribute("Running") == true
		local status = slot:GetAttribute("Status") or ""
		local stopped = not running and status ~= "" and status ~= "work"
		if rec.prompt then
			rec.prompt.Enabled = isOwner(rec.plot)
		end
		-- 상태판
		if rec.bar then
			local t0 = slot:GetAttribute("CycleStart")
			local dur = slot:GetAttribute("CycleSeconds")
			local k = (running and t0 and dur and dur > 0) and math.clamp((now - t0) / dur, 0, 1) or 0
			rec.bar.Size = UDim2.fromScale(k, 1)
			rec.bar.BackgroundColor3 = stopped and RED or GREEN
			if running then
				local left = (t0 and dur) and math.max(0, math.ceil(dur - (now - t0))) or 0
				rec.status.Text = string.format("%s 만드는 중 · %d초", shapeName(slot:GetAttribute("Shape")), left)
				rec.status.TextColor3 = SOFT
			elseif stopped then
				rec.status.Text = "멈춤 · " .. status
				rec.status.TextColor3 = RED
			else
				rec.status.Text = "쉬는 중"
				rec.status.TextColor3 = SOFT
			end
		end
		-- 다 만든 순간 (MadeAt 바뀜) → 배출·진열 연출
		local made = slot:GetAttribute("MadeAt")
		if made and made ~= rec.lastMade then
			rec.lastMade = made
			if (m:GetPivot().Position - camPos).Magnitude < DIST then
				playMade(rec)
			end
		end
		-- 움직임 (가까울 때만)
		if (m:GetPivot().Position - camPos).Magnitude < DIST then
			local blink = (math.floor(now * 2) % 2) == 0
			for _, e in ipairs(rec.parts) do
				local p = e.p
				if p.Parent then
					if e.a == "spin" then
						if running then
							e.ang = (e.ang or 0) + 0.12
						end
						p.CFrame = e.cf * CFrame.fromAxisAngle(e.axis, e.ang or 0)
					elseif e.a == "press" then
						local y = running and (1 - math.abs(math.sin(now * 2.4))) * 0.35 or 0
						p.CFrame = e.cf - Vector3.new(0, y, 0)
					elseif e.a == "lampRun" then
						p.Material = running and Enum.Material.Neon or Enum.Material.SmoothPlastic
						p.Color = running and e.color or e.color:Lerp(Color3.new(0.2, 0.2, 0.2), OFF_DIM)
					elseif e.a == "lampStop" then
						local on = stopped and blink
						p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
						p.Color = on and e.color or e.color:Lerp(Color3.new(0.2, 0.2, 0.2), OFF_DIM)
					elseif e.a == "window" then
						-- 창 속 달고나: 돌아가는 동안 살짝 흔들림
						local w = running and math.sin(now * 3 + e.cf.Position.X * 2) * 0.06 or 0
						p.CFrame = e.cf * CFrame.Angles(0, 0, w)
					end
				end
			end
		end
	end
end)

-- ── 도안 고르기 · 다음 기계 사기 화면 ──
local state = nil
local gui = new("ScreenGui", { Name = "MachineUi", ResetOnSpawn = false, DisplayOrder = 7, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local uiScale = new("UIScale", { Scale = S, Parent = gui })
-- 작은 화면에서는 창이 화면 안에 들어오게 줄임
local function fit()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	uiScale.Scale = math.min(S, (vp.Y - 80) / 420, (vp.X - 24) / 560)
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end
local win = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(560, 420), BackgroundColor3 = CREAM, Parent = gui })
corner(win, 16)
new("UIStroke", { Color = CARAMEL, Thickness = 3, Parent = win })
local titleL = new("TextLabel", { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -80, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, Text = "기계", Parent = win })
local closeBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromRGB(240, 225, 205), Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = BROWN, Text = "X", Parent = win })
corner(closeBtn, 17)
local statusL = new("TextLabel", { Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -36, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SOFT, Text = "", Parent = win })
local gridTitle = new("TextLabel", { Position = UDim2.fromOffset(18, 70), Size = UDim2.new(1, -36, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, Text = "기계가 만들 도안", Parent = win })
local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(14, 94), Size = UDim2.new(1, -28, 1, -206), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win })
new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 118), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
local nextRow = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 70), BackgroundColor3 = Color3.fromRGB(250, 236, 214), Parent = win })
corner(nextRow, 12)
local nextL = new("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 1, -12), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, Text = "", Parent = nextRow })
local buyBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(126, 44), BackgroundColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Text = "사기", Parent = nextRow })
corner(buyBtn, 12)
local msgL = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -87), Size = UDim2.new(1, -36, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = RED, Text = "", Parent = win })

local function preview(parent, entry)
	local vpf = new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(226, 172, 96), Ambient = Color3.fromRGB(190, 190, 195), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6), Size = UDim2.new(1, -10, 1, -36), Position = UDim2.fromOffset(5, 5), Parent = parent })
	corner(vpf, 8)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Cutters")
	local tpl = folder and folder:FindFirstChild("Cutter_" .. entry.id)
	if tpl then
		local mesh = tpl:Clone()
		for _, c in ipairs(mesh:GetChildren()) do
			c:Destroy()
		end
		mesh.Material = Enum.Material.SmoothPlastic
		mesh.Color = Color3.fromRGB(70, 60, 52)
		local c = entry.data.center
		mesh.CFrame = CFrame.new(c.X, 0, -c.Y) * CFrame.Angles(0, math.pi, 0)
		mesh.Parent = vpf
	end
	local cam = new("Camera", { FieldOfView = 22, Parent = vpf })
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, 0), Vector3.zero, Vector3.new(0, 0, -1))
	vpf.CurrentCamera = cam
end

local render -- 아래에서 정의
local busy = false
local function act(what, a)
	if busy then
		return
	end
	busy = true
	msgL.Text = ""
	local ok, res = pcall(function()
		return Remotes.GrowthAction:InvokeServer(what, a)
	end)
	busy = false
	-- 바뀐 상태를 바로 다시 받아 그림 (갱신 신호를 기다리지 않음)
	task.spawn(function()
		local ok2, st = pcall(function()
			return Remotes.GetPlayerState:InvokeServer()
		end)
		if ok2 and st then
			state = st
			if gui.Enabled then
				render()
			end
		end
	end)
	if not ok then
		msgL.Text = "서버 응답이 없어요"
	elseif type(res) == "table" and not res.ok then
		msgL.Text = tostring(res.msg or res.reason or "할 수 없어요")
	elseif type(res) == "table" and res.msg then
		msgL.TextColor3 = GREEN
		msgL.Text = tostring(res.msg)
		task.delay(2, function()
			msgL.TextColor3 = RED
		end)
	end
end

local cards = {}
function render()
	local mc = state and state.growth and state.growth.machine
	for _, c in ipairs(cards) do
		c:Destroy()
	end
	table.clear(cards)
	if not mc then
		titleL.Text = "기계"
		statusL.Text = "기계 정보를 아직 못 받았어요"
		nextRow.Visible = false
		gridTitle.Visible = false
		return
	end
	local stage = mc.stage or 1
	titleL.Text = stage >= 2 and string.format("%s (%d단계)", mc.name or "기계", stage) or "기계 자리"
	if stage < 2 then
		statusL.Text = "아직 기계가 없어요. 기계를 사면 혼자서 달고나를 만들어 진열해 줘요"
	elseif mc.running then
		statusL.Text = string.format("%s %d개씩 만드는 중 · 한 판 %d초", shapeName(mc.shape), mc.batch or 1, mc.seconds or 0)
	else
		statusL.Text = "멈춤 · " .. tostring(mc.status or "")
	end
	-- 도안 카드 (기계로 만들 수 있는 것만, Legendary까지)
	gridTitle.Visible = stage >= 2
	if stage >= 2 then
		for i, id in ipairs(mc.shapes or {}) do
			local e = ShapeCatalog.get(id)
			if e then
				local g = ShapeCatalog.grade(e.grade)
				local chosen = id == mc.shape
				local card = new("TextButton", { LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, Text = "", Parent = grid })
				corner(card, 10)
				new("UIStroke", { Color = chosen and GREEN or (g and g.color or SOFT), Thickness = chosen and 4 or 2, Parent = card })
				preview(card, e)
				new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -6, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = BROWN, Text = e.name, Parent = card })
				new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -6, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = g and g.color or SOFT, Text = chosen and "만드는 중" or (g and g.label or ""), Parent = card })
				card.Activated:Connect(function()
					if not chosen then
						act("machineShape", id)
					end
				end)
				table.insert(cards, card)
			end
		end
	end
	-- 다음 기계
	local nx = mc.next
	nextRow.Visible = true
	if nx then
		nextL.Text = string.format("다음 기계: %s\nLv%d부터 · %s 코인", nx.name or "", nx.level or 0, tostring(nx.price or 0))
		buyBtn.Visible = true
	else
		nextL.Text = "가게 기계는 마지막 단계예요 (다음은 공장)"
		buyBtn.Visible = false
	end
end

buyBtn.Activated:Connect(function()
	act("buy", "machine")
end)
closeBtn.Activated:Connect(function()
	gui.Enabled = false
end)

local function open()
	gui.Enabled = true
	msgL.Text = ""
	render()
	task.spawn(function()
		local ok, s = pcall(function()
			return Remotes:WaitForChild("GetPlayerState"):InvokeServer()
		end)
		if ok and s then
			state = s
			if gui.Enabled then
				render()
			end
		end
	end)
end

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(s)
	state = s
	if gui.Enabled then
		render()
	end
end)

-- 안내(F): 기계 앞 · 빈 기계 자리 → 내 가게일 때만 화면 열기
local function hookPrompt(plot, pr)
	if pr:GetAttribute("Hooked") then
		return
	end
	pr:SetAttribute("Hooked", true)
	pr.Triggered:Connect(function()
		if isOwner(plot) then
			open()
		end
	end)
end

local function watchPlot(plot)
	local function scan()
		local m = plot:FindFirstChild("Machine")
		if m then
			setupMachine(plot, m)
		end
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Name == "MachinePrompt" then
				d.Enabled = isOwner(plot)
				hookPrompt(plot, d)
			end
		end
	end
	scan()
	plot.DescendantAdded:Connect(function(d)
		if d.Name == "Machine" or (d:IsA("ProximityPrompt") and d.Name == "MachinePrompt") then
			task.defer(scan)
		end
	end)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(scan)
end

task.spawn(function()
	local folder = workspace:WaitForChild("ShopPlots")
	for _, p in ipairs(folder:GetChildren()) do
		watchPlot(p)
	end
	folder.ChildAdded:Connect(watchPlot)
end)
