-- 플레이어 저장 (Phase 2, 2026-11-20)
-- DataStore 한 키에 { data = 플레이어 데이터, lock = { job, t } }를 저장한다.
--  - 세션 잠금: 불러올 때 UpdateAsync로 이 서버(JobId)가 잠금을 잡는다. 다른 서버가 잡고 있으면
--    잠깐 기다리고, 잠금이 오래됐으면(죽은 서버) 가져온다. 저장할 때 잠금이 남의 것이면 덮어쓰지 않는다.
--  - 스키마 버전 + MIGRATIONS: 데이터 모양을 바꾸면 GrowthConfig.SchemaVersion을 올리고 옮기는 함수를 넣는다.
--  - 60초 자동 저장 + 데이터가 바뀌면 15초 뒤 한 번 저장, 나갈 때 저장(잠금 풀기), BindToClose에서 모두 저장.
--  - DataStore를 못 쓰면(Studio API 꺼짐 등) 기본 데이터로 놀 수 있지만 저장은 안 함 (canSave = false).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local SAVE = G.Save

local PlayerDataService = {}

-- 버전 n으로 올리는 함수: MIGRATIONS[n](data). 버전 없는 옛 데이터는 0으로 본다.
PlayerDataService.MIGRATIONS = {
	[1] = function(_data)
		-- v0 → v1: 첫 스키마. 빠진 칸은 reconcile이 기본값으로 채운다.
	end,
	[2] = function(data)
		-- v1 → v2 (Phase 4 성장): 도안 해금을 레벨 기준으로 다시 계산 (v1은 별을 기본으로 줬음).
		-- 여기서는 비우기만 하고, reconcile이 Common을 넣고 GrowthService가 접속 때 레벨만큼 더한다.
		data.unlockedShapes = nil
	end,
	[3] = function(data)
		-- v2 → v3 (D21 노점 → 월세 가게): 이미 국자·알바생·작업대 업그레이드를 산 플레이어는 임대 중으로 (보증금은 낸 것으로 봄),
		-- 나머지는 야외 노점에서 시작
		local bought = (tonumber(data.ladles) or 1) > 1
			or (type(data.partTimers) == "table" and #data.partTimers > 0)
			or (type(data.upgrades) == "table" and (tonumber(data.upgrades.table) or 0) > 0)
		data.shop = { state = bought and "rented" or "stall", rentTimer = 0, closed = false }
	end,
	[4] = function(data)
		-- v3 → v4 (진열대에 직접 놓기, 2026-11-21): 달고나마다 번호, 있던 달고나는 앞에서부터 진열대 칸에 놓인 것으로
		local n = 1
		if type(data.stock) == "table" then
			for i, item in ipairs(data.stock) do
				if type(item) == "table" then
					item.id = n
					n += 1
					if i <= 10 then
						item.sl = i
					end
				end
			end
		end
		data.nextItemId = n
	end,
	[5] = function(data)
		-- v4 → v5 (기계 2~4단계, 2026-11-21): 기계별 도안·진행 초. 설비 단계는 1~4로 (공장 5는 따로)
		data.machine = { shapes = {}, t = 0 }
		local stage = math.floor(tonumber(data.machineStage) or 1)
		data.machineStage = math.clamp(stage, 1, 4)
	end,
	[6] = function(data)
		-- v5 → v6 (5단계 공장, 2026-11-21): 제어대 설정·라인·업그레이드. 해금 여부만 남김
		local old = type(data.factory) == "table" and data.factory or {}
		data.factory = { unlocked = old.unlocked == true, on = false, shape = "", qty = 20, mode = "normal", lines = {}, ups = {} }
	end,
}

local JOB_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. HttpService:GenerateGUID(false))

local changed = Instance.new("BindableEvent")
PlayerDataService.Changed = changed.Event -- (player, data)

local profiles = {} -- [player] = { data, canSave, released, saving, lost, loaded }
local store = nil
local inFlight = 0 -- 지금 진행 중인 저장 수 (BindToClose가 다 끝날 때까지 기다림)

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

