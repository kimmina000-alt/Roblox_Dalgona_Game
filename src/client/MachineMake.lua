-- 2·3단계 기계 직접 만들기 (D35·D41, 2026-11-26 사용자: 참고 영상 "달고나 판매기" 순서, 2·3단계는 같은 순서·판 수만 다름,
-- 금형판 칸이 모양 → 찍기·뽑기 없음). 서버 MachineMakeService(시작·제출), 장면 MachineMakeScene, 화면 글·게이지는 손 제작 Making/Ui.
-- 순서: ① 동전 3개 → ② 국자를 배출구에 대고 설탕 받기(꾹 누르기, 초록 칸에서 떼기) → ③ 화구에서 원 그리며 젓기
--       → ④ 설탕 섞은 소다를 젓가락에 묻혀(통 누르기) 국자에 털고 빠르게 젓기 → ⑤ 금형판 칸마다 국자를 대고 꾹 눌러 붓기
--       → ⑥ 칸마다 막대 꽂기 → (국자 물에 헹굼, 자동) → 서버 제출 → 결과
-- 서버로는 점수가 아니라 입력 기록(단계 시각·설탕 양·젓기 표본·칸마다 채운 양)을 보냄 (2026-11-26).
-- 점수·품질 Q는 shared/MachineMakeRules로 서버가 다시 셈 (화면·Studio 시험도 같은 함수). 개수·Perfect 1개 규칙은 서버가 정함
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Rules = require(Shared:WaitForChild("MachineMakeRules"))
local Making = script.Parent:WaitForChild("Making")
local Ui = require(Making:WaitForChild("Ui"))
local Pointer = require(Making:WaitForChild("Pointer"))
local StirJudge = require(Making:WaitForChild("Stir"))
local Sfx = require(Making:WaitForChild("Sfx"))
local Scene = require(script.Parent:WaitForChild("MachineMakeScene"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MachineMake = {}

local STEPS = {
	{ key = "coin", label = "동전", icon = "🪙", title = "동전", desc = "" },
	{ key = "sugar", label = "설탕", icon = "🥄", title = "설탕 받기", desc = "" },
	{ key = "melt", label = "녹이기", icon = "🔥", title = "녹이기", desc = "" },
	{ key = "soda", label = "소다", icon = "🧂", title = "소다", desc = "" },
	{ key = "pour", label = "붓기", icon = "🍯", title = "금형판에 붓기", desc = "" },
	{ key = "stick", label = "막대", icon = "🍡", title = "막대 꽂기", desc = "" },
}
local TAP_PX = 110 -- 도구 화면 자리에서 이만큼 안을 누르면 그 도구
local SUGAR_RATE = Rules.SUGAR_RATE
local SUGAR_LO, SUGAR_HI, SUGAR_MAX = Rules.SUGAR_LO, Rules.SUGAR_HI, Rules.SUGAR_MAX
local MELT_LIMIT = Rules.MELT_LIMIT
local POUR_RATE = Rules.POUR_RATE
local SUGAR = Color3.fromRGB(250, 250, 248)
local AMBER = Color3.fromRGB(226, 150, 50)
local FOAM = Color3.fromRGB(206, 152, 96)

local ui = nil
local running = false
local aborted = false

local function now()
	return workspace:GetServerTimeNow()
end

-- SAMPLE초마다 표본 하나 (서버가 같은 간격으로 다시 셈)
local function sampler()
	local o = { s = {}, acc = 0, last = 0 }
	function o:add(dt, z)
		self.acc += dt
		self.last = z
		while self.acc >= Rules.SAMPLE and #self.s < Rules.MAX_SAMPLES do
			self.acc -= Rules.SAMPLE
			table.insert(self.s, z)
		end
	end
	-- 끝날 때 남은 반 칸 이상은 표본 하나로 (서버 계산이 덜 나오지 않게)
	function o:finish()
		if self.acc >= Rules.SAMPLE * 0.5 and #self.s < Rules.MAX_SAMPLES then
			table.insert(self.s, self.last)
		end
		self.acc = 0
		return self.s
	end
	return o
end

local function frame()
	if aborted then
		return nil
	end
	return RunService.RenderStepped:Wait()
end

local function screenOf(pos)
	local v = workspace.CurrentCamera:WorldToViewportPoint(pos)
	local inset = game:GetService("GuiService"):GetGuiInset()
	return Vector2.new(v.X, v.Y - inset.Y) -- Pointer 좌표(위 메뉴 줄 아래 기준)와 맞춤
end
local function near(pos, px)
	return (Pointer.pos - screenOf(pos)).Magnitude < (px or TAP_PX)
end

-- 다른 화면(HUD·메뉴·기계 창 등) 숨기기. 다른 UI들은 "MakingScreen" 이름만 보고 숨어서, 여기서 직접 끄고 끝나면 켜 둔 것만 다시 켬
local hiddenGuis = {}
local function hideOthers(hide)
	if hide then
		for _, g in ipairs(player.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g ~= (ui and ui.gui) and g.Name ~= "TouchGui" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
	else
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
	end
end

-- 조작 끄기·켜기 (MakingClient setControls와 같은 방식: PlayerModule이 있으면 끄고, 폰 조이스틱 숨김, 걷기 속도 0)
local savedSpeed = nil
local function controls(on)
	local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
	if pm then
		local ok, c = pcall(function()
			return require(pm):GetControls()
		end)
		if ok and c then
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end
	end
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	if touchGui then
		touchGui.Enabled = on
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		if on then
			if savedSpeed then
				hum.WalkSpeed = savedSpeed
				savedSpeed = nil
			end
		else
			savedSpeed = savedSpeed or hum.WalkSpeed
			hum.WalkSpeed = 0
		end
	end
end

-- 단계마다 볼 곳으로 카메라를 부드럽게 옮김. 손제작대 CameraRig처럼 매 프레임 다시 고정 (다른 스크립트가 Custom으로 돌려도 안 빠지게)
local camCF, camGoal = nil, nil
local function shot(sc, name)
	camGoal = sc:shot(name)
	if not camCF then
		camCF = camGoal
	end
	RunService:UnbindFromRenderStep("MachineMakeCam")
	RunService:BindToRenderStep("MachineMakeCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Scriptable
		c.FieldOfView = 50
		camCF = camCF:Lerp(camGoal, 1 - math.exp(-dt * 5))
		c.CFrame = camCF
	end)
end

---------------------------------------------------------------- ① 동전
local function stepCoin(sc)
	ui:setStep(1)
	shot(sc, "coin")
	ui:say("동전 3개를 넣어요", "동전 구멍을 세 번 눌러요 (100원 × 3)")
	local n, seen = 0, Pointer.presses
	while n < 3 do
		if not frame() then
			return false
		end
		if Pointer.presses ~= seen then
			seen = Pointer.presses
			local slot = nil
			for _, c in ipairs(sc.coinList) do
				if near(c, TAP_PX * 1.2) then
					slot = c
				end
			end
			if slot then
				n += 1
				Sfx.play("metalClink", 0.5, 1.4 + n * 0.1)
				-- 동전이 앞에서 구멍으로 쏙 (세운 동전 = 원기둥 축이 Z)
				local coin = Scene.part(sc.model, "Coin", Vector3.new(0.08, 0.55, 0.55), CFrame.new(slot), Color3.fromRGB(210, 210, 200), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
				task.spawn(function()
					for k = 0, 10 do
						coin.CFrame = CFrame.new(slot + Vector3.new(0, 0, -1.2 + k * 0.12)) * CFrame.Angles(0, math.rad(90), 0)
						task.wait(0.02)
					end
					coin:Destroy()
				end)
				ui:toast(string.format("%d / 3", n), 0.5)
			else
				ui:hint("기계 앞 동전 구멍을 눌러요")
			end
		end
	end
	Sfx.play("stepDone", 0.4, 1.2)
	return true
end

---------------------------------------------------------------- ② 설탕 받기
local function slide(sc, to, dur)
	local from = sc:ladlePos()
	local t = 0
	while t < dur do
		local dt = frame()
		if not dt then
			return false
		end
		t += dt
		local k = math.min(t / dur, 1)
		sc:ladleTo(from:Lerp(to, k * k * (3 - 2 * k)) + Vector3.new(0, math.sin(k * math.pi) * 0.6, 0))
	end
	return true
end

local function stepSugar(sc)
	ui:setStep(2)
	shot(sc, "sugar")
	if not slide(sc, sc.sugarLadle, 0.45) then
		return nil
	end
	local t0 = now()
	local what = sc.stage == 3 and "설탕 버튼을" or "설탕 배출구를"
	ui:say(what .. " 꾹 누르고 있으면 설탕이 나와요", "막대가 초록 칸에 오면 손을 떼요")
	local fill, pressed, holding, wasDown = 0, false, false, false
	while true do
		local dt = frame()
		if not dt then
			return nil
		end
		local d = Pointer.down
		if d and not wasDown then
			holding = near(sc.pressPos, TAP_PX * 1.3)
			if not holding then
				ui:hint(what .. " 꾹 눌러요")
			end
		end
		if not d then
			holding = false
		end
		wasDown = d
		local on = holding
		sc:setStream(on)
		if on then
			pressed = true
			fill = math.min(SUGAR_MAX, fill + SUGAR_RATE * dt)
			Sfx.loop("sugarPour", 0.5, 1)
		else
			Sfx.loop("sugarPour", 0, 1)
		end
		sc:setContents(fill * 0.9, SUGAR, Enum.Material.Sand)
		ui:setMeter(true, fill / SUGAR_MAX, SUGAR_LO / SUGAR_MAX, SUGAR_HI / SUGAR_MAX, string.format("%d%%", math.floor(fill / SUGAR_HI * 100 + 0.5)), "설탕")
		if (pressed and not on) or fill >= SUGAR_MAX then
			break
		end
	end
	Sfx.loop("sugarPour", 0, 1)
	sc:setStream(false)
	ui:setMeter(false)
	local rec = { t0 = t0, t1 = now(), fill = fill }
	if fill >= SUGAR_LO and fill <= SUGAR_HI then
		ui:toast("딱 알맞아요!", 0.8)
	elseif fill < SUGAR_LO then
		ui:toast("조금 적어요", 0.8)
	else
		ui:toast("너무 많아요", 0.8)
	end
	task.wait(0.4)
	return rec
end

---------------------------------------------------------------- ③ 녹이기
local function stepMelt(sc)
	ui:setStep(3)
	shot(sc, "melt")
	if not slide(sc, sc.burnerPos + Vector3.new(0, 0.25 * sc.ladleK, 0), 0.5) then
		return nil
	end
	ui:say("국자 안에서 원을 그리며 저어요", "딱 좋은 빠르기로 저으면 빨리 녹아요")
	local judge = StirJudge.new()
	local cfg = Config.Melt
	local melt, t, heat = 0, 0, 0
	local smp, t0 = sampler(), now()
	while melt < 1 do
		local dt = frame()
		if not dt then
			return nil
		end
		t += dt
		heat = math.min(1, heat + dt * 0.8)
		sc:setHeat(heat)
		local speed = judge:update(dt)
		local zone = StirJudge.zone(speed, cfg.slow, cfg.fast)
		local stirring = Pointer.down
		local z = stirring and zone or 0
		smp:add(dt, z)
		melt += Rules.meltGain(z, dt)
		if stirring then
			local c = sc:ladlePos()
			local tip = Pointer.toPlane(c.Y + 0.3 * sc.ladleK)
			local off = Vector3.new(tip.X - c.X, 0, tip.Z - c.Z)
			if off.Magnitude > sc.ladleR then
				off = off.Unit * sc.ladleR
			end
			sc:setStick(c + off + Vector3.new(0, 0.3 * sc.ladleK, 0), true)
			Sfx.loop("stirDry", 0.4, 0.8 + speed / 12)
		else
			sc:setStick(nil, false)
			Sfx.loop("stirDry", 0, 1)
		end
		sc:setContents(0.9, SUGAR:Lerp(AMBER, math.clamp(melt, 0, 1)), melt > 0.55 and Enum.Material.SmoothPlastic or Enum.Material.Sand)
		ui:setGauge(stirring, speed, cfg.slow, cfg.fast)
		ui:setMeter(true, melt, 0.999, 1, string.format("%d%%", math.floor(math.min(melt, 1) * 100)), "녹음")
		if t > MELT_LIMIT then
			ui:toast("너무 오래 걸렸어요", 0.8)
			break
		end
	end
	Sfx.loop("stirDry", 0, 1)
	ui:setGauge(false)
	ui:setMeter(false)
	return { t0 = t0, t1 = now(), s = smp:finish() }
end

---------------------------------------------------------------- ④ 소다
local function stepSoda(sc)
	ui:setStep(4)
	shot(sc, "soda")
	local t0 = now()
	ui:say("소다 통을 눌러 젓가락에 소다를 묻혀요", "두세 번 묻히면 알맞아요 · 다 묻혔으면 국자를 눌러 털어 넣어요")
	local dips, seen, tip = 0, Pointer.presses, sc.sodaTip
	sc:setStick(tip, true)
	while true do
		if not frame() then
			return nil
		end
		if Pointer.presses ~= seen then
			seen = Pointer.presses
			if near(sc.sodaPos + Vector3.new(0, 1.2, 0)) then
				dips += 1
				tip = sc.sodaTip - Vector3.new(0, 0.15, 0)
				Sfx.play("stirCrystal", 0.6, 1.4)
				ui:toast(string.format("소다 %d번", dips), 0.5)
			elseif dips > 0 and near(sc:ladlePos()) then
				break
			elseif dips == 0 then
				ui:hint("먼저 소다 통을 눌러요")
			end
		end
		sc:setStick(tip, true)
		sc:setStickSoda(tip, dips)
	end
	-- 털어 넣고 빠르게 젓기
	sc:setStickSoda(tip, 0)
	Sfx.play("sodaDrop", 0.5, 1.2)
	ui:say("빠르게 저어요!", "빠르게 저을수록 금방 부풀어요")
	local judge = StirJudge.new()
	local foam, t = 0, 0
	local smp = sampler()
	while foam < 1 do
		local dt = frame()
		if not dt then
			return nil
		end
		t += dt
		local speed = judge:update(dt)
		local z = Pointer.down and (speed >= Config.Soda.fastMin and 2 or 1) or 0
		smp:add(dt, z)
		foam += Rules.foamGain(z, dt)
		if Pointer.down then
			local c = sc:ladlePos()
			local p = Pointer.toPlane(c.Y + 0.3 * sc.ladleK)
			local off = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
			if off.Magnitude > sc.ladleR then
				off = off.Unit * sc.ladleR
			end
			sc:setStick(c + off + Vector3.new(0, 0.3 * sc.ladleK, 0), true)
			Sfx.loop("foamBubble", 0.4, 1)
		else
			Sfx.loop("foamBubble", 0, 1)
		end
		sc:setContents(0.9 + 0.5 * math.min(foam, 1), AMBER:Lerp(FOAM, math.min(foam * 1.4, 1)), Enum.Material.SmoothPlastic)
		ui:setGauge(Pointer.down, speed, Config.Soda.fastMin * 0.6, Config.Soda.fastMin)
		ui:setMeter(true, foam, 0.999, 1, string.format("%d%%", math.floor(math.min(foam, 1) * 100)), "거품")
		if t > Rules.FOAM_LIMIT then
			break
		end
	end
	Sfx.loop("foamBubble", 0, 1)
	ui:setGauge(false)
	ui:setMeter(false)
	sc:setStick(nil, false)
	return { t0 = t0, t1 = now(), dips = dips, s = smp:finish() }
end

---------------------------------------------------------------- ⑤ 금형판에 붓기
local function stepPour(sc, shape)
	ui:setStep(5)
	shot(sc, "pour")
	ui:say("국자를 금형판 칸 위로 끌어 꾹 누르고 있어요", "칸이 꽉 차면 다음 칸으로 · 넘치지 않게")
	local t0 = now()
	local n = #sc.cavities
	local batter = n * Rules.BATTER_PER_CAVITY -- 국자에 든 반죽 (칸 n개 + 조금)
	local cur = nil
	while true do
		local dt = frame()
		if not dt then
			return nil
		end
		if Pointer.down then
			local y = sc.cavY + 0.8
			local p = Pointer.toPlane(y)
			sc:ladleTo(Vector3.new(p.X, y, p.Z))
			cur = nil
			for i, c in ipairs(sc.cavities) do
				if Vector3.new(p.X - c.pos.X, 0, p.Z - c.pos.Z).Magnitude < sc.cavD * 0.6 then
					cur = i
				end
			end
			if cur and batter > 0 then
				local add = math.min(batter, POUR_RATE * dt)
				batter -= add
				sc:setCavityFill(cur, sc.cavities[cur].fill + add, shape)
				Sfx.loop("pourGlug", 0.45, 1)
			else
				Sfx.loop("pourGlug", 0, 1)
			end
		else
			Sfx.loop("pourGlug", 0, 1)
		end
		sc:setContents(math.max(0, batter / (n * 1.05)) * 1.3, FOAM, Enum.Material.SmoothPlastic)
		local shown = cur and sc.cavities[cur].fill or 0
		ui:setMeter(true, shown / 1.3, 0.85 / 1.3, 1.1 / 1.3, string.format("%d / %d칸", (function()
			local k = 0
			for _, c in ipairs(sc.cavities) do
				if c.fill >= 0.85 then
					k += 1
				end
			end
			return k
		end)(), n), "칸")
		local allFull = true
		for _, c in ipairs(sc.cavities) do
			if c.fill < 0.85 then
				allFull = false
			end
		end
		if allFull or batter <= 0.01 then
			break
		end
	end
	Sfx.loop("pourGlug", 0, 1)
	ui:setMeter(false)
	local fills = {}
	for i, c in ipairs(sc.cavities) do
		fills[i] = c.fill
	end
	return { t0 = t0, t1 = now(), fills = fills }
end

---------------------------------------------------------------- ⑥ 막대 꽂기
local function stepStick(sc)
	ui:setStep(6)
	shot(sc, "stick")
	local t0 = now()
	ui:say("칸마다 막대를 꽂아요", "굳기 전에 칸을 하나씩 눌러요")
	sc:ladleTo(sc.ladleRest)
	sc:setHeat(0) -- 다 부었으니 화구 끔
	local left, seen = #sc.cavities, Pointer.presses
	while left > 0 do
		if not frame() then
			return nil
		end
		if Pointer.presses ~= seen then
			seen = Pointer.presses
			for i, c in ipairs(sc.cavities) do
				if not c.stick and near(c.pos, 70) then
					sc:addStick(i)
					left -= 1
					Sfx.play("pop", 0.5, 1.2)
					break
				end
			end
		end
	end
	-- 굳으면 막대째 떼어 올림
	task.wait(0.3)
	for _, c in ipairs(sc.cavities) do
		if c.look then
			c.look:PivotTo(c.look:GetPivot() + Vector3.new(0, sc.cavD * 0.3, 0))
		end
		if c.stick then
			c.stick.Position += Vector3.new(0, sc.cavD * 0.3, 0)
		end
	end
	Sfx.play("stepDone", 0.5, 1)
	-- 국자 물에 헹굼 (영상 끝)
	task.wait(0.5)
	shot(sc, "rinse")
	slide(sc, sc.waterPos + Vector3.new(0, 0.6, 0), 0.5)
	Sfx.play("sodaDrop", 0.4, 0.7)
	task.wait(0.4)
	return { t0 = t0, t1 = now() }
end

---------------------------------------------------------------- 한 판
local function round(stage, start)
	local shape = start.shape
	local sc = Scene.new(stage, start.batch or 2, shape)
	local recs = {} -- 단계마다 입력 기록 (점수는 서버가 MachineMakeRules로 셈)
	local ok = stepCoin(sc)
	for _, k in ipairs({ "sugar", "melt", "soda", "pour", "stick" }) do
		if not ok then
			break
		end
		if k == "sugar" then
			recs.sugar = stepSugar(sc)
		elseif k == "melt" then
			recs.melt = stepMelt(sc)
		elseif k == "soda" then
			recs.soda = stepSoda(sc)
		elseif k == "pour" then
			recs.pour = stepPour(sc, shape)
		else
			recs.stick = stepStick(sc)
		end
		ok = recs[k] ~= nil
	end
	local res = nil
	if ok and not aborted then
		ui:say("다 만들었어요!", "")
		if start.test then
			-- Studio 시험: 서버와 같은 검사·점수 (MachineMakeRules.evaluate) → 기록이 서버 검사를 통과하는지도 여기서 봄
			local scores, why = Rules.evaluate(recs, start.t0, now(), #sc.cavities)
			if not scores then
				print("[MachineMake] test rejected:", why)
				return sc, { ok = false, reason = "서버 검사 거절: " .. tostring(why) }
			end
			local q = Rules.quality(scores)
			local grade = "Burnt"
			for _, g in ipairs(Config.Grades) do
				if q >= g.min then
					grade = g.name
					break
				end
			end
			print(string.format("[MachineMake] test sugar %d melt %d soda %d pour %d -> Q%d %s", scores.sugar, scores.melt, scores.soda, scores.pour, q, grade))
			return sc, { ok = true, q = q, grade = grade, made = #sc.cavities, perfect = grade == "Perfect" }
		end
		local okR, r = pcall(function()
			return Remotes:WaitForChild("SubmitMachineMake"):InvokeServer(start.id, recs)
		end)
		res = okR and r or nil
	end
	return sc, res
end

local function finish(sc)
	running = false
	Pointer.enabled = false
	Pointer.reset()
	if sc then
		sc:destroy()
	end
	if ui then
		ui:setGauge(false)
		ui:setMeter(false)
		ui:show(false)
	end
	RunService:UnbindFromRenderStep("MachineMakeCam")
	camCF, camGoal = nil, nil
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	controls(true)
	hideOthers(false)
	player:SetAttribute("Making", nil)
end

-- stage = 2·3. 기계 창의 [직접 만들기]가 부름. test = { shape } 는 Studio에서만: 서버 없이 한 판 (화면 시험용, 저장 안 바뀜)
function MachineMake.start(stage, test)
	if running or Pointer.enabled then
		return false, "지금은 다른 것을 만들고 있어요"
	end
	local okS, start
	if test and RunService:IsStudio() then
		okS, start = true, { ok = true, test = true, t0 = now(), id = "test", shape = test.shape or "Circle", batch = stage == 3 and 5 or 2 }
	else
		okS, start = pcall(function()
			return Remotes:WaitForChild("StartMachineMake"):InvokeServer(stage)
		end)
	end
	if not (okS and type(start) == "table" and start.ok) then
		return false, (okS and type(start) == "table" and start.reason) or "잠깐 뒤에 다시 해 봐요"
	end
	running, aborted = true, false
	if not ui then
		ui = Ui.new(player, STEPS)
		ui.gui.Name = "MachineMakingScreen"
	end
	ui.onExit = function()
		aborted = true
	end
	hideOthers(true)
	ui:show(true)
	ui:setSubAlways(true)
	Pointer.enabled = true
	Pointer.reset()
	controls(false)
	player:SetAttribute("Making", true)
	task.spawn(function()
		while running do
			local sc, res = round(stage, start)
			if aborted or not res then
				finish(sc)
				return
			end
			local e = ShapeCatalog.get(start.shape)
			local title = res.ok and string.format("%s · 완성도 %d%%", res.grade or "", res.q or 0) or "만들기 실패"
			local sub = res.ok and string.format("%s %d개를 만들었어요%s · 진열대·보관함으로", e and e.name or "", res.made or 0, res.perfect and " · Perfect 1개!" or "") or tostring(res.reason or "")
			if res.ok and (res.q or 0) >= 70 then
				Sfx.play("fanfare", 0.4, 1)
			end
			local ask = ui:ask(title, sub, "한 판 더", "그만하기")
			while not ask.choice do
				if not frame() then
					ask.close()
					break
				end
			end
			sc:destroy()
			if ask.choice ~= 1 then
				finish(nil)
				return
			end
			-- 한 판 더: 서버에 새 판 (Studio 시험이면 그대로)
			local ok2, s2 = true, start
			if not start.test then
				ok2, s2 = pcall(function()
					return Remotes.StartMachineMake:InvokeServer(stage)
				end)
			end
			if not (ok2 and type(s2) == "table" and s2.ok) then
				ui:say(ok2 and type(s2) == "table" and s2.reason or "잠깐 뒤에 다시 해 봐요", "")
				task.wait(2)
				finish(nil)
				return
			end
			start = s2
		end
	end)
	return true
end

return MachineMake
