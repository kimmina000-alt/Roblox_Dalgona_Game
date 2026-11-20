-- 4. 붓기: 국자를 끌어 철판 위로 가져가 기울이면, 걸쭉한 반죽이 국자 가장자리에서 굵은 줄기로 흘러내림.
-- 줄기는 아래로 갈수록 가늘어지고 살짝 출렁이며, 철판 위 반죽은 부은 양만큼 퍼짐 (많이 기울일수록 빨리).
-- 다 부으면 줄기 끝이 실처럼 늘어나다 끊겨 떨어짐. 끝에 화면을 톡 치면(탭) 남은 반죽이 떨어짐.
-- 점수: 설탕 원 가운데에 가까울수록 + 남은 양이 적을수록.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Dalgona = require(script.Parent.Parent:WaitForChild("Dalgona"))
local Stir = require(script.Parent.Parent:WaitForChild("Stir"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))
local Fx = require(script.Parent.Parent:WaitForChild("Fx"))

local Pour = {}

local UserInputService = game:GetService("UserInputService")
-- 터치 화면에서는 반죽이 손가락 바로 아래가 아니라 조금 위(화면 높이의 이 비율만큼)에 떨어짐
-- (2026-11-20 "반죽 부을 때 손가락에 가려져서 잘 안 보여")
-- 2026-11-20 다시 "손가락으로 누르는 곳에 떨어지게": 위로 띄우던 것(0.1)을 없앰 → 손가락 바로 아래
local FINGER_UP = 0
local function aimScreenPos(P)
	if FINGER_UP > 0 and UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		return P.pos - Vector2.new(0, workspace.CurrentCamera.ViewportSize.Y * FINGER_UP)
	end
	return P.pos
end

local MAX_TILT = math.rad(95)
local POUR_TILT = math.rad(48) -- 이 각도부터 흘러내리기 시작
local REMAIN = 0.15
local POUR_TIME = 1.8 -- 최대로 기울였을 때 다 붓는 데 걸리는 시간 (걸쭉해서 천천히)
local SEGMENTS = 44
-- 실제 달고나 영상 (국자를 철판 바로 위에서 기울여 부음): 위에서 보면 줄기는 거의 안 보이고,
-- 철판에 닿은 반죽이 가운데부터 둥글게 번지며 원이 점점 커짐 → 떨어지는 줄기는 그리지 않고 철판 위 반죽만 보여 줌
-- (사용자 요청 2026-11-19: 판에 닿는 반죽만 보이게, 원이 점점 커지게)
-- 2026-11-20: 다시 보이게 ("부을 때 부어지는 애니메이션 눈에 보이게"). 위에서 굵게 떨어지는 줄기 + 판 위에서 감기며 퍼지는 반죽
local SHOW_STREAM = true
local RIBBON_PIECES = 2 -- 리본 메시를 곡선 따라 이어 붙인 조각 수 (메시가 아래로 좁아져서, 아래 조각은 위 조각 끝 너비에 맞춤)

local function hideRibbons(st)
	for _, rb in ipairs(st.ribbons or {}) do
		rb.Transparency = 1
	end
end

-- 쌓이는 반죽 위로 리본이 접혀 내려앉음 (영상: 띠가 똬리 틀듯 겹겹이 쌓이다 녹아듦)
local function spawnFold(S, blob, color, ang)
	if not SHOW_STREAM then
		return -- 리본이 접혀 쌓이는 모습도 줄기와 함께 숨김
	end
	local f = Fx.mesh("PourRibbon", S.fx, { Name = "PourFold", Color = color, Material = Enum.Material.SmoothPlastic, Reflectance = 0.04 })
	if not f then
		return
	end
	task.spawn(function()
		local t = 0
		while t < 0.75 and f.Parent do
			t += task.wait()
			local a = math.min(t / 0.75, 1)
			local r = blob:radius()
			local c = blob.center
			local topY = c.Y + blob.h * 0.85
			local len = math.max(r * 1.05, 0.2) * (1 - 0.2 * a)
			local off = r * 0.22
			-- 얹힌 띠가 점점 납작해지며 언덕 속으로 가라앉음
			f.Size = Vector3.new(0.34 * (1 - 0.35 * a), len, (0.2 * (1 - a) + 0.02))
			f.CFrame = CFrame.new(c.X + math.cos(ang) * off, topY + 0.05 * (1 - a) - 0.06 * a, c.Z + math.sin(ang) * off)
				* CFrame.Angles(0, ang, 0)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(0, math.rad(25) * (1 - a), 0)
		end
		f:Destroy()
	end)
end

