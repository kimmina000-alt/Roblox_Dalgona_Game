-- 편집(멈춘) 화면에서도 플레이 화면처럼 골목·가게 6칸·슈퍼·문구사가 보이게 (2026-11-28 사용자 "편집 화면에서도 플레이 화면처럼 맵 보이도록").
-- Studio MCP execute_luau, datamodel = Edit 로 붙여 넣어 실행. 코드가 바뀐 뒤 다시 돌리면 새 모습으로 바뀜.
--  * 게임과 같은 코드(PlotService.init의 가게 만들기, AlleyBuilder.build)를 편집 화면에서 한 번 돌려 Workspace.ShopPlots·Workspace.Alley를 만듦.
--    Play를 누르면 서버가 이 둘을 지우고 새로 만들므로 게임에 두 번 생기지 않음 (PlotService.init / AlleyBuilder.build 첫 줄).
--  * 만드는 동안 코드가 편집 화면 틀(PlotLayout·AlleyMarket·AlleyStationery 등)을 ServerStorage로 옮기므로 끝나고 Workspace로 되돌림.
--  * 보기용 부품은 잠금(Locked) → 화면을 눌러도 틀(고칠 원본)만 잡힘. 틀과 같은 자리에 생긴 보기용 복사본(1번 가게 건물·슈퍼·문구사)은 숨김.
--  * 기계·공장은 주인 데이터가 있어야 생겨서 여기서는 안 만듦 (MachineLayout·FactoryLayout 틀이 편집 화면에 그대로 보임).
local SSS = game:GetService("ServerScriptService")
local Services = SSS.Server.Services
local out = {}

-- 1) 지금 Workspace 바로 아래 것들 기억 (코드가 옮기면 되돌리려고)
local before = {}
for _, c in ipairs(workspace:GetChildren()) do
	before[c] = true
end
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
local spawnCF = spawn and spawn.CFrame

-- 2) 게임 코드로 만들기
local PlotService = require(Services.PlotService)
local ok1, e1 = pcall(function()
	PlotService.init({ notify = function() end })
end)
table.insert(out, "plots " .. tostring(ok1) .. " " .. tostring(e1 or ""))
local ok2, e2 = pcall(function()
	require(Services.AlleyBuilder).build()
end)
table.insert(out, "alley " .. tostring(ok2) .. " " .. tostring(e2 or ""))

-- 3) 옮겨진 틀 되돌리기 + 스폰 자리
for inst in pairs(before) do
	if inst.Parent ~= workspace and inst.Parent ~= nil then
		table.insert(out, "restored " .. inst.Name)
		inst.Parent = workspace
	end
end
if spawn and spawnCF then
	spawn.CFrame = spawnCF
end

-- 4) 보기용 표시·잠금, 틀과 겹치는 복사본 숨김
local function markPreview(root)
	root:SetAttribute("EditPreview", true)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Locked = true
		end
	end
end
local plots, alley = workspace:FindFirstChild("ShopPlots"), workspace:FindFirstChild("Alley")
if plots then
	markPreview(plots)
end
if alley then
	markPreview(alley)
end
local function hideModel(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end
-- 가게 틀(PlotLayout)은 1번 가게 자리에 겹쳐 둠 (가게 간격이 55 → 66으로 바뀐 뒤 틀이 3번 가게와 겹쳤음, 2026-11-28).
-- 게임은 틀 속성 PlotCFrame 기준 상대 위치만 쓰므로 틀과 PlotCFrame을 같이 옮기면 게임 모습은 그대로.
-- 1번 가게 보기용에서 틀에 있는 것과 같은 이름(ShopModel·Floor·자리 표시들)은 숨겨 틀만 보이게
local layout = workspace:FindFirstChild("PlotLayout")
local p1 = PlotService.plotAt and PlotService.plotAt(1)
if layout and p1 and typeof(layout:GetAttribute("PlotCFrame")) == "CFrame" then
	local tcf = layout:GetAttribute("PlotCFrame")
	layout:PivotTo(p1.cframe * tcf:Inverse() * layout:GetPivot())
	layout:SetAttribute("PlotCFrame", p1.cframe)
	local names = {}
	for _, c in ipairs(layout:GetChildren()) do
		names[c.Name] = true
	end
	for _, c in ipairs(p1.model:GetChildren()) do
		if names[c.Name] then
			if c:IsA("BasePart") then
				c.Transparency = 1
				c.CanCollide = false
				c.CanQuery = false
			else
				hideModel(c)
			end
		end
	end
end
-- 틀과 같은 자리(가운데 차이 1 이내)에 있는 보기용 모델은 숨김 (골목 슈퍼·문구사 틀)
local templates = {}
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("Model") and (c.Name:match("Layout$") or c:GetAttribute("AlleyTemplate")) then
		for _, d in ipairs(c:GetChildren()) do
			if d:IsA("Model") then
				table.insert(templates, d:GetBoundingBox().Position)
			end
		end
		table.insert(templates, c:GetBoundingBox().Position)
	end
end
local hidden = 0
for _, root in ipairs({ plots, alley }) do
	for _, m in ipairs(root and root:GetDescendants() or {}) do
		if m:IsA("Model") then
			local p = m:GetBoundingBox().Position
			for _, t in ipairs(templates) do
				if (p - t).Magnitude < 1 then
					hideModel(m)
					hidden += 1
					break
				end
			end
		end
	end
end
table.insert(out, "hidden duplicates " .. hidden)
return table.concat(out, "\n")
