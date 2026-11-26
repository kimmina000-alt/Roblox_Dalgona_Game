# 여러 AI가 같이 작업할 때 보는 안내 (달고나 골목)

- 처음 쓴 날: 2026-11-26 (묶음 1128 머지 직후, main 796b6f6, Studio 장소 버전 234)
- 대상: 이 저장소에서 일하는 모든 AI 세션 (Claude Code 여러 세션, 다른 회사 AI 포함)
- 이 문서는 "어떻게 같이 일하나"를 모은 것이다. 게임 내용은 다른 문서가 기준이다 (1장 표).
- 바뀌면 이 문서도 고친다. 고친 날과 이유를 맨 아래 "고친 기록"에 한 줄 남긴다.

---

## 0. 꼭 지킬 것 (요약)

1. **사용자는 한국어로 쓴다. 답도 한국어로.** 문서·커밋 설명 안 주석도 한국어(커밋 제목은 영어로 써 온 관례가 있음).
2. **자기 브랜치에만 커밋·푸시한다. main에 직접 머지하지 않는다.** main 머지는 묶음 끝에 한 번, 사용자 승인 뒤 (3장).
3. **Rojo는 쓰지 않는다.** `rojo serve`를 켜지 말고, 사용자에게 Connect를 부탁하지 말 것 (2026-11-24 사용자 결정).
4. **평소에는 Studio에 스크립트를 넣지 않는다.** 묶음 시험 때 시험 담당 한 세션만 넣는다 (4장). Play를 켜기 전에 다른 세션에 알린다.
5. **장소 저장(save_place)은 main 머지 뒤 한 번만.** 저장하면 그때 Studio에 있는 다른 세션의 저장 안 된 모델 변경도 같이 저장된다 → 저장 전에 무엇이 같이 들어가는지 사용자에게 알린다.
6. **고정된 것은 건드리지 않는다**: 반죽 붓기(`Steps/Pour` 한 방울씩)와 누른 모양(`BatterMesh.rebuild` 둥근 턱). 바꿔야 하면 먼저 사용자에게 묻는다 (CLAUDE.md "고정").
7. **`레퍼런스/`는 커밋하지 않는다.** (사용자 원본 모델·사진, Blender 결과 glb가 들어 있음)
8. **실제 상표·실제 캐릭터·오징어 게임 IP는 쓰지 않는다.** 이름도 실제 캐릭터와 겹치지 않게 (예: "춘식이" → "고등어 아저씨", AI 너구리 사장님은 다른 게임 캐릭터와 닮아 되돌림).
9. 사용자에게 묻는 질문은 한 곳(PM 세션 또는 사용자가 직접 말 거는 세션)에서. 보고는 짧게.

---

## 1. 어디에 무엇이 있나

| 무엇 | 파일 | 메모 |
|---|---|---|
| 작업 규칙·코드 구조·Studio 에셋 | `CLAUDE.md` | Claude가 자동으로 읽음. 다른 AI도 먼저 읽을 것 |
| 이 문서 (같이 일하는 법) | `docs/AI_COLLAB_GUIDE.md` | |
| 게임 기획 기준 (결정 D1~D58) | `docs/GAME_DESIGN_DOCUMENT.md` | **다른 문서와 다르면 이것이 기준**. 13장 결정표, 14~18장 D33~D58 |
| 진행 현황·묶음 기록·다음 할 일 | `docs/WORK_PRIORITIES.md` | 묶음이 끝날 때마다 갱신 (`docs/priorities-1117` 브랜치에서 고치고 묶음 때 main으로) |
| 개발 순서·미니게임 조작 | `docs/DEVELOPMENT_PLAN.md` | 4장 미니게임, 6장 개발 순서 |
| 움직임 기준값 | `docs/MOTION_REFERENCE_ANALYSIS.md` | 실제 달고나 영상 분석 |
| 가게 성장 수치 | `docs/SHOP_GROWTH_PLAN.md` | 설비 5단계·알바·공장 |
| 경제·성능·사운드·아트 | `docs/ECONOMY_BALANCE.md`, `PERFORMANCE_BUDGET.md`, `SOUND_CANDIDATES.md`, `ART_AND_ASSET_GUIDE.md`, `DALGONA_LOOK.md`, `MACHINE_ERAS.md` | 일부는 옛 내용이 섞임 → GDD가 우선 |
| 옛 작업 일지 | `docs/WORKLOG.md` | 11-18까지만. 지금 현황은 WORK_PRIORITIES |
| 수치 한곳 | `src/shared/GrowthConfig.lua`(경제·성장), `src/shared/DalgonaConfig.lua`(제작) | 숫자는 여기서 고친다 |
| Studio 동기화 도구 | `tools/studio/checksum.py`, `tools/studio/studio_checksum.lua` | 4장 |
| 기계 직접 만들기 자동 시험 | `tools/studio/machine_make_drive.lua` | 5장 |
| Blender 모델 스크립트 | `tools/blender/*.py` | 결과 glb는 `레퍼런스/` 아래 (커밋 안 함) |

