-- 5단계 달고나 공장 (2026-11-21): 생산 연출 · 상태판 · 배출 · 제어대 화면 (FACTORY CONTROL)
-- 서버 연결 규칙 (저장·부지 세션 FactoryService와 정함):
--   workspace.Factories.Factory<i> 속성: OwnerUserId, Unlocked, On, Shape, Qty, Mode, Lines, Status("work"|"off"|멈춘 이유),
--     Line<k>Start(서버 시각, 쉬면 0)·Line<k>Seconds·Line<k>Count·Line<k>Shape, MadeAt·MadeCount·MadeSlots
--   건물 ShopPlots.Plot<i>.FactoryLot.Building (서버 FactoryDisplay, 2026-11-22 D11: 가게 건물 뒤에 붙음): 부품 속성 Anim, 제어대 안내 "ControlPrompt"
--   화면 상태: growth.factory = { unlocked, on, shape, qty, maxQty, mode, lines, status, jobs, ups, upgrades, shapes, preview }
--   조작: GrowthAction("factorySet", { shape, qty, mode }) · ("factoryRun", bool) · ("factoryUp", key) → { ok, reason, msg }

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
local PANEL = Color3.fromRGB(250, 236, 214)
local BROWN = Color3.fromRGB(92, 58, 36)
local SOFT = Color3.fromRGB(150, 110, 80)
local CARAMEL = Color3.fromRGB(222, 150, 70)
local GREEN = Color3.fromRGB(110, 190, 90)
local RED = Color3.fromRGB(200, 70, 60)
local MINT = Color3.fromRGB(120, 200, 190)

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
local MODE_NAME = { normal = "일반", precise = "정밀", fast = "고속" }

local function lineActive(fac, k)
	local t0 = fac:GetAttribute("Line" .. k .. "Start")
	return type(t0) == "number" and t0 > 0
end

-- ── 공장 건물마다 기록 ──
local factories = {} -- [Factory<i>] = rec

-- force: 공장은 맵 밖 먼 곳이라 부품이 스트리밍으로 나중에 들어옴 → 들어올 때마다 다시 훑음
-- 공장 3D는 가게 뒤 공장 부지 안 (Factory<i> → Plot<i>.FactoryLot)
local function lotOf(fac)
	local i = tonumber(fac.Name:match("%d+"))
	local plots = workspace:FindFirstChild("ShopPlots")
	local plot = plots and i and plots:FindFirstChild("Plot" .. i)
	return plot and plot:FindFirstChild("FactoryLot"), plot
end

local function setup(fac, force)
	local lot = lotOf(fac)
	local b = lot and lot:FindFirstChild("Building")
	local old = factories[fac]
	if not b or (old and old.building == b and not force) then
		return
	end
	if old and old.board then
		old.board:Destroy()
	end
	local rec = { fac = fac, building = b, parts = {}, lastMade = old and old.lastMade or fac:GetAttribute("MadeAt") }
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then
			local a = d:GetAttribute("Anim")
			if a then
				local s = d.Size
				local axis = (s.X <= s.Y and s.X <= s.Z) and Vector3.xAxis or ((s.Y <= s.Z) and Vector3.yAxis or Vector3.zAxis)
				-- 처음 자리·색은 부품에 기억 (다시 훑을 때 움직이는 중인 자리를 기준으로 잡지 않게)
				if d:GetAttribute("AnimBase") == nil then
					d:SetAttribute("AnimBase", d.CFrame)
					d:SetAttribute("AnimColor", d.Color)
				end
				table.insert(rec.parts, { p = d, a = a, cf = d:GetAttribute("AnimBase"), color = d:GetAttribute("AnimColor"), axis = axis, phase = (#rec.parts) * 0.7 })
			end
		end
		if d:IsA("ProximityPrompt") and d.Name == "ControlPrompt" then
			rec.prompt = d
		end
	end
	-- 제어대 위 상태판: FACTORY · 상태 · 라인별 진행
	local console = rec.prompt and rec.prompt.Parent
	if console then
		local bb = new("BillboardGui", { Name = "FactoryStatus", Size = UDim2.fromOffset(230, 78), StudsOffset = Vector3.new(0, 4.2, 0), MaxDistance = 90, LightInfluence = 0, Parent = console })
		rec.board = bb
		local box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 44, 60), BackgroundTransparency = 0.1, Parent = bb })
		corner(box, 10)
		rec.head = new("TextLabel", { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = MINT, TextXAlignment = Enum.TextXAlignment.Left, Text = "FACTORY", Parent = box })
		rec.bars, rec.barText = {}, {}
		for k = 1, 2 do
			local y = 26 + (k - 1) * 24
			local bg = new("Frame", { Position = UDim2.fromOffset(8, y + 14), Size = UDim2.new(1, -16, 0, 6), BackgroundColor3 = Color3.fromRGB(70, 74, 92), Parent = box })
			corner(bg, 3)
			rec.bars[k] = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, Parent = bg })
			corner(rec.bars[k], 3)
			rec.barText[k] = new("TextLabel", { Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextScaled = true, TextColor3 = Color3.fromRGB(220, 225, 235), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = box })
			rec.bars[k].Parent.Visible = false
		end
	end
	factories[fac] = rec
