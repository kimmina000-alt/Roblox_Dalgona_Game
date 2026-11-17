-- 철판 위 달고나 반죽: 울퉁불퉁한 언덕 → 두꺼운 원판 → 넓고 얇은 원판 (부피는 그대로)
-- 원 밖에 부으면 철판에 들러붙어 찌그러짐(타원). 갈라짐, 각인, Perfect 반짝임.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DalgonaConfig"))

local Dalgona = {}
Dalgona.__index = Dalgona

local UP = CFrame.Angles(0, 0, math.rad(90))

function Dalgona.new(station, center, color, volume, ellipse)
	local self = setmetatable({}, Dalgona)
	self.S = station
	self.center = center -- 철판 윗면 위의 점
	self.color = color
	self.V = volume
	self.e = ellipse or 0
	self.h = Config.Press.h0
	self.body = station:fxPart(station.fx, { Name = "Dalgona", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic })
	self.dome = station:fxPart(station.fx, { Name = "DalgonaDome", Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.SmoothPlastic })
	self.lumps = {}
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		self.lumps[i] = { part = station:fxPart(station.fx, { Name = "DalgonaLump", Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.SmoothPlastic }), a = a, r = 0.25 + 0.08 * (i % 2) }
	end
	self:setThickness(self.h)
	return self
end

function Dalgona:diameter(h)
	return 2 * math.sqrt(self.V / (math.pi * h))
end

function Dalgona:setThickness(h)
	h = math.max(h, 0.04)
	self.h = h
	local d = self:diameter(h)
	local k = math.sqrt(1 + self.e)
	local c = self.center
	self.body.Size = Vector3.new(h * 0.75, d * k, d / k)
	self.body.CFrame = CFrame.new(c.X, c.Y + h * 0.375, c.Z) * UP
	-- 언덕 모양: 두꺼울 때만 위에 둥근 봉우리와 덩어리
	local s = math.clamp((h - 0.22) / (Config.Press.h0 - 0.22), 0, 1)
	local dd = d * 0.8 * s
	self.dome.Transparency = s < 0.05 and 1 or 0
	self.dome.Size = Vector3.new(dd, math.max(dd * 0.55, 0.01), dd)
	self.dome.CFrame = CFrame.new(c.X, c.Y + h * 0.75, c.Z)
	for _, l in ipairs(self.lumps) do
		local ls = 0.35 * s
		l.part.Transparency = s < 0.05 and 1 or 0
		l.part.Size = Vector3.one * math.max(ls, 0.01)
		l.part.CFrame = CFrame.new(c.X + math.cos(l.a) * l.r * d, c.Y + h * 0.6, c.Z + math.sin(l.a) * l.r * d)
	end
end

function Dalgona:topY()
	return self.center.Y + self.h * 0.75
end

function Dalgona:radius()
	return self:diameter(self.h) / 2
end

function Dalgona:setColor(c)
	self.color = c
	self.body.Color = c
	self.dome.Color = c
	for _, l in ipairs(self.lumps) do
		l.part.Color = c
	end
end

-- 가장자리 갈라짐 (진한 선)
function Dalgona:crack(count, inward)
	local r = self:radius()
	local y = self:topY() + 0.006
	for i = 1, count or 5 do
		local a = math.random() * 2 * math.pi
		local len = 0.3 + math.random() * (inward or 0.4)
		local from = Vector3.new(self.center.X + math.cos(a) * r, y, self.center.Z + math.sin(a) * r)
		local to = from - Vector3.new(math.cos(a + (math.random() - 0.5) * 0.6), 0, math.sin(a + (math.random() - 0.5) * 0.6)) * len
		self.S:fxPart(self.S.fx, {
			Name = "Crack",
			Size = Vector3.new(0.035, 0.012, len),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = Color3.fromRGB(70, 40, 20),
			Material = Enum.Material.SmoothPlastic,
		})
	end
end

-- 모양 틀 자국: 철사 부품들을 반죽 윗면에 진하게 복사
function Dalgona:engrave(wires, clarity)
	local y = self:topY() + 0.008
	local dark = self.color:Lerp(Color3.fromRGB(80, 44, 16), 0.65)
	for _, w in ipairs(wires) do
		local cf = w.CFrame
		self.S:fxPart(self.S.fx, {
			Name = "Engrave",
			Size = Vector3.new(0.07, 0.014, w.Size.Z),
			CFrame = cf + Vector3.new(0, y - cf.Position.Y, 0),
			Color = dark,
			Transparency = 0.6 * (1 - math.clamp(clarity, 0, 1)),
			Material = Enum.Material.SmoothPlastic,
		})
	end
end

function Dalgona:sparkle()
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0.05, 0, 0)
	att.Parent = self.body
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Rate = 14
	pe.Speed = NumberRange.new(0.5, 1)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.EmissionDirection = Enum.NormalId.Right
	pe.Parent = att
end

return Dalgona
