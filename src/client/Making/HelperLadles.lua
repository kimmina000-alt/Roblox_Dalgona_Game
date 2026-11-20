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

-- resting = 알바생이 쉬는 중 (가게 문 닫힘·재료 부족 등): 국자는 비고 젓가락은 기대 둠
local function stepOne(m, now, resting)
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
	if resting then
		hidden = true
	elseif u < 0.08 then
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
local STOOL_H = 1.0 -- 노점 배치에서 미니미가 올라선 나무 의자 높이
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
-- 국자 k의 알바생 미니미 (없으면 nil)
local function minimeFor(ws, k)
	local plot = ws.Parent
	return plot and plot:FindFirstChild("Helper" .. (k - 1))
end

-- 쉬는 중인가: 서버가 머리 위 글에 "쉬는 중 (이유)"를 씀 (GrowthService.setHelperText)
local function isResting(mini)
	local head = mini and mini:FindFirstChild("Head")
	local bb = head and head:FindFirstChild("Status")
	if not bb then
		return false
	end
	-- 글자 칸이 여럿 (번호 배지 Number + 상태 TextLabel): 상태 글을 봄
	local label = bb:FindFirstChild("TextLabel")
	return label ~= nil and label:IsA("TextLabel") and string.find(label.Text, "쉬는 중", 1, true) ~= nil
end

-- 바닥 높이 = 테이블 다리 아래끝 (작업대마다 한 번 잼)
local floorCache = setmetatable({}, { __mode = "k" })
local function floorOf(ws)
	local y = floorCache[ws]
	if not y then
		y = math.huge
		for _, p in ipairs(ws:GetChildren()) do
			if p.Name == "TableLeg" and p:IsA("BasePart") then
				y = math.min(y, p.Position.Y - p.Size.Y / 2)
			end
		end
		floorCache[ws] = y
	end
	return y < math.huge and y or nil
end

-- 의자는 그대로 두고 미니미만 옮김
local function placeMini(mini, cf)
	local stool = mini:FindFirstChild("MinimeStool")
	if stool then
		stool.Parent = nil
	end
	mini:PivotTo(cf)
	if stool then
		stool.Parent = mini
	end
end

