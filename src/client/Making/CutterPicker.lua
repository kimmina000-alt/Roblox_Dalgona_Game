-- 도안 고르기 (제작 시작 전, 결과 화면의 "다른 도안")
-- 도안 카드 격자: 틀 모양(3D 미리 보기), 이름, 등급, 가격. 누르면 그 도안으로 시작.
-- 틀 메시는 ReplicatedStorage.Assets.Cutters. 목록·가격은 Shared.ShapeCatalog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Picker = {}

-- 2026-11-22 새 스타일(shared/UiStyle): 나무 판 + 크림 카드, 둥근 굵은 글꼴
local UI = require(Shared:WaitForChild("UiStyle"))
local CREAM = UI.C.cream
local INK = UI.C.ink

local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end

local function corner(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

-- 카드 안 3D 미리 보기: 틀 위에서 내려다봄 (모양 부분이 가운데, 손잡이는 아래로 잘림)
local function preview(parent, entry)
	local vpf = new("ViewportFrame", {
		Name = "Preview",
		BackgroundColor3 = Color3.fromRGB(226, 172, 96), -- 달고나 색 바탕
		Ambient = Color3.fromRGB(190, 190, 195),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Size = UDim2.new(1, -12, 1, -52),
		Position = UDim2.fromOffset(6, 6),
		ZIndex = 33,
		Parent = parent,
	})
	corner(vpf, 10)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Cutters")
	local tpl = folder and folder:FindFirstChild("Cutter_" .. entry.id)
	if tpl then
		local mesh = tpl:Clone()
		for _, c in ipairs(mesh:GetChildren()) do
			c:Destroy() -- 금속 광택 텍스처는 미리 보기에선 어둡게 나와서 뺌
		end
		mesh.Material = Enum.Material.SmoothPlastic
		mesh.Color = Color3.fromRGB(70, 60, 52)
		local c = entry.data.center
		mesh.CFrame = CFrame.new(c.X, 0, -c.Y) * CFrame.Angles(0, math.pi, 0)
		mesh.Parent = vpf
	end
	local cam = new("Camera", { FieldOfView = 22, Parent = vpf })
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, 0), Vector3.zero, Vector3.new(0, 0, -1))
	vpf.CurrentCamera = cam
end

-- 반환: ShapeCatalog 항목, 또는 nil (중간에 나감)
function Picker.run(ctx, currentId)
	local ui = ctx.ui
	local chosen = nil

	local quality = ui.root:FindFirstChild("Quality")
	local qualityWas = quality and quality.Visible
	if quality then
		quality.Visible = false
	end
	ui:say("어떤 모양으로 만들까요?", "어려운 도안일수록 비싸게 팔려요")

	local dim = new("Frame", {
		Name = "CutterPickerDim",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = ui.root,
	})
	local panel = new("Frame", {
		Name = "CutterPicker",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0.94, 0, 0.8, 0),
		BackgroundColor3 = UI.C.wood,
		ZIndex = 31,
		Parent = ui.root,
	})
	corner(panel, 20)
	new("UIStroke", { Color = UI.C.woodDark, Thickness = 4, Parent = panel })
	UI.gloss(0.2).Parent = panel
	local title = new("TextLabel", {
		Text = "도안 고르기",
		FontFace = UI.F.heavy,
		TextSize = 26,
		TextColor3 = UI.C.cream,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(0.5, 0, 0, 34),
		ZIndex = 32,
		Parent = panel,
	})
	UI.stroke(UI.C.woodDark, 2.5, true).Parent = title
	new("TextLabel", {
		Text = "등급이 높을수록 선이 많고 어려워요",
		FontFace = UI.F.bold,
		TextSize = 16,
		TextColor3 = UI.C.tan,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 8),
		Size = UDim2.new(0.5, -18, 0, 34),
		ZIndex = 32,
		Parent = panel,
	})
	local scroll = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 1, -54),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.C.cream,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 32,
		Parent = panel,
	})
	local cols = 6
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / cols, -8, 0, 150),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	new("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 6), Parent = scroll })

	for i, entry in ipairs(ShapeCatalog.list) do
		local g = ShapeCatalog.grade(entry.grade)
		local card = new("TextButton", {
			Name = entry.id,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = CREAM,
			LayoutOrder = i,
			ZIndex = 32,
			Parent = scroll,
		})
		corner(card, 12)
		new("UIStroke", {
			Color = g.color,
			Thickness = entry.id == currentId and 4 or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = card,
		})
		preview(card, entry)
		new("TextLabel", {
			Text = entry.name,
			FontFace = UI.F.heavy,
			TextSize = 17,
			TextScaled = false,
			TextColor3 = INK,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 1, -45),
			Size = UDim2.new(1, -8, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 33,
			Parent = card,
		})
		local tag = new("TextLabel", {
			Text = string.format("%s · %d코인", g.label, entry.price),
			FontFace = UI.F.heavy,
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = g.color,
			Position = UDim2.new(0, 8, 1, -24),
			Size = UDim2.new(1, -16, 0, 19),
			ZIndex = 33,
			Parent = card,
		})
		corner(tag, 8)
		-- 도안 해금 (성장 Phase 4, 2026-11-20): 서버가 준 목록(속성 UnlockedShapes)에 없으면 잠금
		local unlockedAttr = game:GetService("Players").LocalPlayer:GetAttribute("UnlockedShapes")
		local locked = type(unlockedAttr) == "string" and not table.find(string.split(unlockedAttr, ","), entry.id)
		if locked then
			local G = require(Shared:WaitForChild("GrowthConfig"))
			local need = G.UnlockLevel[entry.grade]
			local cover = new("TextLabel", {
				Text = need and ("🔒 Lv" .. need) or "🔒 도감",
				FontFace = UI.F.heavy,
				TextSize = 18,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundColor3 = Color3.fromRGB(40, 30, 24),
				BackgroundTransparency = 0.35,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 34,
				Parent = card,
			})
			corner(cover, 12)
		end
		card.Activated:Connect(function()
			if locked then
				return
			end
			Sfx.play("pop", 0.6, 1.1)
			chosen = entry
		end)
	end

	while not chosen do
		local dt = ctx.frame()
		if not dt then
			break
		end
	end
	dim:Destroy()
	panel:Destroy()
	if quality then
		quality.Visible = qualityWas
	end
	return chosen
end

return Picker
