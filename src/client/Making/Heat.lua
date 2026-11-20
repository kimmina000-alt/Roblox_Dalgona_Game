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
Heat.handleScreen = nil -- 국자 손잡이 화면 위치 (Heat.control이 매 프레임 갱신)
function Heat.sideZone(pos)
	local v = workspace.CurrentCamera.ViewportSize
	if Heat.handleScreen and (pos - Heat.handleScreen).Magnitude < 110 then
		return true -- 손잡이를 잡고 위아래로 끌어도 됨 (2026-11-20: 화살표가 손잡이에 있음)
	end
	return pos.X < v.X * 0.24 and pos.Y > v.Y * 0.12
end

-- 왼쪽 구역(팔) 또는 높이 막대 자체 (사용자 요청 2026-11-20: 막대에서 직접 움직이기)
function Heat.sideZoneFor(ui)
	return function(pos)
		return Heat.sideZone(pos) or ui:heightHit(pos)
	end
end

-- 막대만 (예전) — 높이 막대가 없어진 뒤(2026-11-20)에는 아무 데도 아님
function Heat.barZoneFor(ui)
	return function(pos)
		return ui:heightHit(pos)
	end
end

-- 왼쪽 구역이지만 avoid(pos)가 참인 곳(소다 통·젓가락 근처)은 빼고 (소다 넣기: 그곳 클릭은 젓가락 쪽)
function Heat.sideZoneExcept(avoid)
	return function(pos)
		return Heat.sideZone(pos) and not avoid(pos)
	end
end

-- 아무것도 안 하고 오래 두면 탐 (2026-11-20): 8초 지나면 타기 시작, 그 뒤 6초에 걸쳐 다 탐 (= 14초)
Heat.IDLE_BURN = 8
Heat.IDLE_BURN_T = 6

local coached = false -- 이번 접속에서 국자 높이를 한 번이라도 끌어 봤나 (처음 하는 사람 안내)

function Heat.control(st, P, ui, S)
	local cfg = Config.Melt
	local d = P.takeSideDelta()
	if P.side.down then
		coached = true
	end
	-- 국자 들기 안내 (2026-11-20 "국자 들라고 할 때, 국자 손잡이 위치에"): 처음 한 번 끌어 보기 전, 불에 너무 가까울 때,
	-- 단계가 더 높이 들라고 할 때(st.wantLift, 소다 젓기). 화살표는 국자 손잡이에서 아래 → 위로
	local handle = nil
	if S and S.ladleHandleWorld then
		local v, on = workspace.CurrentCamera:WorldToScreenPoint(S:ladleHandleWorld())
		if on then
			handle = Vector2.new(v.X, v.Y)
		end
	end
	Heat.handleScreen = handle
	ui:setCoach(not coached or st.wantLift or Heat.sourceTemp(st.h) > cfg.burnTemp or st.temp > cfg.tempHigh + 1, handle)
	-- 온도 막대 옆 화살표: 국자를 올리면 ▼(온도 내려감), 내리면 ▲ (2026-11-20 "국자 올려서 온도 조절하는 거 한눈에")
	if ui.setTempTrend then
		ui:setTempTrend((d.Y < -0.01 and -1) or (d.Y > 0.01 and 1) or 0)
	end
	if P.side.down and P.side.start and ui:heightHit(P.side.start) then
		-- 막대를 잡고 끌면 손가락 자리 = 국자 높이 (바로 따라옴)
		st.h = cfg.hMin + ui:heightAt(P.side.pos.Y) * (cfg.hMax - cfg.hMin)
	elseif d.Y ~= 0 then
		local vh = workspace.CurrentCamera.ViewportSize.Y
		-- 2026-11-20 플레이 테스트: 안내 줄(왼쪽 아래 큰 화살표 길, 화면 높이의 약 27%)을 한 번 끝까지 끌면
		-- 알맞은 높이 칸 가운데쯤 (약 160°)에 들어가게. 0.45는 끝까지 끌어도 타고, 0.25는 너무 올라가 식음
		st.h = math.clamp(st.h - d.Y / (vh * 0.34) * (cfg.hMax - cfg.hMin), cfg.hMin, cfg.hMax)
	end
	local danger = Heat.sourceTemp(st.h) > cfg.burnTemp or st.temp > cfg.burnTemp - 3
	-- 알맞은 높이 칸: 불 온도가 tempLow ~ tempHigh가 되는 높이 (sourceTemp = 235 - 95 × h01)
	local band = { math.clamp((235 - cfg.tempHigh) / 95, 0, 1), math.clamp((235 - cfg.tempLow) / 95, 0, 1) }
	local anchor = nil
	if S and S.Bowl then
		local v, on = workspace.CurrentCamera:WorldToScreenPoint(S.Bowl.Position)
		if on then
			anchor = Vector2.new(v.X, v.Y)
		end
	end
	ui:setHeight(true, (st.h - cfg.hMin) / (cfg.hMax - cfg.hMin), danger, P.side.down, band, anchor)
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
	-- 시작 유예 (사용자 요청 2026-11-19): 국자가 연탄 위에 놓인 채 녹이기를 시작해도 처음 몇 초는 타지 않음.
	-- 그 사이 국자를 들어 올리는 게 정식 방법이고, 유예가 끝난 뒤에도 계속 가까이 있으면 탐
	if st.grace and st.grace > 0 then
		st.grace -= dt
		st.temp = math.min(st.temp, Config.Melt.burnTemp - 2)
		return
	end
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