-- 진열하러 가기 (D26, 2026-11-21): 알바생이 만든 달고나를 진열대 빈 칸에 놓을 때 서버가 미니미에
-- DeliverSlot(칸 번호)·DeliverAt(서버 시각)을 남김 → DELIVER_T초 동안 의자에서 내려 그 칸까지 들고 걸어가
-- 놓고 돌아옴 (칸에는 서버가 이미 달고나를 보여 줌). 내 화면에서만 그리는 움직임
local DELIVER_T = 3.2
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function deliverPose(ws, mini, torso, joint, home, footDrop)
	local at, k = mini:GetAttribute("DeliverAt"), mini:GetAttribute("DeliverSlot")
	if type(at) ~= "number" or type(k) ~= "number" then
		return false
	end
	local age = workspace:GetServerTimeNow() - at
	local disc = mini:FindFirstChild("CarryDisc")
	if age < 0 or age >= DELIVER_T then
		if disc then
			disc.Transparency = 1
		end
		return false
	end
	local plot = ws.Parent
	local shelf = plot and plot:FindFirstChild("DisplayShelf")
	local slot = shelf and shelf:FindFirstChild("Slot" .. k)
	local floorY = floorOf(ws)
	if not (slot and slot:IsA("BasePart") and floorY) then
		return false
	end
	local sp = slot.Position
	local homeG = Vector3.new(home.X, floorY + footDrop, home.Z)
	local toHome = Vector3.new(homeG.X - sp.X, 0, homeG.Z - sp.Z)
	local stand = Vector3.new(sp.X, floorY + footDrop, sp.Z) + (toHome.Magnitude > 0.1 and toHome.Unit or Vector3.zAxis) * 1.3
	local p, face, reach
	if age < 1.2 then
		p = homeG:Lerp(stand, smooth(age / 1.2))
		face = stand
		-- 걸음: 살짝 통통 튀며
		p += Vector3.new(0, math.abs(math.sin(age * 12)) * 0.12, 0)
	elseif age < 2.0 then
		p = stand
		face = Vector3.new(sp.X, stand.Y, sp.Z)
		reach = true
	else
		p = stand:Lerp(homeG, smooth((age - 2.0) / 1.2))
		face = homeG
		p += Vector3.new(0, math.abs(math.sin(age * 12)) * 0.12, 0)
	end
	local look = Vector3.new(face.X - p.X, 0, face.Z - p.Z)
	local cf = look.Magnitude > 0.05 and CFrame.lookAt(p, p + look) or CFrame.new(p) * (mini:GetPivot() - mini:GetPivot().Position)
	placeMini(mini, cf)
	-- 팔: 들고 갈 때는 앞으로, 칸 앞에서는 칸으로 뻗음, 돌아올 때는 내림
	local jointCf = torso.CFrame * joint.C0
	if age < 2.0 then
		local target = reach and (sp + Vector3.new(0, 0.2, 0)) or (cf * CFrame.new(0.3, -0.4, -1.2)).Position
		local v = jointCf:VectorToObjectSpace(target - jointCf.Position)
		if v.Magnitude > 1e-3 then
			joint.Transform = CFrame.fromRotationBetweenVectors(Vector3.new(0, -1, 0), v.Unit)
		end
	else
		joint.Transform = CFrame.new()
	end
	-- 손에 든 달고나 (칸에 놓을 때까지)
	local hand = mini:FindFirstChild("RightHand")
	if not disc then
		disc = Instance.new("Part")
		disc.Name = "CarryDisc"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.08, 0.7, 0.7)
		disc.Color = Color3.fromRGB(214, 150, 74)
		disc.Material = Enum.Material.SmoothPlastic
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.Parent = mini
	end
	if hand and age < 1.7 then
		disc.Transparency = 0
		disc.CFrame = CFrame.new(hand.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	else
		disc.Transparency = 1
	end
	return true
end

local function poseMinime(ws, k, grip, center, resting)
	local mini = minimeFor(ws, k)
	local top = ws:FindFirstChild("TableTop")
	local root = mini and mini:FindFirstChild("HumanoidRootPart")
	local torso = mini and mini:FindFirstChild("UpperTorso")
	local arm = mini and mini:FindFirstChild("RightUpperArm")
	local joint = arm and arm:FindFirstChild("RightShoulder")
	if not (top and root and torso and joint) then
		return
	end
	hideHandLadle(mini)
	-- 발 높이: 화로가 땅 위에 있으면(노점 배치, 2026-11-21) 바닥, 아니면 카운터 윗면. 피벗 → 발까지 거리는 처음 한 번 잼
	if not armRest[mini] then
		local cf, size = mini:GetBoundingBox()
		armRest[mini] = { footDrop = root.Position.Y - (cf.Position.Y - size.Y / 2) }
	end
	local footY = top.Position.Y + top.Size.Y / 2
	if ws:GetAttribute("StreetLayout") then
		local floorY = armRest[ws]
		if not floorY then
			floorY = math.huge
			for _, p in ipairs(ws:GetChildren()) do
				if p.Name == "TableLeg" and p:IsA("BasePart") then
					floorY = math.min(floorY, p.Position.Y - p.Size.Y / 2)
				end
			end
			armRest[ws] = floorY
		end
		if floorY < math.huge then
			-- 화로(키 약 3.8)에 가려 안 보이므로 작은 나무 의자 위에 섬 (내 화면에서만 만드는 부품)
			footY = floorY + STOOL_H
			local stool = mini:FindFirstChild("MinimeStool")
			if not stool then
				stool = Instance.new("Part")
				stool.Name = "MinimeStool"
				stool.Anchored = true
				stool.CanCollide = false
				stool.CanQuery = false
				stool.CanTouch = false
				stool.Material = Enum.Material.Wood
				stool.Color = Color3.fromRGB(150, 104, 64)
				stool.Size = Vector3.new(1.3, STOOL_H, 1.1)
				stool.Parent = mini
			end
			stool.Anchored = true
			stool:SetAttribute("Stool", true)
		end
	end
	-- 국자 옆(작업대 가운데 반대쪽 = 화로 바깥) + 뒤(-Z, 손님 반대쪽)에 서서 국자 쪽을 봄
	local brazier = ws:FindFirstChild("Brazier")
	local bc = brazier and brazier:GetPivot().Position or center
	local out = Vector3.new(center.X - bc.X, 0, center.Z - bc.Z)
	out = out.Magnitude > 0.05 and out.Unit or Vector3.new(1, 0, 0)
	local side = (out + Vector3.new(0, 0, -0.6)).Unit
	local pos = Vector3.new(center.X, footY + armRest[mini].footDrop, center.Z) + side * STAND_OFF
	local lookAt = Vector3.new(center.X, pos.Y, center.Z)
	local want = CFrame.lookAt(pos, lookAt)
	local stool = mini:FindFirstChild("MinimeStool")
	if stool then
		stool.CFrame = CFrame.new(pos.X, footY - STOOL_H / 2, pos.Z) * (want - want.Position)
	end
	-- 진열하러 가는 중이면 그 움직임만 (D26)
	if deliverPose(ws, mini, torso, joint, pos, armRest[mini].footDrop) then
		return
	end
	if (root.Position - pos).Magnitude > 0.01 or root.CFrame.LookVector:Dot(want.LookVector) < 0.999 then
		placeMini(mini, want)
	end
	-- 쉬는 중: 팔을 내리고 서 있음 (2026-11-21 가게 문 닫힘·재료 부족 때)
	if resting then
		joint.Transform = CFrame.new()
		return
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
					local k = tonumber(m.Name:sub(12))
					local mini = k and minimeFor(ws, k)
					local resting = isResting(mini)
					local grip, center = stepOne(m, now, resting)
					if grip and k then
						poseMinime(ws, k, grip, center, resting)
					end
				end
			end
		end
	end)
end

return Helper
