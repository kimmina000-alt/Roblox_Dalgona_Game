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
local UI = require(Shared:WaitForChild("UiStyle")) -- 2026-11-22 새 스타일 (나무 판 창 + 왼쪽 세로 탭 + 사탕 버튼)

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = touch and 0.8 or 1
local CREAM = UI.C.cream
local PANEL = UI.C.cream
local BROWN = UI.C.ink
local SOFT = UI.C.soft
local CARAMEL = UI.C.yellow
local GREEN = UI.C.green
local RED = UI.C.red
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

local BELT_N = 7 -- 컨베이어 위에 돌려 쓰는 달고나 수 (D36: 6~8)
local function beltFolder()
	local f = workspace:FindFirstChild("FactoryBeltFx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "FactoryBeltFx"
		f.Parent = workspace
	end
	return f
end
local HEAT = Color3.fromRGB(255, 90, 60)

-- 경첩(hinge) 둘레로 axis 축 ang만큼 돌린 자세
local function hingeTurn(cf, hinge, axis, ang)
	local r = CFrame.fromAxisAngle(axis, ang)
	return CFrame.new(hinge) * r * CFrame.new(-hinge) * cf
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
				if d:GetAttribute("AnimSize") == nil then
					d:SetAttribute("AnimSize", d.Size)
					d:SetAttribute("AnimT", d.Transparency)
					d:SetAttribute("AnimMat", d.Material.Name)
				end
				local mat = Enum.Material[d:GetAttribute("AnimMat") or d.Material.Name]
				table.insert(rec.parts, { p = d, a = a, cf = d:GetAttribute("AnimBase"), color = d:GetAttribute("AnimColor"), size = d:GetAttribute("AnimSize"), t0 = d:GetAttribute("AnimT"), mat = mat, axis = axis, phase = (#rec.parts) * 0.7, key = d:GetAttribute("StationKey") })
			end
			-- 옛 5개 묶음 달고나: 길 표시(BeltStart·BeltEnd)가 있으면 내 화면에서 숨기고 아래에서 6~8개를 돌려 씀 (D36)
			if d:GetAttribute("BeltBundle") and b:GetAttribute("BeltStart") and b:GetAttribute("BeltEnd") then
				d.LocalTransparencyModifier = 1
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
		rec.head = new("TextLabel", { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1, FontFace = UI.F.heavy, TextScaled = true, TextColor3 = MINT, TextXAlignment = Enum.TextXAlignment.Left, Text = "달고나 공장", Parent = box })
		rec.bars, rec.barText = {}, {}
		for k = 1, 2 do
			local y = 26 + (k - 1) * 24
			local bg = new("Frame", { Position = UDim2.fromOffset(8, y + 14), Size = UDim2.new(1, -16, 0, 6), BackgroundColor3 = Color3.fromRGB(70, 74, 92), Parent = box })
			corner(bg, 3)
			rec.bars[k] = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, Parent = bg })
			corner(rec.bars[k], 3)
			rec.barText[k] = new("TextLabel", { Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, 13), BackgroundTransparency = 1, FontFace = UI.F.bold, TextScaled = true, TextColor3 = Color3.fromRGB(220, 225, 235), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = box })
			rec.bars[k].Parent.Visible = false
		end
	end
	-- 컨베이어 위 달고나 (D36: 보이는 칸 6~8개만 돌려 씀). 길 = 건물 속성 BeltStart → BeltEnd (서버 FactoryDisplay)
	if old and old.beltLooks then
		for _, l in ipairs(old.beltLooks) do
			l:Destroy()
		end
	end
	if b:GetAttribute("BeltStart") and b:GetAttribute("BeltEnd") then
		rec.beltLooks = {}
		for i = 1, BELT_N do
			local look = DalgonaLook.build({ s = fac:GetAttribute("Line1Shape") or "Circle", g = "Good" }, 0.9)
			look.Name = "BeltDalgona" .. i
			-- 공장 부지 밖 폴더에 둠: 부지 안에 넣으면 부품이 들어올 때마다 공장을 다시 훑는 감시(onAdded)가 되풀이됨
			look.Parent = beltFolder()
			rec.beltLooks[i] = look
		end
	end
	-- 경첩으로 도는 부품(레버·뚜껑·커튼): 처음 자세 기준 경첩 자리와 축 (건물 기준 좌우축 = 기계 X축)
	-- 기계 좌우축 = 벨트가 흐르는 방향 (시작 → 끝). 레버·뚜껑은 이 축으로 돌면 앞(제어대 쪽)으로 넘어옴 (3D 세션 메모)
	local bp = b:GetPivot()
	local s0, s1 = b:GetAttribute("BeltStart"), b:GetAttribute("BeltEnd")
	local flow = (s0 and s1) and ((bp * s1).Position - (bp * s0).Position) or bp.RightVector
	flow = Vector3.new(flow.X, 0, flow.Z)
	flow = flow.Magnitude > 1e-3 and flow.Unit or Vector3.xAxis
	for _, e in ipairs(rec.parts) do
		local cf, sz = e.cf, e.size or e.p.Size
		local half = (cf - cf.Position):VectorToWorldSpace(sz / 2)
		local ext = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
		if e.a == "lever" or e.a == "lid" then
			e.hinge = cf.Position - Vector3.new(0, ext.Y, 0) -- 아래 끝 = 경첩
			e.hAxis = flow
		elseif e.a == "curtain" then
			e.hinge = cf.Position + Vector3.new(0, ext.Y, 0) -- 윗변 = 경첩
			-- 커튼 폭 방향(가로로 긴 쪽)이 축 → 벨트 방향으로 흔들림
			e.hAxis = (ext.X >= ext.Z) and Vector3.xAxis or Vector3.zAxis
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
	local t = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = UI.F.heavy, TextScaled = true, TextColor3 = Color3.fromRGB(255, 240, 160), TextStrokeTransparency = 0.3, Text = string.format("+%d개 (진열 %d · 보관함 %d)", count, slots, math.max(0, count - slots)), Parent = bb })
	TweenService:Create(bb, TweenInfo.new(1.8), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.9, function()
		bb:Destroy()
	end)
