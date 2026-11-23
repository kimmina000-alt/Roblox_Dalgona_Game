-- 알바생이 다 만든 달고나를 들고 진열대까지 걸어갔다 돌아오는 연출 (2026-11-24 사용자 "알바가 달고나를 들고 진열대로").
-- 내 화면에서만: 서버 미니미 모델을 PivotTo로 옮기고 다리·팔 관절을 움직임. 서버 규칙(진열 칸 채우기·MadeSlots)은 그대로.
-- 쓰는 곳: FactoryClient(공장 ⑤ 포장 알바 Staff_pack), MachineClient(4단계 연속 생산 설비 알바 Helper_line).
-- 걷는 동안 모델 속성 Carrying = true → 자리 동작(FactoryClient·MachineClient 자세)이 이 모델은 건드리지 않음.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DalgonaLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaLook"))

local HelperCarry = {}

local SPEED = 7 -- 걷는 빠르기 (스터드/초)
local STOP = 2.4 -- 진열 칸에서 이만큼 앞에 섬
local MAX_WALK = 70 -- 이보다 멀면 걷지 않음 (날아가는 연출로)
local HOLD_N = 3 -- 손에 든 달고나 (보이는 개수)

-- 관절: 이름 → { 부품, 관절 }
local J = {
	RH = { "RightUpperLeg", "RightHip" },
	LH = { "LeftUpperLeg", "LeftHip" },
	RK = { "RightLowerLeg", "RightKnee" },
	LK = { "LeftLowerLeg", "LeftKnee" },
	RS = { "RightUpperArm", "RightShoulder" },
	LS = { "LeftUpperArm", "LeftShoulder" },
}

local function setJoint(m, key, cf)
	local j = J[key]
	local part = m:FindFirstChild(j[1])
	local motor = part and part:FindFirstChild(j[2])
	if motor and motor:IsA("AnimationConstraint") then
		-- 앞뒤(X) 회전이 Motor6D와 반대 (FactoryClient·MachineClient와 같음)
		local rx, ry, rz = cf:ToEulerAnglesXYZ()
		motor.Transform = CFrame.Angles(-rx, ry, rz)
	elseif motor and motor:IsA("Motor6D") then
		local base = motor:GetAttribute("BaseC0")
		if base == nil then
			base = motor.C0
			motor:SetAttribute("BaseC0", base)
		end
		motor.C0 = base * cf
	end
end

local function resetJoints(m)
	for key in pairs(J) do
		setJoint(m, key, CFrame.identity)
	end
end

-- 걷는 자세: phase = 걸은 거리 기준, carry = 두 팔을 앞으로 (쟁반 들기)
local function walkPose(m, phase, carry)
	local s = math.sin(phase)
	setJoint(m, "RH", CFrame.Angles(math.rad(32 * s), 0, 0))
	setJoint(m, "LH", CFrame.Angles(math.rad(-32 * s), 0, 0))
	setJoint(m, "RK", CFrame.Angles(math.rad(-28 * math.max(0, -s)), 0, 0))
	setJoint(m, "LK", CFrame.Angles(math.rad(-28 * math.max(0, s)), 0, 0))
	if carry then
		setJoint(m, "RS", CFrame.Angles(math.rad(-75), 0, math.rad(10)))
		setJoint(m, "LS", CFrame.Angles(math.rad(-75), 0, math.rad(-10)))
	else
		setJoint(m, "RS", CFrame.Angles(math.rad(-25 * s), 0, 0))
		setJoint(m, "LS", CFrame.Angles(math.rad(25 * s), 0, 0))
	end
end

local busy = setmetatable({}, { __mode = "k" })

function HelperCarry.isBusy(m)
	return busy[m] == true
end

-- 손에 든 달고나 묶음 (가슴 앞, 몸을 따라감)
local function makeStack(shape, n)
	local stack = {}
	for i = 1, n do
		local look = DalgonaLook.build({ s = shape, g = "Good" }, 0.8)
		for _, p in ipairs(look:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
			end
		end
		look.Parent = workspace
		stack[i] = look
	end
	return stack
end

local function placeStack(stack, root)
	for i, look in ipairs(stack) do
		if look.Parent then
			-- 몸 앞 1.1, 가슴 높이. 눕혀서 쌓음
			look:PivotTo(root.CFrame * CFrame.new(0, 0.1 + (i - 1) * 0.09, -1.1))
		end
	end
end

local function fly(look, from, to, dur)
	local t = 0
	while t < dur and look.Parent do
		t += RunService.Heartbeat:Wait()
		local k = math.min(t / dur, 1)
		local e = k * k * (3 - 2 * k)
		look:PivotTo(CFrame.new(from:Lerp(to, e) + Vector3.new(0, math.sin(math.pi * k) * 0.8, 0)) * CFrame.Angles(math.rad(90), 0, 0))
	end
end

local function fade(look)
	for _, p in ipairs(look:GetDescendants()) do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.3, function()
		look:Destroy()
	end)
