-- 건설(꾸미기) 모드 (D53 안 A, 2026-11-25 확정, GDD 15장, 판매 세션). 수치·물건 목록은 GrowthConfig.Build
-- 가게 안 물건을 2스터드 격자에 옮기고 90°씩 돌림. 손 작업대·공장 공정·문·벽에 붙은 것(걸이판·벽 선반)은 고정.
--   저장: d.layout = { [물건 key] = { x, z, r } } — 부지 기준 로컬 격자 좌표(정수, 1칸 = 2스터드, 물건 가운데) + 회전 0~3.
--         어느 부지를 배정받아도 같은 배치. 없으면 처음 자리(가게 3D 틀 그대로). [처음 배치로] = layout 비우기
--   서버 검사: 놓을 수 있는 범위(G.Build.area) 안, 다른 물건·고정물(작업대·공장 문 앞·벽 걸이판)과 안 겹침,
--             입구 → 진열 가구 옆 → 계산대까지 폭 4스터드 길이 막히지 않음 (2스터드 격자 BFS, 2×2칸 몸)
--   바꾸면: 그 부지 물건(가게 3D 노드)을 옮기고 기계 모습(MachineDisplay.sync)·알바 미니미(다시 세움)·알바 길(HelperPath) 다시.
--           진열 칸은 가구 부품 자리를 그때그때 읽어서(SalesService localBox) 따라감
--   가게를 임대한 뒤(G.shopOpen 또는 rented)에만. 노점 때는 안 됨
--
-- 화면 쪽 약속 (UI 세션 [꾸미기] 화면):
--   Remotes.BuildAction:InvokeServer("get") → { ok, layout, items = { [key] = { name, x, z, r, w, d, default = {x,z,r} } }, area = {x0,x1,z0,z1}, cell = 2 }
--       x, z = 지금 가운데 격자 좌표(부지 로컬 스터드 = 값 × 2), w, d = 차지하는 칸(회전 0일 때 가로·세로 격자 칸 수)
--   ("check", key, x, z, r) → { ok, reason } (초록/빨강 미리 보기, 저장 안 함)
--   ("place", key, x, z, r) → { ok, reason } (저장·적용)
--   ("reset") → { ok } (처음 배치로)
--   부지 모델 속성 LayoutVersion(숫자)이 바뀌면 배치가 바뀐 것

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local BuildService = {}

local B = G.Build
local CELL = B.cell
local Data, Economy, Plots
local MachineDisplay, HelperPath

local plotsInfo = {} -- [부지 번호] = { cf, items = { [key] = { nodes = { {inst, rel} }, c0 = Vector3(로컬 가운데), half = Vector3(로컬 반 크기) } } }
local applied = {} -- [player] = 적용한 부지 번호

local function pivotOf(inst)
	if inst:IsA("Model") then
		return inst:GetPivot()
	end
	return inst.CFrame
end

local function setPivot(inst, cf)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	else
		inst.CFrame = cf
	end
end

-- 부지 모델 안에서 물건 노드 찾기: Role 부품의 부모 노드(가게 3D 노드 Model) 또는 이름으로 찾은 부품
local function findNodes(model, def)
	local out = {}
	for _, role in ipairs(def.roles or {}) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Role") == role then
				local node = d.Parent
				if node and node:IsA("Model") and node.Name ~= "ShopModel" and node ~= model then
					table.insert(out, node)
				else
					table.insert(out, d)
				end
				break
			end
		end
	end
	for _, name in ipairs(def.names or {}) do
		local p = model:FindFirstChild(name)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

