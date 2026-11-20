-- 작업대 찾기 (17b, 2026-11-21): 가게 부지마다 손 작업대가 있음 (서버 PlotService가 만듦)
--   workspace.ShopPlots.Plot<n>.Workstation, 속성 OwnerUserId = 주인, PlotIndex, CoalLeft, LadleCount
-- 스폰 앞 공용 DalgonaWorkstation은 없앰 (U8). 예전 장소(공용 작업대가 아직 있는 곳)에서도 돌게 마지막 대안으로만 봄.

local Players = game:GetService("Players")

local Workstations = {}

local function plotsFolder()
	return workspace:FindFirstChild("ShopPlots")
end

-- 모든 가게 작업대 (다른 플레이어 것 포함)
function Workstations.all()
	local list = {}
	local plots = plotsFolder()
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local ws = plot:FindFirstChild("Workstation")
			if ws and ws:IsA("Model") then
				table.insert(list, ws)
			end
		end
	end
	local shared = workspace:FindFirstChild("DalgonaWorkstation")
	if shared then
		table.insert(list, shared)
	end
	return list
end

-- 내 가게 작업대 (가게를 아직 못 받았으면 nil)
function Workstations.mine()
	local me = Players.LocalPlayer
	local plots = plotsFolder()
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local ws = plot:FindFirstChild("Workstation")
			if ws and ws:IsA("Model") and ws:GetAttribute("OwnerUserId") == me.UserId then
				return ws
			end
		end
	end
	return nil
end

-- 작업대가 다 만들어졌나 (복제·이동이 끝나 부품이 다 들어왔는지)
function Workstations.ready(ws)
	return ws ~= nil and ws.Parent ~= nil and ws:FindFirstChild("TableTop") ~= nil and ws:FindFirstChild("Ladle") ~= nil and ws:FindFirstChild("Brazier") ~= nil
end

return Workstations
