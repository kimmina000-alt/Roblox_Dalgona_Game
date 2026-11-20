-- 0. 나무젓가락 고르기 (제작 시작 전)
-- 화면 왼쪽의 포장된 나무젓가락을 누르면 → 가운데로 사선으로 커짐 → 누르면 "찍" 포장지2가 찢어져 나감
-- → 누르면 나무젓가락 1 또는 2(랜덤)를 꺼냄 → 누르면 "뽀각" 두 짝으로 쪼개짐 → 누른 쪽 한 짝으로 제작 시작.
-- 메시는 ReplicatedStorage.Assets.Chopsticks (사용자 Blender 모델 dalgona_joggalack.glb). 3D는 ViewportFrame 안에서 보여 준다.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaConfig"))

local Picker = {}

-- 나무젓가락 메시가 길이를 X축으로 눕힌 판(나뭇결이 X축을 따라감)이면 예전 판(길이 Y)처럼 세우는 보정
local function stickFix(p)
	if p.Size.X > p.Size.Y * 2 then
		-- 90° 세운 뒤 길이 축으로 180° 뒤집음: 쪼개진 두 짝의 안쪽(붙어 있던) 면이 서로 마주 보게
		return CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.new()
end

local TILT = -35 -- 사선 각도
local STICK_RISE = 0.19 -- 포장지 안에서 젓가락 가운데 높이 (glb 기준)

