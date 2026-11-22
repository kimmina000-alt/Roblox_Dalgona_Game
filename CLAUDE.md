# 달고나 골목 (Dalgona Alley) — 작업 메모

- 사용자는 한국어로 쓴다. 답도 한국어로.
- 원본은 GitHub(`kimmina000-alt/Roblox_Dalgona_Game`). 기능마다 브랜치, 사용자가 승인하면 `main`에 머지한다.
- `레퍼런스/`는 커밋하지 않는다.
- 계획: `docs/DEVELOPMENT_PLAN.md` (4장 미니게임, 6장 개발 순서), 움직임 기준값: `docs/MOTION_REFERENCE_ANALYSIS.md`.

## 코드 구조 (Rojo, `default.project.json`)
| 폴더 | Studio 위치 | 내용 |
|---|---|---|
| `src/shared` | ReplicatedStorage.Shared | `DalgonaConfig`(수치), `GrowthConfig`(저장·부지·재료·레벨 수치, Phase 2), `Scoring`(Q 공식, 서버·클라 공용), `CutterShapes`(도안 외곽선, 자동 생성), `ShapeCatalog`(도안 목록·가격), `CutterRig`(작업대 틀에 도안 끼우기) |
| `src/server` | ServerScriptService.Server | `ServerMain`, `Services/ProductionService`(세션·서버 점수, `hooks.canStart/onResult`로 경제 연결), `Services/PlayerDataService`(DataStore 저장: 스키마 버전·MIGRATIONS, 세션 잠금, 60초 자동 저장, 퇴장·BindToClose 저장), `Services/PlotService`(가게 부지 6칸 `workspace.ShopPlots`: 배정·반환·이름 간판, 손 작업대 자리·기계 1자리·공장 문 자리), `Services/EconomyService`(재료 상점, 제작 끝 → 재료 소비·재고·EXP·레벨업, HUD 상태 전송), `Services/WorkstationBuilder`(작업대를 Part로 생성), `Services/FactoryBuilder`(Lv5 공장 배치·색칠), `Services/StallDecor`(깅엄 식탁보·러그·색감 보정, 1단계 꾸미기: 은박지·설탕 결정·틀 쟁반·막대 통·포장 달고나 진열대, 테이블 오른쪽 +6 포장 공간 PackArea: 매트·비닐 통·빵끈 통) |
| `src/client` | StarterPlayerScripts.Client | `MakingClient`(진입점), `Hud`(코인·레벨·재료·보관함 HUD + 재료 상점, 제작 화면 중엔 숨김), `Making/`(Ui, CameraRig, Pointer, Station, Stir, Heat, Dalgona, SugarLook, Fx, Sfx, ChopstickPicker, CutterPicker, Toon=도구 만화 외곽선, ChopstickCup=젓가락 통, BatterMesh=EditableMesh 반죽, Showcase=완성 달고나(포장했으면 포장째) 화면 정중앙에 띄워 보여 주기, Ppopgi=뽑기(7단계, 선택: 바늘로 점선 긁기, 판정은 shared/PpopgiRules), Supplies=재료가 0이면 작업대 통을 빈 통으로, Pack=모양 찍기 뒤 포장할지 고르면 테이블 오른쪽 포장 공간에서 네모 비닐 씌우기·빵끈 집어 두 번 끌어 묶기, HelperLadles=화로 위 알바생 국자 움직임, FoamMesh=소다 많이 넣었을 때 국자 넘쳐 흘러내리는 거품 3D, BagShape=입구 벌린 포장 봉투 정점 데이터(자동 생성, `tools/blender/bag.py`)), `Making/Steps/`(Stick=막대 꽂기 포함)(단계마다 모듈 1개) |

미니게임 단계는 모듈 하나씩 (Luau 로컬 변수 200개 제한).

