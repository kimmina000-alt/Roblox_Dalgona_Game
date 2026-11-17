-- 원 그리며 젓기: 손가락 각속도(0.45초 평균)와 원의 중심 높이를 잰다.
-- 녹이기와 소다 젓기가 같이 쓴다. 나무젓가락이 손가락 위치를 따라감.

local Pointer = require(script.Parent:WaitForChild("Pointer"))

local Stir = {}
Stir.__index = Stir

function Stir.new()
	return setmetatable({ center = nil, lastAngle = nil, speed = 0, presses = -1, active = false }, Stir)
end

function Stir:update(dt)
	if not Pointer.down then
		self.speed *= math.exp(-dt * 6)
		self.lastAngle = nil
		self.active = false
		return self.speed
	end
	local p = Pointer.pos
	if Pointer.presses ~= self.presses then
		self.presses = Pointer.presses
		self.center = p
		self.lastAngle = nil
	end
	self.active = true
	-- 원의 중심 = 손가락 위치의 느린 평균
	self.center = self.center:Lerp(p, 1 - math.exp(-dt * 1.7))
	local d = p - self.center
	if d.Magnitude < 6 then
		self.speed *= math.exp(-dt * 3)
		return self.speed
	end
	local a = math.atan2(d.Y, d.X)
	if self.lastAngle and dt > 0 then
		local da = a - self.lastAngle
		if da > math.pi then
			da -= 2 * math.pi
		elseif da < -math.pi then
			da += 2 * math.pi
		end
		local inst = math.min(math.abs(da) / dt, 40)
		self.speed += (inst - self.speed) * (1 - math.exp(-dt / 0.45))
	end
	self.lastAngle = a
	return self.speed
end

-- 1 = 느림, 2 = 적당, 3 = 빠름
function Stir.zone(speed, slow, fast)
	if speed < slow then
		return 1
	elseif speed > fast then
		return 3
	end
	return 2
end

-- 원 중심의 화면 높이 (0 = 위, 1 = 아래)
function Stir:centerHeight01()
	if not self.center then
		return nil
	end
	local vh = workspace.CurrentCamera.ViewportSize.Y
	return math.clamp(self.center.Y / vh, 0, 1)
end

-- 나무젓가락 끝을 국자 안 world 위치에 둔다
function Stir.placeChopsticks(station, world)
	local bowl = station.Bowl.Position
	local top = station:contentsTopY()
	local flat = Vector3.new(world.X - bowl.X, 0, world.Z - bowl.Z)
	local r = station.bowlRadius - 0.2
	if flat.Magnitude > r then
		flat = flat.Unit * r
	end
	local tip = Vector3.new(bowl.X, top - 0.04, bowl.Z) + flat
	local dir = Vector3.new(0.35, 1, 0.55).Unit
	local cf = CFrame.lookAt(tip + dir * 1.3, tip)
	local m = station.Chopsticks
	m.Stick1.CFrame = cf
	m.Stick2.CFrame = cf * CFrame.new(0.12, 0, 0.02)
	-- 고른 나무젓가락 메시 (길이 축 Y를 젓가락 방향으로, 아래쪽 끝이 국자 안)
	local chosen = m:FindFirstChild("Chosen")
	if chosen then
		chosen.CFrame = cf * CFrame.new(0, 0, 0.1) * CFrame.Angles(math.rad(90), 0, 0) * (chosen:GetAttribute("Fix") and CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.pi, 0, 0) or CFrame.new())
	end
	return tip
end

return Stir