end

-- ── 공장 공정 알바생 (D30): 고용한 공정의 미니미가 그 공정 동작을 되풀이. 멀거나(STAFF_DIST) 쉬면 멈춘 자세 ──
-- 미니미 = FactoryLot.Staff.Staff_<key> (서버 FactoryDisplay), 일하는지 = Factory<i> 속성 StaffOn_<key>
local STAFF_DIST = 60
local STAFF_SHOW = 20 -- 공장 건물 상자에서 이만큼 안이면 공정 알바가 보임 (공장 안·문 앞)
local staffBox = setmetatable({}, { __mode = "k" }) -- [Building] = { cf, half }
local JOINTS = { R = { "RightUpperArm", "RightShoulder" }, L = { "LeftUpperArm", "LeftShoulder" }, W = { "UpperTorso", "Waist" }, N = { "Head", "Neck" } }
local MOTION = {
	-- 공정마다 팔·허리·고개 각도(라디안)를 시간 t로: 설탕 붓기 · 솥 젓기 · 레버 당기기 · 들여다보기 · 상자 접기
	sugar = function(t)
		local k = (math.sin(t * 2.4) + 1) / 2
		return { R = CFrame.Angles(math.rad(-40 - 70 * k), 0, math.rad(-20 * k)), N = CFrame.Angles(math.rad(-10), 0, 0) }
	end,
	boil = function(t)
		return { R = CFrame.Angles(math.rad(-55 + 12 * math.sin(t * 4)), math.rad(18 * math.cos(t * 4)), 0), L = CFrame.Angles(math.rad(-30), 0, 0), W = CFrame.Angles(0, math.rad(8 * math.sin(t * 4)), 0) }
	end,
	press = function(t)
		local k = math.max(0, math.sin(t * 1.8))
		return { R = CFrame.Angles(math.rad(-120 + 90 * k), 0, 0), L = CFrame.Angles(math.rad(-120 + 90 * k), 0, 0), W = CFrame.Angles(math.rad(12 * k), 0, 0) }
	end,
	inspect = function(t)
		return { R = CFrame.Angles(math.rad(-80), 0, math.rad(-10)), W = CFrame.Angles(math.rad(18), math.rad(15 * math.sin(t * 0.9)), 0), N = CFrame.Angles(math.rad(-15), math.rad(20 * math.sin(t * 0.9)), 0) }
	end,
	pack = function(t)
		local k = (math.sin(t * 3) + 1) / 2
		return { R = CFrame.Angles(math.rad(-60), 0, math.rad(-25 + 35 * k)), L = CFrame.Angles(math.rad(-60), 0, math.rad(25 - 35 * k)), W = CFrame.Angles(math.rad(10), 0, 0) }
	end,
}
local function setPose(m, pose)
	for key, j in pairs(JOINTS) do
		local part = m:FindFirstChild(j[1])
		local motor = part and part:FindFirstChild(j[2])
		if motor and motor:IsA("Motor6D") then
			local base = motor:GetAttribute("BaseC0")
			if base == nil then
				base = motor.C0
				motor:SetAttribute("BaseC0", base)
			end
			motor.C0 = pose and pose[key] and base * pose[key] or base
		elseif motor and motor:IsA("AnimationConstraint") then
			-- 새 아바타 관절(AnimationConstraint): 자세는 Transform으로. 앞뒤(X) 회전 방향이 Motor6D와 반대라 X만 뒤집음
			-- (2026-11-24 가게 알바에서 손이 몸 뒤로 가는 것을 확인)
			local cf = pose and pose[key]
			if cf then
				local rx, ry, rz = cf:ToEulerAnglesXYZ()
				cf = CFrame.Angles(-rx, ry, rz)
			end
			motor.Transform = cf or CFrame.identity
		end
	end
end
local function animateStaff(fac, now, camPos)
	local i = tonumber(fac.Name:match("%d+"))
	local plots = workspace:FindFirstChild("ShopPlots")
	local plot = plots and i and plots:FindFirstChild("Plot" .. i)
	local lot = plot and plot:FindFirstChild("FactoryLot")
	local folder = lot and lot:FindFirstChild("Staff")
	if not folder then
		return
	end
	-- 공장 공정 알바 5명은 공장 안·앞에서만 보임 (D43, 2026-11-24): 카메라가 공장 건물 상자에서 STAFF_SHOW 안이면 보임
	-- (건물 피벗은 건물 가운데가 아니라 멀리 있을 수 있어서 상자로 잼. 상자는 한 번만 재서 기억)
	local b = lot:FindFirstChild("Building")
	local show = false
	if b then
		local box = staffBox[b]
		if not box then
			local cf, size = b:GetBoundingBox()
			box = { cf = cf, half = size / 2 }
			staffBox[b] = box
		end
		local lp = box.cf:PointToObjectSpace(camPos)
		show = math.abs(lp.X) < box.half.X + STAFF_SHOW and math.abs(lp.Z) < box.half.Z + STAFF_SHOW and math.abs(lp.Y) < box.half.Y + STAFF_SHOW * 2
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("Shown") ~= show then
			m:SetAttribute("Shown", show)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = show and 0 or 1
				elseif d:IsA("BillboardGui") then
					d.Enabled = show
				end
			end
		end
	end
	if not show then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		local key = m:GetAttribute("StaffKey")
		local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		if key and root then
			local on = fac:GetAttribute("StaffOn_" .. key) == true
			local near = (root.Position - camPos).Magnitude < STAFF_DIST
			if on and near and MOTION[key] then
				setPose(m, MOTION[key](now + #key * 0.37))
				m:SetAttribute("Posed", true)
			elseif m:GetAttribute("Posed") then
				setPose(m, nil) -- 멈춘 자세 (멀리 있거나 쉬는 중)
				m:SetAttribute("Posed", false)
			end
			-- 머리 위 글: 공정 이름 · 일하는 중/쉬는 중
			local t = m:FindFirstChild("TextLabel", true)
			local base = m:GetAttribute("StationName")
			if t and base then
				local want = base .. (on and " · 일하는 중" or " · 쉬는 중")
				if t.Text ~= want then
					t.Text = want
				end
			end
		end
	end
end

-- ── 매 프레임: 움직임 · 표시등 · 상태판 ──
-- 공정 알바 자세는 PreSimulation(애니메이션 다음, 물리 전)에: 미니미 Animator가 매 프레임 관절 Transform을 지우므로
-- Heartbeat에서 넣으면 화면에 안 나옴 (2026-11-24 가게 알바에서 확인)
RunService.PreSimulation:Connect(function()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local now = workspace:GetServerTimeNow()
	for fac, rec in pairs(factories) do
		if rec.building.Parent then
			animateStaff(fac, now, camPos)
		end
	end
end)
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for fac, rec in pairs(factories) do
		if not rec.building.Parent then
			for _, l in ipairs(rec.beltLooks or {}) do
				l:Destroy()
			end
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
				rec.head.Text = "달고나 공장 · 멈춤: " .. status
				rec.head.TextColor3 = Color3.fromRGB(255, 130, 120)
			elseif running then
				rec.head.Text = "달고나 공장 · 가동 중 · " .. (MODE_NAME[fac:GetAttribute("Mode")] or "일반")
				rec.head.TextColor3 = MINT
			else
				rec.head.Text = "달고나 공장 · 꺼짐"
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
				elseif a == "feed" then
					-- ① 공급관: 작게 흔들림
					local r = running and math.sin(now * 7 + e.phase) * math.rad(1) or 0
					p.CFrame = e.cf * CFrame.Angles(r, 0, r * 0.6)
				elseif a == "stir" then
					-- ② 젓개: 세로축으로 천천히 돎
					if running then
						e.ang = (e.ang or 0) + 0.04
					end
					p.CFrame = CFrame.new(e.cf.Position) * CFrame.Angles(0, e.ang or 0, 0) * e.cf.Rotation
				elseif a == "gauge" then
					-- ② 계기 바늘: 돌 때 -60° → +60° 로 오르고 (끓음) 되풀이, 멈추면 -60°
					local k = running and ((now * 0.25 + e.phase) % 1) or 0
					p.CFrame = e.cf * CFrame.fromAxisAngle(e.axis, math.rad(-60 + 120 * math.sin(k * math.pi * 0.5)))
				elseif a == "heat" then
					-- ② 가열 띠: 돌 때 빨강
					p.Material = running and Enum.Material.Neon or e.mat
					p.Color = running and HEAT:Lerp(e.color, 0.25 + 0.2 * math.sin(now * 3)) or e.color
				elseif a == "nozzle" then
					-- ③ 노즐: 붓는 순간(프레스 박자 사이) 살짝 내려왔다 올라감
					local k = running and math.max(0, math.sin(now * 2.2 + 1.2)) or 0
					p.CFrame = e.cf - Vector3.new(0, k * 0.22, 0)
				elseif a == "drip" then
					-- ③ 방울: 노즐 끝에서 떨어지며 작아지고 투명 → 다시
					if running then
						local k = (now * 1.1 + e.phase) % 1
						p.CFrame = e.cf - Vector3.new(0, k * 0.88, 0)
						p.Size = e.size * (1 - 0.6 * k)
						p.Transparency = math.min(1, (e.t0 or 0) + k)
					else
						p.CFrame = e.cf
						p.Size = e.size
						p.Transparency = e.t0 or 0
					end
				elseif a == "lever" then
					-- ③ 레버: 프레스 박자에 앞으로 ~40° 당김
					local k = running and (1 - math.abs(math.sin(now * 2.2))) or 0
					if e.hinge then
						p.CFrame = hingeTurn(e.cf, e.hinge, e.hAxis, math.rad(40) * k)
					end
				elseif a == "curtain" then
					-- ④ 비닐 커튼: 윗변 경첩으로 ±10° 흔들림
					local r = running and math.sin(now * 2.6 + e.phase) * math.rad(10) or 0
					if e.hinge then
						p.CFrame = hingeTurn(e.cf, e.hinge, e.hAxis, r)
					end
				elseif a == "lid" then
					-- ⑤ 상자 뚜껑: 돌 때 6초마다 잠깐 닫혔다 열림 (상자 하나 다 담음)
					local c = running and ((now + e.phase) % 6) or 0
					local k = (c > 4.6 and c < 5.8) and math.sin((c - 4.6) / 1.2 * math.pi) or 0
					if e.hinge then
						p.CFrame = hingeTurn(e.cf, e.hinge, e.hAxis, math.rad(100) * k * (e.lidSign or 1))
					end
				elseif a == "stationLamp" then
					-- 공정 표시등: 그 공정 알바가 일하면 켜짐
					local on = e.key ~= nil and fac:GetAttribute("StaffOn_" .. e.key) == true
					p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
					p.Color = on and e.color or e.color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.5)
				elseif a == "hanger" then
					-- 빈 작업복 걸이: 그 공정 알바를 고용하면 숨김
					local hired = e.key ~= nil and fac:GetAttribute("Staff_" .. e.key) == true
					p.LocalTransparencyModifier = hired and 1 or 0
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
		-- 컨베이어 위 달고나 BELT_N개: 시작 → 끝으로 흘러가고 되풀이 (멈추면 그 자리에 섬)
		if rec.beltLooks then
			local bp = rec.building:GetPivot()
			local s0, s1 = rec.building:GetAttribute("BeltStart"), rec.building:GetAttribute("BeltEnd")
			if s0 and s1 then
				local a0, a1 = (bp * s0).Position, (bp * s1).Position
				if running then
					rec.beltT = (rec.beltT or 0) + (now - (rec.beltLast or now)) * 0.08
				end
				rec.beltLast = now
				for i, look in ipairs(rec.beltLooks) do
					local k = ((rec.beltT or 0) + (i - 1) / BELT_N) % 1
					local pos = a0:Lerp(a1, k)
					look:PivotTo(CFrame.new(pos) * CFrame.Angles(math.rad(90), 0, 0))
				end
			end
		end
	end
end)

