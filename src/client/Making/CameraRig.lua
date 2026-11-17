-- 단계마다 고정 카메라. 단계가 바뀔 때만 컷 1프레임 + 0.25초 ease-out (MOTION_REFERENCE 5장)
-- 제작 중에는 매 프레임 카메라를 잡아 둔다 (다른 스크립트나 도구가 카메라를 바꿔도 고정 유지).

local RunService = game:GetService("RunService")

local CameraRig = {}

-- 작업대 피벗 기준 { 보는 점, 카메라 위치 }
local POSES = {
	sugar = { Vector3.new(-1.7, 4.6, 0.4), Vector3.new(-1.7, 10.6, 8.0) },
	melt = { Vector3.new(-3.2, 6.1, 0.1), Vector3.new(-3.2, 11.6, 4.6) },
	soda = { Vector3.new(-2.6, 5.9, 0.0), Vector3.new(-2.6, 11.2, 5.4) },
	pour = { Vector3.new(0.3, 4.6, 0.0), Vector3.new(0.3, 11.8, 8.6) },
	press = { Vector3.new(4.0, 4.0, 0.0), Vector3.new(4.0, 8.0, 6.4) },
	stamp = { Vector3.new(5.0, 3.8, 0.2), Vector3.new(5.0, 9.6, 5.6) },
	result = { Vector3.new(3.6, 3.7, 0.0), Vector3.new(3.6, 8.4, 4.4) },
}

local FOV = 70
local EASE = 0.25

local origin = CFrame.new()
local bound = false
local from, to = CFrame.new(), CFrame.new()
local t0 = 0

function CameraRig.init(stationPivot)
	origin = stationPivot
end

function CameraRig.poseFor(key)
	local p = POSES[key] or POSES.sugar
	local look = origin:PointToWorldSpace(p[1])
	local pos = origin:PointToWorldSpace(p[2])
	return CFrame.lookAt(pos, look)
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
	local target = CameraRig.poseFor(key)
	if instant then
		from, to = target, target
	else
		-- 컷: 첫 프레임은 살짝 뒤에서, 그다음 0.25초 ease-out으로 다가감
		from, to = target * CFrame.new(0, 0.4, 1.6), target
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
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
end

return CameraRig