-- 노드들을 부지 축으로 본 상자 (가운데·반 크기)
local function boxOf(cf, nodes)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, n in ipairs(nodes) do
		local parts = n:IsA("BasePart") and { n } or n:GetDescendants()
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				local l = cf:ToObjectSpace(p.CFrame)
				local h = p.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						for _, sy in ipairs({ -1, 1 }) do
							local v = (l * CFrame.new(h.X * sx, h.Y * sy, h.Z * sz)).Position
							mn = Vector3.new(math.min(mn.X, v.X), math.min(mn.Y, v.Y), math.min(mn.Z, v.Z))
							mx = Vector3.new(math.max(mx.X, v.X), math.max(mx.Y, v.Y), math.max(mx.Z, v.Z))
						end
					end
				end
			end
		end
	end
	if mn.X == math.huge then
		return nil
	end
	return (mn + mx) / 2, (mx - mn) / 2
end

local function capture(i)
	if plotsInfo[i] then
		return plotsInfo[i]
	end
	local plot = Plots.plotAt(i)
	if not (plot and plot.model and plot.cframe) then
		return nil
	end
	local info = { cf = plot.cframe, items = {} }
	for _, def in ipairs(B.items) do
		local nodes = findNodes(plot.model, def)
		if #nodes > 0 then
			local c0, half = boxOf(plot.cframe, nodes)
			if c0 then
				local rec = { def = def, nodes = {}, c0 = c0, half = half }
				for _, n in ipairs(nodes) do
					table.insert(rec.nodes, { inst = n, rel = plot.cframe:ToObjectSpace(pivotOf(n)) })
				end
				info.items[def.key] = rec
			end
		end
	end
	plotsInfo[i] = info
	return info
end

-- 물건 하나가 차지하는 부지 로컬 사각형 (x0, x1, z0, z1): 자리 e(격자) 또는 처음 자리
local function rectOf(rec, e)
	local cx, cz, hx, hz = rec.c0.X, rec.c0.Z, rec.half.X, rec.half.Z
	if e then
		cx, cz = e.x * CELL, e.z * CELL
		if (e.r or 0) % 2 == 1 then
			hx, hz = hz, hx
		end
	end
	local pad = B.pad
	return { cx - hx + pad, cx + hx - pad, cz - hz + pad, cz + hz - pad }
end

local function overlap(a, b)
	return a[1] < b[2] and b[1] < a[2] and a[3] < b[4] and b[3] < a[4]
end

-- 고정물 사각형 (부지 로컬): 손 작업대(지금 모델 상자), 공장 문 앞, 벽 걸이판 등 (G.Build.fixedNames)
local function fixedRects(i)
	local plot = Plots.plotAt(i)
	local out = {}
	if not plot then
		return out
	end
	for _, name in ipairs(B.fixedNames) do
		local n = plot.model:FindFirstChild(name)
		-- 손 작업대는 가게 안 자리(AtInside)일 때만. 들어온 직후에는 아직 가게 밖 노점 자리(입구 앞)에 있다가
		-- PlotService가 곧 안으로 옮기는데, 그때 검사하면 "입구가 막혀요"로 저장된 배치가 처음 자리로 돌아갔음
		if n and not (name == "Workstation" and n:GetAttribute("AtInside") ~= true) then
			local c, h = boxOf(plot.cframe, { n })
			if c then
				local extra = B.fixedPad[name] or 0
				h = h * (B.fixedScale[name] or 1) -- 가게 안 손 작업대는 화면에서 1/2 크기 (ViewScale)
				table.insert(out, { c.X - h.X - extra, c.X + h.X + extra, c.Z - h.Z - extra, c.Z + h.Z + extra, name = name })
			end
		end
	end
	for _, def in ipairs(B.fixedRoles) do
		local nodes = findNodes(plot.model, { roles = { def } })
		local c, h = boxOf(plot.cframe, nodes)
		if c then
			table.insert(out, { c.X - h.X, c.X + h.X, c.Z - h.Z, c.Z + h.Z, name = def })
		end
	end
	return out
end

