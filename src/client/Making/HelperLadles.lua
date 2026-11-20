-- 화로 위 알바생 국자 움직임 (MACHINE_ERAS 1단계: 국자 2~4개, 2026-11-20 사용자 요청 "국자 여러 개")
-- 서버 WorkstationBuilder.setLadleCount가 만든 HelperLadle2~4마다:
--   설탕을 넣고 → 젓가락이 원을 그리며 저어 흰 설탕이 투명한 호박색으로 녹고 → 소다를 넣어 베이지색으로 부풀고
--   → 부어서 비워진 뒤 잠깐 쉬었다가 다시. 국자마다 시작 시점(Phase)이 달라서 따로따로 돌아감.
-- 꾸밈 움직임이라 각 플레이어 화면에서만 그림 (서버 부담 없음)

local RunService = game:GetService("RunService")

local Helper = {}

local CYCLE = 20 -- 한 바퀴(설탕 넣기 ~ 다시 비움) 초
local SUGAR = Color3.fromRGB(250, 250, 250)
local AMBER = Color3.fromRGB(236, 168, 52)
local FOAM = Color3.fromRGB(214, 164, 108)

local base = setmetatable({}, { __mode = "k" }) -- 내용물 처음 자리 (부품 → CFrame)

local function stepOne(m, now)
	local c = m:GetAttribute("Center")
	local R = m:GetAttribute("BowlR") or 0.85
	local stick, cont = m:FindFirstChild("Stick"), m:FindFirstChild("Contents")
	if not (c and stick and cont) then
		return
	end
	if not base[cont] then
		base[cont] = cont.CFrame
	end
	local cf0 = base[cont]
	local th0 = cont:GetAttribute("BaseThick") or cont.Size.X
	local u = (now / CYCLE + (m:GetAttribute("Phase") or 0)) % 1
	local color, thick, mat, hidden = SUGAR, th0, Enum.Material.Sand, false
	local stir = 0 -- 젓는 빠르기 (rad/s)
	if u < 0.08 then
		-- 설탕을 붓는 중: 흰 설탕이 쌓임
		thick = th0 * (0.3 + 0.7 * u / 0.08)
	elseif u < 0.5 then
		-- 녹이기: 흰 → 투명한 호박색
		local k = (u - 0.08) / 0.42
		color = SUGAR:Lerp(AMBER, k)
		mat = k < 0.55 and Enum.Material.Sand or Enum.Material.SmoothPlastic
		stir = 5
	elseif u < 0.7 then
		-- 소다: 빠르게 저으면 베이지색으로 부풀어 오름
		local k = (u - 0.5) / 0.2
		color = AMBER:Lerp(FOAM, math.min(k * 1.5, 1))
		mat = Enum.Material.SmoothPlastic
		thick = th0 * (1 + 2.2 * k * k * (3 - 2 * k))
		stir = 10
	elseif u < 0.78 then
		-- 부음: 내용물이 줄어듦
		local k = (u - 0.7) / 0.08
		color = FOAM
		mat = Enum.Material.SmoothPlastic
		thick = th0 * 3.2 * (1 - k)
		hidden = k > 0.97
	else
		hidden = true -- 비어서 잠깐 쉼
	end
	cont.Transparency = hidden and 1 or 0
	if not hidden then
		thick = math.max(thick, 0.01)
		cont.Size = Vector3.new(thick, cont.Size.Y, cont.Size.Z)
		cont.CFrame = cf0 + Vector3.new(0, (thick - th0) / 2, 0)
		cont.Color = color
		cont.Material = mat
	end
	-- 나무젓가락: 끝이 국자 안에서 원을 그림, 손잡이는 위로 비스듬히. 쉴 때는 국자에 기대 둠
	local a = stir > 0 and now * stir + (m:GetAttribute("Phase") or 0) * 20 or 0.8
	local r = stir > 0 and R * 0.42 or R * 0.55
	local topY = cf0.Position.Y + thick / 2
	local tip = Vector3.new(c.X + math.cos(a) * r, topY + 0.02, c.Z + math.sin(a) * r)
	local lean = stir > 0 and Vector3.new(math.cos(a) * 0.35, 1, math.sin(a) * 0.35) or Vector3.new(math.cos(a) * 0.9, 0.6, math.sin(a) * 0.9)
	local hand = tip + lean.Unit * stick.Size.X
	stick.CFrame = CFrame.lookAt((tip + hand) / 2, hand) * CFrame.Angles(0, math.rad(90), 0)
end

local started = false
function Helper.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function()
		local ws = workspace:FindFirstChild("DalgonaWorkstation")
		if not ws then
			return
		end
		local now = os.clock()
		for _, m in ipairs(ws:GetChildren()) do
			if m.Name:sub(1, 11) == "HelperLadle" then
				stepOne(m, now)
			end
		end
	end)
end

return Helper
