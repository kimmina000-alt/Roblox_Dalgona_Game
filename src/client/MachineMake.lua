-- 2·3단계 기계 직접 만들기 (D35·D41, 2026-11-26 사용자: 참고 영상 "달고나 판매기" 순서, 2·3단계는 같은 순서·판 수만 다름,
-- 금형판 칸이 모양 → 찍기·뽑기 없음). 서버 MachineMakeService(시작·제출), 장면 MachineMakeScene, 화면 글·게이지는 손 제작 Making/Ui.
-- 순서: ① 동전 3개 → ② 국자를 배출구에 대고 설탕 받기(꾹 누르기, 초록 칸에서 떼기) → ③ 녹이기 → ④ 소다 → ⑤ 금형판 칸마다 붓기
--       → ⑥ 칸마다 막대 꽂기 → (국자 물에 헹굼, 자동) → 서버 제출 → 결과
-- 2026-11-26 사용자 "손 작업대 화면 구현 방식과 게임 방식 그대로": 내 손 작업대를 복제한 Station(MachineMakeScene:station)으로
--   국자·나무젓가락·소다통·설탕 더미와 결정(Steps/Sugar)을 그대로 쓰고, ③ 녹이기·④ 소다는 손 작업대 단계 모듈(Steps/Melt, Steps/Soda)을
--   그대로 돌림 (결정이 녹는 단계·젓가락 길·국자 높이·탐·소다 찍기·부푸는 거품·점수 모두 같음). ⑤ 붓기는 손 작업대 붓기 판처럼
--   화면 오른쪽 반투명 검은 판(Ui:setMoldPad)의 칸을 누르고 있으면 그 칸에 부음.
-- 서버로는 점수가 아니라 입력 기록(단계 시각·설탕 양·손 제작 녹이기/소다 기록·칸마다 채운 양)을 보냄.
-- 점수·품질 Q는 shared/MachineMakeRules로 서버가 다시 셈 (Studio 시험 모드도 같은 함수). 개수·Perfect 1개 규칙은 서버가 정함
-- 2026-11-26 D60~D63 (사용자 확정):
--   D60 장면은 내 가게의 그 기계 자리에서 (MachineMakeScene), 카메라는 지금 자리에서 기계로 다가감.
--   D61 막대는 손 작업대 막대(Steps/Stick.build): 막대 통에서 끌어 칸에 놓기 (칸을 바로 눌러도 꽂힘).
--   D62 붓기 뒤 넓은 누름판으로 한 번 누르기 (목표 0.08, 손 작업대 마지막 누르기와 같음).
--   D63 3단계: 왼쪽 기둥 아래에 국자를 대고 있으면 설탕 정량, 녹인 뒤 오른쪽 기둥 아래에 대면 식소다 정량 → 바로 젓기.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local Rules = require(Shared:WaitForChild("MachineMakeRules"))
local Making = script.Parent:WaitForChild("Making")
local Ui = require(Making:WaitForChild("Ui"))
local Pointer = require(Making:WaitForChild("Pointer"))
local Sfx = require(Making:WaitForChild("Sfx"))
local CameraRig = require(Making:WaitForChild("CameraRig"))
local Steps = Making:WaitForChild("Steps")
local SugarStep = require(Steps:WaitForChild("Sugar"))
local MeltStep = require(Steps:WaitForChild("Melt"))
local SodaStep = require(Steps:WaitForChild("Soda"))
local StickStep = require(Steps:WaitForChild("Stick"))
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
	{ key = "press", label = "누르기", icon = "⬇", title = "누름판", desc = "" },
	{ key = "stick", label = "막대", icon = "🍡", title = "막대 꽂기", desc = "" },
}
local SUGAR_FULL = 1.5 -- 3단계 설탕 기둥: 정량이 다 나오는 데 걸리는 초 (Rules.SUGAR_HOLD 1.2 이상이어야 서버 통과)
local SODA_FULL = 1.0 -- 3단계 소다 기둥
local TAP_PX = 110 -- 도구 화면 자리에서 이만큼 안을 누르면 그 도구
local SUGAR_RATE = Rules.SUGAR_RATE
local SUGAR_LO, SUGAR_HI, SUGAR_MAX = Rules.SUGAR_LO, Rules.SUGAR_HI, Rules.SUGAR_MAX
local POUR_RATE = Rules.POUR_RATE
local GRAINS = 16 -- 설탕 더미 위 결정 낱알 수 (Steps/Sugar와 같은 느낌)
local WHITE = Color3.fromRGB(252, 252, 252)
local BATTER = Color3.fromRGB(206, 152, 96)