---

## 2. 세션(AI)마다 맡는 일

여러 세션이 동시에 돈다. 같은 파일을 두 세션이 고치지 않게 맡은 범위를 지킨다.

| 세션 | 맡는 것 | 주로 고치는 파일 |
|---|---|---|
| 달고나 게임 (총괄) | 묶음 main 머지, 머지 뒤 장소 저장 | — |
| PM | 묶음 정리·시험 브랜치 만들기·우선순위 문서·사용자 질문 모으기 | `docs/WORK_PRIORITIES.md` |
| 기획 | 결정(D번호) 정리, 문서 브랜치 `docs/*` | `docs/GAME_DESIGN_DOCUMENT.md` 등 |
| 제작 화면 | 손 제작 미니게임·기계 직접 만들기 화면 | `src/client/Making/*`, `MakingClient`, `MachineMake*` |
| 저장·부지 (시험 담당) | 저장·경제·판매·부지 서버, **묶음 시험 때 Studio 동기화** | `src/server/Services/*`, `GrowthConfig` |
| UI | 화면 UI (UiStyle) | `src/client/*Ui*`, `Hud`, 창 스크립트 |
| 3D / 손님 NPC | Blender 스크립트, Studio 에셋 | `tools/blender/*`, Studio `Assets` |

- 지금(2026-11-26)은 사용자가 한 세션에게 "묶음 진행해"라고 하면 그 세션이 시험 브랜치 → Studio 동기화 → 시험 → (사용자 승인) main 머지 → 장소 저장까지 해도 된다. 그때도 다른 세션에 Studio 쓴다고 먼저 알린다.
- 다른 세션에 보낼 보고: "브랜치 이름 + 커밋 + 한 줄". 길게 쓰지 않는다.

---

## 3. 브랜치와 묶음(batch) 흐름

```
기능 브랜치 (feat/… fix/… claude/… docs/…)  ← 각 세션이 커밋·푸시만
        │  묶음 끝
        ▼
test/batch-<날짜>  ← origin/main에서 새로 만들고, 이번 묶음 브랜치들을 --no-ff로 합침
        │  Studio 동기화(4장) → 1인·2인 Play 시험 → 고칠 것은 원래 브랜치에서 고쳐 다시 합침
        ▼
main  ← 사용자 승인 뒤 (보통 fast-forward: git push origin test/batch-XXXX:main)
        │
        ▼
Studio 장소 저장 (main과 Studio 스크립트가 같은지 combined 체크섬으로 확인한 뒤)
```

- 브랜치 이름: `feat/<기능>-<MMDD>`, `fix/…`, `docs/…`, `claude/…`(Claude 앱 세션이 만든 것). 날짜는 그 작업을 시작한 날.
- 묶음 이름 = 날짜 (`test/batch-1128`). 같은 날 두 번이면 `1125b`.
- 합칠 브랜치 고르기: `git branch -r --no-merged origin/main`으로 남은 것을 보고, **Studio에 먼저 Import해야 하는 브랜치는 Import가 됐는지 Studio에서 확인한 뒤에만** 넣는다 (예: `feat/basic-npc-1126`은 `CustomerRig`를 새 모델 기준으로 바꾸므로, 모델을 Import하기 전에 넣으면 손님이 깨짐).
- 충돌 확인: `git merge-tree --write-tree origin/main origin/<브랜치>` (출력이 실패면 충돌).
- 머지 뒤 `docs/WORK_PRIORITIES.md`에 "묶음 NNNN 끝남 (main 커밋, 장소 버전): 한 일 · 못 한 일 · 사용자 확인할 것"과 다음 묶음 목록을 적는다.
- 커밋 끝 줄 (Claude): `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` — 다른 AI는 자기 이름으로.

---

## 4. Studio 동기화 (Rojo 없이, MCP + 체크섬)

- 장소: "Vantablack_Dev의 장소: 11172026_1" (placeId 122010099115917). Studio MCP 도구로 다룬다 (`list_roblox_studios`로 studio_id 받기).
- 경로 대응 (`default.project.json`): `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`. `.server.lua` = Script, `.client.lua` = LocalScript, 나머지 = ModuleScript.

