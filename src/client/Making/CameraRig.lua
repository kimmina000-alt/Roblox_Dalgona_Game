-- 테이블을 위에서 내려다보는 항공샷. 화면은 두 곳만 쓴다.
--   왼쪽: 설탕 · 녹이기 · 소다 (설탕 그릇과 국자를 크게)
--   오른쪽: 붓기 · 누르기 · 모양 (철판 위)
-- 같은 화면 안에서는 카메라가 그대로이고, 화면이 바뀔 때만 컷 1프레임 + 0.25초 ease-out (MOTION_REFERENCE 5장)
-- 제작 중에는 매 프레임 카메라를 잡아 둔다 (다른 스크립트나 도구가 카메라를 바꿔도 고정 유지).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraRig = {}

local TABLE_TOP = 3.5
local TILT = 0.12 -- 완전 수직이면 도구가 납작해 보여서 플레이어 쪽으로 살짝 기울임

-- 작업대 피벗 기준 { 화면 가운데에 올 테이블 위 점(x, z), 카메라 높이(y) }
local POSES = {
	left = { Vector2.new(-3.1, 0.1), 12.3 }, -- 화로 1.5배: 화로가 QUALITY 창에 안 가리게 왼쪽·위로
	right = { Vector2.new(4.3, 0.1), 10.8 },
	result = { Vector2.new(3.6, 0.0), 9.6 },
}
local STEP_POSE = {
	sugar = "left",
	melt = "left",
	soda = "left",
	pour = "right",
	press = "right",
	stamp = "right",
	result = "result",
}

local FOV = 70
local EASE = 0.25

local origin = CFrame.new()
local bound = false
local current = nil
local from, to = CFrame.new(), CFrame.new()
local t0 = 0

function CameraRig.init(stationPivot)
	origin = stationPivot
end

function CameraRig.poseFor(key)
	local p = POSES[STEP_POSE[key] or key] or POSES.left
	local c, y = p[1], p[2]
	-- 세로 화면은 옆이 좁으니 더 높이 올라감
	local vp = workspace.CurrentCamera.ViewportSize
	if vp.X / math.max(vp.Y, 1) < 1.2 then
		y = TABLE_TOP + (y - TABLE_TOP) * 1.6
	end
	-- 폰 결과 화면: 팝업이 오른쪽이라 달고나를 왼쪽에 둠
	if key == "result" and UserInputService.TouchEnabled then
		c += Vector2.new(1.9, 0)
	end
	local h = y - TABLE_TOP
	local look = origin:PointToWorldSpace(Vector3.new(c.X, TABLE_TOP, c.Y))
	local pos = origin:PointToWorldSpace(Vector3.new(c.X, y, c.Y + h * TILT))
	-- 화면 위쪽 = 테이블 안쪽(-Z)
	return CFrame.lookAt(pos, look, origin:VectorToWorldSpace(Vector3.new(0, 0, -1)))
end

local function step()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = FOV
	local a = math.clamp((os.clock() - t0) / EASE, 0, 1)
	local e = 1 - (1 - a) * (1 - a) -- Quad ease-out
	cam.CFrame = from:Lerp(to, e)
end

function CameraRig.go(key, instant)
	local pose = STEP_POSE[key] or key
	if bound and pose == current and not instant then
		return -- 같은 화면이면 카메라를 움직이지 않음
	end
	current = pose
	local target = CameraRig.poseFor(key)
	if instant then
		from, to = target, target
	else
		-- 컷: 첫 프레임은 살짝 높이서, 그다음 0.25초 ease-out으로 내려옴
		from, to = target * CFrame.new(0, 0, 1.6), target
	end
	t0 = os.clock()
	if not bound then
		bound = true
		RunService:BindToRenderStep("DalgonaCamera", Enum.RenderPriority.Camera.Value + 1, step)
	end
	step()
end

function CameraRig.release()
	if bound then
		bound = false
		RunService:UnbindFromRenderStep("DalgonaCamera")
	end
	current = nil
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
end

return CameraRig
