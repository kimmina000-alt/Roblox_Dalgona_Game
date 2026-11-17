-- 작업대 부품 찾기, 제자리 자세 기억, 리셋, 스프링 복귀 도우미
-- 클라이언트에서 바꾸는 위치·색은 이 플레이어 화면에서만 보인다 (Phase 1 혼자 테스트용).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Station = {}
Station.__index = Station

local MOVABLE = { "Ladle", "WoodSpoon", "SodaSpoon", "Presser", "Cutter", "Chopsticks" }
local CutterRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CutterRig"))

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

	self.rest = {}
	for _, name in ipairs(MOVABLE) do
		self.rest[name] = self[name]:GetPivot()
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
		return self.Bowl.Position.Y + self.bowlHalf + 0.03
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
			local base = self.Bowl.CFrame * CFrame.new(0.226 + v / 2, 0, 0)
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
	h.part.Size = h.size * (0.35 + 0.65 * a)
	if color then
		h.part.Color = color
	end
end

function Station:clearFx()
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
		self[name]:PivotTo(cf)
	end
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

-- 누름판은 누를 때도 금속 그대로 보인다 (사용자 요청: 반투명 안 함). 부르는 쪽은 그대로 둠
function Station:presserSeeThrough(on)
	for p, t in pairs(self.presserParts) do
		p.Transparency = t
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
	c.CFrame = self.Chopsticks.Stick1.CFrame * CFrame.Angles(math.rad(90), 0, 0) * (c:GetAttribute("Fix") and CFrame.Angles(0, 0, math.rad(90)) or CFrame.new())
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