**순서**
1. 시험 브랜치를 체크아웃한 worktree에서 `python tools/studio/checksum.py . --json <임시파일>` → 스크립트별 체크섬 + 마지막 줄 `combined`.
2. Studio(Edit)에서 `tools/studio/studio_checksum.lua` 내용을 `execute_luau`로 실행 → 같은 형식.
3. 줄끼리 비교: 다른 것 = 고칠 것, 로컬에만 있음 = 새로 만들 것, Studio에만 있음 = 지울 것.
4. 고치기: 작은 차이는 `multi_edit`로 diff 부분만 바꾸기 (`git diff origin/main HEAD -- <파일>`을 보고 old/new 문자열). 새 스크립트는 `multi_edit`에 `className`과 빈 `old_string`으로 전체 내용.
5. 다시 2번 → **combined 값이 로컬과 같아야 끝.** 다르면 그 스크립트만 줄 단위 해시로 비교해 틀린 줄을 찾는다 (긴 파일을 옮겨 적다 한글 한 글자가 틀린 적이 있음 — 2026-11-26 `빨갛게`→`빨겛게`).
6. Play 시험 (5장). 장소 저장은 main 머지 뒤에만.

**함정**
- 저장소 파일은 CRLF/LF가 섞여 있다 (autocrlf). 체크섬은 CRLF→LF로 바꿔 셈. 스크립트로 파일을 고칠 때는 줄바꿈을 그대로 두거나 `\r?\n`으로 찾는다. Bash heredoc 안 파이썬에 `\n`·`\\`를 쓰면 깨지기 쉬움 → 파이썬 파일을 따로 써서 돌리는 게 안전.
- Studio 스크립트 Source는 LF. `multi_edit`의 old_string도 LF로.
- `execute_luau`에서 `require`하면 게임이 실제로 쓰는 모듈과 **다른 복사본**이 나온다 (서버 `PlayerDataService.get`이 nil). 실제 상태는 클라이언트에서 `Remotes.GetPlayerState:InvokeServer()`로 보거나 게임 속성·출력창으로 본다.
- `rbxassetid://203785492` "Asset type does not match" 경고는 아바타 에셋이라 무시 (원래 있음).

---

## 5. 시험하는 법

| 무엇 | 어떻게 |
|---|---|
| 시작 | `start_stop_play(true)` → `get_console_output`으로 오류 확인. 들어오면 "자리 비운 동안" 창(`PlayerGui.OfflineReport`)이 화면을 가리니 시험 중에는 `Enabled = false` |
| 손 제작 | 작업대 앞에서 E, 또는 클라이언트에서 `PlayerScripts.Client.MakingClient.StartMaking:Fire()`. Studio에서만 `MakingClient.TestPointer:Fire(down, x, y)`로 손가락 입력 주입 (같은 복사본 문제 없음: MakingClient가 직접 받음) |
| 기계 직접 만들기 (2·3단계) | `tools/studio/machine_make_drive.lua`를 Play 중 Client에 실행 → 출력 `[MachineMake] test … -> Q.. 등급`. 시험 모드는 서버 검사와 같은 `MachineMakeRules.evaluate`를 돌림. 실제 서버 판은 테스트 계정에 재료(특히 소다)가 있어야 함 |
| 화면 보기 | `screen_capture` — **카메라 위치를 꼭 넘긴다** (안 넘기면 플레이 카메라를 Custom으로 되돌림). 제작 중에는 CameraRig가 매 프레임 카메라를 고정하므로 넘기지 않아도 제작 화면이 찍힘 |
| 결과 로그 | 손 제작 `[Making] result …`(클라) / `[Production] …`(서버), 기계 `[MachineMake] …`, 판매 `[Sales] …`, 저장 `[Data] saved …` |
| MCP 마우스 입력 | 실제보다 느려서 젓기 속도 판정 시험에는 맞지 않음 → 위 주입 방식 |
| 2인 시험 | Studio Test 탭 Clients 2 (사용자가 띄움). 노점·임대 두 상태, 남의 가게 버튼이 안 보이는지 |
| 테스트 계정 | Vantablack_Dev (Lv25, 기계 4단계·공장 있음). Studio 시험이 저장 데이터를 실제로 바꾼다 (젓가락·재료·코인). 큰 데이터 조작(레벨·기계 단계 바꾸기)은 하지 않는다 |

---

## 6. 코드 규칙

