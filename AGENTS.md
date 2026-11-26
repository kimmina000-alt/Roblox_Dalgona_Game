# AGENTS.md — 이 저장소에서 일하는 AI에게

달고나 골목 (Dalgona Alley), Roblox 게임. 사용자는 한국어로 쓴다 — 답도 한국어로.

먼저 읽을 것 (순서대로):
1. `docs/AI_COLLAB_GUIDE.md` — 여러 AI가 같이 일하는 규칙: 브랜치·묶음 흐름, Studio 동기화(Rojo 없음, MCP + 체크섬), 시험 방법, 지금 상태
2. `CLAUDE.md` — 코드 구조, Studio 전용 에셋, 고정된 것(바꾸지 말 것)
3. `docs/GAME_DESIGN_DOCUMENT.md` — 기획 기준 (결정 D1~D58). 다른 문서와 다르면 이것이 우선
4. `docs/WORK_PRIORITIES.md` — 진행 현황과 다음 할 일

가장 중요한 규칙:
- 자기 브랜치에만 커밋·푸시. main 머지는 묶음 끝에 사용자 승인 뒤 한 번.
- Rojo 쓰지 않음. Studio에는 묶음 시험 때 한 세션만 MCP로 넣고 체크섬으로 확인.
- 코인·재고·품질은 서버가 정함 (클라이언트 점수를 믿지 않음).
- `레퍼런스/`는 커밋하지 않음. 실제 상표·캐릭터·오징어 게임 IP 쓰지 않음.
