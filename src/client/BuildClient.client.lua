-- 꾸미기(건설) 화면 (D53, 2026-11-25 사용자 "건설 가능하게 하기 (기계나 가구 내가 원하는 곳에 배치할 수 있게)", 안 A).
--   HUD 메뉴 [🛠 꾸미기] → 카메라가 내 가게 안을 위에서 비스듬히 내려다봄.
--   물건을 탭하면 선택(윤곽), 끌면 2스터드 격자를 따라 움직임, 놓을 수 있으면 초록 / 못 놓으면 빨강 (서버 "check").
--   아래 큰 버튼: [돌리기] [취소] [완료], 위: [처음 배치로]. PC는 R = 돌리기.
--   [넣어 두기]는 서버 첫 버전에 없어서 아직 안 보임 (서버가 생기면 STORE_READY = true).
-- 화면에서만 미리 옮겨 보고(내 화면 CFrame), [완료] 때 옮긴 물건마다 서버 "place"(검사·저장·진짜로 옮김).
-- 서버 (판매 세션 feat/shop-features-1125, BuildService):
--   Remotes.BuildAction:InvokeServer("get") → { ok, layout, items = { [key] = { name, x, z, r, w, d, default } }, area = {x0,x1,z0,z1}, cell = 2 }
--     좌표 = 부지 로컬(부지 모델 속성 PlotCFrame 기준) 격자, 물건 가운데 스터드 = 값 × cell, r = 처음 자리에서 90°씩
--   ("check", key, x, z, r) → { ok, reason } (미리 보기, 저장 안 함) / ("place", key, x, z, r) → { ok, reason } / ("reset") → { ok }
--   물건 부품은 GrowthConfig.Build.items의 roles(가게 3D 부품 속성 Role → 그 부모 노드) · names(부지 안 이름)로 찾음 (서버와 같은 방법)
--   배치가 바뀌면 부지 속성 LayoutVersion이 늘어남. 손 작업대·걸이판·공장 문은 고정.

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

local STORE_READY = false -- 서버에 [넣어 두기]가 생기면 true
local OK_COLOR = Color3.fromRGB(90, 220, 90)
local BAD_COLOR = Color3.fromRGB(240, 70, 60)
local WAIT_COLOR = Color3.fromRGB(255, 220, 90)

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

local topBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(720, 56), BackgroundTransparency = 1, Parent = root })
fit(topBar)
local hint = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -80, 0.5, 0), Size = UDim2.new(1, -200, 1, 0), TextSize = 22, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = topBar })
local resetBtn = UI.button({ Text = "처음 배치로", Color = C.grey, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(150, 50), TextSize = 18, Parent = topBar })

local bottom = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(4 * 150 + 3 * 12, 70), BackgroundTransparency = 1, Parent = root }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
fit(bottom)
local function bigButton(text, color, order)
	return UI.button({ Text = text, Color = color, LayoutOrder = order, Size = UDim2.fromOffset(150, 66), TextSize = 22, Parent = bottom })
end
local rotateBtn = bigButton("🔄 돌리기", C.cyan, 1)
local storeBtn = bigButton("📦 넣어 두기", C.yellow, 2)
storeBtn.Visible = STORE_READY
local cancelBtn = bigButton("취소", C.red, 3)
local doneBtn = bigButton("✔ 완료", C.green, 4)

---------------------------------------------------------------- 상태
local active = false
local dragInput = nil -- 지금 물건을 끄는 손가락 (폰)
local plot, plotCF = nil, nil
local CELL = 2
local area = nil -- { x0, x1, z0, z1 } 부지 로컬 스터드
-- items[key] = { name, w, d, nodes = { { inst, orig = 처음 pivot } }, x0, z0, r0 (들어올 때), x, z, r (지금), ok (마지막 검사), why }
local items = {}
local selected = nil
local dragging = false
local grab = Vector2.zero -- 끌기 시작한 점과 물건 가운데의 차이 (스터드)
local highlights = {}
local hidden = {}
local checkSeq = 0

