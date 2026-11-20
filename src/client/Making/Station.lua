-- 작업대 부품 찾기, 제자리 자세 기억, 리셋, 스프링 복귀 도우미
-- 클라이언트에서 바꾸는 위치·색은 이 플레이어 화면에서만 보인다 (Phase 1 혼자 테스트용).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Station = {}
Station.__index = Station

local MOVABLE = { "Ladle", "WoodSpoon", "SodaSpoon", "Presser", "Cutter", "Chopsticks" }
local CutterRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CutterRig"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaConfig"))
local Fx = require(script.Parent:WaitForChild("Fx"))

function Station.new()
	local m = workspace:WaitForChild("DalgonaWorkstation")
	local self = setmetatable({}, Station)
	self.model = m
	for _, name in ipairs(MOVABLE) do
		self[name] = m:WaitForChild(name)
	end
	self.Brazier = m:WaitForChild("Brazier")
	self.Plate = m:WaitForChild("IronPlate")
	self.Ring = m:WaitForChild("SugarRing")
	self.WhiteBowl = m:WaitForChild("SugarBowlWhite")
	self.BrownBowl = m:WaitForChild("SugarBowlBrown")
	self.SodaTub = m:WaitForChild("SodaTub")
	self.Prompt = m:WaitForChild("TableTop"):WaitForChild("PromptAtt"):WaitForChild("MakePrompt")
	self.Bowl = self.Ladle:WaitForChild("Bowl")
	self.Contents = self.Ladle:WaitForChild("Contents")
	self.Flame = self.Brazier:WaitForChild("Briquette"):WaitForChild("FireAtt"):WaitForChild("Flame")

	self.grillTop = self.Brazier:GetAttribute("GrillTopY") or (self.Bowl.Position.Y - 0.825)
	self.plateTop = self.Plate.Position.Y + self.Plate.Size.Y / 2
	self.ringCenter = Vector3.new(self.Ring.Position.X, self.plateTop, self.Ring.Position.Z)
	self.ringRadius = self.Ring.Size.Y / 2
	self.bowlRadius = self.Bowl.Size.Y / 2
	self.bowlHalf = self.Bowl.Size.X / 2
	-- 국자 속 내용물(설탕·설탕물·거품)이 깔리는 높이 (Bowl 중심 기준, 위로 +).
	-- Bowl 원기둥 윗면(테두리 높이)이 아니라 국자 메시 그릇 안쪽 중간 깊이: 메시 그릇 바닥이 Bowl 중심보다 0.33 아래,
	-- 테두리 반지름 0.85 → 이 높이에서 안쪽 반지름 약 0.72 = 내용물 원판(1.42)과 맞음 (사용자 지적 2026-11-18: 설탕과 국자 위치가 안 맞음)
	self.floor = self.bowlHalf - 0.25

	self.rest = {}
	for _, name in ipairs(MOVABLE) do
		self.rest[name] = self[name]:GetPivot()
	end
	-- 국자는 기본으로 연탄 위 철망에 놓여 있음 (사용자 요청 2026-11-19: 저절로 중간 높이에 떠 있지 않고, 플레이어가 들어야 함)
	self.rest.Ladle = self:ladleAt(Config.Melt.hMin)
	self.Ladle:PivotTo(self.rest.Ladle)
	-- 소다 통 숟가락은 안 씀 (사용자 요청 2026-11-19: 소다컵에 숟가락 삭제). 모델은 남겨 두고 이 화면에서만 숨김
	for _, p in ipairs(self.SodaSpoon:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		end
	end
	-- 젓가락은 부품마다 따로 움직여서(Stir) 모델째 되돌리면 테이블 위 포장 젓가락이 밀려남 → 부품별로 기억
	self.chopRest = {}
	for _, p in ipairs(self.Chopsticks:GetChildren()) do
		if p:IsA("BasePart") then
			self.chopRest[p] = p.CFrame
		end
	end
	self.contentsRest = {
		Size = self.Contents.Size,
		CFrame = self.Bowl.CFrame:ToObjectSpace(self.Contents.CFrame),
		Color = self.Contents.Color,
		Material = self.Contents.Material,
		Transparency = self.Contents.Transparency,
	}
	self.heaps = {
		WoodSpoon = { part = self.WoodSpoon:WaitForChild("Heap") },
		SodaSpoon = { part = self.SodaSpoon:WaitForChild("Heap") },
	}
	for _, h in pairs(self.heaps) do
		h.size = h.part.Size
		h.color = h.part.Color
	end
	-- 나무 숟가락 위 설탕: 동그란 공 대신 그릇 더미와 같은 메시로 "납작하고 가운데만 살짝 솟은" 모양 (사용자 요청 2026-11-19)
	local ball = self.heaps.WoodSpoon.part
	local tpl = self.WhiteBowl:FindFirstChild("SugarHeapMesh")
	if tpl then
		local m = self.WoodSpoon:FindFirstChild("HeapMound") or tpl:Clone() -- Station을 또 만들어도 하나만
		m.Name = "HeapMound"
		m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
		local d = math.max(ball.Size.X, ball.Size.Z) * 1.1
		Fx.placeDome(m, ball.Position - Vector3.new(0, ball.Size.Y * 0.3, 0), d, d * 0.22, 0)
		m.Color = ball.Color
		m.Parent = self.WoodSpoon
		ball.LocalTransparencyModifier = 1
		self.heaps.WoodSpoon = {
			part = m,
			mound = true,
			size = m.Size,
			color = ball.Color,
			-- 숟가락 기준 바닥 자리 (숟가락이 움직이고 기울어도 같이 따라감)
			baseLocal = self.WoodSpoon:GetPivot():ToObjectSpace(m.CFrame * CFrame.new(0, -m.Size.Y / 2, 0)),
			model = self.WoodSpoon,
		}
	end

	-- 누름판 반투명용: 원래 보이는 부품과 투명도
	self.presserParts = {}
	for _, p in ipairs(self.Presser:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			self.presserParts[p] = p.Transparency
		end
	end

	local fx = workspace:FindFirstChild("MakingFx")
	if not fx then
		fx = Instance.new("Folder")
		fx.Name = "MakingFx"
		fx.Parent = workspace
	end
	self.fx = fx
	return self
end

-- 국자 받침 높이 h (철망 위 거리) → 국자 피벗
function Station:ladleAt(h, tilt)
	local rest = self.rest.Ladle
	local y = self.grillTop + h + self.bowlHalf
	local cf = CFrame.new(rest.Position.X, y, rest.Position.Z) * (rest - rest.Position)
	if tilt then
		cf = cf * CFrame.Angles(0, 0, tilt)
	end
	return cf
end

function Station:contentsTopY()
	local c = self.Contents
	if c.Transparency >= 1 then
		return self.Bowl.Position.Y + self.floor + 0.03
	end
	return c.Position.Y + c.Size.X / 2
end

-- 국자 안 내용물 모양: thickness 두께, color, material, transparency
function Station:setContents(props)
	local c = self.Contents
	-- 국자가 비면 3D 거품도 같이 사라짐 (붓기)
	if (props.thickness and props.thickness < 0.05) or props.Transparency == 1 then
		local foam = self.Ladle:FindFirstChild("FxFoam")
		if foam then
			foam:Destroy()
		end
	end
	for k, v in pairs(props) do
		if k == "thickness" then
			local s = c.Size
			c.Size = Vector3.new(v, s.Y, s.Z)
			-- 바닥(국자 윗면)을 기준으로 위로 쌓이게
			local base = self.Bowl.CFrame * CFrame.new(self.floor + v / 2, 0, 0)
			c.CFrame = base
		else
			c[k] = v
		end
	end
end

function Station:setHeap(name, amount01, color)
	local h = self.heaps[name]
	local a = math.clamp(amount01, 0, 1)
	h.part.Transparency = a <= 0.001 and 1 or 0
	if h.mound then
		-- 줄어들 때 납작하게 퍼진 채로 얇아짐 (바닥은 숟가락 면에 붙어 있음)
		local sz = Vector3.new(h.size.X * (0.6 + 0.4 * a), h.size.Y * (0.3 + 0.7 * a), h.size.Z * (0.6 + 0.4 * a))
		h.part.Size = sz
		h.part.CFrame = h.model:GetPivot() * h.baseLocal * CFrame.new(0, sz.Y / 2, 0)
		if color then
			h.part.Color = color
		end
		return
	end
	h.part.Size = h.size * (0.35 + 0.65 * a)
	if color then
		h.part.Color = color
	end
end

function Station:clearFx()
	Sfx.stopAll()
	self.fx:ClearAllChildren()
	for _, d in ipairs(self.Ladle:GetChildren()) do
		if d.Name:sub(1, 2) == "Fx" then
			d:Destroy()
		end
	end
end

function Station:reset()
	self:clearFx()
	for name, cf in pairs(self.rest) do
		if name ~= "Chopsticks" then
			self[name]:PivotTo(cf)
		end
	end
	self:restChopsticks()
	local c = self.Contents
	local r = self.contentsRest
	c.Size = r.Size
	c.CFrame = self.Bowl.CFrame * r.CFrame
	c.Color = r.Color
	c.Material = r.Material
	c.Transparency = r.Transparency
	for name, h in pairs(self.heaps) do
		h.part.Size = h.size
		h.part.Color = h.color
		h.part.Transparency = 0
	end
	self.Flame.Rate = 30
	self:presserSeeThrough(false)
	self:hidePresser(false)
	local chosen = self.Chopsticks:FindFirstChild("Chosen")
	if chosen then
		chosen:Destroy()
	end
	for _, p in ipairs(self.Chopsticks:GetChildren()) do
		if p.Name:sub(1, 7) == "Wrapped" then
			p.LocalTransparencyModifier = 0
		end
	end
end

-- 국자 손잡이를 잡은 플레이어 손 (사용자 요청 2026-11-18). 국자 모델 안에 넣어서 국자와 같이 움직임.
-- 손등이 손잡이 위, 네 손가락은 먼 쪽으로 감아 아래로, 엄지는 위쪽 가까운 쪽, 팔은 손잡이 끝에서 화면 앞쪽으로 빠짐.
-- 색은 아바타 피부색. 손잡이 위치는 국자 메시(LadleMesh) 꼭짓점으로 잰 값: 메시 로컬 (0, 0.2, 1.6~1.95)
local HAND_GRIP = Vector3.new(0, 0.2, 1.45) -- 손바닥 가운데 (국자 메시 로컬)
local HS = 1.8 -- 손 크기 (손잡이 폭 0.45에 맞춤)
local SLEEVE = Color3.fromRGB(238, 234, 226)

local function skinColor(player)
	local ch = player and player.Character
	local hand = ch and (ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm"))
	if hand and hand:IsA("BasePart") then
		return hand.Color
	end
	local bc = ch and ch:FindFirstChildOfClass("BodyColors")
	if bc then
		return bc.RightArmColor3
	end
	return Color3.fromRGB(234, 184, 146)
end

-- 플레이어 캐릭터의 진짜 오른팔(손·아래팔·위팔)을 복제해 국자 손잡이에 얹음 (사용자 요청: 만든 손 말고 캐릭터 손).
-- 캐릭터째 복제해서 피부색·셔츠가 그대로 보이고, 오른팔 말고는 숨김. 실패하면 부품으로 만든 손.
local ARM_KEEP = { RightUpperArm = true, RightLowerArm = true, RightHand = true, ["Right Arm"] = true }

-- 국자 손잡이 잡는 자리를 국자 피벗 회전만 뺀 기준(제자리 회전 rest 기준)으로: 붓기에서 손가락이 이 점을 잡음
function Station:ladleGripLocal()
	local mesh = self.Ladle:FindFirstChild("Mesh")
	local pv = self.Ladle:GetPivot()
	local world
	if mesh then
		world = (mesh.CFrame * CFrame.new(HAND_GRIP)).Position
	else
		local g = self.Ladle:FindFirstChild("Grip") or self.Ladle:FindFirstChild("Handle")
		world = g and g.Position or (pv.Position - Vector3.new(1.6, 0, 0))
	end
	local rot = self.rest.Ladle - self.rest.Ladle.Position
	return rot:VectorToObjectSpace(world - pv.Position)
end

function Station:attachHand(player)
	self:removeHand()
	local ch = player and player.Character
	local mesh = self.Ladle:FindFirstChild("Mesh")
	if not ch or not mesh or not ch:FindFirstChildOfClass("Humanoid") then
		return self:attachPartHand(player)
	end
	local was = ch.Archivable
	ch.Archivable = true
	local ok, copy = pcall(function()
		return ch:Clone()
	end)
	ch.Archivable = was
	if not ok or not copy then
		return self:attachPartHand(player)
	end
	copy.Name = "PlayerHand"
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	for _, c in ipairs(copy:GetChildren()) do
		if c:IsA("Accessory") then
			c:Destroy()
		elseif c:IsA("BasePart") then
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.Massless = true, false, false, false, true
			c.CastShadow = ARM_KEEP[c.Name] == true
			if not ARM_KEEP[c.Name] then
				c.Transparency = 1
				for _, d in ipairs(c:GetChildren()) do
					if d:IsA("Decal") then
						d:Destroy() -- 얼굴 등
					end
				end
			end
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
	end
	-- 배치: 손바닥이 손잡이 위에 엎어짐(손 -X = 아래), 팔은 손잡이 끝 너머 화면 앞쪽 위로 (손 Y = 어깨 쪽)
	local grip = mesh.CFrame * CFrame.new(HAND_GRIP)
	local ax = mesh.CFrame:VectorToWorldSpace(Vector3.zAxis)
	ax = Vector3.new(ax.X, 0, ax.Z).Unit
	local up = Vector3.yAxis
	local side = ax:Cross(up)
	if side.Z < 0 then
		side = -side
	end
	local dir = (ax * 0.8 + up * 0.18 + side * 0.55).Unit -- 거의 수평으로 (카메라 쪽으로 솟으면 화면을 가림)
	local xAxis = (up - dir * up:Dot(dir)).Unit
	local function put(p, center)
		p.CFrame = CFrame.fromMatrix(center, xAxis, dir)
	end
	local hand, lower, upper = copy:FindFirstChild("RightHand"), copy:FindFirstChild("RightLowerArm"), copy:FindFirstChild("RightUpperArm")
	local base = grip.Position + up * 0.04
	if hand and lower and upper then
		local hc = base + xAxis * (hand.Size.X / 2) + dir * (hand.Size.Y * 0.15)
		put(hand, hc)
		local lc = hc + dir * (hand.Size.Y / 2 + lower.Size.Y / 2 - 0.12)
		put(lower, lc)
		put(upper, lc + dir * (lower.Size.Y / 2 + upper.Size.Y / 2 - 0.12))
	else
		local arm = copy:FindFirstChild("Right Arm") -- R6: 팔 한 덩어리
		if not arm then
			copy:Destroy()
			return self:attachPartHand(player)
		end
		put(arm, base + xAxis * (arm.Size.X / 2) + dir * (arm.Size.Y / 2 - 0.25))
	end
	copy.Parent = self.Ladle
	self.hand = copy
end

-- (대신) 부품으로 만든 손
function Station:attachPartHand(player)
	self:removeHand()
	local mesh = self.Ladle:FindFirstChild("Mesh")
	local frame
	if mesh then
		frame = mesh.CFrame * CFrame.new(HAND_GRIP)
	else
		-- 메시가 없으면 손잡이 부품(Grip/Handle) 기준
		local g = self.Ladle:FindFirstChild("Grip") or self.Ladle:FindFirstChild("Handle")
		if not g then
			return
		end
		frame = g.CFrame * CFrame.Angles(0, math.rad(-90), 0)
	end
	-- 손 좌표: X = 손잡이 끝 쪽, Y = 위, Z = 화면 앞(카메라) 쪽
	local ax = frame.LookVector * -1 -- 메시 로컬 +Z (손잡이 끝 방향)
	if mesh then
		ax = mesh.CFrame:VectorToWorldSpace(Vector3.zAxis)
	end
	ax = Vector3.new(ax.X, 0, ax.Z).Unit
	local up = Vector3.yAxis
	local side = ax:Cross(up)
	if side.Z < 0 then
		side = -side
	end
	local o = frame.Position
	local skin = skinColor(player)
	local model = Instance.new("Model")
	model.Name = "PlayerHand"
	local function at(x, y, z)
		return o + (ax * x + up * y + side * z) * HS
	end
	local function part(shape, size, cf, color)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Color = color or skin
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	-- 원기둥을 두 점 사이에 (원기둥 축 = 부품 X)
	local function rod(a, b, d, color)
		local len = (b - a).Magnitude
		return part(Enum.PartType.Cylinder, Vector3.new(len, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color)
	end
	local basis = CFrame.fromMatrix(o, ax, up)
	-- 손등 (둥근 타원체)
	part(Enum.PartType.Ball, Vector3.new(0.72, 0.26, 0.58) * HS, basis + up * 0.13 * HS)
	-- 네 손가락: 손등 먼 쪽 끝에서 손잡이를 감아 아래로, 끝은 손잡이 밑
	for i, x in ipairs({ -0.24, -0.08, 0.08, 0.23 }) do
		local d = ((i == 4) and 0.11 or 0.13) * HS
		local top = at(x, 0.15, -0.24)
		local bend = at(x, -0.02, -0.3)
		local tip = at(x * 0.95, -0.1, -0.12)
		rod(top, bend, d)
		rod(bend, tip, d * 0.92)
		part(Enum.PartType.Ball, Vector3.one * d * 0.95, CFrame.new(tip))
	end
	-- 엄지: 손잡이 위 가까운 쪽, 그릇 쪽을 향해
	local t0 = at(0.12, 0.16, 0.2)
	local t1 = at(-0.22, 0.1, 0.24)
	rod(t0, t1, 0.15 * HS)
	part(Enum.PartType.Ball, Vector3.one * 0.15 * HS, CFrame.new(t1))
	-- 손목·팔: 손잡이 끝 너머로, 화면 앞쪽 위로 빠짐 (손목 쪽은 피부, 그 뒤는 소매)
	local wrist = at(0.38, 0.14, 0.04)
	local dir = (ax * 0.8 + up * 0.35 + side * 0.55).Unit
	rod(wrist - dir * 0.1, wrist + dir * 1.6, 0.36 * HS)
	rod(wrist + dir * 1.5, wrist + dir * 4.5, 0.44 * HS, SLEEVE)
	model.Parent = self.Ladle
	self.hand = model
end

function Station:removeHand()
	if self.hand then
		self.hand:Destroy()
		self.hand = nil
	end
end

-- 누름판은 누를 때도 금속 그대로 보인다 (사용자 요청: 반투명 안 함). 부르는 쪽은 그대로 둠
-- 누름판 통째로 숨기기 (2026-11-20 "반죽 부을 때 철판 옆에 뜨는 거 삭제"). 광택 메시(SurfaceAppearance)는
-- LocalTransparencyModifier로 다 안 숨겨져서 Transparency·그림자·외곽선을 직접 끔. false면 원래대로
function Station:hidePresser(on)
	for p, t in pairs(self.presserParts) do
		p.Transparency = on and 1 or t
		if p:GetAttribute("OrigShadow") == nil then
			p:SetAttribute("OrigShadow", p.CastShadow)
		end
		p.CastShadow = not on and p:GetAttribute("OrigShadow") or false
	end
	local outline = self.Presser:FindFirstChild("ToonOutline")
	if outline then
		outline.Enabled = not on
	end
end

function Station:presserSeeThrough(on)
	for p, t in pairs(self.presserParts) do
		p.Transparency = t
	end
end

-- 젓가락 내려놓기: 부품마다 처음 자리로 (고른 한 짝은 Stick1 자리에)
function Station:restChopsticks()
	for p, cf in pairs(self.chopRest) do
		if p.Parent then
			p.CFrame = cf
		end
	end
	local chosen = self.Chopsticks:FindFirstChild("Chosen")
	if chosen then
		chosen.CFrame = self.Chopsticks.Stick1.CFrame * CFrame.Angles(math.rad(90), 0, 0) * (chosen:GetAttribute("Fix") and CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.pi, 0, 0) or CFrame.new())
	end
end

-- 고른 나무젓가락 한 짝으로 젓기 (테이블 위 포장된 젓가락은 숨김)
function Station:useChopstick(pair, side)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cs = assets and assets:FindFirstChild("Chopsticks")
	local tpl = cs and cs:FindFirstChild(("Stick%d%s"):format(pair, side))
	if not tpl then
		return
	end
	for _, p in ipairs(self.Chopsticks:GetChildren()) do
		if p.Name:sub(1, 7) == "Wrapped" then
			p.LocalTransparencyModifier = 1
		end
	end
	local old = self.Chopsticks:FindFirstChild("Chosen")
	if old then
		old:Destroy()
	end
	local c = tpl:Clone()
	c.Name = "Chosen"
	-- 길이를 X로 눕힌 메시(나뭇결용)는 90° 세워서 예전과 같은 방향으로
	c:SetAttribute("Fix", c.Size.X > c.Size.Y * 2)
	c.CFrame = self.Chopsticks.Stick1.CFrame * CFrame.Angles(math.rad(90), 0, 0) * (c:GetAttribute("Fix") and CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.pi, 0, 0) or CFrame.new())
	c.Parent = self.Chopsticks
end

-- 프레임마다 목표 자세로 다가감 (rate 25 ≈ 0.12초에 95%)
function Station.approach(current, target, dt, rate)
	return current:Lerp(target, 1 - math.exp(-(rate or 25) * dt))
end

function Station:springTo(model, target, dt, rate)
	local cur = model:GetPivot()
	model:PivotTo(Station.approach(cur, target, dt, rate))
	return (cur.Position - target.Position).Magnitude < 0.01
end

-- 작은 부품 만들기 (효과용, 이 클라이언트에만 있음)
function Station:fxPart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent or self.fx
	return p
end

-- 쏟아지는 알갱이 파티클 (숟가락에 붙임)
function Station:pourEmitter(model, color)
	local att = model.PrimaryPart:FindFirstChild("PourAtt")
	local pe = att:FindFirstChild("Pour")
	if not pe then
		pe = Instance.new("ParticleEmitter")
		pe.Name = "Pour"
		-- 고운 알갱이 줄기: 작고 많이, 크기가 제각각
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.045, 0.015), NumberSequenceKeypoint.new(1, 0.03, 0.01) })
		pe.Lifetime = NumberRange.new(0.35, 0.5)
		pe.Speed = NumberRange.new(0.3, 0.9)
		pe.SpreadAngle = Vector2.new(14, 14)
		pe.Acceleration = Vector3.new(0, -30, 0)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-200, 200)
		pe.Rate = 260
		pe.EmissionDirection = Enum.NormalId.Left
		pe.LightInfluence = 1
		pe.Enabled = false
		pe.Parent = att
	end
	pe.Color = ColorSequence.new(color)
	return pe
end

-- 고른 도안으로 모양 틀 바꿔 끼우기 (이 플레이어 화면에서만). 틀은 제자리에서 바꾼다.
function Station:setCutter(id)
	self.Cutter:PivotTo(self.rest.Cutter)
	return CutterRig.apply(self.Cutter, id)
end

return Station
