# Claude Config Migration Tasks

마이그레이션 작업: CLAUDE.md 단일 파일을 `rules/` + `templates/` 구조로 분할 + SessionStart hook + audit.log 일 1회 회전.

> ✅ **완료** (커밋 `80002ad`, `2628563`, `565a452`). 아래 Phase 0~6 체크리스트는 이력 보존용 — Results 참조.

작업 디렉토리: `~/dotfiles/claude-config`
시작일: 2026-04-29

---

## Phase 0 — 안전장치

- [x] settings.json 백업 (`settings.json.bak.<ts>`)
- [x] CLAUDE.md 백업 (`CLAUDE.md.bak.<ts>`)
- [x] 작업 결과물 임시 디렉토리에서 검증 (`/tmp/claude-config-migration-*`)

## Phase 1 — rules/ 분리 (5개 파일)

원본 CLAUDE.md 섹션 → 신규 파일 매핑

- [x] `rules/workflow.md` ← `## Workflow Orchestration` + `## Task Management`
- [x] `rules/context.md` ← `## Context Management Strategies`
- [x] `rules/engineering.md` ← `## Engineering Best Practices`
- [x] `rules/error-recovery.md` ← `## Error Handling and Recovery Patterns`
- [x] `rules/git-hygiene.md` ← `## Git and Change Hygiene`

> `## Communication Guidelines`는 매 응답 적용 → CLAUDE.md 인라인 유지 (분리 X).

## Phase 2 — templates/ 분리 (2개 파일)

- [x] `templates/plan.md` ← Plan Template
- [x] `templates/bugfix.md` ← Bugfix Template

## Phase 3 — 새 CLAUDE.md (~90줄)

- [x] 언어 명시 (한국어 응답 기본)
- [x] Operating Principles (그대로)
- [x] Definition of Done (SSOT — 검증 관련 표현 1곳에 응축)
- [x] Communication Guidelines (인라인 유지)
- [x] **자동 라우팅 표** (트리거 단어 → `rules/templates` 파일)
- [x] cross-project-researcher 부분에서 특정 프로젝트 특화 문구 제거 (글로벌은 일반론만)
- [x] Local Setup Check 항목은 SessionStart hook으로 이관 → CLAUDE.md에서 제거

## Phase 4 — SessionStart hook + 로그 회전

- [x] `sessionstart.sh` 작성
  - 직전 활동 요약 (cwd 매칭, 노이즈 필터, 시크릿 마스킹, 24h 윈도)
  - 위험 명령 강조 (`reset --hard`, `force push`, `--no-verify`, `rm -rf`, `chmod 777`, `drop table/database`)
  - 프로젝트 CLAUDE.md 미존재 시 1회 안내
  - audit.log 일 1회 회전 (gzip 압축, 30일 후 삭제)
  - 1MB 초과 시 즉시 trim (회전 사이 폭주 방어)
- [x] settings.json에 SessionStart hook 등록
- [x] stdout 방식 — 컨텍스트 토큰 비용 0
- [x] timeout 5초 내 안전 종료 검증

## Phase 5 — README & 검증

- [x] README.md 분할 구조 반영
- [x] 자동 라우팅 동작 원리 문서화
- [x] 모든 라우팅 참조 grep으로 검증 (`~/.claude/rules/`, `~/.claude/templates/` 절대 경로)
- [x] 심링크 정상 여부 확인

## Phase 6 — 적용 & 마무리

- [x] 사용자 복붙 명령으로 임시 디렉토리 → `~/dotfiles/claude-config` 이관
- [x] `chmod +x sessionstart.sh`
- [x] 새 세션 시작하여 SessionStart hook 동작 확인
- [x] git commit (의미 단위 분리)
- [x] git push

---

## Acceptance Criteria

- 새 CLAUDE.md가 100줄 이내
- 모든 분할 섹션이 `rules/` 또는 `templates/`에 존재
- 자동 라우팅 표가 모든 분할 파일을 빠짐없이 가리킴
- SessionStart hook이 5초 내 종료, 토큰 비용 0
- audit.log가 1MB 초과 시 자동 trim, 자정 지나면 자동 회전
- 30일 초과 압축 로그 자동 삭제
- 시크릿 패턴이 stdout에 노출되지 않음
- 특정 프로젝트 특화 정보가 글로벌 CLAUDE.md에 없음

## Results

- 변경된 파일: `CLAUDE.md`(재작성), `rules/` 5개, `templates/` 2개, `sessionstart.sh`, `settings.json`, `README.md`, `.gitignore`
- 검증 방법: README 전수조사 스크립트(문법·심링크·SSOT·특화 잔재) + 새 세션 hook 동작 확인
- 발견한 이슈: 없음 (당시)
- 후속 과제: → 아래 2026-07-25 셋업 자동화로 이어짐

---

# 2026-07-25 — 셋업 자동화 (setup.sh + 심링크 자동 복구)

**배경(포스트모템)**: `db-guard.sh` 추가 커밋(`376b790`)이 settings.json에 훅을 등록했지만 README 셋업 스크립트의 하드코딩 파일 목록에는 누락 → 새 머신(WSL)에서 `~/.claude/db-guard.sh` 심링크 부재 → `sh`가 exit 2 반환 → **모든 Bash 실행 하드 차단**.

- 원인: 훅 등록(settings.json)과 심링크 목록(README)이 이중 관리 — 단일 커밋에서 동기화 강제 장치 없음.
- 탐지 신호: `PreToolUse:Bash hook error: sh: 0: cannot open ...db-guard.sh`.
- 예방 규칙: 링크 대상을 하드코딩하지 않고 `*.sh` 글롭으로 동적 구성 + settings.json 훅 참조 무결성 검증 + 세션 시작 시 자동 복구.

## 작업 항목

- [x] `setup.sh` 신규 — 복붙 대신 실행형 셋업, `*.sh` 글롭 동적 목록, 멱등, 훅 참조 무결성 검증
- [x] `sessionstart.sh` — (0)단계로 누락 심링크 자동 복구 추가 (기존 항목은 불변, 생성만)
- [x] `README.md` — db-guard.sh 반영(구조·hooks 표), 셋업 섹션을 setup.sh 호출로 교체, 전수조사 스크립트 `*.sh` 글롭화 + 훅 참조 검사 추가, 기본 모델 설정 문서화
- [x] `TASKS.md` — 마이그레이션 완료 마킹 + 본 포스트모템 기록
- [x] `verify.sh` 신규 — README 인라인 전수조사를 실행형 파일로 이관 (POSIX sh 재작성 — 기존 `diff <(…)` bash 전용 문법 제거) + 라우팅 표 동기화·훅 참조·**OS 이식성**(하드코딩 경로/bashism/fallback 없는 OS 전용 명령) 검사 추가
- [x] `sessionstart.sh` — 30일 초과 `~/.claude/*.bak.*` 자동 정리 추가
- [x] `statusline-command.sh` — API가 소수 percentage/epoch를 줄 경우 POSIX 산술 오류 방지 (jq `floor` 정수화)
- [x] `sessionstart.sh` — 첫 회전 백업 스탬프의 mtime 조회를 GNU/BSD 겸용으로 (macOS에서 `init` 대신 실제 날짜)
- [x] OS 이식성 전수조사 — 유일한 하드코딩 경로였던 본 파일의 macOS 홈 절대경로(작업 디렉토리 표기)를 `~` 기반으로 수정. BSD/GNU date 분기와 알림 명령은 모두 fallback·가드 확인됨. 지원 환경(macOS/Linux/WSL, Windows 네이티브 미지원)을 README에 명시