-- 입구에서 진열 가구·계산대 옆까지 폭 4스터드 길이 있나 (2스터드 격자, 몸 = 2×2칸). 반환: ok, 막힌 물건 key
local function pathOk(rects, targets)
	local A = B.walk
	local nx = math.floor((A.x1 - A.x0) / CELL)
	local nz = math.floor((A.z1 - A.z0) / CELL)
	local blocked = {}
	local function cellRect(ix, iz)
		local x0, z0 = A.x0 + ix * CELL, A.z0 + iz * CELL
		return { x0, x0 + CELL, z0, z0 + CELL }
	end
	for ix = 0, nx - 1 do
		blocked[ix] = {}
		for iz = 0, nz - 1 do
			local cr = cellRect(ix, iz)
			local b = false
			for _, r in ipairs(rects) do
				if overlap(cr, r) then
					b = true
					break
				end
			end
			-- 벽: 가게 앞선 안쪽은 건물 벽 안만 걸을 수 있음
			local cx, cz = (cr[1] + cr[2]) / 2, (cr[3] + cr[4]) / 2
			if cz > B.frontZ and math.abs(cx) > B.wallHalf then
				b = true
			end
			blocked[ix][iz] = b
		end
	end
	local function free(ix, iz) -- 몸 2×2칸
		if ix < 0 or iz < 0 or ix + 1 >= nx or iz + 1 >= nz then
			return false
		end
		return not (blocked[ix][iz] or blocked[ix + 1][iz] or blocked[ix][iz + 1] or blocked[ix + 1][iz + 1])
	end
	local sx = math.floor((B.entry.X - A.x0) / CELL)
	local sz = math.floor((B.entry.Z - A.z0) / CELL)
	if not free(sx, sz) then
		return false, "entry"
	end
	local seen = { [sx * 1000 + sz] = true }
	local q = { { sx, sz } }
	local head = 1
	while head <= #q do
		local c = q[head]
		head += 1
		for _, dxz in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local x, z = c[1] + dxz[1], c[2] + dxz[2]
			local k = x * 1000 + z
			if not seen[k] and free(x, z) then
				seen[k] = true
				table.insert(q, { x, z })
			end
		end
	end
	-- 물건마다: 그 사각형 옆(1칸 밖) 몸 자리에 닿을 수 있나
	for key, r in pairs(targets) do
		local reach = false
		local grown = { r[1] - CELL * 2.5, r[2] + CELL * 0.5, r[3] - CELL * 2.5, r[4] + CELL * 0.5 }
		for _, c in ipairs(q) do
			local x0, z0 = A.x0 + c[1] * CELL, A.z0 + c[2] * CELL
			local body = { x0, x0 + CELL * 2, z0, z0 + CELL * 2 }
			if overlap(body, grown) then
				reach = true
				break
			end
		end
		if not reach then
			return false, key
		end
	end
	return true
end

local function itemName(key)
	for _, def in ipairs(B.items) do
		if def.key == key then
			return def.name
		end
	end
	return key
end

-- 받침에 맞는 조사 ("와"/"과", "가"/"이"). 끝이 숫자면 읽는 소리로 (1 일, 3 삼 …)
local DIGIT_BATCHIM = { ["0"] = true, ["1"] = true, ["3"] = true, ["6"] = true, ["7"] = true, ["8"] = true }
local function hasBatchim(word)
	local last
	for _, cp in utf8.codes(word) do
		last = cp
	end
	if not last then
		return false
	end
	if last >= 0xAC00 and last <= 0xD7A3 then
		return (last - 0xAC00) % 28 ~= 0
	end
	return DIGIT_BATCHIM[utf8.char(last)] == true
end
local function josa(word, withBatchim, without)
	return word .. (hasBatchim(word) and withBatchim or without)
end