local ui = nil
local running = false
local aborted = false

local function now()
	return workspace:GetServerTimeNow()
end

local function frame()
	if aborted then
		return nil
	end
	local dt = RunService.RenderStepped:Wait()
	if aborted then
		return nil
	end
	if ui then
		ui:tick()
	end
	return dt
end

local function screenOf(pos)
	local v = workspace.CurrentCamera:WorldToViewportPoint(pos)
	local inset = game:GetService("GuiService"):GetGuiInset()
	return Vector2.new(v.X, v.Y - inset.Y) -- Pointer 좌표(위 메뉴 줄 아래 기준)와 맞춤
end
local function near(pos, px)
	return (Pointer.pos - screenOf(pos)).Magnitude < (px or TAP_PX)
end
-- 손가락 자리를 높이 y인 가로 판 위 세계 자리로
local function pointerAt(y)
	local inset = game:GetService("GuiService"):GetGuiInset()
	local ray = workspace.CurrentCamera:ViewportPointToRay(Pointer.pos.X, Pointer.pos.Y + inset.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- 국자 속 설탕 더미 (손 작업대와 같은 그릇 더미 메시 + 결정 낱알, Steps/Sugar). k = 0~1
local function showSugar(S, st, k)
	if k <= 0.01 then
		return
	end
	if SugarStep.pile(S, st, math.min(k, 1), WHITE) then
		-- 더미는 설탕 그릇 더미 메시를 복제함 → 복제한 작업대에선 그릇이 숨겨져 있어 보이게 되돌림
		if st.pile and st.pile.Transparency > 0.5 then
			st.pile.Transparency = 0
		end
		while #st.grains < math.floor(GRAINS * math.min(k, 1)) do
			SugarStep.addGrain(S, st.grains, st)
		end
	else
		S:setContents({ Transparency = 0, thickness = 0.05 + 0.3 * math.min(k, 1), Color = WHITE, Material = Enum.Material.Sand })
	end
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

-- 카메라: 동전·설탕·붓기·막대·헹굼은 장면 자리(Scene:shot), 녹이기·소다는 손 작업대 CameraRig 그대로 (국자를 따라감).
-- 장면 카메라는 매 프레임 다시 고정 (다른 스크립트가 Custom으로 돌려도 안 빠지게)
local camCF, camGoal = nil, nil
local function shot(sc, name)
	CameraRig.release()
	camGoal = sc:shot(name)
	camCF = camCF or workspace.CurrentCamera.CFrame
	RunService:UnbindFromRenderStep("MachineMakeCam")
	RunService:BindToRenderStep("MachineMakeCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Scriptable
		c.FieldOfView = 50
		camCF = camCF:Lerp(camGoal, 1 - math.exp(-dt * 5))
		c.CFrame = camCF
	end)
end
local function rig(key)
	RunService:UnbindFromRenderStep("MachineMakeCam")
	camCF = nil
	CameraRig.go(key)
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
-- 국자 그릇 가운데를 from → to로 (가운데가 살짝 들리는 호)
local function slide(sc, from, to, dur)
	local t = 0
	while t < dur do
		local dt = frame()
		if not dt then
			return false
		end
		t += dt
		local k = math.min(t / dur, 1)
		sc:ladleBowlTo(from:Lerp(to, k * k * (3 - 2 * k)) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0))
	end
	return true
end

