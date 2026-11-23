-- 꾸미기(건설) 화면 (D53, 2026-11-25 사용자 "건설 가능하게 하기 (기계나 가구 내가 원하는 곳에 배치할 수 있게)", 안 A).
--   HUD 메뉴 [🛠 꾸미기] → 카메라가 내 가게 안을 위에서 비스듬히 내려다봄.
--   물건을 탭하면 선택(윤곽), 끌면 2스터드 격자를 따라 움직임, 놓을 수 있으면 초록 / 못 놓으면 빨강.
--   아래 큰 버튼: [돌리기] [넣어 두기] [취소] [완료], 위: [처음 배치로]. PC는 R = 돌리기, Delete = 넣어 두기.
--   넣어 둔 물건은 왼쪽 [보관] 줄에 → 누르면 다시 가운데에 꺼냄.
-- 화면에서만 미리 옮겨 보고(내 화면 CFrame), [완료] 때 서버가 다시 검사·저장하고 진짜로 옮김.
-- 서버 형식 (저장·부지 세션에 제안, 2026-11-25):
--   부지 모델(workspace.ShopPlots.Plot<i>) 안
--     "BuildArea" Part: 놓을 수 있는 바닥 (크기 X·Z = 범위, CFrame = 격자 기준, 윗면 = 바닥)
--     "NoBuild" Part들 (선택): 문 앞 등 못 놓는 칸
--     옮길 수 있는 물건 Model: 속성 BuildKey (문자열), BuildW·BuildD (발자국 칸 수, 없으면 크기로 셈), BuildName (화면 이름, 선택)
--   격자 좌표: x, z = 물건 발자국의 왼쪽 위 칸 번호 (BuildArea 로컬 -X·-Z 모서리 = 0,0), r = 0~3 (90°씩)
--   Remotes.BuildAction:InvokeServer("begin" | "end")  꾸미기 시작·끝 알림 (손님 잠깐 멈춤 등)
--   Remotes.BuildAction:InvokeServer("save", { [key] = { x =, z =, r = } 또는 { stored = true } }) → { ok, reason, bad = key }
--   Remotes.BuildAction:InvokeServer("reset") → { ok, reason }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UiStyle"))
local G = require(Shared:WaitForChild("GrowthConfig"))
local C = UI.C
local new = UI.new

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local camera = workspace.CurrentCamera

local BUILD = G.Build or {}
local GRID = BUILD.grid or 2
local OK_COLOR = Color3.fromRGB(90, 220, 90)
local BAD_COLOR = Color3.fromRGB(240, 70, 60)

local function buildAction(...)
	local r = Remotes:FindFirstChild("BuildAction")
	if not r then
		return nil
	end
	local args = table.pack(...)
	local ok, res = pcall(function()
		return r:InvokeServer(table.unpack(args, 1, args.n))
	end)
	return ok and res or nil
end
local function toast(text)
	local hud = script.Parent:FindFirstChild("Hud")
	local ev = hud and hud:FindFirstChild("Toast")
	if ev then
		ev:Fire(text)
	end
end

---------------------------------------------------------------- 화면
local gui = UI.screen("BuildUi", 40, playerGui)
gui.Enabled = false
local root = UI.root(gui)
local fit = UI.fitter(root)

-- 위: 안내 + [처음 배치로]
local topBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(720, 56), BackgroundTransparency = 1, Parent = root })
fit(topBar)
local hint = UI.text({ Text = "물건을 눌러 고르고, 끌어서 옮겨요", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -240, 1, 0), TextSize = 22, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = topBar })
local resetBtn = UI.button({ Text = "처음 배치로", Color = C.grey, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(150, 50), TextSize = 18, Parent = topBar })

-- 아래: 큰 버튼 4개
local bottom = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(4 * 150 + 3 * 12, 70), BackgroundTransparency = 1, Parent = root }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
fit(bottom)
local function bigButton(text, color, order)
	return UI.button({ Text = text, Color = color, LayoutOrder = order, Size = UDim2.fromOffset(150, 66), TextSize = 22, Parent = bottom })
end
local rotateBtn = bigButton("🔄 돌리기", C.cyan, 1)
local storeBtn = bigButton("📦 넣어 두기", C.yellow, 2)
local cancelBtn = bigButton("취소", C.red, 3)
local doneBtn = bigButton("✔ 완료", C.green, 4)

-- 왼쪽: 넣어 둔 물건
local tray = UI.card({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(150, 300), BackgroundColor3 = C.woodInner, Visible = false, Parent = root })
tray:FindFirstChildOfClass("UIStroke").Color = C.woodDark
fit(tray)
UI.text({ Text = "📦 보관", Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 24), TextSize = 18, TextColor3 = C.cream, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Parent = tray })
local trayList = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 1, -42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = tray }, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

