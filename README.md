# Claude Code Global Config

Claude Code 글로벌 설정 모음. `~/.claude/`에 심링크로 연결하여 여러 컴퓨터에서 동일 환경 유지.

## 지원 환경

- **macOS / Linux / Windows(WSL)** — POSIX `sh` + 심링크 기반. 모든 경로는 `$HOME`/`~` 상대로만 작성하며, 특정 기기·사용자·OS 경로 하드코딩 금지 (`verify.sh` 10번 항목이 검사).
- **Windows 네이티브(PowerShell/cmd)는 미지원** — 훅이 `sh`로 실행되고 심링크에 의존하므로, Windows에서는 WSL 안에서 사용한다.
- 의존 도구: `jq`(모든 훅이 사용 — 없으면 fail-open으로 조용히 통과), `gzip`, `git`. macOS 기본 탑재, Linux/WSL은 필요 시 설치.
- OS 분기가 필요한 명령은 반드시 fallback 동반: `date -v … || date -d …`(BSD/GNU), `osascript || notify-send`(각각 `command -v` 가드).

## 구조

```
claude-config/
├── CLAUDE.md                 # 핵심 원칙 + DoD(SSOT) + Communication + 자동 라우팅 표 (~100줄)
├── settings.json             # permissions, hooks, statusline, 플러그인, env, 기본 모델
├── setup.sh                  # ~/.claude 심링크 셋업 (멱등 — 새 머신에서 1회 실행)
├── verify.sh                 # 전수조사 — 심링크·문법·라우팅·훅 참조·OS 이식성 검증
├── statusline-command.sh     # 하단 상태바
├── audit-log.sh              # PreToolUse hook — Bash 명령 audit
├── check-secrets.sh          # UserPromptSubmit hook — 시크릿 패턴 차단
├── db-guard.sh               # PreToolUse hook — node/python 경유 DB 접속·변경 게이트
├── sessionstart.sh           # SessionStart hook — 심링크 자동 복구 + 활동 요약 + 위험 명령 + 로그 회전
├── TASKS.md                  # 마이그레이션·진행 중 작업 트래킹 (git에 커밋)
├── .gitignore                # 백업·로컬·임시 파일 추적 방지
├── README.md
├── rules/                    # 상황별 규칙 (CLAUDE.md 자동 라우팅으로 로드)
│   ├── workflow.md           #   계획·플랜·다중 단계 작업
│   ├── context.md            #   컨텍스트 관리
│   ├── engineering.md        #   코드 작성·수정 베스트프랙티스
│   ├── error-recovery.md     #   버그·에러·디버그·회귀
│   └── git-hygiene.md        #   커밋·PR·머지·리베이스
├── templates/                # 산출물 골격 (자동 라우팅 또는 직접 호출)
│   ├── plan.md               #   작업 계획서
│   └── bugfix.md             #   버그 리포트
├── commands/                 # 슬래시 커맨드
│   ├── pr-desc.md            #   /pr-desc — PR 제목·설명 자동 생성
│   ├── review.md             #   /review — QA 리뷰
│   └── tasks-dashboard.md    #   /tasks-dashboard — 태스크 진행 대시보드
└── agents/                   # 서브에이전트
    ├── codebase-investigator.md
    ├── cross-project-researcher.md
    ├── git-history-researcher.md
    └── log-analyzer.md
```

## 자동 라우팅 — CLAUDE.md ↔ rules/templates 연결

CLAUDE.md만 매 세션 자동 로드된다. `rules/*.md`와 `templates/*.md`는 **명시적으로 Read**해야 적용된다.

CLAUDE.md 안의 **Auto-Loaded Rules 표**가 트리거 단어/작업 성격을 파일에 매핑하며, AI는 작업 시작 전에 그 파일을 즉시 Read한다.

| 트리거 (사용자 요청 키워드 / 작업 성격) | 즉시 로드 |
|---|---|
| 코드 작성·수정·구현·리팩터링, API/타입/테스트 변경 | `rules/engineering.md` |
| 버그·에러·디버그·회귀·"안 됨"·"이상해" | `rules/error-recovery.md` (+ 리포트 작성 시 `templates/bugfix.md`) |
| 커밋·PR·머지·리베이스·태그·브랜치 정리 | `rules/git-hygiene.md` |
| 계획·플랜·설계·마이그레이션·아키텍처 결정·다중 단계 | `rules/workflow.md` + `templates/plan.md` |
| 컨텍스트 비대화·대량 검색·다중 파일 읽기 | `rules/context.md` |

