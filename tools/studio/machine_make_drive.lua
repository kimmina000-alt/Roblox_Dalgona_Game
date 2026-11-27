-- 2·3단계 기계 직접 만들기 자동 시험 (Studio Play 중, MCP execute_luau datamodel = Client로 붙여 넣어 실행).
-- 서버 없이 Studio 시험 모드(MachineMake.start(stage, { shape }))로 한 판을 끝까지 하고,
-- 결과를 출력창에 "[MachineMake] test stage .. sugar .. melt .. soda .. pour .. press .. burnt .. -> Q.. 등급" (또는 "test rejected: 이유")로 남김.
-- 시험 모드도 서버와 같은 검사(shared/MachineMakeRules.evaluate)를 돌리므로, 실제 입력 기록이 서버 검사를 통과하는지 볼 수 있음.
-- 저장 데이터는 안 바뀜 (서버를 안 부름). 2026-11-26 기계 직접 만들기가 손 작업대 단계(Steps/Melt, Steps/Soda)를 쓰게 바뀐 뒤 버전.
--
-- 주의 (2026-11-26 확인):
--  * execute_luau 안에서 require하면 게임이 쓰는 모듈과 "다른 복사본"이 나온다. 그래서 여기서 require한 Pointer를 직접 움직인다
--    (같은 복사본의 MachineMake가 그 Pointer를 읽음). 서버 쪽 require(PlayerDataService)로는 실제 플레이어 데이터를 못 봄.
--  * execute_luau가 끝날 때 카메라 종류가 바뀌어 있으면 도구가 Custom으로 되돌린다 → 시작은 task.delay로 명령이 끝난 뒤에.
--  * 녹이기·소다는 손 작업대와 같아서 국자 높이를 조절해야 안 탐: 온도계 글씨("123°")를 읽어 Pointer.side.delta로 국자를 올리고 내림.
--  * 오래 가만히 두면(8초) 탄다 → 스크린샷을 찍느라 멈추면 탈 수 있음.
--  * 결과 창(한 판 더 / 그만하기)은 열린 채로 끝남 → Play를 멈추면 됨. 진행 상황은 _G.__driveLog.
-- 2026-11-26 D60~D63 뒤: 장면이 내 가게 기계 자리에 생겨서 자리는 MM.scene(MachineMakeScene)에서 읽음.
--   3단계는 기둥 아래로 국자 끌기(설탕·소다), 붓기 뒤 누름판 1.38초 누르기, 막대는 첫 칸만 막대 통에서 끌고 나머지는 칸 누르기.
local STAGE = 2 -- 2 또는 3
local SHAPE = "Star"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local plr = Players.LocalPlayer
for _, g in ipairs(plr.PlayerGui:GetChildren()) do
	if g.Name == "OfflineReport" then
		g.Enabled = false -- 들어올 때 뜨는 "자리 비운 동안" 창
	end
end
local Client = plr.PlayerScripts:WaitForChild("Client")
local P = require(Client.Making.Pointer)
local MM = require(Client.MachineMake)
local Config = require(game:GetService("ReplicatedStorage").Shared.DalgonaConfig)

local function scr(p)
	local v = workspace.CurrentCamera:WorldToViewportPoint(p)
	return Vector2.new(v.X, v.Y - GuiService:GetGuiInset().Y)
end
local function inject(down, pos)
	P.pos = pos
	if down and not P.down then
		P.down = true
		P.downPos = pos
		P.presses += 1
	elseif not down and P.down then
		P.down = false
		P.releases = (P.releases or 0) + 1
	end
end
local function tap(p2)
	inject(true, p2)
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	inject(false, p2)
	task.wait(0.35)
end
local function gui()
	return plr.PlayerGui:FindFirstChild("MachineMakingScreen")
