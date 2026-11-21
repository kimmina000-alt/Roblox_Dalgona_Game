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
	-- 2026-11-19 도구 간격 1.5씩 넓힘 (StallDecor.layout): 화로·국자·젓가락은 x -1.5, 철판·누름판·틀은 x +1.5
	pick = { Vector2.new(-9.7, -1.7), 12.6 }, -- (안 씀: 2026-11-20부터 poseFor가 녹이기 화면을 옆으로 옮겨 만듦)
	sugar = { Vector2.new(-4.9, 0.4), 17.0 }, -- 설탕 그릇 두 개 + 국자
	melt = { Vector2.new(-5.9, 0.0), 16.2 }, -- 국자 (CameraRig.track으로 국자를 따라가며 화면 가운데에 둠)
	soda = { Vector2.new(-4.4, 0.0), 16.4 }, -- 국자 + 소다 통 (게이지 위로). 통에 담가 휘저으니 통이 화면 안쪽에 오게 (2026-11-19)
	-- 붓기: 항공샷 그대로 (2026-11-19). 기울여 붓는 동안 국자는 화면 위로 올라간 것처럼 사라지고 떨어지는 반죽만 보임 (Pour.lua)
	pour = { Vector2.new(5.8, -0.5), 12.4, 0.55 }, -- 2026-11-20: 막대 꽂을 때(누르기)와 같은 화면. 철판 + 오른쪽 분홍 버튼
	press = { Vector2.new(5.8, -0.5), 12.4, 0.55 }, -- 앞쪽에서 비스듬히: 반죽 두께(옆면)가 보이게 (2026-11-19) -- 철판 + 오른쪽 뒤로 비킨 누름판
	stamp = { Vector2.new(5.0, 0.8), 14.1 }, -- 철판 + 오른쪽 모양 틀
	result = { Vector2.new(6.7, 0.2), 12.2 }, -- 달고나는 왼쪽 (오른쪽은 결과 창)
}
local STEP_POSE = {}
-- 2026-11-20 플레이 테스트: 안내 문구가 위 단계 줄 바로 아래로 올라가면서 화면 위쪽 도구를 가림 →
-- 모든 항공샷을 높이의 이 비율만큼 테이블 안쪽(-Z)을 보게 해 장면을 화면 아래로 내림 (아래는 비어 있음)
local SHIFT = 0.09 -- (2026-11-20 0.15로 더 내렸다가 사용자 확인: 0.09가 맞음, 되돌림)

local FOV = 40 -- 망원: 가까이 당겨 보이면서 원근 왜곡이 적음
local EASE = 0.25

local origin = CFrame.new()
local bound = false
local current = nil
local from, to = CFrame.new(), CFrame.new()
local t0 = 0

-- stationPivot = 작업대 기준 자리, model = 작업대 모델 (17b: 가게마다 작업대가 있어서 내 작업대를 넘김)
function CameraRig.init(stationPivot, model)
	origin = stationPivot
	CameraRig.model = model
end

local trackPose -- 아래에서 정의 (젓가락 화면이 녹이기 화면을 그대로 옆으로 옮긴 것이라서 씀)
local PICK_X = -9.7 -- 젓가락 화면 가운데 x (작업대 기준)

-- 새 배치(ㄷ자 카운터, 작업대 속성 CounterLayout, 2026-11-21)에서는 물건 자리가 달라서 화면 가운데를 실제 물건 자리로 셈.
-- 높이·기울기는 원래 값 그대로, 가운데만 (원래 배치에서 각 화면이 보던 물건과의 관계를 따라)
local function localXZ(inst)
	if not inst then
		return nil
	end
	local pos = inst:IsA("Model") and inst:GetBoundingBox().Position or inst.Position
	local v = origin:PointToObjectSpace(pos)
	return Vector2.new(v.X, v.Z)
