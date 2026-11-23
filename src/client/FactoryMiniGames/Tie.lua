-- ⑤ 포장: 비닐 입구를 빵끈으로 묶기. 손 포장(Making/Pack)과 같은 조작: 한 번에 충분히(DRAG_PX) 옆으로 쓱 끌기 두 번
-- → 그 판 자동 포장 ×1.1 + 팁 +5%
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local new = UI.new

local Tie = { LIMIT = 5 }

local DRAG = 0.28 -- 한 번에 끌어야 하는 길이 (칸 폭 비율, 손 포장 DRAG_PX 110px과 비슷)
local NEED = 2
local TIE = Color3.fromRGB(226, 176, 52)

-- 손재주 (D49): 끌어야 하는 길이 ÷api.width, 2단계 = 끌 방향 화살표가 좌우로 움직이며 안내, 3단계 = 끌기 한 번.
-- 돌려줌: 잘했나, 점수 (묶은 수 / 필요한 수)
function Tie.run(area, api)
	local level, width = api.level or 1, api.width or 1
	local need = level >= 3 and 1 or NEED
	local drag = DRAG / width
	-- 비닐 봉투 (위 네모 + 아래 모인 입구) + 막대
	local bag = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.34, 0.5), BackgroundColor3 = Color3.fromRGB(248, 250, 255), BackgroundTransparency = 0.1, Parent = area }, { UI.corner(10), UI.stroke(Color3.fromRGB(180, 190, 205), 2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.7, 0.7), BackgroundColor3 = Color3.fromRGB(226, 160, 70), Parent = bag }, { UI.corner("round"), new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.03, 0.34), BackgroundColor3 = Color3.fromRGB(235, 215, 170), Parent = area })
	local wraps = {}
	for i = 1, need do
		wraps[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6 + (i - 1) * 0.05), Size = UDim2.fromScale(0.16, 0.035), BackgroundColor3 = TIE, Visible = false, ZIndex = 3, Parent = area }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 1) })
	end
	if level >= 2 then
		-- 방향 화살표: 비닐 입구 앞을 왼쪽 → 오른쪽으로 미끄러짐 (이렇게 끌면 됨)
		local hand = UI.text({ Text = "➜", TextSize = 30, TextColor3 = UI.C.red, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 5, Parent = area })
		task.spawn(function()
			local t = 0
			while hand.Parent do
				t += RunService.RenderStepped:Wait()
				local k = (t * 0.8) % 1
				hand.Position = UDim2.fromScale(0.3 + 0.4 * k, 0.66)
				hand.TextTransparency = k > 0.85 and (k - 0.85) / 0.15 or 0
			end
		end)
	end
	local arrow = UI.text({ Text = "← 쓱 →", TextSize = 18, TextColor3 = UI.C.soft, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.86), Size = UDim2.fromScale(1, 0.12), Parent = area })
	local p = api.pointer
	local presses = p.presses
	local startX = nil
	local done = 0
	while api.left() > 0 do
		RunService.RenderStepped:Wait()
		if p.down then
			local uv = api.uv(p.pos)
			if p.presses ~= presses or not startX then
				presses = p.presses
				startX = uv.X
			end
			if math.abs(uv.X - startX) >= drag then
				done += 1
				startX = uv.X -- 같은 누름에서 반대로 또 끌어도 한 번 더
				wraps[done].Visible = true
				arrow.Text = done < need and "한 번 더!" or ""
				if done >= need then
					-- 끈 끝이 양옆으로 뻗음
					new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.42, 0.6), Size = UDim2.fromScale(0.1, 0.025), Rotation = 20, BackgroundColor3 = TIE, ZIndex = 3, Parent = area })
					new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.58, 0.6), Size = UDim2.fromScale(0.1, 0.025), Rotation = -20, BackgroundColor3 = TIE, ZIndex = 3, Parent = area })
					api.hint("꽉 묶었어요!")
					task.wait(0.3)
					return true, 100
				end
			end
		else
			startX = nil
		end
	end
	return false, math.floor(done / need * 100)
end

return Tie
