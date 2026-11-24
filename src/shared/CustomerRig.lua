-- 자동 생성: tools/blender/basic_npc.py (손으로 고치지 말 것) — 임시 기본 손님 (동물 7종은 보류)
-- 손님 NPC 7종 리그. 좌표 = 손님 Root 기준 (Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X), 단위 stud.
-- parts[이름] = { center = 서 있을 때 부품(MeshPart) 가운데, size = 메시 크기, joint = 돌리는 관절 점 }
--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)
--   Head = 목, Body = 엉덩이 가운데, ArmL/ArmR = 어깨, LegL/LegR = 엉덩이 관절.
-- 메시는 Studio ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> (dalgona_customers_basic.glb).
-- mouth = 입 앞 (먹기 연출), hand = 오른손(ArmR 끝) 가운데, height = 키.

return {
	order = { "Ppogeuli", "Kkuldanji", "Mochi", "Godeungeo", "Dotori", "Owl", "Pongpong" },
	types = {
		Ppogeuli = {
			label = "뽀글이",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
		Kkuldanji = {
			label = "꿀단지",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
		Mochi = {
			label = "설기",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
		Godeungeo = {
			label = "고등어 아저씨",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
		Dotori = {
			label = "도토리",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
		Owl = {
			label = "부엉이",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
		Pongpong = {
			label = "퐁퐁이",
			height = 3.218,
			mouth = Vector3.new(-0.000, 2.198, -0.678),
			hand = Vector3.new(0.679, 0.950, -0.020),
			parts = {
				Head = { center = Vector3.new(-0.000, 2.498, 0.039), size = Vector3.new(1.446, 1.440, 1.443), joint = Vector3.new(-0.000, 1.900, 0.000) },
				Body = { center = Vector3.new(-0.000, 1.375, 0.000), size = Vector3.new(1.150, 1.050, 0.850), joint = Vector3.new(-0.000, 0.850, 0.000) },
				ArmL = { center = Vector3.new(-0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(-0.679, 1.691, 0.000) },
				ArmR = { center = Vector3.new(0.679, 1.323, -0.007), size = Vector3.new(0.464, 1.184, 0.463), joint = Vector3.new(0.679, 1.691, 0.000) },
				LegL = { center = Vector3.new(-0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(-0.276, 0.850, 0.000) },
				LegR = { center = Vector3.new(0.276, 0.455, -0.096), size = Vector3.new(0.468, 0.910, 0.640), joint = Vector3.new(0.276, 0.850, 0.000) },
			},
		},
	},
}
