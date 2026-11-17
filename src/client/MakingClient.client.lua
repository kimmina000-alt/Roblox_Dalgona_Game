-- 달고나 제작 화면 진입점 (Phase 1 프로토타입)
-- 작업대 앞에서 E(폰은 버튼) → 도안 고르기 → 나무젓가락 → 6단계: 설탕 → 녹이기 → 소다 → 붓기 → 누르기 → 모양 → 결과
-- 단계마다 모듈 하나 (Making/Steps). 점수는 서버가 입력 기록으로 다시 계산한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Making = script.Parent:WaitForChild("Making")
local Pointer = require(Making:WaitForChild("Pointer"))
local Station = require(Making:WaitForChild("Station"))
local CameraRig = require(Making:WaitForChild("CameraRig"))
local Ui = require(Making:WaitForChild("Ui"))
local ChopstickPicker = require(Making:WaitForChild("ChopstickPicker"))
local CutterPicker = require(Making:WaitForChild("CutterPicker"))
local StepsFolder = Making:WaitForChild("Steps")

local STEP_MODULES = {}
for _, step in ipairs(Config.Steps) do
	local name = step.key:sub(1, 1):upper() .. step.key:sub(2)
	STEP_MODULES[step.key] = require(StepsFolder:WaitForChild(name))
end

local station = Station.new()
local ui = Ui.new(player, Config.Steps)
CameraRig.init(station.model:GetPivot())

local running = false
local current = nil -- 지금 진행 중인 ctx
local shape = ShapeCatalog.get(ShapeCatalog.default) -- 고른 도안 (다시 하기는 같은 도안)
local pickShape = true -- 다음 판 시작 때 도안 고르기 화면을 띄울지

-- 제작 중에는 캐릭터가 움직이지 않게 (PlayerModule이 없는 환경도 있어서 속도도 0으로)
local savedSpeed = nil
local function setControls(enabled)
	local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
	if pm then
		local ok, controls = pcall(function()
			return require(pm):GetControls()
		end)
		if ok and controls then
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end
	-- 폰: 조이스틱과 점프 버튼은 제작 중에 숨김
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	if touchGui then
		touchGui.Enabled = enabled
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		if enabled then
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

local function setCharacterHidden(hidden)
	local char = player.Character
	if not char then
		return
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function finish()
	running = false
	if current then
		current.aborted = true
		current = nil
	end
	Pointer.enabled = false
	Pointer.reset()
	ui:show(false)
	CameraRig.release()
	setControls(true)
	setCharacterHidden(false)
	station:reset()
	station.Prompt.Enabled = true
end

local startMaking

