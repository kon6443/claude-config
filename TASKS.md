# Claude Config Migration Tasks

마이그레이션 작업: CLAUDE.md 단일 파일을 `rules/` + `templates/` 구조로 분할 + SessionStart hook + audit.log 일 1회 회전.

작업 디렉토리: `/Users/onamkwon/dotfiles/claude-config`
시작일: 2026-04-29
담당: skwon@mobigo.kr

---

## Phase 0 — 안전장치

- [ ] settings.json 백업 (`settings.json.bak.<ts>`)
- [ ] CLAUDE.md 백업 (`CLAUDE.md.bak.<ts>`)
- [ ] 작업 결과물 임시 디렉토리에서 검증 (`/tmp/claude-config-migration-*`)

## Phase 1 — rules/ 분리 (5개 파일)

원본 CLAUDE.md 섹션 → 신규 파일 매핑

- [ ] `rules/workflow.md` ← `## Workflow Orchestration` + `## Task Management`
- [ ] `rules/context.md` ← `## Context Management Strategies`
- [ ] `rules/engineering.md` ← `## Engineering Best Practices`
- [ ] `rules/error-recovery.md` ← `## Error Handling and Recovery Patterns`
- [ ] `rules/git-hygiene.md` ← `## Git and Change Hygiene`

> `## Communication Guidelines`는 매 응답 적용 → CLAUDE.md 인라인 유지 (분리 X).

## Phase 2 — templates/ 분리 (2개 파일)

- [ ] `templates/plan.md` ← Plan Template
- [ ] `templates/bugfix.md` ← Bugfix Template

## Phase 3 — 새 CLAUDE.md (~90줄)

- [ ] 언어 명시 (한국어 응답 기본)
- [ ] Operating Principles (그대로)
- [ ] Definition of Done (SSOT — 검증 관련 표현 1곳에 응축)
- [ ] Communication Guidelines (인라인 유지)
- [ ] **자동 라우팅 표** (트리거 단어 → `rules/templates` 파일)
- [ ] cross-project-researcher 부분에서 mobisell 특화 문구 제거 (글로벌은 일반론만)
- [ ] Local Setup Check 항목은 SessionStart hook으로 이관 → CLAUDE.md에서 제거

## Phase 4 — SessionStart hook + 로그 회전

- [ ] `sessionstart.sh` 작성
  - 직전 활동 요약 (cwd 매칭, 노이즈 필터, 시크릿 마스킹, 24h 윈도)
  - 위험 명령 강조 (`reset --hard`, `force push`, `--no-verify`, `rm -rf`, `chmod 777`, `drop table/database`)
  - 프로젝트 CLAUDE.md 미존재 시 1회 안내
  - audit.log 일 1회 회전 (gzip 압축, 30일 후 삭제)
  - 1MB 초과 시 즉시 trim (회전 사이 폭주 방어)
- [ ] settings.json에 SessionStart hook 등록
- [ ] stdout 방식 — 컨텍스트 토큰 비용 0
- [ ] timeout 5초 내 안전 종료 검증

## Phase 5 — README & 검증

- [ ] README.md 분할 구조 반영
- [ ] 자동 라우팅 동작 원리 문서화
- [ ] 모든 라우팅 참조 grep으로 검증 (`~/.claude/rules/`, `~/.claude/templates/` 절대 경로)
- [ ] 심링크 정상 여부 확인

## Phase 6 — 적용 & 마무리

- [ ] 사용자 복붙 명령으로 임시 디렉토리 → `~/dotfiles/claude-config` 이관
- [ ] `chmod +x sessionstart.sh`
- [ ] 새 세션 시작하여 SessionStart hook 동작 확인
- [ ] git commit (의미 단위 분리)
  - feat: rules/ + templates/ 분리, 자동 라우팅 도입
  - feat: SessionStart hook + audit.log 일 1회 회전
  - docs: README 갱신
- [ ] git push

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

## Results (작업 완료 후 채움)

- 변경된 파일:
- 검증 방법:
- 발견한 이슈:
- 후속 과제:
