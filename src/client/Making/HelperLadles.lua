-- 화로 위 알바생 국자 움직임 (MACHINE_ERAS 1단계: 국자 2~4개, 2026-11-20 사용자 요청 "국자 여러 개")
-- 서버 WorkstationBuilder.setLadleCount가 만든 HelperLadle2~4마다:
--   설탕을 넣고 → 젓가락이 원을 그리며 저어 흰 설탕이 투명한 호박색으로 녹고 → 소다를 넣어 베이지색으로 부풀고
--   → 부어서 비워진 뒤 잠깐 쉬었다가 다시. 국자마다 시작 시점(Phase)이 달라서 따로따로 돌아감.
-- 꾸밈 움직임이라 각 플레이어 화면에서만 그림 (서버 부담 없음)

local RunService = game:GetService("RunService")
local Workstations = require(script.Parent:WaitForChild("Workstations"))

local Helper = {}

local CYCLE = 20 -- 한 바퀴(설탕 넣기 ~ 다시 비움) 초
local SUGAR = Color3.fromRGB(250, 250, 250)
local AMBER = Color3.fromRGB(236, 168, 52)
local FOAM = Color3.fromRGB(214, 164, 108)

local GRIP_ALONG = 0.9 -- 알바생 미니미가 젓가락을 잡는 자리: 끝에서 이만큼 위 (아래 poseMinime)
local base = setmetatable({}, { __mode = "k" }) -- 내용물 처음 자리 (부품 → CFrame)

local function stepOne(m, now)
	local c = m:GetAttribute("Center")
	local R = m:GetAttribute("BowlR") or 0.85
	local stick, cont = m:FindFirstChild("Stick"), m:FindFirstChild("Contents")
	if not (c and stick and cont) then
		return
	end
	if not base[cont] then
		base[cont] = cont.CFrame
	end
	local cf0 = base[cont]
	local th0 = cont:GetAttribute("BaseThick") or cont.Size.X
	local u = (now / CYCLE + (m:GetAttribute("Phase") or 0)) % 1
	local color, thick, mat, hidden = SUGAR, th0, Enum.Material.Sand, false
	local stir = 0 -- 젓는 빠르기 (rad/s)
	if u < 0.08 then
		-- 설탕을 붓는 중: 흰 설탕이 쌓임
		thick = th0 * (0.3 + 0.7 * u / 0.08)
	elseif u < 0.5 then
		-- 녹이기: 흰 → 투명한 호박색
		local k = (u - 0.08) / 0.42
		color = SUGAR:Lerp(AMBER, k)
		mat = k < 0.55 and Enum.Material.Sand or Enum.Material.SmoothPlastic
		stir = 5
	elseif u < 0.7 then
		-- 소다: 빠르게 저으면 베이지색으로 부풀어 오름
		local k = (u - 0.5) / 0.2
		color = AMBER:Lerp(FOAM, math.min(k * 1.5, 1))
		mat = Enum.Material.SmoothPlastic
		thick = th0 * (1 + 2.2 * k * k * (3 - 2 * k))
		stir = 10
	elseif u < 0.78 then
		-- 부음: 내용물이 줄어듦
		local k = (u - 0.7) / 0.08
		color = FOAM
		mat = Enum.Material.SmoothPlastic
		thick = th0 * 3.2 * (1 - k)
		hidden = k > 0.97
	else
		hidden = true -- 비어서 잠깐 쉼
	end
	cont.Transparency = hidden and 1 or 0
	if not hidden then
		thick = math.max(thick, 0.01)
		cont.Size = Vector3.new(thick, cont.Size.Y, cont.Size.Z)
		cont.CFrame = cf0 + Vector3.new(0, (thick - th0) / 2, 0)
		cont.Color = color
		cont.Material = mat
	end
	-- 나무젓가락: 끝이 국자 안에서 원을 그림, 손잡이는 위로 비스듬히. 쉴 때는 국자에 기대 둠
	local a = stir > 0 and now * stir + (m:GetAttribute("Phase") or 0) * 20 or 0.8
	local r = stir > 0 and R * 0.42 or R * 0.55
	local topY = cf0.Position.Y + thick / 2
	local tip = Vector3.new(c.X + math.cos(a) * r, topY + 0.02, c.Z + math.sin(a) * r)
	local lean = stir > 0 and Vector3.new(math.cos(a) * 0.35, 1, math.sin(a) * 0.35) or Vector3.new(math.cos(a) * 0.9, 0.6, math.sin(a) * 0.9)
	local hand = tip + lean.Unit * stick.Size.X
	stick.CFrame = CFrame.lookAt((tip + hand) / 2, hand) * CFrame.Angles(0, math.rad(90), 0)
	-- 알바생(미니미)이 잡는 자리: 젓가락 끝에서 GRIP_ALONG만큼 위 (맨 위 끝은 키가 작아 손이 안 닿음)
	return tip + lean.Unit * math.min(GRIP_ALONG, stick.Size.X), c