-- 효과음은 게임 시작 때 미리 불러 두고(누를 때 만들면 불러오는 동안 늦게 들림),
-- 파일 앞쪽 무음은 건너뛰고 재생한다.
local sounds = {}
local function getSound(key)
	local s = sounds[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Picker_" .. key
		s.SoundId = Config.Sounds[key]
		s.Volume = 0.9
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(Config.Sounds[key .. "Start"] or 0, 60)
		s.Parent = SoundService
		sounds[key] = s
	end
	return s
end
task.spawn(function()
	ContentProvider:PreloadAsync({ getSound("paperTear"), getSound("stickSnap") })
end)

local function play(key)
	local s = getSound(key)
	s:Stop()
	s:Play()
end

local function easeOut(a)
	return 1 - (1 - a) * (1 - a)
end

-- 반환: { pair = 1 | 2, side = "A" | "B" } 또는 nil(중간에 나감)
-- opts.from = 젓가락 통에서 막 뽑은 포장 젓가락(월드 부품): 1) 누르기를 건너뛰고 그 자리에서 바로 커짐 (2026-11-19)
function Picker.run(ctx, opts)
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
	-- 그림자 대비를 낮춤: 포장지 찢는 이음매에 생기던 어두운 줄이 안 보이게 (입체감은 조금 남김)
	vpf.Ambient = Color3.fromRGB(214, 211, 204)
	vpf.LightColor = Color3.fromRGB(115, 112, 106)
	vpf.LightDirection = Vector3.new(-0.3, -0.4, -1)
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
	-- 만화 외곽선 (2026-11-20): ViewportFrame 안에서는 Highlight가 안 그려져서, 조각마다 조금 큰 짙은 갈색 복제본을
	-- 바로 뒤(카메라 반대쪽)에 둬 테두리처럼 보이게 함
	local OUTLINE = Color3.fromRGB(92, 52, 34)
	local OUT_W = 0.025 -- 테두리 두께 (조각 크기에 더함). 2026-11-20 "너무 두꺼움": 다른 도구 외곽선만큼 가늘게
	local function add(name, localCf, transparency)
		local p = cs:FindFirstChild(name):Clone()
		p.Transparency = transparency or 0
		p.Parent = vpf
		local o = p:Clone()
		o.Name = name .. "_Outline"
		for _, c in ipairs(o:GetChildren()) do
			c:Destroy()
		end
		o.Color = OUTLINE
		o.Material = Enum.Material.SmoothPlastic
		if o:IsA("MeshPart") then
			o.TextureID = ""
		end
		o.Size = p.Size + Vector3.one * OUT_W
		o.Parent = vpf
		local it = { part = p, outline = o, cf = localCf, fix = name:sub(1, 5) == "Stick" and stickFix(p) or CFrame.new() }
		items[name] = it
		return it
	end
	local function render()
		local pivot = CFrame.Angles(0, 0, math.rad(angle))
		for _, it in pairs(items) do
			local cf = pivot * it.cf * it.fix
			it.part.CFrame = cf
			-- 테두리는 같은 자리에서 카메라 반대쪽(-Z)으로 살짝 뒤
			it.outline.CFrame = cf - Vector3.new(0, 0, 0.12)
			it.outline.Transparency = it.part.Transparency
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
			quality.Visible = false -- 퍼센트 창은 안 씀 (2026-11-20)
		end
		return result
	end

	local wrap1 = add("Wrap1", CFrame.new(cs.Wrap1:GetAttribute("Offset")))
	local wrap2 = add("Wrap2", CFrame.new(cs.Wrap2:GetAttribute("Offset")))
	local wrapOpen = add("WrapOpen", CFrame.new(cs.WrapOpen:GetAttribute("Offset")), 1)
	render()

	-- 1) 테이블 왼쪽에 놓인 포장된 나무젓가락 누르기
	-- 처음에는 테이블 위 진짜 젓가락이 보이고, 누를 자리(holder)만 그 위에 겹쳐 둔다.
	-- 누르면 같은 자리에서 3D 미리 보기로 바뀌어 화면 가운데로 커진다 (테이블에서 집어 드는 느낌).
	local worldWrap = {}
	if opts and opts.from then
		worldWrap = { opts.from }
	else
		for _, p in ipairs(ctx.station.Chopsticks:GetChildren()) do
			if p.Name:sub(1, 7) == "Wrapped" then
				table.insert(worldWrap, p)
			end
		end
	end
	local function placeOverWorld()
		local cam = workspace.CurrentCamera
		local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
		for _, p in ipairs(worldWrap) do
			local half = p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local v = cam:WorldToScreenPoint(p.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
						lo = lo:Min(Vector2.new(v.X, v.Y))
						hi = hi:Max(Vector2.new(v.X, v.Y))
					end
				end
			end
		end
		local s = ui.scale.Scale
		local c = (lo + hi) / 2 / s
		local len = math.max(hi.Y - lo.Y, hi.X - lo.X) / s
		local h = len / 0.81 -- 미리 보기 카메라에서 젓가락이 화면 높이의 81%
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromOffset(c.X, c.Y)
		holder.Size = UDim2.fromOffset(math.max(h * 0.625, 70), h)
	end
	ui:say("왼쪽 나무젓가락을 눌러요", "포장된 나무젓가락을 꺼내요")
	if #worldWrap > 0 then
		vpf.Visible = false
		clicked = nil
		if opts and opts.from then
			placeOverWorld()
		else
			while not clicked do
				placeOverWorld()
				if not ctx.frame() then
					return finish(nil)
				end
			end
		end
		for _, p in ipairs(worldWrap) do
			p.LocalTransparencyModifier = 1
		end
		vpf.Visible = true
	elseif not waitClick() then
		return finish(nil)
	end
	-- 2) 화면 가운데로 사선으로 커지며 줌
	local rootSize = ui.root.Size
	-- 2026-11-20: 젓가락 화면이 녹이기 화면과 같아지면서 크게 띄운 젓가락 위 끝이 안내 문구에 가려짐 →
	-- 안내 문구(설명 줄 포함) 아래 남는 칸 가운데에, 그 칸에 맞는 크기로
	local topY = 0
	if ui.pill and ui.pill.Visible then
		topY = (ui.pill.AbsolutePosition.Y + ui.pill.AbsoluteSize.Y) / ui.scale.Scale + 36
	end
	local avail = rootSize.Y.Offset - topY - 8
	local h = math.min(rootSize.Y.Offset * 0.82, avail)
	TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(rootSize.X.Offset / 2, topY + avail / 2),
		Size = UDim2.fromOffset(math.min(h * 0.75, rootSize.X.Offset * 0.6), h),
	}):Play()
	-- 2026-11-20 "젓가락 꺼내고 뽀갤 때 배경에 검은색 깔리는 거 삭제": 뒤 화면을 어둡게 하지 않음
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
	play("paperTear")
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
	play("stickSnap")
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
