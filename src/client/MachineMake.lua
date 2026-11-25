-- 2·3단계 기계 직접 만들기 (D35·D41, 2026-11-26 사용자: 참고 영상 "달고나 판매기" 순서, 2·3단계는 같은 순서·판 수만 다름,
-- 금형판 칸이 모양 → 찍기·뽑기 없음). 서버 MachineMakeService(시작·제출), 장면 MachineMakeScene, 화면 글·게이지는 손 제작 Making/Ui.
-- 순서: ① 동전 3개 → ② 국자를 배출구에 대고 설탕 받기(꾹 누르기, 초록 칸에서 떼기) → ③ 화구에서 원 그리며 젓기
--       → ④ 설탕 섞은 소다를 젓가락에 묻혀(통 누르기) 국자에 털고 빠르게 젓기 → ⑤ 금형판 칸마다 국자를 대고 꾹 눌러 붓기
--       → ⑥ 칸마다 막대 꽂기 → (국자 물에 헹굼, 자동) → 서버 제출 → 결과
-- 점수(0~100)는 설탕·녹이기·소다·붓기 4개를 서버로 보냄. 품질 Q와 개수·Perfect 1개 규칙은 서버가 정함
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
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
local SUGAR_RATE = 0.42 -- 설탕 받는 빠르기 (1 = 꽉 참)
local SUGAR_LO, SUGAR_HI, SUGAR_MAX = 0.72, 0.95, 1.25
local MELT_RATE = 0.085 -- 적당한 빠르기로 저을 때 초당 녹는 양 (약 12초)
local MELT_LIMIT = 32
local FOAM_RATE = 0.3 -- 빠르게 저을 때 초당 거품
local POUR_RATE = 0.75 -- 칸에 붓는 빠르기
local SUGAR = Color3.fromRGB(250, 250, 248)
local AMBER = Color3.fromRGB(226, 150, 50)
local FOAM = Color3.fromRGB(206, 152, 96)

local ui = nil
local running = false
local aborted = false

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

local function controls(on)
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and pm then
		local c = pm:GetControls()
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end
end

-- 위에서 내려다봄 (화면 위 = 기계 뒤 -Z)
local function camera(sc)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 50
	local o = sc.origin.Position
	local vp = cam.ViewportSize
	local h = vp.X / math.max(vp.Y, 1) < 1.2 and 26 or 15.5
	cam.CFrame = CFrame.lookAt(o + Vector3.new(-0.4, h, h * 0.2), o + Vector3.new(-0.4, 0, 0.2), Vector3.new(0, 0, -1))
end

---------------------------------------------------------------- ① 동전
local function stepCoin(sc)
	ui:setStep(1)
	ui:say("동전 3개를 넣어요", "동전 구멍을 세 번 눌러요 (100원 × 3)")
	local n, seen = 0, Pointer.presses
	while n < 3 do
		if not frame() then
			return false
		end
		if Pointer.presses ~= seen then
			seen = Pointer.presses
			if near(sc.coinPos, TAP_PX * 1.2) then
				n += 1
				Sfx.play("metalClink", 0.5, 1.4 + n * 0.1)
				local coin = Scene.cyl(sc.model, "Coin", 0.08, 0.8, sc.coinPos + Vector3.new(0, 1.2, 0), Color3.fromRGB(210, 210, 200), Enum.Material.Metal)
				task.spawn(function()
					for k = 0, 10 do
						coin.Position = sc.coinPos + Vector3.new(0, 1.2 - k * 0.12, 0)
						task.wait(0.02)
					end
					coin:Destroy()
				end)
				ui:toast(string.format("%d / 3", n), 0.5)
			else
				ui:hint("왼쪽 위 동전 구멍을 눌러요")
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
	if not slide(sc, Vector3.new(sc.spoutPos.X, sc.origin.Y + 0.25, sc.spoutPos.Z + 0.1), 0.45) then
		return nil
	end
	ui:say("배출구를 꾹 누르고 있으면 설탕이 나와요", "막대가 초록 칸에 오면 손을 떼요")
	local fill, pressed = 0, false
	while true do
		local dt = frame()
		if not dt then
			return nil
		end
		local on = Pointer.down
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
	ui:setMeter(false)
	local score
	if fill >= SUGAR_LO and fill <= SUGAR_HI then
		score = 100
		ui:toast("딱 알맞아요!", 0.8)
	elseif fill < SUGAR_LO then
		score = math.max(20, 100 - (SUGAR_LO - fill) * 160)
		ui:toast("조금 적어요", 0.8)
	else
		score = math.max(20, 100 - (fill - SUGAR_HI) * 220)
		ui:toast("너무 많아요", 0.8)
	end
	task.wait(0.4)
	return score
