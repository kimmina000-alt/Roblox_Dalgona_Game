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
local Fx = require(script.Parent.Parent:WaitForChild("Fx"))

local Pour = {}

local MAX_TILT = math.rad(95)
local POUR_TILT = math.rad(48) -- 이 각도부터 흘러내리기 시작
local REMAIN = 0.15
local POUR_TIME = 1.8 -- 최대로 기울였을 때 다 붓는 데 걸리는 시간 (걸쭉해서 천천히)
local SEGMENTS = 28

-- 흘러내리는 반죽 줄기: 공 모양 조각을 이어 붙인 관. 국자 가장자리(lip) → 반죽 위(land)
local function newStream(S, color)
	local st = { parts = {}, head = 0, tail = 0, t = 0, flow = 0 }
	-- 3D 리본 메시가 있으면 그것 하나로 (영상: 가는 줄기가 아니라 넓적한 반죽 띠가 접히며 미끄러져 나옴)
	st.ribbon = Fx.mesh("PourRibbon", S.fx, { Name = "PourRibbon", Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
	if st.ribbon then
		return st
	end
	for i = 1, SEGMENTS do
		st.parts[i] = S:fxPart(S.fx, {
			Name = "PourStream",
			Shape = Enum.PartType.Ball,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.12,
			Size = Vector3.one * 0.05,
			Transparency = 1,
		})
	end
	return st
end

-- lip: 국자 가장자리, out: 흘러나가는 방향(수평), land: 떨어지는 곳(반죽 윗면)
-- head/tail: 줄기의 위끝·아래끝 위치 (0 = 국자, 1 = 바닥). flow: 굵기 0~1
local function drawStream(st, lip, out, land)
	if st.ribbon then
		local top = lip:Lerp(land, st.tail)
		local bottom = lip:Lerp(land, math.min(st.head, 1))
		local len = (bottom - top).Magnitude
		if len < 0.03 or st.flow <= 0.01 then
			st.ribbon.Transparency = 1
			return
		end
		local up = (top - bottom).Unit
		local right = out:Cross(Vector3.yAxis)
		if right.Magnitude < 1e-3 then
			right = Vector3.xAxis
		end
		right = (right - up * right:Dot(up)).Unit
		local w = math.sqrt(st.flow) * (st.tail > 0 and (1 - st.tail * 0.6) or 1)
		st.ribbon.Size = Vector3.new(0.5 * w, len + 0.08, 0.26 * w)
		-- 출렁임: 띠가 살짝 비틀리고 흔들림
		local wob = CFrame.Angles(0, math.sin(st.t * 5) * 0.35, math.sin(st.t * 7) * 0.06)
		st.ribbon.CFrame = CFrame.fromMatrix((top + bottom) / 2, right, up) * wob
		st.ribbon.Transparency = 0
		return
	end
	local ctrl = lip + out * 0.2 + Vector3.new(0, -0.05, 0) -- 가장자리에서 살짝 밀려 나왔다 떨어짐
	for i, p in ipairs(st.parts) do
		local s = (i - 1) / (SEGMENTS - 1)
		if s < st.tail or s > st.head or st.flow <= 0.01 then
			p.Transparency = 1
		else
			local u = 1 - s
			local pos = lip * u * u + ctrl * 2 * u * s + land * s * s
			-- 점성: 위는 굵고 아래로 갈수록 가늘어짐, 바닥에 닿는 곳은 살짝 똬리처럼 퍼짐
			local r = (0.17 - 0.09 * s ^ 0.7) * math.sqrt(st.flow)
			if s > 0.9 then
				r *= 1 + (s - 0.9) * 4
			end
			-- 끊어질 때(tail이 내려올 때) 위쪽이 실처럼 가늘어짐
			if st.tail > 0 then
				r *= math.clamp((s - st.tail) / 0.35, 0.25, 1)
			end
			local side = out:Cross(Vector3.yAxis)
			pos += side * math.sin(st.t * 7 + s * 5) * 0.03 * s
			p.Size = Vector3.one * math.max(r * 2, 0.03)
			p.CFrame = CFrame.new(pos)
			p.Transparency = 0
		end
	end
end

-- 미리 보기·테스트용 (Studio에서 줄기 모양 확인)
Pour.newStream = newStream
Pour.drawStream = drawStream

function Pour.run(ctx)
	local S, P, ui, st = ctx.station, ctx.pointer, ctx.ui, ctx.state
	local rec = { t0 = ctx.now(), dist = 10, remain = REMAIN }
	local ladle = S.Ladle
	local home = ladle:GetPivot()
	local rot = S.rest.Ladle - S.rest.Ladle.Position
	local carryY = S.plateTop + 1.8
	local plate = S.Plate.Position
	local half = S.Plate.Size.X / 2
	local color = st.batterColor or S.Contents.Color
	local volume = math.pi * 0.55 ^ 2 * Config.Press.h0

	-- 젓가락은 내려놓음
	S.Chopsticks:PivotTo(S.rest.Chopsticks)

	local grabbing = false
	local seenPress = P.presses
	local tilt = 0
	local dropped = false
	local dropTime = 0
	local flickPress = nil
	local blob = nil
	local poured = 0
	local total = volume * (1 - REMAIN)
	local look = Dalgona.lookFor(ctx.records, st)
	color = Dalgona.colorFor(look) -- 줄기·반죽 색 = 탄 정도에 맞춘 색
	local stream = newStream(S, color)
	local contentsThick = S.Contents.Size.X

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
	ui:say("국자를 철판 위로 끌어 기울여요", "설탕 원 가운데에 덩어리째 부어요")

	while true do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		if not dropped then
			if P.down and not grabbing and P.presses ~= seenPress then
				seenPress = P.presses
				grabbing = true
			end
			if grabbing and not P.down then
				grabbing = false
			end
			if grabbing then
				local w = P.toPlane(carryY)
				local over = math.abs(w.X - plate.X) < half and math.abs(w.Z - plate.Z) < half
				if over then
					tilt = math.min(MAX_TILT, tilt + math.rad(150) * dt)
				else
					tilt += (0 - tilt) * (1 - math.exp(-14 * dt))
				end
				ladle:PivotTo(CFrame.new(w) * CFrame.Angles(0, 0, -tilt) * rot)
				-- 국자 가장자리(손잡이 반대쪽 +X)와 흘러나가는 방향
				local out = Vector3.new(1, 0, 0)
				local lip = (CFrame.new(w) * CFrame.Angles(0, 0, -tilt)):PointToWorldSpace(Vector3.new(S.bowlRadius - 0.04, S.bowlHalf, 0))
				if tilt > POUR_TILT and poured < total then
					local rate = (tilt - POUR_TILT) / (MAX_TILT - POUR_TILT)
					local amt = math.min(total - poured, total / POUR_TIME * (0.35 + 0.65 * rate) * dt)
					if not blob then
						-- 처음 닿는 곳에 반죽이 생김 (점수는 이 자리로)
						local landing = Vector3.new(lip.X + 0.12, S.plateTop, lip.Z) -- 줄기가 실제로 떨어지는 곳
						local flat = Vector3.new(landing.X - S.ringCenter.X, 0, landing.Z - S.ringCenter.Z)
						rec.dist = flat.Magnitude
						local e = math.clamp((rec.dist - 0.9) / 1.0, 0, 0.5)
						blob = Dalgona.new(S, landing, color, volume * 0.02, e)
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
					local fill = poured / total
					blob.V = math.max(volume * 0.02, volume * (1 - REMAIN) * fill)
					blob:setThickness(Config.Press.h0 * (1.15 - 0.15 * fill) + 0.03 * math.sin(stream.t * 9) * stream.flow)
					local land = Vector3.new(blob.center.X, blob:topY() + 0.05, blob.center.Z)
					drawStream(stream, lip, out, land)
					local remain = 1 - poured / volume
					S:setContents({ thickness = math.max(0.06, contentsThick * remain / 1) })
					local foam = ladle:FindFirstChild("FxFoam")
					if foam then
						foam.Transparency = math.clamp(fill * 1.3, 0, 1)
					end
					if poured >= total - 1e-4 then
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
								drawStream(stream, lip, out, Vector3.new(blob.center.X, blob:topY() + 0.05, blob.center.Z))
								local a = math.min(t / 0.45, 1)
								blob:setThickness(finalH * (1 + 0.08 * math.sin(a * math.pi * 2.5) * (1 - a)))
							end
							if stream.ribbon then
								stream.ribbon.Transparency = 1
							end
							for _, p in ipairs(stream.parts) do
								p.Transparency = 1
							end
							blob:setThickness(finalH)
						end)
						S:setContents({ thickness = 0.03 })
						ui:say("국자를 톡 털어요 (탭)", "남은 반죽까지 떨어뜨려요")
						seenPress = P.presses
					end
				end
			else
				tilt = 0
				S:springTo(ladle, home, dt, 22)
				if blob and not dropped then
					-- 붓다가 손을 떼면 줄기가 끊겨 떨어짐 (다시 기울이면 이어서 부음)
					stream.flow = math.max(0, stream.flow - dt * 5)
					if stream.flow <= 0.01 then
						if stream.ribbon then
							stream.ribbon.Transparency = 1
						end
						for _, p in ipairs(stream.parts) do
							p.Transparency = 1
						end
						stream.head = 0
					end
				end
			end
		else
			-- 탭 = 국자를 톡 털어 남은 반죽 떨어뜨리기
			if P.presses ~= seenPress then
				seenPress = P.presses
				flickPress = os.clock()
				ladle:PivotTo(ladle:GetPivot() * CFrame.new(0, -0.15, 0))
			end
			if flickPress and not P.down and P.releases > 0 then
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
				ui:buzz(0.4, 0.06)
				break
			end
			if os.clock() - dropTime > 2.5 then
				break
			end
		end
		ctx.live("pour", Scoring.pour(rec))
	end

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
	S:setContents({ Transparency = 1 })
	rec.t1 = ctx.now()
	return rec
end

return Pour
