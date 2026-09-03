# [완료] CLAUDE.md → rules/ + templates/ 분할 마이그레이션 (2026-04-29)

> ⚠️ **이후 변경됨**: 2026-09-03 에 `templates/` 는 `skills/plan`·`skills/bugfix` 로 이관되고
> CLAUDE.md 의 자동 라우팅 표는 제거됐다 (rules 는 Claude Code 가 자동 로드한다). 경위는 `../decisions.md` 참조.
> 아래 내용은 2026-04-29 시점의 기록이며 현재 구조와 다르다.

마이그레이션 작업: CLAUDE.md 단일 파일을 `rules/` + `templates/` 구조로 분할 + SessionStart hook + audit.log 일 1회 회전.

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
- [x] cross-project-researcher 부분에서 mobisell 특화 문구 제거 (글로벌은 일반론만)
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
  - feat: rules/ + templates/ 분리, 자동 라우팅 도입
  - feat: SessionStart hook + audit.log 일 1회 회전
  - docs: README 갱신
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
- mobisell 등 프로젝트 특화 정보가 글로벌 CLAUDE.md에 없음

## Results

- 변경된 파일: CLAUDE.md, rules/*.md(5), templates/*.md(2), sessionstart.sh, settings.json, README.md
- 검증 방법: 라우팅 grep 대조, 심링크 확인, 새 세션에서 SessionStart 훅 동작 확인 (커밋 80002ad, 2628563)
- 발견한 이슈: 이후 2026-09 감사에서 (1) rules/ 가 Claude Code 에 의해 자동 로드되어 라우팅 Read 가 이중 로드였음 (2) SessionStart 평문 stdout 이 모델 컨텍스트에 주입됨 — 둘 다 2026-09-03 수정
- 후속 과제: 없음 (아카이브)
