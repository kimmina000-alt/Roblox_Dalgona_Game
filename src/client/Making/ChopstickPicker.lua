-- 0. 나무젓가락 고르기 (제작 시작 전)
-- 화면 왼쪽의 포장된 나무젓가락을 누르면 → 가운데로 사선으로 커짐 → 누르면 "찍" 포장지2가 찢어져 나감
-- → 누르면 나무젓가락 1 또는 2(랜덤)를 꺼냄 → 누르면 "뽀각" 두 짝으로 쪼개짐 → 누른 쪽 한 짝으로 제작 시작.
-- 메시는 ReplicatedStorage.Assets.Chopsticks (사용자 Blender 모델 dalgona_joggalack.glb). 3D는 ViewportFrame 안에서 보여 준다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaConfig"))

local Picker = {}

local TILT = -35 -- 사선 각도
local STICK_RISE = 0.19 -- 포장지 안에서 젓가락 가운데 높이 (glb 기준)

local function play(id)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.9
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function easeOut(a)
	return 1 - (1 - a) * (1 - a)
end

-- 반환: { pair = 1 | 2, side = "A" | "B" } 또는 nil(중간에 나감)
function Picker.run(ctx)
	local ui = ctx.ui
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cs = assets and assets:FindFirstChild("Chopsticks")
	if not cs then
		return { pair = 1, side = "A" } -- 에셋이 없으면 건너뜀
	end

	local holder = Instance.new("Frame")
	holder.Name = "ChopstickPicker"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 24, 0.6, 0)
	holder.Size = UDim2.fromOffset(150, 240)
	holder.ZIndex = 30
	holder.Parent = ui.root
	-- 크게 볼 때 뒤 화면을 어둡게. QUALITY 창은 고르는 동안 숨김
	local dim = Instance.new("Frame")
	dim.Name = "PickerDim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 29
	dim.Parent = ui.root
	local quality = ui.root:FindFirstChild("Quality")
	if quality then
		quality.Visible = false
	end

	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.BackgroundTransparency = 1
	vpf.Ambient = Color3.fromRGB(170, 166, 160)
	vpf.LightColor = Color3.fromRGB(255, 250, 240)
	vpf.LightDirection = Vector3.new(-0.6, -1, -0.8)
	vpf.ZIndex = 30
	vpf.Parent = holder
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, 7), Vector3.zero)
	cam.Parent = vpf
	vpf.CurrentCamera = cam

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 31
	hit.Parent = holder

	local angle = 0
	local items = {}
	local function add(name, localCf, transparency)
		local p = cs:FindFirstChild(name):Clone()
		p.Transparency = transparency or 0
		p.Parent = vpf
		local it = { part = p, cf = localCf }
		items[name] = it
		return it
	end
	local function render()
		local pivot = CFrame.Angles(0, 0, math.rad(angle))
		for _, it in pairs(items) do
			it.part.CFrame = pivot * it.cf
		end
	end
	local function animate(dur, fn)
		local t = 0
		while t < dur do
			local dt = ctx.frame()
			if not dt then
				return false
			end
			t += dt
			fn(easeOut(math.min(t / dur, 1)))
			render()
		end
		return true
	end
	local clicked = nil
	hit.Activated:Connect(function(input)
		clicked = input and Vector2.new(input.Position.X, input.Position.Y) or Vector2.zero
	end)
	local function waitClick()
		clicked = nil
		while not clicked do
			if not ctx.frame() then
				return nil
			end
		end
		return clicked
	end
	local function finish(result)
		holder:Destroy()
		dim:Destroy()
		if quality then
			quality.Visible = true
		end
		return result
	end

	local wrap1 = add("Wrap1", CFrame.new(cs.Wrap1:GetAttribute("Offset")))
	local wrap2 = add("Wrap2", CFrame.new(cs.Wrap2:GetAttribute("Offset")))
	local wrapOpen = add("WrapOpen", CFrame.new(cs.WrapOpen:GetAttribute("Offset")), 1)
	render()

	-- 1) 왼쪽의 포장된 나무젓가락 누르기
	ui:say("왼쪽 나무젓가락을 눌러요", "포장된 나무젓가락을 꺼내요")
	if not waitClick() then
		return finish(nil)
	end
	-- 2) 화면 가운데로 사선으로 커지며 줌
	local rootSize = ui.root.Size
	local h = rootSize.Y.Offset * 0.82
	TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.min(h * 0.75, rootSize.X.Offset * 0.6), h),
	}):Play()
	TweenService:Create(dim, TweenInfo.new(0.35), { BackgroundTransparency = 0.45 }):Play()
	if not animate(0.35, function(a)
		angle = TILT * a
	end) then
		return finish(nil)
	end
	ui:say("포장지를 눌러 찢어요", "")

	-- 3) 찍 — 포장지2가 찢어져 날아가고, 젓가락이 든 모습이 보임
	if not waitClick() then
		return finish(nil)
	end
	play(Config.Sounds.paperTear)
	ctx.ui:buzz(0.3, 0.06)
	local w2start = wrap2.cf
	if not animate(0.35, function(a)
		wrap2.cf = w2start * CFrame.new(0.7 * a, 1.1 * a, 0) * CFrame.Angles(0, 0, math.rad(-50 * a))
		wrap2.part.Transparency = a
	end) then
		return finish(nil)
	end
	wrap1.part.Transparency = 1
	wrapOpen.part.Transparency = 0
	render()
	ui:say("나무젓가락을 눌러 꺼내요", "")

	-- 4) 꺼내기: 나무젓가락 1 또는 2가 랜덤으로 나옴
	if not waitClick() then
		return finish(nil)
	end
	local pair = math.random(1, 2)
	local a = add(("Stick%dA"):format(pair), CFrame.new(cs:FindFirstChild(("Stick%dA"):format(pair)):GetAttribute("Offset") + Vector3.new(0, STICK_RISE, 0)))
	local b = add(("Stick%dB"):format(pair), CFrame.new(cs:FindFirstChild(("Stick%dB"):format(pair)):GetAttribute("Offset") + Vector3.new(0, STICK_RISE, 0)))
	wrapOpen.part.Transparency = 1
	wrap1.part.Transparency = 0
	local aStart, bStart, wStart = a.cf, b.cf, wrap1.cf
	if not animate(0.45, function(t)
		a.cf = aStart + Vector3.new(0, 2.4 * t, 0)
		b.cf = bStart + Vector3.new(0, 2.4 * t, 0)
		wrap1.cf = wStart + Vector3.new(0, -1.0 * t, 0)
		wrap1.part.Transparency = t
	end) then
		return finish(nil)
	end
	aStart, bStart = a.cf, b.cf
	if not animate(0.25, function(t)
		a.cf = aStart + Vector3.new(0, -(2.4 + STICK_RISE) * t, 0)
		b.cf = bStart + Vector3.new(0, -(2.4 + STICK_RISE) * t, 0)
	end) then
		return finish(nil)
	end
	ui:say("젓가락을 눌러 쪼개요", "")

	-- 5) 뽀각 — 두 짝으로 쪼개짐
	if not waitClick() then
		return finish(nil)
	end
	play(Config.Sounds.stickSnap)
	ctx.ui:buzz(0.5, 0.08)
	aStart, bStart = a.cf, b.cf
	if not animate(0.22, function(t)
		a.cf = aStart * CFrame.new(0.32 * t, 0, 0) * CFrame.Angles(0, 0, math.rad(-7 * t))
		b.cf = bStart * CFrame.new(-0.32 * t, 0, 0) * CFrame.Angles(0, 0, math.rad(7 * t))
	end) then
		return finish(nil)
	end
	ui:say("쓸 젓가락 한 짝을 골라요", "누른 쪽으로 설탕을 저어요")

	-- 6) 누른 쪽 한 짝 고르기 (A는 오른쪽, B는 왼쪽)
	local pos = waitClick()
	if not pos then
		return finish(nil)
	end
	local center = holder.AbsolutePosition + holder.AbsoluteSize / 2
	local side = pos.X >= center.X and "A" or "B"
	local chosen, other = (side == "A") and a or b, (side == "A") and b or a
	local cStart = chosen.cf
	if not animate(0.3, function(t)
		other.part.Transparency = t
		chosen.cf = cStart:Lerp(CFrame.new(0, 0, 0.5), t)
	end) then
		return finish(nil)
	end
	ctx.ui:buzz(0.3, 0.05)
	TweenService:Create(holder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(0, 0),
	}):Play()
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	local t = 0
	while t < 0.3 do
		local dt = ctx.frame()
		if not dt then
			return finish(nil)
		end
		t += dt
	end
	return finish({ pair = pair, side = side })
end

return Picker
