-- 4. 붓기: 국자를 끌어 철판 위로 가져가면 기울어지고, 걸쭉한 덩어리가 미끄러져 떨어짐.
-- 끝에 화면을 톡 치면(탭) 남은 반죽이 떨어짐. 점수: 설탕 원 가운데에 가까울수록 + 남은 양이 적을수록.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Dalgona = require(script.Parent.Parent:WaitForChild("Dalgona"))

local Pour = {}

local MAX_TILT = math.rad(95)
local DROP_TILT = math.rad(65)
local REMAIN = 0.15

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
	local landing = nil

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
				if tilt > DROP_TILT then
					-- 덩어리가 국자 가장자리(+X쪽, 손잡이 반대)로 미끄러져 떨어짐
					dropped = true
					dropTime = os.clock()
					landing = Vector3.new(w.X + 0.45, S.plateTop, w.Z)
					local flat = Vector3.new(landing.X - S.ringCenter.X, 0, landing.Z - S.ringCenter.Z)
					rec.dist = flat.Magnitude
					local e = math.clamp((rec.dist - 0.9) / 1.0, 0, 0.5)
					local blob = Dalgona.new(S, Vector3.new(landing.X, S.plateTop, landing.Z), color, volume * (1 - REMAIN), e)
					st.dalgona = blob
					st.volume = volume
					-- 떨어지는 동안 위에서 아래로 (0.25초) + 착지하며 납작해짐
					local finalCenter = blob.center
					blob.center = finalCenter + Vector3.new(0, 1.2, 0)
					blob:setThickness(Config.Press.h0 * 1.3)
					task.spawn(function()
						local t = 0
						while t < 0.25 do
							t += task.wait()
							local a = math.min(t / 0.25, 1)
							blob.center = finalCenter + Vector3.new(0, 1.2 * (1 - a * a), 0)
							blob:setThickness(Config.Press.h0 * (1.3 - 0.3 * a * a))
						end
						blob.center = finalCenter
						blob:setThickness(Config.Press.h0 * 0.9)
						task.wait(0.06)
						blob:setThickness(Config.Press.h0)
					end)
					S:setContents({ thickness = 0.03 })
					ui:buzz(0.5, 0.1)
					if rec.dist > 1.0 then
						ui:hint("원 밖에 떨어졌어요! 철판에 들러붙어요")
					end
					ui:say("국자를 톡 털어요 (탭)", "남은 반죽까지 떨어뜨려요")
					seenPress = P.presses
				end
			else
				tilt = 0
				S:springTo(ladle, home, dt, 22)
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
