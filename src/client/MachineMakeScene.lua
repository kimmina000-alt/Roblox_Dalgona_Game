-- 2·3단계 기계 직접 만들기 장면 (MachineMake가 씀). 내 화면에서만 만드는 작은 작업대: 참고 영상 "달고나 판매기" 윗판처럼
-- 동전 구멍 · 설탕 배출구 · 전기 화구 · 설탕 섞은 소다 통 · 금형판(2칸 / 5칸, 고른 도안 모양) · 물그릇 · 국자 · 나무젓가락.
-- 게임 맵과 겹치지 않게 높은 곳(ORIGIN)에 만들고, 위에서 내려다보는 카메라(화면 위 = -Z)로 봄. 끝나면 지움.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DalgonaLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaLook"))

local Scene = {}
Scene.__index = Scene

local ORIGIN = CFrame.new(0, 900, 0)
local C = {
	steel = Color3.fromRGB(170, 176, 182),
	pink = Color3.fromRGB(240, 150, 176),
	dark = Color3.fromRGB(70, 72, 78),
	iron = Color3.fromRGB(54, 52, 52),
	copper = Color3.fromRGB(214, 132, 72),
	wood = Color3.fromRGB(196, 150, 104),
	white = Color3.fromRGB(250, 250, 248),
	water = Color3.fromRGB(150, 196, 222),
	coil = Color3.fromRGB(255, 96, 40),
	floor = Color3.fromRGB(176, 140, 108),
	sign = Color3.fromRGB(255, 240, 214),
}