local function myPlot()
	local plots = workspace:FindFirstChild("ShopPlots")
	local i = me:GetAttribute("PlotIndex")
	return plots and i and plots:FindFirstChild("Plot" .. i)
end

local function pivotOf(inst)
	return inst:IsA("Model") and inst:GetPivot() or inst.CFrame
end
local function setPivot(inst, cf)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	else
		inst.CFrame = cf
	end
end

-- 서버 BuildService.findNodes와 같은 방법
local function findNodes(model, def)
	local out = {}
	for _, role in ipairs(def.roles or {}) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Role") == role then
				local node = d.Parent
				if node and node:IsA("Model") and node.Name ~= "ShopModel" and node ~= model then
					table.insert(out, node)
				else
					table.insert(out, d)
				end
				break
			end
		end
	end
	for _, name in ipairs(def.names or {}) do
		local p = model:FindFirstChild(name)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

-- 지금 (x, z, r)로 내 화면에서 옮김: 들어올 때 자리에서 바뀐 만큼 (서버 apply와 같은 식, 가운데 기준 회전)
local function place(it)
	local delta = plotCF
		* CFrame.new(it.x * CELL, 0, it.z * CELL)
		* CFrame.Angles(0, math.rad(90 * (it.r - it.r0)), 0)
		* CFrame.new(-it.x0 * CELL, 0, -it.z0 * CELL)
		* plotCF:Inverse()
	for _, n in ipairs(it.nodes) do
		if n.inst.Parent then
			setPivot(n.inst, delta * n.orig)
		end
	end
end

local function restoreAll()
	for _, it in pairs(items) do
		for _, n in ipairs(it.nodes) do
			if n.inst.Parent then
				setPivot(n.inst, n.orig)
			end
		end
	end
end

local function moved(it)
	return it.x ~= it.x0 or it.z ~= it.z0 or it.r ~= it.r0
end

local function clearHighlights()
	for _, h in ipairs(highlights) do
		h:Destroy()
	end
	table.clear(highlights)
end

local function refresh()
	clearHighlights()
	if selected then
		local color = selected.ok == nil and WAIT_COLOR or (selected.ok and OK_COLOR or BAD_COLOR)
		for _, n in ipairs(selected.nodes) do
			table.insert(highlights, new("Highlight", { Adornee = n.inst, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillColor = color, FillTransparency = 0.75, OutlineColor = color, Parent = gui }))
		end
		if selected.ok == nil then
			hint.Text = selected.name .. " · 확인 중…"
		elseif selected.ok then
			hint.Text = selected.name .. " · 놓을 수 있어요"
		else
			hint.Text = selected.name .. " · " .. (selected.why or "여기는 못 놓아요")
		end
	else
		hint.Text = "물건을 눌러 고르고, 끌어서 옮겨요"
	end
	UI.setButton(rotateBtn, { Enabled = selected ~= nil })
	UI.setButton(storeBtn, { Enabled = selected ~= nil })
end

-- 서버에 미리 검사 (가장 마지막 요청 결과만 씀)
local function check(it)
	if not moved(it) then
		it.ok, it.why = true, nil
		refresh()
		return
	end
	-- 범위 밖은 화면에서 바로 빨강
	local w, d = it.w, it.d
	if it.r % 2 == 1 then
		w, d = d, w
	end
	local cx, cz = it.x * CELL, it.z * CELL
	if area and (cx - w * CELL / 2 < area.x0 - 0.01 or cx + w * CELL / 2 > area.x1 + 0.01 or cz - d * CELL / 2 < area.z0 - 0.01 or cz + d * CELL / 2 > area.z1 + 0.01) then
		it.ok, it.why = false, "가게 바닥 밖이에요"
		refresh()
		return
	end
	it.ok, it.why = nil, nil
	refresh()
	checkSeq += 1
	local my = checkSeq
	local key, x, z, r = it.key, it.x, it.z, it.r
	task.spawn(function()
		local res = buildAction("check", key, x, z, r)
		if my ~= checkSeq or not active then
			return
		end
		if type(res) == "table" then
			it.ok, it.why = res.ok == true, res.reason
		else
			it.ok, it.why = false, "꾸미기 서버가 아직 없어요"
		end
		refresh()
	end)
