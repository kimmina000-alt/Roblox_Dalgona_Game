# 기술 구조 및 Roblox 구현 설계

상태: 구현 전 설계 초안. 실제 Studio 프로젝트 구조와 충돌 여부 확인 후 적용한다.

## 1. 권장 Explorer 구조
```
ReplicatedStorage
├─ Remotes
│  ├─ StartProduction
│  ├─ SubmitProduction
│  ├─ ProductionResult
│  ├─ BuyMaterial
│  ├─ BuyUpgrade
│  ├─ HireEmployee
│  ├─ InventoryUpdated
│  └─ DataUpdated
├─ Shared
│  ├─ GameConfig
│  ├─ DalgonaConfig
│  ├─ RecipeConfig
│  ├─ UpgradeConfig
│  ├─ EmployeeConfig
│  └─ EconomyConfig
└─ Assets
   ├─ DalgonaModels
   ├─ StampModels
   ├─ Effects
   └─ Animations

ServerScriptService
├─ ServerMain.server.lua
└─ Services
   ├─ PlayerDataService.lua
   ├─ PlotService.lua
   ├─ ProductionService.lua
   ├─ EconomyService.lua
   ├─ InventoryService.lua
   ├─ CustomerService.lua
   ├─ EmployeeService.lua
   └─ UpgradeService.lua

StarterPlayer
└─ StarterPlayerScripts
   ├─ CameraController.client.lua
   ├─ InteractionController.client.lua
   ├─ ProductionController.client.lua
   └─ UIController.client.lua

StarterGui
├─ MainHUD
├─ ProductionUI
├─ ShopUI
├─ InventoryUI
├─ UpgradeUI
└─ EmployeeUI

Workspace
├─ PlayerPlots
├─ MainStreet
├─ NPCs
└─ SpawnLocation
```

## 2. 서버/클라이언트 책임
### 클라이언트
- 캐릭터 입력, 카메라, UI, 미니게임 시각 표현, 애니메이션 요청.
- 미니게임 입력 이벤트와 타임스탬프/단계 식별자를 서버에 전달.
- 클라이언트 점수나 코인/재고 값을 최종 권한으로 취급하지 않는다.

### 서버
- 플레이어 데이터, Plot 소유권, 재료/재고/코인.
- 제작 세션 생성과 유효성 검증.
- 입력 시간/순서/세션 ID 검증 및 최종 품질 판정.
- NPC 구매 및 보상 지급.
- 직원 생산/급여/재고 제한.
- 업그레이드와 도안 해금 검증.

## 3. 제작 요청 흐름
1. 클라이언트가 StartProduction 요청.
2. 서버는 Plot/작업대 접근, 재료, 현재 제작 여부 확인.
3. 서버는 고유 제작 세션 ID와 시작 시각, 허용 단계 정보를 생성.
4. 클라이언트는 단계별 조작을 수행하고 입력 결과 제출.
5. 서버는 세션 ID, 단계 순서, 최소/최대 시간, 입력 횟수와 허용 범위를 검증.
6. 서버가 점수를 계산하고 품질을 판정.
7. 서버가 재고에 상품을 등록하고 결과를 클라이언트에 통지.

클라이언트가 계산한 Q 점수를 그대로 받지 않는다. 단순히 입력 이벤트만 받아도 완벽한 치트 방지가 되는 것은 아니므로 서버 검증과 비정상 입력 제한을 함께 설계한다.

## 4. NPC 판매 흐름
- 서버가 가게별 손님 스케줄을 관리.
- NPC는 서버가 소유한 상태로 생성/이동.
- 판매 직전 재고 항목을 원자적으로 예약/제거.
- 판매 금액을 서버가 계산하고 한 번만 지급.
- 재고 없음/Plot 해제/중복 요청 상황을 처리.
- 고객 NPC 수가 많아지면 경로 탐색 빈도와 동시 수를 제한한다.

## 5. 데이터 저장 제안
```lua
PlayerData = {
    Coins = 100,
    Level = 1,
    Exp = 0,
    ShopLevel = 1,
    Materials = {
        Sugar = 20,
        BakingSoda = 20,
        BasicWrap = 20,
    },
    Inventory = {},
    UnlockedShapes = {
        Circle = true,
        Square = true,
        Triangle = true,
    },
    Upgrades = {
        Stove = 1,
        Press = 1,
        Workbench = 1,
    },
    Employees = {},
    Statistics = {
        TotalMade = 0,
        PerfectMade = 0,
        TotalSold = 0,
        TotalEarned = 0,
    }
}
```

저장 대상은 지속 데이터다. 진행 중 미니게임, NPC의 월드 좌표, 현재 손님 상태 등 휘발성 상태는 저장하지 않는다. 스키마 버전과 데이터 마이그레이션, 자동 저장, 퇴장 저장, 서버 종료 저장을 구현한다.

## 6. 서버 성능
- 플레이어별 무한 while 루프보다 중앙 스케줄러/누적 시간 기반 업데이트를 사용.
- 직원 생산은 실제 생산 완료 시각을 누적 관리.
- NPC 생성 수와 경로 탐색을 제한.
- 판매/생산/급여는 이벤트 또는 정해진 주기의 서버 작업으로 처리.
- 재고/코인 변경은 한 서버 서비스에서 검증해 동시성 문제를 줄인다.

## 7. 보안
- 클라이언트가 가격, 품질, 코인 보상, 직원 급여, 해금 상태를 결정하지 않는다.
- RemoteEvent 인자 타입/범위/호출 빈도 검증.
- Plot 소유권과 작업대 거리 확인.
- 세션 ID로 제작 요청 재전송/중복 지급 방지.
- 상품 판매 시 재고 항목의 고유 ID를 사용해 중복 판매 방지.
- 저장 실패 시 재시도/로그 및 데이터 손상 방지 전략 마련.