-- 흘러내리는 반죽 줄기: 공 모양 조각을 이어 붙인 관. 국자 가장자리(lip) → 반죽 위(land)
local function newStream(S, color)
	local st = { parts = {}, head = 0, tail = 0, t = 0, flow = 0 }
	-- 3D 리본 메시가 있으면 그것 하나로 (영상: 가는 줄기가 아니라 넓적한 반죽 띠가 접히며 미끄러져 나옴)
	if false and Fx.template("PourRibbon") then -- 리본 조각은 이음매가 보여서 둥근 줄기로
		st.ribbons = {}
		for i = 1, RIBBON_PIECES do
			st.ribbons[i] = Fx.mesh("PourRibbon", S.fx, { Name = "PourRibbon", Color = color, Material = Enum.Material.SmoothPlastic, Reflectance = 0.04, Transparency = 1 })
		end
		st.ribbon = st.ribbons[1]
		return st
	end
	for i = 1, SEGMENTS do
		st.parts[i] = S:fxPart(S.fx, {
			Name = "PourStream",
			Shape = Enum.PartType.Cylinder, -- 점 사이를 잇는 원통 (공을 이으면 구슬처럼 보임, 2026-11-20)
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.03,
			Size = Vector3.one * 0.05,
			Transparency = 1,
		})
	end
	return st
end

-- lip: 국자 가장자리, out: 흘러나가는 방향(수평), land: 떨어지는 곳(반죽 윗면)
-- head/tail: 줄기의 위끝·아래끝 위치 (0 = 국자, 1 = 바닥). flow: 굵기 0~1
local function drawStream(st, lip, out, land)
	if not SHOW_STREAM then
		hideRibbons(st)
		for _, p in ipairs(st.parts) do
			p.Transparency = 1
		end
		return
	end
	if st.ribbon then
		-- 국자 가장자리에서 밖으로 살짝 밀려 나왔다가 떨어지는 곡선 위에 리본 조각을 이어 붙임
		local ctrl = lip + out * 0.3 + Vector3.new(0, -0.02, 0)
		local function bez(t)
			local u = 1 - t
			return lip * u * u + ctrl * 2 * u * t + land * t * t
		end
		local s0, s1 = st.tail, math.min(st.head, 1)
		if s1 - s0 < 0.02 or st.flow <= 0.01 then
			hideRibbons(st)
			return
		end
		local side = out:Cross(Vector3.yAxis)
		side = side.Magnitude > 1e-3 and side.Unit or Vector3.zAxis
		local n = #st.ribbons
		for i, rb in ipairs(st.ribbons) do
			-- 조각 경계: 위 조각이 조금 더 길고, 서로 살짝 겹침
			local split = s0 + (s1 - s0) * 0.48
			local a = i == 1 and s0 or split - 0.04
			local b = i == n and s1 or split + 0.02
			-- 아래로 갈수록 좌우로 더 흔들림 (점성 있는 띠가 늘어지며 출렁)
			local pa = bez(a) + side * math.sin(st.t * 6 + a * 7) * 0.045 * a
			local pb = bez(b) + side * math.sin(st.t * 6 + b * 7) * 0.045 * b
			local len = (pa - pb).Magnitude
			local up = (pa - pb).Unit
			local right = (side - up * side:Dot(up)).Unit
			local sm = (a + b) / 2
			-- 국자 쪽은 넓적하고 아래로 갈수록 좁고 가늘어짐, 굵기는 흐르는 양을 따라 맥박치듯
			local pulse = 1 + 0.06 * math.sin(st.t * 9 - sm * 8)
			-- 리본 메시는 위가 아래의 2배 넓음 → 아래 조각은 위 조각 아래끝 너비에서 시작
			local scale = i == 1 and 1 or 0.52
			local w = math.sqrt(st.flow) * 0.62 * scale * pulse
			local th = math.sqrt(st.flow) * 0.26 * scale * pulse
			if st.tail > 0 then
				-- 끊어질 때: 위쪽부터 실처럼 가늘어짐
				local k = math.clamp((sm - st.tail) / 0.4, 0.15, 1)
				w *= k
				th *= k
			end
			rb.Size = Vector3.new(math.max(w, 0.02), len + 0.04, math.max(th, 0.02))
			-- 아래로 갈수록 띠가 비틀림
			rb.CFrame = CFrame.fromMatrix((pa + pb) / 2, right, up) * CFrame.Angles(0, sm * 0.35 + math.sin(st.t * 4 + sm * 5) * 0.15, 0)
			rb.Transparency = 0
		end
		return
	end
	local ctrl = lip + out * 0.2 + Vector3.new(0, -0.05, 0) -- 가장자리에서 살짝 밀려 나왔다 떨어짐
	local side = out:Cross(Vector3.yAxis)
	local function at(s)
		local u = 1 - s
		return lip * u * u + ctrl * 2 * u * s + land * s * s + side * math.sin(st.t * 7 + s * 5) * 0.03 * s
	end
	local function radius(s)
		-- 점성: 위는 굵고 아래로 갈수록 가늘어짐, 바닥에 닿는 곳은 살짝 똬리처럼 퍼짐
		local r = (0.15 - 0.07 * s ^ 0.7) * math.sqrt(st.flow)
		if s > 0.9 then
			r *= 1 + (s - 0.9) * 4
		end
		-- 끊어질 때(tail이 내려올 때) 위쪽이 실처럼 가늘어짐
		if st.tail > 0 then
			r *= math.clamp((s - st.tail) / 0.35, 0.25, 1)
		end
		return r
	end
	local n = #st.parts
	for i, p in ipairs(st.parts) do
		local s0, s1 = (i - 1) / n, i / n
		if s1 < st.tail or s0 > st.head or st.flow <= 0.01 then
			p.Transparency = 1
		else
			s0, s1 = math.max(s0, st.tail), math.min(s1, st.head)
			local a, b = at(s0), at(s1)
			local r = radius((s0 + s1) / 2)
			local len = (b - a).Magnitude
			-- 원통 축(X) = 줄기 방향, 이음매가 안 보이게 살짝 겹침
			p.Size = Vector3.new(len + r * 0.6, math.max(r * 2, 0.03), math.max(r * 2, 0.03))
			p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
			p.Transparency = 0
		end
	end
