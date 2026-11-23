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
local GrowthConfig = require(Shared:WaitForChild("GrowthConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Making = script.Parent:WaitForChild("Making")
local Pointer = require(Making:WaitForChild("Pointer"))
local Station = require(Making:WaitForChild("Station"))
local CameraRig = require(Making:WaitForChild("CameraRig"))
local Ui = require(Making:WaitForChild("Ui"))
local ChopstickPicker = require(Making:WaitForChild("ChopstickCup")) -- 2026-11-19: 포장 찢기 대신 젓가락 통에서 꺼내기
local CutterPicker = require(Making:WaitForChild("CutterPicker"))
local Sfx = require(Making:WaitForChild("Sfx"))
local Showcase = require(Making:WaitForChild("Showcase"))
local Pack = require(Making:WaitForChild("Pack"))
local Ppopgi = require(Making:WaitForChild("Ppopgi"))
local StepsFolder = Making:WaitForChild("Steps")

local STEP_MODULES = {}
for _, step in ipairs(Config.Steps) do
	local name = step.key:sub(1, 1):upper() .. step.key:sub(2)
	STEP_MODULES[step.key] = require(StepsFolder:WaitForChild(name))
end

local Workstations = require(Making:WaitForChild("Workstations"))
local Toon = require(Making:WaitForChild("Toon"))
-- 작업대 = 내 가게 작업대 (17b, 2026-11-21). 가게를 받으면 생기고, 다시 받으면 바뀜 → 아래 watchStation이 연결
local station = nil
require(Making:WaitForChild("HelperLadles")).start() -- 화로 위 알바생 국자 (LadleCount 2~4)
-- 가게 안 손 작업대는 내 화면에서 1/2로 줄여 보임 (저장·부지 세션 Making/ViewScale, 2026-11-22 사용자 "가게 안 손 제작대 1/2").
-- 만드는 동안만 내 작업대를 원래 크기로: 되돌리기(setUnturned) 전에 키우고, 다시 돌린 뒤에 줄임. 모듈이 없으면 아무 일 없음
local ViewScale = Making:FindFirstChild("ViewScale") and require(Making.ViewScale)
local function setFullSize(full)
	if ViewScale and station and station.model then
		ViewScale.setFull(station.model, full)
	end
end
require(Making:WaitForChild("Supplies")).start() -- 재료가 없으면 작업대 통이 빈 통으로 (2026-11-21)
local ui = Ui.new(player, Config.Steps)

local running = false
local roundsPlayed = 0 -- 이번 접속에서 시작한 판 수 (처음 SUB_ROUNDS판은 설명 글씨를 늘 보여 줌)
local SUB_ROUNDS = 2
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

-- 만드는 동안 카메라를 가리는 가게 천장·벽은 내 화면에서 숨김 (2026-11-22 "가게 안 제작 화면 분홍 단색")
local ViewClear = require(Making:WaitForChild("ViewClear"))
-- 노점 파라솔 (D21)이 위에서 내려다보는 제작 화면을 가림 → 만드는 동안 내 화면에서만 숨김 (2026-11-21)
local function setParasolHidden(hidden)
	if not hidden then
		ViewClear.stop() -- 먼저 되돌린 뒤 파라솔을 보이게 (반대 순서면 숨긴 채로 되돌려짐)
	end
	local plot = station and station.model.Parent
	if not plot then
		return
	end
	for _, name in ipairs({ "ParasolPole", "ParasolCanopy" }) do
		for _, p in ipairs(plot:GetDescendants()) do
			if p.Name == name and p:IsA("BasePart") then
				p.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
	if hidden then
		ViewClear.start(station.model)
	end
end

-- 작업대는 겉으로만 돌려 놓음 (2026-11-21 사용자 "작업대 눈에 보이는 것만 180도 돌리고 작업할 때 화면은 기존 그대로"):
-- 서버는 GrowthConfig.Plots.workstationTurn(도)만큼 돌려 놓고, 만드는 동안만 내 화면에서 작업대를 가운데 기준으로
-- 되돌려 예전 그대로의 제작 화면을 씀. 끝나면 다시 돌림 (다른 플레이어 화면은 그대로 돌린 모습)
local unturned = nil -- { model, c = 돌린 가운데, a = 각도 }
local function setUnturned(on)
	if not station then
		return
	end
	-- 가게 작업대(주인 속성이 있는 것)만 돌려 놓음. 새 배치 미리 보기 작업대는 안 돌림
	if on and not unturned and station.model:GetAttribute("OwnerUserId") ~= nil then
		local plots = GrowthConfig.Plots
		-- 2026-11-23 사용자 "손제작대 화면 배경 회전": 작업대를 내 화면에서 되돌리지 않음. 카메라(CameraRig)가 작업대 방향을
		-- 따라 반대편에서 보므로 도구 배치는 그대로이고, 배경(가게 바닥·길)만 실제 가게 방향대로 보임.
		-- 다시 되돌리려면 아래를 math.rad((plots and plots.workstationTurn) or 0) 으로
		local a = 0
		local _ = plots
		if a == 0 then
			return
		end
		local m = station.model
		-- 돌리는 가운데: 테이블 상판·다리(서버 부품)만으로 잰 상자 가운데. 작업대 전체 상자는 쓰지 않음 —
		-- 클라이언트가 만든 부품(숟가락 위 설탕 더미 HeapMound, 손, 효과)과 알바생 국자는 작업대가 가게 안↔밖으로
		-- 옮겨져도 옛 자리에 남아 가운데가 쏠림 (2026-11-22 "옮긴 뒤 테이블 자리 어긋남", 저장·부지 세션이 찾음)
		local mn, mx = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and (d.Name == "TableTop" or d.Name == "TableLeg") then
				-- 돌아간 부품의 축 정렬 상자 반폭
				local h, r = d.Size / 2, d.CFrame
				local rx, ry, rz = r.RightVector * h.X, r.UpVector * h.Y, r.LookVector * h.Z
				local ext = Vector3.new(
					math.abs(rx.X) + math.abs(ry.X) + math.abs(rz.X),
					math.abs(rx.Y) + math.abs(ry.Y) + math.abs(rz.Y),
					math.abs(rx.Z) + math.abs(ry.Z) + math.abs(rz.Z)
				)
				mn = mn:Min(d.Position - ext)
				mx = mx:Max(d.Position + ext)
			end
		end
		local c = mn.X < math.huge and CFrame.new((mn + mx) / 2) or CFrame.new((m:GetBoundingBox()).Position)
		local T = c * CFrame.Angles(0, -a, 0) * c:Inverse()
		m:PivotTo(T * m:GetPivot())
		unturned = { model = m, c = c, a = a, conns = {} }
		-- 서버가 만드는 동안 연탄(높이·새 연탄)을 바꾸면 서버의 돌린 자리 값이 내려와 내 화면의 되돌린 자세가 풀림 →
		-- 화로 부품의 CFrame이 서버에서 바뀌면 같은 만큼 다시 되돌림 (2026-11-22 "다시하기 누르면 연탄 위치 오류").
		-- 화로 부품은 클라이언트가 움직이지 않으므로 바뀌면 서버 값
		local brazier = m:FindFirstChild("Brazier")
		if brazier then
			-- 신호가 늦게 옴(Deferred): 내가 넣은 값에도 신호가 다시 와서 또 되돌리면 두 자리를 계속 오감 →
			-- 마지막으로 내가 넣은 값과 같으면 넘어감
			local mine = setmetatable({}, { __mode = "k" })
			local function fix(p)
				local last = mine[p]
				if last and (p.Position - last.Position).Magnitude < 1e-3 and p.CFrame.LookVector:Dot(last.LookVector) > 0.9999 then
					return
				end
				local cf = T * p.CFrame
				mine[p] = cf
				p.CFrame = cf
			end
			local function watch(p)
				if not p:IsA("BasePart") then
					return
				end
				mine[p] = mine[p] or p.CFrame -- 지금 값은 이미 되돌린 값
				table.insert(unturned.conns, p:GetPropertyChangedSignal("CFrame"):Connect(function()
					if unturned then
						fix(p)
					end
				end))
			end
			for _, d in ipairs(brazier:GetDescendants()) do
				watch(d)
			end
			table.insert(unturned.conns, brazier.DescendantAdded:Connect(function(d)
				if d:IsA("BasePart") and unturned then
					fix(d)
					watch(d)
				end
			end))
		end
		station = Station.new(m) -- 제자리(rest)를 돌리기 전 자세로 다시 잼
		CameraRig.init(m:GetPivot(), m)
	elseif not on and unturned then
		local u = unturned
		unturned = nil
		for _, cn in ipairs(u.conns or {}) do
			cn:Disconnect()
		end
		if u.model.Parent then
			u.model:PivotTo(u.c * CFrame.Angles(0, u.a, 0) * u.c:Inverse() * u.model:GetPivot())
			station = Station.new(u.model)
			CameraRig.init(u.model:GetPivot(), u.model)
		end
	end
end

local function finish()
	running = false
	setParasolHidden(false)
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
	if station then
		station:reset()
		station:removeHand()
		setUnturned(false) -- 제자리로 되돌린 뒤 다시 겉모습대로 돌림
		setFullSize(false)
		station.Prompt.Enabled = true
	end
	-- 손으로 만든 달고나는 직접 진열 (2026-11-21): 들고 있으면 진열대로 안내 (서버 속성 Carrying = 들고 있는 달고나 번호)
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "number" and carrying ~= 0 then
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", { Title = "달고나 진열", Text = "진열대 빈 칸에서 R을 눌러 놓아요", Duration = 6 })
		end)
	end
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
	roundsPlayed += 1
	ui:setSubAlways(roundsPlayed <= SUB_ROUNDS)
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

	-- 재료가 모자라면 나무젓가락을 꺼내기 전에 상점으로 안내 (2026-11-20 젓가락, 2026-11-21 모든 재료:
	-- "젓가락 쪼갰는데 다른 재료 없어서 못 만들면 젓가락 소진 안 되게" → 쪼개기 전에 확인)
	do
		local need = GrowthConfig.recipe(shape.grade)
		need.chopsticks = GrowthConfig.ChopsticksPerRound or 1
		local function missingList()
			local missing, first = {}, nil
			for _, ing in ipairs(GrowthConfig.Ingredients) do
				local n = need[ing.id] or 0
				local have = player:GetAttribute("Ing_" .. ing.id)
				if ing.id == "chopsticks" and have == nil then
					have = player:GetAttribute("Chopsticks")
				end
				if n > 0 and have ~= nil and have < n then
					table.insert(missing, string.format("%s %d", ing.name, n))
					first = first or ing.id
				end
			end
			return missing, first
		end
		local missing, first = missingList()
		if #missing > 0 then
			-- 상점을 연 채로 기다렸다가, 사서 재료가 다 차면 상점을 닫고 그대로 이어서 만듦 (2026-11-23 사용자
			-- "재료 부족할 때 상점에서 바로 사면 창 닫히지 않고 그대로 제작 이어지게"). 상점을 그냥 닫으면 예전처럼 끝냄
			local hud = script.Parent:FindFirstChild("Hud")
			local open = hud and hud:FindFirstChild("OpenShop")
			local shopGui = player.PlayerGui:FindFirstChild("ShopHud")
			local shopWin = shopGui and shopGui:FindFirstChild("Shop", true)
			ui:say("재료가 모자라요", table.concat(missing, ", ") .. " 필요 · 상점에서 사면 바로 이어서 만들어요")
			if open then
				open:Fire(first)
			end
			task.wait(0.3)
			while true do
				if ctx.aborted then
					if shopWin then
						shopWin.Visible = false
					end
					return
				end
				if #(missingList()) == 0 then
					if shopWin then
						shopWin.Visible = false
					end
					ui:say("재료가 다 모였어요", "이어서 만들어요")
					task.wait(0.8)
					break
				end
				if not shopWin or not shopWin.Visible then
					-- 사지 않고 상점을 닫음 → 끝냄
					finish()
					return
				end
				task.wait(0.2)
			end
		end
	end
	-- 0. 나무젓가락 꺼내기 (통을 누르면 한 짝이 뽑혀 테이블 위에 놓임)
	CameraRig.go("pick") -- 테이블 왼쪽 끝 젓가락 쪽으로
	local pick = ChopstickPicker.run(ctx)
	if ctx.aborted or not pick then
		return
	end
	station:useChopstick(pick.pair, pick.side)
	-- 국자 잡은 손은 안 붙임 (2026-11-20 사용자 요청 "국자 잡은 손 삭제")
	ctx.state.chopstick = pick

	local okStart, sessionId, why = pcall(function()
		return Remotes.StartProduction:InvokeServer(shape.id)
	end)
	if okStart and not sessionId and type(why) == "string" then
		-- 재료 부족·보관함 가득 (저장·가게, 2026-11-20): 이유를 보여 주고 끝냄
		ui:say(why, "")
		task.wait(2.5)
		finish()
		return
	end
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
		Sfx.play("stepDone", 0.45) -- 단계 끝 "띵"
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
	result.details = Scoring.explain(ctx.records)
	-- 결과를 보고 포장할지 고름 (2026-11-20) → 포장하면 테이블 오른쪽 포장 공간에서 비닐·빵끈 →
	-- 다 만든 달고나(포장했으면 포장째)를 화면 정중앙에 크게 → 완성 창
	if dal and not result.burnt then
		-- 모양 단계에서 "포장하기"를 눌렀으면 (모양 안 찍음, 2026-11-20) 묻지 않고 바로 포장
		local stampRec = ctx.records.stamp
		-- 7. 뽑기 (선택, 15번): 모양을 찍었으면 도전할지 고름. 순서 = 뽑기 → 포장. 쪼개지면 포장 못 함
		local packDirect = false -- 뽑기 대신 "포장하기"를 골랐으면 포장할지 다시 묻지 않음
		local canPpopgi = not result.misshaped and ctx.state.stampRoot ~= nil and not (stampRec and stampRec.packNow)
			and (result.ppopgiOk or not result.verified)
		if canPpopgi then
			-- 2026-11-22 사용자: "그만하고 넘어가기" 대신 "포장하기" → 고르면 묻지 않고 바로 포장
			local pask = ui:ask(string.format("%s · 완성도 %d%%", result.grade, result.Q), "뽑기에 도전할까요? 바늘로 점선을 긁어 모양을 떼어 내요 · 성공하면 달고나 하나 덤 (완벽하면 2개)", "뽑기 도전", "포장하기")
			while not pask.choice do
				if not ctx.frame() then
					pask.close()
					return
				end
			end
			packDirect = pask.choice == 2
			if pask.choice == 1 then
				local out = Ppopgi.run(ctx, dal, shape.id)
				if ctx.aborted then
					return
				end
				if out then
					local pres = out.res
					if result.verified then
						local okP, server = pcall(function()
							return Remotes.SubmitPpopgi:InvokeServer({ samples = out.samples, quit = out.quit })
						end)
						if okP and type(server) == "table" and server.ok then
							pres = server
							pres.verified = true
						else
							warn("[Making] ppopgi rejected:", okP and server and server.reason or server)
						end
					end
					pres.quit = out.quit
					result.ppopgi = pres
					if pres.price then
						result.price = pres.price
					end
				end
				CameraRig.go("result")
			end
		end
		local ask = { choice = 1 }
		if result.ppopgi and result.ppopgi.broken then
			ask = { choice = 2 } -- 쪼개진 달고나는 포장 안 함
		elseif not (stampRec and stampRec.packNow) and not packDirect then
			ask = ui:ask(string.format("%s · 완성도 %d%%", result.grade, result.Q), "포장할까요? 비닐에 넣고 빵끈으로 묶어요", "포장하기", "그냥 두기")
			while not ask.choice do
				if not ctx.frame() then
					ask.close()
					return
				end
			end
		end
		local extras = nil
		if ask.choice == 1 then
			-- 포장지·빵끈은 포장할 때 씀 (2026-11-20): 서버가 재료를 확인하고 판매가 ×1.1
			local okPack, packRes = pcall(function()
				return Remotes.PackDalgona:InvokeServer()
			end)
			if okPack and type(packRes) == "table" and not packRes.ok and packRes.reason ~= "no item" then
				ui:say(tostring(packRes.reason), "상점에서 사 와요 · 이번엔 포장 없이 끝나요")
				task.wait(2)
				ask.choice = 2
			end
		end
		if ask.choice == 1 then
			extras = Pack.run(ctx, dal, ctx.state)
			if ctx.aborted or not extras then
				return
			end
		end
		Showcase.run(ctx, dal, ctx.state, extras)
		if ctx.aborted then
			return
		end
	end
	if result.stars >= 2 and not result.burnt and not result.misshaped then
		Sfx.play("fanfare", 0.5)
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
	if result.ppopgi then
		local pp = result.ppopgi
		print(string.format("[Making] ppopgi cov=%.2f cracks=%d acc=%.2f broken=%s perfect=%s extra=%d verified=%s", pp.coverage or 0, pp.cracks or 0, pp.acc or 0, tostring(pp.broken), tostring(pp.perfect), pp.extraAdded or pp.extra or 0, tostring(pp.verified)))
	end
	print(string.format("[Making] result %s Q=%d %s price=%s stars=%d (verified=%s) sugar=%s melt=%s soda=%s pour=%s press=%s stamp=%s", shape.id, result.Q, result.grade, tostring(result.price), result.stars, tostring(result.verified), tostring(s.sugar), tostring(s.melt), tostring(s.soda), tostring(s.pour), tostring(s.press), tostring(s.stamp)))
end

function startMaking(restart)
	if running and not restart then
		return
	end
	if not station then
		return -- 가게(작업대)를 아직 못 받음
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
	setFullSize(true)
	setUnturned(true)
	-- 작업대는 연결된 뒤에도 서버가 옮길 수 있음 (노점 HandStationSpot ↔ 가게 안 HandStationInside, 두 자리 방향이 다를 수 있음).
	-- 연결 때 잰 자리·방향을 그대로 쓰면 제작 화면이 돌아가 보임 (2026-11-24 "밖에서 본 손제작대랑 화면이랑 둘 다 거꾸로")
	-- → 만들기를 시작할 때마다 지금 자리로 다시 잼
	-- 다시 재기 전에 지난 판 모습(탄 국자 내용물, 고른 젓가락 등)을 먼저 되돌림: 안 그러면 탄 모습을 원래 모습으로 잼
	-- (2026-11-24 "태워서 다시 도전하면 탄 국자랑 오른쪽에 검은색")
	if not unturned and station.model.Parent then
		station:reset(true)
		station = Station.new(station.model)
		station.Prompt.Enabled = false
		CameraRig.init(station.model:GetPivot(), station.model)
	end
	setParasolHidden(true)
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

-- 내 가게 작업대 연결 (17b): 작업대가 생기거나 바뀌면 Station을 새로 만듦 (만드는 중에는 안 바꿈).
-- 다른 가게 작업대의 E는 내 화면에서 끔. 가게를 아직 못 받았으면 한 번 안내
local function bindStation(m)
	station = Station.new(m)
	Toon.apply(m) -- 도구 만화 외곽선
	CameraRig.init(m:GetPivot(), m)
	station.Prompt.Triggered:Connect(function()
		task.spawn(startMaking, false)
	end)
end
-- 새 배치 미리 보기 작업대(WorkstationPreviewV3, 2026-11-21)에서도 만들 수 있게: 그 E를 누르면 잠깐 그 작업대로 연결.
-- 다 만들면 아래 감시가 다시 내 가게 작업대로 연결함 (만드는 중에는 안 바꿈)
local previewHooked = setmetatable({}, { __mode = "k" })
local function hookPreview()
	local prev = workspace:FindFirstChild("WorkstationPreviewV3")
	local top = prev and prev:FindFirstChild("TableTop")
	local att = top and top:FindFirstChild("PromptAtt")
	local prompt = att and att:FindFirstChild("MakePrompt")
	if prompt and not previewHooked[prompt] and Workstations.ready(prev) then
		previewHooked[prompt] = true
		prompt.Triggered:Connect(function()
			if running then
				return
			end
			local ok, err = pcall(function()
				station = Station.new(prev)
				Toon.apply(prev)
				CameraRig.init(prev:GetPivot(), prev)
			end)
			if ok then
				task.spawn(startMaking, false)
			else
				warn("[Making] preview bind failed:", err)
			end
		end)
	end
end
task.spawn(function()
	local told = false
	local since = os.clock()
	while true do
		local mine = Workstations.mine()
		if not running then
			if mine and Workstations.ready(mine) and (not station or station.model ~= mine) then
				local ok, err = pcall(bindStation, mine)
				if not ok then
					warn("[Making] workstation bind failed:", err)
					station = nil
				end
			elseif station and not station.model.Parent then
				station = nil -- 가게를 비움
			end
		end
		for _, ws in ipairs(Workstations.all()) do
			if ws ~= mine then
				local top = ws:FindFirstChild("TableTop")
				local att = top and top:FindFirstChild("PromptAtt")
				local prompt = att and att:FindFirstChild("MakePrompt")
				if prompt and prompt.Enabled then
					prompt.Enabled = false
				end
			end
		end
		hookPreview()
		if not mine and not told and os.clock() - since > 8 then
			told = true
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", { Title = "달고나 골목", Text = "가게를 받으면 내 작업대에서 만들 수 있어요", Duration = 6 })
			end)
		end
		task.wait(1)
	end
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
	-- 왼쪽 구역 옆 조작 (국자 높이) 주입: Fire(down, x, y)
	local testSide = Instance.new("BindableEvent")
	testSide.Name = "TestSide"
	testSide.Parent = script
	testSide.Event:Connect(function(down, x, y)
		local pos = Vector2.new(x, y)
		if down then
			if Pointer.side.down then
				Pointer.side.delta += pos - Pointer.side.pos
			else
				Pointer.side.start = pos
			end
			Pointer.side.down = true
			Pointer.side.pos = pos
		else
			Pointer.side.down = false
		end
	end)
end
