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

-- 손잡이를 잡고 젓기 (사용자 요청 2026-11-18: 손가락이 국자를 가리지 않게)
-- 손가락 = 젓가락 손잡이 끝. 젓는 끝은 손가락 아래 평면에서 화면 위쪽(-Z)으로 GRIP만큼 떨어진 곳
-- 손가락(손잡이)에서 젓는 끝까지 화면 위쪽 거리. 크면 젓가락이 더 눕고 끝이 위에서 잘 보임
-- (2026-11-19: 1.2면 젓가락이 카메라 쪽으로 서서 끝에 묻은 설탕·소다가 안 보임 → 1.9)
-- (2026-11-20 다시: 1.9면 국자 아랫부분을 저으려면 손가락이 화면 맨 아래까지 내려가야 함 → 1.0.
--  국자가 화면 가운데에 있어서 1.0이면 손가락이 국자 아래 가까이에서 원 전체를 저을 수 있고, 끝도 손가락에 안 가려짐)
Stir.GRIP = 1.0
-- 젓는 끝 ~ 손가락. 고른 젓가락 메시(길이 2.8)는 placeChopsticksAt 배치에서 가운데가 끝에서 1.4 → 손잡이 끝이 2.8.
-- 손가락이 손잡이 맨 끝을 잡게 2.75 (사용자 요청 2026-11-18: 더 끝부분 잡기. 고르기 화면 왼쪽 아래 끝 = 메시 -X 끝 = 손잡이)
local HANDLE_LEN = 2.75

-- 끝이 닿을 높이 y → (끝 위치, 손잡이 끝 위치). 손잡이 끝은 손가락 시선 위에서 끝과 HANDLE_LEN 떨어진 점
-- → 화면에서 손가락이 정확히 젓가락 손잡이 끝을 잡고 있음
-- 화면 위쪽 방향 (테이블 평면 위, 단위 벡터). 예전에는 만드는 동안 작업대를 원래 방향으로 되돌려 놓아서 세계 -Z가 화면 위였음.
-- 2026-11-23부터 작업대를 돌린 채 카메라가 따라가므로 세계 축 대신 카메라 위쪽을 씀 (2026-11-24 "숟가락 거꾸로", "젓가락 위가 기준점")
function Stir.screenUp()
	local up = workspace.CurrentCamera.CFrame.UpVector
	local flat = Vector3.new(up.X, 0, up.Z)
	if flat.Magnitude < 1e-3 then
		local lv = workspace.CurrentCamera.CFrame.LookVector
		flat = Vector3.new(lv.X, 0, lv.Z)
	end
	return flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
end

-- 화면 기준 방향: r = 화면 오른쪽, u = 위(세계 Y), down = 화면 아래쪽 성분 → 세계 단위 벡터.
-- 예전 코드의 세계 축 값 Vector3.new(x, y, z)는 Stir.screenDir(x, y, z)로 바꾸면 돌린 작업대에서도 같은 모습
function Stir.screenDir(r, u, down)
	local cr = workspace.CurrentCamera.CFrame.RightVector
	local right = Vector3.new(cr.X, 0, cr.Z)
	right = right.Magnitude > 1e-3 and right.Unit or Vector3.xAxis
	return (right * r + Vector3.yAxis * u - Stir.screenUp() * down).Unit
end

function Stir.grip(y)
	local f = Pointer.toPlane(y)
	local tip = f + Stir.screenUp() * Stir.GRIP
	return tip, Stir.handleFor(tip)
end

-- 끝 위치 tip → 손잡이 끝 (손가락 시선 위, 끝에서 HANDLE_LEN 떨어진 카메라 쪽 점)
function Stir.handleFor(tip)
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(Pointer.pos.X, Pointer.pos.Y)
	local o, u = ray.Origin, ray.Direction.Unit
	local w = o - tip
	local b = w:Dot(u)
	local disc = b * b - (w:Dot(w) - HANDLE_LEN * HANDLE_LEN)
	if disc <= 0 then
		return tip + Vector3.new(0, 1.0, 0) - Stir.screenUp() * Stir.GRIP
	end
	return o + u * (-b - math.sqrt(disc)) -- 카메라 쪽 교점
end

-- 나무젓가락 끝을 국자 안 world 위치에 둔다 (handle: 손잡이 쪽 점, 없으면 기본 기울기)
function Stir.placeChopsticks(station, world, handle)
	local bowl = station.Bowl.Position
	local top = station:contentsTopY()
	local flat = Vector3.new(world.X - bowl.X, 0, world.Z - bowl.Z)
	local r = station.bowlRadius - 0.2
	if flat.Magnitude > r then
		flat = flat.Unit * r
	end
	return Stir.placeChopsticksAt(station, Vector3.new(bowl.X, top - 0.04, bowl.Z) + flat, handle)
end

-- 나무젓가락 끝을 아무 world 위치에 둔다 (국자 밖도: 소다 찍기)
function Stir.placeChopsticksAt(station, tip, handle)
	local dir = Stir.screenDir(0.35, 1, 0.55)
	if handle then
		local d = handle - tip
		if d.Magnitude > 0.2 and d.Y > 0.3 then
			dir = d.Unit -- 끝에서 손가락(손잡이) 쪽으로 기울어짐
		end
	end
	station.stickDir = dir
	local cf = CFrame.lookAt(tip + dir * 1.3, tip) -- 젓가락 메시 중심은 끝에서 1.2, 길이 2.8 → 손잡이 끝은 끝에서 약 2.6
	local m = station.Chopsticks
	m.Stick1.CFrame = cf
	m.Stick2.CFrame = cf * CFrame.new(0.12, 0, 0.02)
	-- 고른 나무젓가락 메시 (길이 축을 젓가락 방향으로). 가는 끝이 국자 안, 굵은 손잡이 쪽이 손가락 쪽
	-- (예전엔 거꾸로 들어가 손잡이 쪽으로 저었음 → 길이 방향으로 180° 뒤집음)
	local chosen = m:FindFirstChild("Chosen")
	if chosen then
		chosen.CFrame = cf * CFrame.new(0, 0, 0.1) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(math.rad(90), 0, 0) * (chosen:GetAttribute("Fix") and CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.pi, 0, 0) or CFrame.new())
	end
	return tip
end

return Stir
