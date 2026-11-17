-- 연탄불 위 국자: 높이 → 온도 → 녹음 / 탐. 국자 속 색 바꾸기.
-- "불에 너무 가까이 하지 말고 약간 떨어져서" (MOTION_REFERENCE 6장)

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DalgonaConfig"))

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Heat = {}

local WHITE = Color3.fromRGB(250, 250, 250)
local AMBER = Color3.fromRGB(236, 168, 52)
local DARK = Color3.fromRGB(96, 48, 16)
local BLACK = Color3.fromRGB(24, 16, 12)

function Heat.sourceTemp(h)
	local cfg = Config.Melt
	return 235 - 95 * (h - cfg.hMin) / (cfg.hMax - cfg.hMin)
end

-- 국자 높이 조작 (사용자 요청 2026-11-18): 화면 왼쪽 구역을 위로 끌면 국자가 올라가고(불에서 멀어짐),
-- 아래로 끌면 불 가까이 내려감. 젓는 원은 높이와 상관없음. 왼쪽 막대에 높이 표시, 탈 만큼 가까우면 빨강
function Heat.sideZone(pos)
	local v = workspace.CurrentCamera.ViewportSize
	return pos.X < v.X * 0.24 and pos.Y > v.Y * 0.12
end

function Heat.control(st, P, ui)
	local cfg = Config.Melt
	local d = P.takeSideDelta()
	if d.Y ~= 0 then
		local vh = workspace.CurrentCamera.ViewportSize.Y
		st.h = math.clamp(st.h - d.Y / (vh * 0.45) * (cfg.hMax - cfg.hMin), cfg.hMin, cfg.hMax)
	end
	local danger = Heat.sourceTemp(st.h) > cfg.burnTemp or st.temp > cfg.burnTemp - 3
	ui:setHeight(true, (st.h - cfg.hMin) / (cfg.hMax - cfg.hMin), danger, P.side.down)
	return danger
end

-- (예전 방식) 원 중심 화면 높이(0 위 ~ 1 아래) → 국자 높이
function Heat.heightFromScreen(y01)
	local cfg = Config.Melt
	local f = math.clamp((y01 - 0.2) / 0.6, 0, 1)
	return cfg.hMax - f * (cfg.hMax - cfg.hMin)
end

function Heat.step(st, dt)
	local src = Heat.sourceTemp(st.h)
	st.temp += (src - st.temp) * (1 - math.exp(-0.6 * dt))
	if st.temp > Config.Melt.burnTemp then
		-- 불에 너무 가까우면 탐: 온도가 넘을수록 빨리 (가장 낮으면 2초 안팎)
		st.burn = math.min(1, st.burn + dt * (st.temp - Config.Melt.burnTemp) / 40)
	end
end

function Heat.meltColor(p, burn)
	local c = WHITE:Lerp(AMBER, math.clamp(p, 0, 1))
	if burn > 0 then
		c = c:Lerp(DARK, math.clamp(burn / 0.7, 0, 1))
		if burn > 0.7 then
			c = c:Lerp(BLACK, math.clamp((burn - 0.7) / 0.3, 0, 1))
		end
	end
	return c
end

function Heat.smoke(station, on, amount)
	local bowl = station.Bowl
	local att = bowl:FindFirstChild("FxSmokeAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "FxSmokeAtt"
		att.Position = Vector3.new(0.4, 0, 0)
		att.Parent = bowl
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Smoke"
		pe.Color = ColorSequence.new(Color3.fromRGB(90, 90, 90), Color3.fromRGB(200, 200, 200))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(1.5, 2.5)
		pe.EmissionDirection = Enum.NormalId.Right
		pe.Enabled = false
		pe.Parent = att
	end
	local pe = att.Smoke
	pe.Enabled = on
	pe.Rate = 6 + 30 * (amount or 0)
end

-- 국자 바로 밑 불꽃 세기 (가까울수록 셈)
function Heat.flame(station, h)
	local cfg = Config.Melt
	local f = 1 - (h - cfg.hMin) / (cfg.hMax - cfg.hMin)
	station.Flame.Rate = 18 + 40 * f
	-- 불 소리: 국자가 불에 가까울수록 크고 조금 높게
	Sfx.loop("fire", 0.15 + 0.45 * f, 0.9 + 0.2 * f)
end

return Heat