end

-- ── 배출: 다 만든 달고나가 슈트에서 나와 상자 쪽으로 굴러 감 + "+N" 표시 ──
local function playMade(rec)
	local fac = rec.fac
	local outlet
	for _, e in ipairs(rec.parts) do
		if e.a == "outlet" then
			outlet = e.p
		end
	end
	if not outlet then
		return
	end
	local count = fac:GetAttribute("MadeCount") or 1
	local slots = 0
	for _ in string.gmatch(fac:GetAttribute("MadeSlots") or "", "%d+") do
		slots += 1
	end
	local shape = fac:GetAttribute("Line1Shape") or fac:GetAttribute("Shape")
	local start = outlet.Position + Vector3.new(0, 0.8, 0)
	for i = 1, math.min(count, 8) do
		task.spawn(function()
			task.wait((i - 1) * 0.15)
			local look = DalgonaLook.build({ s = shape, g = "Good" }, 0.9)
			look.Parent = workspace
			local to = start + Vector3.new(-1.5 - math.random() * 1.5, -1.6, (math.random() - 0.5) * 2)
			local t, dur = 0, 0.6
			while t < dur do
				t += RunService.Heartbeat:Wait()
				local k = math.min(t / dur, 1)
				look:PivotTo(CFrame.new(start:Lerp(to, k) + Vector3.new(0, math.sin(math.pi * k) * 1.2, 0)) * CFrame.Angles(k * 6, 0, 0))
			end
			task.wait(0.4)
			look:Destroy()
		end)
	end
	-- 떠오르는 글씨: 진열 n · 보관함 m
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(220, 40), StudsOffset = Vector3.new(0, 2, 0), AlwaysOnTop = true, LightInfluence = 0, Parent = outlet })
	local t = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(255, 240, 160), TextStrokeTransparency = 0.3, Text = string.format("+%d개 (진열 %d · 보관함 %d)", count, slots, math.max(0, count - slots)), Parent = bb })
	TweenService:Create(bb, TweenInfo.new(1.8), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.9, function()
		bb:Destroy()
	end)
end

