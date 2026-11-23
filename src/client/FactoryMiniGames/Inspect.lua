-- ④ 식히기·검사: 벨트 위로 달고나가 지나감. 금 간 것 2개를 탭해서 집어냄 (멀쩡한 것을 2번 이상 집으면 실패) → 그 판 Poor 없음
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local new = UI.new

local Inspect = { LIMIT = 5 }

local N = 7 -- 지나가는 달고나 수
local CRACKED = 2
local GAP = 0.32 -- 달고나 사이 (칸 폭 비율)
local SPEED = 0.42 -- 칸 폭/초
local R = 0.07 -- 반지름 (칸 폭 비율)

function Inspect.run(area, api)
	new("Frame", { Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.44), BackgroundColor3 = Color3.fromRGB(90, 86, 82), Parent = area })
	-- 금 간 것 자리: 처음 둘은 빼고 고름 (볼 시간)
	local crackAt = {}
	while true do
		crackAt = {}
		local n = 0
		for i = 2, N do
			if n < CRACKED and math.random() < 0.35 then
				crackAt[i] = true
				n += 1
			end
		end
		if n == CRACKED then
			break
		end
	end
	local items = {}
	for i = 1, N do
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(R * 3, 0.25), BackgroundColor3 = Color3.fromRGB(226, 160, 70), ZIndex = 2, Parent = area }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 1.5), new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		if crackAt[i] then
			-- 금: 지그재그 선 두 개
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.45, 0.4), Size = UDim2.new(0.7, 0, 0, 3), Rotation = 35, BackgroundColor3 = UI.C.woodDark, BorderSizePixel = 0, ZIndex = 3, Parent = f })
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.6, 0.62), Size = UDim2.new(0.5, 0, 0, 3), Rotation = -40, BackgroundColor3 = UI.C.woodDark, BorderSizePixel = 0, ZIndex = 3, Parent = f })
		end
		items[i] = { f = f, cracked = crackAt[i] == true, x0 = -R - (i - 1) * GAP, gone = false }
	end
	local p = api.pointer
	local presses = p.presses
	local picked, wrong = 0, 0
	local x = 0
	while api.left() > 0 do
		local dt = RunService.RenderStepped:Wait()
		x += dt * SPEED
		local size = api.size()
		local aspect = size.Y > 0 and size.X / size.Y or 1
		for _, it in ipairs(items) do
			if not it.gone then
				it.f.Position = UDim2.fromScale(it.x0 + x, 0.52)
			end
		end
		if p.presses ~= presses then
			presses = p.presses
			local uv = api.uv(p.pos)
			local best, bd = nil, math.huge
			for _, it in ipairs(items) do
				if not it.gone then
					local d = Vector2.new(uv.X - (it.x0 + x), (uv.Y - 0.52) / aspect).Magnitude
					if d < bd then
						best, bd = it, d
					end
				end
			end
			if best and bd < R * 1.6 then
				best.gone = true
				if best.cracked then
					picked += 1
					best.f.Position = UDim2.fromScale(best.x0 + x, 0.15)
					best.f.BackgroundColor3 = UI.C.green
				else
					wrong += 1
					best.f.BackgroundColor3 = UI.C.red
					task.delay(0.25, function()
						best.f.Visible = false
					end)
					if wrong >= 2 then
						api.hint("멀쩡한 걸 너무 많이 골랐어요")
						task.wait(0.3)
						return false
					end
				end
				if picked >= CRACKED then
					api.hint("금 간 것만 쏙쏙!")
					task.wait(0.3)
					return true
				end
			end
		end
		-- 금 간 것이 벨트 끝을 지나가면 실패
		for _, it in ipairs(items) do
			if it.cracked and not it.gone and it.x0 + x > 1 + R then
				api.hint("금 간 게 지나갔어요")
				task.wait(0.3)
				return false
			end
		end
	end
	return false
end

return Inspect
