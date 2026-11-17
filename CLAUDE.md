# 달고나 골목 (Dalgona Alley) — 작업 메모

- 사용자는 한국어로 쓴다. 답도 한국어로.
- 원본은 GitHub(`kimmina000-alt/Roblox_Dalgona_Game`). 기능마다 브랜치, 사용자가 승인하면 `main`에 머지한다.
- `레퍼런스/`는 커밋하지 않는다.
- 계획: `docs/DEVELOPMENT_PLAN.md` (4장 미니게임, 6장 개발 순서), 움직임 기준값: `docs/MOTION_REFERENCE_ANALYSIS.md`.

## 코드 구조 (Rojo, `default.project.json`)
| 폴더 | Studio 위치 | 내용 |
|---|---|---|
| `src/shared` | ReplicatedStorage.Shared | `DalgonaConfig`(수치), `Scoring`(Q 공식, 서버·클라 공용), `CutterShapes`(도안 외곽선, 자동 생성), `ShapeCatalog`(도안 목록·가격), `CutterRig`(작업대 틀에 도안 끼우기) |
| `src/server` | ServerScriptService.Server | `ServerMain`, `Services/ProductionService`(세션·서버 점수), `Services/WorkstationBuilder`(작업대를 Part로 생성) |
| `src/client` | StarterPlayerScripts.Client | `MakingClient`(진입점), `Making/`(Ui, CameraRig, Pointer, Station, Stir, Heat, Dalgona, ChopstickPicker, CutterPicker), `Making/Steps/`(단계마다 모듈 1개) |

미니게임 단계는 모듈 하나씩 (Luau 로컬 변수 200개 제한).

## 에셋 (Rojo 밖, Studio에만 있음)
- `ServerStorage.Assets.LadleMesh`: 사용자가 만든 구리 국자 (`레퍼런스/dalgona_gukja.glb`를 Studio에서 가져옴). `WorkstationBuilder.attachLadleMesh`가 투명한 판정용 원기둥 `Ladle.Bowl`에 맞춰 붙인다. 게임 코드는 계속 `Bowl` 기준으로 움직인다.
- `ServerStorage.Assets.BrazierMesh / CoalMesh / CoalBurntMesh`: 사용자가 만든 화로·연탄·다 탄 연탄 (`레퍼런스/dalgona_wharo.glb`). 화로는 CorrodedMetal(낡은 금속). 연탄은 `WorkstationBuilder.setCoal(ws, 남은 양)`으로 높이·색이 바뀌고, 작업대 속성 `CoalLeft`에 남는다. 한 판 끝날 때마다 서버가 0.1씩 줄이고, 0이면 다음 판 시작 때 새 연탄.
- `ServerStorage.Assets.PresserMesh`: 누름판 (`dalgona_nulumpan.glb`), 금속 + 국자와 같은 광택 텍스처.
- `ReplicatedStorage.Assets.Chopsticks`: 나무젓가락·포장지 7조각 (`dalgona_joggalack.glb`). 클라이언트도 써야 해서 ReplicatedStorage. 조각마다 속성 `Offset`(짝 안에서 상대 위치). 포장지 = 흰 종이, 젓가락 = 연한 나무. 제작 시작 때 `Making/ChopstickPicker`가 고르기 연출을 하고, 고른 한 짝(`Chosen`)으로 젓는다.
- `ServerStorage.Assets.StarCutterMesh`: 예전 별 틀 (지금은 안 씀, 도안 틀 전체로 바뀜).
- 도안 틀 전체 (`ReplicatedStorage.Assets.Cutters` — 클라이언트 미리 보기·교체에 필요, 메시 이름 `Cutter_<id>`, 금속 광택 SteelShine 넣어 둠): `tools/blender/cutters.py` → `레퍼런스/dalgona_cutters.glb`(Cutter_<id>, 23개). 사용자 모형틀(3D.blend 모형틀1~8)이 있는 도안은 그 모델, 없는 도안은 `shapes.py`로 생성. 안쪽 선이 있는 도안(문어·호랑이·공룡·궁전·Master 4종)은 먼저 `python tools/blender/design_shapes.py`(OpenCV) → `shape_data.json`. `src/shared/CutterShapes.lua`는 자동 생성.
- `ServerStorage.Assets.SugarBowlMesh / SugarHeapMesh / SodaCanMesh / SodaLabelMesh / SodaPowderMesh / WoodSpoonMesh / TinSpoonMesh`: Claude가 `tools/blender/props.py`로 만든 양은 설탕 그릇·소다 깡통·숟가락 (`레퍼런스/dalgona_props.glb`). 빌더가 붙이고 게임용 부품은 투명하게 남김. 스크립트를 다시 돌리면 `PROP_CENTER` 값도 같이 고친다.
- `ReplicatedStorage.Assets.Fx`: 설탕 결정·설탕 더미·소다 가루·부푼 거품 (`tools/blender/fx.py` → `레퍼런스/dalgona_fx.glb`). 클라이언트 `Making/Fx`가 쓰고, 없으면 예전 Part 모양.
- glb는 Roblox로 가져오면 앞뒤(Z)가 뒤집힌다. 다른 메시를 바꿀 때도 방향을 화면으로 먼저 확인한다.
- glb의 금속도·거칠기 값(Principled BSDF 숫자)은 Roblox로 넘어오지 않는다. 그래서 `LadleMesh` 안에 SurfaceAppearance `CopperShine`을 직접 넣었다: 금속도 텍스처 `rbxassetid://75555295293901`(0.95), 거칠기 텍스처 `rbxassetid://116334782975968`(0.25), 색 (214,132,72). `rbxasset://` 내장 텍스처는 게임 안에서 막혀서 쓸 수 없다.

## Studio 동기화
- Studio 장소: "Vantablack_Dev의 장소: 11172026_1" (placeId 122010099115917).
- 이 PC에는 Rojo가 없고, Studio Assistant의 HTTP 허용 목록 때문에 로컬 서버에서 받아 오는 방식도 막혀 있다.
  그래서 지금은 Studio MCP(`multi_edit` / `execute_luau`로 `Source` 설정)로 넣는다. **`src/`와 Studio를 항상 같게 유지한다.**
- 확인 방법: 양쪽에서 같은 체크섬(`x = (x*31 + byte) % 2147483647`)을 계산해 모든 스크립트가 같은지 본다.
- Rojo를 설치하면 `rojo serve`로 바꾼다 (프로젝트 파일은 이미 맞춰 둠).

## 테스트
- Play → 작업대 앞에서 E (또는 클라이언트에서 `MakingClient.StartMaking:Fire()`).
- Studio에서만 `MakingClient.TestPointer:Fire(down, x, y)`로 손가락 입력을 프레임 단위로 넣을 수 있다 (자동 테스트용).
  MCP 마우스 입력은 실제 속도보다 느리게 실행돼서 젓기 속도 판정 테스트에는 맞지 않는다.
- MCP `screen_capture`는 카메라 위치를 꼭 넘긴다 (안 넘기면 플레이 카메라를 Custom으로 되돌림). 제작 중에는 CameraRig가 매 프레임 카메라를 다시 고정한다.
- 결과는 출력창 `[Making] result ...`(클라)와 `[Production] ...`(서버)에 단계별 점수가 찍힌다.
