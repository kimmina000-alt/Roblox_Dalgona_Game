# 손님 NPC 색 그림 정리 (2026-11-28 작업 지시서 "얼룩·노이즈·색 번짐 제거, 균일하고 깨끗한 표면, 원래 색 유지").
#   Tripo 원본 그림 자체에 얼룩(바지 옆 허옇게 번진 줄, 털 위 회색 반점, 흐린 명암 덩어리)이 있어서, 옮긴 뒤 한 번 더 정리:
#   1) 경계는 살리고 점 노이즈·얼룩진 명암을 고르게 (bilateral)
#   2) 손님마다 주요 색 K개(Lab의 a·b만, k-means)를 뽑고 각 픽셀의 색만 그쪽으로 당김 (밝기·명암은 그대로)
#      → 허옇게 빠진 초록 같은 번진 중간 색이 원래 색으로. 색 수를 줄이는 게 아니라 얼굴·무늬 명암은 남음
#   3) 얼굴(머리 앞쪽)은 원래 그림 그대로, 앞을 보는 곳의 작고 진한 디테일(단추·끈·배지)도 그대로. 옆·뒤 작은 점은 얼룩으로 보고 지움
#   UV 섬 밖(마스크 0)은 섬 색을 늘려 채움 (이음매).
# 실행 (시스템 파이썬, OpenCV): python tools/blender/npc_clean.py <색.png> <마스크.png> <출력.png> [K] [당김 0~1]
import sys

import cv2
import numpy as np

src, maskp, outp = sys.argv[1:4]
K = int(sys.argv[4]) if len(sys.argv) > 4 else 12
PULL = float(sys.argv[5]) if len(sys.argv) > 5 else 0.6
ITERS = int(sys.argv[6]) if len(sys.argv) > 6 else 4
# 7번째부터: 직접 지울 자리 "u,v,r" (그림 왼쪽 위 기준 0~1, r = 반지름 비율). 얼굴 보호 범위 안의 원본 얼룩용
ERASE = [tuple(float(x) for x in a.split(",")) for a in sys.argv[7:]]  # 흐림 횟수 (뽀글이처럼 털 결이 디자인이면 줄임)

# 경로에 한글(레퍼런스)이 있어 cv2.imread/imwrite 대신 바이트로 읽고 씀
img = cv2.imdecode(np.fromfile(src, np.uint8), cv2.IMREAD_COLOR)
mk = cv2.imdecode(np.fromfile(maskp, np.uint8), cv2.IMREAD_COLOR)  # R = UV 섬, G = 앞을 보는 곳, B = 얼굴
mask, front, face = mk[:, :, 2] > 127, mk[:, :, 1] > 127, mk[:, :, 0] > 127
H, W = mask.shape

# 1) 경계 살린 흐림 (bilateral 4번): 점 노이즈·얼룩진 명암을 고르게, 눈·줄무늬 경계는 그대로
sm = img.copy()
for _ in range(ITERS):
    sm = cv2.bilateralFilter(sm, 9, 28, 6)
lab = cv2.cvtColor(sm, cv2.COLOR_BGR2LAB).astype(np.float32)

# 2) 색 번짐(허옇게 빠진 초록 같은 중간 색): 밝기(L)는 두고 색(a, b)만 손님 주요 색 K개 쪽으로 당김
samples = lab[mask][:, 1:3]
rng = np.random.default_rng(1)
pick = samples[rng.choice(len(samples), min(len(samples), 60000), replace=False)]
crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 40, 0.5)
_, _, centers = cv2.kmeans(pick, K, None, crit, 3, cv2.KMEANS_PP_CENTERS)
ab = lab[:, :, 1:3].reshape(-1, 1, 2)
d = ((ab - centers.reshape(1, -1, 2)) ** 2).sum(-1)
lbl = d.argmin(1).reshape(H, W)
votes = np.zeros((K, H, W), np.float32)
for k in range(K):
    votes[k] = cv2.boxFilter((lbl == k).astype(np.float32), -1, (5, 5), normalize=False)