장점: 매 세션 자동 로드 토큰 ~60% 절감 + 상황별 정밀 적용.
주의: 라우팅 표 갱신을 빼먹으면 신규 규칙이 적용되지 않는다 → 신규 `rules/<name>.md` 추가 시 반드시 CLAUDE.md 라우팅 표에도 행을 추가한다.

## hooks

| 이벤트 | 동작 |
|---|---|
| `SessionStart` | `sessionstart.sh` — **~/.claude 심링크 자동 복구(누락분만)** + 직전 활동 요약(cwd 매칭/노이즈 필터/시크릿 마스킹/24h 윈도) + 위험 명령 강조 + audit.log 일 1회 gzip 회전 + 1MB 초과 시 즉시 trim + **30일 초과 `*.bak.*` 정리** + 프로젝트 CLAUDE.md 미존재 시 1회 안내. **stdout 출력만 — 컨텍스트 토큰 0** |
| `UserPromptSubmit` | `check-secrets.sh` — 시크릿 패턴 발견 시 모델 전송 전 차단 |
| `PreToolUse(Bash)` | `audit-log.sh` — 모든 Bash 명령을 `~/.claude/audit.log`에 누적 |
| `PreToolUse(Bash)` | `db-guard.sh` — node/python 실행 명령의 DB 시그니처 게이트: 쓰기 SQL(INSERT/UPDATE/DELETE/DDL) 감지 시 **deny(exit 2)**, DB 접속(읽기 포함)·검증 불가(REPL/파이프)는 **ask**, 무관하면 통과 |
| `Notification` | macOS osascript 또는 Linux notify-send 알림 |

> ⚠️ **훅 스크립트가 `~/.claude`에 없으면 해당 이벤트가 통째로 차단될 수 있다** (`sh`가 파일을 못 열면 exit 2 = 하드 차단으로 해석됨). 신규 훅 추가 시 심링크 연결까지가 한 작업 단위 — `setup.sh`가 `*.sh` 글롭으로 자동 포함하고, `sessionstart.sh`가 매 세션 누락 링크를 자동 복구한다.

### audit.log 회전 정책

| 항목 | 값 |
|---|---|
| 회전 주기 | 일 1회 (자정 넘어 첫 SessionStart) |
| 회전 방식 | gzip 압축 → `~/.claude/backups/audit.log.YYYY-MM-DD.gz` |
| 보관 기간 | 30일 (이후 자동 삭제) |
| 안전망 | 1MB 초과 시 즉시 `tail -10000`로 trim |
| 셋업 백업 정리 | `~/.claude/*.bak.*` 30일 초과분 자동 삭제 (setup.sh 교체 잔재) |
| 시크릿 마스킹 | stdout 출력 시 토큰·키 패턴 `[REDACTED]` |
| 외부 의존성 | 없음 (launchd/cron/logrotate 불필요) |

## permissions

| 구분 | 동작 | 예시 |
|---|---|---|
| `allow` | 자동 실행 | git 읽기 명령, 패키지 매니저, 일반 유틸 (`grep`, `find`, `jq`, `gh`) |
| `ask` | 매번 확인 | `git push/commit/merge/rebase/stash/tag`, `docker`, `rm` |
| `deny` | 무조건 차단 | `rm -rf /` 변형, `git push --force/-f`, `git reset --hard`, ssh/env/credentials/pem/key 읽기, `Edit/Write(~/.claude/**)`, `Edit/Write(~/dotfiles/**)`, `npm publish` 등 |

`Edit/Write(~/.claude/**)`, `Edit/Write(~/dotfiles/**)` 차단은 **자기 자신의 글로벌 설정을 보호**한다. 갱신 작업이 필요할 때는 임시 디렉토리에 작성 후 사용자가 직접 `cp`로 이동.

## 기본 모델·동작 설정 (settings.json)

| 키 | 값 | 설명 |
|---|---|---|
| `model` | `opus[1m]` | 기본 모델 (1M 컨텍스트) — `/model`로 바꾸면 심링크를 통해 repo 파일이 직접 수정되므로 커밋/되돌리기 결정 필요 |
| `effortLevel` | `xhigh` | 추론 노력 수준 |
| `language` | `Korean` | 응답 언어 |

## .gitignore 정책

