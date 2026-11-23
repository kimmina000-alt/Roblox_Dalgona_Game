-- 간판 금테 (D38, 2026-11-24): 가게 부지 모델(workspace.ShopPlots.Plot<i>) 속성 SignGold = true면
-- 그 가게 간판 테를 금색으로. 서버는 속성만 넣고, 색은 이 화면에서만 바꿈 (끄면 원래 색으로).
-- 테 부품은 가게 3D(PlotLayout.ShopModel)의 Role로 찾음:
--   "걸이 간판 테" = HangingSign.HSign_Frame, "큰 간판 판" = 가게 이름 판 뒤 나무 판

local GOLD_ROLES = { ["걸이 간판 테"] = true, ["큰 간판 판"] = true }
local GOLD = Color3.fromRGB(255, 196, 60)
local GOLD_MATERIAL = Enum.Material.Foil -- 살짝 반짝임

local saved = {} -- [part] = { Color, Material }

local function isFrame(d)
	return d:IsA("BasePart") and GOLD_ROLES[d:GetAttribute("Role")] == true
end

local function paint(part, on)
	if on then
		if not saved[part] then
			saved[part] = { part.Color, part.Material }
			part.Destroying:Connect(function()
				saved[part] = nil
			end)
		end
		part.Color = GOLD
		part.Material = GOLD_MATERIAL
	elseif saved[part] then
		part.Color, part.Material = saved[part][1], saved[part][2]
		saved[part] = nil
	end
end

local function watchPlot(plot)
	local function apply()
		local on = plot:GetAttribute("SignGold") == true
		for _, d in ipairs(plot:GetDescendants()) do
			if isFrame(d) then
				paint(d, on)
			end
		end
	end
	plot:GetAttributeChangedSignal("SignGold"):Connect(apply)
	-- 스트리밍으로 나중에 들어오는 부품
	plot.DescendantAdded:Connect(function(d)
		if isFrame(d) and plot:GetAttribute("SignGold") == true then
			paint(d, true)
		end
	end)
	apply()
end

task.spawn(function()
	local plots = workspace:WaitForChild("ShopPlots")
	for _, p in ipairs(plots:GetChildren()) do
		watchPlot(p)
	end
	plots.ChildAdded:Connect(watchPlot)
end)