end

---------------------------------------------------------------- ③ 녹이기
local function stepMelt(sc)
	ui:setStep(3)
	if not slide(sc, sc.burnerPos + Vector3.new(0, 0.55, 0), 0.5) then
		return nil
	end
	ui:say("국자 안에서 원을 그리며 저어요", "딱 좋은 빠르기로 저으면 빨리 녹아요")
	local judge = StirJudge.new()
	local cfg = Config.Melt
	local melt, good, bad, t, heat = 0, 0, 0, 0, 0
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
		if stirring then
			melt += dt * MELT_RATE * (zone == 2 and 1 or zone == 3 and 0.55 or 0.2)
			if zone == 2 then
				good += dt
			else
				bad += dt * 0.6
			end
			local tip = Pointer.toPlane(sc:ladlePos().Y + 0.3)
			local c = sc:ladlePos()
			local off = Vector3.new(tip.X - c.X, 0, tip.Z - c.Z)
			if off.Magnitude > 0.6 then
				off = off.Unit * 0.6
			end
			sc:setStick(c + off + Vector3.new(0, 0.3, 0), true)
			Sfx.loop("stirDry", 0.4, 0.8 + speed / 12)
		else
			bad += dt -- 안 저으면 바닥이 눌어붙음
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
	local score = math.clamp(100 * good / math.max(good + bad, 0.1), 0, 100)
	if t > MELT_LIMIT then
		score *= 0.6
	end
	return score
end

---------------------------------------------------------------- ④ 소다
local function stepSoda(sc)
	ui:setStep(4)
	ui:say("소다 통을 눌러 젓가락에 소다를 묻혀요", "두세 번 묻히면 알맞아요 · 다 묻혔으면 국자를 눌러 털어 넣어요")
	local dips, seen, tip = 0, Pointer.presses, sc.sodaPos + Vector3.new(0, 1.4, 0)
	sc:setStick(tip, true)
	while true do
		if not frame() then
			return nil
		end
		if Pointer.presses ~= seen then
			seen = Pointer.presses
			if near(sc.sodaPos + Vector3.new(0, 1.2, 0)) then
				dips += 1
				tip = sc.sodaPos + Vector3.new(0, 1.3, 0)
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
	while foam < 1 do
		local dt = frame()
		if not dt then
			return nil
		end
		t += dt
		local speed = judge:update(dt)
		if Pointer.down then
			foam += dt * FOAM_RATE * (speed >= Config.Soda.fastMin and 1 or 0.35)
			local c = sc:ladlePos()
			local p = Pointer.toPlane(c.Y + 0.3)
			local off = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
			if off.Magnitude > 0.6 then
				off = off.Unit * 0.6
			end
			sc:setStick(c + off + Vector3.new(0, 0.3, 0), true)
			Sfx.loop("foamBubble", 0.4, 1)
		else
			Sfx.loop("foamBubble", 0, 1)
		end
		sc:setContents(0.9 + 0.5 * math.min(foam, 1), AMBER:Lerp(FOAM, math.min(foam * 1.4, 1)), Enum.Material.SmoothPlastic)
		ui:setGauge(Pointer.down, speed, Config.Soda.fastMin * 0.6, Config.Soda.fastMin)
		ui:setMeter(true, foam, 0.999, 1, string.format("%d%%", math.floor(math.min(foam, 1) * 100)), "거품")
		if t > 25 then
			break
		end
	end
	Sfx.loop("foamBubble", 0, 1)
	ui:setGauge(false)
	ui:setMeter(false)
	sc:setStick(nil, false)
	local dipScore = (dips == 2 or dips == 3) and 100 or (dips == 1 and 70) or 60
	local foamScore = math.clamp(100 - math.max(0, t - 4) * 6, 40, 100)
	if foam < 1 then
		foamScore = 30
	end
	return dipScore * 0.5 + foamScore * 0.5