-- ── 매 프레임: 움직임 · 표시등 · 상태판 ──
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for fac, rec in pairs(factories) do
		if not rec.building.Parent then
			factories[fac] = nil
			continue
		end
		local status = fac:GetAttribute("Status") or "off"
		local running = lineActive(fac, 1) or lineActive(fac, 2)
		local stopped = status ~= "work" and status ~= "off"
		if rec.prompt then
			rec.prompt.Enabled = fac:GetAttribute("OwnerUserId") == player.UserId
		end
		local made = fac:GetAttribute("MadeAt")
		if made and made ~= rec.lastMade then
			rec.lastMade = made
			if (rec.building:GetPivot().Position - camPos).Magnitude < 160 then
				playMade(rec)
			end
		end
		if (rec.building:GetPivot().Position - camPos).Magnitude > 160 then
			continue
		end
		-- 상태판
		if rec.head then
			if stopped then
				rec.head.Text = "FACTORY · 멈춤: " .. status
				rec.head.TextColor3 = Color3.fromRGB(255, 130, 120)
			elseif running then
				rec.head.Text = "FACTORY · ONLINE · " .. (MODE_NAME[fac:GetAttribute("Mode")] or "일반")
				rec.head.TextColor3 = MINT
			else
				rec.head.Text = "FACTORY · 꺼짐"
				rec.head.TextColor3 = Color3.fromRGB(200, 200, 210)
			end
			local lines = fac:GetAttribute("Lines") or 1
			for k = 1, 2 do
				local show = k <= lines
				rec.bars[k].Parent.Visible = show
				rec.barText[k].Visible = show
				if show then
					local t0 = fac:GetAttribute("Line" .. k .. "Start") or 0
					local dur = fac:GetAttribute("Line" .. k .. "Seconds") or 0
					if t0 > 0 and dur > 0 then
						local f = math.clamp((now - t0) / dur, 0, 1)
						rec.bars[k].Size = UDim2.fromScale(f, 1)
						rec.barText[k].Text = string.format("라인 %d · %s %d개 · %d초 남음", k, shapeName(fac:GetAttribute("Line" .. k .. "Shape")), fac:GetAttribute("Line" .. k .. "Count") or 0, math.max(0, math.ceil(dur - (now - t0))))
					else
						rec.bars[k].Size = UDim2.fromScale(0, 1)
						rec.barText[k].Text = string.format("라인 %d · 쉬는 중", k)
					end
				end
			end
		end
		-- 움직임
		local blink = (math.floor(now * 2) % 2) == 0
		for _, e in ipairs(rec.parts) do
			local p = e.p
			if p.Parent then
				local a = e.a
				if a == "press" then
					local y = running and (1 - math.abs(math.sin(now * 2.2))) * 0.9 or 0
					p.CFrame = e.cf - Vector3.new(0, y, 0)
				elseif a == "spin" then
					if running then
						e.ang = (e.ang or 0) + 0.15
					end
					p.CFrame = e.cf * CFrame.fromAxisAngle(e.axis, e.ang or 0)
				elseif a == "belt" then
					-- 컨베이어 위 달고나: 반죽 붓는 곳 → 찍는 기계 → 슈트 쪽으로 흘러가고 되풀이 (모델 기준 -X 방향)
					local off = running and ((now * 1.6 + e.phase) % 6) - 3 or 0
					p.CFrame = e.cf * CFrame.new(-off, 0, 0)
				elseif a == "hopper" then
					local y = running and math.sin(now * 3 + e.phase) * 0.12 or 0
					p.CFrame = e.cf + Vector3.new(0, y, 0)
				elseif a == "kettle" then
					local r = running and math.sin(now * 9 + e.phase) * 0.02 or 0
					p.CFrame = e.cf * CFrame.Angles(r, 0, r)
				elseif a == "lampRun" then
					p.Material = running and Enum.Material.Neon or Enum.Material.SmoothPlastic
					p.Color = running and e.color or e.color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.5)
				elseif a == "lampStop" then
					local on = stopped and blink
					p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
					p.Color = on and e.color or e.color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.5)
				elseif a == "lampIdle" then
					local on = not running and not stopped
					p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
					p.Color = on and e.color or e.color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.5)
				end
			end
		end
	end
end)