end
local function counterCenter(key)
	local ws = CameraRig.model
	if not (ws and ws:GetAttribute("CounterLayout")) then
		return nil
	end
	local plate = localXZ(ws:FindFirstChild("IronPlate"))
	local brazier = localXZ(ws:FindFirstChild("Brazier"))
	if key == "sugar" then
		local w, b = localXZ(ws:FindFirstChild("SugarBowlWhite")), localXZ(ws:FindFirstChild("SugarBowlBrown"))
		if brazier and w and b then
			return brazier:Lerp((w + b) / 2, 0.25) -- 국자(화로) 쪽, 설탕 그릇도 보이게
		end
	elseif key == "soda" then
		local sd = localXZ(ws:FindFirstChild("SodaTub"))
		if brazier and sd then
			return brazier:Lerp(sd, 0.3)
		end
	elseif key == "pour" or key == "press" then
		if plate then
			return plate + Vector2.new(0.7, -0.5)
		end
	elseif key == "stamp" then
		local cu = localXZ(ws:FindFirstChild("Cutter"))
		if plate and cu then
			return plate:Lerp(cu, 0.35)
		end
	elseif key == "result" then
		if plate then
			return plate + Vector2.new(1.6, 0.2)
		end
	end
	return nil
end

function CameraRig.poseFor(key)
	if key == "pick" then
		-- 2026-11-20 "나무젓가락 화면이랑 연탄 화로 화면 위치가 다름": 녹이기 카메라(국자를 따라가는 화면)를
		-- 높이·기울기·거리 그대로 두고 옆(x)으로만 옮긴 화면. 그래서 젓가락 → 화로로 갈 때 오른쪽으로만 움직임
		local ws = CameraRig.model -- 지금 쓰는 작업대 (17b: 내 가게 작업대)
		local bowl = ws and ws:FindFirstChild("Ladle") and ws.Ladle:FindFirstChild("Bowl")
		local by = bowl and origin:PointToObjectSpace(bowl.Position).Y or 8.1
		local bz = bowl and origin:PointToObjectSpace(bowl.Position).Z or 0
		-- 젓가락 통이 옮겨졌으면(2026-11-21 바닥 화로 앞) 그 통 위로
		local cup = ws and ws:FindFirstChild("ChopstickCup")
		if cup then
			local cc = origin:PointToObjectSpace(cup:GetBoundingBox().Position)
			return trackPose(origin:PointToWorldSpace(Vector3.new(cc.X, cc.Y, cc.Z + 0.3)), "melt")
		end
		return trackPose(origin:PointToWorldSpace(Vector3.new(PICK_X, by, bz + 0.3)), "melt")
	end
	local p = POSES[STEP_POSE[key] or key] or POSES.sugar
	local c, y = p[1], p[2]
	c = counterCenter(STEP_POSE[key] or key) or c
	local tilt = p[3] or TILT
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
	c -= Vector2.new(0, h * SHIFT)
	local look = origin:PointToWorldSpace(Vector3.new(c.X, TABLE_TOP, c.Y))
	local pos = origin:PointToWorldSpace(Vector3.new(c.X, y, c.Y + h * tilt))
	-- 화면 위쪽 = 테이블 안쪽(-Z)
	return CFrame.lookAt(pos, look, origin:VectorToWorldSpace(Vector3.new(0, 0, -1)))
end

-- 움직이는 물체 따라가기 (사용자 요청 2026-11-19: 국자를 들면 화면 가운데에서 어긋남).
-- fn()이 돌려주는 점이 화면 가운데에 오게, 지금 화면의 카메라 높이·기울기 그대로 부드럽게 따라감. nil이면 멈춤
local tracker = nil
local frontEase = 0.9
function CameraRig.track(fn)
	tracker = fn
end