-- 배치 layout이 괜찮나 (부지 i 기준). 반환: ok, 이유
local REQUIRE_PATH = false -- 손님·알바가 지나갈 폭 4 길을 검사할지
local function validate(i, layout)
	local info = capture(i)
	if not info then
		return false, "가게를 찾지 못했어요"
	end
	local rects, targets = {}, {}
	local fixed = fixedRects(i)
	for key, rec in pairs(info.items) do
		local e = layout[key]
		local r = rectOf(rec, e)
		if e then
			local A = B.area
			if r[1] < A.x0 or r[2] > A.x1 or r[3] < A.z0 or r[4] > A.z1 then
				return false, itemName(key) .. ": 가게 밖으로 나가요"
			end
			for _, f in ipairs(rec.def.wall and {} or fixed) do -- 벽에 거는 물건은 바닥 고정물과 높이가 달라 안 겹침
				if overlap(r, f) then
					return false, itemName(key) .. ": 고정된 물건과 겹쳐요"
				end
			end
		end
		for k2, r2 in pairs(rects) do
			local sameLevel = (rec.def.wall == true) == (info.items[k2].def.wall == true) -- 벽 물건끼리·바닥 물건끼리만 겹침 검사
			if sameLevel and overlap(r, r2) and (e or layout[k2]) then
				return false, string.format("%s %s 겹쳐요", josa(itemName(key), "과", "와"), josa(itemName(k2), "이", "가"))
			end
		end
		rects[key] = r
		if rec.def.needPath then
			targets[key] = r
		end
	end
	local all = {}
	for _, r in pairs(rects) do
		table.insert(all, r)
	end
	for _, f in ipairs(fixed) do
		table.insert(all, f)
	end
	-- 2026-11-28 사용자 "가구끼리 폭 4 거리 둬야 함? 겹치지만 않으면 설치 가능하게": 길 검사는 끔 (REQUIRE_PATH)
	local ok, bad = true, nil
	if REQUIRE_PATH then
		ok, bad = pathOk(all, targets)
	end
	if not ok then
		return false, bad == "entry" and "입구가 막혀요" or (itemName(bad) .. " 앞으로 가는 길(폭 4)이 막혀요")
	end
	return true
end

-- 부지 i에 배치 적용 (layout 없으면 처음 자리)
local function apply(i, layout)
	local info = capture(i)
	local plot = Plots.plotAt(i)
	if not (info and plot) then
		return
	end
	layout = layout or {}
	local movedMachine = false
	for key, rec in pairs(info.items) do
		local e = layout[key]
		local T = CFrame.new()
		if e then
			T = CFrame.new(e.x * CELL, 0, e.z * CELL) * CFrame.Angles(0, math.rad(90 * (e.r or 0)), 0) * CFrame.new(-rec.c0.X, 0, -rec.c0.Z)
		end
		for _, n in ipairs(rec.nodes) do
			if n.inst.Parent then
				setPivot(n.inst, info.cf * T * n.rel)
			end
		end
		if rec.def.machine then
			movedMachine = true
		end
	end
	if movedMachine then
		MachineDisplay = MachineDisplay or require(script.Parent:WaitForChild("MachineDisplay"))
		pcall(MachineDisplay.sync, plot.model, false)
	end
	-- 알바 미니미는 다시 세움 (GrowthService syncHelpers가 Data.Changed 때 없는 미니미를 새 자리에 만듦), 알바 길도 다시
	for _, c in ipairs(plot.model:GetChildren()) do
		if c:IsA("Model") and c.Name:match("^Helper") then
			c:Destroy()
		end
	end
	HelperPath = HelperPath or require(script.Parent:WaitForChild("HelperPath"))
	HelperPath.clear()
	plot.model:SetAttribute("LayoutVersion", (plot.model:GetAttribute("LayoutVersion") or 0) + 1)
end

local function cleanLayout(raw)
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, def in ipairs(B.items) do
		local e = raw[def.key]
		if type(e) == "table" and tonumber(e.x) and tonumber(e.z) then
			out[def.key] = { x = math.floor(tonumber(e.x)), z = math.floor(tonumber(e.z)), r = math.floor(tonumber(e.r) or 0) % 4 }
		end
	end
	return out
end

