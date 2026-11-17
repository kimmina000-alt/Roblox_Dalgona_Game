-- 한 손가락 / 마우스 입력을 하나로 묶는다.
-- + 옆 조작(side): sideZone(pos)이 참인 곳(녹이기·소다의 왼쪽 구역)에서 시작한 누름은 따로 받는다.
--   폰은 두 번째 손가락으로 젓는 것과 동시에, 마우스는 번갈아. 위아래로 끈 양은 takeSideDelta()로 가져감
-- pos는 InputObject.Position 좌표(위쪽 GUI 인셋 제외)라서 Camera:ScreenPointToRay와 바로 맞는다.

local UserInputService = game:GetService("UserInputService")

local Pointer = {
	down = false,
	pos = Vector2.zero,
	downPos = Vector2.zero,
	downTime = 0,
	upTime = 0,
	presses = 0, -- 누를 때마다 +1 (단계가 "새로 눌렀는지" 확인용)
	releases = 0,
	enabled = false,
	sideZone = nil, -- function(pos: Vector2) -> boolean
	side = { down = false, pos = Vector2.zero, delta = Vector2.zero },
}

local activeTouch = nil
local sideInput = nil -- 옆 조작 중인 InputObject (마우스면 "mouse")

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not Pointer.enabled or processed or not isPress(input) then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	if Pointer.sideZone and not sideInput and Pointer.sideZone(pos) and not (isMouse and Pointer.down) and input ~= activeTouch then
		sideInput = isMouse and "mouse" or input
		Pointer.side.down = true
		Pointer.side.pos = pos
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		if activeTouch then
			return
		end
		activeTouch = input
	end
	Pointer.down = true
	Pointer.pos = Vector2.new(input.Position.X, input.Position.Y)
	Pointer.downPos = Pointer.pos
	Pointer.downTime = os.clock()
	Pointer.presses += 1
end)

UserInputService.InputChanged:Connect(function(input)
	if sideInput and ((sideInput == "mouse" and input.UserInputType == Enum.UserInputType.MouseMovement) or input == sideInput) then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		Pointer.side.delta += pos - Pointer.side.pos
		Pointer.side.pos = pos
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if not activeTouch then
			Pointer.pos = Vector2.new(input.Position.X, input.Position.Y)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
		Pointer.pos = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not isPress(input) then
		return
	end
	if sideInput and ((sideInput == "mouse" and input.UserInputType == Enum.UserInputType.MouseButton1) or input == sideInput) then
		sideInput = nil
		Pointer.side.down = false
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		if input ~= activeTouch then
			return
		end
		activeTouch = nil
	end
	if Pointer.down then
		Pointer.down = false
		Pointer.upTime = os.clock()
		Pointer.releases += 1
	end
end)

function Pointer.reset()
	Pointer.down = false
	activeTouch = nil
	sideInput = nil
	Pointer.side.down = false
	Pointer.side.delta = Vector2.zero
end

-- 옆 조작으로 끈 양 (지난번 이후). 가져가면 0으로
function Pointer.takeSideDelta()
	local d = Pointer.side.delta
	Pointer.side.delta = Vector2.zero
	return d
end

-- 화면 좌표 → 높이 y인 수평면 위의 점
function Pointer.toPlane(y, screenPos)
	local cam = workspace.CurrentCamera
	local p = screenPos or Pointer.pos
	local ray = cam:ScreenPointToRay(p.X, p.Y)
	local dy = ray.Direction.Y
	if math.abs(dy) < 1e-4 then
		return ray.Origin
	end
	local t = (y - ray.Origin.Y) / dy
	return ray.Origin + ray.Direction * math.max(t, 0)
end

function Pointer.toScreen(worldPos)
	local v = workspace.CurrentCamera:WorldToScreenPoint(worldPos)
	return Vector2.new(v.X, v.Y)
end

return Pointer