-- 기본 데이터에 있는데 저장본에 없는 칸을 채운다 (배열은 통째로 기본값만)
local function reconcile(data, default)
	for k, v in pairs(default) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and #v == 0 and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function migrate(data)
	data.version = tonumber(data.version) or 0
	if data.version > G.SchemaVersion then
		-- 더 새 서버가 쓴 데이터: 모르는 칸은 그대로 두고 읽기만 (덮어써도 칸은 남음)
		warn("[Data] newer schema", data.version, ">", G.SchemaVersion)
	end
	for v = data.version + 1, G.SchemaVersion do
		local fn = PlayerDataService.MIGRATIONS[v]
		if fn then
			fn(data)
		end
		data.version = v
	end
	reconcile(data, G.DefaultData)
	return data
end

function PlayerDataService.newData()
	local d = deepCopy(G.DefaultData)
	d.version = G.SchemaVersion
	return d
end

local function keyFor(player)
	return "u_" .. tostring(player.UserId)
end

local function getStore()
	if store then
		return store
	end
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(SAVE.storeName)
	end)
	if ok then
		store = s
	end
	return store
end

-- 불러오기 + 잠금 잡기. 반환: data(또는 nil), 오류 문자열
local function loadRecord(player)
	local st = getStore()
	if not st then
		return nil, "no datastore"
	end
	local key = keyFor(player)
	local waited = 0
	local delay = SAVE.retryDelay
	local lastErr = "?"
	for attempt = 1, SAVE.retries + 1 do
		local steal = waited >= SAVE.loadWaitSeconds
		local blocked = false
		local ok, res = pcall(function()
			return st:UpdateAsync(key, function(old)
				old = type(old) == "table" and old or {}
				local lock = old.lock
				if type(lock) == "table" and lock.job ~= JOB_ID and not steal then
					local age = os.time() - (tonumber(lock.t) or 0)
					if age < SAVE.lockStaleSeconds then
						blocked = true
						return nil -- 다른 서버가 쓰는 중: 바꾸지 않고 기다림
					end
				end
				old.lock = { job = JOB_ID, t = os.time() }
				return old
			end)
		end)
		if ok and res then
			if type(res.lock) == "table" and res.lock.job == JOB_ID then
				return type(res.data) == "table" and res.data or {}, nil
			end
			lastErr = "lock mismatch"
		elseif ok and blocked then
			lastErr = "locked by another server"
			task.wait(2)
			waited += 2
		else
			lastErr = tostring(res)
			if lastErr:find("API Services") or lastErr:find("StudioAccessToApisNotAllowed") or lastErr:find("403") or lastErr:find("publish") then
				return nil, lastErr -- Studio에서 API 접근이 꺼져 있음: 재시도해도 안 됨
			end
			task.wait(delay)
			delay *= 2
		end
		if not player.Parent then
			return nil, "left"
		end
	end
	return nil, lastErr
end

-- 저장 (release면 잠금도 품). 반환: 성공 여부
local function saveRecord(player, profile, release)
	local st = getStore()
	if not st or not profile.canSave or profile.lost then
		return false
	end
	local key = keyFor(player)
	local payload = deepCopy(profile.data)
	local delay = SAVE.retryDelay
	for _ = 1, SAVE.retries + 1 do
		local lostLock = false
		local ok, err = pcall(function()
			st:UpdateAsync(key, function(old)
				old = type(old) == "table" and old or {}
				if type(old.lock) == "table" and old.lock.job ~= JOB_ID then
					lostLock = true
					return nil -- 다른 서버가 잠금을 가져감: 덮어쓰지 않음
				end
				old.data = payload
				old.lock = (not release) and { job = JOB_ID, t = os.time() } or nil
				return old
			end)
		end)
		if ok then
			if lostLock then
				profile.lost = true
				warn("[Data] lock lost, not saving", player.Name)
				return false
			end
			return true
		end
		warn("[Data] save failed", player.Name, err)
		task.wait(delay)
		delay *= 2
	end
	return false
end

