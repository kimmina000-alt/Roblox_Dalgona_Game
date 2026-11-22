-- 편집 화면에서 고친 모양 틀을 코드로 만든 모델에 옮기기 (2026-11-22 사용자 "부지 수정할 수 있게", 판매 세션)
-- 쓰는 곳: PlotService(가게 부지·진열대), FactoryDisplay(공장 부지 울타리), MachineDisplay(기계 단계별)
--  - tag(root, from): from(기본 root) 아래 BasePart마다 속성 LayoutKey = root 기준 경로("A/B/이름") + "#" + 같은 경로에서 몇 번째
--  - apply(built, template, fromCF, toCF, opts): template 안 부품을 fromCF 기준 → toCF 기준으로 옮겨, built 안 같은 LayoutKey 부품에
--    위치·크기·색·재질·투명도·모양(Part)·CFrame 속성을 복사. 틀에 새로 넣은 부품(LayoutKey 없음)은 복제해 넣고,
--    틀에서 지운 부품은 지움 (opts.keep(part)가 true면 숨기기만: 안내·판정에 꼭 필요한 부품)
--    opts.skip(tp): true면 그 틀 부품은 무시 (다른 곳에서 따로 옮기는 묶음)

local L = {}

local SKIP_ATTR = { AnimBase = true } -- 클라이언트가 움직임 기준으로 적는 값

local function pathOf(d, root)
	local names = {}
	local a = d
	while a and a ~= root do
		table.insert(names, 1, a.Name)
		a = a.Parent
	end
	return table.concat(names, "/")
end

function L.tag(root, from)
	local count = {}
	local list = (from or root):GetDescendants()
	if from and from:IsA("BasePart") then
		table.insert(list, 1, from)
	end
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			local path = pathOf(d, root)
			count[path] = (count[path] or 0) + 1
			d:SetAttribute("LayoutKey", path .. "#" .. count[path])
		end
	end
end

function L.apply(built, template, fromCF, toCF, opts)
	opts = opts or {}
	local function place(cf)
		return toCF * fromCF:ToObjectSpace(cf)
	end
	local have = {}
	for _, d in ipairs(built:GetDescendants()) do
		local key = d:IsA("BasePart") and d:GetAttribute("LayoutKey")
		if key then
			have[key] = d
		end
	end
	local seen = {}
	for _, tp in ipairs(template:GetDescendants()) do
		if tp:IsA("BasePart") and not (opts.skip and opts.skip(tp)) then
			local key = tp:GetAttribute("LayoutKey")
			local target = key and have[key]
			if target then
				seen[key] = true
				target.CFrame = place(tp.CFrame)
				target.Size = tp.Size
				target.Color = tp.Color
				target.Material = tp.Material
				target.Transparency = tp.Transparency
				if target:IsA("Part") and tp:IsA("Part") then
					target.Shape = tp.Shape
				end
				for name, v in pairs(tp:GetAttributes()) do
					if typeof(v) == "CFrame" and not SKIP_ATTR[name] then
						target:SetAttribute(name, place(v))
					end
				end
			elseif not key then
				-- 틀에 새로 넣은 부품: 같은 이름의 부모가 있으면 그 아래, 없으면 built 바로 아래
				local copy = tp:Clone()
				copy.CFrame = place(tp.CFrame)
				copy.Anchored = true
				local parent = built
				if tp.Parent ~= template then
					parent = built:FindFirstChild(tp.Parent.Name, true) or built
				end
				copy.Parent = parent
			end
		end
	end
	for key, d in pairs(have) do
		if not seen[key] and d.Parent then
			if opts.keep and opts.keep(d) then
				d.Transparency = 1
				d.CanCollide = false
				-- 숨긴 부품 위 글씨·그림도 끔 (안 그러면 글씨만 떠 보임, 2026-11-23)
				for _, g in ipairs(d:GetDescendants()) do
					if g:IsA("SurfaceGui") or g:IsA("BillboardGui") then
						g.Enabled = false
					elseif g:IsA("Decal") or g:IsA("Texture") then
						g.Transparency = 1
					end
				end
			else
				d:Destroy()
			end
		end
	end
end

return L