end

---------------------------------------------------------------- ⑤ 금형판에 붓기
local function stepPour(sc, shape)
	ui:setStep(5)
	ui:say("국자를 금형판 칸 위로 끌어 꾹 누르고 있어요", "칸이 꽉 차면 다음 칸으로 · 넘치지 않게")
	local n = #sc.cavities
	local batter = n * 1.05 -- 국자에 든 반죽 (칸 n개 + 조금)
	local cur = nil
	while true do
		local dt = frame()
		if not dt then
			return nil
		end
		if Pointer.down then
			local p = Pointer.toPlane(sc.origin.Y + 1.3)
			sc:ladleTo(Vector3.new(p.X, sc.origin.Y + 1.3, p.Z))
			cur = nil
			for i, c in ipairs(sc.cavities) do
				if Vector3.new(p.X - c.pos.X, 0, p.Z - c.pos.Z).Magnitude < 1.1 then
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
	local sum = 0
	for _, c in ipairs(sc.cavities) do
		sum += math.clamp(100 - math.abs(c.fill - 1) * 220, 0, 100)
	end
	return sum / n
end

---------------------------------------------------------------- ⑥ 막대 꽂기
local function stepStick(sc)
	ui:setStep(6)
	ui:say("칸마다 막대를 꽂아요", "굳기 전에 칸을 하나씩 눌러요")
	sc:ladleTo(sc.ladleRest)
	local left, seen = #sc.cavities, Pointer.presses
	while left > 0 do
		if not frame() then
			return false
		end
		if Pointer.presses ~= seen then
			seen = Pointer.presses
			for _, c in ipairs(sc.cavities) do
				if not c.stick and near(c.pos, 70) then
					c.stick = Scene.part(sc.model, "Stick", Vector3.new(0.14, 0.14, 2.4), CFrame.new(c.pos + Vector3.new(0, 0.12, 1.7)), Color3.fromRGB(236, 214, 170), Enum.Material.Wood)
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
			c.look:PivotTo(c.look:GetPivot() + Vector3.new(0, 0.6, 0))
		end
		if c.stick then
			c.stick.Position += Vector3.new(0, 0.6, 0)
		end
	end
	Sfx.play("stepDone", 0.5, 1)
	-- 국자 물에 헹굼 (영상 끝)
	slide(sc, sc.waterPos + Vector3.new(0, 0.6, 0), 0.5)
	Sfx.play("sodaDrop", 0.4, 0.7)
	task.wait(0.4)
	return true
end

---------------------------------------------------------------- 한 판
local function round(stage, start)
	local shape = start.shape
	local sc = Scene.new(stage, start.batch or 2, shape)
	camera(sc)
	local scores = {}
	local ok = stepCoin(sc)
	if ok then
		scores.sugar = stepSugar(sc)
		ok = scores.sugar ~= nil
	end
	if ok then
		scores.melt = stepMelt(sc)
		ok = scores.melt ~= nil
	end
	if ok then
		scores.soda = stepSoda(sc)
		ok = scores.soda ~= nil
	end
	if ok then
		scores.pour = stepPour(sc, shape)
		ok = scores.pour ~= nil
	end
	if ok then
		ok = stepStick(sc)
	end
	local res = nil
	if ok and not aborted then
		ui:say("다 만들었어요!", "")
		local okR, r = pcall(function()
			return Remotes:WaitForChild("SubmitMachineMake"):InvokeServer(start.id, scores)
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
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	controls(true)
	player:SetAttribute("Making", nil)
end

-- stage = 2·3. 기계 창의 [직접 만들기]가 부름
function MachineMake.start(stage)
	if running or Pointer.enabled then
		return false, "지금은 다른 것을 만들고 있어요"
	end
	local okS, start = pcall(function()
		return Remotes:WaitForChild("StartMachineMake"):InvokeServer(stage)
	end)
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
			-- 한 판 더: 서버에 새 판
			local ok2, s2 = pcall(function()
				return Remotes.StartMachineMake:InvokeServer(stage)
			end)
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