local function stepSugar(sc, S, st)
	ui:setStep(2)
	shot(sc, "sugar")
	local home = S.Bowl.Position
	local catchAt = sc.sugarLadle + Vector3.new(0, S.bowlHalf, 0)
	if (catchAt - home).Magnitude > 0.2 and not slide(sc, home, catchAt, 0.45) then
		return nil
	end
	local t0 = now()
	local what = sc.stage == 3 and "설탕 버튼을" or "설탕 배출구를"
	ui:say(what .. " 꾹 누르고 있으면 설탕이 나와요", "막대가 초록 칸에 오면 손을 떼요")
	st.grains = {}
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
		-- 손 작업대와 같은 국자 속 설탕 더미(그릇 더미 메시) + 결정 낱알 (Steps/Sugar)
		showSugar(S, st, math.clamp(fill / SUGAR_HI, 0, 1.2))
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
	-- 국자를 화구 위로 (손 작업대 녹이기 시작 자리 = 철망 바로 위)
	local onBurner = S:ladleAt(Config.Melt.hMin)
	local pv = S.Ladle:GetPivot()
	local bowlHome = onBurner.Position - (pv.Position - S.Bowl.Position)
	if not slide(sc, S.Bowl.Position, bowlHome, 0.5) then
		return nil
	end
	S.Ladle:PivotTo(onBurner)
	return rec
end

---------------------------------------------------------------- 3단계 기둥 (D63): 국자를 끌어 기둥 아래에 대고 있으면 정량이 나옴
-- key = "sugarPillar" | "sodaPillar", full = 정량이 다 나오는 초, onFill(k 0~1) = 국자 속 보이기. 반환 { t0, t1, held }
local function holdUnderPillar(sc, S, key, full, color, onFill)
	local pillar = sc[key]
	local bowlY = pillar.Y - S.bowlHalf - 0.35 * sc.S
	local reach = 0.4 * sc.S
	local t0 = now()
	local held, wasUnder = 0, false
	local cur = S.Bowl.Position
	while held < full do
		local dt = frame()
		if not dt then
			sc:setStream(false)
			return nil
		end
		-- 손가락을 따라 국자가 움직임 (기둥 높이 바로 아래 판 위, 기둥에서 너무 멀리는 못 감)
		if Pointer.down then
			local p = pointerAt(bowlY)
			if p then
				local off = flat(p - pillar)
				if off.Magnitude > 5 * sc.S then
					off = off.Unit * 5 * sc.S
				end
				local want = Vector3.new(pillar.X, bowlY, pillar.Z) + off
				cur = cur:Lerp(want, 1 - math.exp(-dt * 14))
			end
		end
		sc:ladleBowlTo(cur)
		local d = flat(S.Bowl.Position - pillar).Magnitude
		local under = d < reach
		sc:setPillarGlow(key, d < reach * 3)
		if under then
			held = math.min(full, held + dt)
			onFill(held / full)
			sc:setStream(true, pillar, color)
			Sfx.loop("sugarPour", 0.5, key == "sodaPillar" and 1.3 or 1)
		else
			sc:setStream(false)
			Sfx.loop("sugarPour", 0, 1)
			if wasUnder then
				ui:hint("기둥 아래에 계속 대고 있어요")
			end
		end
		wasUnder = under
		ui:setMeter(true, held / full, 0.999, 1, string.format("%d%%", math.floor(held / full * 100 + 0.5)), key == "sodaPillar" and "소다" or "설탕")
	end
	Sfx.loop("sugarPour", 0, 1)
	sc:setStream(false)
	sc:setPillarGlow(key, false)
	ui:setMeter(false)
	Sfx.play("stepDone", 0.4, 1.3)
	return { t0 = t0, t1 = now(), held = held }
end

-- 국자를 화구(열선 컵) 위 녹이기 자리로
local function toBurner(sc, S)
	local onBurner = S:ladleAt(Config.Melt.hMin)
	local pv = S.Ladle:GetPivot()
	local bowlHome = onBurner.Position - (pv.Position - S.Bowl.Position)
	if not slide(sc, S.Bowl.Position, bowlHome, 0.5) then
		return false
	end
	S.Ladle:PivotTo(onBurner)
	return true
end