-- 따라가는 화면(녹이기)은 카메라가 국자에 가까워서 같은 SHIFT면 국자가 화면 아래로 너무 내려감
-- (2026-11-20 "화면 너무 내려와서 국자 아래쪽은 나무젓가락으로 안 저어져") → 국자까지 거리의 이 비율만큼만
local TRACK_SHIFT = 0.04
function trackPose(p, poseKey)
	local pose = POSES[poseKey or current] or POSES.sugar
	-- 화로를 테이블 속으로 내린 만큼(작업대 속성 BrazierDrop, 2026-11-21) 국자 따라가는 화면도 내려서 크기를 그대로
	local y = pose[2] - ((CameraRig.model and CameraRig.model:GetAttribute("BrazierDrop")) or 0)
	local vp = workspace.CurrentCamera.ViewportSize
	if vp.X / math.max(vp.Y, 1) < 1.2 then
		y = TABLE_TOP + (y - TABLE_TOP) * 1.6
	end
	local h = y - TABLE_TOP
	local camY = origin:PointToWorldSpace(Vector3.new(0, y, 0)).Y
	p += origin:VectorToWorldSpace(Vector3.new(0, 0, -(camY - p.Y) * TRACK_SHIFT))
	local pos = Vector3.new(p.X, camY, p.Z) + origin:VectorToWorldSpace(Vector3.new(0, 0, h * (pose[3] or TILT)))
	return CFrame.lookAt(pos, p, origin:VectorToWorldSpace(Vector3.new(0, 0, -1)))
end

local function step(dt)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = FOV
	if tracker then
		local p = tracker()
		if p then
			to = to:Lerp(trackPose(p), 1 - math.exp(-10 * (dt or 1 / 60)))
		end
	end
	local glide = current == "front" or current == "point"
	local a = math.clamp((os.clock() - t0) / (glide and frontEase or EASE), 0, 1)
	local e = glide and a * a * (3 - 2 * a) or 1 - (1 - a) * (1 - a) -- 정면 보기·옮겨 가기는 부드럽게, 나머지는 Quad ease-out
	cam.CFrame = from:Lerp(to, e)
end

function CameraRig.go(key, instant)
	local pose = STEP_POSE[key] or key
	if bound and pose == current and not instant then
		return -- 같은 화면이면 카메라를 움직이지 않음
	end
	tracker = nil
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

-- 정면 보기 (2026-11-20: 비닐 씌울 때는 항공뷰 말고 정면에서). focus = 보여 줄 곳(세계 좌표).
-- 테이블 앞(플레이어 쪽 +Z)에서 눈높이로 수평에 가깝게 바라봄. ease초에 걸쳐 부드럽게 옮겨 감
function CameraRig.goFront(focus, ease)
	tracker = nil
	current = "front"
	local cam = workspace.CurrentCamera
	local fwd = origin:VectorToWorldSpace(Vector3.new(0, 0, 1))
	local look = focus + Vector3.new(0, 1.4, 0)
	local pos = look + fwd * 8 + Vector3.new(0, 0.9, 0)
	from = cam.CFrame
	to = CFrame.lookAt(pos, look, Vector3.yAxis)
	t0 = os.clock()
	frontEase = ease or 0.9
	if not bound then
		bound = true
		RunService:BindToRenderStep("DalgonaCamera", Enum.RenderPriority.Camera.Value + 1, step)
	end
end

-- 테이블 위 아무 곳(세계 좌표 focus)을 항공샷으로 보러 부드럽게 옮겨 감 (2026-11-20 포장 공간)
-- height = 테이블 윗면 위 카메라 높이, tilt = 플레이어 쪽으로 기울인 정도
function CameraRig.goPoint(focus, height, tilt, ease)
	tracker = nil
	current = "point"
	local cam = workspace.CurrentCamera
	local h = height
	local vp = cam.ViewportSize
	if vp.X / math.max(vp.Y, 1) < 1.2 then
		h *= 1.6
	end
	focus += origin:VectorToWorldSpace(Vector3.new(0, 0, -h * SHIFT))
	local pos = focus + Vector3.new(0, h, 0) + origin:VectorToWorldSpace(Vector3.new(0, 0, h * (tilt or TILT)))
	from = cam.CFrame
	to = CFrame.lookAt(pos, focus, origin:VectorToWorldSpace(Vector3.new(0, 0, -1)))
	t0 = os.clock()
	frontEase = ease or 0.7
	if not bound then
		bound = true
		RunService:BindToRenderStep("DalgonaCamera", Enum.RenderPriority.Camera.Value + 1, step)
	end
end

function CameraRig.release()
	if bound then
		bound = false
		RunService:UnbindFromRenderStep("DalgonaCamera")
	end
	current = nil
	tracker = nil
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
end

return CameraRig