end

-- 알바생 미니미 (D19, 2026-11-21 사용자 "카운터 위"): 서버 Minime가 가게 바닥에 세운 미니미를 내 화면에서
-- 카운터(작업대 윗면) 위, 자기 국자 옆에 세우고 오른팔을 뻗어 젓가락을 잡게 함. 손에 든 작은 국자는 숨김
-- (화로 위 알바생 국자가 진짜). 국자 k ↔ 알바생 k-1 (HelperLadle2 = 알바생 1). 모든 플레이어 화면에서 같게 그림
local STAND_OFF = 1.25 -- 국자 가운데에서 미니미 몸통까지 (옆 + 뒤로)
local armRest = setmetatable({}, { __mode = "k" })
local function hideHandLadle(mini)
	local hl = mini:FindFirstChild("HandLadle", true)
	if hl and not hl:GetAttribute("HiddenByHelper") then
		hl:SetAttribute("HiddenByHelper", true)
		local list = hl:IsA("BasePart") and { hl } or {}
		for _, d in ipairs(hl:GetDescendants()) do
			table.insert(list, d)
		end
		for _, d in ipairs(list) do
			if d:IsA("BasePart") then
				d.Transparency = 1 -- 광택(SurfaceAppearance) 메시는 LocalTransparencyModifier로 다 안 사라짐
				d.CastShadow = false
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
	end
end
local function poseMinime(ws, k, grip, center)
	local plot = ws.Parent
	local mini = plot and plot:FindFirstChild("Helper" .. (k - 1))
	local top = ws:FindFirstChild("TableTop")
	local root = mini and mini:FindFirstChild("HumanoidRootPart")
	local torso = mini and mini:FindFirstChild("UpperTorso")
	local arm = mini and mini:FindFirstChild("RightUpperArm")
	local joint = arm and arm:FindFirstChild("RightShoulder")
	if not (top and root and torso and joint) then
		return
	end
	hideHandLadle(mini)
	-- 발 높이: 미니미 아래끝(발)이 카운터 윗면에 오게. 피벗 → 발까지 거리는 처음 한 번 잼
	if not armRest[mini] then
		local cf, size = mini:GetBoundingBox()
		armRest[mini] = { footDrop = root.Position.Y - (cf.Position.Y - size.Y / 2) }
	end
	local footY = top.Position.Y + top.Size.Y / 2
	-- 국자 옆(작업대 가운데 반대쪽 = 화로 바깥) + 뒤(-Z, 손님 반대쪽)에 서서 국자 쪽을 봄
	local brazier = ws:FindFirstChild("Brazier")
	local bc = brazier and brazier:GetPivot().Position or center
	local out = Vector3.new(center.X - bc.X, 0, center.Z - bc.Z)
	out = out.Magnitude > 0.05 and out.Unit or Vector3.new(1, 0, 0)
	local side = (out + Vector3.new(0, 0, -0.6)).Unit
	local pos = Vector3.new(center.X, footY + armRest[mini].footDrop, center.Z) + side * STAND_OFF
	local lookAt = Vector3.new(center.X, pos.Y, center.Z)
	local want = CFrame.lookAt(pos, lookAt)
	if (root.Position - pos).Magnitude > 0.01 or root.CFrame.LookVector:Dot(want.LookVector) < 0.999 then
		mini:PivotTo(want)
	end
	-- 오른팔: 어깨에서 잡는 자리 쪽으로 곧게 뻗음 (팔꿈치는 펴 둠)
	local jointCf = torso.CFrame * joint.C0
	local v = jointCf:VectorToObjectSpace(grip - jointCf.Position)
	if v.Magnitude > 1e-3 then
		joint.Transform = CFrame.fromRotationBetweenVectors(Vector3.new(0, -1, 0), v.Unit)
	end
	local elbow = mini:FindFirstChild("RightElbow", true)
	if elbow then
		elbow.Transform = CFrame.new()
	end
end

local started = false
function Helper.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function()
		-- 가게마다 작업대가 있음 (17b): 모든 작업대의 알바생 국자를 움직임 (다른 가게 것도 보임)
		local now = os.clock()
		for _, ws in ipairs(Workstations.all()) do
			for _, m in ipairs(ws:GetChildren()) do
				if m.Name:sub(1, 11) == "HelperLadle" then
					local grip, center = stepOne(m, now)
					local k = tonumber(m.Name:sub(12))
					if grip and k then
						poseMinime(ws, k, grip, center)
					end
				end
			end
		end
	end)
end

return Helper
