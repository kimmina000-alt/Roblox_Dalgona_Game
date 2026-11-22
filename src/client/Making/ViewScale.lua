-- 가게 안 손 작업대를 내 화면에서만 작게 보이기 (2026-11-22 사용자: "가게 안에 있는 손 제작대 테이블 크기 전체적으로 1/2,
-- 달고나 만들 때 테이블 크기나 화면은 수정하지 말고"). 판매 세션이 만듦, 제작 세션 MakingClient·HelperLadles가 씀.
--  - 서버 작업대(크기·위치·속성 GrillTopY·Center 등)는 그대로. 내 화면에서만 부품 CFrame·Size를 바닥 가운데 기준으로 줄임
--  - 서버 속성 AtInside = true(월세 내고 가게 안 자리)인 작업대만 줄임. 노점(가게 밖)일 때는 원래 크기
--  - 기준점 = 서버 속성 ViewOrigin (Vector3, 작업대 바닥 가운데, PlotService.placeWorkstation이 넣음)
--  - 줄인 동안 작업대에 내 화면 속성 ViewScale(숫자, 줄였으면 SCALE, 아니면 1)을 넣음 → HelperLadles가 Center를
--    ViewOrigin + (Center - ViewOrigin) * ViewScale 로 줄여 씀
--  - ViewScale.setFull(ws, true): 원래 크기로 (제작 시작: MakingClient가 setUnturned(true) 바로 앞에서 부름)
--    ViewScale.setFull(ws, false): 다시 줄임 (제작 끝: setUnturned(false) 바로 뒤)
--  - 서버가 줄인 동안 값을 바꾸면(연탄 setCoal, 새 부품, 작업대 옮김) 그 값을 원래 크기 값으로 기억하고 다시 줄임.
--    신호가 늦게 오므로(Deferred) 내가 넣은 값과 같으면 넘어감 (두 자리를 오가는 반복 방지)
--  - 알바생 국자(HelperLadle*)는 HelperLadles가 매 프레임 놓으므로 건드리지 않음

local SCALE = 0.5

local ViewScale = {}
ViewScale.SCALE = SCALE

local states = {} -- [ws] = { full, base = {[part] = {cf, size, att = {[att] = pos}, mesh = {[mesh] = {scale, offset}}}}, mine = {[part] = {cf, size}}, conns }

local function skip(ws, d)
	local a = d
	while a and a ~= ws do
		if a.Name:sub(1, 11) == "HelperLadle" then
			return true
		end
		a = a.Parent
	end
	return false
end

local function shouldScale(ws, st)
	return not st.full and ws:GetAttribute("AtInside") == true and typeof(ws:GetAttribute("ViewOrigin")) == "Vector3"
end

local function same(p, rec)
	return rec and (p.Position - rec.cf.Position).Magnitude < 1e-3 and p.CFrame.LookVector:Dot(rec.cf.LookVector) > 0.9999 and (p.Size - rec.size).Magnitude < 1e-3
end

-- 지금 값(원래 크기라고 보고)을 기억
local function remember(st, p)
	local b = { cf = p.CFrame, size = p.Size, att = {}, mesh = {} }
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("Attachment") then
			b.att[c] = c.Position
		elseif c:IsA("SpecialMesh") or c:IsA("BlockMesh") or c:IsA("CylinderMesh") then
			b.mesh[c] = { scale = c.Scale, offset = c.Offset }
		end
	end
	st.base[p] = b
end

local function put(st, p, cf, size)
	st.mine[p] = { cf = cf, size = size }
	p.Size = size
	p.CFrame = cf
end

local function scalePart(ws, st, p)
	local b = st.base[p]
	if not b then
		return
	end
	local o = ws:GetAttribute("ViewOrigin")
	local pos = o + (b.cf.Position - o) * SCALE
	put(st, p, CFrame.new(pos) * b.cf.Rotation, b.size * SCALE)
	for a, v in pairs(b.att) do
		if a.Parent == p then
			a.Position = v * SCALE
		end
	end
	for m, v in pairs(b.mesh) do
		if m.Parent == p then
			if m:IsA("SpecialMesh") and m.MeshType == Enum.MeshType.FileMesh then
				m.Scale = v.scale * SCALE
			end
			m.Offset = v.offset * SCALE
		end
	end
end

local function restorePart(st, p)
	local b = st.base[p]
	if not b then
		return
	end
	put(st, p, b.cf, b.size)
	for a, v in pairs(b.att) do
		if a.Parent == p then
			a.Position = v
		end
	end
	for m, v in pairs(b.mesh) do
		if m.Parent == p then
			m.Scale = v.scale
			m.Offset = v.offset
		end
	end
end

local function applyAll(ws, st)
	local on = shouldScale(ws, st)
	-- 내가 넣은 값이 아닌 부품 = 서버가 새로 보낸 원래 크기 값 (작업대를 옮기면 속성과 위치가 같이 옴, 순서는 모름)
	for p in pairs(st.base) do
		if p.Parent and not same(p, st.mine[p]) then
			remember(st, p)
		end
	end
	for p in pairs(st.base) do
		if p.Parent then
			if on then
				scalePart(ws, st, p)
			else
				restorePart(st, p)
			end
		else
			st.base[p] = nil
			st.mine[p] = nil
		end
	end
	st.scaled = on
	ws:SetAttribute("ViewScale", on and SCALE or 1) -- 내 화면에서만 (HelperLadles가 씀)
end

-- 부품 하나 지켜보기: 내가 넣은 값이 아니면 서버(또는 다른 스크립트)가 바꾼 원래 크기 값
local function watch(ws, st, p)
	if st.base[p] or skip(ws, p) then
		return
	end
	remember(st, p)
	local function changed()
		if st.full or not st.scaled then
			return
		end
		if same(p, st.mine[p]) then
			return
		end
		remember(st, p)
		scalePart(ws, st, p)
	end
	table.insert(st.conns, p:GetPropertyChangedSignal("CFrame"):Connect(changed))
	table.insert(st.conns, p:GetPropertyChangedSignal("Size"):Connect(changed))
	if st.scaled then
		scalePart(ws, st, p)
	end
end

function ViewScale.track(ws)
	if states[ws] then
		return states[ws]
	end
	local st = { full = false, scaled = false, base = setmetatable({}, { __mode = "k" }), mine = setmetatable({}, { __mode = "k" }), conns = {} }
	states[ws] = st
	for _, d in ipairs(ws:GetDescendants()) do
		if d:IsA("BasePart") then
			watch(ws, st, d)
		end
	end
	table.insert(st.conns, ws.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			watch(ws, st, d)
		end
	end))
	-- 가게 안·밖이 바뀌거나 기준점이 바뀌면(작업대를 옮김) 다시
	local function re()
		if st.full then
			return
		end
		applyAll(ws, st)
	end
	table.insert(st.conns, ws:GetAttributeChangedSignal("AtInside"):Connect(re))
	table.insert(st.conns, ws:GetAttributeChangedSignal("ViewOrigin"):Connect(re))
	table.insert(st.conns, ws.AncestryChanged:Connect(function(_, parent)
		if not parent then
			for _, c in ipairs(st.conns) do
				c:Disconnect()
			end
			states[ws] = nil
		end
	end))
	applyAll(ws, st)
	return st