local function canBuild(d)
	local shop = d.shop or {}
	return shop.state == "rented" or shop.state == "owned"
end

local function action(player, what, key, x, z, r)
	local d = Data.get(player)
	local _, i = Plots.get(player)
	if not (d and i) then
		return { ok = false, reason = "불러오는 중이에요" }
	end
	local layout = cleanLayout(d.layout)
	if what == "get" then
		local info = capture(i)
		local items = {}
		for k, rec in pairs(info and info.items or {}) do
			local e = layout[k]
			local def0 = { x = math.floor(rec.c0.X / CELL + 0.5), z = math.floor(rec.c0.Z / CELL + 0.5), r = 0 }
			items[k] = {
				name = rec.def.name,
				x = e and e.x or def0.x,
				z = e and e.z or def0.z,
				r = e and e.r or 0,
				w = math.max(1, math.floor(rec.half.X * 2 / CELL + 0.5)),
				d = math.max(1, math.floor(rec.half.Z * 2 / CELL + 0.5)),
				default = def0,
			}
		end
		return { ok = true, layout = layout, items = items, area = B.area, cell = CELL }
	end
	if not canBuild(d) then
		return { ok = false, reason = "가게를 임대하면 꾸밀 수 있어요" }
	end
	if what == "reset" then
		Data.update(player, function(dd)
			dd.layout = {}
		end)
		apply(i, {})
		Economy.push(player)
		return { ok = true }
	end
	if what ~= "check" and what ~= "place" then
		return { ok = false, reason = "잘못된 요청" }
	end
	local info = capture(i)
	if type(key) ~= "string" or not (info and info.items[key]) then
		return { ok = false, reason = "옮길 수 없는 물건이에요" }
	end
	x, z, r = tonumber(x), tonumber(z), tonumber(r)
	if not (x and z) then
		return { ok = false, reason = "잘못된 자리" }
	end
	local try = table.clone(layout)
	try[key] = { x = math.floor(x), z = math.floor(z), r = math.floor(r or 0) % 4 }
	local ok, why = validate(i, try)
	if not ok or what == "check" then
		return { ok = ok, reason = why }
	end
	apply(i, try)
	Data.update(player, function(dd)
		dd.layout = try
	end)
	Economy.push(player)
	return { ok = true }
end

function BuildService.init(dataService, economyService, plotService)
	Data, Economy, Plots = dataService, economyService, plotService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fn = remotes:FindFirstChild("BuildAction")
	if not fn then
		fn = Instance.new("RemoteFunction")
		fn.Name = "BuildAction"
		fn.Parent = remotes
	end
	local last = {}
	fn.OnServerInvoke = function(player, what, key, x, z, r)
		if what ~= "check" and last[player] and os.clock() - last[player] < 0.25 then
			return { ok = false, reason = "천천히!" }
		end
		last[player] = os.clock()
		local ok, res = pcall(action, player, what, key, x, z, r)
		if not ok then
			warn("[Build]", res)
			return { ok = false, reason = "오류가 났어요" }
		end
		return res
	end
	-- 처음 자리는 서버 시작 때 (주인이 오기 전, 틀 그대로) 잼
	task.defer(function()
		for i = 1, G.Plots.count do
			pcall(capture, i)
		end
	end)
	-- 들어오면 저장된 배치를 그 부지에, 나가면 처음 자리로
	Data.Changed:Connect(function(player)
		if applied[player] then
			return
		end
		local d = Data.get(player)
		local _, i = Plots.get(player)
		if d and i then
			applied[player] = i
			local layout = cleanLayout(d.layout)
			if next(layout) then
				-- 저장 뒤 틀이 바뀌었을 수 있어서 다시 검사, 안 맞으면 처음 자리
				if not validate(i, layout) then
					layout = {}
				end
				apply(i, layout)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		local i = applied[p]
		applied[p] = nil
		last[p] = nil
		if i then
			pcall(apply, i, {})
		end
	end)
end

return BuildService