end
local function has(pat)
	local g = gui()
	if not g then
		return false
	end
	for _, d in ipairs(g:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text:find(pat, 1, true) then
			return true
		end
	end
	return false
end
local function waitFor(pat, t)
	local t0 = os.clock()
	while not has(pat) and os.clock() - t0 < (t or 20) do
		task.wait(0.1)
	end
end
local function temp()
	for _, d in ipairs(gui():GetDescendants()) do
		if d:IsA("TextLabel") and d.Visible then
			local n = d.Text:match("^(%d+)°$")
			if n then
				return tonumber(n)
			end
		end
	end
end
local function sc()
	return MM.scene
end
local function bowl()
	return sc().model.MachineStation.Ladle.Bowl.Position
end
local function hold(pos3, t)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		inject(true, scr(pos3))
		RunService.RenderStepped:Wait()
	end
	inject(false, P.pos)
end
-- 국자 손잡이를 잡고 그릇을 bowl3 자리로 끌기 (손가락 = 그릇 + 손잡이 거리)
local function dragBowlTo(bowl3, t)
	hold(bowl3 + sc().gripOff, t)
end
-- 3단계 기둥 입구 아래로 국자 끌어 대기 (MachineMake holdUnderPillar와 같은 높이)
local function underPillar(key, t)
	local s = sc()
	local half = s.model.MachineStation.Ladle.Bowl.Size.X / 2
	local top = key == "sodaPillar" and s.sodaTop or s.sugarTop
	dragBowlTo(Vector3.new(top.X, top.Y - (s.S_ and s.S_.bowlHalf or half) - s.PILLAR_GAP * s.S, top.Z), t)
end
local lo, hi = Config.Melt.tempLow, Config.Melt.tempHigh
-- 국자 위에서 원 그리며 젓기 + 온도 맞추기 (위로 끌기 = 국자 올림 = 덜 뜨거움)
local function stirUntil(omega, pat, maxT, target)
	target = target or (lo + hi) / 2
	local a, t0 = 0, os.clock()
	while not has(pat) and os.clock() - t0 < maxT do
		local dt = RunService.RenderStepped:Wait()
		a += omega * dt
		inject(true, scr(bowl()) + Vector2.new(math.cos(a), math.sin(a)) * 40)
		local tt = temp()
		if tt then
			P.side.delta += Vector2.new(0, (tt > target) and -1.2 or ((tt < target - 6) and 1.2 or 0))
		end
	end
	inject(false, P.pos)
end

_G.__driveLog = {}
local function log(s)
	table.insert(_G.__driveLog, s)
	print("[Drive] " .. s)
end
task.delay(1, function()
	local ok, err = pcall(function()
		log("start " .. tostring(MM.start(STAGE, { shape = SHAPE })))
		waitFor("동전 3개")
		task.wait(1.3)
		for _ = 1, 3 do
			tap(scr(sc().coinList[1]))
		end
		if STAGE == 3 then
			waitFor("설탕 구멍")
			task.wait(0.6)
			underPillar("sugarPillar", 2.6)
		else
			-- 2026-11-28부터 동전을 넣으면 국자가 배출구 아래로 저절로 옴 (끌기 없음)
			waitFor("꾹 누르고")
			task.wait(0.6)
			hold(sc().pressPos, 1.9) -- 설탕 약 0.8 (초록 칸)
		end
		waitFor("원을 그리며")
		task.wait(0.8)
		stirUntil(7, STAGE == 3 and "소다 구멍" or "소다를 묻혀", 60) -- 녹이기: 적당한 빠르기
		log("melt done")
		task.wait(0.8)
		if STAGE == 3 then
			underPillar("sodaPillar", 2.0)
			task.wait(0.8)
		else
			local tub = sc().model.MachineStation.SodaTub.Soda
			for _ = 1, 2 do -- 소다 2번 묻히고 국자에 털기
				tap(scr(tub.Position))
				task.wait(0.4)
			end
			tap(scr(bowl()))
			task.wait(0.5)
		end
		stirUntil(13, "검은 판", 40, lo) -- 소다: 빠르게, 불에서 조금 떼고
		log("soda done")
		task.wait(1.3)
		local pad = gui():FindFirstChild("MoldPad", true)
		for _, f in ipairs(pad:GetChildren()) do -- 금형판 판의 칸마다 약 100%
			if f:IsA("Frame") and f.Visible then
				local c = f.AbsolutePosition + f.AbsoluteSize / 2
				local t1 = os.clock()
				while os.clock() - t1 < 1.36 do
					inject(true, c)
					RunService.RenderStepped:Wait()
				end
			end
		end
		inject(false, P.pos) -- 손을 떼야 붓기가 끝남
		waitFor("막대 더미에서", 10)
		task.wait(1.3)
		-- 첫 칸: 막대 더미에서 끌어 오기, 나머지는 칸 누르기
		local from, to = scr(sc():stickRest()), scr(sc().cavities[1].pos)
		for k = 0, 20 do
			inject(true, from:Lerp(to, k / 20))
			RunService.RenderStepped:Wait()
		end
		inject(false, to)
		task.wait(0.3)
		for i = 2, #sc().cavities do
			tap(scr(sc().cavities[i].pos))
		end
		waitFor("누름판을 꾹", 10)
		task.wait(0.8)
		_G.__pressShot = true
		hold(sc().plateCenter, math.log(Config.Press.h0 / 0.08) / Config.Press.k) -- 0.45 → 0.08
		log("press done")
	end)
	log("finished " .. tostring(ok) .. " " .. tostring(err))
end)
return "driver scheduled (출력창 [Drive]·[MachineMake] 줄, _G.__driveLog)"
