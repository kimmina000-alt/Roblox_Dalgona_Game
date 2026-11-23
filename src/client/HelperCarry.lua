-- 알바생이 달고나를 들고 진열대까지 걸어갔다 돌아오는 연출 (2026-11-24 사용자 "알바가 달고나를 들고 진열대로").
-- 서버(GrowthService stepCarry, G.CarryHelpers)가 정함: 4단계 라인 알바(Plot.Helper_line)·공장 포장 알바(FactoryLot.Staff.Staff_pack)가
-- 그 기계·공장이 만든 달고나를 하나씩 빈 칸에 예약하고 들고 감. 서버는 걷는 동안 미니미를 옮기지 않고 속성만 줌:
--   CarryState "go"(가는 중) | "back"(돌아오는 중) | "", CarryShape(든 도안, 돌아올 때 ""면 빈손), CarrySlot, CarryFrom·CarryTo(Vector3),
--   CarryStart(서버 시각), CarryDur(초 = 걷기 + 집기·놓기 G.CarryHelpers.pickSeconds)
-- 여기서는 그 시각표대로 내 화면에서만 모델을 PivotTo로 옮기고 다리·팔을 움직임. 걷는 동안 속성 Carrying = true (내 화면에만) →
-- 자리 동작(FactoryClient·MachineClient 자세)은 이 모델을 건드리지 않고, 공장 알바는 공장 밖에서도 보임.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DalgonaLook = require(Shared:WaitForChild("DalgonaLook"))
local GrowthConfig = require(Shared:WaitForChild("GrowthConfig"))
local WalkPath = require(Shared:WaitForChild("WalkPath"))

local HelperCarry = {}

local CH = GrowthConfig.CarryHelpers or {}
local PICK = CH.pickSeconds or 0.6
local STOP = 2.2 -- 진열 칸에서 이만큼 앞에 섬

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

local function pose(m, phase, walking, holding)
	local s = walking and math.sin(phase) or 0
	setJoint(m, "RH", CFrame.Angles(math.rad(32 * s), 0, 0))
	setJoint(m, "LH", CFrame.Angles(math.rad(-32 * s), 0, 0))
	setJoint(m, "RK", CFrame.Angles(math.rad(-28 * math.max(0, -s)), 0, 0))
	setJoint(m, "LK", CFrame.Angles(math.rad(-28 * math.max(0, s)), 0, 0))
	if holding then
		setJoint(m, "RS", CFrame.Angles(math.rad(-75), 0, math.rad(10)))
		setJoint(m, "LS", CFrame.Angles(math.rad(-75), 0, math.rad(-10)))
	else
		setJoint(m, "RS", CFrame.Angles(math.rad(-25 * s), 0, 0))
		setJoint(m, "LS", CFrame.Angles(math.rad(25 * s), 0, 0))
	end
end

local function resetJoints(m)
	for key in pairs(J) do
		setJoint(m, key, CFrame.identity)
	end
end

local function makeLook(shape)
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
	return look
end

-- [모델] = { home = 처음 자리 CFrame, key = 지금 신호(상태+시작 시각), look = 든 달고나 }
-- 약한 표(__mode "k")는 쓰지 않음: Instance 키가 걷는 도중 사라져 처음 자리를 진열대 앞으로 다시 잼 (2026-11-24 확인). 없어진 모델은 아래에서 지움
local active = {}

function HelperCarry.isBusy(m)
	return active[m] ~= nil
end

local function stop(m, rec)
	if rec.look then
		rec.look:Destroy()
	end
	if m.Parent then
		m:PivotTo(rec.home)
		resetJoints(m)
		m:SetAttribute("Carrying", nil)
	end
	active[m] = nil
end