local function part(parent, name, size, cf, color, mat, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
Scene.part = part

-- 세운 원기둥 (Part 원기둥은 X축이 길이)
local function cyl(parent, name, h, d, pos, color, mat, props)
	local p = part(parent, name, Vector3.new(h, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
Scene.cyl = cyl

-- stage: 2 철제 판매기(회색) / 3 분홍 자판기, cavities: 금형판 칸 수, shape: 도안 id
function Scene.new(stage, cavities, shape)
	local self = setmetatable({}, Scene)
	local m = Instance.new("Model")
	m.Name = "MachineMakeScene"
	self.model = m
	self.origin = ORIGIN
	local O = ORIGIN.Position
	local body = stage == 3 and C.pink or C.steel
	-- 바닥(카메라에 하늘이 안 보이게) + 기계 윗판
	part(m, "Floor", Vector3.new(80, 1, 60), CFrame.new(O + Vector3.new(0, -4, 0)), C.floor, Enum.Material.WoodPlanks)
	part(m, "Top", Vector3.new(17, 0.6, 11), CFrame.new(O + Vector3.new(0, -0.3, 0)), body, Enum.Material.DiamondPlate)
	part(m, "Body", Vector3.new(17, 3.4, 11), CFrame.new(O + Vector3.new(0, -2.3, 0)), body:Lerp(C.dark, 0.25), Enum.Material.Metal)
	-- 뒤쪽 배출 상자 (설탕) + 앞 동전 판
	local box = part(m, "SugarBox", Vector3.new(3, 2.2, 2.4), CFrame.new(O + Vector3.new(-4.6, 1.1, -3.9)), body:Lerp(C.dark, 0.1), Enum.Material.Metal)
	self.nozzle = part(m, "Nozzle", Vector3.new(0.7, 0.7, 0.9), CFrame.new(O + Vector3.new(-4.6, 1.5, -2.5)), C.dark, Enum.Material.Metal)
	self.spoutPos = O + Vector3.new(-4.6, 1.1, -2.2)
	local coin = part(m, "CoinPlate", Vector3.new(1.6, 0.25, 1.6), CFrame.new(O + Vector3.new(-7.3, 0.13, -3.9)), Color3.fromRGB(200, 200, 196), Enum.Material.Metal)
	part(m, "CoinSlot", Vector3.new(0.2, 0.3, 0.9), CFrame.new(O + Vector3.new(-7.3, 0.2, -3.9)), C.iron, Enum.Material.Metal)
	self.coinPos = coin.Position
	-- 간판 (300원 달고나 · 가상 문구)
	local sign = part(m, "Sign", Vector3.new(6, 0.15, 1.6), CFrame.new(O + Vector3.new(1.5, 0.08, -4.6)), C.sign, Enum.Material.SmoothPlastic)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "달고나 · 국자를 대고 설탕을 받으세요 · 뜨거우니 조심!"
	t.TextScaled = true
	t.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	t.TextColor3 = Color3.fromRGB(200, 40, 40)
	t.Parent = g
	-- 전기 화구 (코일 고리, 켜지면 빨갛게)
	self.burnerPos = O + Vector3.new(-1.2, 0, -1.4)
	cyl(m, "BurnerBase", 0.2, 2.6, self.burnerPos + Vector3.new(0, 0.1, 0), C.dark, Enum.Material.Metal)
	self.coil = {}
	for i, d in ipairs({ 2.1, 1.4, 0.7 }) do
		local r = cyl(m, "Coil" .. i, 0.12, d, self.burnerPos + Vector3.new(0, 0.26, 0), C.iron, Enum.Material.Metal)
		table.insert(self.coil, r)
		if i < 3 then
			cyl(m, "CoilGap" .. i, 0.13, d - 0.25, self.burnerPos + Vector3.new(0, 0.27, 0), C.dark, Enum.Material.Metal)
		end
	end
	-- 설탕 섞은 소다 통
	self.sodaPos = O + Vector3.new(3.6, 0, -2.6)
	cyl(m, "SodaCup", 1.3, 1.5, self.sodaPos + Vector3.new(0, 0.65, 0), Color3.fromRGB(196, 200, 206), Enum.Material.Metal)
	cyl(m, "SodaPowder", 0.1, 1.3, self.sodaPos + Vector3.new(0, 1.25, 0), C.white, Enum.Material.Sand)
	-- 물그릇
	self.waterPos = O + Vector3.new(-6, 0, 2.6)
	cyl(m, "Bowl", 0.9, 2.6, self.waterPos + Vector3.new(0, 0.45, 0), Color3.fromRGB(190, 190, 186), Enum.Material.Metal)
	self.water = cyl(m, "Water", 0.05, 2.3, self.waterPos + Vector3.new(0, 0.82, 0), C.water, Enum.Material.Glass, { Transparency = 0.35 })
	-- 금형판 (무쇠, 칸 = 고른 도안 모양 자국)
	local cols = cavities <= 2 and cavities or 3
	local rows = math.ceil(cavities / cols)
	local plateW, plateD = 2.4 * cols + 1, 2.4 * rows + 1
	self.platePos = O + Vector3.new(2.6, 0, 2.2)
	part(m, "MoldPlate", Vector3.new(plateW, 0.5, plateD), CFrame.new(self.platePos + Vector3.new(0, 0.25, 0)), C.iron, Enum.Material.Slate)
	self.cavities = {}
	for i = 1, cavities do
		local c = (i - 1) % cols
		local r = math.floor((i - 1) / cols)
		local rowN = math.min(cols, cavities - r * cols)
		local x = (c - (rowN - 1) / 2) * 2.4
		local z = (r - (rows - 1) / 2) * 2.4
		local pos = self.platePos + Vector3.new(x, 0.52, z)
		-- 칸 자국: 어두운 달고나 모양 (DalgonaLook을 진한 색으로)
		local mark = DalgonaLook.build({ s = shape, g = "Burnt" }, 1.9)
		mark.Name = "Cavity" .. i
		for _, p in ipairs(mark:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanQuery = false
				p.CastShadow = false
				if p.Name == "Disc" then
					p.Color = Color3.fromRGB(36, 34, 34)
				end
			end
		end
		mark:PivotTo(CFrame.new(pos))
		mark.Parent = m
		table.insert(self.cavities, { pos = pos, fill = 0, look = nil, stick = nil })
	end
	-- 국자 (구리 그릇 + 손잡이 + 내용물)
	self.ladle = Instance.new("Model")
	self.ladle.Name = "Ladle"
	self.ladle.Parent = m
	self.ladleBowl = cyl(self.ladle, "Bowl", 0.5, 1.8, Vector3.zero, C.copper, Enum.Material.Metal)
	self.ladleIn = cyl(self.ladle, "Inside", 0.05, 1.5, Vector3.new(0, 0.26, 0), C.copper:Lerp(C.dark, 0.35), Enum.Material.Metal)
	part(self.ladle, "Handle", Vector3.new(0.25, 0.18, 3.4), CFrame.new(0, 0.3, 2.4) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(60, 150, 90), Enum.Material.SmoothPlastic)
	self.contents = cyl(self.ladle, "Contents", 0.06, 1.4, Vector3.new(0, 0.28, 0), C.white, Enum.Material.Sand, { Transparency = 1 })
	self.ladle.PrimaryPart = self.ladleBowl
	self.ladleRest = O + Vector3.new(-3.2, 0.25, 2.6)
	self:ladleTo(self.ladleRest)
	-- 나무젓가락 (보일 때만)
	self.stick = part(m, "Chopstick", Vector3.new(0.14, 0.14, 4), CFrame.new(O + Vector3.new(6, 1, 3)), C.wood, Enum.Material.Wood, { Transparency = 1 })
	self.stickTip = part(m, "StickSoda", Vector3.new(0.3, 0.3, 0.45), CFrame.new(O), C.white, Enum.Material.Sand, { Transparency = 1, Shape = Enum.PartType.Ball })
	m.Parent = workspace
	return self
end

-- 국자 그릇 가운데를 pos로
function Scene:ladleTo(pos)
	self.ladle:PivotTo(CFrame.new(pos))
end
function Scene:ladlePos()
	return self.ladleBowl.Position
end

-- 내용물: amount 0~1 (두께), color, material, visible
function Scene:setContents(amount, color, mat)
	local c = self.contents
	if amount <= 0.01 then
		c.Transparency = 1
		return
	end
	local h = 0.05 + 0.35 * math.clamp(amount, 0, 1.4)
	c.Transparency = 0
	c.Size = Vector3.new(h, 1.4, 1.4)
	c.CFrame = CFrame.new(self.ladleBowl.Position + Vector3.new(0, 0.05 + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	if color then
		c.Color = color
	end
	if mat then
		c.Material = mat
	end
end

-- 화구 코일 밝기 0~1
function Scene:setHeat(k)
	for _, r in ipairs(self.coil) do
		r.Color = C.iron:Lerp(C.coil, k)
		r.Material = k > 0.3 and Enum.Material.Neon or Enum.Material.Metal
	end
end

-- 젓가락: tip = 끝 자리, 손잡이는 화면 아래 쪽으로 기울임
function Scene:setStick(tip, visible)
	local s = self.stick
	if not visible then
		s.Transparency = 1
		self.stickTip.Transparency = 1
		return
	end
	s.Transparency = 0
	local dir = Vector3.new(0.3, 1, 0.55).Unit
	local center = tip + dir * 2
	s.CFrame = CFrame.lookAt(center, center + dir)
end

function Scene:setStickSoda(tip, amount)
	local p = self.stickTip
	if amount <= 0 then
		p.Transparency = 1
		return
	end
	p.Transparency = 0
	local d = 0.25 + 0.08 * amount
	p.Size = Vector3.new(d, d, d * 1.3)
	p.CFrame = CFrame.new(tip + Vector3.new(0.05, 0.12, 0.08))
end

-- 금형판 칸 i에 붓는 반죽 (fill 0~1.3), 다 되면 shape 모양 달고나
function Scene:setCavityFill(i, fill, shape)
	local c = self.cavities[i]
	c.fill = fill
	if fill <= 0.02 then
		return
	end
	if not c.look then
		c.look = DalgonaLook.build({ s = shape, g = "Good" }, 1.9)
		c.look.Name = "Fill" .. i
		c.look.Parent = self.model
	end
	-- 붓는 동안: 가운데부터 넓어짐 (그림 면 위)
	local k = math.clamp(fill, 0, 1)
	for _, p in ipairs(c.look:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = fill < 0.15 and 0.5 or 0
		end
	end
	c.look:ScaleTo(math.max(0.15, k))
	c.look:PivotTo(CFrame.new(c.pos + Vector3.new(0, 0.04 + 0.04 * math.min(fill, 1.3), 0)))
	if fill > 1.15 then
		-- 넘침: 둘레로 흘러나온 얇은 반죽
		if not c.spill then
			c.spill = cyl(self.model, "Spill" .. i, 0.03, 2.4, c.pos + Vector3.new(0, 0.01, 0), Color3.fromRGB(214, 150, 70), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
		end
	end
end

function Scene:destroy()
	self.model:Destroy()
end

return Scene