end

---------------------------------------------------------------- 들어가기 · 나가기
-- 움직임 막기: PlayerModule이 있으면 그걸로, 없으면(이 장소처럼) 걷기·점프 0 (MakingClient.setControls와 같은 방법)
-- WaitForChild를 쓰면 PlayerModule이 없는 장소에서 영원히 멈춤 (2026-11-25 묶음 시험)
local savedMove = nil
local function controls(on)
	local pm = me:FindFirstChild("PlayerScripts") and me.PlayerScripts:FindFirstChild("PlayerModule")
	if pm then
		local ok, c = pcall(function()
			return require(pm):GetControls()
		end)
		if ok and c then
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end
	end
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui then
		touchGui.Enabled = on
	end
	local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		if on then
			if savedMove then
				hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = savedMove[1], savedMove[2], savedMove[3]
				savedMove = nil
			end
		else
			savedMove = savedMove or { hum.WalkSpeed, hum.JumpPower, hum.JumpHeight }
			hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
		end
	end
end

local function aimCamera()
	-- 가게 바닥 범위 전체가 보이게, 가게 앞(부지 로컬 -Z, 골목 쪽)에서 위로 60° 비스듬히
	local sx, sz = area.x1 - area.x0, area.z1 - area.z0
	local center = plotCF * Vector3.new((area.x0 + area.x1) / 2, 0, (area.z0 + area.z1) / 2)
	local fov = math.rad(camera.FieldOfView)
	local vp = camera.ViewportSize
	local aspect = vp.X / math.max(vp.Y, 1)
	local need = math.max(sz * 1.1, sx * 1.15 / aspect)
	local dist = need / (2 * math.tan(fov / 2)) + 8
	local pitch = math.rad(60)
	local front = plotCF.LookVector -- 로컬 -Z = 골목 쪽
	front = Vector3.new(front.X, 0, front.Z).Unit
	local eye = center + front * math.cos(pitch) * dist + Vector3.new(0, math.sin(pitch) * dist, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(eye, center) }):Play()
end

-- 서버 "get"으로 지금 배치를 받아 물건을 모음
local function load()
	local res = buildAction("get")
	if type(res) ~= "table" or not res.ok then
		return false, type(res) == "table" and res.reason or "꾸미기 서버가 아직 없어요"
	end
	CELL = res.cell or 2
	area = res.area
	table.clear(items)
	local defs = {}
	for _, def in ipairs((G.Build and G.Build.items) or {}) do
		defs[def.key] = def
	end
	for key, e in pairs(res.items or {}) do
		local def = defs[key]
		-- 계산대·유리 진열장은 꾸미기에서 안 옮김 (2026-11-27 사용자 "카운터 진열대 제외 모두 바꿀 수 있도록")
		local nodes = (def and key ~= "counter") and findNodes(plot, def) or {}
		-- 기계 자리(MachineSlot)는 바닥 판뿐 → 그 위 기계(Machine2·3·4)도 같이 끌려 보이게 (서버는 [완료] 때 MachineDisplay.sync로 옮김)
		if def and def.machine and #nodes > 0 then
			local mm = plot:FindFirstChild("Machine" .. tostring(key):gsub("^m", ""))
			if mm then
				table.insert(nodes, mm)
			end
		end
		if #nodes > 0 then
			local it = { key = key, name = e.name or key, w = e.w or 1, d = e.d or 1, nodes = {}, x0 = e.x, z0 = e.z, r0 = e.r or 0, x = e.x, z = e.z, r = e.r or 0, ok = true }
			for _, n in ipairs(nodes) do
				table.insert(it.nodes, { inst = n, orig = pivotOf(n) })
			end
			items[key] = it
		end
	end
	return next(items) ~= nil, "옮길 수 있는 물건이 없어요"
