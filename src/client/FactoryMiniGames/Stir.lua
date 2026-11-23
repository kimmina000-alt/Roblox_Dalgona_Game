-- ② 끓이기: 솥을 원 그리며 젓기. 손 제작 녹이기와 같은 판정(Making/Stir, DalgonaConfig.Melt slow·fast)을 씀:
-- 적당한 빠르기(JUST RIGHT)로 저은 만큼 채워지고, 너무 빠르면 절반만. 정해진 양(3바퀴)을 채우면 성공 → 그 판 품질 +25%
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaConfig"))
local StirJudge = require(script.Parent.Parent:WaitForChild("Making"):WaitForChild("Stir"))
local new = UI.new

local Stir = { LIMIT = 5 }

local GOAL = math.pi * 2 * 3 -- 3바퀴 (라디안)
local ZONE_GAIN = { 0, 1, 0.5 } -- 느림 / 적당 / 빠름

-- 손재주 (D49): 빠르기 판정 폭 ×api.width (느림 경계 ÷, 빠름 경계 ×), 2단계 = 솥 위 원 안내선(따라 그리는 길),
-- 3단계 = 바퀴 수 −1 (3 → 2바퀴). 돌려줌: 잘했나, 점수 (채운 양 %)
function Stir.run(area, api)
	local level, width = api.level or 1, api.width or 1
	local goal = GOAL - (level >= 3 and math.pi * 2 or 0)
	local pot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.36, 0.52), Size = UDim2.fromScale(0.42, 0.75), BackgroundColor3 = Color3.fromRGB(170, 70, 50), Parent = area }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 3), new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), BackgroundColor3 = Color3.fromRGB(232, 170, 70), Parent = pot }, { UI.corner("round") })
	if level >= 2 then
		-- 원 안내선: 솥 가운데 둘레의 점선 고리 + 도는 화살 (이 길을 따라 저으면 됨)
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundTransparency = 1, ZIndex = 3, Parent = pot }, { UI.corner("round"), new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3, Transparency = 0.25 }) })
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = UI.C.yellow, ZIndex = 4, Parent = ring }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 1.5) })
		task.spawn(function()
			local a = 0
			while dot.Parent do
				a += RunService.RenderStepped:Wait() * 4
				dot.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5)
			end
		end)
	end
	local spoon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.fromRGB(230, 200, 150), Visible = false, ZIndex = 4, Parent = area }, { UI.corner("round"), UI.stroke(UI.C.woodDark, 2) })
	-- 오른쪽: 빠르기 표시 + 채운 양
	local speedL = UI.text({ Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.62, 0.12), Size = UDim2.fromScale(0.36, 0.2), Parent = area })
	local back = new("Frame", { Position = UDim2.fromScale(0.66, 0.4), Size = UDim2.fromScale(0.28, 0.16), BackgroundColor3 = UI.C.tan, Parent = area }, { UI.corner("round"), UI.stroke(UI.C.line, 2) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.C.green, Parent = back }, { UI.corner("round") })
	local judge = StirJudge.new()
	local cfg = { slow = Config.Melt.slow / width, fast = Config.Melt.fast * width }
	local p = api.pointer
	local done = 0
	while api.left() > 0 do
		local dt = RunService.RenderStepped:Wait()
		local speed = judge:update(dt)
		local zone = StirJudge.zone(speed, cfg.slow, cfg.fast)
		if p.down then
			local uv = api.uv(p.pos)
			spoon.Visible = true
			spoon.Position = UDim2.fromScale(math.clamp(uv.X, 0, 1), math.clamp(uv.Y, 0, 1))
			done += speed * dt * ZONE_GAIN[zone]
		else
			spoon.Visible = false
		end
		speedL.Text = (not p.down and "") or ({ "느려요", "딱 좋아요", "너무 빨라요" })[zone]
		speedL.TextColor3 = zone == 2 and UI.C.good or UI.C.bad
		fill.Size = UDim2.fromScale(math.clamp(done / goal, 0, 1), 1)
		if done >= goal then
			api.hint("잘 저었어요!")
			task.wait(0.3)
			return true, 100
		end
	end
	return false, math.floor(math.clamp(done / goal, 0, 1) * 100)
end

return Stir