local function stepPillarSugar(sc, S, st)
	ui:setStep(2)
	shot(sc, "sugar")
	st.grains = {}
	-- 국자는 앞쪽 받침에서 시작 (화구 컵이 바로 설탕 기둥 아래라서)
	local rest = sc.ladleRest + Vector3.new(0, S.bowlHalf, 0)
	if not slide(sc, S.Bowl.Position, rest, 0.4) then
		return nil
	end
	ui:say("국자를 왼쪽 기둥 아래로 끌어 대요", "대고 있으면 설탕이 정해진 만큼 나와요")
	local rec = holdUnderPillar(sc, S, "sugarPillar", SUGAR_FULL, WHITE, function(k)
		showSugar(S, st, k)
	end)
	if not rec then
		return nil
	end
	ui:toast("설탕 딱 알맞아요!", 0.8)
	task.wait(0.3)
	if not toBurner(sc, S) then
		return nil
	end
	return rec
end

-- 녹인 뒤 오른쪽 기둥에서 식소다 정량 → st.sodaPreset (Steps/Soda가 찍기 없이 바로 젓기)
local function stepPillarSoda(sc, S, st)
	shot(sc, "sodaPillar")
	ui:say("국자를 오른쪽 기둥 아래로 끌어 대요", "식소다가 정해진 만큼 나와요 · 대면 바로 빠르게 저어요")
	local first = nil
	local rec = holdUnderPillar(sc, S, "sodaPillar", SODA_FULL, Color3.fromRGB(240, 240, 236), function()
		first = first or now()
	end)
	if not rec then
		return false
	end
	st.sodaPreset = Rules.SODA_FIXED
	st.sodaAt = first or now()
	return toBurner(sc, S)
end

---------------------------------------------------------------- ⑤ 금형판에 붓기 (반투명 검은 판)
local function stepPour(sc, S, shape, st)
	ui:setStep(5)
	shot(sc, "pour")
	ui:say("오른쪽 검은 판의 칸을 꾹 누르고 있어요", "칸이 꽉 차면 다음 칸으로 · 넘치지 않게")
	local t0 = now()
	local n = #sc.cavities
	local batter0 = n * Rules.BATTER_PER_CAVITY -- 국자에 든 반죽 (칸 n개 + 조금)
	local batter = batter0
	local color = st.batterColor or S.Contents.Color or BATTER
	local baseThick = math.max(0.1, S.Contents.Size.X)
	local uvs, rr = sc:moldPadLayout()
	local fills = {}
	for i = 1, n do
		fills[i] = 0
	end
	-- 국자는 금형판 위로 (처음엔 판 가운데 위)
	local hoverY = sc.cavY + S.bowlHalf + 1.1
	local cur, last = nil, sc.plateCenter
	local tilt = 0
	ui:setMoldPad(true, uvs, fills, nil, rr)
	while true do
		local dt = frame()
		if not dt then
			ui:setMoldPad(false)
			sc:setPourStream(nil)
			return nil
		end
		cur = nil
		if Pointer.down then
			local u, v = ui:moldPadAt(Pointer.pos)
			if u then
				local best, bd = nil, (rr * 1.7) ^ 2
				for i, c in ipairs(uvs) do
					local dd = (c[1] - u) ^ 2 + (c[2] - v) ^ 2
					if dd < bd then
						best, bd = i, dd
					end
				end
				cur = best
			else
				ui:hint("오른쪽 검은 판의 칸을 눌러요")
			end
		end
		if cur then
			last = sc.cavities[cur].pos
		end
		-- 국자: 고른 칸 위로 가서 기울여 부음 (손을 떼면 바로 세움)
		tilt += ((cur and batter > 0) and 1.0 - tilt or -tilt) * (1 - math.exp(-dt * 10))
		local bowlAt = Vector3.new(last.X, hoverY, last.Z) + Vector3.new(0, 0, -0.35 * tilt)
		sc:ladleBowlTo(bowlAt, tilt)
		if cur and batter > 0 then
			local add = math.min(batter, POUR_RATE * dt)
			batter -= add
			fills[cur] += add
			sc:setCavityFill(cur, fills[cur], shape, color)
			sc:setPourStream(S.Bowl.Position + Vector3.new(0, -0.2, -0.2), sc.cavities[cur].pos + Vector3.new(0, 0.05, 0), color)
			S:setContents({ thickness = baseThick * math.max(0, batter / batter0) })
			Sfx.loop("pourGlug", 0.45, 1)
		else
			sc:setPourStream(nil)
			Sfx.loop("pourGlug", 0, 1)
		end
		ui:setMoldPad(true, uvs, fills, cur, rr)
		local full = 0
		for i = 1, n do
			if fills[i] >= Rules.CAVITY_FULL then
				full += 1
			end
		end
		ui:setMeter(true, (cur and fills[cur] or 0) / 1.3, 0.85 / 1.3, 1.1 / 1.3, string.format("%d / %d칸", full, n), "칸")
		-- 칸이 다 85% 넘어도 손을 뗄 때까지는 계속 (마지막 칸도 100%까지 채울 수 있게)
		if (full >= n and not Pointer.down) or batter <= 0.01 then
			break
		end
	end
	Sfx.loop("pourGlug", 0, 1)
	sc:setPourStream(nil)
	ui:setMeter(false)
	ui:setMoldPad(false)
	S:setContents({ Transparency = 1 })
	return { t0 = t0, t1 = now(), fills = fills }