local function runSession()
	local ctx = {
		station = station,
		pointer = Pointer,
		ui = ui,
		state = {},
		records = {},
		scores = {},
		aborted = false,
	}
	current = ctx
	function ctx.now()
		return workspace:GetServerTimeNow()
	end
	function ctx.frame()
		local dt = RunService.RenderStepped:Wait()
		if ctx.aborted then
			return nil
		end
		ui:tick()
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

	station:reset()
	ui:hideResult()
	ui:setQuality(100, Config.StarCut)
	ui:show(true)
	Pointer.reset()
	Pointer.enabled = true

	-- 0. 도안 고르기 (처음 시작, 또는 결과 화면의 "다른 도안")
	ui:setStep(1)
	CameraRig.go("sugar")
	if pickShape then
		local picked = CutterPicker.run(ctx, shape.id)
		if ctx.aborted or not picked then
			return
		end
		shape = picked
		pickShape = false
	end
	station:setCutter(shape.id)
	ctx.state.shape = shape

	-- 0. 나무젓가락 고르기 (포장지 찢기 → 꺼내기 → 쪼개기 → 한 짝 고르기)
	local pick = ChopstickPicker.run(ctx)
	if ctx.aborted or not pick then
		return
	end
	station:useChopstick(pick.pair, pick.side)
	ctx.state.chopstick = pick

	local okStart, sessionId = pcall(function()
		return Remotes.StartProduction:InvokeServer(shape.id)
	end)
	if not okStart or not sessionId then
		task.wait(1)
		okStart, sessionId = pcall(function()
			return Remotes.StartProduction:InvokeServer(shape.id)
		end)
	end

	-- 0. 준비 (자동): 철판에 설탕 원을 깔아 둠
	ui:setStep(1)
	CameraRig.go("sugar")
	ui:say("철판에 설탕 원을 깔아 뒀어요", "준비 완료!")
	local t = 0
	while t < 0.5 do
		local dt = ctx.frame()
		if not dt then
			return
		end
		t += dt
	end

	for i, step in ipairs(Config.Steps) do
		ui:setStep(i)
		if i > 1 then
			CameraRig.go(step.key)
		end
		local rec = STEP_MODULES[step.key].run(ctx)
		if ctx.aborted or not rec then
			return
		end
		ctx.records[step.key] = rec
		ctx.scores[step.key] = Scoring[step.key](rec)
		ui:setQuality(Scoring.live(ctx.scores), Config.StarCut)
		if (rec.burnt or ctx.state.burntLate) then
			break
		end
		-- 단계 사이 짧은 숨 (성공 피드백이 보이게)
		local w = 0
		while w < 0.35 do
			local dt = ctx.frame()
			if not dt then
				return
			end
			w += dt
		end
	end

	-- 결과: 클라이언트 미리 보기 → 서버 판정으로 덮어씀
	local preview = Scoring.compute(ctx.records, shape)
	local result = preview
	if okStart and sessionId then
		local ok, server = pcall(function()
			return Remotes.SubmitProduction:InvokeServer(sessionId, ctx.records)
		end)
		if ok and type(server) == "table" and server.ok then
			result = server
			result.verified = true
		else
			warn("[Making] server rejected:", ok and server and server.reason or server)
		end
	end
	if ctx.aborted then
		return
	end
	ui:setStep(#Config.Steps + 1)
	ui:setQuality(result.Q, Config.StarCut)
	CameraRig.go("result")
	local dal = ctx.state.dalgona
	if result.grade == "Perfect" and dal then
		dal:sparkle()
	end
	if result.burnt then
		station:setContents({ Color = Color3.fromRGB(24, 16, 12), Transparency = 0, Material = Enum.Material.Slate })
		CameraRig.go("melt")
	end
	ui:say(string.format("%s · 완성도 %d%%", result.grade, result.Q), "")
	Pointer.enabled = false
	ui:showResult(result, shape, {
		retry = function()
			ui:hideResult()
			task.spawn(startMaking, true)
		end,
		other = function()
			ui:hideResult()
			pickShape = true
			task.spawn(startMaking, true)
		end,
		leave = function()
			finish()
		end,
	})
	current = nil
	local s = result.steps or {}
	print(string.format("[Making] result %s Q=%d %s price=%s stars=%d (verified=%s) sugar=%s melt=%s soda=%s pour=%s press=%s stamp=%s", shape.id, result.Q, result.grade, tostring(result.price), result.stars, tostring(result.verified), tostring(s.sugar), tostring(s.melt), tostring(s.soda), tostring(s.pour), tostring(s.press), tostring(s.stamp)))
end

function startMaking(restart)
	if running and not restart then
		return
	end
	if current then
		current.aborted = true
		current = nil
	end
	if not restart then
		pickShape = true -- 작업대에 새로 앉으면 도안부터 고름
	end
	running = true
	station.Prompt.Enabled = false
	setControls(false)
	setCharacterHidden(true)
	local ok, err = pcall(runSession)
	if not ok then
		warn("[Making] error:", err)
		finish()
	end
end

ui.onExit = function()
	finish()
end

station.Prompt.Triggered:Connect(function()
	task.spawn(startMaking, false)
end)

-- 테스트용: 다른 스크립트(또는 Studio 명령)에서 시작할 수 있게
local bindable = Instance.new("BindableEvent")
bindable.Name = "StartMaking"
bindable.Parent = script
bindable.Event:Connect(function()
	task.spawn(startMaking, false)
end)

-- Studio 자동 테스트용 입력 주입 (실제 서버에서는 만들지 않음): Fire(down, x, y)
if RunService:IsStudio() then
	local testPointer = Instance.new("BindableEvent")
	testPointer.Name = "TestPointer"
	testPointer.Parent = script
	testPointer.Event:Connect(function(down, x, y)
		if not Pointer.enabled then
			return
		end
		Pointer.pos = Vector2.new(x, y)
		if down and not Pointer.down then
			Pointer.down = true
			Pointer.downPos = Pointer.pos
			Pointer.downTime = os.clock()
			Pointer.presses += 1
		elseif not down and Pointer.down then
			Pointer.down = false
			Pointer.upTime = os.clock()
			Pointer.releases += 1
		end
	end)
end
