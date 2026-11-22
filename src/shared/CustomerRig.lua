-- 자동 생성: tools/blender/customers.py (손으로 고치지 말 것)
-- 손님 NPC 7종 리그. 좌표 = 손님 Root 기준 (Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X), 단위 stud.
-- parts[이름] = { center = 서 있을 때 부품(MeshPart) 가운데, size = 메시 크기, joint = 돌리는 관절 점 }
--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)
--   Head = 목, Body = 엉덩이 가운데, ArmL/ArmR = 어깨, LegL/LegR = 엉덩이 관절.
-- 메시는 Studio ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> (dalgona_customers.glb).
-- mouth = 입 앞 (먹기 연출), hand = 오른손(ArmR 끝) 가운데, height = 키.

return {
	order = { "Ppogeuli", "Kkuldanji", "Mochi", "Chunsik", "Dotori", "Owl", "Pongpong" },
	types = {
		Ppogeuli = {
			label = "뽀글이",
			height = 3.639,
			mouth = Vector3.new(-0.000, 2.170, -0.974),
			hand = Vector3.new(0.734, 0.828, -0.020),
			parts = {
				Head = { center = Vector3.new(0.007, 2.679, -0.019), size = Vector3.new(2.371, 1.919, 1.950), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(0.003, 1.225, 0.142), size = Vector3.new(1.663, 1.674, 1.742), joint = Vector3.new(-0.000, 0.700, 0.000) },
				ArmL = { center = Vector3.new(-0.724, 1.167, 0.010), size = Vector3.new(0.740, 1.206, 0.717), joint = Vector3.new(-0.734, 1.564, 0.000) },
				ArmR = { center = Vector3.new(0.744, 1.167, 0.010), size = Vector3.new(0.740, 1.206, 0.717), joint = Vector3.new(0.734, 1.564, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.491, -0.027), size = Vector3.new(0.820, 1.079, 0.867), joint = Vector3.new(-0.286, 0.700, 0.000) },
				LegR = { center = Vector3.new(0.296, 0.491, -0.027), size = Vector3.new(0.820, 1.079, 0.867), joint = Vector3.new(0.286, 0.700, 0.000) },
			},
		},
		Kkuldanji = {
			label = "꿀단지",
			height = 3.250,
			mouth = Vector3.new(-0.000, 1.944, -0.920),
			hand = Vector3.new(0.709, 0.728, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.362, -0.065), size = Vector3.new(1.800, 1.776, 1.730), joint = Vector3.new(-0.000, 1.650, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.125, 0.141), size = Vector3.new(1.265, 1.302, 1.348), joint = Vector3.new(-0.000, 0.600, 0.000) },
				ArmL = { center = Vector3.new(-0.709, 0.992, -0.050), size = Vector3.new(0.595, 1.056, 0.576), joint = Vector3.new(-0.709, 1.314, 0.000) },
				ArmR = { center = Vector3.new(0.709, 0.992, -0.050), size = Vector3.new(0.595, 1.056, 0.576), joint = Vector3.new(0.709, 1.314, 0.000) },
				LegL = { center = Vector3.new(-0.275, 0.435, -0.095), size = Vector3.new(0.580, 0.990, 0.731), joint = Vector3.new(-0.275, 0.600, 0.000) },
				LegR = { center = Vector3.new(0.275, 0.435, -0.095), size = Vector3.new(0.580, 0.990, 0.731), joint = Vector3.new(0.275, 0.600, 0.000) },
			},
		},
		Mochi = {
			label = "모찌",
			height = 3.899,
			mouth = Vector3.new(-0.000, 2.070, -0.805),
			hand = Vector3.new(0.620, 0.790, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.709, -0.017), size = Vector3.new(1.759, 2.380, 1.634), joint = Vector3.new(-0.000, 1.700, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.161, 0.000), size = Vector3.new(1.750, 1.461, 1.772), joint = Vector3.new(-0.000, 0.650, 0.000) },
				ArmL = { center = Vector3.new(-0.620, 1.121, -0.032), size = Vector3.new(0.496, 1.102, 0.516), joint = Vector3.new(-0.620, 1.420, 0.000) },
				ArmR = { center = Vector3.new(0.620, 1.121, -0.032), size = Vector3.new(0.496, 1.102, 0.516), joint = Vector3.new(0.620, 1.420, 0.000) },
				LegL = { center = Vector3.new(-0.242, 0.454, -0.101), size = Vector3.new(0.500, 0.972, 0.720), joint = Vector3.new(-0.242, 0.650, 0.000) },
				LegR = { center = Vector3.new(0.242, 0.454, -0.101), size = Vector3.new(0.500, 0.972, 0.720), joint = Vector3.new(0.242, 0.650, 0.000) },
			},
		},
		Chunsik = {
			label = "춘식이 아저씨",
			height = 3.869,
			mouth = Vector3.new(-0.000, 2.480, -0.947),
			hand = Vector3.new(0.762, 1.025, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.874, -0.048), size = Vector3.new(1.899, 1.991, 1.777), joint = Vector3.new(-0.000, 2.200, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.492, 0.204), size = Vector3.new(1.410, 1.741, 1.874), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.762, 1.407, -0.050), size = Vector3.new(0.620, 1.315, 0.600), joint = Vector3.new(-0.762, 1.850, 0.000) },
				ArmR = { center = Vector3.new(0.762, 1.407, -0.050), size = Vector3.new(0.620, 1.315, 0.600), joint = Vector3.new(0.762, 1.850, 0.000) },
				LegL = { center = Vector3.new(-0.308, 0.560, -0.098), size = Vector3.new(0.621, 1.279, 0.776), joint = Vector3.new(-0.297, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.308, 0.560, -0.098), size = Vector3.new(0.621, 1.279, 0.776), joint = Vector3.new(0.297, 0.850, 0.000) },
			},
		},
		Dotori = {
			label = "도토리",
			height = 3.033,
			mouth = Vector3.new(-0.000, 1.843, -0.881),
			hand = Vector3.new(0.591, 0.693, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.208, -0.050), size = Vector3.new(1.679, 1.651, 1.652), joint = Vector3.new(-0.000, 1.550, 0.000) },
				Body = { center = Vector3.new(-0.145, 1.599, 1.017), size = Vector3.new(1.347, 2.768, 3.204), joint = Vector3.new(-0.000, 0.550, 0.000) },
				ArmL = { center = Vector3.new(-0.591, 0.985, -0.032), size = Vector3.new(0.471, 1.076, 0.492), joint = Vector3.new(-0.591, 1.284, 0.000) },
				ArmR = { center = Vector3.new(0.591, 0.985, -0.032), size = Vector3.new(0.471, 1.076, 0.492), joint = Vector3.new(0.591, 1.284, 0.000) },
				LegL = { center = Vector3.new(-0.231, 0.398, -0.090), size = Vector3.new(0.480, 0.864, 0.640), joint = Vector3.new(-0.231, 0.550, 0.000) },
				LegR = { center = Vector3.new(0.231, 0.398, -0.090), size = Vector3.new(0.480, 0.864, 0.640), joint = Vector3.new(0.231, 0.550, 0.000) },
			},
		},
		Owl = {
			label = "부엉이",
			height = 3.965,
			mouth = Vector3.new(-0.000, 2.071, -0.920),
			hand = Vector3.new(0.852, 0.764, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.758, -0.082), size = Vector3.new(1.959, 2.414, 1.883), joint = Vector3.new(-0.000, 1.830, 0.000) },
				Body = { center = Vector3.new(0.000, 1.105, 0.025), size = Vector3.new(1.765, 1.798, 1.431), joint = Vector3.new(-0.000, 0.380, 0.000) },
				ArmL = { center = Vector3.new(-0.852, 1.087, -0.046), size = Vector3.new(0.546, 1.249, 0.298), joint = Vector3.new(-0.852, 1.522, 0.000) },
				ArmR = { center = Vector3.new(0.852, 1.087, -0.046), size = Vector3.new(0.546, 1.249, 0.298), joint = Vector3.new(0.852, 1.522, 0.000) },
				LegL = { center = Vector3.new(-0.341, 0.261, -0.125), size = Vector3.new(0.560, 0.558, 0.710), joint = Vector3.new(-0.341, 0.380, 0.000) },
				LegR = { center = Vector3.new(0.341, 0.261, -0.125), size = Vector3.new(0.560, 0.558, 0.710), joint = Vector3.new(0.341, 0.380, 0.000) },
			},
		},
		Pongpong = {
			label = "퐁퐁이",
			height = 3.120,
			mouth = Vector3.new(-0.000, 1.894, -1.009),
			hand = Vector3.new(0.617, 0.643, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.222, 0.000), size = Vector3.new(2.220, 1.796, 2.220), joint = Vector3.new(-0.000, 1.500, 0.000) },
				Body = { center = Vector3.new(0.068, 0.955, 0.000), size = Vector3.new(1.689, 1.341, 1.586), joint = Vector3.new(-0.000, 0.450, 0.000) },
				ArmL = { center = Vector3.new(-0.617, 0.954, -0.006), size = Vector3.new(0.471, 1.039, 0.441), joint = Vector3.new(-0.617, 1.234, 0.000) },
				ArmR = { center = Vector3.new(0.617, 0.954, -0.006), size = Vector3.new(0.471, 1.039, 0.441), joint = Vector3.new(0.617, 1.234, 0.000) },
				LegL = { center = Vector3.new(-0.242, 0.291, -0.112), size = Vector3.new(0.600, 0.619, 0.800), joint = Vector3.new(-0.242, 0.450, 0.000) },
				LegR = { center = Vector3.new(0.242, 0.291, -0.112), size = Vector3.new(0.600, 0.619, 0.800), joint = Vector3.new(0.242, 0.450, 0.000) },
			},
		},
	},
}
