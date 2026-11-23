-- ③ 붓기·찍기: 프레스가 일정 박자로 내려와 달고나를 찍음. 바닥에 닿는 순간에 맞춰 탭 3번 성공하면 → 그 판 시간 −15%
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local new = UI.new

local Press = { LIMIT = 5 }

local BEAT = 0.85 -- 한 번 내려왔다 올라가는 시간 (초)
local WINDOW = 0.15 -- 바닥에 닿는 순간 앞뒤로 이만큼 안이면 맞음 (초)
local NEED = 3

function Press.run(area, api)
	-- 벨트 + 달고나 + 프레스
	new("Frame", { Position = UDim2.fromScale(0.05, 0.78), Size = UDim2.fromScale(0.9, 0.1), BackgroundColor3 = UI.C.woodInner, Parent = area }, { UI.corner(4) })
	local dal = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.2, 0.1), BackgroundColor3 = Color3.fromRGB(226, 160, 70), Parent = area }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 1.5) })
	local head = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.26, 0.2), BackgroundColor3 = UI.C.yellow, ZIndex = 3, Parent = area }, { UI.corner(6), UI.stroke(UI.C.woodDark, 2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 8, 2, 0), BackgroundColor3 = UI.C.grey, Parent = head })
	local dots = {}
	for i = 1, NEED do
		dots[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.82 + (i - 2) * 0.07, 0.12), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = UI.C.tan, Parent = area }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 1.5) })
	end
	local p = api.pointer
	local presses = p.presses
	local t = -0.4 -- 처음 조금 기다렸다 시작
	local hits = 0
	local usedBeat = -1
	while api.left() > 0 do
		local dt = RunService.RenderStepped:Wait()
		t += dt
		local beat = math.floor(math.max(t, 0) / BEAT)
		local ph = (math.max(t, 0) % BEAT) / BEAT -- 0 = 위, 0.5 = 바닥, 1 = 위
		local down = math.sin(ph * math.pi) -- 0~1
		head.Position = UDim2.fromScale(0.5, 0.2 + 0.48 * down)
		dal.Size = UDim2.fromScale(0.2 + 0.04 * math.max(0, down - 0.9) * 10, 0.1)
		if p.presses ~= presses then
			presses = p.presses
			local off = math.abs(ph - 0.5) * BEAT -- 바닥 순간에서 떨어진 시간
			if t >= 0 and off <= WINDOW and beat ~= usedBeat then
				usedBeat = beat
				hits += 1
				dots[hits].BackgroundColor3 = UI.C.green
				if hits >= NEED then
					api.hint("박자 딱딱!")
					task.wait(0.3)
					return true
				end
			else
				head.BackgroundColor3 = UI.C.red
				task.delay(0.15, function()
					head.BackgroundColor3 = UI.C.yellow
				end)
			end
		end
	end
	return false
end

return Press