---------------------------------------------------------------- 상태
local active = false
local area = nil -- BuildArea Part
local cellsX, cellsZ = 0, 0
local items = {} -- [key] = { model, w, d, x, z, r, stored, orig (원래 pivot), off (pivot → 발자국 가운데, 모델 로컬), y (기준 높이), name }
local selected = nil
local dragging = false
local dragGrab = Vector2.zero -- 끌기 시작한 칸과 물건 칸의 차이
local highlight = new("Highlight", { Name = "BuildSelect", DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = 0.75, OutlineTransparency = 0 })
local blocked = {} -- NoBuild 칸 사각형 { x0, z0, x1, z1 }
local hidden = {} -- 꾸미기 동안 끈 다른 ScreenGui

local function myPlot()
	local plots = workspace:FindFirstChild("ShopPlots")
	local i = me:GetAttribute("PlotIndex")
	return plots and i and plots:FindFirstChild("Plot" .. i)
end

local function footprint(it)
	if it.r % 2 == 1 then
		return it.d, it.w
	end
	return it.w, it.d
end

-- 격자 → 월드 (발자국 가운데)
local function cellCenter(it)
	local w, d = footprint(it)
	local lx = -area.Size.X / 2 + (it.x + w / 2) * GRID
	local lz = -area.Size.Z / 2 + (it.z + d / 2) * GRID
	return lx, lz
end

local function place(it)
	if it.stored then
		it.model:PivotTo(it.orig + Vector3.new(0, -500, 0)) -- 넣어 둔 동안은 바닥 아래로 (내 화면만)
		return
	end
	local lx, lz = cellCenter(it)
	local target = area.CFrame * CFrame.new(lx, it.y, lz) * CFrame.Angles(0, it.r * math.pi / 2, 0)
	it.model:PivotTo(target * CFrame.new(-it.off))
end

local function rectOf(it)
	local w, d = footprint(it)
	return it.x, it.z, it.x + w, it.z + d
end
local function overlaps(a0, b0, a1, b1, c0, d0, c1, d1)
	return a0 < c1 and c0 < a1 and b0 < d1 and d0 < b1
end
-- 놓을 수 있나 (범위·겹침·못 놓는 칸). 길 검사는 서버가 [완료] 때.
local function valid(it)
	if it.stored then
		return true
	end
	local x0, z0, x1, z1 = rectOf(it)
	if x0 < 0 or z0 < 0 or x1 > cellsX or z1 > cellsZ then
		return false, "바닥 밖이에요"
	end
	for _, b in ipairs(blocked) do
		if overlaps(x0, z0, x1, z1, b[1], b[2], b[3], b[4]) then
			return false, "문 앞에는 못 놓아요"
		end
	end
	for _, o in pairs(items) do
		if o ~= it and not o.stored then
			local a0, b0, a1, b1 = rectOf(o)
			if overlaps(x0, z0, x1, z1, a0, b0, a1, b1) then
				return false, "다른 물건과 겹쳐요"
			end
		end
	end
	return true
end

local function refreshHighlight()
	if selected and not selected.stored then
		local ok, why = valid(selected)
		highlight.Adornee = selected.model
		highlight.OutlineColor = ok and OK_COLOR or BAD_COLOR
		highlight.FillColor = ok and OK_COLOR or BAD_COLOR
		highlight.Parent = gui
		hint.Text = ok and string.format("%s · 놓을 수 있어요", selected.name) or (selected.name .. " · " .. why)
	else
		highlight.Adornee = nil
		hint.Text = "물건을 눌러 고르고, 끌어서 옮겨요"
	end
	UI.setButton(rotateBtn, { Enabled = selected ~= nil })
	UI.setButton(storeBtn, { Enabled = selected ~= nil })
end