function PlayerDataService.save(player, release)
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.released then
		return false
	end
	while profile.saving do
		task.wait(0.1)
	end
	if profile.released then
		return false
	end
	profile.saving = true
	if release then
		profile.released = true
	end
	inFlight += 1
	local ok = saveRecord(player, profile, release)
	inFlight -= 1
	profile.saving = false
	if ok then
		print(string.format("[Data] saved %s coins=%d lv=%d stock=%d%s", player.Name, profile.data.coins, profile.data.level, #profile.data.stock, release and " (release)" or ""))
	end
	return ok
end

-- 데이터 (불러오는 중이면 기다림, 실패/퇴장이면 nil)
function PlayerDataService.get(player, wait)
	local profile = profiles[player]
	if wait then
		local t = 0
		while player.Parent and (not profile or not profile.loaded) and t < 30 do
			task.wait(0.1)
			t += 0.1
			profile = profiles[player]
		end
	end
	return profile and profile.loaded and profile.data or nil
end

function PlayerDataService.canSave(player)
	local profile = profiles[player]
	return profile ~= nil and profile.canSave and not profile.lost
end

-- 데이터를 바꾸고 알림: fn(data)가 false를 돌려주면 바꾼 게 없다고 봄
function PlayerDataService.update(player, fn)
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	local r = fn(data)
	if r == false then
		return false
	end
	changed:Fire(player, data)
	-- 바뀐 뒤 changeSaveSeconds 안에 한 번 저장 (이미 예약돼 있으면 그대로; DataStore 쓰기 횟수 아낌)
	local profile = profiles[player]
	if profile and profile.canSave and not profile.saveQueued then
		profile.saveQueued = true
		task.delay(SAVE.changeSaveSeconds, function()
			profile.saveQueued = false
			if profiles[player] == profile and not profile.released then
				PlayerDataService.save(player, false)
			end
		end)
	end
	return true
end

local function onPlayerAdded(player)
	if profiles[player] then
		return
	end
	local profile = { loaded = false, canSave = false }
	profiles[player] = profile
	local raw, err = loadRecord(player)
	if not player.Parent then
		-- 불러오는 중에 나감: 잡은 잠금만 풀어 둠
		if raw then
			profile.data = migrate(raw)
			profile.loaded = true
			profile.canSave = true
			PlayerDataService.save(player, true)
		end
		profiles[player] = nil
		return
	end
	if raw then
		profile.data = migrate(raw)
		profile.canSave = true
	else
		warn("[Data] load failed, playing without save:", player.Name, err)
		profile.data = PlayerDataService.newData()
		profile.canSave = false
	end
	profile.loaded = true
	print(string.format("[Data] loaded %s v%d coins=%d lv=%d stock=%d save=%s", player.Name, profile.data.version, profile.data.coins, profile.data.level, #profile.data.stock, tostring(profile.canSave)))
	changed:Fire(player, profile.data)
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if profile and profile.loaded then
		PlayerDataService.save(player, true)
	end
	profiles[player] = nil
end

function PlayerDataService.init()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onPlayerAdded, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- 자동 저장: 플레이어마다 시간을 조금씩 나눠서
	task.spawn(function()
		while true do
			task.wait(SAVE.autosaveSeconds)
			local list = {}
			for p, prof in pairs(profiles) do
				if prof.loaded and not prof.released then
					table.insert(list, p)
				end
			end
			local gap = #list > 0 and math.min(1, SAVE.autosaveSeconds / (#list * 2)) or 0
			for _, p in ipairs(list) do
				task.spawn(PlayerDataService.save, p, false)
				task.wait(gap)
			end
		end
	end)

	game:BindToClose(function()
		-- 아직 안 푼 플레이어는 저장하고, PlayerRemoving에서 이미 시작된 저장도 끝날 때까지 기다린다
		for p, prof in pairs(profiles) do
			if prof.loaded and not prof.released then
				task.spawn(PlayerDataService.save, p, true)
			end
		end
		task.wait() -- 위 저장들이 inFlight를 올릴 시간
		local t0 = os.clock()
		while inFlight > 0 and os.clock() - t0 < SAVE.closeTimeout do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
