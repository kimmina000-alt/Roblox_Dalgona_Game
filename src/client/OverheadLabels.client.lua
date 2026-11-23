-- 가게 안 머리 위 표시판 숨기기 (2026-11-24 사용자 요청 "안 보이게 해"):
--   기계 위 상태판(MachineClient의 MachineStatus: "연속 생산 설비 · 멈춤 …"),
--   알바생·미니미 머리 위 번호표 + 상태 글(서버 GrowthService/Minime의 Status: "① 알바생 1 · 동그라미 33/35초").
-- 내 화면에서만 끔 (서버·다른 스크립트는 그대로 글을 바꿔도 됨). 다시 켜려면 HIDE에서 이름을 빼면 됨.

local HIDE = { MachineStatus = true, Status = true }

local function hide(d)
	if d:IsA("BillboardGui") and HIDE[d.Name] then
		d.Enabled = false
		-- 다른 코드가 다시 켜면 바로 끔
		d:GetPropertyChangedSignal("Enabled"):Connect(function()
			if d.Enabled then
				d.Enabled = false
			end
		end)
	end
end

local function watch(folder)
	for _, d in ipairs(folder:GetDescendants()) do
		hide(d)
	end
	folder.DescendantAdded:Connect(hide)
end

task.spawn(function()
	watch(workspace:WaitForChild("ShopPlots"))
end)