## 고정 (사용자가 "너무 좋다, 고정해" 한 것 — 바꾸지 말 것, 2026-11-20)
- 반죽 붓기: `Steps/Pour` 한 방울씩 떨어뜨리기 (먼저 떨어진 방울과 경계가 흐려지며 이어짐). 2026-11-21 사용자가 바꿈: 국자를 눌러 철판 위로 끌면 국자 그릇 아래로 떨어지고, 누른 채로 끌면 따라 떨어짐 (국자는 붓는 동안에도 보임). 예전 오른쪽 반투명 판(`Ui:setPad`)은 안 씀.
- 누른 모양: `BatterMesh.rebuild` 가운데 평평하게 내려앉고 가장자리 두툼한 둥근 턱 (RIM_* 값), 기포는 부을 때 보이다 서서히 사라짐.
- 다른 기능을 고치다 이 둘이 달라지면 안 된다. 바꿔야 하면 먼저 사용자에게 묻는다.

## 에셋 (Rojo 밖, Studio에만 있음)
- `ServerStorage.Assets.LadleMesh`: 사용자가 만든 구리 국자 (`레퍼런스/dalgona_gukja.glb`를 Studio에서 가져옴). `WorkstationBuilder.attachLadleMesh`가 투명한 판정용 원기둥 `Ladle.Bowl`에 맞춰 붙인다. 게임 코드는 계속 `Bowl` 기준으로 움직인다.
- `ServerStorage.Assets.BrazierMesh / CoalMesh / CoalBurntMesh`: 사용자가 만든 화로·연탄·다 탄 연탄 (`레퍼런스/dalgona_wharo.glb`). 화로는 CorrodedMetal(낡은 금속). 연탄은 `WorkstationBuilder.setCoal(ws, 남은 양)`으로 높이·색이 바뀌고, 작업대 속성 `CoalLeft`에 남는다. 한 판 끝날 때마다 서버가 0.1씩 줄이고, 0이면 다음 판 시작 때 새 연탄.
- `ServerStorage.Assets.PresserMesh`: 누름판 (`dalgona_nulumpan.glb`), 금속 + 국자와 같은 광택 텍스처.
- `ReplicatedStorage.Assets.Chopsticks`: 나무젓가락·포장지 7조각 (`dalgona_joggalack.glb`). 클라이언트도 써야 해서 ReplicatedStorage. 조각마다 속성 `Offset`(짝 안에서 상대 위치). 포장지 = 흰 종이, 젓가락 = 연한 나무. 제작 시작 때 `Making/ChopstickPicker`가 고르기 연출을 하고, 고른 한 짝(`Chosen`)으로 젓는다.
- `ServerStorage.Assets.Factory`: Lv5 달고나 공장 (Claude가 `tools/blender/factory.py`로 만든 `레퍼런스/factory/dalgona_factory.glb`, 부품 45개, 텍스처 포함). 가져온 방향: Blender (x,y,z) → 모델 (-x, z, y), 앞 = -Z. 벽은 뒤·왼쪽 끝에만 있고 오른쪽 짧은 끝(배출 상자 쪽, 모델 -X)이 열려 있음. 2026-11-22부터 `FactoryDisplay`가 해금된 가게 뒤 공장 부지(`Plot<i>.FactoryLot`, 28×44)에 -90° 돌려 놓아 그 열린 끝이 가게 뒷문을 봄 (공용 (0,0,30) 공장은 없앰).
- `ServerStorage.Assets.MachineLine`: Lv4 연속 생산 설비(컨베이어 라인, `factory.py ... line` → `레퍼런스/line/dalgona_line.glb`, 부품 39개). `MachineDisplay`가 가게 기계 자리(`Plot<i>.Machine`, 4단계)에 줄여 놓음 (시험 자리는 없앰). 2·3단계 판매기·자판기는 `MachineDisplay`가 부품으로 만듦. 공장과 라인 모두 파스텔 사탕 공장 그림체(2026-11-19).
- `ServerStorage.Assets.StarCutterMesh`: 예전 별 틀 (지금은 안 씀, 도안 틀 전체로 바뀜).
- 도안 틀 전체 (`ReplicatedStorage.Assets.Cutters` — 클라이언트 미리 보기·교체에 필요, 메시 이름 `Cutter_<id>`, 금속 광택 SteelShine 넣어 둠): `tools/blender/cutters.py` → `레퍼런스/dalgona_cutters.glb`(Cutter_<id>, 23개). 사용자 모형틀(3D.blend 모형틀1~8)이 있는 도안은 그 모델, 없는 도안은 `shapes.py`로 생성. 안쪽 선이 있는 도안(문어·호랑이·공룡·궁전·Master 4종)은 먼저 `python tools/blender/design_shapes.py`(OpenCV) → `shape_data.json`. `src/shared/CutterShapes.lua`는 자동 생성.
- `ServerStorage.Assets.SugarBowlMesh / SugarHeapMesh / SodaCanMesh / SodaLabelMesh / SodaPowderMesh / WoodSpoonMesh / TinSpoonMesh`: Claude가 `tools/blender/props.py`로 만든 양은 설탕 그릇·소다 깡통·숟가락 (`레퍼런스/dalgona_props.glb`). 빌더가 붙이고 게임용 부품은 투명하게 남김. 스크립트를 다시 돌리면 `PROP_CENTER` 값도 같이 고친다.
- `ReplicatedStorage.Assets.Fx`: 설탕 결정·설탕 더미·소다 가루·부푼 거품 (`tools/blender/fx.py` → `레퍼런스/dalgona_fx.glb`). 클라이언트 `Making/Fx`가 쓰고, 없으면 예전 Part 모양.
- 포장 봉투(입구 벌린 모양)는 Studio 에셋 없이 `tools/blender/bag.py`가 `src/client/Making/BagShape.lua`(정점)를 만들고, `Pack`이 EditableMesh로 조립. 실행: `"D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/bag.py -- <레퍼런스/bag> <저장소 루트>`
- `ServerStorage.Assets.Customers`: 손님 NPC 7종 (사용자 디자인 동물 손님, 2026-11-22). `tools/blender/customers.py` → `레퍼런스/customers/dalgona_customers.glb`, 같이 `src/shared/CustomerRig.lua`(부품 가운데·크기·관절·입·손, 자동 생성). Folder 안 `Customer_<id>` Model, 그 안 MeshPart `<id>_Head/_Body/_ArmL/_ArmR/_LegL/_LegR` (Anchored, 충돌 끔, PrimaryPart = Body, 팔레트 텍스처 1장 공용). Humanoid 없이 부품 나눔: 판매 코드가 관절 기준으로 부품 CFrame을 놓아 걷기·먹기. 사용자가 가장 가벼운 버전을 고름 (손님 1명 삼각형 4,800~8,100개) — 털 결·잔 곱슬은 넣지 말 것. 실행: `"D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/customers.py -- <레퍼런스/customers> <저장소 루트>`
- `BatterMesh`(반죽 3D)는 EditableMesh (2026-11-20 사용자가 Experience Settings > Security에서 켬). 정점을 직접 움직여 부은 결·누른 모양·찍힌 홈을 표현. 삼각형 한도(약 2만 개) 때문에 SEG 160 × RINGS 48. 꺼지면 예전 접힌 메시로 돌아감.
- glb는 Roblox로 가져오면 앞뒤(Z)가 뒤집힌다. 다른 메시를 바꿀 때도 방향을 화면으로 먼저 확인한다.
- glb의 금속도·거칠기 값(Principled BSDF 숫자)은 Roblox로 넘어오지 않는다. 그래서 `LadleMesh` 안에 SurfaceAppearance `CopperShine`을 직접 넣었다: 금속도 텍스처 `rbxassetid://75555295293901`(0.95), 거칠기 텍스처 `rbxassetid://116334782975968`(0.25), 색 (214,132,72). `rbxasset://` 내장 텍스처는 게임 안에서 막혀서 쓸 수 없다.

