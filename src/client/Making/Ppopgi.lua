-- 뽑기 (7단계, 선택. 15번, 2026-11-20): 모양 찍기 뒤 "뽑기 도전"을 고르면
--   바늘로 점선(찍힌 틀 자국)을 따라 긁음. 빠르게 긋거나 선을 벗어나면 금이 가고 금 간 곳이 빨갛게.
--   금 3번 = 쪼개짐(못 팖, 2026-11-21). 점선을 다 긁으면 성공 → 달고나 1개 덤 (완벽하면 2개, 2026-11-21). 언제든 "그만하기".
-- 판정은 shared/PpopgiRules (서버가 같은 표본으로 다시 계산). 목표 시간 10~20초.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PpopgiRules"))
local CameraRig = require(script.Parent:WaitForChild("CameraRig"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Ppopgi = {}

local DASH = Color3.fromRGB(255, 247, 228) -- 아직 안 긁은 점선
local SCRAPED = Color3.fromRGB(104, 58, 24) -- 긁어 낸 선
local CRACK_RED = Color3.fromRGB(228, 42, 36)
local STEEL = Color3.fromRGB(205, 208, 214)
local NEEDLE_LEN = 1.15
-- 3D 반죽 정점 높이(surfaceY)보다 이만큼 위에 그려야 보임 (2026-11-20 Studio 확인: +0.02는 묻힘, +0.06 보임)
local LIFT = 0.06

-- ctx.frame()으로 기다림. 반환 { samples, res(클라 계산), quit } 또는 nil(중단·준비 안 됨)
function Ppopgi.run(ctx, dal, shapeId)
	local S, ui, P = ctx.station, ctx.ui, ctx.pointer
	local root = ctx.state.stampRoot
	local path = root and Rules.path(shapeId)
	if not path or not dal then
		return nil
	end
	local topY = dal:topY()
	-- 틀 기준 좌표계 (찍은 자리·각도), 높이는 반죽 윗면
	local frame = CFrame.new(root.Position.X, topY, root.Position.Z) * (root - root.Position)
	local function toLocal(w)
		local v = frame:PointToObjectSpace(w)
		return v.X, -v.Z
	end
	-- 반죽 윗면 높이 (3D 반죽은 가장자리 턱·홈이 있어서 정점 높이로, 아니면 윗면)
	local function surfY(w)
		local b = dal.batter
		local y = b and b.surfaceY and b:surfaceY(w)
		return y or topY
	end
	local function toWorld(x, y, lift)
		local w = frame:PointToWorldSpace(Vector3.new(x, 0, -y))
		return Vector3.new(w.X, surfY(w) + (lift or 0), w.Z)
	end
	local function tangent(li, s)
		local ax, ay = Rules.pointAt(path, li, s - 0.01)
		local bx, by = Rules.pointAt(path, li, s + 0.01)
		local a, b = toWorld(ax, ay), toWorld(bx, by)
		local d = b - a
		return d.Magnitude > 1e-5 and d.Unit or Vector3.xAxis
	end

	-- 카메라: 긁을 선(틀 자국)을 위에서 크게 (선 전체가 화면 높이의 약 60%)
	local ext = 0
	for _, L in ipairs(path.loops) do
		for i = 1, L.n do
			ext = math.max(ext, math.abs(L.x[i]), math.abs(L.y[i]))
		end
	end
	CameraRig.goPoint(Vector3.new(root.Position.X, topY, root.Position.Z), math.max(ext * 4.6, 2.2), 0.1, 0.6)

	-- 점선 (칸마다 짧은 줄 하나, 긁으면 진한 홈으로 이어짐)
	local dashes = {}
	for li, L in ipairs(path.loops) do
		dashes[li] = {}
		for b = 0, L.nb - 1 do
			local s = (b + 0.5) * L.binLen
			local x, y = Rules.pointAt(path, li, s)
			local pos = toWorld(x, y, LIFT)
			local dir = tangent(li, s)
			dashes[li][b] = S:fxPart(S.fx, {
				Name = "Engrave",
				Color = DASH,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.08,
				Size = Vector3.new(0.03, 0.01, L.binLen * 0.5),
				CFrame = CFrame.lookAt(pos, pos + dir),
			})
		end
	end
	local function scrape(li, b)
		local d = dashes[li] and dashes[li][b]
		if d then
			local L = path.loops[li]
			d.Color = SCRAPED
			d.Transparency = 0
			d.Size = Vector3.new(0.045, 0.012, L.binLen * 1.08)
		end
	end
	local function crackMark(x, y)
		local li, s = Rules.nearest(path, x, y)
		local along = tangent(li, s)
		local across = along:Cross(Vector3.yAxis).Unit
		local p = toWorld(x, y, LIFT + 0.004)
		local side = math.random() < 0.5 and 1 or -1
		for k = 1, 3 do
			local len = 0.09 + math.random() * 0.07
			local dir = (across * side + along * ((k % 2 == 0) and 0.7 or -0.5) * (0.6 + math.random() * 0.6)).Unit
			local q = p + dir * len
			S:fxPart(S.fx, {
				Name = "Crack",
				Color = CRACK_RED,
				Material = Enum.Material.SmoothPlastic,
				Size = Vector3.new(0.032, 0.012, len),
				CFrame = CFrame.lookAt((p + q) / 2, q),
			})
			p = q
		end
		-- 금 간 자리 빨간 점 (잘 보이게)
		S:fxPart(S.fx, {
			Name = "Crack",
			Shape = Enum.PartType.Cylinder,
			Color = CRACK_RED,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			Size = Vector3.new(0.01, 0.16, 0.16),
			CFrame = CFrame.new(toWorld(x, y, LIFT + 0.008)) * CFrame.Angles(0, 0, math.pi / 2),
		})
	end

	-- 바늘 (가는 쇠 + 빨간 머리). 끝 = 긁는 자리
	local shaft = S:fxPart(S.fx, { Name = "PpopgiNeedle", Shape = Enum.PartType.Cylinder, Color = STEEL, Material = Enum.Material.Metal, Reflectance = 0.2, Size = Vector3.new(NEEDLE_LEN, 0.035, 0.035) })
	local head = S:fxPart(S.fx, { Name = "PpopgiNeedleHead", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(220, 70, 70), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(0.13, 0.13, 0.13) })
	local function placeNeedle(tip, lifted, stress)
		local cam = workspace.CurrentCamera.CFrame
		local right = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z)
		local down = -Vector3.new(cam.UpVector.X, 0, cam.UpVector.Z)
		local dir = (Vector3.yAxis * 1.0 + (right.Magnitude > 0 and right.Unit or Vector3.xAxis) * 0.42 + (down.Magnitude > 0 and down.Unit or Vector3.zAxis) * 0.3).Unit
		local t = tip + Vector3.new(0, lifted and 0.12 or 0, 0)
		local top = t + dir * NEEDLE_LEN
		shaft.CFrame = CFrame.lookAt((t + top) / 2, top) * CFrame.Angles(0, math.pi / 2, 0)
		head.CFrame = CFrame.new(top)
		shaft.Color = STEEL:Lerp(CRACK_RED, math.clamp(stress, 0, 1) * 0.8)
	end
	local function tipFromPointer()
		-- 누른 곳 그대로 긁음 (2026-11-21 사용자: 누른 곳과 긁히는 곳이 달랐음 → 폰 손가락 보정 뺌)
		local f = P.toPlane(topY + 0.03)
		return Vector3.new(f.X, surfY(f) + LIFT - 0.01, f.Z)
	end

	ui:say("바늘로 점선을 따라 긁어요", "천천히! 빠르게 긋거나 선을 벗어나면 금이 가요")
	local quitBtn = ui:setSkip(true, "그만하기")
	local run = Rules.newRun(path)
	local samples = {}
	local t, acc = 0, 0
	local hintT = 0
	local quit = false
	local ended = nil -- "done" / "broken" / "quit"
	local wasDown = false
	local scrapeT = 0
	ui:setMeter(true, 0, Rules.DONE, 1, "0%", "뽑기")
	while true do
		local dt = ctx.frame()
		if not dt then
			ui:setSkip(false)
			ui:setMeter(false)
			return nil
		end
		t += dt
		acc += dt
		hintT -= dt
		local tip = tipFromPointer()
		placeNeedle(tip, not P.down, run.stress)
		if quitBtn and quitBtn.clicked then
			quit = true
			ended = "quit"
			break
		end
		if t > Rules.MAX_TIME then
			quit = true
			ended = "quit"
			ui:hint("시간이 다 됐어요")
			break
		end
		-- 표본: 초당 RATE번 (누르기·떼기 순간도 바로)
		local downNow = P.down
		if acc >= 1 / Rules.RATE or downNow ~= wasDown then
			acc = 0
			wasDown = downNow
			if #samples < Rules.MAX_SAMPLES * 4 then
				local x, y = toLocal(tip)
				x = math.floor(math.clamp(x, -4, 4) * 1000 + 0.5) / 1000
				y = math.floor(math.clamp(y, -4, 4) * 1000 + 0.5) / 1000
				local st = math.floor(t * 1000 + 0.5) / 1000
				table.insert(samples, st)
				table.insert(samples, x)
				table.insert(samples, y)
				table.insert(samples, downNow and 1 or 0)
				local event, state = Rules.feed(run, st, x, y, downNow)
				for _, nb in ipairs(run.newBins) do
					scrape(nb[1], nb[2])
				end
				if #run.newBins > 0 or (state and state.on and state.speed > 0.05) then
					scrapeT = 0.15
				end
				if event then
					local c = run.crackAt[#run.crackAt]
					crackMark(c[1], c[2])
					Sfx.play("crack", 0.9, 1.2)
					ui:buzz(0.8, 0.15)
					if event == "broken" then
						ended = "broken"
						break
					end
					ui:hint(string.format("쩍! 금이 갔어요 (%d/%d) 천천히 긁어요", run.cracks, Rules.BREAK))
					hintT = 1.6
				elseif state and hintT <= 0 then
					if state.speed > run.safe * 1.4 then
						ui:hint("너무 빨라요! 천천히")
						hintT = 1
					elseif not state.on and not state.far then
						ui:hint("점선에서 벗어났어요")
						hintT = 1
					end
				end
				local cov = Rules.coverage(run)
				ui:setMeter(true, cov / Rules.DONE, 0.999, 1, string.format("%d%%", math.floor(math.min(cov / Rules.DONE, 1) * 100)), "뽑기")
				ui:say("바늘로 점선을 따라 긁어요", string.format("금 %d/%d · 천천히 긁을수록 안전해요", run.cracks, Rules.BREAK))
				if cov >= Rules.DONE then
					ended = "done"
					break
				end
			end
		end
		scrapeT -= dt
		Sfx.loop("stirDry", (scrapeT > 0 and P.down) and 0.3 or 0, 1.5) -- 긁는 소리
	end
	Sfx.loop("stirDry", 0)
	ui:setSkip(false)
	ui:setMeter(false)
	local res = Rules.result(run)
	shaft:Destroy()
	head:Destroy()

	local wait = 0.7
	if ended == "broken" then
		dal:crack(6, 1)
		ui:say("쩌적… 쪼개졌어요", "쪼개진 달고나는 팔 수 없어요")
		wait = 1.3
	elseif ended == "done" then
		for li, L in ipairs(path.loops) do
			for b = 0, L.nb - 1 do
				scrape(li, b)
			end
		end
		Sfx.play("stepDone", 0.6, 1.1)
		if res.perfect then
			dal:sparkle()
			ui:say("완벽 뽑기!", string.format("덤으로 달고나 %d개 더!", res.extra))
		else
			ui:say("뽑기 성공!", string.format("덤으로 달고나 %d개 더!", res.extra))
		end
		wait = 1.1
	else
		ui:say("뽑기를 그만뒀어요", "보너스 없이 그대로 팔아요")
	end
	local w = 0
	while w < wait do
		local dt = ctx.frame()
		if not dt then
			return nil
		end
		w += dt
	end
	return { samples = samples, res = res, quit = quit, ended = ended }
end

return Ppopgi