```
*.bak           # 백업 파일
*.bak.*         # 타임스탬프 백업
*.tmp           # 임시 파일
.DS_Store
*.local         # 로컬 전용
CLAUDE.local.md      # 머신별/계정별 오버라이드 (추후 도입)
settings.local.json  # Claude Code의 로컬 설정 (자동 생성됨)
```

`audit.log`는 `~/.claude/`에 위치하므로 dotfiles repo와 무관 — 동기화되지 않는다.

## 셋업 (새 머신에서 1회)

```bash
[ -d ~/dotfiles/claude-config ] || git clone <repo> ~/dotfiles/claude-config
sh ~/dotfiles/claude-config/setup.sh
```

`setup.sh`는 멱등(재실행 안전)이며:

- 링크 대상을 **`*.sh` 글롭 + 고정 항목으로 동적 구성** — 새 훅 스크립트를 repo에 추가해도 셋업 스크립트 갱신 불필요
- 기존 실파일/타 경로 링크는 `.bak.<ts>`로 백업 후 교체
- 마지막에 **settings.json이 참조하는 훅 경로 무결성 검증** (누락 시 exit 1)

이후 유지보수는 자동: `git pull`로 새 훅 스크립트가 들어와도 `sessionstart.sh`가 **다음 세션 시작 시 누락 심링크를 자동 복구**한다. `setup.sh` 재실행은 기존 항목을 교체해야 할 때(실파일 → 링크 전환 등)만 필요.

## TASKS.md 사용법

`TASKS.md`는 dotfiles repo에 커밋되어 **글로벌 설정 변경 작업의 진행 상태**를 기록한다.

- 마이그레이션·셋업 작업: 본 파일에 Phase 추가 → 완료 시 ✅ 마킹
- 1회성 일감: GitHub Issue 또는 프로젝트별 task 파일 사용
- 다중 머신 동기화: `git pull` 시 다른 머신에서 한 작업 가시화

> 일회성 작업 진행 상태(현재 세션 내)는 Claude Code 내장 task 시스템 사용. TASKS.md는 **세션 간 영속이 필요한 글로벌 설정 변경**에만.

## 환경 변수

| 키 | 값 | 설명 |
|---|---|---|
| `CLAUDE_CODE_NO_FLICKER` | `1` | 화면 깜빡임 방지 |
| `BASH_DEFAULT_TIMEOUT_MS` | `120000` | Bash 기본 timeout (2분) |
| `BASH_MAX_TIMEOUT_MS` | `600000` | Bash 최대 timeout (10분) |
| `MAX_MCP_OUTPUT_TOKENS` | `25000` | MCP 출력 토큰 상한 |

## 운영 팁

### audit.log 직접 조회
```bash
tail -50 ~/.claude/audit.log                # 최근 50개
grep "git push" ~/.claude/audit.log         # 키워드 검색
ls -lh ~/.claude/backups/audit.log.*.gz     # 회전 백업 목록
zcat ~/.claude/backups/audit.log.2026-04-28.gz | grep ...  # 과거 로그 검색
```

### settings.json 변경 (deny에 막혀 있으므로)
1. 임시 디렉토리에 새 settings.json 작성
2. `cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%Y%m%d-%H%M%S)`
3. `cp /tmp/.../settings.json ~/dotfiles/claude-config/settings.json`
4. 새 세션 시작 → 동작 검증

### 전수조사 (변경 후 무결성 검증)

설정 파일을 변경할 때마다 실행. 하나라도 실패하면 exit 코드 ≥ 1.

```bash
sh ~/dotfiles/claude-config/verify.sh
```

검사 항목 (10종):

| # | 항목 | # | 항목 |
|---|---|---|---|
| 1 | 필수 파일 존재 + 크기 | 6 | DoD SSOT — 정의가 CLAUDE.md 1곳뿐인지 |
| 2 | `~/.claude` 심링크 (동적 목록) | 7 | 프로젝트 특화 잔재 |
| 3 | JSON / shell 문법 | 8 | `*.sh` 실행 권한 |
| 4 | settings.json 훅 참조 → 실재 여부 | 9 | .gitignore 동작 (백업 추적 방지) |
| 5 | CLAUDE.md 라우팅 표 ↔ `rules/`·`templates/` 동기화 | 10 | **OS 이식성** — 하드코딩 경로·bashism·fallback 없는 OS 전용 명령 |