-- ── 제어대 화면 (FACTORY CONTROL) ──
local state = nil
local gui = UI.screen("FactoryUi", 7, player:WaitForChild("PlayerGui"))
gui.Enabled = false
-- 폰 가로 화면에 맞춘 넓고 낮은 나무 판 창 + 왼쪽 세로 탭 (사용자 참고 그림의 "공장 설비" 창)
local fitRoot = UI.root(gui)
local fitWin = UI.fitter(fitRoot)
local win, body = UI.window({ Name = "Window", Title = "공장 제어대", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(800, 360), ZIndex = 10, Visible = true, Parent = fitRoot })
fitWin(win, 800, 385)
body.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local closeBtn = win.Close
-- 버튼 꾸미기 (TextButton 그대로: .Text·.BackgroundColor3를 바꾸는 코드가 그대로 동작)
local function candy(b, color)
	b.AutoButtonColor = true
	b.FontFace = UI.F.heavy
	if color then
		b.BackgroundColor3 = color
	end
	b.TextColor3 = Color3.new(1, 1, 1)
	new("UIStroke", { Color = UI.C.woodDark, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	new("UIStroke", { Color = UI.C.woodDark, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = b })
	UI.gloss(0.2).Parent = b
	return b
end
-- 왼쪽 세로 탭 + 아래 상태 칩
local tabCol = new("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(0, 130, 1, -24), BackgroundTransparency = 1, ZIndex = 12, Parent = body })
local tabs = {}
local pages = {}
local function tabButton(i, text)
	local b = new("TextButton", { Position = UDim2.fromOffset(0, (i - 1) * 52), Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = UI.C.woodLight, TextSize = 20, Text = text, ZIndex = 12, Parent = tabCol })
	corner(b, 14)
	candy(b)
	tabs[i] = b
	pages[i] = new("Frame", { Position = UDim2.fromOffset(152, 10), Size = UDim2.new(1, -162, 1, -20), BackgroundTransparency = 1, Visible = i == 1, ZIndex = 12, Parent = body })
	return b
end
tabButton(1, "생산")
tabButton(2, "업그레이드")
tabButton(3, "알바생") -- 공정별 알바생 고용 (D30)
-- 상태 칩 (가동 중 · 꺼짐 · 멈춘 이유)
local chip = UI.text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 0, BackgroundColor3 = UI.C.woodDark, TextSize = 15, TextColor3 = MINT, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Text = "", ZIndex = 13, Parent = tabCol })
corner(chip, 17)
local msgL = UI.text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Outline = RED, TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 12, Parent = win })
-- msgL 색(초록/빨강)은 나무 판 위 흰 글씨의 테두리 색으로 보여 줌
msgL:GetPropertyChangedSignal("TextColor3"):Connect(function()
	local c = msgL.TextColor3
	if c ~= Color3.new(1, 1, 1) then
		msgL:FindFirstChildOfClass("UIStroke").Color = c
		msgL.TextColor3 = Color3.new(1, 1, 1)
	end
end)