-- ── 제어대 화면 (FACTORY CONTROL) ──
local state = nil
local gui = new("ScreenGui", { Name = "FactoryUi", ResetOnSpawn = false, DisplayOrder = 7, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local uiScale = new("UIScale", { Scale = S, Parent = gui })
local W, H = 640, 470
local function fit()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	uiScale.Scale = math.min(S, (vp.Y - 80) / H, (vp.X - 24) / W)
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end
local win = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(W, H), BackgroundColor3 = CREAM, Parent = gui })
corner(win, 16)
new("UIStroke", { Color = CARAMEL, Thickness = 3, Parent = win })
local header = new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Color3.fromRGB(40, 44, 60), Parent = win })
corner(header, 16)
new("TextLabel", { Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0, 260, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MINT, Text = "FACTORY CONTROL", Parent = header })
local chip = new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0), Size = UDim2.fromOffset(200, 28), BackgroundColor3 = Color3.fromRGB(60, 66, 86), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = MINT, Text = "", Parent = header })
corner(chip, 14)
local closeBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromRGB(240, 225, 205), Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = BROWN, Text = "X", Parent = header })
corner(closeBtn, 17)
-- 탭
local tabs = {}
local pages = {}
local function tabButton(i, text)
	local b = new("TextButton", { Position = UDim2.fromOffset(14 + (i - 1) * 118, 56), Size = UDim2.fromOffset(110, 30), BackgroundColor3 = PANEL, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = BROWN, Text = text, Parent = win })
	corner(b, 10)
	tabs[i] = b
	pages[i] = new("Frame", { Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 1, -128), BackgroundTransparency = 1, Visible = i == 1, Parent = win })
	return b
end
tabButton(1, "생산")
tabButton(2, "업그레이드")
local msgL = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -36, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = RED, Text = "", Parent = win })

-- 생산 탭: 왼쪽 도안 카드, 오른쪽 수량·방식·예상·라인 진행·시작/멈춤
local prod = pages[1]
new("TextLabel", { Size = UDim2.new(0.55, -8, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, Text = "① 생산할 도안", Parent = prod })
local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.55, -8, 1, -22), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = prod })
new("UIGridLayout", { CellSize = UDim2.fromOffset(102, 112), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
local right = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.45, -4, 1, 0), BackgroundColor3 = PANEL, Parent = prod })
corner(right, 12)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), Parent = right })
local function rtext(y, h, size, bold, text)
	return new("TextLabel", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = size, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = BROWN, Text = text or "", Parent = right })
end
rtext(0, 18, 14, true, "② 생산 수량")
local qtyRow = new("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = right })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = qtyRow })
rtext(56, 18, 14, true, "③ 생산 방식")
local modeRow = new("Frame", { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = right })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = modeRow })
local modeDesc = rtext(108, 30, 12, false, "")
modeDesc.TextColor3 = SOFT
local previewL = rtext(140, 48, 13, false, "")
local jobsL = rtext(190, 62, 13, false, "")
local runBtn = new("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = "생산 시작", Parent = right })
corner(runBtn, 12)

-- 업그레이드 탭
local upList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pages[2] })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = upList })

local function selectTab(i)
	for k, p in ipairs(pages) do
		p.Visible = k == i
		tabs[k].BackgroundColor3 = k == i and CARAMEL or PANEL
		tabs[k].TextColor3 = k == i and Color3.new(1, 1, 1) or BROWN
	end
end
selectTab(1)
for i, b in ipairs(tabs) do
	b.Activated:Connect(function()
		selectTab(i)
	end)
end

local function preview(parent, entry)
	local vpf = new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(226, 172, 96), Ambient = Color3.fromRGB(190, 190, 195), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6), Size = UDim2.new(1, -10, 1, -34), Position = UDim2.fromOffset(5, 5), Parent = parent })
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
local function refresh()
	local ok, st = pcall(function()
		return Remotes.GetPlayerState:InvokeServer()
	end)
	if ok and st then
		state = st
		if gui.Enabled then
			render()
		end
	end
end
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
	task.spawn(refresh)
	if not ok then
		msgL.TextColor3 = RED
		msgL.Text = "서버 응답이 없어요"
	elseif type(res) == "table" and not res.ok then
		msgL.TextColor3 = RED
		msgL.Text = tostring(res.msg or res.reason or "할 수 없어요")
	elseif type(res) == "table" and res.msg then
		msgL.TextColor3 = GREEN
		msgL.Text = tostring(res.msg)
	end
