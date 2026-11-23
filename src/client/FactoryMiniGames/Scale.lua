-- ① 설탕 넣기: 저울 바늘이 왼쪽↔오른쪽을 오가고, 초록 칸에 왔을 때 탭해서 멈추기 (한 번). 잘하면 그 판 설탕 −20%
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local new = UI.new

local Scale = { LIMIT = 4 }

local SPEED = 0.9 -- 바늘 왕복 (번/초)
local ZONE = 0.16 -- 초록 칸 폭 (눈금판 비율)

-- 손재주 (D49): 초록 칸 폭 ×api.width, 2단계 = 바늘이 느려짐(×0.7), 3단계 = 초록 칸 안에서 바늘이 머뭇거림(그 안에선 ×0.35)
-- 돌려줌: 잘했나, 점수 (초록 칸 안 100, 벗어난 만큼 깎임)
function Scale.run(area, api)
	local level, width = api.level or 1, api.width or 1
	local zoneW = math.min(0.5, ZONE * width)
	local speed = SPEED * (level >= 2 and 0.7 or 1)
	-- 눈금판
	local dial = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.86, 0.34), BackgroundColor3 = Color3.fromRGB(250, 236, 210), Parent = area }, { UI.corner(10), UI.stroke(UI.C.woodDark, 2) })
	local z0 = 0.1 + math.random() * (0.8 - zoneW)
	new("Frame", { Position = UDim2.fromScale(z0, 0), Size = UDim2.fromScale(zoneW, 1), BackgroundColor3 = UI.C.green, BackgroundTransparency = 0.15, Parent = dial }, { UI.corner(6) })
	for i = 0, 10 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 10, 0), Size = UDim2.new(0, 2, 0.3, 0), BackgroundColor3 = UI.C.woodDark, BorderSizePixel = 0, Parent = dial })
	end
	UI.text({ Text = "설탕 저울", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.05), Size = UDim2.fromScale(1, 0.18), Parent = area })
	local needle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 6, 1.5, 0), BackgroundColor3 = UI.C.red, ZIndex = 3, Parent = dial }, { UI.corner(3), UI.stroke(UI.C.woodDark, 1.5) })
	local p = api.pointer
	local presses = p.presses
	local ph = math.random() * math.pi * 2 -- 바늘 위상 (머뭇거림을 위해 속도를 바꿔 가며 직접 쌓음)
	local x = 0
	while api.left() > 0 do
		local dt = RunService.RenderStepped:Wait()
		local inZone = x >= z0 and x <= z0 + zoneW
		ph += dt * speed * math.pi * 2 * ((level >= 3 and inZone) and 0.35 or 1)
		x = (math.sin(ph - math.pi / 2) + 1) / 2 -- 0~1 왕복
		needle.Position = UDim2.fromScale(x, 0.5)
		if p.presses ~= presses then
			-- 멈춤: 초록 칸 안이면 성공
			local ok = x >= z0 and x <= z0 + zoneW
			local off = ok and 0 or math.min(math.abs(x - z0), math.abs(x - (z0 + zoneW)))
			needle.BackgroundColor3 = ok and UI.C.good or UI.C.bad
			api.hint(ok and "딱 맞아요!" or "조금 빗나갔어요")
			task.wait(0.35)
			return ok, ok and 100 or math.max(0, math.floor(100 - off * 400))
		end
	end
	return false, 0
end

return Scale