-- 생산 탭: 왼쪽 도안 카드, 오른쪽 수량·방식·예상·라인 진행·시작/멈춤
local prod = pages[1]
UI.text({ Size = UDim2.new(0.55, -8, 0, 20), TextSize = 18, TextColor3 = UI.C.cream, Outline = UI.C.woodDark, Text = "① 생산할 도안", ZIndex = 12, Parent = prod })
local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(0.55, -8, 1, -24), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = UI.C.cream, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 12, Parent = prod })
new("UIGridLayout", { CellSize = UDim2.fromOffset(102, 112), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
local right = UI.card({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.45, -4, 1, 0), ZIndex = 12, Parent = prod })
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), Parent = right })
local function rtext(y, h, size, bold, text)
	return new("TextLabel", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, FontFace = bold and UI.F.heavy or UI.F.bold, TextSize = size, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = BROWN, Text = text or "", ZIndex = 13, Parent = right })
end
rtext(0, 20, 17, true, "② 생산 수량")
local qtyRow = new("Frame", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 13, Parent = right })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = qtyRow })
rtext(60, 20, 17, true, "③ 생산 방식")
local modeRow = new("Frame", { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 13, Parent = right })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = modeRow })
local modeDesc = rtext(120, 34, 14, false, "")
modeDesc.TextColor3 = SOFT
local previewL = rtext(156, 36, 14, false, "")
local jobsL = rtext(196, 56, 14, false, "")
-- 생산 시작/멈추기는 왼쪽 탭 아래 (어느 탭에서나 보이게, 폰에서 오른쪽 칸 글씨를 크게 쓰려고)
local runBtn = new("TextButton", { Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = GREEN, TextSize = 18, Text = "생산 시작", ZIndex = 13, Parent = tabCol })
corner(runBtn, 14)
candy(runBtn)

