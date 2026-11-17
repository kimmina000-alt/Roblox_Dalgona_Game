# 소리 후보 (2026-11-18)

## 고른 소리 (2026-11-18 사용자 선택, `C.Sounds`에 넣음)
| 키 | ID | 길이 | 앞 무음 건너뜀 |
|---|---|---|---|
| sugarPour (설탕 붓기) | 9113597694 | 1.25 s | 0.08 s |
| crack (금 가는 소리) | 9113959343 | 1.02 s | 0.16 s |
| fire (불) | 158853971 | 13.8 s | — |
| stirDry (가루 젓기) | 9120083178 | 2.2 s | 0.4 s |
| stirCrystal (결정) | 9113381863 | 3.2 s | — |
| stirLiquid (시럽) | 9116146746 | 3.3 s | 0.15 s |
| stirCream (소다 뒤) | 9126209045 | 1.3 s | 0.12 s |
원본 크기가 달라서 젓기 소리 크기를 `Sfx.lua`의 `STIR_VOL`로 맞춤 (가루·시럽 원본이 아주 작음). 아래는 처음 찾은 후보 목록.

설계 근거: `docs/MOTION_REFERENCE_ANALYSIS.md` 8-6 (실제 영상 YqKNy2l802c 소리 분석).
영상 소리는 대부분 해설 목소리 + 배경음악이라 조리 소리를 그대로 따올 수 없다. 아래는 Creator Store(무료)에서 찾은 후보다.
**Claude는 소리를 들을 수 없어서 이름·설명만 보고 골랐다.** 게임에는 아직 아무 ID도 넣지 않았다 (코드 연결은 끝남, ID만 비어 있음).

## 고르는 법
1. 링크(`https://create.roblox.com/store/asset/<ID>`)를 열어 재생하거나, Studio 도구 상자(Toolbox) → 오디오에서 ID로 검색해 들어 본다.
2. 마음에 드는 ID를 키마다 하나씩 알려 주면 `src/shared/DalgonaConfig.lua`의 `C.Sounds`에 `"rbxassetid://<ID>"`로 넣는다. 직접 올린 소리도 ID만 주면 된다.
3. 앞부분에 무음이 있으면 `<키>Start = 초`로 건너뛴다 (예: `paperTearStart`).

`ProSoundEffects`가 올린 것은 Roblox가 라이선스를 받은 효과음이라 써도 안전하다. 다른 사람이 올린 것은 출처가 불분명할 수 있다 (특히 `DistrokidOfficial`은 음악일 가능성).
오디오 에셋에는 스크립트가 없다 (모델을 가져올 때만 스크립트를 지운다).

## 코드에 연결된 키 (`C.Sounds`) — 지금 비어 있음
| 키 | 언제 | 어떻게 | 후보 (ID · 이름 · 길이) |
|---|---|---|---|
| `sugarPour` | 숟가락을 기울여 설탕이 쏟아질 때 | 반복, 기울인 만큼 크고 조금 빠르게 | 9118760944 Rust Crumbles 6 (3.3 s) · 9118760655 Rust Crumbles 3 (5.3 s) — 잘게 부서지는 소리. 진짜 설탕 붓는 소리는 직접 올리기 권장 |
| `crack` | 달고나에 금이 갈 때 (찍기 너무 셈, 누르기 실패, 앞으로 뽑기) | 한 번 "쩌적", 높이 조금씩 달리 | 1571353871 Ice crack sound · 112737750172501 ice crack sfx123 · 9113538220 Bone 2 Single Crunch (2.6 s) |
| `fire` | 녹이기·소다 단계 내내 (연탄불) | 반복, 국자가 불에 가까울수록 크고 조금 높게 | 2787093357 forest fire · 1185303834 wildfire · 150367086 Torch_Burn · 77688442375055 Crackling Fireplace (음악 섞였는지 확인) |
| `stirDry` | 가루 상태에서 저을 때 | 반복, 젓는 속도 = 크기·재생 속도 | 9113597177 Brush Scrub Rubbing On Wood Floor 3 (1.5 s) · 9113597285 … 5 (1.6 s) · 9120081384 Tissue Paper Movement 3 (1.4 s) |
| `stirCrystal` | 결정 상태에서 저을 때 | 〃 | 9113381863 Beads Pick Up 4 (3.6 s) · 106303743730403 marbles |
| `stirLiquid` | 녹는 중·액체 상태, 소다 넣기 전 | 〃 (작게) | 9116146746 Kelp Movement 302 (3.3 s) · 73232090200005 Custard Boiling |
| `stirCream` | 소다 넣고 부풀 때 (걸쭉) | 〃 (둔하게) | 9126209045 Wet Newspaper Squish 14 (1.3 s) · 9120649397 … 7 (1.8 s) · 9125410075 Bubbles Suds Gurgly Water (8.4 s) |

## 아직 코드에 연결 안 한 소리 (다음에)
| 단계 | 원하는 소리 | 후보 |
|---|---|---|
| 젓가락이 국자에 닿음 | 가끔 "땡" | 9125616884 Keys Handling Small Ring With Metal Clinks (0.6 s) |
| 소다 넣기 | 액체에 닿을 때 "치익-쉬" | 95017080310058 Open soda can 2 · 123359260762085 Opening Soda Can #2 |
| 부풀기 | "부글부글" | 73232090200005 Custard Boiling · 9113598224 Bubble Bath Bubbles Low Level Popping (12.4 s) |
| 녹는 중 / 탈 때 | "지글" / "치익" | 7056816387 Cooking Sizzle Noise · 9065756741 sizzle sfx · 70429057022490 burn sizzle |
| 붓기 | 끈적한 "툭" | 9126209045 Wet Newspaper Squish 14 |
| 누르기 | 금속판 "착" | 9114528679 Fork On Plate 28 (2.1 s) |
| 찍기 | 철사 틀 "딸깍" | 9125616884 Keys Handling (0.6 s) |