end

-- m(미니미 모델)을 바닥 위 점 to까지 걸리게 함. 매 프레임 PreSimulation에서 움직임 (Animator가 관절을 지운 뒤)
local function walkTo(m, to, carry, stack)
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if not root then
		return
	end
	local done = false
	local phase = 0
	local conn
	conn = RunService.PreSimulation:Connect(function(dt)
		if not m.Parent then
			done = true
			conn:Disconnect()
			return
		end
		local pv = m:GetPivot()
		local here = pv.Position
		local d = Vector3.new(to.X - here.X, 0, to.Z - here.Z)
		local step = SPEED * dt
		if d.Magnitude <= step then
			m:PivotTo(CFrame.lookAt(Vector3.new(to.X, here.Y, to.Z), Vector3.new(to.X, here.Y, to.Z) + (d.Magnitude > 1e-3 and d.Unit or pv.LookVector)))
			resetJoints(m)
			if carry then
				setJoint(m, "RS", CFrame.Angles(math.rad(-75), 0, math.rad(10)))
				setJoint(m, "LS", CFrame.Angles(math.rad(-75), 0, math.rad(-10)))
			end
			if stack then
				placeStack(stack, root)
			end
			done = true
			conn:Disconnect()
			return
		end
		local dir = d.Unit
		-- 방향은 부드럽게 돌림
		local look = pv.LookVector:Lerp(dir, math.min(1, dt * 10))
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 1e-3 then
			look = dir
		end
		local pos = here + dir * step
		phase += step * 1.6
		m:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
		walkPose(m, phase, carry)
		if stack then
			placeStack(stack, root)
		end
	end)
	while not done do
		RunService.Heartbeat:Wait()
	end
end

-- m: 미니미 모델, targets: 진열 칸 위치(Vector3) 목록, shape: 도안 id.
-- 걸어가서 칸마다 하나씩 놓고, 원래 자리로 돌아옴. 걸을 수 없으면 false (부른 쪽이 예전 날아가는 연출을 씀)
function HelperCarry.deliver(m, targets, shape)
	if busy[m] or not m.Parent or #targets == 0 then
		return false
	end
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if not root then
		return false
	end
	local home = m:GetPivot()
	-- 진열 칸들의 가운데 앞에 섬 (알바가 있던 쪽으로 STOP만큼)
	local c = Vector3.zero
	for _, p in ipairs(targets) do
		c += p
	end
	c /= #targets
	local flat = Vector3.new(home.Position.X - c.X, 0, home.Position.Z - c.Z)
	if flat.Magnitude > MAX_WALK or flat.Magnitude < 0.5 then
		return false
	end
	local stand = Vector3.new(c.X, home.Position.Y, c.Z) + flat.Unit * STOP
	busy[m] = true
	m:SetAttribute("Carrying", true)
	task.spawn(function()
		local stack = makeStack(shape, math.min(HOLD_N, #targets))
		placeStack(stack, root)
		walkTo(m, stand, true, stack)
		-- 칸마다 하나씩 내려놓음 (손에 든 것을 차례로 쓰고, 모자라면 새로 만듦)
		for i, to in ipairs(targets) do
			if not m.Parent then
				break
			end
			local look = stack[#stack]
			if look then
				stack[#stack] = nil
			else
				look = makeStack(shape, 1)[1]
			end
			local from = root.CFrame * Vector3.new(0, 0.1, -1.1)
			fly(look, from, to, 0.35)
			fade(look)
			if i < #targets then
				task.wait(0.08)
			end
		end
		for _, look in ipairs(stack) do
			look:Destroy()
		end
		task.wait(0.25)
		if m.Parent then
			walkTo(m, home.Position, false, nil)
			m:PivotTo(home)
			resetJoints(m)
		end
		m:SetAttribute("Carrying", nil)
		busy[m] = nil
	end)
	return true
end

return HelperCarry
