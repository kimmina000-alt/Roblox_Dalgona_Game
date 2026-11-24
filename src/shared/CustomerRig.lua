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
			mouth = Vector3.new(-0.000, 2.322, -0.885),
			hand = Vector3.new(1.258, 1.097, 0.189),
			parts = {
				Head = { center = Vector3.new(-0.017, 2.763, -0.057), size = Vector3.new(2.127, 1.766, 1.568), joint = Vector3.new(-0.000, 1.880, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.165, -0.047), size = Vector3.new(1.560, 1.430, 1.345), joint = Vector3.new(-0.000, 0.450, 0.000) },
				ArmL = { center = Vector3.new(-0.920, 1.415, -0.157), size = Vector3.new(0.647, 0.734, 0.717), joint = Vector3.new(-0.780, 1.650, -0.105) },
				ArmR = { center = Vector3.new(0.941, 1.408, 0.154), size = Vector3.new(0.682, 0.732, 0.558), joint = Vector3.new(0.780, 1.630, 0.110) },
				LegL = { center = Vector3.new(-0.290, 0.235, -0.058), size = Vector3.new(0.547, 0.429, 0.621), joint = Vector3.new(-0.314, 0.450, 0.000) },
				LegR = { center = Vector3.new(0.302, 0.225, 0.032), size = Vector3.new(0.541, 0.450, 0.673), joint = Vector3.new(0.314, 0.450, 0.000) },
			},
		},
		Kkuldanji = {
			label = "꿀단지",
			height = 3.074,
			mouth = Vector3.new(-0.000, 1.834, -0.790),
			hand = Vector3.new(0.828, 0.881, -0.023),
			parts = {
				Head = { center = Vector3.new(0.010, 2.247, -0.112), size = Vector3.new(1.558, 1.654, 1.255), joint = Vector3.new(-0.000, 1.420, 0.000) },
				Body = { center = Vector3.new(-0.000, 0.920, 0.021), size = Vector3.new(1.240, 1.000, 1.169), joint = Vector3.new(-0.000, 0.420, 0.000) },
				ArmL = { center = Vector3.new(-0.678, 1.141, -0.094), size = Vector3.new(0.419, 0.432, 0.474), joint = Vector3.new(-0.620, 1.273, -0.089) },
				ArmR = { center = Vector3.new(0.679, 1.115, -0.010), size = Vector3.new(0.424, 0.468, 0.408), joint = Vector3.new(0.620, 1.263, -0.025) },
				LegL = { center = Vector3.new(-0.273, 0.216, -0.013), size = Vector3.new(0.393, 0.407, 0.528), joint = Vector3.new(-0.308, 0.420, 0.000) },
				LegR = { center = Vector3.new(0.267, 0.210, 0.008), size = Vector3.new(0.426, 0.420, 0.539), joint = Vector3.new(0.308, 0.420, 0.000) },
			},
		},
		Mochi = {
			label = "설기",
			height = 4.109,
			mouth = Vector3.new(-0.000, 2.437, -0.843),
			hand = Vector3.new(0.986, 1.045, -0.028),
			parts = {
				Head = { center = Vector3.new(-0.001, 2.995, 0.009), size = Vector3.new(1.647, 2.229, 1.604), joint = Vector3.new(-0.000, 1.880, 0.000) },
				Body = { center = Vector3.new(-0.013, 1.190, 0.032), size = Vector3.new(1.541, 1.380, 1.416), joint = Vector3.new(-0.000, 0.500, 0.000) },
				ArmL = { center = Vector3.new(-0.804, 1.398, 0.040), size = Vector3.new(0.616, 0.693, 0.507), joint = Vector3.new(-0.700, 1.606, 0.031) },
				ArmR = { center = Vector3.new(0.771, 1.393, 0.030), size = Vector3.new(0.608, 0.695, 0.498), joint = Vector3.new(0.700, 1.624, 0.003) },
				LegL = { center = Vector3.new(-0.295, 0.255, 0.008), size = Vector3.new(0.505, 0.490, 0.582), joint = Vector3.new(-0.305, 0.500, 0.000) },
				LegR = { center = Vector3.new(0.289, 0.250, 0.000), size = Vector3.new(0.524, 0.500, 0.595), joint = Vector3.new(0.305, 0.500, 0.000) },
			},
		},
		Godeungeo = {
			label = "고등어 아저씨",
			height = 3.790,
			mouth = Vector3.new(-0.000, 2.582, -0.969),
			hand = Vector3.new(1.330, 1.333, 0.053),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.985, -0.157), size = Vector3.new(1.960, 1.610, 1.555), joint = Vector3.new(-0.000, 2.180, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.365, 0.929), size = Vector3.new(1.640, 1.630, 3.701), joint = Vector3.new(-0.000, 0.550, 0.000) },
				ArmL = { center = Vector3.new(-0.977, 1.711, 0.091), size = Vector3.new(0.674, 0.768, 0.528), joint = Vector3.new(-0.820, 1.981, 0.142) },
				ArmR = { center = Vector3.new(1.027, 1.682, 0.089), size = Vector3.new(0.678, 0.772, 0.528), joint = Vector3.new(0.820, 1.917, 0.108) },
				LegL = { center = Vector3.new(-0.359, 0.276, -0.005), size = Vector3.new(0.690, 0.549, 0.883), joint = Vector3.new(-0.364, 0.550, 0.000) },
				LegR = { center = Vector3.new(0.362, 0.275, -0.005), size = Vector3.new(0.690, 0.550, 0.893), joint = Vector3.new(0.364, 0.550, 0.000) },
			},
		},
		Dotori = {
			label = "도토리",
			height = 3.057,
			mouth = Vector3.new(-0.000, 1.979, -0.743),
			hand = Vector3.new(0.755, 1.035, 0.014),
			parts = {
				Head = { center = Vector3.new(-0.014, 2.339, 0.647), size = Vector3.new(1.224, 1.437, 2.829), joint = Vector3.new(-0.000, 1.620, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.085, 0.634), size = Vector3.new(1.100, 1.070, 2.429), joint = Vector3.new(-0.000, 0.550, 0.000) },
				ArmL = { center = Vector3.new(-0.612, 1.247, 0.045), size = Vector3.new(0.400, 0.487, 0.356), joint = Vector3.new(-0.550, 1.400, 0.033) },
				ArmR = { center = Vector3.new(0.588, 1.262, 0.044), size = Vector3.new(0.395, 0.480, 0.351), joint = Vector3.new(0.550, 1.429, 0.031) },
				LegL = { center = Vector3.new(-0.178, 0.276, -0.001), size = Vector3.new(0.459, 0.549, 0.484), joint = Vector3.new(-0.220, 0.550, 0.000) },
				LegR = { center = Vector3.new(0.189, 0.275, -0.004), size = Vector3.new(0.447, 0.550, 0.477), joint = Vector3.new(0.220, 0.550, 0.000) },
			},
		},
		Owl = {
			label = "부엉이",
			height = 3.834,
			mouth = Vector3.new(-0.000, 2.384, -0.894),
			hand = Vector3.new(1.455, 1.484, -0.669),
			parts = {
				Head = { center = Vector3.new(0.037, 2.867, -0.001), size = Vector3.new(1.775, 1.934, 1.686), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(0.002, 1.090, 0.078), size = Vector3.new(2.569, 1.620, 1.732), joint = Vector3.new(-0.000, 0.280, 0.000) },
				ArmL = { center = Vector3.new(-1.334, 1.265, 0.095), size = Vector3.new(0.568, 0.830, 1.051), joint = Vector3.new(-1.050, 1.247, 0.143) },
				ArmR = { center = Vector3.new(1.258, 1.265, -0.042), size = Vector3.new(0.416, 0.830, 1.254), joint = Vector3.new(1.050, 1.310, 0.046) },
				LegL = { center = Vector3.new(-0.428, 0.140, 0.005), size = Vector3.new(0.552, 0.279, 0.739), joint = Vector3.new(-0.360, 0.280, 0.000) },
				LegR = { center = Vector3.new(0.417, 0.140, -0.002), size = Vector3.new(0.573, 0.280, 0.745), joint = Vector3.new(0.360, 0.280, 0.000) },
			},
		},
		Pongpong = {
			label = "퐁퐁이",
			height = 2.991,
			mouth = Vector3.new(-0.000, 1.858, -0.972),
			hand = Vector3.new(0.908, 0.921, -0.325),
			parts = {
				Head = { center = Vector3.new(0.037, 2.235, 0.035), size = Vector3.new(1.729, 1.511, 1.916), joint = Vector3.new(-0.000, 1.480, 0.000) },
				Body = { center = Vector3.new(-0.069, 0.900, 0.039), size = Vector3.new(1.626, 1.160, 1.470), joint = Vector3.new(-0.000, 0.320, 0.000) },
				ArmL = { center = Vector3.new(-0.747, 1.108, -0.035), size = Vector3.new(0.468, 0.394, 0.908), joint = Vector3.new(-0.720, 1.203, 0.130) },
				ArmR = { center = Vector3.new(0.778, 1.124, -0.150), size = Vector3.new(0.400, 0.461, 0.543), joint = Vector3.new(0.720, 1.271, -0.113) },
				LegL = { center = Vector3.new(-0.301, 0.160, 0.072), size = Vector3.new(0.413, 0.320, 0.452), joint = Vector3.new(-0.268, 0.320, 0.000) },
				LegR = { center = Vector3.new(0.324, 0.162, -0.029), size = Vector3.new(0.367, 0.316, 0.537), joint = Vector3.new(0.268, 0.320, 0.000) },
			},
		},
	},
}
