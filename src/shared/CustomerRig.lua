-- 자동 생성: tools/blender/customers_ai.py (손으로 고치지 말 것)
-- 손님 NPC 7종 리그 (2026-11-25부터 사용자가 가져온 AI 모델을 부품으로 나눈 판). 좌표 = 손님 Root 기준
--   (Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X), 단위 stud.
-- parts[이름] = { center = 서 있을 때 부품(MeshPart) 가운데, size = 메시 크기, joint = 돌리는 관절 점 }
--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)
--   Head = 목, Body = 엉덩이 가운데, ArmL/ArmR = 어깨, LegL/LegR = 엉덩이 관절.
-- 메시는 Studio ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> (dalgona_customers_ai.glb).
-- mouth = 입 앞 (먹기 연출), hand = 오른손(ArmR 끝) 가운데, height = 키.

return {
	order = { "Ppogeuli", "Kkuldanji", "Mochi", "Godeungeo", "Dotori", "Owl", "Pongpong" },
	types = {
		Ppogeuli = {
			label = "뽀글이",
			height = 3.646,
			mouth = Vector3.new(-0.000, 2.335, -0.885),
			hand = Vector3.new(1.304, 1.100, 0.347),
			parts = {
				Head = { center = Vector3.new(0.003, 2.736, -0.057), size = Vector3.new(2.087, 1.820, 1.568), joint = Vector3.new(-0.000, 1.880, 0.000) },
				Body = { center = Vector3.new(0.003, 1.144, -0.047), size = Vector3.new(1.706, 1.562, 1.345), joint = Vector3.new(-0.000, 0.450, 0.000) },
				ArmL = { center = Vector3.new(-0.993, 1.380, -0.160), size = Vector3.new(0.665, 0.750, 0.711), joint = Vector3.new(-0.780, 1.550, 0.000) },
				ArmR = { center = Vector3.new(1.008, 1.406, 0.154), size = Vector3.new(0.680, 0.797, 0.558), joint = Vector3.new(0.780, 1.550, 0.000) },
				LegL = { center = Vector3.new(-0.290, 0.277, -0.059), size = Vector3.new(0.547, 0.512, 0.622), joint = Vector3.new(-0.315, 0.450, 0.000) },
				LegR = { center = Vector3.new(0.304, 0.256, 0.032), size = Vector3.new(0.543, 0.511, 0.673), joint = Vector3.new(0.315, 0.450, 0.000) },
			},
		},
		Kkuldanji = {
			label = "꿀단지",
			height = 3.074,
			mouth = Vector3.new(-0.000, 1.846, -0.790),
			hand = Vector3.new(0.949, 0.889, -0.023),
			parts = {
				Head = { center = Vector3.new(0.010, 2.222, -0.112), size = Vector3.new(1.558, 1.703, 1.255), joint = Vector3.new(-0.000, 1.420, 0.000) },
				Body = { center = Vector3.new(0.029, 0.831, 0.017), size = Vector3.new(1.489, 1.268, 1.179), joint = Vector3.new(-0.000, 0.420, 0.000) },
				ArmL = { center = Vector3.new(-0.748, 1.122, -0.089), size = Vector3.new(0.424, 0.469, 0.485), joint = Vector3.new(-0.620, 1.185, 0.000) },
				ArmR = { center = Vector3.new(0.715, 1.126, -0.009), size = Vector3.new(0.480, 0.558, 0.410), joint = Vector3.new(0.620, 1.185, 0.000) },
				LegL = { center = Vector3.new(-0.271, 0.283, -0.013), size = Vector3.new(0.396, 0.540, 0.528), joint = Vector3.new(-0.304, 0.420, 0.000) },
				LegR = { center = Vector3.new(0.265, 0.284, 0.008), size = Vector3.new(0.440, 0.567, 0.539), joint = Vector3.new(0.304, 0.420, 0.000) },
			},
		},
		Mochi = {
			label = "설기",
			height = 4.109,
			mouth = Vector3.new(-0.000, 2.447, -0.843),
			hand = Vector3.new(1.135, 1.068, 0.031),
			parts = {
				Head = { center = Vector3.new(-0.001, 2.975, 0.009), size = Vector3.new(1.647, 2.267, 1.604), joint = Vector3.new(-0.000, 1.880, 0.000) },
				Body = { center = Vector3.new(-0.007, 1.149, 0.032), size = Vector3.new(1.530, 1.579, 1.416), joint = Vector3.new(-0.000, 0.500, 0.000) },
				ArmL = { center = Vector3.new(-0.849, 1.365, 0.040), size = Vector3.new(0.618, 0.674, 0.507), joint = Vector3.new(-0.700, 1.550, 0.000) },
				ArmR = { center = Vector3.new(0.827, 1.356, 0.031), size = Vector3.new(0.616, 0.684, 0.499), joint = Vector3.new(0.700, 1.550, 0.000) },
				LegL = { center = Vector3.new(-0.299, 0.302, 0.011), size = Vector3.new(0.504, 0.583, 0.586), joint = Vector3.new(-0.291, 0.500, 0.000) },
				LegR = { center = Vector3.new(0.288, 0.278, 0.000), size = Vector3.new(0.529, 0.556, 0.596), joint = Vector3.new(0.291, 0.500, 0.000) },
			},
		},
		Godeungeo = {
			label = "고등어 아저씨",
			height = 3.790,
			mouth = Vector3.new(-0.000, 2.612, -0.969),
			hand = Vector3.new(1.331, 1.332, 0.053),
			parts = {
				Head = { center = Vector3.new(-0.011, 2.927, -0.157), size = Vector3.new(1.844, 1.726, 1.555), joint = Vector3.new(-0.000, 2.180, 0.000) },
				Body = { center = Vector3.new(0.046, 1.308, 0.923), size = Vector3.new(1.868, 1.981, 3.713), joint = Vector3.new(-0.000, 0.550, 0.000) },
				ArmL = { center = Vector3.new(-1.016, 1.729, 0.095), size = Vector3.new(0.705, 0.860, 0.536), joint = Vector3.new(-0.820, 1.915, 0.000) },
				ArmR = { center = Vector3.new(1.005, 1.699, 0.093), size = Vector3.new(0.725, 0.808, 0.537), joint = Vector3.new(0.820, 1.915, 0.000) },
				LegL = { center = Vector3.new(-0.370, 0.367, -0.016), size = Vector3.new(0.717, 0.732, 0.906), joint = Vector3.new(-0.370, 0.550, 0.000) },
				LegR = { center = Vector3.new(0.372, 0.346, -0.020), size = Vector3.new(0.710, 0.692, 0.922), joint = Vector3.new(0.370, 0.550, 0.000) },
			},
		},
		Dotori = {
			label = "도토리",
			height = 3.057,
			mouth = Vector3.new(-0.000, 1.998, -0.743),
			hand = Vector3.new(0.799, 1.012, 0.014),
			parts = {
				Head = { center = Vector3.new(-0.014, 2.302, 0.647), size = Vector3.new(1.224, 1.511, 2.829), joint = Vector3.new(-0.000, 1.620, 0.000) },
				Body = { center = Vector3.new(-0.040, 1.098, 0.637), size = Vector3.new(1.411, 1.227, 2.435), joint = Vector3.new(-0.000, 0.550, 0.000) },
				ArmL = { center = Vector3.new(-0.608, 1.292, 0.043), size = Vector3.new(0.448, 0.597, 0.363), joint = Vector3.new(-0.550, 1.375, 0.000) },
				ArmR = { center = Vector3.new(0.600, 1.284, 0.040), size = Vector3.new(0.460, 0.570, 0.367), joint = Vector3.new(0.550, 1.375, 0.000) },
				LegL = { center = Vector3.new(-0.180, 0.312, -0.013), size = Vector3.new(0.462, 0.621, 0.478), joint = Vector3.new(-0.224, 0.550, 0.000) },
				LegR = { center = Vector3.new(0.195, 0.328, 0.008), size = Vector3.new(0.459, 0.655, 0.464), joint = Vector3.new(0.224, 0.550, 0.000) },
			},
		},
		Owl = {
			label = "부엉이",
			height = 3.834,
			mouth = Vector3.new(-0.000, 2.394, -0.894),
			hand = Vector3.new(1.122, 0.726, 0.611),
			parts = {
				Head = { center = Vector3.new(0.037, 2.847, -0.001), size = Vector3.new(1.775, 1.974, 1.686), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(0.002, 1.100, 0.078), size = Vector3.new(2.569, 1.679, 1.732), joint = Vector3.new(-0.000, 0.280, 0.000) },
				ArmL = { center = Vector3.new(-1.275, 1.183, 0.086), size = Vector3.new(0.687, 1.010, 1.033), joint = Vector3.new(-1.050, 1.265, 0.000) },
				ArmR = { center = Vector3.new(1.207, 1.141, -0.029), size = Vector3.new(0.518, 1.162, 1.280), joint = Vector3.new(1.050, 1.265, 0.000) },
				LegL = { center = Vector3.new(-0.429, 0.155, 0.005), size = Vector3.new(0.549, 0.308, 0.739), joint = Vector3.new(-0.368, 0.280, 0.000) },
				LegR = { center = Vector3.new(0.419, 0.162, -0.002), size = Vector3.new(0.569, 0.324, 0.745), joint = Vector3.new(0.368, 0.280, 0.000) },
			},
		},
		Pongpong = {
			label = "퐁퐁이",
			height = 2.991,
			mouth = Vector3.new(-0.000, 1.868, -0.972),
			hand = Vector3.new(0.966, 0.891, -0.325),
			parts = {
				Head = { center = Vector3.new(0.037, 2.215, 0.035), size = Vector3.new(1.729, 1.551, 1.916), joint = Vector3.new(-0.000, 1.480, 0.000) },
				Body = { center = Vector3.new(0.003, 0.849, 0.039), size = Vector3.new(1.771, 1.330, 1.470), joint = Vector3.new(-0.000, 0.320, 0.000) },
				ArmL = { center = Vector3.new(-0.743, 1.185, -0.050), size = Vector3.new(0.481, 0.549, 0.935), joint = Vector3.new(-0.720, 1.200, 0.000) },
				ArmR = { center = Vector3.new(0.812, 1.134, -0.157), size = Vector3.new(0.449, 0.541, 0.528), joint = Vector3.new(0.720, 1.200, 0.000) },
				LegL = { center = Vector3.new(-0.301, 0.202, 0.072), size = Vector3.new(0.413, 0.404, 0.452), joint = Vector3.new(-0.274, 0.320, 0.000) },
				LegR = { center = Vector3.new(0.324, 0.207, -0.029), size = Vector3.new(0.367, 0.405, 0.537), joint = Vector3.new(0.274, 0.320, 0.000) },
			},
		},
	},
}
