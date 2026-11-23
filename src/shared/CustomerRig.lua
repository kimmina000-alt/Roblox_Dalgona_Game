-- 자동 생성: tools/blender/customers.py (손으로 고치지 말 것)
-- 손님 NPC 7종 리그. 좌표 = 손님 Root 기준 (Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X), 단위 stud.
-- parts[이름] = { center = 서 있을 때 부품(MeshPart) 가운데, size = 메시 크기, joint = 돌리는 관절 점 }
--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)
--   Head = 목, Body = 엉덩이 가운데, ArmL/ArmR = 어깨, LegL/LegR = 엉덩이 관절.
-- 메시는 Studio ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> (dalgona_customers.glb).
-- mouth = 입 앞 (먹기 연출), hand = 오른손(ArmR 끝) 가운데, height = 키.

return {
	order = { "Ppogeuli", "Kkuldanji", "Mochi", "Godeungeo", "Dotori", "Owl", "Pongpong" },
	types = {
		Ppogeuli = {
			label = "뽀글이",
			height = 3.646,
			mouth = Vector3.new(-0.000, 2.310, -0.662),
			hand = Vector3.new(0.710, 1.100, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.808, -0.115), size = Vector3.new(2.030, 1.675, 1.910), joint = Vector3.new(-0.000, 2.100, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.550, 0.188), size = Vector3.new(1.200, 1.200, 1.375), joint = Vector3.new(-0.000, 0.950, 0.000) },
				ArmL = { center = Vector3.new(-0.710, 1.478, -0.020), size = Vector3.new(0.488, 1.216, 0.460), joint = Vector3.new(-0.710, 1.880, 0.000) },
				ArmR = { center = Vector3.new(0.710, 1.478, -0.020), size = Vector3.new(0.488, 1.216, 0.460), joint = Vector3.new(0.710, 1.880, 0.000) },
				LegL = { center = Vector3.new(-0.288, 0.505, -0.091), size = Vector3.new(0.487, 1.010, 0.650), joint = Vector3.new(-0.288, 0.950, 0.000) },
				LegR = { center = Vector3.new(0.288, 0.505, -0.091), size = Vector3.new(0.487, 1.010, 0.650), joint = Vector3.new(0.288, 0.950, 0.000) },
			},
		},
		Kkuldanji = {
			label = "꿀단지",
			height = 3.074,
			mouth = Vector3.new(-0.000, 1.964, -0.650),
			hand = Vector3.new(0.691, 0.900, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.349, -0.160), size = Vector3.new(1.607, 1.450, 1.720), joint = Vector3.new(-0.000, 1.750, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.250, 0.120), size = Vector3.new(1.150, 1.000, 1.140), joint = Vector3.new(-0.000, 0.750, 0.000) },
				ArmL = { center = Vector3.new(-0.691, 1.197, -0.020), size = Vector3.new(0.512, 1.077, 0.483), joint = Vector3.new(-0.691, 1.519, 0.000) },
				ArmR = { center = Vector3.new(0.691, 1.197, -0.020), size = Vector3.new(0.512, 1.077, 0.483), joint = Vector3.new(0.691, 1.519, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.405, -0.093), size = Vector3.new(0.507, 0.810, 0.673), joint = Vector3.new(-0.276, 0.750, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.405, -0.093), size = Vector3.new(0.507, 0.810, 0.673), joint = Vector3.new(0.276, 0.750, 0.000) },
			},
		},
		Mochi = {
			label = "설기",
			height = 4.109,
			mouth = Vector3.new(-0.000, 2.218, -0.668),
			hand = Vector3.new(0.599, 1.000, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.943, -0.013), size = Vector3.new(1.440, 2.331, 1.345), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.370, 0.030), size = Vector3.new(1.480, 1.600, 1.540), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.599, 1.354, -0.007), size = Vector3.new(0.439, 1.121, 0.439), joint = Vector3.new(-0.599, 1.702, 0.000) },
				ArmR = { center = Vector3.new(0.599, 1.354, -0.007), size = Vector3.new(0.439, 1.121, 0.439), joint = Vector3.new(0.599, 1.702, 0.000) },
				LegL = { center = Vector3.new(-0.240, 0.455, -0.099), size = Vector3.new(0.409, 0.910, 0.660), joint = Vector3.new(-0.240, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.240, 0.455, -0.099), size = Vector3.new(0.409, 0.910, 0.660), joint = Vector3.new(0.240, 0.850, 0.000) },
			},
		},
		Godeungeo = {
			label = "고등어 아저씨",
			height = 3.790,
			mouth = Vector3.new(-0.000, 2.604, -0.690),
			hand = Vector3.new(0.771, 1.250, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 3.000, -0.098), size = Vector3.new(1.640, 1.581, 1.635), joint = Vector3.new(-0.000, 2.350, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.665, 0.252), size = Vector3.new(1.339, 1.370, 1.607), joint = Vector3.new(-0.000, 1.050, 0.000) },
				ArmL = { center = Vector3.new(-0.771, 1.666, -0.020), size = Vector3.new(0.537, 1.338, 0.506), joint = Vector3.new(-0.771, 2.108, 0.000) },
				ArmR = { center = Vector3.new(0.771, 1.666, -0.020), size = Vector3.new(0.537, 1.338, 0.506), joint = Vector3.new(0.771, 2.108, 0.000) },
				LegL = { center = Vector3.new(-0.321, 0.555, -0.085), size = Vector3.new(0.578, 1.110, 0.715), joint = Vector3.new(-0.312, 1.050, 0.000) },
				LegR = { center = Vector3.new(0.321, 0.555, -0.085), size = Vector3.new(0.578, 1.110, 0.715), joint = Vector3.new(0.312, 1.050, 0.000) },
			},
		},
		Dotori = {
			label = "도토리",
			height = 3.057,
			mouth = Vector3.new(-0.000, 1.995, -0.625),
			hand = Vector3.new(0.594, 0.900, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.346, -0.102), size = Vector3.new(1.400, 1.422, 1.585), joint = Vector3.new(-0.000, 1.750, 0.000) },
				Body = { center = Vector3.new(-0.118, 1.750, 0.522), size = Vector3.new(1.235, 2.380, 1.953), joint = Vector3.new(-0.000, 0.750, 0.000) },
				ArmL = { center = Vector3.new(-0.594, 1.234, -0.007), size = Vector3.new(0.415, 1.059, 0.416), joint = Vector3.new(-0.594, 1.563, 0.000) },
				ArmR = { center = Vector3.new(0.594, 1.234, -0.007), size = Vector3.new(0.415, 1.059, 0.416), joint = Vector3.new(0.594, 1.563, 0.000) },
				LegL = { center = Vector3.new(-0.240, 0.405, -0.090), size = Vector3.new(0.400, 0.810, 0.600), joint = Vector3.new(-0.240, 0.750, 0.000) },
				LegR = { center = Vector3.new(0.240, 0.405, -0.090), size = Vector3.new(0.400, 0.810, 0.600), joint = Vector3.new(0.240, 0.750, 0.000) },
			},
		},
		Owl = {
			label = "부엉이",
			height = 3.834,
			mouth = Vector3.new(-0.000, 2.200, -0.748),
			hand = Vector3.new(0.821, 0.850, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.777, -0.043), size = Vector3.new(1.700, 2.113, 1.566), joint = Vector3.new(-0.000, 1.850, 0.000) },
				Body = { center = Vector3.new(0.001, 1.229, 0.100), size = Vector3.new(1.639, 1.620, 1.299), joint = Vector3.new(-0.000, 0.500, 0.000) },
				ArmL = { center = Vector3.new(-0.821, 1.216, -0.020), size = Vector3.new(0.537, 1.238, 0.506), joint = Vector3.new(-0.821, 1.608, 0.000) },
				ArmR = { center = Vector3.new(0.821, 1.216, -0.020), size = Vector3.new(0.537, 1.238, 0.506), joint = Vector3.new(0.821, 1.608, 0.000) },
				LegL = { center = Vector3.new(-0.336, 0.280, -0.095), size = Vector3.new(0.507, 0.560, 0.610), joint = Vector3.new(-0.336, 0.500, 0.000) },
				LegR = { center = Vector3.new(0.336, 0.280, -0.095), size = Vector3.new(0.507, 0.560, 0.610), joint = Vector3.new(0.336, 0.500, 0.000) },
			},
		},
		Pongpong = {
			label = "퐁퐁이",
			height = 2.991,
			mouth = Vector3.new(-0.000, 1.921, -0.722),
			hand = Vector3.new(0.599, 0.800, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.236, -0.022), size = Vector3.new(1.960, 1.510, 2.005), joint = Vector3.new(-0.000, 1.600, 0.000) },
				Body = { center = Vector3.new(0.080, 1.030, 0.013), size = Vector3.new(1.480, 1.200, 1.345), joint = Vector3.new(-0.000, 0.600, 0.000) },
				ArmL = { center = Vector3.new(-0.599, 1.104, -0.007), size = Vector3.new(0.439, 1.021, 0.439), joint = Vector3.new(-0.599, 1.402, 0.000) },
				ArmR = { center = Vector3.new(0.599, 1.104, -0.007), size = Vector3.new(0.439, 1.021, 0.439), joint = Vector3.new(0.599, 1.402, 0.000) },
				LegL = { center = Vector3.new(-0.240, 0.330, -0.114), size = Vector3.new(0.507, 0.660, 0.760), joint = Vector3.new(-0.240, 0.600, 0.000) },
				LegR = { center = Vector3.new(0.240, 0.330, -0.114), size = Vector3.new(0.507, 0.660, 0.760), joint = Vector3.new(0.240, 0.600, 0.000) },
			},
		},
	},
}
