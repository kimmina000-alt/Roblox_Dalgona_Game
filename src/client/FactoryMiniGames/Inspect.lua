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

-- 손재주 (D49): 집는 범위 ×api.width, 지나가는 속도 2단계 −15% · 3단계 −25%, 2단계부터 금 간 것이 반짝임,
-- 3단계는 1개만 집어도 절반 점수. 돌려줌: 잘했나, 점수 (집은 수 / 2, 잘못 집으면 −25)
local function score(picked, wrong)
	return math.max(0, math.floor(picked / CRACKED * 100 - wrong * 25))
end

function Inspect.run(area, api)
	local level, width = api.level or 1, api.width or 1
	local speed = SPEED * (level >= 3 and 0.75 or level >= 2 and 0.85 or 1)
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
		if crackAt[i] and level >= 2 then
			-- 반짝임: 금 간 달고나 테두리가 금색으로 깜빡임
			local glow = new("UIStroke", { Color = UI.C.gold, Thickness = 3, Transparency = 0.2, Parent = f })
			task.spawn(function()
				local t = 0
				while glow.Parent do
					t += RunService.RenderStepped:Wait()
					glow.Transparency = 0.15 + 0.6 * (math.sin(t * 9) + 1) / 2
				end
			end)
		end
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
		x += dt * speed
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
			if best and bd < R * 1.6 * width then
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
						return false, score(picked, wrong)
					end
				end
				if picked >= CRACKED then
					api.hint("금 간 것만 쏙쏙!")
					task.wait(0.3)
					return true, score(picked, wrong)
				end
			end
		end
		-- 금 간 것이 벨트 끝을 지나가면 실패
		for _, it in ipairs(items) do
			if it.cracked and not it.gone and it.x0 + x > 1 + R then
				api.hint("금 간 게 지나갔어요")
				task.wait(0.3)
				return false, level >= 3 and score(picked, wrong) or 0
			end
		end
	end
	return false, level >= 3 and score(picked, wrong) or 0
end

return Inspect