end

-- 지붕·천장·앞쪽 윗벽 숨기기 (내 화면만, 2026-11-25 묶음 시험: 위에서 보면 지붕만 보이고 레이캐스트가 지붕에 맞음)
-- 부지 바닥 높이 + ROOF_Y 위에서 시작하는 부품 = 지붕·윗벽. LocalTransparencyModifier = 1 + 레이캐스트 제외, 나갈 때 되돌림.
local ROOF_Y = 8
local roofParts = {}
local function hideRoof()
	table.clear(roofParts)
	local movable = {}
	for _, it in pairs(items) do
		for _, n in ipairs(it.nodes) do
			movable[n.inst] = true
		end
	end
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("BasePart") then
			-- 옮길 물건(노드 안)은 숨기지 않음
			local skip = false
			local a = d
			while a and a ~= plot do
				if movable[a] then
					skip = true
					break
				end
				a = a.Parent
			end
			if not skip then
				-- 부품의 가장 낮은 점 (부지 로컬 높이)
				local cf, size = d.CFrame, d.Size / 2
				local low = math.huge
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local y = plotCF:PointToObjectSpace((cf * CFrame.new(size.X * sx, size.Y * sy, size.Z * sz)).Position).Y
							low = math.min(low, y)
						end
					end
				end
				if low > ROOF_Y then
					d.LocalTransparencyModifier = 1
					table.insert(roofParts, d)
				end
			end
		end
	end
end
local function showRoof()
	for _, d in ipairs(roofParts) do
		if d.Parent then
			d.LocalTransparencyModifier = 0
		end
	end
	table.clear(roofParts)
end

local function exit(restore)
	if not active then
		return
	end
	active = false
	-- 꾸미기 끝: 다른 버튼·진열·보관함 누르기 다시 켬
	me:SetAttribute("Building", nil)
	game:GetService("ProximityPromptService").Enabled = true
	dragging = false
	checkSeq += 1
	if restore then
		restoreAll()
	end
	selected = nil
	clearHighlights()
	gui.Enabled = false
	for g in pairs(hidden) do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hidden)
	dragInput = nil
	camera.CameraType = Enum.CameraType.Custom
	showRoof()
end

local function enter()
	if active then
		return
	end
	plot = myPlot()
	plotCF = plot and plot:GetAttribute("PlotCFrame")
	if typeof(plotCF) ~= "CFrame" then
		plotCF = plot and plot:GetPivot()
	end
	if not plot then
		toast("가게를 불러오는 중이에요")
		return
	end
	local ok, why = load()
	if not ok then
		toast(why)
		return
	end
	active = true
	-- 꾸미기 중에는 꾸미기만 (2026-11-27 사용자 "달고나 들고 진열장 눌러도 진열이 아니라 위치 수정으로"):
	-- 모든 기계·가구 버튼(ProximityPrompt)을 끄고, 진열·보관함 클라이언트는 이 속성을 보고 누르기를 무시
	me:SetAttribute("Building", true)
	game:GetService("ProximityPromptService").Enabled = false
	selected = nil
	for _, g in ipairs(playerGui:GetChildren()) do
		-- 폰 조이스틱(TouchGui)은 남김: 꾸미는 동안에도 걸어 다님
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled and g.Name ~= "TouchGui" then
			hidden[g] = true
			g.Enabled = false
		end
	end
	gui.Enabled = true
	-- 2026-11-28 사용자 "꾸미기 때 창이 다 가려짐, 일반 플레이 화면에서 가구를 옮기게, 화면 회전 가능하게":
	-- 위에서 내려다보는 카메라(aimCamera)·지붕 숨기기(hideRoof)·조작 끄기를 안 하고 평소 카메라 그대로.
	-- 물건을 끄는 동안만 카메라를 그 자리에 멈춤 (손가락 끌기가 화면 돌리기로 가지 않게)
	refresh()