end

---------------------------------------------------------------- ⑥ 넓은 누름판으로 한 번 누르기 (D62)
local PRESS_VIS = 1.6 -- 두께 1 = 화면에서 이만큼 스터드
local function stepPress(sc, S)
	ui:setStep(6)
	shot(sc, "press")
	sc:ladleBowlTo(sc.ladleRest + Vector3.new(0, S.bowlHalf, 0))
	sc:setHeat(0) -- 다 부었으니 화구 끔
	local P = Config.Press
	local target = P.targets[#P.targets]
	local function hy(h)
		return 0.04 + h * PRESS_VIS
	end
	if not sc:presser() then
		-- 누름판을 못 찾음 (작업대 없음): 누르기 없이 목표 두께로 (점수는 그대로 나옴)
		warn("[MachineMake] presser missing")
	end
	-- 위에서 내려와 반죽에 닿음
	local top = hy(P.h0) + 3
	local t = 0
	while t < 0.45 do
		local dt = frame()
		if not dt then
			return nil
		end
		t += dt
		local k = math.min(t / 0.45, 1)
		sc:presserTo(top + (hy(P.h0) - top) * k * k)
	end
	Sfx.play("pop", 0.4, 0.8)
	ui:say("누름판을 꾹 누르고 있어요", "막대가 초록 칸에 오면 손을 떼요 · 한 번만 눌러요")
	local h, t0, pressed = P.h0, nil, false
	local lo, hi = target - 0.015, target + 0.02
	while true do
		local dt = frame()
		if not dt then
			sc:hidePresser()
			ui:setMeter(false)
			return nil
		end
		if Pointer.down then
			t0 = t0 or now()
			pressed = true
			h = h * math.exp(-P.k * dt)
			Sfx.loop("pourGlug", 0.15, 0.6)
		elseif pressed then
			break
		end
		if h < 0.03 then
			break
		end
		sc:presserTo(hy(h))
		sc:flattenCavities(math.clamp((P.h0 - h) / (P.h0 - target), 0, 1.2))
		ui:setMeter(true, h / P.h0, lo / P.h0, hi / P.h0, string.format("%d%%", math.floor(target / h * 100 + 0.5)), "두께")
	end
	Sfx.loop("pourGlug", 0, 1)
	ui:setMeter(false)
	local t1 = now()
	Sfx.play("pressSticky", 0.5, 1)
	if h >= lo and h <= hi then
		ui:toast("딱 알맞게 눌렀어요!", 0.8)
	elseif h < P.crack then
		ui:toast("너무 얇아서 갈라졌어요", 0.8)
	elseif h > hi then
		ui:toast("조금 두꺼워요", 0.8)
	else
		ui:toast("조금 얇아요", 0.8)
	end
	-- 누름판 들어 올림
	t = 0
	while t < 0.35 do
		local dt = frame()
		if not dt then
			break
		end
		t += dt
		sc:presserTo(hy(h) + 3 * math.min(t / 0.35, 1))
	end
	sc:hidePresser()
	return { t0 = t0 or t1, t1 = t1 + 0.01, h = h }
end

---------------------------------------------------------------- ⑦ 막대 꽂기 (D61, 손 작업대 막대) + 헹굼
-- 칸 i에 막대를 꽂은 자세 (한쪽 끝이 칸 가운데, 나머지는 앞(-Z)으로 빠져나옴, 막대 길이 = X축)
local function stickCF(sc, i)
	local p = sc:stickSpot(i) + sc.dir(Vector3.new(0, 0, -(StickStep.SIZE.LEN / 2 - sc.cavD * 0.15)))
	return CFrame.new(p) * sc.rot * CFrame.Angles(0, math.rad(90), 0)
end

local function stepStick(sc, S)
	ui:setStep(7)
	shot(sc, "stick")
	local t0 = now()
	ui:say("막대 통에서 막대를 끌어 칸마다 놓아요", "칸을 바로 눌러도 꽂혀요")
	sc:ladleBowlTo(sc.ladleRest + Vector3.new(0, S.bowlHalf, 0))
	sc:setHeat(0)
	local left = #sc.cavities
	local drag, place = nil, nil
	local wasDown = false
	local restCF = CFrame.new(sc:stickRest()) * sc.rot
	local dragY = sc.cavY + 0.4
	local function freeNear(px)
		local best, bd = nil, px
		for i, c in ipairs(sc.cavities) do
			if not c.stick then
				local d = (Pointer.pos - screenOf(c.pos)).Magnitude
				if d < bd then
					best, bd = i, d
				end
			end
		end
		return best
	end
	local function plant(i, m, pl)
		local c = sc.cavities[i]
		pl(stickCF(sc, i))
		c.stick, c.stickPlace = m, pl
		left -= 1
		Sfx.play("pop", 0.5, 1.2)
	end
	while left > 0 do
		if not frame() then
			if drag then
				drag:Destroy()
			end
			return nil
		end
		local d = Pointer.down
		if d and not wasDown then
			if near(sc:stickRest(), TAP_PX * 1.2) then
				drag, place = StickStep.build(S)
				drag.Parent = sc.model
				place(restCF)
			else
				local i = freeNear(80)
				if i then
					local m, pl = StickStep.build(S)
					m.Parent = sc.model
					plant(i, m, pl)
				else
					ui:hint("막대 통에서 막대를 끌어 와요")
				end
			end
		end
		if drag then
			if d then
				local p = pointerAt(dragY)
				if p then
					place(CFrame.new(p) * sc.rot * CFrame.Angles(0, math.rad(90), 0))
				end
			else
				local i = freeNear(110)
				if i then
					plant(i, drag, place)
				else
					drag:Destroy()
					ui:hint("빈 칸 위에 놓아요")
				end
				drag, place = nil, nil
			end
		end
		wasDown = d
	end
	-- 굳으면 막대째 떼어 올림
	task.wait(0.3)
	for _, c in ipairs(sc.cavities) do
		if c.look then
			c.look:PivotTo(c.look:GetPivot() + Vector3.new(0, sc.cavD * 0.3, 0))
		end
		if c.stick then
			c.stick:PivotTo(c.stick:GetPivot() + Vector3.new(0, sc.cavD * 0.3, 0))
		end
	end
	Sfx.play("stepDone", 0.5, 1)
	-- 국자 물에 헹굼 (영상 끝)
	task.wait(0.5)
	shot(sc, "rinse")
	slide(sc, S.Bowl.Position, sc.waterPos + Vector3.new(0, 0.6, 0), 0.5)
	Sfx.play("sodaDrop", 0.4, 0.7)
	task.wait(0.4)
	return { t0 = t0, t1 = now() }
end

---------------------------------------------------------------- 한 판
local function round(stage, start)
	local shape = start.shape
	local sc = Scene.new(stage, start.batch or 2, shape)
	local S, why = sc:station()
	if not S then
		return sc, { ok = false, reason = why }
	end
	CameraRig.init(S.model:GetPivot(), S.model)
	-- 손 작업대 단계 모듈(Steps/Melt, Steps/Soda)이 쓰는 ctx (MakingClient runSession과 같은 모양)
	local ctx = { station = S, pointer = Pointer, ui = ui, state = {}, records = {}, scores = {}, aborted = false }
	function ctx.now()
		return now()
	end
	function ctx.frame()
		local dt = frame()
		ctx.aborted = dt == nil
		return dt
	end
	function ctx.live(key, score)
		ctx.scores[key] = score
		ui:setQuality(Scoring.live(ctx.scores), Config.StarCut)
	end
	function ctx.markBurnt()
		local m = ctx.records.melt
		if m then
			m.burn = 1
			m.burnt = true
		end
		ctx.state.burntLate = true
	end
	ui:setQuality(100, Config.StarCut)
	local recs = ctx.records
	local burnt = false
	local ok = stepCoin(sc)
	if ok then
		if stage == 3 then
			recs.sugar = stepPillarSugar(sc, S, ctx.state)
		else
			recs.sugar = stepSugar(sc, S, ctx.state)
		end
		ok = recs.sugar ~= nil
	end
	if ok then
		ui:setStep(3)
		sc:setHeat(1)
		rig("melt")
		recs.melt = MeltStep.run(ctx)
		ok = recs.melt ~= nil
		burnt = ok and (recs.melt.burnt == true)
	end
	if ok and not burnt then
		Sfx.play("stepDone", 0.45)
		ui:setStep(4)
		if stage == 3 then
			ok = stepPillarSoda(sc, S, ctx.state)
		end
		if ok then
			rig("soda")
			recs.soda = SodaStep.run(ctx)
		end
		ok = recs.soda ~= nil
		if ok and ctx.state.burntLate then
			recs.soda.burnt = true
			burnt = true
		end
	end
	if ok and not burnt then
		Sfx.play("stepDone", 0.45)
		recs.pour = stepPour(sc, S, shape, ctx.state)
		ok = recs.pour ~= nil
	end
	if ok and not burnt then
		recs.press = stepPress(sc, S)
		ok = recs.press ~= nil
	end
	if ok and not burnt then
		recs.stick = stepStick(sc, S)
		ok = recs.stick ~= nil
	end
	if burnt and ok then
		ui:say("앗, 까맣게 탔어요", "이번 판은 탄 달고나가 돼요")
		task.wait(1.5)
	end
	local res = nil
	if ok and not aborted then
		if not burnt then
			ui:say("다 만들었어요!", "")
		end
		if start.test then
			-- Studio 시험: 서버와 같은 검사·점수 (MachineMakeRules.evaluate) → 기록이 서버 검사를 통과하는지도 여기서 봄
			local scores, why2 = Rules.evaluate(recs, start.t0, now(), #sc.cavities, stage)
			if not scores then
				print("[MachineMake] test rejected:", why2)
				return sc, { ok = false, reason = "서버 검사 거절: " .. tostring(why2) }
			end
			local q = Rules.quality(scores, stage)
			local grade = "Burnt"
			for _, g in ipairs(Config.Grades) do
				if q >= g.min then
					grade = g.name
					break
				end
			end
			print(string.format("[MachineMake] test stage %d sugar %d melt %d soda %d pour %d press %d burnt %s -> Q%d %s", stage, scores.sugar, scores.melt, scores.soda, scores.pour, scores.press or 0, tostring(scores.burnt), q, grade))
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
	Pointer.sideZone = nil
	if sc then
		sc:destroy()
	end
	if ui then
		ui:setGauge(false)
		ui:setMeter(false)
		pcall(function()
			ui:setHeight(false)
			ui:setMoldPad(false)
		end)
		ui:show(false)
	end
	RunService:UnbindFromRenderStep("MachineMakeCam")
	camCF, camGoal = nil, nil
	CameraRig.release()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	controls(true)
	hideOthers(false)
	player:SetAttribute("Making", nil)
	local re = Remotes:FindFirstChild("MakingState")
	if re then
		re:FireServer(false)
	end
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
	-- 서버도 같은 속성 (칭호 숨김 · 주문 손님 기다림 절반 속도 D59 · 다른 사람 화면)
	local re = Remotes:FindFirstChild("MakingState")
	if re then
		re:FireServer(true)
	end
	task.spawn(function()
		while running do
			local ok, sc, res = pcall(round, stage, start)
			if not ok then
				warn("[MachineMake] round error:", sc)
				finish(nil)
				return
			end
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
