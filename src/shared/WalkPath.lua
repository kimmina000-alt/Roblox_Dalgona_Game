-- 알바생 걷는 길 (2026-11-24 사용자 "알바가 진열하러 걸을 때 벽을 뚫고 다님", 판매 세션)
-- 서버(Services/HelperPath)가 PathfindingService로 찾은 경유점을 미니미 속성 문자열 "WalkPath"로 넣고,
-- 클라이언트(HelperLadles 진열 알바·HelperCarry 들고 가는 알바)가 이 길을 따라 걸음. 길이 없으면 예전처럼 곧게.
-- 문자열: "x,y,z;x,y,z;..." (소수 한 자리)

local WalkPath = {}

function WalkPath.encode(points)
	local t = table.create(#points)
	for i, p in ipairs(points) do
		t[i] = string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)
	end
	return table.concat(t, ";")
end

local cache = {}
local cacheN = 0
function WalkPath.decode(s)
	if type(s) ~= "string" or s == "" then
		return nil
	end
	local hit = cache[s]
	if hit then
		return hit
	end
	local pts = {}
	for x, y, z in string.gmatch(s, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	if #pts < 2 then
		return nil
	end
	local lens, total = { 0 }, 0
	for i = 2, #pts do
		total += (Vector3.new(pts[i].X, 0, pts[i].Z) - Vector3.new(pts[i - 1].X, 0, pts[i - 1].Z)).Magnitude
		lens[i] = total
	end
	local rec = { points = pts, lens = lens, length = total }
	cacheN += 1
	if cacheN > 200 then
		table.clear(cache)
		cacheN = 1
	end
	cache[s] = rec
	return rec
end

-- 길 위 한 점: k = 0(처음) ~ 1(끝). 반환 = 자리, 앞 방향(수평)
function WalkPath.sample(rec, k)
	local pts, lens = rec.points, rec.lens
	local d = math.clamp(k, 0, 1) * rec.length
	for i = 2, #pts do
		if d <= lens[i] or i == #pts then
			local seg = lens[i] - lens[i - 1]
			local f = seg > 1e-3 and math.clamp((d - lens[i - 1]) / seg, 0, 1) or 1
			local a, b = pts[i - 1], pts[i]
			local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			return a:Lerp(b, f), dir.Magnitude > 1e-3 and dir.Unit or nil
		end
	end
	return pts[#pts], nil
end

-- 거꾸로 (돌아올 때)
function WalkPath.reversed(rec)
	local pts = {}
	for i = #rec.points, 1, -1 do
		table.insert(pts, rec.points[i])
	end
	return WalkPath.decode(WalkPath.encode(pts))
end

return WalkPath