local function refreshTray()
	for _, c in ipairs(trayList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local n = 0
	for _, it in pairs(items) do
		if it.stored then
			n += 1
			local b = UI.button({ Text = it.name, Color = C.woodLight, LayoutOrder = n, Size = UDim2.new(1, 0, 0, 44), TextSize = 15, Parent = trayList })
			b.Activated:Connect(function()
				-- 가운데에 꺼내 놓고 고름 (못 놓으면 빨강 → 옮기면 됨)
				it.stored = false
				local w, d = footprint(it)
				it.x = math.max(0, math.floor((cellsX - w) / 2))
				it.z = math.max(0, math.floor((cellsZ - d) / 2))
				place(it)
				selected = it
				refreshTray()
				refreshHighlight()
			end)
		end
	end
	tray.Visible = n > 0
end

---------------------------------------------------------------- 들어가기 · 나가기
local savedCam = nil
local function controls(on)
	local ok, pm = pcall(function()
		return require(me:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and pm then
		local c = pm:GetControls()
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end
end

local function aimCamera()
	-- 가게 바닥 전체가 보이게, 위에서 약 60° 비스듬히
	local size = area.Size
	local fov = math.rad(camera.FieldOfView)
	local vp = camera.ViewportSize
	local aspect = vp.X / math.max(vp.Y, 1)
	local need = math.max(size.Z * 1.15, size.X * 1.15 / aspect)
	local dist = need / (2 * math.tan(fov / 2)) + 6
	local pitch = math.rad(60)
	local center = area.CFrame * CFrame.new(0, area.Size.Y / 2, 0)
	-- 가게 앞(BuildArea의 -LookVector 쪽)에서 비스듬히
	local flatBack = -area.CFrame.LookVector
	flatBack = Vector3.new(flatBack.X, 0, flatBack.Z).Unit
	local eye = center.Position + flatBack * math.cos(pitch) * dist + Vector3.new(0, math.sin(pitch) * dist, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(eye, center.Position) }):Play()
end

local function collect(plot)
	table.clear(items)
	table.clear(blocked)
	for _, d in ipairs(plot:GetDescendants()) do
		if d.Name == "NoBuild" and d:IsA("BasePart") then
			local lp = area.CFrame:PointToObjectSpace(d.Position)
			local hx, hz = d.Size.X / 2, d.Size.Z / 2
			table.insert(blocked, {
				math.floor((lp.X - hx + area.Size.X / 2) / GRID),
				math.floor((lp.Z - hz + area.Size.Z / 2) / GRID),
				math.ceil((lp.X + hx + area.Size.X / 2) / GRID),
				math.ceil((lp.Z + hz + area.Size.Z / 2) / GRID),
			})
		elseif d:IsA("Model") and type(d:GetAttribute("BuildKey")) == "string" then
			local pivot = d:GetPivot()
			local box, size = d:GetBoundingBox()
			local rel = area.CFrame:ToObjectSpace(pivot)
			local _, yaw = rel:ToOrientation()
			local r = math.round(yaw / (math.pi / 2)) % 4
			local w = d:GetAttribute("BuildW") or math.max(1, math.ceil(size.X / GRID - 0.05))
			local dd = d:GetAttribute("BuildD") or math.max(1, math.ceil(size.Z / GRID - 0.05))
			local off = pivot:PointToObjectSpace(box.Position)
			off = Vector3.new(off.X, 0, off.Z)
			local it = { model = d, w = w, d = dd, r = r, orig = pivot, off = off, y = rel.Y, name = d:GetAttribute("BuildName") or d.Name }
			-- 지금 자리 → 격자 칸 (가장 가까운 칸으로)
			local center = area.CFrame:PointToObjectSpace(pivot * off)
			local fw, fd = footprint(it)
			it.x = math.round((center.X + area.Size.X / 2) / GRID - fw / 2)
			it.z = math.round((center.Z + area.Size.Z / 2) / GRID - fd / 2)
			it.stored = d:GetAttribute("BuildStored") == true
			items[d:GetAttribute("BuildKey")] = it
		end
	end
end

local function exit(restore)
	if not active then
		return
	end
	active = false
	dragging = false
	if restore then
		for _, it in pairs(items) do
			it.model:PivotTo(it.orig)
		end
	end
	selected = nil
	highlight.Adornee = nil
	gui.Enabled = false
	for g, was in pairs(hidden) do
		if g.Parent then
			g.Enabled = was
		end
	end
	table.clear(hidden)
	camera.CameraType = Enum.CameraType.Custom
	controls(true)
	buildAction("end")
end

local function enter()
	if active then
		return
	end
	local plot = myPlot()
	area = plot and plot:FindFirstChild("BuildArea", true)
	if not area then
		toast("가게를 임대하면 꾸밀 수 있어요")
		return
	end
	local res = buildAction("begin")
	if type(res) == "table" and res.ok == false then
		toast(res.reason or "지금은 꾸밀 수 없어요")
		return
	end
	cellsX = math.floor(area.Size.X / GRID + 0.01)
	cellsZ = math.floor(area.Size.Z / GRID + 0.01)
	collect(plot)
	active = true
	selected = nil
	-- 다른 화면은 잠깐 숨김 (내 것만)
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			hidden[g] = true
			g.Enabled = false
		end
	end
	gui.Enabled = true
	controls(false)
	aimCamera()
	refreshTray()
	refreshHighlight()
end

---------------------------------------------------------------- 고르기 · 끌기
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function itemAt(screen)
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	rayParams.FilterDescendantsInstances = { me.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
	if not hit then
		return nil
	end
	for _, it in pairs(items) do
		if not it.stored and hit.Instance:IsDescendantOf(it.model) then
			return it
		end
	end
	return nil
end

-- 화면 점 → 바닥 격자 칸 (바닥 윗면 평면과 만나는 점)
local function cellAt(screen)
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local top = area.CFrame * CFrame.new(0, area.Size.Y / 2, 0)
	local n = top.UpVector
	local denom = ray.Direction:Dot(n)
	if math.abs(denom) < 1e-4 then
		return nil
	end
	local t = (top.Position - ray.Origin):Dot(n) / denom
	if t < 0 then
		return nil
	end
	local p = top:PointToObjectSpace(ray.Origin + ray.Direction * t)
	return Vector2.new((p.X + area.Size.X / 2) / GRID, (p.Z + area.Size.Z / 2) / GRID)
end

local function pressAt(pos)
	local it = itemAt(pos)
	selected = it
	if it then
		local c = cellAt(pos)
		dragging = c ~= nil
		if c then
			dragGrab = Vector2.new(c.X - it.x, c.Y - it.z)
		end
	end
	refreshHighlight()
end

local function moveTo(pos)
	if not (dragging and selected) then
		return
	end
	local c = cellAt(pos)
	if not c then
		return
	end
	local w, d = footprint(selected)
	local nx = math.clamp(math.floor(c.X - dragGrab.X + 0.5), -w + 1, cellsX - 1)
	local nz = math.clamp(math.floor(c.Y - dragGrab.Y + 0.5), -d + 1, cellsZ - 1)
	if nx ~= selected.x or nz ~= selected.z then
		selected.x, selected.z = nx, nz
		place(selected)
		refreshHighlight()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not active or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressAt(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.R then
		if selected then
			selected.r = (selected.r + 1) % 4
			place(selected)
			refreshHighlight()
		end
	elseif input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
		if selected then
			selected.stored = true
			place(selected)
			selected = nil
			refreshTray()
			refreshHighlight()
		end
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		moveTo(Vector2.new(input.Position.X, input.Position.Y))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

---------------------------------------------------------------- 버튼
rotateBtn.Activated:Connect(function()
	if selected then
		selected.r = (selected.r + 1) % 4
		place(selected)
		refreshHighlight()
	end
end)
storeBtn.Activated:Connect(function()
	if selected then
		selected.stored = true
		place(selected)
		selected = nil
		refreshTray()
		refreshHighlight()
	end
end)
cancelBtn.Activated:Connect(function()
	exit(true)
end)
local busy = false
doneBtn.Activated:Connect(function()
	if busy then
		return
	end
	-- 화면에서 먼저 검사
	for _, it in pairs(items) do
		local ok, why = valid(it)
		if not ok then
			selected = it
			refreshHighlight()
			hint.Text = it.name .. " · " .. why
			return
		end
	end
	local layout = {}
	for key, it in pairs(items) do
		layout[key] = it.stored and { stored = true } or { x = it.x, z = it.z, r = it.r }
	end
	busy = true
	local res = buildAction("save", layout)
	busy = false
	if type(res) ~= "table" then
		hint.Text = "꾸미기 서버가 아직 없어요 (저장 안 됨)"
		return
	end
	if not res.ok then
		hint.Text = res.reason or "저장할 수 없어요"
		if res.bad and items[res.bad] then
			selected = items[res.bad]
			highlight.Adornee = selected.model
			highlight.OutlineColor = BAD_COLOR
			highlight.FillColor = BAD_COLOR
		end
		return
	end
	exit(false) -- 서버가 진짜로 옮김 (내 화면에 옮겨 둔 자리 그대로)
	toast(res.msg or "가게 배치를 바꿨어요!")
end)
resetBtn.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	local res = buildAction("reset")
	busy = false
	if type(res) == "table" and res.ok then
		exit(true)
		toast(res.msg or "처음 배치로 돌렸어요")
	else
		hint.Text = type(res) == "table" and (res.reason or "되돌릴 수 없어요") or "꾸미기 서버가 아직 없어요"
	end
end)

-- 죽거나 캐릭터가 바뀌면 취소
me.CharacterAdded:Connect(function()
	exit(true)
end)
RunService.RenderStepped:Connect(function()
	if active and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

---------------------------------------------------------------- HUD 메뉴 버튼 [🛠 꾸미기]
task.spawn(function()
	local menu = playerGui:WaitForChild("ShopHud"):WaitForChild("Root"):WaitForChild("Menu")
	local slot = new("Frame", { Name = "BuildSlot", LayoutOrder = 4, Size = UDim2.fromOffset(72, 86), BackgroundTransparency = 1, Parent = menu })
	local btn = UI.button({ Name = "Build", Text = "🛠", Color = C.woodLight, Radius = 18, TextSize = 30, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(64, 66), Parent = slot })
	UI.text({ Text = "꾸미기", TextSize = 17, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Parent = slot })
	btn.Activated:Connect(enter)
end)