end

-- true = 원래 크기 (제작 중), false = 다시 줄임
function ViewScale.setFull(ws, on)
	if not ws then
		return
	end
	local st = states[ws] or ViewScale.track(ws)
	if on then
		st.full = true
		applyAll(ws, st) -- 기억한 원래 크기 값으로 (줄이지 않음)
	else
		st.full = false
		-- 제작 중에 서버·제작 화면이 바꾼 값까지 지금 값이 원래 크기 값
		for p in pairs(st.base) do
			if p.Parent then
				remember(st, p)
			end
		end
		applyAll(ws, st)
	end
end

-- 모든 가게 작업대를 지켜봄 (WorkstationScale.client.lua가 한 번 부름)
function ViewScale.start()
	local function hookPlot(plot)
		local function try(c)
			if c.Name == "Workstation" and c:IsA("Model") then
				task.defer(ViewScale.track, c)
			end
		end
		for _, c in ipairs(plot:GetChildren()) do
			try(c)
		end
		plot.ChildAdded:Connect(try)
	end
	task.spawn(function()
		local plots = workspace:WaitForChild("ShopPlots")
		for _, p in ipairs(plots:GetChildren()) do
			hookPlot(p)
		end
		plots.ChildAdded:Connect(hookPlot)
	end)
end

return ViewScale
