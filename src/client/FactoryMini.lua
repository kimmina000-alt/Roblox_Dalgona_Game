-- 공장 공정 미니게임 (D45, 2026-11-24 확정 안 B): 알바 없는 공정을 내가 맡으면 공장 한 판(100초)마다 3~5초짜리 미니게임이 한 번 뜸.
-- 잘하면 그 판만 효과가 조금 더 (서버가 정함). 못하거나 건너뛰어도 손해 없음.
--   ① sugar 저울 멈추기 · ② boil 솥 젓기(손 제작 Stir 판정) · ③ press 프레스 박자 탭 · ④ inspect 금 간 것 집기 · ⑤ pack 빵끈 묶기
-- 게임마다 모듈 하나: Client.FactoryMiniGames.<이름> → run(area, api) -> 잘했는지(boolean)
-- 서버 연결: Remotes[REMOTE.name] (RemoteEvent). 서버 → 나: FireClient(player, REMOTE.start, station, token)
--   나 → 서버: FireServer(REMOTE.result, token, ok). 이름은 저장·부지 세션과 맞춤 (바뀌면 REMOTE만 고침)
-- Studio 시험: Client.FactoryMini 모듈의 FactoryMini.play("sugar") 또는 BindableEvent Client.FactoryMiniTest:Fire("sugar")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local Pointer = require(script.Parent:WaitForChild("Making"):WaitForChild("Pointer"))
local GamesFolder = script.Parent:WaitForChild("FactoryMiniGames")

local FactoryMini = {}

FactoryMini.REMOTE = { name = "FactorySelf", start = "mini", result = "miniResult" }

-- 공정 → 게임 모듈 이름, 제목, 처음 안내
local GAMES = {
	sugar = { mod = "Scale", title = "① 설탕 넣기", hint = "바늘이 초록 칸에 올 때 탭!" },
	boil = { mod = "Stir", title = "② 끓이기", hint = "솥을 빙글빙글 저어요" },
	press = { mod = "Press", title = "③ 붓기·찍기", hint = "프레스가 내려올 때 탭! (3번)" },
	inspect = { mod = "Inspect", title = "④ 식히기·검사", hint = "금 간 달고나 2개를 집어내요" },
	pack = { mod = "Tie", title = "⑤ 포장", hint = "빵끈을 옆으로 쓱 두 번 끌어 묶어요" },
}
FactoryMini.GAMES = GAMES

local player = Players.LocalPlayer
local new = UI.new
local playing = false

function FactoryMini.isPlaying()
	return playing
end

-- 카드(설계 크기 380 x 300) 안 게임 칸(340 x 190)을 만듦
local W, H = 380, 300
local function buildGui(info)
	local gui = new("ScreenGui", {
		Name = "FactoryMini",
		ResetOnSpawn = false,
		IgnoreGuiInset = false, -- 손가락 좌표(Pointer)와 같은 기준 (Roblox 위 메뉴 줄 아래부터)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local fit = UI.fitter(root)
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = UI.C.wood,
		Parent = root,
	}, { UI.corner(18), UI.stroke(UI.C.woodDark, 3) })
	fit(card, W, H)
	UI.text({ Name = "Title", Text = info.title .. " · 내가 하기", TextSize = 22, TextColor3 = UI.C.white, Outline = UI.C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 6), Parent = card })
	local hint = UI.text({ Name = "Hint", Text = info.hint, TextSize = 17, TextColor3 = UI.C.cream, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 40), Parent = card })
	local area = new("Frame", {
		Name = "Area",
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.fromOffset(W - 40, 190),
		BackgroundColor3 = UI.C.cream,
		ClipsDescendants = true,
		Parent = card,
	}, { UI.corner(12), UI.stroke(UI.C.line, 2) })
	-- 남은 시간 막대
	local barBack = new("Frame", { Position = UDim2.fromOffset(20, 270), Size = UDim2.fromOffset(W - 40, 12), BackgroundColor3 = UI.C.woodInner, Parent = card }, { UI.corner("round") })
	local bar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.C.yellow, Parent = barBack }, { UI.corner("round") })
	-- 나타날 때 톡
	local sc = card:FindFirstChildOfClass("UIScale")
	if sc then
		local target = sc.Scale
		sc.Scale = target * 0.6
		TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
	end
	return gui, card, area, hint, bar