-- 업그레이드 탭
local upList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = UI.C.cream, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 12, Parent = pages[2] })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = upList })

-- 알바생 탭: 공정 5곳마다 효과 · 고용비 · 급여 · 고용/내보내기 (D30)
local staffList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = UI.C.cream, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 12, Parent = pages[3] })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = staffList })

local function selectTab(i)
	for k, p in ipairs(pages) do
		p.Visible = k == i
		tabs[k].BackgroundColor3 = k == i and UI.C.yellow or UI.C.woodLight
		tabs[k]:FindFirstChildOfClass("UIStroke").Color = k == i and UI.C.cream or UI.C.woodDark
	end
end
selectTab(1)
for i, b in ipairs(tabs) do
	b.Activated:Connect(function()
		selectTab(i)
	end)
end

local function preview(parent, entry)
	local vpf = new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(226, 172, 96), Ambient = Color3.fromRGB(190, 190, 195), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6), Size = UDim2.new(1, -10, 1, -34), Position = UDim2.fromOffset(5, 5), ZIndex = 14, Parent = parent })
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
local showSelf -- D45 알림판 (아래에서 정의)
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
	local b = new("TextButton", { Size = UDim2.fromOffset(78, 34), BackgroundColor3 = on and UI.C.yellow or UI.C.tan, FontFace = UI.F.heavy, TextSize = 16, TextColor3 = on and UI.C.woodDark or BROWN, Text = text, ZIndex = 14, Parent = parent })
	corner(b, 12)
	new("UIStroke", { Color = on and UI.C.woodDark or UI.C.line, Thickness = on and 2.5 or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
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
	chip.Text = (st == "work" and "● 가동 중") or (st == "off" and "○ 꺼짐") or ("멈춤: " .. st)
	chip.TextColor3 = (st == "work" and Color3.fromRGB(150, 230, 120)) or (st == "off" and UI.C.tan) or Color3.fromRGB(255, 140, 120)
	local function set(shape, qty, mode)
		act("factorySet", { shape = shape or f.shape, qty = qty or f.qty, mode = mode or f.mode })
	end
	-- ① 도안 카드
	for i, id in ipairs(f.shapes or {}) do
		local e = ShapeCatalog.get(id)
		if e then
			local g = ShapeCatalog.grade(e.grade)
			local chosen = id == f.shape
			local card = new("TextButton", { LayoutOrder = i, BackgroundColor3 = CREAM, Text = "", ZIndex = 13, Parent = grid })
			corner(card, 10)
			new("UIStroke", { Color = chosen and UI.C.good or (g and g.color or SOFT), Thickness = chosen and 4 or 2, Parent = card })
			preview(card, e)
			new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -13), Size = UDim2.new(1, -6, 0, 15), BackgroundTransparency = 1, FontFace = UI.F.heavy, TextSize = 16, TextColor3 = BROWN, Text = e.name, ZIndex = 14, Parent = card })
			new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -6, 0, 12), BackgroundTransparency = 1, FontFace = UI.F.heavy, TextSize = 12, TextColor3 = chosen and UI.C.good or (g and g.color or SOFT), Text = chosen and "선택됨" or (g and g.label or ""), ZIndex = 14, Parent = card })
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
			b.BackgroundColor3 = Color3.fromRGB(225, 212, 190)
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
		local row = UI.card({ LayoutOrder = i, Size = UDim2.new(1, -10, 0, 68), ZIndex = 13, Parent = upList })
		new("TextLabel", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -190, 0, 22), BackgroundTransparency = 1, FontFace = UI.F.heavy, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, Text = u.name or u.key, ZIndex = 14, Parent = row })
		new("TextLabel", { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -190, 0, 30), BackgroundTransparency = 1, FontFace = UI.F.bold, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = SOFT, Text = u.desc or "", ZIndex = 14, Parent = row })
		local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 48), BackgroundColor3 = u.cost and UI.C.yellow or UI.C.grey, TextSize = 18, Text = u.cost and (tostring(u.cost) .. " 코인") or "완료", ZIndex = 14, Parent = row })
		corner(b, 14)
		candy(b)
		b.Activated:Connect(function()
			if u.cost then
				act("factoryUp", u.key)
			end
		end)
		table.insert(made, row)
	end
	-- 알바생 (공정별 고용)
	local STAFF_COLOR = { sugar = Color3.fromRGB(240, 240, 240), boil = Color3.fromRGB(220, 70, 70), press = Color3.fromRGB(255, 205, 60), inspect = Color3.fromRGB(140, 200, 240), pack = Color3.fromRGB(80, 130, 220) }
	for i, s in ipairs(f.staff or {}) do
		local mine = s.self == true -- D45: 내가 이 공정을 맡는 중 (서버 staff[i].self)
		local row = UI.card({ LayoutOrder = i, Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = mine and Color3.fromRGB(255, 240, 200) or nil, ZIndex = 13, Parent = staffList })
		if mine then
			row:FindFirstChildOfClass("UIStroke").Color = UI.C.gold
			row:FindFirstChildOfClass("UIStroke").Thickness = 4
		end
		local chipC = new("TextLabel", { Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = STAFF_COLOR[s.key] or SOFT, FontFace = UI.F.round, TextSize = 22, TextColor3 = s.key == "sugar" and BROWN or Color3.new(1, 1, 1), Text = tostring(i), ZIndex = 14, Parent = row })
		corner(chipC, 22)
		new("UIStroke", { Color = UI.C.woodDark, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chipC })
		local selfBtn = (not s.hired) and (s.canSelf or mine) -- 알바 없는 자리 = [내가 하기] (서버 staff[i].canSelf)
		local textW = selfBtn and -360 or -240 -- 버튼 두 개면 글씨 칸을 줄임
		new("TextLabel", { Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, textW, 0, 22), BackgroundTransparency = 1, FontFace = UI.F.heavy, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BROWN, TextTruncate = Enum.TextTruncate.AtEnd, Text = (s.name or s.key) .. (s.hired and (s.on and "  · 일하는 중" or "  · 쉬는 중") or (mine and "  · 🙋 내가 하는 중" or "")), ZIndex = 14, Parent = row })
		new("TextLabel", { Position = UDim2.fromOffset(66, 30), Size = UDim2.new(1, textW, 0, 38), BackgroundTransparency = 1, FontFace = UI.F.bold, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = SOFT, Text = string.format("%s\n급여 30초당 6 · 이번 판 %s 코인", s.desc or "", tostring(s.wage or 0)), ZIndex = 14, Parent = row })
		local hireCost = f.staffHireCost or 10000
		local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(s.hired and 170 or 160, 48), BackgroundColor3 = s.hired and RED or GREEN, TextSize = 17, Text = s.hired and "내보내기" or string.format("고용 · %d", hireCost), ZIndex = 14, Parent = row })
		corner(b, 14)
		candy(b)
		b.Activated:Connect(function()
			act(s.hired and "factoryFire" or "factoryHire", s.key)
		end)
		-- [내가 하기] (D45): 알바가 없는 자리만. 맡는 중이면 [그만하기]
		if selfBtn then
			local me = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -178, 0.5, 0), Size = UDim2.fromOffset(118, 48), BackgroundColor3 = mine and RED or UI.C.blue, TextSize = 17, Text = mine and "그만하기" or "내가 하기", ZIndex = 14, Parent = row })
			corner(me, 14)
			candy(me)
			me.Activated:Connect(function()
				-- 같은 공정을 다시 누르면 그만, 다른 공정이면 옮김 (서버 토글). 공장 방 밖이면 서버가 이유를 돌려줌 (msgL)
				act("factorySelf", s.key)
			end)
		end
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

