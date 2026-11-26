-- 2·3단계 기계 직접 만들기 자동 시험 (Studio Play 중, MCP execute_luau datamodel = Client로 붙여 넣어 실행).
-- 서버 없이 Studio 시험 모드(MachineMake.start(stage, { shape }))로 한 판을 끝까지 하고,
-- 결과를 출력창에 "[MachineMake] test sugar .. melt .. soda .. pour .. -> Q.. 등급" (또는 "test rejected: 이유")로 남김.
-- 시험 모드도 서버와 같은 검사(shared/MachineMakeRules.evaluate)를 돌리므로, 실제 입력 기록이 서버 검사를 통과하는지 볼 수 있음.
-- 저장 데이터는 안 바뀜 (서버를 안 부름).
--
-- 주의 (2026-11-26 확인):
--  * execute_luau 안에서 require하면 게임이 쓰는 모듈과 "다른 복사본"이 나온다. 그래서 MakingClient.TestPointer 대신
--    여기서 require한 Pointer를 직접 움직인다 (같은 복사본의 MachineMake가 그 Pointer를 읽음).
--  * 같은 이유로 서버 쪽 require(PlayerDataService)로는 실제 플레이어 데이터를 못 본다 → 클라이언트에서 Remotes.GetPlayerState로 볼 것.
--  * 카메라가 옮겨 가는 데 약 1초라 단계마다 기다린 뒤 누름. 젓기는 화면에서 원을 그림: 녹이기 7 rad/s(적당), 소다 13 rad/s(빠르게).
--  * 결과 창(한 판 더 / 그만하기)은 열린 채로 끝남 → Play를 멈추면 됨.
local STAGE = 3 -- 2 또는 3
local SHAPE = "Heart"

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
local Pointer = require(Client.Making.Pointer)
local MM = require(Client.MachineMake)

-- MachineMakeScene LAYOUT 값 (장면 원점 (0, 900, 0), S배). 장면 값을 바꾸면 여기도 같이.
local L = ({
	[2] = {
		S = 2.5, ladle = 0.7, size = Vector3.new(4.86, 5.86, 3.23), coin = Vector3.new(1.5, 1.36, -1.65),
		press = Vector3.new(0, 0.75, -1.65), burner = Vector3.new(1.4, 4.52, -0.1), shelfY = 4.5, cavY = 5.92,
		cavs = { Vector3.new(0.31, 0, 1.15), Vector3.new(-0.26, 0, 1.15) }, -- 8칸 중 가운데 2칸
	},
	[3] = {
		S = 2, ladle = 0.85, size = Vector3.new(6.32, 7.13, 4.97), coin = Vector3.new(-0.94, 4.84, -2.45),
		press = Vector3.new(0.29, 4.13, -2.45), burner = Vector3.new(1.7, 1.5, -1.4), shelfY = 1.7, cavY = 1.7,
		cavs = { Vector3.new(-0.75, 0, -1.8), Vector3.new(-1.6, 0, -1.8), Vector3.new(-2.45, 0, -1.8), Vector3.new(-1.17, 0, -0.95), Vector3.new(-2.03, 0, -0.95) },
	},
})[STAGE]
local O, S = Vector3.new(0, 900, 0), L.S
local function W(v)
	return O + v * S
end
local function scr(p)
	local v = workspace.CurrentCamera:WorldToViewportPoint(p)
	return Vector2.new(v.X, v.Y - GuiService:GetGuiInset().Y)
end
local function inject(down, pos)
	Pointer.pos = pos
	if down and not Pointer.down then
		Pointer.down = true
		Pointer.downPos = pos
		Pointer.downTime = os.clock()
		Pointer.presses += 1
	elseif not down and Pointer.down then
		Pointer.down = false
		Pointer.upTime = os.clock()
		Pointer.releases = (Pointer.releases or 0) + 1
	end
end
local function screenText(pat)
	local g = plr.PlayerGui:FindFirstChild("MachineMakingScreen")
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
local function waitText(pat, t)
	local t0 = os.clock()
	while not screenText(pat) do
		if os.clock() - t0 > (t or 30) then
			error("timeout waiting: " .. pat)
		end
		task.wait(0.1)
	end
end
local function tap(worldPos)
	inject(true, scr(worldPos))
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	inject(false, scr(worldPos))
	task.wait(0.35)
end
local function hold(worldPos, secs)
	local t0 = os.clock()
	while os.clock() - t0 < secs do
		inject(true, scr(worldPos))
		RunService.RenderStepped:Wait()
	end
end
local function stir(centerWorld, omega, untilText, maxT)
	local a, t0 = 0, os.clock()
	while not screenText(untilText) and os.clock() - t0 < maxT do
		local dt = RunService.RenderStepped:Wait()
		a += omega * dt
		inject(true, scr(centerWorld) + Vector2.new(math.cos(a), math.sin(a)) * 45)
	end
	inject(false, Pointer.pos)
end

task.spawn(function()
	local ok, err = pcall(function()
		print("[Drive] start", MM.start(STAGE, { shape = SHAPE }))
		waitText("동전 3개")
		task.wait(1.3)
		for _ = 1, 3 do
			tap(W(L.coin))
		end
		waitText("꾹 누르고")
		task.wait(0.9)
		hold(W(L.press), 2.0) -- 설탕 0.84 (초록 칸)
		inject(false, Pointer.pos)
		waitText("원을 그리며")
		task.wait(1.0)
		local ladle = W(L.burner) + Vector3.new(0, 0.25 * L.ladle, 0)
		stir(ladle, 7, "소다 통을 눌러", 40)
		task.wait(1.3)
		local half, shelfY = L.size.X * S / 2, L.shelfY * S
		local soda = O + Vector3.new(-half - 2, shelfY, -L.size.Z * S / 2 + 2.2) + Vector3.new(0, 1.2, 0)
		tap(soda)
		task.wait(0.3)
		tap(soda) -- 소다 2번 = 알맞음
		task.wait(0.3)
		tap(ladle)
		waitText("빠르게 저어요")
		task.wait(0.3)
		stir(ladle, 13, "금형판 칸 위로", 30)
		task.wait(1.3)
		local cavY = O.Y + L.cavY * S
		local cavs = {}
		for i, c in ipairs(L.cavs) do
			cavs[i] = Vector3.new(O.X + c.X * S, cavY, O.Z + c.Z * S)
		end
		for _, c in ipairs(cavs) do
			hold(Vector3.new(c.X, cavY + 0.8, c.Z), 1.34) -- 칸마다 약 100%
		end
		inject(false, Pointer.pos) -- 손을 떼야 붓기가 끝남
		waitText("막대를 꽂아요", 10)
		task.wait(1.3)
		for _, c in ipairs(cavs) do
			tap(c)
		end
	end)
	print("[Drive] finished", ok, err)
end)
return "driver running (출력창에서 [Drive]·[MachineMake] 줄을 봄)"