-- 한 프레임: 서버 시각표대로 자리·자세를 정함
local function step(m, now)
	local state = m:GetAttribute("CarryState")
	local rec = active[m]
	if state ~= "go" and state ~= "back" then
		if rec then
			stop(m, rec)
		end
		return
	end
	local from, to = m:GetAttribute("CarryFrom"), m:GetAttribute("CarryTo")
	local t0, dur = m:GetAttribute("CarryStart"), m:GetAttribute("CarryDur")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(t0) ~= "number" or type(dur) ~= "number" then
		return
	end
	if not rec then
		rec = { home = m:GetPivot() }
		active[m] = rec
		m:SetAttribute("Carrying", true)
	end
	local shape = m:GetAttribute("CarryShape")
	local holding = type(shape) == "string" and shape ~= ""
	local key = state .. tostring(t0)
	if rec.key ~= key then
		rec.key = key
		if rec.look then
			rec.look:Destroy()
			rec.look = nil
		end
		if holding then
			rec.look = makeLook(shape)
		end
	end
	-- 걷는 길: 바닥 높이(처음 자리 Y)에서, 진열 칸 앞 STOP에 섬. go = 처음 자리 → 칸 앞, back = 칸 앞 → 처음 자리
	local y = rec.home.Position.Y
	local home = Vector3.new(rec.home.Position.X, y, rec.home.Position.Z)
	local shelf = state == "go" and to or from -- 칸 자리 (back이면 From이 칸)
	local flat = Vector3.new(shelf.X, y, shelf.Z)
	local away = home - flat
	local stand = away.Magnitude > STOP + 0.2 and flat + away.Unit * STOP or home
	local a, b = home, stand
	if state == "back" then
		a, b = stand, home
	end
	-- 벽을 돌아가는 길 (서버 HelperPath → 속성 WalkPath = 처음 자리 → 칸 앞, 2026-11-24). 첫 점은 내 화면의 처음 자리, 높이는 처음 자리 높이
	local raw = m:GetAttribute("WalkPath")
	if rec.routeRaw ~= raw or rec.routeKey ~= key then
		rec.routeRaw, rec.routeKey, rec.route = raw, key, nil
		local src = WalkPath.decode(raw)
		if src then
			local pts = { home }
			for j = 2, #src.points do
				local q = src.points[j]
				table.insert(pts, Vector3.new(q.X, y, q.Z))
			end
			rec.route = WalkPath.decode(WalkPath.encode(pts))
		end
	end
	local route = rec.route
	local walk = math.max(0.1, dur - PICK)
	local t = math.clamp(now - t0, 0, dur)
	local k = math.clamp(t / walk, 0, 1)
	local e = k < 1 and k or 1
	local pos = a:Lerp(b, e)
	local dir = b - a
	if route then
		local d2
		pos, d2 = WalkPath.sample(route, state == "go" and e or 1 - e)
		if d2 then
			dir = state == "go" and d2 or -d2
		end
	end
	local face = dir.Magnitude > 1e-3 and dir.Unit or rec.home.LookVector
	if state == "go" and k >= 1 then
		face = Vector3.new(shelf.X - pos.X, 0, shelf.Z - pos.Z)
		face = face.Magnitude > 1e-3 and face.Unit or rec.home.LookVector
	elseif state == "back" and k >= 1 then
		face = rec.home.LookVector
	end
	local walking = k < 1
	m:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(face.X, 0, face.Z)))
	pose(m, (b - a).Magnitude * e * 1.6, walking, holding)
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if rec.look and root then
		if state == "go" and k >= 1 then
			-- 칸에 내려놓음 (놓기 시간 동안 손에서 칸으로)
			local q = math.clamp((t - walk) / PICK, 0, 1)
			local hand = root.CFrame * Vector3.new(0, 0.1, -1.1)
			local p = hand:Lerp(shelf + Vector3.new(0, 0.6, 0), q) + Vector3.new(0, math.sin(math.pi * q) * 0.6, 0)
			rec.look:PivotTo(CFrame.new(p) * CFrame.Angles(math.rad(90 * q), 0, 0))
		else
			rec.look:PivotTo(root.CFrame * CFrame.new(0, 0.1, -1.1))
		end
	end
end

local started = false
function HelperCarry.start()
	if started then
		return
	end
	started = true
	-- 자세는 PreSimulation(애니메이션 다음)에: Animator가 매 프레임 관절을 지움
	RunService.PreSimulation:Connect(function()
		local plots = workspace:FindFirstChild("ShopPlots")
		if not plots then
			return
		end
		local now = workspace:GetServerTimeNow()
		for _, plot in ipairs(plots:GetChildren()) do
			local line = plot:FindFirstChild("Helper_line")
			if line then
				step(line, now)
			end
			local lot = plot:FindFirstChild("FactoryLot")
			local staff = lot and lot:FindFirstChild("Staff")
			local pack = staff and staff:FindFirstChild("Staff_pack")
			if pack then
				step(pack, now)
			end
		end
		for m, rec in pairs(active) do
			if not m.Parent then
				if rec.look then
					rec.look:Destroy()
				end
				active[m] = nil
			end
		end
	end)
end

return HelperCarry
