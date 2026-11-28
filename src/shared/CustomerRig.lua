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
		Ppogeuli = { -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)
			label = "뽀글이",
			height = 3.700,
			mouth = Vector3.new(-0.000, 2.389, -0.885),
			hand = Vector3.new(1.329, 0.922, 0.229),
			parts = {
				Head = { center = Vector3.new(-0.007, 2.796, -0.052), size = Vector3.new(2.125, 1.809, 1.585), joint = Vector3.new(-0.000, 2.036, 0.000) },
				Body = { center = Vector3.new(-0.014, 1.266, -0.035), size = Vector3.new(1.382, 1.592, 1.340), joint = Vector3.new(-0.000, 0.736, 0.000) },
				ArmL = { center = Vector3.new(-0.845, 1.354, -0.137), size = Vector3.new(1.075, 0.974, 0.695), joint = Vector3.new(-0.443, 1.841, -0.137) },
				ArmR = { center = Vector3.new(0.771, 1.453, 0.115), size = Vector3.new(1.171, 1.113, 0.653), joint = Vector3.new(0.415, 1.881, 0.115) },
				LegL = { center = Vector3.new(-0.306, 0.423, -0.054), size = Vector3.new(0.564, 0.814, 0.628), joint = Vector3.new(-0.295, 0.732, -0.032) },
				LegR = { center = Vector3.new(0.323, 0.433, 0.028), size = Vector3.new(0.529, 0.866, 0.680), joint = Vector3.new(0.316, 0.762, 0.031) },
			},
		},
		Kkuldanji = { -- 곰돌 모델 = 꿀단지 (2026-11-28 사용자). tools/blender/gomdol.py (레퍼런스/npc/곰돌.glb)
			label = "꿀단지",
			height = 3.800,
			mouth = Vector3.new(-0.000, 2.296, -0.972),
			hand = Vector3.new(1.197, 0.985, -0.088),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.763, -0.152), size = Vector3.new(1.941, 2.075, 1.540), joint = Vector3.new(-0.000, 1.891, 0.000) },
				Body = { center = Vector3.new(-0.003, 1.210, 0.000), size = Vector3.new(1.357, 1.319, 1.390), joint = Vector3.new(-0.000, 0.807, 0.000) },
				ArmL = { center = Vector3.new(-0.842, 1.327, -0.122), size = Vector3.new(0.780, 0.719, 0.581), joint = Vector3.new(-0.543, 1.696, -0.122) },
				ArmR = { center = Vector3.new(0.766, 1.371, -0.023), size = Vector3.new(0.914, 0.859, 0.484), joint = Vector3.new(0.537, 1.690, -0.023) },
				LegL = { center = Vector3.new(-0.352, 0.485, -0.026), size = Vector3.new(0.492, 0.928, 0.618), joint = Vector3.new(-0.441, 0.838, -0.014) },
				LegR = { center = Vector3.new(0.298, 0.472, 0.000), size = Vector3.new(0.601, 0.944, 0.679), joint = Vector3.new(0.339, 0.831, -0.035) },
			},
		},
		Mochi = { -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)
			label = "설기",
			height = 4.000,
			mouth = Vector3.new(-0.000, 2.415, -0.808),
			hand = Vector3.new(1.161, 0.844, 0.019),
			parts = {
				Head = { center = Vector3.new(-0.005, 2.907, 0.014), size = Vector3.new(1.607, 2.187, 1.544), joint = Vector3.new(-0.000, 1.988, 0.000) },
				Body = { center = Vector3.new(-0.013, 1.220, 0.031), size = Vector3.new(1.430, 1.414, 1.358), joint = Vector3.new(-0.000, 0.884, 0.000) },
				ArmL = { center = Vector3.new(-0.725, 1.247, 0.041), size = Vector3.new(0.947, 0.848, 0.480), joint = Vector3.new(-0.374, 1.677, 0.041) },
				ArmR = { center = Vector3.new(0.684, 1.241, 0.071), size = Vector3.new(0.998, 0.873, 0.520), joint = Vector3.new(0.349, 1.673, 0.071) },
				LegL = { center = Vector3.new(-0.297, 0.515, 0.013), size = Vector3.new(0.489, 1.013, 0.559), joint = Vector3.new(-0.303, 0.900, 0.019) },
				LegR = { center = Vector3.new(0.285, 0.520, 0.000), size = Vector3.new(0.512, 1.040, 0.609), joint = Vector3.new(0.286, 0.915, -0.017) },
			},
		},
		Godeungeo = { -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)
			label = "고등어 아저씨",
			height = 3.800,
			mouth = Vector3.new(-0.000, 2.652, -0.869),
			hand = Vector3.new(1.265, 1.230, 0.170),
			parts = {
				Head = { center = Vector3.new(-0.000, 3.008, -0.107), size = Vector3.new(1.793, 1.584, 1.500), joint = Vector3.new(-0.000, 2.343, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.581, 0.226), size = Vector3.new(1.550, 1.662, 1.796), joint = Vector3.new(-0.000, 1.186, 0.000) },
				ArmL = { center = Vector3.new(-0.777, 1.716, 0.114), size = Vector3.new(1.093, 1.007, 0.573), joint = Vector3.new(-0.402, 2.196, 0.114) },
				ArmR = { center = Vector3.new(0.795, 1.700, 0.114), size = Vector3.new(1.057, 0.975, 0.573), joint = Vector3.new(0.402, 2.196, 0.114) },
				LegL = { center = Vector3.new(-0.393, 0.698, -0.000), size = Vector3.new(0.765, 1.396, 1.055), joint = Vector3.new(-0.356, 1.228, 0.027) },
				LegR = { center = Vector3.new(0.393, 0.682, -0.000), size = Vector3.new(0.765, 1.365, 1.055), joint = Vector3.new(0.356, 1.201, 0.027) },
			},
		},
		Dotori = { -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)
			label = "도토리",
			height = 3.700,
			mouth = Vector3.new(-0.000, 2.360, -0.903),
			hand = Vector3.new(1.067, 1.089, -0.032),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.776, -0.223), size = Vector3.new(1.435, 1.848, 1.486), joint = Vector3.new(-0.000, 2.000, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.739, 0.876), size = Vector3.new(1.204, 2.328, 3.112), joint = Vector3.new(-0.000, 0.888, 0.000) },
				ArmL = { center = Vector3.new(-0.633, 1.469, -0.037), size = Vector3.new(0.897, 0.827, 0.402), joint = Vector3.new(-0.408, 1.799, -0.037) },
				ArmR = { center = Vector3.new(0.676, 1.433, -0.037), size = Vector3.new(0.811, 0.755, 0.402), joint = Vector3.new(0.408, 1.799, -0.037) },
				LegL = { center = Vector3.new(-0.309, 0.522, -0.000), size = Vector3.new(0.382, 1.045, 0.412), joint = Vector3.new(-0.318, 0.919, 0.014) },
				LegR = { center = Vector3.new(0.309, 0.518, -0.000), size = Vector3.new(0.382, 1.035, 0.412), joint = Vector3.new(0.318, 0.911, 0.014) },
			},
		},
		Owl = { -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)
			label = "부엉이",
			height = 3.800,
			mouth = Vector3.new(-0.000, 2.437, -0.862),
			hand = Vector3.new(1.424, 1.449, -0.604),
			parts = {
				Head = { center = Vector3.new(0.030, 2.860, -0.001), size = Vector3.new(1.709, 1.880, 1.623), joint = Vector3.new(-0.000, 2.070, 0.000) },
				Body = { center = Vector3.new(0.003, 1.168, 0.074), size = Vector3.new(2.551, 1.873, 1.713), joint = Vector3.new(-0.000, 0.457, 0.000) },
				ArmL = { center = Vector3.new(-0.985, 1.319, 0.047), size = Vector3.new(1.078, 0.729, 0.893), joint = Vector3.new(-0.447, 1.501, 0.047) },
				ArmR = { center = Vector3.new(0.881, 1.322, -0.073), size = Vector3.new(1.105, 0.832, 1.093), joint = Vector3.new(0.452, 1.530, -0.073) },
				LegL = { center = Vector3.new(-0.440, 0.254, 0.009), size = Vector3.new(0.477, 0.505, 0.665), joint = Vector3.new(-0.346, 0.446, 0.025) },
				LegR = { center = Vector3.new(0.433, 0.269, -0.007), size = Vector3.new(0.491, 0.538, 0.669), joint = Vector3.new(0.329, 0.473, 0.030) },
			},
		},
		Pongpong = { -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)
			label = "퐁퐁이",
			height = 3.300,
			mouth = Vector3.new(-0.000, 2.098, -0.851),
			hand = Vector3.new(1.055, 0.794, -0.286),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.471, 0.094), size = Vector3.new(1.878, 1.658, 1.954), joint = Vector3.new(-0.000, 1.775, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.028, 0.088), size = Vector3.new(1.539, 1.358, 1.490), joint = Vector3.new(-0.000, 0.627, 0.000) },
				ArmL = { center = Vector3.new(-0.694, 1.101, -0.163), size = Vector3.new(0.774, 0.681, 0.478), joint = Vector3.new(-0.424, 1.476, -0.163) },
				ArmR = { center = Vector3.new(0.696, 1.093, -0.075), size = Vector3.new(0.772, 0.665, 0.654), joint = Vector3.new(0.424, 1.476, -0.075) },
				LegL = { center = Vector3.new(-0.291, 0.369, 0.000), size = Vector3.new(0.274, 0.738, 0.430), joint = Vector3.new(-0.252, 0.649, 0.112) },
				LegR = { center = Vector3.new(0.291, 0.361, 0.000), size = Vector3.new(0.274, 0.722, 0.430), joint = Vector3.new(0.252, 0.635, 0.112) },
			},
		},
	},
}