end

local made = {} -- 다시 그릴 때 지울 것
local function clearMade()
	for _, o in ipairs(made) do
		o:Destroy()
	end
	table.clear(made)
end
-- 라인 진행 글씨 (화면을 다시 만들지 않고 1초마다 이것만 바꿈)
local function updateJobs(f)
	local lines = {}
	local now = workspace:GetServerTimeNow()
	for k = 1, f.lines or 1 do
		local j = f.jobs and f.jobs[k]
		if j and j.t and j.seconds and j.t > 0 then
			table.insert(lines, string.format("라인 %d: %s %d개 · %d초 남음", k, shapeName(j.shape), j.count or 0, math.max(0, math.ceil(j.seconds - (now - j.t)))))
		else
			table.insert(lines, string.format("라인 %d: 쉬는 중", k))
		end
	end
	jobsL.Text = table.concat(lines, "\n")
end
local function pill(parent, text, on, onClick)
	local b = new("TextButton", { Size = UDim2.fromOffset(64, 30), BackgroundColor3 = on and CARAMEL or Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = on and Color3.new(1, 1, 1) or BROWN, Text = text, Parent = parent })
	corner(b, 10)
	b.Activated:Connect(onClick)
	table.insert(made, b)
	return b
end

function render()
	clearMade()
	local f = state and state.growth and state.growth.factory
	if not f then
		chip.Text = "정보 없음"
		previewL.Text = "공장 정보를 아직 못 받았어요"
		jobsL.Text = ""
		return
	end
	local st = f.status or "off"
	chip.Text = (st == "work" and "ONLINE") or (st == "off" and "OFF") or ("멈춤: " .. st)
	chip.TextColor3 = (st == "work" and MINT) or (st == "off" and Color3.fromRGB(200, 200, 210)) or Color3.fromRGB(255, 130, 120)
	local function set(shape, qty, mode)
		act("factorySet", { shape = shape or f.shape, qty = qty or f.qty, mode = mode or f.mode })
	end
	-- ① 도안 카드
	for i, id in ipairs(f.shapes or {}) do
		local e = ShapeCatalog.get(id)
		if e then
			local g = ShapeCatalog.grade(e.grade)
			local chosen = id == f.shape
			local card = new("TextButton", { LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1), Text = "", Parent = grid })
			corner(card, 10)
			new("UIStroke", { Color = chosen and GREEN or (g and g.color or SOFT), Thickness = chosen and 4 or 2, Parent = card })
			preview(card, e)
			new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -13), Size = UDim2.new(1, -6, 0, 15), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = BROWN, Text = e.name, Parent = card })
			new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -6, 0, 12), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = chosen and GREEN or (g and g.color or SOFT), Text = chosen and "선택됨" or (g and g.label or ""), Parent = card })
			card.Activated:Connect(function()
				if not chosen then
					set(id, nil, nil)
				end
			end)
			table.insert(made, card)
		end
	end
	-- ② 수량 (최대 maxQty)
	for _, q in ipairs({ 20, 30, 40 }) do
		local b = pill(qtyRow, q .. "개", f.qty == q, function()
			if q <= (f.maxQty or 20) and q ~= f.qty then
				set(nil, q, nil)
			end
		end)
		if q > (f.maxQty or 20) then
			b.Text = q .. " 잠김"
			b.TextSize = 11
			b.BackgroundColor3 = Color3.fromRGB(225, 215, 200)
			b.TextColor3 = SOFT
		end
	end
	-- ③ 방식
	for _, m in ipairs({ "normal", "precise", "fast" }) do
		pill(modeRow, MODE_NAME[m], f.mode == m, function()
			if m ~= f.mode then
				set(nil, nil, m)
			end
		end)
	end
	local DESC = { normal = "기본 품질 · 기본 속도 (Normal~Good)", precise = "품질↑ 시간 1.5배 (Good~Excellent)", fast = "시간 0.7배 · 품질↓ (Poor~Good)" }
	modeDesc.Text = DESC[f.mode] or ""
	-- 예상
	local pv = f.preview
	if pv then
		-- 포장지는 자동 포장 시스템이 있을 때만 씀 (2026-11-22 사용자 확정: 없으면 preview.wrapper = nil)
		local wrap = pv.wrapper and string.format(" · 포장지 %s", tostring(pv.wrapper)) or ""
		previewL.Text = string.format("예상 한 판: %d초\n설탕 %s · 소다 %s%s · %s 코인", pv.seconds or 0, tostring(pv.sugar or 0), tostring(pv.soda or 0), wrap, tostring(pv.coins or 0))
	else
		previewL.Text = ""
	end
	updateJobs(f)
	runBtn.Text = f.on and "생산 멈추기" or "생산 시작"
	runBtn.BackgroundColor3 = f.on and RED or GREEN
	-- 업그레이드
	for i, u in ipairs(f.upgrades or {}) do
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = PANEL, Parent = upList })
		corner(row, 10)
		new("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, Text = u.name or u.key, Parent = row })
		new("TextLabel", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -170, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SOFT, Text = u.desc or "", Parent = row })
		local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 40), BackgroundColor3 = u.cost and GREEN or Color3.fromRGB(200, 190, 175), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Text = u.cost and (tostring(u.cost) .. " 코인") or "완료", Parent = row })
		corner(b, 10)
		b.Activated:Connect(function()
			if u.cost then
				act("factoryUp", u.key)
			end
		end)
		table.insert(made, row)
	end
