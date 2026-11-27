-- 골목 슈퍼·문구사 편집 화면 틀 (2026-11-28 사용자 "플레이할 때만 보이는 건물·진열을 편집 화면에서도 보이고 거기서 고치게").
-- Studio 편집 모드에서 실행 (MCP execute_luau 또는 명령 창). 다시 실행하면 틀을 새로 만듦 (고친 것이 지워지니 주의).
--   Workspace.AlleyMarket     = ServerStorage.Assets.AlleyMarket 복제, 게임 자리(골목 동쪽 끝 남쪽 첫 칸)
--   Workspace.AlleyStationery = ServerStorage.Assets.AlleyStationery 복제 + 선반 모양틀·국자(St_Goods), 서쪽 끝 남쪽 첫 칸
--   둘 다 속성 AlleyTemplate = true. 게임을 켜면 AlleyBuilder가 이 틀을 놓인 자리 그대로 씀 (선반 물건 포함).
-- 사용자가 고치는 법: 편집 화면에서 Workspace.AlleyMarket / AlleyStationery 안 부품을 옮기거나 지우고 장소를 저장 → Play.
--   건물 통째로 옮기기 = 모델을 끌어 옮김 (문 앞 자리 Mk_Pt_Door가 같이 움직이면 됨). 선반 물건(봉지·모양틀)은 하나씩 옮기거나 지워도 됨.
--   Mk_Wall(안 보이는 벽)·Mk_Pt_*(자리 표시)는 지우지 말 것.
local SS = game:GetService("ServerStorage")
local Services = game:GetService("ServerScriptService").Server.Services
-- 편집 모드 require는 예전 결과를 기억할 수 있어서 복제본을 require
local mod = Services.AlleyBuilder:Clone()
local A = require(mod)

local out = {}
for _, name in ipairs({ "AlleyMarket", "AlleyStationery" }) do
	local old = workspace:FindFirstChild(name)
	if old and old:GetAttribute("AlleyTemplate") then
		old:Destroy()
	end
	local src = SS.Assets:FindFirstChild(name)
	local front = A.defaultFront(name)
	if src and front then
		local t = src:Clone()
		local door = t:FindFirstChild("Mk_Pt_Door", true)
		local own = door.CFrame * CFrame.new(0, -door.Size.Y / 2, 1.5) -- 틀의 문 앞 바닥
		t:PivotTo(front * own:Inverse() * t:GetPivot())
		t:SetAttribute("AlleyTemplate", true)
		t:SetAttribute("Note", "편집 화면 틀 (tools/studio/alley_templates_1128.lua). 게임은 이 자리·이 모습 그대로 씀. 고치고 장소 저장 → Play")
		if name == "AlleyStationery" then
			A.fillStationery(t, t)
		end
		t.Parent = workspace
		table.insert(out, name .. " @ " .. tostring(front.Position))
	end
end
mod:Destroy()
return table.concat(out, "\n")