end

local function showResult(card, ok)
	local banner = UI.text({
		Text = ok and "잘했어요! 이번 판 효과 UP" or "아쉬워요 · 효과는 그대로",
		TextSize = 24,
		TextColor3 = UI.C.white,
		Outline = UI.C.woodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.9, 0, 0, 46),
		BackgroundTransparency = 0,
		BackgroundColor3 = ok and UI.C.green or UI.C.grey,
		ZIndex = 20,
		Parent = card,
	})
	UI.corner(14).Parent = banner
	UI.stroke(UI.C.woodDark, 2).Parent = banner
end

-- 미니게임 한 번. limit초 안에 끝남. 잘했으면 true
function FactoryMini.play(station, limit)
	local info = GAMES[station]
	if not info or playing then
		return false
	end
	local mod = GamesFolder:FindFirstChild(info.mod)
	if not mod then
		return false
	end
	-- 손 작업대에서 만드는 중이면 안 뜸 (그쪽이 손가락을 씀)
	if Pointer.enabled then
		return false
	end
	local game_ = require(mod)
	playing = true
	limit = limit or game_.LIMIT or 5
	local gui, card, area, hint, bar = buildGui(info)
	Pointer.enabled = true
	Pointer.down = false
	local t0 = os.clock()
	local api = {
		pointer = Pointer,
		limit = limit,
		-- 게임 칸 안 좌표 (0~1, 0~1). 칸 밖이면 범위를 넘는 값
		uv = function(pos)
			local p, s = area.AbsolutePosition, area.AbsoluteSize
			return Vector2.new((pos.X - p.X) / math.max(s.X, 1), (pos.Y - p.Y) / math.max(s.Y, 1))
		end,
		size = function()
			return area.AbsoluteSize
		end,
		hint = function(text)
			hint.Text = text
		end,
		-- 남은 시간 (초)
		left = function()
			return math.max(0, limit - (os.clock() - t0))
		end,
	}
	local barConn = RunService.RenderStepped:Connect(function()
		bar.Size = UDim2.fromScale(api.left() / limit, 1)
	end)
	local okRun, ok = pcall(game_.run, area, api)
	if not okRun then
		warn("[FactoryMini]", station, ok)
		ok = false
	end
	barConn:Disconnect()
	Pointer.enabled = false
	Pointer.down = false
	showResult(card, ok == true)
	task.wait(1.0)
	gui:Destroy()
	playing = false
	return ok == true
end

-- 서버 연결 (Remote가 아직 없으면 생길 때까지 기다리지 않고 지켜봄)
local function hookRemote(re)
	re.OnClientEvent:Connect(function(kind, station, token, limit)
		if kind ~= FactoryMini.REMOTE.start then
			return
		end
		task.spawn(function()
			local ok = FactoryMini.play(station, limit)
			re:FireServer(FactoryMini.REMOTE.result, token, ok)
		end)
	end)
end

function FactoryMini.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local re = remotes:FindFirstChild(FactoryMini.REMOTE.name)
	if re and re:IsA("RemoteEvent") then
		hookRemote(re)
	else
		local conn
		conn = remotes.ChildAdded:Connect(function(c)
			if c.Name == FactoryMini.REMOTE.name and c:IsA("RemoteEvent") then
				conn:Disconnect()
				hookRemote(c)
			end
		end)
	end
	if RunService:IsStudio() then
		local test = Instance.new("BindableEvent")
		test.Name = "FactoryMiniTest"
		test.Event:Connect(function(station)
			task.spawn(FactoryMini.play, station)
		end)
		test.Parent = script.Parent
	end
end

return FactoryMini