end

---------------------------------------------------------------- 고르기 · 끌기
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- 광선이 상자(cf, size)에 닿는 거리 (안 닿으면 nil)
local function rayBox(origin, dir, cf, size)
	local o = cf:PointToObjectSpace(origin)
	local d = cf:VectorToObjectSpace(dir)
	local h = size / 2
	local tmin, tmax = 0, math.huge
	for _, ax in ipairs({ "X", "Y", "Z" }) do
		local oa, da, ha = o[ax], d[ax], h[ax]
		if math.abs(da) < 1e-8 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	return tmin
end

-- 화면 점에 있는 물건: 물건 노드마다 부품 상자에 광선을 대 봄 (2026-11-27 사용자 "냉장고만 옮겨짐": 가게 가구 부품은
-- 대부분 CanQuery = false라 레이캐스트에 안 맞아서 버튼(CanQuery)이 있는 냉장고만 골라졌음). 가장 가까운 것
local function itemAt(screen)
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local best, bt = nil, math.huge
	for _, it in pairs(items) do
		for _, n in ipairs(it.nodes) do
			local parts = n.inst:IsA("BasePart") and { n.inst } or n.inst:GetDescendants()
			for _, p in ipairs(parts) do
				if p:IsA("BasePart") and p.Transparency < 0.95 and p.Size.Magnitude > 0.05 then
					local t = rayBox(ray.Origin, ray.Direction, p.CFrame, p.Size)
					if t and t < bt then
						best, bt = it, t
					end
				end
			end
		end
	end
	return best
end

-- 화면 점 → 부지 로컬 바닥 점 (스터드, 바닥 = 부지 기준 높이)
local function floorAt(screen)
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local n = plotCF.UpVector
	local denom = ray.Direction:Dot(n)
	if math.abs(denom) < 1e-4 then
		return nil
	end
	local t = (plotCF.Position - ray.Origin):Dot(n) / denom
	if t < 0 then
		return nil
	end
	local p = plotCF:PointToObjectSpace(ray.Origin + ray.Direction * t)
	return Vector2.new(p.X, p.Z)
end

-- 끄는 동안 카메라 멈춤 (평소 카메라는 끌면 돌아감)
local function holdCamera(on)
	if on then
		local cf = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cf
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- 누른 자리에 물건이 있으면 고르고 끌기 시작. 빈 곳이면 고른 것은 그대로 두고 화면 돌리기(평소 카메라)에 맡김
local function pressAt(pos, input)
	local it = itemAt(pos)
	if not it then
		return
	end
	if it ~= selected then
		checkSeq += 1
	end
	selected = it
	dragging = false
	local f = floorAt(pos)
	if f then
		dragging = true
		dragInput = input
		grab = f - Vector2.new(it.x * CELL, it.z * CELL)
		holdCamera(true)
	end
	refresh()
end

local function moveTo(pos)
	if not (dragging and selected) then
		return
	end
	local f = floorAt(pos)
	if not f then
		return
	end
	local c = f - grab
	local nx, nz = math.floor(c.X / CELL + 0.5), math.floor(c.Y / CELL + 0.5)
	if nx ~= selected.x or nz ~= selected.z then
		selected.x, selected.z = nx, nz
		place(selected)
		check(selected)
	end
end

local function rotate()
	if selected then
		selected.r = (selected.r + 1) % 4
		place(selected)
		check(selected)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not active or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if not dragging then -- 두 번째 손가락(확대·축소)은 끌기로 안 침
			pressAt(Vector2.new(input.Position.X, input.Position.Y), input)
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		rotate()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput) then
		moveTo(Vector2.new(input.Position.X, input.Position.Y))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput) then
		if dragging then
			holdCamera(false)
		end
		dragging = false
		dragInput = nil
	end
