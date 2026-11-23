-- 알바생 걷는 길 찾기 (2026-11-24 사용자 "알바가 진열하러 걸을 때 벽을 뚫고 다님", 판매 세션)
-- PathfindingService로 처음 자리 → 진열 칸 앞까지 경유점을 찾아 둠 (같은 길은 저장해 두고 다시 씀).
-- 진열 칸은 가구 위라 그 자리로는 길이 없음 → 칸 둘레 8방향(STAND만큼 떨어진 바닥)에서 처음 자리와 가까운 곳부터 찾아봄.
-- 결과는 shared/WalkPath 문자열로 미니미 속성 "WalkPath"에 넣고, 클라이언트가 그 길로 걸음. 못 찾으면 nil (예전처럼 곧게).

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WalkPath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkPath"))

local HelperPath = {}

local STAND = 2.2 -- 칸에서 이만큼 떨어진 바닥에 섬 (클라 HelperCarry STOP과 같음)
local MAX_CACHE = 400

local cache = {} -- [key] = 문자열 | false(못 찾음)
local pending = {} -- [key] = true (찾는 중)
local count = 0

local function key(a, b)
	return string.format("%d,%d,%d>%d,%d,%d", math.floor(a.X + 0.5), math.floor(a.Y + 0.5), math.floor(a.Z + 0.5), math.floor(b.X + 0.5), math.floor(b.Y + 0.5), math.floor(b.Z + 0.5))
end

local params = RaycastParams.new()
params.RespectCanCollide = true
local function ground(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	return hit and hit.Position or Vector3.new(p.X, p.Y - 2.5, p.Z)
end

local function compute(from, to)
	local a = ground(from)
	local cands = {}
	for i = 0, 7 do
		local ang = i * math.pi / 4
		local c = Vector3.new(to.X + math.cos(ang) * STAND, a.Y, to.Z + math.sin(ang) * STAND)
		table.insert(cands, c)
	end
	table.sort(cands, function(x, y)
		return (x - a).Magnitude < (y - a).Magnitude
	end)
	local path = PathfindingService:CreatePath({ AgentRadius = 1, AgentHeight = 4.5, AgentCanJump = false, WaypointSpacing = 4 })
	for _, c in ipairs(cands) do
		local ok = pcall(function()
			path:ComputeAsync(a, c)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local pts = {}
			for _, w in ipairs(path:GetWaypoints()) do
				table.insert(pts, w.Position)
			end
			if #pts >= 2 then
				return WalkPath.encode(pts)
			end
		end
	end
	return false
end

-- 바로 답: 문자열(길) / false(못 찾음) / nil(아직 찾는 중, 뒤에서 찾기 시작함)
function HelperPath.get(from, to)
	local k = key(from, to)
	local v = cache[k]
	if v ~= nil then
		return v
	end
	if not pending[k] then
		pending[k] = true
		task.spawn(function()
			local s = compute(from, to)
			pending[k] = nil
			if count >= MAX_CACHE then
				table.clear(cache)
				count = 0
			end
			cache[k] = s
			count += 1
		end)
	end
	return nil
end

-- 기다려서 답 (yield). 문자열 또는 false
function HelperPath.wait(from, to)
	local v = HelperPath.get(from, to)
	local t0 = os.clock()
	while v == nil and os.clock() - t0 < 5 do
		task.wait(0.1)
		v = HelperPath.get(from, to)
	end
	return v or false
end

-- 길 길이 (수평). 길이 없으면 곧은 거리
function HelperPath.length(s, from, to)
	local rec = s and WalkPath.decode(s)
	if rec then
		return rec.length
	end
	return (Vector3.new(to.X, 0, to.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
end

-- 가게 바닥·벽이 바뀌면 (가게를 열고 가구가 나타남 등) 다시 찾게
function HelperPath.clear()
	table.clear(cache)
	count = 0
end

return HelperPath
