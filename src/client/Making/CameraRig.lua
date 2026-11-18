-- 테이블을 위에서 내려다보는 항공샷. 단계마다 가까이 당겨서 보고, 단계가 바뀌면 옆으로 옮겨 감
-- (사용자 요청 2026-11-18: 화면 더 확대, 어차피 옆으로 이동하니까).
--   젓가락 고르기 → 설탕(그릇 + 국자) → 녹이기(국자 크게) → 소다(국자 + 소다 통) → 붓기 → 누르기 → 모양
-- 같은 화면 안에서는 카메라가 그대로이고, 화면이 바뀔 때만 컷 1프레임 + 0.25초 ease-out (MOTION_REFERENCE 5장)
-- 제작 중에는 매 프레임 카메라를 잡아 둔다 (다른 스크립트나 도구가 카메라를 바꿔도 고정 유지).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraRig = {}

local TABLE_TOP = 3.5
local TILT = 0.12 -- 완전 수직이면 도구가 납작해 보여서 플레이어 쪽으로 살짝 기울임

-- 작업대 피벗 기준 { 화면 가운데에 올 테이블 위 점(x, z), 카메라 높이(y) }
-- 각 단계에서 꼭 보여야 할 점들(국자·손잡이 잡는 자리·그릇·철판·틀 등)이 왼쪽 UI(화면 24%)·위 단계 줄·아래 안내를
-- 피해 다 들어오면서 가장 가까운 카메라를 Play 화면에서 계산한 값 (점들은 남는 칸 가운데로).
-- 망원(FOV 40)으로 높이서 찍어서 높은 국자(화로 1.95배, y 약 8.1)와 테이블 위 그릇이 덜 찌그러짐
local POSES = {
	pick = { Vector2.new(-8.3, 0.3), 12.0 }, -- 테이블 왼쪽 끝 나무젓가락
	sugar = { Vector2.new(-4.1, 0.4), 16.2 }, -- 설탕 그릇 두 개 + 국자
	melt = { Vector2.new(-5.5, 0.4), 16.2 }, -- 국자 (아래 STIR SPEED 게이지에 안 가리게 화면 위쪽 62% 안)
	soda = { Vector2.new(-4.6, 0.0), 14.7 }, -- 국자 + 소다 통 (게이지 위로)
	pour = { Vector2.new(1.7, 0.3), 14.1 }, -- 철판 + 왼쪽에서 들고 오는 국자
	press = { Vector2.new(2.8, 0.2), 12.0 }, -- 철판 + 오른쪽 뒤로 비킨 누름판
	stamp = { Vector2.new(3.5, 0.8), 14.1 }, -- 철판 + 오른쪽 모양 틀
	result = { Vector2.new(5.2, 0.2), 12.2 }, -- 달고나는 왼쪽 (오른쪽은 결과 창)
}
local STEP_POSE = {}

local FOV = 40 -- 망원: 가까이 당겨 보이면서 원근 왜곡이 적음
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
	local p = POSES[STEP_POSE[key] or key] or POSES.sugar
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