end

-- 부은 뒤 도구 고르기 (사용자 요청 2026-11-19): 철판 오른쪽에 나무젓가락과 누름판을 놓아 두고,
-- 플레이어가 잡는 도구에 따라 다음 작업이 정해짐.
--   나무젓가락 손잡이를 잡고 끌면 → 모양 다듬기 (길쭉한 끝을 가운데로 끌어 모음, 여러 번 가능)
--   누름판을 잡으면 → 바로 누르기 단계로 (잡은 채로 넘어감)
-- 다듬기는 완전히 동그랗게는 못 하고 조금 나아지는 정도(최대 RESHAPE_MAX만큼)
local RESHAPE_FROM = 1.15 -- 이보다 길쭉해야 다듬기로 줄어듦
local RESHAPE_MAX = 0.6 -- 다듬어서 줄일 수 있는 길쭉함 최대
local RESHAPE_GAIN = 0.35 -- 가운데로 끈 거리(stud) → 줄어드는 길쭉함 (여러 번 끌어 모아야 함)
local PICK_PX = 90 -- 누름판 화면 위치에서 이만큼 안을 누르면 누르기로

-- 붓는 동안 국자·손을 숨기고 줄기를 HIDE_RISE만큼 위에서 시작 → 화면 밖 높은 곳에서 붓는 것처럼
local HIDE_RISE = 5.5 -- 줄기 윗끝이 화면 밖에서 시작하게 (2026-11-20: 2.4면 윗끝이 막대처럼 보임)
local function setLadleHidden(ladle, k)
	for _, p in ipairs(ladle:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = k
			-- 광택 메시(SurfaceAppearance)는 LocalTransparencyModifier로 다 안 사라지고 그림자도 남음 (2026-11-20 "냄비 같은 원통형")
			if k > 0.5 then
				if p:GetAttribute("PourOrigT") == nil then
					p:SetAttribute("PourOrigT", p.Transparency)
					p:SetAttribute("PourOrigShadow", p.CastShadow)
				end
				p.Transparency = 1
				p.CastShadow = false
			elseif p:GetAttribute("PourOrigT") ~= nil then
				p.Transparency = p:GetAttribute("PourOrigT")
				p.CastShadow = p:GetAttribute("PourOrigShadow")
				p:SetAttribute("PourOrigT", nil)
				p:SetAttribute("PourOrigShadow", nil)
			end
		end
	end
	local outline = ladle:FindFirstChild("ToonOutline")
	if outline then
		outline.Enabled = k < 0.3
	end
end

local function reshape(ctx, rec, blob, eRing)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local spread0 = rec.spread or 1
	print(string.format("[Pour] 부은 모양 길쭉함 %.2f", spread0))
	local floor = math.max(1.08, spread0 - RESHAPE_MAX)
	local cam = workspace.CurrentCamera
	-- 나무젓가락은 철판 오른쪽 가장자리에 앞으로 눕혀 둠 (끝 = 철판 안쪽, 손잡이 = 화면 아래 플레이어 쪽).
	-- 오른쪽 바깥으로 두면 화면 밖으로 나가고 모양 틀과 겹쳐서 손잡이를 잡기 어려움 (플레이 테스트 2026-11-19)
	local plate = S.Plate.Position
	local half = S.Plate.Size.X / 2
	local restTip = Vector3.new(plate.X + half * 0.75, S.plateTop + 0.05, plate.Z - half * 0.35)
	local restDir = Vector3.new(0.12, 0.1, 1).Unit
	local function restStick()
		Stir.placeChopsticksAt(S, restTip, restTip + restDir * 2.75)
	end
	restStick()
	local function screen(v)
		local p = cam:WorldToScreenPoint(v)
		return Vector2.new(p.X, p.Y)
	end
	local seenPress = P.presses
	local holding = false
	local lastTip = nil
	local touched = false
	local foldA, fold = nil, nil -- 접기: 잡은 가장자리 점, 늘어난 반죽 조각
	local function mergeFold()
		-- 늘어난 조각이 접힌 자리에서 반죽 속으로 녹아듦
		foldA = nil
		local f = fold
		fold = nil
		if f then
			task.spawn(function()
				local s0, t = f.Size, 0
				while t < 0.3 and f.Parent do
					t += task.wait()
					local a = math.min(t / 0.3, 1)
					f.Size = Vector3.new(s0.X * (1 + 0.3 * a), s0.Y * (1 - 0.7 * a), s0.Z * (1 - 0.6 * a))
					f.Transparency = a
				end
				f:Destroy()
			end)
		end
	end
	ui:say("젓가락으로 모양을 다듬어요", "끌어서 가장자리를 안쪽으로 접어요 · 다 됐으면 누름판을 눌러요")
	if spread0 > RESHAPE_FROM then
		ui:hint("반죽이 길쭉해요! 젓가락으로 끝을 가운데로 모아 봐요")
	end
	while true do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		if P.down and not holding and P.presses ~= seenPress then
			seenPress = P.presses
			local pv = S.Presser:GetPivot()
			local presserTop = screen(pv.Position + Vector3.new(0, S.Presser.Disc.Size.X, 0))
			if (P.pos - presserTop).Magnitude < PICK_PX then
				-- 누름판을 누르면 누르기 단계로 (사용자 요청 2026-11-19)
				st.presserInHand = true
				break
			end
			-- 나머지는 들고 있는 나무젓가락으로 다듬기 (도구 고르기 없이 기본으로 젓가락을 들고 있음)
			holding = true
			lastTip = nil
		end
		if holding then
			local tip, hnd = Stir.grip(blob:topY() + 0.02)
			Stir.placeChopsticksAt(S, tip, hnd)
			-- 긴 축(yaw) 좌표: 반죽 가운데에서 긴 쪽으로 얼마나 나가 있나
			local cy, sy = math.cos(blob.yaw or 0), math.sin(blob.yaw or 0)
			local function major(v)
				local dx, dz = v.X - blob.center.X, v.Z - blob.center.Z
				return dx * cy - dz * sy, dx * sy + dz * cy
			end
			if lastTip then
				local a0 = major(lastTip)
				local a1, b1 = major(tip)
				local R = blob:radius()
				local k = math.sqrt(1 + blob.e)
				local L = R * k -- 긴 쪽 반지름
				-- 끝 쪽(긴 축 바깥 절반, 반죽 안이나 바로 바깥)에서 가운데로 끌면 줄어듦
				local nearEnd = math.abs(a1) > L * 0.45 and math.abs(a1) < L * 1.15 and math.abs(b1) < R / k * 1.1
				local inward = math.abs(a0) - math.abs(a1)
				if nearEnd and inward > 0 and rec.spread > floor and rec.spread > RESHAPE_FROM * 0.95 then
					touched = true
					rec.spread = math.max(floor, rec.spread - inward * RESHAPE_GAIN)
					blob.e = math.max(eRing, rec.spread - 1)
					blob:setThickness(blob.h)
				end
			end
			lastTip = tip
			-- 접기 모션 (사용자 요청 2026-11-19): 젓가락 끝이 반죽 가장자리에 처음 닿은 곳을 잡고, 끄는 만큼
			-- 그 자리의 반죽이 혀처럼 늘어나 안쪽으로 접혀 올라옴. 놓거나 반죽 밖으로 멀리 빼면 반죽 속으로 녹아듦
			do
				local R = blob:radius()
				local k = math.sqrt(1 + blob.e)
				local a, b = major(tip)
				local rn = math.sqrt((a / (R * k)) ^ 2 + (b / (R / k)) ^ 2)
				if not foldA and rn > 0.55 and rn < 1.2 then
					-- 끝에서 가운데 → 바깥 방향으로 가장자리 점
					local dx, dz = tip.X - blob.center.X, tip.Z - blob.center.Z
					foldA = Vector3.new(blob.center.X + dx / math.max(rn, 1e-3), blob:topY(), blob.center.Z + dz / math.max(rn, 1e-3))
				elseif foldA and rn > 1.5 then
					mergeFold()
				end
				if foldA then
					local T = Vector3.new(tip.X, blob:topY(), tip.Z)
					local len = (T - foldA).Magnitude
					if len > 0.04 then
						if not fold then
							fold = Fx.ellipsoid(S:fxPart(S.fx, { Name = "FoldFlap", Color = blob.color, Material = Enum.Material.SmoothPlastic }))
						end
						local w = math.max(R * 0.38, 0.12)
						local mid = (foldA + T) / 2 + Vector3.new(0, 0.025, 0)
						fold.Transparency = 0
						fold.Size = Vector3.new(w * (1 - 0.25 * math.min(len / R, 1)), 0.07, len + w * 0.6)
						fold.CFrame = CFrame.lookAt(mid, Vector3.new(T.X, mid.Y, T.Z))
					end
				end
			end
			if not P.down then
				holding = false
				mergeFold()
				restStick() -- 놓으면 오른쪽 자리로 돌아감
			end
		end
		ctx.live("pour", Scoring.pour(rec))
		if holding then
			ui:say("젓가락으로 모양을 다듬어요", string.format("길쭉한 끝을 가운데로 끌어 모아요 · 길쭉함 %d%%", math.floor((rec.spread - 1) * 100 + 0.5)))
		else
			ui:say("젓가락으로 모양을 다듬어요", touched and string.format("길쭉함 %d%% · 다 됐으면 누름판을 눌러요", math.floor((rec.spread - 1) * 100 + 0.5)) or "끌어서 가장자리를 안쪽으로 접어요 · 다 됐으면 누름판을 눌러요")
		end
	end
	S:restChopsticks()
	print(string.format("[Pour] 다듬은 뒤 길쭉함 %.2f", rec.spread))
	return true
end
Pour.reshape = reshape

-- 미리 보기·테스트용 (Studio에서 줄기 모양 확인)
Pour.newStream = newStream
Pour.drawStream = drawStream

function Pour.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local rec = { t0 = ctx.now(), dist = 10, remain = REMAIN, spread = 1 }
	local ladle = S.Ladle
	local home = ladle:GetPivot()
	local rot = S.rest.Ladle - S.rest.Ladle.Position
	local carryY = S.plateTop + 1.8
	local plate = S.Plate.Position
	local half = S.Plate.Size.X / 2
	local color = st.batterColor or S.Contents.Color
	local volume = math.pi * 0.55 ^ 2 * Config.Press.h0
	-- 국자 손잡이 잡는 자리 (국자 피벗 기준, 기울이기 전 자세). 메시 손잡이 = 손 붙이는 자리와 같음
	local gripLocal = S:ladleGripLocal()
	local hideK = 1 -- 국자 숨김 정도 (2026-11-20: 붓기 내내 국자는 안 보이고 떨어지는 반죽만)
	setLadleHidden(ladle, 1)
	-- 붓는 동안 철판 옆 누름판은 안 보이게 (누르기 단계에서 다시 나옴)
	S:hidePresser(true)
	-- 반죽이 떨어질 자리 표시 (손가락 아래 철판 위 옅은 그림자)
	local aimMark = S:fxPart(S.fx, { Name = "PourAim", Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(60, 36, 20), Material = Enum.Material.SmoothPlastic, Transparency = 1, Size = Vector3.new(0.01, 0.34, 0.34) })

	-- 2026-11-20 사용자 요청 (다시): 화면 아무 데나 누르고 있으면 반죽이 떨어짐. 처음엔 철판(설탕 원) 가운데,
	-- 누른 채로 끌면 끈 방향·거리만큼 떨어지는 자리가 옮겨짐 (손가락이 반죽을 가리지 않게 손가락 아래가 아니라 상대 이동)
	local aimPt = S.ringCenter -- 지금 떨어지는 자리
	local aimAnchor, aim0 = nil, nil -- 누른 순간의 손가락 자리(철판 높이)와 그때의 떨어지는 자리

	-- 젓가락은 내려놓음
	S:restChopsticks()

	local grabbing = false
	local seenPress = P.presses
	local tilt = 0
	local dropped = false
	local dropTime = 0
	local blob = nil
	local poured = 0
	local total = volume * (1 - REMAIN)
	local look = Dalgona.lookFor(ctx.records, st)
	color = Dalgona.colorFor(look) -- 줄기·반죽 색 = 탄 정도에 맞춘 색
	local stream = newStream(S, color)
	local foldAcc, foldAng = 0, math.random() * 6
	local contentsThick = S.Contents.Size.X
	-- 붓는 자리 기록 (양으로 가중): 반죽 모양 = 부은 경로. 한 곳에 부으면 둥글고, 끌면서 부으면 그 방향으로 길쭉해짐
	local sw, sx, sz, sxx, szz, sxz = 0, 0, 0, 0, 0, 0
	local D0 = 2 * math.sqrt(volume * (1 - REMAIN) / (math.pi * Config.Press.h0)) -- 한 곳에 다 부었을 때 지름
	local eRing = 0
	local landNow = nil
	-- 방울 붓기 (2026-11-20): 3D 반죽이면 줄기 대신 한 방울씩 뚝뚝. 떨어진 자리대로 모양이 됨 (3D가 안 되면 예전 줄기)
	local dropMode = true
	local drops = {} -- 떨어지는 중인 방울
	local dropAcc = 0
	local DROP_N = 36
	local function landDrop(at, amt)
		if not blob then
			local flat = Vector3.new(at.X - S.ringCenter.X, 0, at.Z - S.ringCenter.Z)
			rec.dist = flat.Magnitude
			blob = Dalgona.new(S, at, color, amt, 0)
			blob.simple = true
			blob:setLook(look)
			st.dalgona = blob
			st.volume = volume
			ui:buzz(0.4, 0.08)
			if rec.dist > 1.0 then
				ui:hint("원 밖에 떨어졌어요! 철판에 들러붙어요")
			end
			if not blob.batter then
				dropMode = false -- 3D 반죽을 못 쓰면 예전 줄기 방식으로 이어서
				return
			end
		end
		blob:addDrop(at, amt)
		Sfx.play("pop", 0.3, 0.75 + math.random() * 0.2)
		local flat = Vector3.new(blob.center.X - S.ringCenter.X, 0, blob.center.Z - S.ringCenter.Z)
		rec.dist = flat.Magnitude
		rec.spread = math.clamp(blob.elong or 1, 1, 4)
		rec.round = Scoring.roundFromDev(blob.roundDev or 0)
		blob:setThickness(Config.Press.h0 * (1.15 - 0.15 * poured / total))
	end
	local function stepDrops(dt)
		for i = #drops, 1, -1 do
			local d = drops[i]
			d.t += dt
			local k = math.min(d.t / 0.32, 1)
			local y = d.from.Y + (d.to.Y - d.from.Y) * k * k -- 중력처럼 점점 빨리
			local stretch = 1 + 0.6 * k -- 떨어질수록 길쭉
			d.part.Size = Vector3.new(d.size / math.sqrt(stretch), d.size * stretch, d.size / math.sqrt(stretch))
			d.part.CFrame = CFrame.new(d.to.X, y, d.to.Z)
			if k >= 1 then
				d.part:Destroy()
				table.remove(drops, i)
				landDrop(Vector3.new(d.to.X, S.plateTop, d.to.Z), d.amt)
			end
		end
	end

	-- 카메라가 철판 쪽으로 옮겨 가 있으니, 국자를 먼저 철판 왼쪽 위로 들고 옴 (0.4초)
	local hover = CFrame.new(plate.X - half - 0.15, carryY, plate.Z + 0.9) * rot
	local start = ladle:GetPivot()
	local tc = 0
	while tc < 0.4 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		tc += dt
		ladle:PivotTo(start:Lerp(hover, 1 - (1 - math.min(tc / 0.4, 1)) ^ 3))
	end
	home = hover
	ui:say("화면을 꾹 누르고 있어요", "누르는 동안 반죽이 한 방울씩 · 누른 채로 끌면 떨어지는 자리가 움직여요")

	while true do
		local dt = ctx.frame()
		if not dt then
			ui:setWorldTip(nil)
			return nil
		end
		stepDrops(dt)
		if not dropped then
			if P.down and not grabbing and P.presses ~= seenPress then
				seenPress = P.presses
				grabbing = true
				aimAnchor, aim0 = P.toPlane(S.plateTop), aimPt
				Sfx.play("pop", 0.5, 1.1)
			end
			if grabbing and not P.down then
				grabbing = false
			end
			if grabbing then
				-- 손가락 = 국자 손잡이 (사용자 요청 2026-11-18: 동그란 그릇이 아니라 손잡이를 잡고 옮김).
				-- 그릇 자리 = 손가락 자리에서 손잡이→그릇 만큼 옮긴 곳
				local f = P.toPlane(carryY + rot:VectorToWorldSpace(gripLocal).Y)
				local w = f - rot:VectorToWorldSpace(gripLocal)
				w = Vector3.new(w.X, carryY, w.Z)
				local over = math.abs(w.X - plate.X) < half and math.abs(w.Z - plate.Z) < half
				-- 방울 붓기: 국자는 숨기고 손가락 바로 아래로 반죽이 떨어짐 (2026-11-20)
				local fingerLand = P.toPlane(S.plateTop, aimScreenPos(P))
				if dropMode then
					-- 누르고 있는 동안 떨어지는 자리 = 처음 자리 + 손가락을 끈 만큼 (철판 밖으로는 안 나감)
					local d = P.toPlane(S.plateTop) - (aimAnchor or P.toPlane(S.plateTop))
					local lim = half - 0.35
					aimPt = Vector3.new(math.clamp(aim0.X + d.X, plate.X - lim, plate.X + lim), S.plateTop, math.clamp(aim0.Z + d.Z, plate.Z - lim, plate.Z + lim))
					fingerLand = aimPt
					over = true
					aimMark.Transparency = over and 0.55 or 1
					aimMark.CFrame = CFrame.new(fingerLand.X, S.plateTop + 0.006, fingerLand.Z) * CFrame.Angles(0, 0, math.rad(90))
				end
				if over then
					tilt = math.min(MAX_TILT, tilt + math.rad(150) * dt)
				else
					tilt += (0 - tilt) * (1 - math.exp(-14 * dt))
				end
				-- 기울일 때는 그릇 자리를 그대로 두고 그릇 가장자리 쪽으로 기울임 (손잡이를 손가락에 붙여 두면
				-- 기울이는 만큼 그릇이 손 쪽으로 1.6 넘게 밀려 철판 밖에 부어짐 → 플레이 테스트에서 확인)
				ladle:PivotTo(CFrame.new(w) * CFrame.Angles(0, 0, -tilt) * rot)
				-- 국자 가장자리(손잡이 반대쪽 +X)와 흘러나가는 방향
				local out = Vector3.new(1, 0, 0)
				local lip = (CFrame.new(w) * CFrame.Angles(0, 0, -tilt)):PointToWorldSpace(Vector3.new(S.bowlRadius - 0.04, S.bowlHalf, 0))
				if dropMode and tilt > POUR_TILT and poured < total then
					-- 한 방울씩: 많이 기울일수록 자주. 국자를 움직이며 떨어뜨리면 그 길대로 모양이 됨 (하트를 그리면 하트)
					local rate = (tilt - POUR_TILT) / (MAX_TILT - POUR_TILT)
					-- 가운데 근처에 살짝씩 흩어져 떨어짐 (똑같은 자리에 겹치지 않게)
					local ja, jr = math.random() * 2 * math.pi, math.sqrt(math.random()) * 0.16
					local landing = Vector3.new(fingerLand.X + math.cos(ja) * jr, S.plateTop, fingerLand.Z + math.sin(ja) * jr)
					landNow = landing
					dropAcc += dt
					if dropAcc >= 0.3 - 0.18 * rate then
						dropAcc = 0
						local amt = math.min(total - poured, total / DROP_N)
						poured += amt
						local size = 0.3
						local part = Fx.ellipsoid(S:fxPart(S.fx, { Name = "PourDrop", Color = color, Material = Enum.Material.SmoothPlastic, Size = Vector3.one * size }))
						local from = landing + Vector3.new(0, 6, 0) -- 화면 밖 높은 곳(숨긴 국자)에서
						part.CFrame = CFrame.new(from)
						table.insert(drops, { part = part, from = from, to = landing + Vector3.new(0, 0.12, 0), t = 0, amt = amt, size = size })
					end
				elseif not dropMode and tilt > POUR_TILT and poured < total then
					local rate = (tilt - POUR_TILT) / (MAX_TILT - POUR_TILT)
					local amt = math.min(total - poured, total / POUR_TIME * (0.35 + 0.65 * rate) * dt)
					local landing = Vector3.new(lip.X + 0.12, S.plateTop, lip.Z) -- 줄기가 실제로 떨어지는 곳
					landNow = landing
					sw += amt
					sx += amt * landing.X
					sz += amt * landing.Z
					sxx += amt * landing.X * landing.X
					szz += amt * landing.Z * landing.Z
					sxz += amt * landing.X * landing.Z
					if not blob then
						-- 처음 닿는 곳에 반죽이 생김 (점수는 부은 자리들의 가운데로)
						local flat = Vector3.new(landing.X - S.ringCenter.X, 0, landing.Z - S.ringCenter.Z)
						rec.dist = flat.Magnitude
						eRing = math.clamp((rec.dist - 0.9) / 1.0, 0, 0.5)
						blob = Dalgona.new(S, landing, color, volume * 0.02, eRing)
						-- 붓는 동안은 매끈한 원판 + 가운데 볼록 (접힌 주름 메시 대신) → 동그란 웅덩이가 번지는 모습
						blob.simple = true
						blob:setLook(look)
						st.dalgona = blob
						st.volume = volume
						stream.head = 0
						ui:buzz(0.4, 0.08)
						if rec.dist > 1.0 then
							ui:hint("원 밖에 떨어졌어요! 철판에 들러붙어요")
						end
					end
					poured += amt
					stream.flow = math.min(1, stream.flow + dt * 6) * (0.55 + 0.45 * rate)
				else
					stream.flow = math.max(0, stream.flow - dt * 4)
				end
				if blob then
					-- 줄기 머리가 중력처럼 점점 빨리 내려감, 철판 반죽은 부은 양만큼 퍼짐 (가운데가 볼록한 채로)
					stream.head = math.min(1, stream.head + dt * (2.5 + 9 * stream.head))
					stream.t += dt
					if stream.ribbon and stream.flow > 0.2 then
						-- 리본이 접히며 쌓임: 일정 간격으로 띠 하나가 돌아가며 내려앉고, 언덕은 천천히 돌아감
						foldAcc += dt * (0.7 + stream.flow)
						if foldAcc > 0.22 then
							foldAcc = 0
							foldAng += 2.1
							spawnFold(S, blob, color, foldAng)
						end
						blob.spin = (blob.spin or 0) + dt * 0.7
					end
					local fill = poured / total
					if not blob.lobes then
						blob.V = math.max(volume * 0.02, volume * (1 - REMAIN) * fill)
					end
					-- 반죽 모양: 부은 자리들의 가운데 + 퍼진 방향으로 길쭉하게 (일직선으로 쭉 부으면 일직선 모양)
					if sw > 0 and not blob.lobes then
						local mx, mz = sx / sw, sz / sw
						local cxx, czz, cxz = sxx / sw - mx * mx, szz / sw - mz * mz, sxz / sw - mx * mz
						local major = (cxx + czz) / 2 + math.sqrt(((cxx - czz) / 2) ^ 2 + cxz * cxz)
						local spread = math.clamp(1 + math.max(0, 3 * math.sqrt(math.max(major, 0)) - 0.15) / D0, 1, 4)
						blob.center = Vector3.new(mx, S.plateTop, mz)
						blob.yaw = -0.5 * math.atan2(2 * cxz, cxx - czz)
						rec.spread = spread
						local flat = Vector3.new(mx - S.ringCenter.X, 0, mz - S.ringCenter.Z)
						rec.dist = flat.Magnitude
						eRing = math.clamp((rec.dist - 0.9) / 1.0, 0, 0.5)
						blob.e = math.max(eRing, spread - 1)
						if spread > 1.5 then
							ui:hint("한 곳에 모아 부어요 (길쭉해지면 틀이 안 맞아요)")
						end
					end
					blob:setThickness(Config.Press.h0 * (1.15 - 0.15 * fill) + 0.03 * math.sin(stream.t * 9) * stream.flow)
					if blob.batter then
						-- 떨어지는 줄기가 쌓이며 소용돌이 결이 감겨 돎 (붓는 세기만큼)
						blob.turnA = (blob.turnA or 0) + dt * 3.2 * stream.flow
						blob.batter:setTurn(blob.turnA)
					end
					local at = landNow or blob.center
					local land = Vector3.new(at.X, blob:topY() + 0.05, at.Z)
					drawStream(stream, lip + Vector3.new(0, HIDE_RISE * hideK, 0), out, land)
					local remain = 1 - poured / volume
					S:setContents({ thickness = math.max(0.06, contentsThick * remain / 1) })
					local foam = ladle:FindFirstChild("FxFoam")
					if foam and hideK < 0.5 then
						foam.Transparency = math.clamp(fill * 1.3, 0, 1)
						for _, c in ipairs(foam:GetDescendants()) do -- 기포 구멍 등도 같이
							if c:IsA("BasePart") then
								c.Transparency = math.max(c.Transparency, foam.Transparency)
							end
						end
					end
					if poured >= total - 1e-4 and #drops == 0 then
						-- 다 부음: 줄기가 실처럼 늘어나다 끊겨 떨어지고 반죽이 출렁이며 자리 잡음
						dropped = true
						dropTime = os.clock()
						local finalH = Config.Press.h0
						task.spawn(function()
							local t = 0
							while t < 0.45 and not ctx.aborted do
								t += task.wait()
								stream.t += 1 / 60
								stream.tail = math.min(1, t / 0.35)
								stream.flow = math.max(0.15, stream.flow * 0.97)
								drawStream(stream, lip + Vector3.new(0, HIDE_RISE * hideK, 0), out, Vector3.new(blob.center.X, blob:topY() + 0.05, blob.center.Z))
								local a = math.min(t / 0.45, 1)
								blob:setThickness(finalH * (1 + 0.08 * math.sin(a * math.pi * 2.5) * (1 - a)))
							end
							hideRibbons(stream)
							for _, p in ipairs(stream.parts) do
								p.Transparency = 1
							end
							blob:setThickness(finalH)
						end)
						S:setContents({ thickness = 0.03 })
						seenPress = P.presses
					end
				end
			else
				tilt = 0
				aimMark.Transparency = 1
				S:springTo(ladle, home, dt, 22)
				if blob and blob.lobes and poured >= total - 1e-4 and #drops == 0 then
					-- 방울을 다 떨어뜨린 뒤 손을 뗌: 다 부은 것으로
					dropped = true
					dropTime = os.clock()
					blob:setThickness(Config.Press.h0)
					S:setContents({ thickness = 0.03 })
					seenPress = P.presses
				end
				if blob and not dropped then
					-- 붓다가 손을 떼면 줄기가 끊겨 떨어짐 (다시 기울이면 이어서 부음)
					stream.flow = math.max(0, stream.flow - dt * 5)
					if stream.flow <= 0.01 then
						hideRibbons(stream)
						for _, p in ipairs(stream.parts) do
							p.Transparency = 1
						end
						stream.head = 0
					end
				end
			end
		else
			-- 다 부으면 남은 반죽이 저절로 똑 떨어짐 (사용자 요청 2026-11-19: 젓가락으로 국자 긁기 삭제)
			aimMark.Transparency = 1
			ui:setWorldTip(nil)
			if os.clock() - dropTime > 0.5 then
				local remainBlob = S:fxPart(S.fx, { Name = "Drip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, Color = color, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(S.Bowl.Position) })
				local target = st.dalgona.center + Vector3.new(0.1, st.dalgona.h * 0.6, 0)
				local tw = TweenService:Create(remainBlob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target), Size = Vector3.one * 0.2 })
				tw:Play()
				tw.Completed:Connect(function()
					remainBlob:Destroy()
				end)
				st.dalgona.V = volume
				st.dalgona:setThickness(st.dalgona.h)
				rec.remain = 0.02
				S:setContents({ Transparency = 1 })
				st.dalgona:addSwirl() -- 막 부은 결이 보였다가 매끈해짐 (영상 7~10번)
				break
			end
		end
		-- 반죽이 흘러내리는 "꿀렁" (줄기 세기만큼)
		Sfx.loop("pourGlug", (stream.flow or 0) * 0.6, 0.75)
		ctx.live("pour", Scoring.pour(rec))
	end
	Sfx.stop("pourGlug")

	ctx.live("pour", Scoring.pour(rec))
	ui:say("잘 부었어요!", rec.remain > 0.1 and "국자에 반죽이 조금 남았어요" or "")
	-- 국자는 화로로 돌아감
	local t = 0
	while t < 0.45 do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		t += dt
		S:springTo(ladle, S.rest.Ladle, dt, 14)
	end
	ladle:PivotTo(S.rest.Ladle)
	-- 다 부은 국자는 비어 있음: 부푼 거품·소다 자국은 치우고 국자만 다시 보이게
	for _, c in ipairs(ladle:GetChildren()) do
		if c.Name:sub(1, 2) == "Fx" then
			c:Destroy()
		end
	end
	S:setContents({ Transparency = 1 })
	setLadleHidden(ladle, 0)
	S:hidePresser(false)
	ui:setWorldTip(nil)
	if st.dalgona then
		st.dalgona.simple = false
		st.dalgona:setThickness(st.dalgona.h)
	end
	S:setContents({ Transparency = 1 })
	-- 젓가락으로 반죽 다듬기 삭제 (사용자 요청 2026-11-19): 부으면 바로 누르기로
	ctx.live("pour", Scoring.pour(rec))
	rec.t1 = ctx.now()
	return rec
end

return Pour