end

runBtn.Activated:Connect(function()
	local f = state and state.growth and state.growth.factory
	act("factoryRun", not (f and f.on))
end)
closeBtn.Activated:Connect(function()
	gui.Enabled = false
end)

-- 화면이 열려 있는 동안 남은 시간 글씨를 1초마다 다시 씀
task.spawn(function()
	while true do
		task.wait(1)
		local f = state and state.growth and state.growth.factory
		if gui.Enabled and f then
			updateJobs(f)
		end
	end
end)

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(s)
	local old = state and state.growth and state.growth.factory
	state = s
	local f = s and s.growth and s.growth.factory
	-- 설정·상태가 바뀌었을 때만 다시 그림 (매초 오는 진행 갱신은 글씨만)
	if gui.Enabled and f and (not old or old.shape ~= f.shape or old.qty ~= f.qty or old.mode ~= f.mode or old.on ~= f.on or old.status ~= f.status or old.lines ~= f.lines or old.maxQty ~= f.maxQty) then
		render()
	end
end)

local function open()
	gui.Enabled = true
	msgL.Text = ""
	if state then
		render()
	end
	task.spawn(refresh)
end

local hookedPrompts = setmetatable({}, { __mode = "k" })
local function hook(fac)
	local pending = false
	local function scan(force)
		setup(fac, force)
		local rec = factories[fac]
		local pr = rec and rec.prompt
		if pr and not hookedPrompts[pr] then
			hookedPrompts[pr] = true
			pr.Triggered:Connect(function()
				if fac:GetAttribute("OwnerUserId") == player.UserId then
					open()
				end
			end)
		end
	end
	scan(false)
	-- 공장 3D가 생기거나(해금) 부품이 스트리밍으로 들어오면 잠깐 모았다가 다시 훑음. 부지는 가게 안 (Plot<i>.FactoryLot)
	local function onAdded(d)
		if pending or not (d:IsA("BasePart") or d:IsA("ProximityPrompt") or d.Name == "Building" or d.Name == "FactoryLot") then
			return
		end
		pending = true
		task.delay(0.5, function()
			pending = false
			scan(true)
		end)
	end
	local _, plot = lotOf(fac)
	if plot then
		plot.DescendantAdded:Connect(onAdded)
	end
end

task.spawn(function()
	local folder = workspace:WaitForChild("Factories")
	for _, f in ipairs(folder:GetChildren()) do
		hook(f)
	end
	folder.ChildAdded:Connect(hook)
end)