-- D45 "내가 하기" 맡는 동안 화면 위 가운데 알림판 (창을 닫아도 보임): 🙋 내가 ② 끓이기 하는 중 · [그만하기]
-- 서버 (feat/factory-self-1124): growth.factory.staff[i].self = 내가 하는 중, .canSelf = 알바 없는 자리(버튼 보임),
--   Remotes.GrowthAction("factorySelf", key) = 시작 / 같은 key 다시 = 그만 / 다른 key = 옮김. 플레이어 속성 FactorySelf = 지금 공정 key
local selfGui = UI.screen("FactorySelf", 7, player:WaitForChild("PlayerGui"))
local selfRoot = UI.root(selfGui)
local selfFit = UI.fitter(selfRoot)
local selfPill = UI.card({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(0, 52), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(255, 240, 200), Visible = false, ZIndex = 5, Parent = selfRoot })
selfPill:FindFirstChildOfClass("UIStroke").Color = UI.C.woodDark
selfPill:FindFirstChildOfClass("UIStroke").Thickness = 3
selfFit(selfPill, 520, 52)
new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 8), Parent = selfPill })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), Parent = selfPill })
local selfText = UI.text({ LayoutOrder = 1, Text = "", TextSize = 19, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = selfPill })
local selfStop = UI.button({ LayoutOrder = 2, Name = "StopSelf", Text = "그만하기", Color = UI.C.red, Size = UDim2.fromOffset(110, 42), TextSize = 17, ZIndex = 6, Parent = selfPill })
local selfKey = nil
selfStop.Activated:Connect(function()
	if selfKey then
		act("factorySelf", selfKey) -- 같은 공정 다시 = 그만
	end
end)
showSelf = function(f)
	local key, name = f and f.self or nil, nil -- growth.factory.self (공정 key) 또는 staff[i].self
	for _, s in ipairs(f and f.staff or {}) do
		if s.self or (key and s.key == key) then
			key, name = s.key, s.name
		end
	end
	if not key then
		local a = player:GetAttribute("FactorySelf")
		if type(a) == "string" and a ~= "" then
			key = a
		end
	end
	selfKey = key
	selfPill.Visible = key ~= nil
	selfText.Text = string.format("🙋 내가 %s 하는 중", name or tostring(key))