- 가게 작업대 틀 = 편집 모드 `Workspace.WorkstationLayout` (ㄷ자 카운터, (-50,0,10), 2026-11-21 교체). 사용자가 물건 자리를 직접 옮긴다 (막대 통 `Stage1Decor.StickBox`, 비닐 통 `PackArea.BagBin`, 빵끈 통 `PackArea.TieBox`는 묶음). 게임 시작 때 서버가 Workspace에서 빼서 `ServerStorage.Assets.WorkstationTemplate`으로 쓰고(`syncCounter`), 꾸미기(dress·streetLayout)는 다시 안 한다. 예전 노점 틀 백업: `ServerStorage.Backup.WorkstationTemplate_Old`. `counterLayout`·`StallDecor` 값을 바꿔도 저장된 틀에는 안 들어가므로, 다시 만들려면 사용자에게 먼저 묻는다 (옮긴 자리가 사라짐).

- 가게 부지 틀 = 편집 모드 `Workspace.PlotLayout` (부지 하나, 속성 `PlotCFrame` = 기준, 2026-11-22). 사용자가 울타리·건물·간판·파라솔·자리 표시·공장 문·입구를 직접 옮기거나 크기·색을 바꾸고, 부품을 지우거나 새로 넣을 수 있다. 서버(`PlotService`)가 코드로 6칸을 만든 뒤 부품 속성 `LayoutKey`로 틀과 맞춰 6칸 모두에 옮긴다 (게임 중에는 ServerStorage로 옮겨 안 보임). 작업대·기계·공장 부지는 이 틀에 없다. 진열대는 틀 안 `DisplayShelf`로 고친다 (`PlotService.applyChild`, 칸 Slot1~10 자리 = 진열 자리, 손님은 몸통 앞에 섬, 칸은 지워도 숨김만). 손 작업대는 노점·월세 밀림일 때 `HandStationSpot`(가게 밖), 월세를 내고 열리면 `HandStationInside`(가게 안, 게임에서는 안 보임) 가운데에 놓인다 (`PlotService.placeWorkstation`, 알바생·알바 국자도 같이 옮김). 바닥(Floor)·입구(Entry)·간판(Sign)·셔터·간판판(Header)·임대 종이·기계 자리·공장 문짝은 지워도 숨김만 됨.
- 공장 틀 = 편집 모드 `Workspace.FactoryLayout` (칠한 공장을 Plot1 공장 부지 자리에 놓은 것, 속성 `LotCFrame` = 그 부지 기준, 2026-11-22). 사용자가 공장 부품을 옮기거나 색·크기를 바꾸고 넣고 뺄 수 있다. 서버 `FactoryDisplay`가 시작 때 ServerStorage로 옮기고, 해금된 가게마다 `Assets.Factory`+style() 대신 이걸 복제해 같은 자리 관계로 놓는다. 부품 이름을 바꾸면 움직임(Anim)·제어대가 안 붙으니 이름은 그대로 둔다. 안의 `Lot`(바닥·울타리·표지판)은 6칸 공장 부지 모두에 옮겨짐 (바닥·표지판은 지워도 숨김만).
- 가게 건물 = 사용자 가게 3D `PlotLayout.ShopModel` (2026-11-23, 1.5배, 폭 46.7 × 깊이 82, 앞 가게 + 왼쪽 복도 + 뒤 자체 공장 방 안쪽 약 40×40, 부품 속성 Role). 속성 `CloneWhole`이라 `PlotService`가 6칸에 통째로 복제(계층·효과 유지). 간판 글씨 `OwnerName` = 주인 닉네임. 옛 가게 몸체·공장 방(폭 91)·꾸미기는 `ServerStorage.Backup_NewShop_1123`. 같은 줄 간격 `G.Plots.spacing` = 55. 진열 칸은 모델 유리 진열장 안, 가게 안 작업대 자리는 카운터와 뒷벽 사이, 기계 자리는 뒷벽(2·3단계 = 모델의 기계로 만든 `MachineLayout.Stage2/3` 틀), 공장 문은 왼쪽 복도 입구, 공장 기계는 모델 공장 방 가운데(FactoryLayout의 LotCFrame도 새 문 기준). 숨김만 되는 틀 부품은 글씨·그림도 꺼짐.
- 가게 안 손 작업대는 클라이언트 `Making/ViewScale`(`WorkstationScale.client.lua`)이 내 화면에서만 1/2로 보이게 함 (서버 값은 원래 크기, 속성 AtInside·ViewOrigin은 PlotService가 넣음). 내가 만들 때는 MakingClient가 `setFull(ws, true)`로 원래 크기. 알바생 미니미는 원래 크기(사용자 결정).
- 기계 틀 = 편집 모드 `Workspace.MachineLayout` 안 `Stage2`(철제 판매기)·`Stage3`(분홍 자판기)·`Stage4`(연속 생산 설비), 2026-11-22. 각 모델 안 분홍 판 `SlotAnchor` = 기계 자리 기준이라 모델째 옮겨도 그대로, 부품만 옮기면 바뀜. 가게 안 기계 위치는 PlotLayout의 `MachineSlot`을 옮긴다. `MachineDisplay`가 시작 때 ServerStorage로 옮김.
- 세 틀 모두 공통 모듈 `Services/LayoutTemplate`(LayoutKey = 경로#번째로 맞춤). 틀 부품 이름을 바꾸면 새 부품으로 취급된다.

## Studio 동기화
- Studio 장소: "Vantablack_Dev의 장소: 11172026_1" (placeId 122010099115917).
- 2026-11-22부터 **Rojo**(7.7.1, `C:\Tools\rojo\rojo.exe`)로 넣는다. `default.project.json`이 Shared·Server·Client·StarterGui(`src/gui`, 비어 있음)를 `$path`로 관리하고, 이 4곳에서 저장소에 없는 인스턴스는 Rojo가 지운다 (첫 연결 전 확인: Studio에만 있는 것 없음, 되돌리기용 장소 버전 152).
- **`rojo serve`는 한 번에 하나만.** Studio를 쓸 차례인 세션이 켠다.
  - 최신 main을 넣을 때: `.claude/worktrees/rojo-main`(main을 가리키는 전용 worktree)에서 켠다. 머지 뒤에는 `git -C .claude/worktrees/rojo-main checkout --detach origin/main`으로 갱신.
  - 자기 브랜치를 시험할 때: 자기 worktree에서 켠다.
  - **공유 폴더 `D:\Roblox\Roblox_Dalgona_Game`에서는 켜지 않는다** (옛 브랜치라 Studio 스크립트를 옛것으로 덮어씀 — 2026-11-22 실제로 일어남).
- 차례를 넘길 때: 내 serve를 끄고(Studio Rojo 플러그인 Disconnect) 다음 세션에 알린다. 다음 세션이 자기 폴더에서 serve를 켜고 사용자에게 Studio 플러그인 Connect(localhost:34872)를 부탁한다.
- **Rojo가 연결된 동안에는 MCP로 스크립트 `Source`를 쓰지 않는다** (덮어써짐). Studio 전용 에셋(ServerStorage.Assets, ReplicatedStorage.Assets, Workspace 모델·속성)은 지금처럼 MCP로 다룬다.
- 체크섬(`x = (x*31 + byte) % 2147483647`)으로 모든 스크립트가 `src/`와 같은지는 연결을 바꿀 때 한 번만 본다.
- Play를 켜기 전에 서로 알리는 규칙은 그대로.
- 스트리밍 반경 `Workspace.StreamingTargetRadius = 256` (2026-11-22, 장소에 저장).

## 테스트
- Play → 작업대 앞에서 E (또는 클라이언트에서 `MakingClient.StartMaking:Fire()`).
- Studio에서만 `MakingClient.TestPointer:Fire(down, x, y)`로 손가락 입력을 프레임 단위로 넣을 수 있다 (자동 테스트용).
  MCP 마우스 입력은 실제 속도보다 느리게 실행돼서 젓기 속도 판정 테스트에는 맞지 않는다.
- MCP `screen_capture`는 카메라 위치를 꼭 넘긴다 (안 넘기면 플레이 카메라를 Custom으로 되돌림). 제작 중에는 CameraRig가 매 프레임 카메라를 다시 고정한다.
- 결과는 출력창 `[Making] result ...`(클라)와 `[Production] ...`(서버)에 단계별 점수가 찍힌다.