lbl2 = votes.argmax(0)
out_lab = lab.copy()
out_lab[:, :, 1:3] = centers[lbl2] * PULL + lab[:, :, 1:3] * (1 - PULL)
out = cv2.cvtColor(np.clip(out_lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)

# 2.5) 옆·뒤의 가는 검은 선·점(원본의 주름 자국, 설기 등 쪽 점선 등): 밝기 닫힘(5px)으로 지움. 앞·얼굴은 그대로
side = mask & ~front & ~face
lab2 = cv2.cvtColor(out, cv2.COLOR_BGR2LAB)
L = lab2[:, :, 0]
closed = cv2.morphologyEx(L, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
thin = side & (closed.astype(np.int16) - L.astype(np.int16) > 18)
thin = cv2.dilate(thin.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & side
if thin.any():
    med = cv2.medianBlur(out, 7)
    lab_med = cv2.cvtColor(med, cv2.COLOR_BGR2LAB)
    lab_med[:, :, 0] = np.maximum(lab_med[:, :, 0], closed)
    fix = cv2.cvtColor(lab_med, cv2.COLOR_LAB2BGR)
    out[thin] = fix[thin]

# 2.6) 옆·뒤의 작은 색 얼룩(뽀글이 머리 옆 빨간 점, 손에 묻은 회색 자국): 주변(중간값)과 색(a, b)이 크게 다르고 작은 덩어리면 주변 색으로
med = cv2.medianBlur(out, 21)
lab_o = cv2.cvtColor(out, cv2.COLOR_BGR2LAB).astype(np.int16)
lab_m = cv2.cvtColor(med, cv2.COLOR_BGR2LAB).astype(np.int16)
dab = np.sqrt(((lab_o[:, :, 1:] - lab_m[:, :, 1:]) ** 2).sum(-1))
spot = (side & (dab > 14)).astype(np.uint8)
n_, cc_, st_, _ = cv2.connectedComponentsWithStats(spot, 8)
small = np.zeros(spot.shape, bool)
for i in range(1, n_):
    if st_[i, cv2.CC_STAT_AREA] < 600:
        small[cc_ == i] = True
small = cv2.dilate(small.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & side
out[small] = med[small]

# 3) 작은 진한 디테일(눈동자·입·눈썹·수염·단추)은 원본 유지: 주변(블러)과 차이가 크고 면적이 작은 곳
orig_lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
blur = cv2.GaussianBlur(orig_lab, (0, 0), 6)
diff = np.sqrt(((orig_lab - blur) ** 2).sum(-1))
detail = (diff > 28).astype(np.uint8)
n, cc, stats, _ = cv2.connectedComponentsWithStats(detail, 8)
keep = np.zeros_like(detail)
for i in range(1, n):
    if stats[i, cv2.CC_STAT_AREA] < 900:
        keep[cc == i] = 1
keep &= front.astype(np.uint8)  # 옆·뒤의 작은 진한 점은 얼룩(뽀글이 머리 옆 빨간 점 등)이라 지움
keep |= face.astype(np.uint8)  # 얼굴은 원래 그림 그대로 (표정 변경 금지)
keep = cv2.dilate(keep, np.ones((3, 3), np.uint8))
alpha = cv2.GaussianBlur(keep.astype(np.float32), (0, 0), 1.0)[..., None]
out = (out.astype(np.float32) * (1 - alpha) + img.astype(np.float32) * alpha)
# 섬 가장자리 계단 줄이기: 섬 안에서만 아주 살짝 흐림
out = out.astype(np.uint8)
sm = cv2.GaussianBlur(out, (0, 0), 0.7)
out[mask] = sm[mask]

# 지정 자리 지우기 (주변 색으로 채움)
if ERASE:
    em = np.zeros((H, W), np.uint8)
    for u, v, r in ERASE:
        cv2.circle(em, (int(u * W), int(v * H)), max(2, int(r * W)), 255, -1)
    out = cv2.inpaint(out, em, 5, cv2.INPAINT_TELEA)

# 섬 밖 채우기 (16px)
fill = out.copy()
have = mask.copy()
for _ in range(16):
    grown = cv2.dilate(have.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & ~have
    if not grown.any():
        break
    acc = cv2.blur(np.where(have[..., None], fill, 0).astype(np.float32), (3, 3))
    cnt = cv2.blur(have.astype(np.float32), (3, 3))[..., None]
    v = acc / np.maximum(cnt, 1e-6)
    fill[grown] = v[grown].astype(np.uint8)
    have |= grown
cv2.imencode(".png", fill)[1].tofile(outp)
print("[clean] wrote", outp, "K", K)
