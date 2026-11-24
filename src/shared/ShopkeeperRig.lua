-- 자동 생성: tools/blender/shopkeeper_ai.py (손으로 고치지 말 것)
-- 골목 슈퍼 계산대 너구리 사장님 NPC 리그 (2026-11-25부터 사용자가 가져온 AI 모델판). 손님(CustomerRig)과 같은 방식·같은 좌표:
--   Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X, 단위 stud.
--   parts[이름] = { center = 서 있을 때 부품 가운데, size = 메시 크기, joint = 돌리는 관절 점 }
--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)
-- 메시는 Studio ServerStorage.Assets.Shopkeeper_Raccoon 안 Raccoon_<부품> (dalgona_shopkeeper.glb).
-- 동작 (미리 보기 shopkeeper_preview2.png와 같은 값):
--   인사(손 흔들기) = ArmR 회전 CFrame.Angles(0, 0, math.rad(wave.raise + math.sin(t * wave.speed) * wave.swing))
--   고개 끄덕 = Head 회전 CFrame.Angles(math.rad(-nod), 0, 0)  (음수 X = 앞으로 숙임)
--   서 있기 = 회전 없음 (원하면 Body를 아주 조금 위아래로 숨쉬기)

return {
	label = "너구리 사장님",
	height = 3.620,
	mouth = Vector3.new(-0.000, 2.390, -1.079),
	hand = Vector3.new(0.907, 0.815, -0.258),
	wave = { raise = 140, swing = 18, speed = 7 },
	nod = 14,
	parts = {
		Head = { center = Vector3.new(0.011, 2.800, -0.074), size = Vector3.new(1.803, 1.640, 1.914), joint = Vector3.new(-0.000, 1.980, 0.000) },
		Body = { center = Vector3.new(-0.003, 1.129, 0.430), size = Vector3.new(1.694, 1.702, 2.363), joint = Vector3.new(-0.000, 0.380, 0.000) },
		ArmL = { center = Vector3.new(-0.839, 1.335, -0.058), size = Vector3.new(0.484, 1.007, 0.802), joint = Vector3.new(-0.800, 1.688, 0.062) },
		ArmR = { center = Vector3.new(0.825, 1.327, -0.074), size = Vector3.new(0.506, 1.023, 0.779), joint = Vector3.new(0.800, 1.689, 0.056) },
		LegL = { center = Vector3.new(-0.342, 0.192, 0.031), size = Vector3.new(0.428, 0.375, 0.543), joint = Vector3.new(-0.336, 0.380, 0.000) },
		LegR = { center = Vector3.new(0.330, 0.190, 0.018), size = Vector3.new(0.424, 0.380, 0.539), joint = Vector3.new(0.336, 0.380, 0.000) },
	},
}
