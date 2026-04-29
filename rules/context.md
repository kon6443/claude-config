# Context Management Strategies

> 자동 라우팅: "컨텍스트 비대화 우려, 대량 검색·다중 파일 읽기 시작" 시 즉시 로드.

세션 컨텍스트가 한정 자원이라는 전제로 작업한다. 토큰 낭비는 정확도 저하로 직결된다.

---

## 1. Read Before Write

- 편집 전에 **권위 있는 source of truth**(기존 모듈/패턴/테스트)를 먼저 위치시킨다.
- 전체 레포 스캔보다 작고 국소적인 읽기를 선호.
- 같은 파일을 두 번 읽지 않는다. Edit이 성공했다면 변경은 이미 적용된 것.

## 2. Keep a Working Memory

- 짧은 "Working Notes"를 응답 본문 안에 유지:
  - 핵심 제약, 불변 조건, 결정, 발견한 함정.
- 컨텍스트가 커지면 **요약·압축**하고 raw noise는 버린다.
- 메모리 시스템(`memory/MEMORY.md`)은 세션 간 영속 정보용 — 일회성 작업 상태는 저장 금지.

## 3. Minimize Cognitive Load in Code

- 명시적 이름과 직선적 흐름 우선.
- 프로젝트가 이미 사용 중이지 않다면 영리한 메타 프로그래밍 금지.
- 발견 시점보다 더 읽기 좋은 코드를 남긴다.

## 4. Control Scope Creep

- 변경하다 더 깊은 문제를 발견하면:
  - 정확성/안전에 필요한 부분만 고친다.
  - 나머지는 TODO/이슈로 기록 후 현재 작업을 끝낸다.
- "이왕 손댄 김에"는 후행 PR로 분리.

## 5. Subagent로 컨텍스트 보호

- 넓은 탐색·다파일 분석은 서브에이전트에 위임 — 메인 컨텍스트에는 합성된 결과만 들어온다.
- `codebase-investigator`, `cross-project-researcher`, `git-history-researcher`, `log-analyzer` 등 활용.
- 각 호출에 단일 목표 + 산출물 명시.

## 6. Tool Result 핸들링

- Tool 결과 중 후속 단계에서 필요한 핵심 정보는 응답 텍스트에 옮겨 적어둔다.
- raw tool result는 컨텍스트 정리 시 잘릴 수 있다.