- Luau. 한 스크립트 로컬 변수 200개 한도 → 미니게임은 단계마다 모듈 하나 (`Making/Steps/*`).
- **코인·재고·품질은 서버가 정한다.** 클라이언트는 입력 기록만 보내고 서버가 같은 식으로 다시 계산 (손 제작 `ProductionService` + `shared/Scoring`, 기계 직접 만들기 `MachineMakeService` + `shared/MachineMakeRules`, 뽑기 `shared/PpopgiRules`). 클라이언트가 보낸 점수를 그대로 믿는 코드를 새로 만들지 않는다.
- RemoteEvent/Function은 타입·범위·호출 빈도를 검사. 세션 ID, 단계 순서, 최소·최대 시간 확인.
- 수치는 `GrowthConfig` / `DalgonaConfig` 한곳에. 저장 형식을 바꾸면 `PlayerDataService`의 스키마 버전·MIGRATIONS를 올린다 (지금 v17).
- 화면 UI는 공용 `src/shared/UiStyle.lua` (아늑한 나무 판 + 사탕 버튼). 폰 가로 화면(약 750×310)을 기준으로 넓고 낮게.
- 편집 화면 틀: `Workspace.PlotLayout`(가게 부지), `WorkstationLayout`(손 작업대), `MachineLayout`(기계 2~4단계), `FactoryLayout`(공장). 게임 시작 때 서버가 ServerStorage로 옮겨 쓴다. 부품 이름을 바꾸면 새 부품 취급 (`LayoutTemplate`의 LayoutKey). 자세한 것은 CLAUDE.md 에셋 절.
- glb를 Roblox로 가져오면 앞뒤(Z)가 뒤집힌다. 금속도·거칠기는 안 넘어와서 SurfaceAppearance를 직접 넣는다. `rbxasset://` 내장 텍스처는 게임 안에서 막힘.
- 주석은 한국어로, 왜 그렇게 했는지와 날짜·결정 번호(D..)를 남긴다 (지금 코드가 다 그렇게 되어 있음).

---

## 7. 지금 상태 (2026-11-26)

- main **796b6f6** = 묶음 1128, Studio 장소 **버전 234** (스크립트 107개, combined 체크섬 857229036).
- 묶음 1128에 들어간 것: D35 2·3단계 기계 직접 만들기(사용자 기계 모델, 서버 재계산, 도감 기록, 붓기는 손을 뗄 때 끝남), 손 작업대 "E 달고나 만들기" 버튼 안 뜨던 것(`PromptStyle`), D35 문서.
- 장소 234에 같이 저장된 Studio 변경 (다른 세션 작업): 2·3단계 사용자 기계 메시, 4단계 파스텔 기계(`MachineLayout.Stage4`), 파스텔 공장(`FactoryLayout`의 '기계 ' 폴더). 예전 코지 디자인은 `ServerStorage.Backup_1126`.

**다음 묶음 1129 — 사용자 Import가 먼저**

| 할 일 | 상태 | 메모 |
|---|---|---|
| 벽면 진열장 Import | 🙋 사용자 | `레퍼런스/wall_case/dalgona_wall_case.glb` → `PlotLayout.ShopModel` 벽에 (`WallCaseBack` Role "벽면 진열장"). 없으면 진열장 6단계는 "준비 중" |
| 손 작업대 앞 긴 진열장·손님 의자 Import | 🙋 사용자 → 코드 | `레퍼런스/user_furniture/dalgona_user_furniture.glb` (HandCounterShelf, HandCounterShelf_Glass, CustomerStool). Import 뒤 놓는 코드 필요 |
| 임시 기본 손님 NPC | 🙋 사용자 → 머지 | `레퍼런스/customers_basic/dalgona_customers_basic.glb` Import 뒤 `feat/basic-npc-1126` 합침 |
| D47 공장 대량 납품 | 기획만 있음 | GDD 14장 D47 |

**확인 못 한 것 / 사용자에게 물을 것**
- 기계 직접 만들기를 실제 서버로 한 판 (테스트 계정 소다 0) — 재료 빠짐·보관함·도감 기록.
- 2인 시험 (1128).
- 3단계 분홍 자판기 앞면 텍스처에 만화 캐릭터 그림 → GDD 4-1 "캐릭터·상표는 안 그림"과 다른지.
- 파스텔 공장: 벨트·김 표시(`Fac_Pt_BeltStart/BeltEnd/Steam`)가 없어 애니메이션 위치가 어긋날 수 있음.
- 남은 브랜치 `feat/build-mode-1125`, `feat/market-1125`, `feat/customers-ai-1125`는 다른 브랜치로 대신 들어갔거나 보류(AI 손님) — 합치지 말 것.

---

## 8. 고친 기록

| 날짜 | 누가 | 무엇 |
|---|---|---|
| 2026-11-26 | Claude (문서 검토·묶음 1128 세션) | 처음 씀. 체크섬 도구(`tools/studio/checksum.py`, `studio_checksum.lua`)와 기계 자동 시험(`machine_make_drive.lua`) 같이 넣음 |