end
player:GetAttributeChangedSignal("FactorySelf"):Connect(function()
	showSelf(state and state.growth and state.growth.factory)
end)

-- 알바생 고용·일하는지 바뀜을 알아보는 짧은 글 (매초 오는 갱신에서 바뀌었을 때만 다시 그림)
local function staffSig(f)
	local t = {}
	for _, s in ipairs(f and f.staff or {}) do
		table.insert(t, (s.hired and "1" or "0") .. (s.on and "1" or "0") .. (s.self and "1" or "0") .. (s.canSelf and "1" or "0"))
	end
	return table.concat(t)
end
Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(s)
	local old = state and state.growth and state.growth.factory
	state = s
	local f = s and s.growth and s.growth.factory
	-- 설정·상태가 바뀌었을 때만 다시 그림 (매초 오는 진행 갱신은 글씨만)
	if gui.Enabled and f and (not old or old.shape ~= f.shape or old.qty ~= f.qty or old.mode ~= f.mode or old.on ~= f.on or old.status ~= f.status or old.lines ~= f.lines or old.maxQty ~= f.maxQty or staffSig(old) ~= staffSig(f)) then
		render()
	end
	showSelf(f)
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
	-- 가게 부지가 다시 만들어지면(주인이 나갔다 들어옴) 위 연결이 옛 부지에 걸려 있음 → 2초마다 공장 3D를 다시 찾음
	task.spawn(function()
		while fac.Parent do
			task.wait(2)
			local rec = factories[fac]
			local lot = lotOf(fac)
			local b = lot and lot:FindFirstChild("Building")
			if b and (not rec or rec.building ~= b) then
				scan(true)
				local _, p2 = lotOf(fac)
				if p2 and p2 ~= plot then
					plot = p2
					plot.DescendantAdded:Connect(onAdded)
				end
			end
		end
	end)
end

task.spawn(function()
	local folder = workspace:WaitForChild("Factories")
	for _, f in ipairs(folder:GetChildren()) do
		hook(f)
	end
	folder.ChildAdded:Connect(hook)
end)