end)

---------------------------------------------------------------- 버튼
rotateBtn.Activated:Connect(rotate)
cancelBtn.Activated:Connect(function()
	exit(true)
end)

local busy = false
doneBtn.Activated:Connect(function()
	if busy then
		return
	end
	local list = {}
	for _, it in pairs(items) do
		if moved(it) then
			if it.ok == false then
				selected = it
				refresh()
				return
			end
			table.insert(list, it)
		end
	end
	if #list == 0 then
		exit(true)
		return
	end
	busy = true
	hint.Text = "저장하는 중…"
	-- 서버가 진짜로 옮기므로, 내 화면에서 옮긴 것은 먼저 원래대로 (서버가 옮긴 자리가 그대로 보이게)
	restoreAll()
	-- 서버는 한 개씩 검사 → 서로 자리를 바꾸는 경우 앞의 것이 비켜야 됨. 실패한 것은 한 바퀴 더 (성공이 있는 동안 반복)
	local failed = nil
	local pending = list
	local sent = 0
	while #pending > 0 do
		local nextRound, progress = {}, false
		for _, it in ipairs(pending) do
			if sent > 0 then
				task.wait(0.3) -- 서버 "천천히!" (0.25초)
			end
			sent += 1
			local res = buildAction("place", it.key, it.x, it.z, it.r)
			if type(res) == "table" and res.ok then
				progress = true
			else
				table.insert(nextRound, it)
				failed = { it = it, why = type(res) == "table" and res.reason or "꾸미기 서버가 아직 없어요" }
				if type(res) ~= "table" then
					nextRound = {}
					break
				end
			end
		end
		if #nextRound == 0 then
			failed = (type(failed) == "table" and failed.why == "꾸미기 서버가 아직 없어요") and failed or nil
			break
		end
		if not progress then
			break
		end
		pending = nextRound
	end
	busy = false
	if not failed then
		exit(false)
		toast("가게 배치를 바꿨어요!")
		return
	end
	-- 실패: 저장된 것까지 다시 받아서 이어서 꾸미기, 못 놓은 물건은 그 자리에 다시 놓아 빨강
	local want = { x = failed.it.x, z = failed.it.z, r = failed.it.r }
	task.wait(0.2)
	load()
	local again = items[failed.it.key]
	if again then
		again.x, again.z, again.r = want.x, want.z, want.r
		again.ok, again.why = false, failed.why
		place(again)
		selected = again
	end
	refresh()
end)

resetBtn.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	restoreAll()
	local res = buildAction("reset")
	busy = false
	if type(res) == "table" and res.ok then
		exit(false)
		toast("처음 배치로 돌렸어요")
	else
		hint.Text = type(res) == "table" and (res.reason or "되돌릴 수 없어요") or "꾸미기 서버가 아직 없어요"
	end
end)

me.CharacterAdded:Connect(function()
	exit(true)
end)
-- (예전: 꾸미는 동안 카메라를 위에서 고정 — 2026-11-28부터 평소 카메라, 끄는 동안만 holdCamera)

---------------------------------------------------------------- HUD 메뉴 버튼 [🛠 꾸미기]
task.spawn(function()
	local menu = playerGui:WaitForChild("ShopHud"):WaitForChild("Root"):WaitForChild("Menu")
	local slot = new("Frame", { Name = "BuildSlot", LayoutOrder = 4, Size = UDim2.fromOffset(72, 86), BackgroundTransparency = 1, Parent = menu })
	local btn = UI.button({ Name = "Build", Text = "🛠", Color = C.woodLight, Radius = 18, TextSize = 30, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(64, 66), Parent = slot })
	UI.text({ Text = "꾸미기", TextSize = 17, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Parent = slot })
	btn.Activated:Connect(enter)
end)
