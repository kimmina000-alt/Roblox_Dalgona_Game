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
				Head = { center = Vector3.new(0.003, 2.677, 0.005), size = Vector3.new(2.400, 1.925, 1.998), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.003, 1.228, 0.164), size = Vector3.new(1.613, 1.672, 1.751), joint = Vector3.new(-0.000, 0.700, 0.000) },
				ArmL = { center = Vector3.new(-0.725, 1.167, 0.010), size = Vector3.new(0.705, 1.210, 0.717), joint = Vector3.new(-0.734, 1.564, 0.000) },
				ArmR = { center = Vector3.new(0.743, 1.164, 0.010), size = Vector3.new(0.705, 1.233, 0.717), joint = Vector3.new(0.734, 1.564, 0.000) },
				LegL = { center = Vector3.new(-0.277, 0.491, -0.023), size = Vector3.new(0.785, 1.096, 0.859), joint = Vector3.new(-0.286, 0.700, 0.000) },
				LegR = { center = Vector3.new(0.295, 0.492, -0.025), size = Vector3.new(0.785, 1.083, 0.863), joint = Vector3.new(0.286, 0.700, 0.000) },
			},
		},
		Kkuldanji = {
			label = "꿀단지",
			height = 3.250,
			mouth = Vector3.new(-0.000, 1.944, -0.920),
			hand = Vector3.new(0.709, 0.728, -0.020),
			parts = {
				Head = { center = Vector3.new(0.004, 2.354, -0.060), size = Vector3.new(1.827, 1.791, 1.740), joint = Vector3.new(-0.000, 1.650, 0.000) },
				Body = { center = Vector3.new(0.002, 1.118, 0.137), size = Vector3.new(1.286, 1.316, 1.363), joint = Vector3.new(-0.000, 0.600, 0.000) },
				ArmL = { center = Vector3.new(-0.713, 1.000, -0.038), size = Vector3.new(0.603, 1.056, 0.591), joint = Vector3.new(-0.709, 1.314, 0.000) },
				ArmR = { center = Vector3.new(0.699, 1.001, -0.052), size = Vector3.new(0.589, 1.073, 0.583), joint = Vector3.new(0.709, 1.314, 0.000) },
				LegL = { center = Vector3.new(-0.269, 0.439, -0.099), size = Vector3.new(0.580, 1.002, 0.748), joint = Vector3.new(-0.275, 0.600, 0.000) },
				LegR = { center = Vector3.new(0.278, 0.436, -0.080), size = Vector3.new(0.584, 1.004, 0.738), joint = Vector3.new(0.275, 0.600, 0.000) },
			},
		},
		Mochi = {
			label = "모찌",
			height = 3.899,
			mouth = Vector3.new(-0.000, 2.070, -0.805),
			hand = Vector3.new(0.620, 0.790, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.005, 2.704, -0.012), size = Vector3.new(1.771, 2.391, 1.645), joint = Vector3.new(-0.000, 1.700, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.159, 0.000), size = Vector3.new(1.750, 1.464, 1.772), joint = Vector3.new(-0.000, 0.650, 0.000) },
				ArmL = { center = Vector3.new(-0.620, 1.139, -0.011), size = Vector3.new(0.523, 1.133, 0.539), joint = Vector3.new(-0.620, 1.420, 0.000) },
				ArmR = { center = Vector3.new(0.618, 1.146, -0.016), size = Vector3.new(0.521, 1.129, 0.560), joint = Vector3.new(0.620, 1.420, 0.000) },
				LegL = { center = Vector3.new(-0.246, 0.457, -0.093), size = Vector3.new(0.515, 0.962, 0.749), joint = Vector3.new(-0.242, 0.650, 0.000) },
				LegR = { center = Vector3.new(0.241, 0.453, -0.094), size = Vector3.new(0.498, 0.991, 0.726), joint = Vector3.new(0.242, 0.650, 0.000) },
			},
		},
		Chunsik = {
			label = "춘식이 아저씨",
			height = 3.879,
			mouth = Vector3.new(-0.000, 2.480, -0.947),
			hand = Vector3.new(0.762, 1.025, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.001, 2.882, -0.047), size = Vector3.new(1.898, 1.994, 1.778), joint = Vector3.new(-0.000, 2.200, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.513, 0.205), size = Vector3.new(1.445, 1.783, 1.876), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.760, 1.409, -0.046), size = Vector3.new(0.638, 1.321, 0.597), joint = Vector3.new(-0.762, 1.850, 0.000) },
				ArmR = { center = Vector3.new(0.760, 1.411, -0.052), size = Vector3.new(0.633, 1.324, 0.595), joint = Vector3.new(0.762, 1.850, 0.000) },
				LegL = { center = Vector3.new(-0.305, 0.554, -0.096), size = Vector3.new(0.627, 1.288, 0.761), joint = Vector3.new(-0.297, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.306, 0.562, -0.094), size = Vector3.new(0.625, 1.294, 0.774), joint = Vector3.new(0.297, 0.850, 0.000) },
			},
		},
		Dotori = {
			label = "도토리",
			height = 3.033,
			mouth = Vector3.new(-0.000, 1.843, -0.881),
			hand = Vector3.new(0.591, 0.693, -0.020),
			parts = {
				Head = { center = Vector3.new(0.002, 2.206, -0.050), size = Vector3.new(1.686, 1.655, 1.652), joint = Vector3.new(-0.000, 1.550, 0.000) },
				Body = { center = Vector3.new(-0.143, 1.596, 1.035), size = Vector3.new(1.349, 2.835, 3.240), joint = Vector3.new(-0.000, 0.550, 0.000) },
				ArmL = { center = Vector3.new(-0.591, 0.989, -0.014), size = Vector3.new(0.490, 1.137, 0.526), joint = Vector3.new(-0.591, 1.284, 0.000) },
				ArmR = { center = Vector3.new(0.592, 0.986, -0.019), size = Vector3.new(0.495, 1.140, 0.529), joint = Vector3.new(0.591, 1.284, 0.000) },
				LegL = { center = Vector3.new(-0.228, 0.401, -0.090), size = Vector3.new(0.483, 0.865, 0.639), joint = Vector3.new(-0.231, 0.550, 0.000) },
				LegR = { center = Vector3.new(0.233, 0.401, -0.078), size = Vector3.new(0.487, 0.874, 0.649), joint = Vector3.new(0.231, 0.550, 0.000) },
			},
		},
		Owl = {
			label = "부엉이",
			height = 3.965,
			mouth = Vector3.new(-0.000, 2.071, -0.920),
			hand = Vector3.new(0.852, 0.764, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.005, 2.757, -0.076), size = Vector3.new(1.970, 2.417, 1.894), joint = Vector3.new(-0.000, 1.830, 0.000) },
				Body = { center = Vector3.new(-0.001, 1.106, 0.025), size = Vector3.new(1.768, 1.812, 1.431), joint = Vector3.new(-0.000, 0.380, 0.000) },
				ArmL = { center = Vector3.new(-0.852, 1.092, -0.047), size = Vector3.new(0.532, 1.260, 0.304), joint = Vector3.new(-0.852, 1.522, 0.000) },
				ArmR = { center = Vector3.new(0.852, 1.092, -0.050), size = Vector3.new(0.569, 1.259, 0.294), joint = Vector3.new(0.852, 1.522, 0.000) },
				LegL = { center = Vector3.new(-0.341, 0.270, -0.125), size = Vector3.new(0.560, 0.556, 0.710), joint = Vector3.new(-0.341, 0.380, 0.000) },
				LegR = { center = Vector3.new(0.341, 0.263, -0.125), size = Vector3.new(0.560, 0.573, 0.710), joint = Vector3.new(0.341, 0.380, 0.000) },
			},
		},
		Pongpong = {
			label = "퐁퐁이",
			height = 3.121,
			mouth = Vector3.new(-0.000, 1.894, -1.009),
			hand = Vector3.new(0.617, 0.643, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.215, 0.000), size = Vector3.new(2.220, 1.811, 2.220), joint = Vector3.new(-0.000, 1.500, 0.000) },
				Body = { center = Vector3.new(0.080, 0.959, 0.002), size = Vector3.new(1.713, 1.348, 1.590), joint = Vector3.new(-0.000, 0.450, 0.000) },
				ArmL = { center = Vector3.new(-0.614, 0.974, -0.005), size = Vector3.new(0.496, 1.071, 0.497), joint = Vector3.new(-0.617, 1.234, 0.000) },
				ArmR = { center = Vector3.new(0.616, 0.971, -0.005), size = Vector3.new(0.525, 1.075, 0.501), joint = Vector3.new(0.617, 1.234, 0.000) },
				LegL = { center = Vector3.new(-0.242, 0.310, -0.112), size = Vector3.new(0.600, 0.636, 0.800), joint = Vector3.new(-0.242, 0.450, 0.000) },
				LegR = { center = Vector3.new(0.242, 0.280, -0.112), size = Vector3.new(0.600, 0.622, 0.800), joint = Vector3.new(0.242, 0.450, 0.000) },
			},
		},
	},
}
