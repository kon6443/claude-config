# Claude Code Global Config

Claude Code 글로벌 설정 모음. `~/.claude/`에 심링크로 연결하여 여러 컴퓨터에서 동일 환경 유지.

## 지원 환경

| 환경 | 지원 | 비고 |
|---|---|---|
| macOS | ✅ | 기본 개발 환경. `jq`는 별도 설치 (`brew install jq`) |
| Linux (Ubuntu 등) | ✅ | `/bin/sh`가 dash여도 동작하도록 POSIX sh로만 작성 |
| WSL2 | ✅ | WSL 안의 Linux 파일시스템에서 사용. `/mnt/c` 경로에 두지 않는다 |
| Windows 네이티브 (PowerShell/cmd) | ❌ | 훅이 `sh`로 실행되고 심링크에 의존한다. WSL 안에서 사용한다 |

**이식성 규칙의 정본은 `rules/shell-portability.md`** 다 (경로 한정 규칙 — 셸 파일 작업 시 자동 로드).
여기서 다시 적지 않는다. `scripts/check.sh` 9절이 그 규칙의 위반을 자동으로 잡는다.

의존 도구: **`jq` 필수** (없으면 훅 가드 3종이 무음 비활성화되고 SessionStart가 경고한다), `git`·`gzip`은 기본 탑재. `shellcheck`는 선택이며 있으면 검사에 포함된다.

## 셋업 / 검증

```bash
[ -d ~/dotfiles/claude-config ] || git clone https://github.com/kon6443/claude-config.git ~/dotfiles/claude-config
sh ~/dotfiles/claude-config/scripts/setup.sh   # 멱등 — 심링크·clean 필터·chmod·의존성·훅 참조 무결성
sh ~/dotfiles/claude-config/scripts/check.sh   # 10개 섹션 무결성 + 이식성 + 훅 회귀 테스트 (CI와 동일)
```

## 구조

```
claude-config/
├── CLAUDE.md                 # 핵심 원칙 + DoD(SSOT) + Communication + 가드레일 (약 100줄)
├── settings.json             # permissions, hooks, sandbox, statusline, 플러그인, env, model
├── statusline-command.sh     # 하단 상태바
├── sessionstart.sh           # SessionStart(startup|resume) — 심링크 자동복구 + 활동 요약(systemMessage) + 로그 회전
├── audit-log.sh              # PreToolUse(Bash) — 명령 감사 로그 (기록 시점 마스킹, 600)
├── db-guard.sh               # PreToolUse(Bash) — 스크립트 런타임 경유 DB 접속·변경 게이트
├── check-secrets.sh          # UserPromptSubmit — 시크릿 패턴 차단
├── rules/                    # 상황별 규칙 — 자동 로드. shell-portability.md 만 paths: 조건부
├── skills/                   # 슬래시 커맨드 5종 (/plan /bugfix /review /pr-desc /tasks-dashboard)
├── agents/                   # 읽기 전용 서브에이전트 4종
├── scripts/
│   ├── setup.sh              #   새 머신 셋업 / 재동기화 (멱등, 훅 참조 무결성 검증)
│   ├── check.sh              #   무결성 10절 + OS 이식성 + 훅 회귀 테스트
│   └── strip-orca.sh         #   git clean 필터 — 커밋에서 Orca 훅 제거
├── tests/hooks/run.sh        # 훅 픽스처 테스트 (오탐·우회·마스킹·이식성·심링크 복구 회귀)
├── docs/history/             # 완료된 마이그레이션 기록
├── .github/workflows/ci.yml  # PR/main 마다 scripts/check.sh
├── .gitattributes            # settings.json 에 clean 필터 지정 (Orca 훅 커밋 제외)
└── .gitignore                # 백업·로컬·임시 파일 추적 방지
```

## 규칙 로딩 모델

| 종류 | 로딩 | 근거 |
|---|---|---|
| `CLAUDE.md` | 매 세션 자동 | Claude Code 기본 동작 |
| `rules/*.md` (조건 없음) | 매 세션 자동 | Claude Code는 `~/.claude/rules/*.md`를 user-level rules로 로드한다 (공식 memory 문서) |
| `rules/*.md` (`paths:` 있음) | 해당 패턴 파일을 읽을 때만 | 조건부 로드. 상시 컨텍스트를 차지하지 않는다 |
| `skills/*/SKILL.md` | 이름·설명만 상시, 본문은 호출 시 | `/name` 으로 직접 호출하거나 설명이 맞으면 모델이 불러온다 |

### 어떤 규칙에 `paths:`를 붙이나

| 규칙 | 조건 | 왜 |
|---|---|---|
| `engineering.md` `error-recovery.md` `git-hygiene.md` `workflow.md` `context.md` | 없음 (상시) | **작업 방식**에 대한 규칙이다. 언어·파일 종류와 무관하므로 조건을 걸면 필요할 때 로드되지 않는다 |
| `shell-portability.md` | `**/*.sh` `**/*.bash` `**/*.zsh` | **파일 종류**에 대한 규칙이다. 셸을 안 건드리는 작업에서는 실릴 이유가 없다 |

판단 기준은 하나다. **"이 규칙이 특정 파일 종류에만 참인가?"** 그렇다면 `paths:`를 붙이고, 아니면 붙이지 않는다.
프로세스 규칙에 확장자 목록을 붙이면 목록에 없는 언어에서 규칙이 사라지므로 오히려 위험하다.
새 `rules/<name>.md`를 추가할 때 CLAUDE.md 를 고칠 필요는 없다 — 각 파일 헤더가 적용 상황을 밝히고, 파일은 자동으로 로드된다.
`scripts/check.sh` 5절이 "파일을 Read 하라"는 지시가 CLAUDE.md 에 되살아나는 것과 `templates/` 부활을 막는다.

**프로젝트가 우선한다.** 사용자 규칙이 먼저 로드되고 프로젝트 규칙이 나중에 오므로, 충돌 시 더 구체적인 프로젝트 쪽이 이긴다.

## hooks

| 이벤트 | 스크립트 | 동작 |
|---|---|---|
| `SessionStart` (`startup\|resume`) | `sessionstart.sh` | `~/.claude` 심링크 자동 복구 + 직전 활동 요약 + 24h 위험 명령 + audit.log 일 1회 gzip 회전 + 1MB 초과 trim + CLAUDE.md 부재 안내 + jq 미설치 경고. **출력은 `systemMessage` JSON** → 사용자 화면에만 표시, 컨텍스트 토큰 0 |
| `UserPromptSubmit` | `check-secrets.sh` | 시크릿 패턴(Anthropic/OpenAI/GitHub/GitLab/AWS/Google/Stripe/Slack/npm/HF/JWT/개인키) 발견 시 모델 전송 전 차단 |
| `PreToolUse(Bash)` | `audit-log.sh` | 모든 Bash 명령을 `~/.claude/audit.log`에 1줄 기록. 개행은 공백으로, 시크릿은 기록 시점에 `[REDACTED]`, 파일 모드 600 |
| `PreToolUse(Bash)` | `db-guard.sh` | 아래 판정표 |
| `Notification` | 인라인 | macOS osascript 또는 Linux notify-send |

> ⚠️ **SessionStart의 평문 stdout은 모델 컨텍스트에 주입된다** (공식 hooks 문서: "adds plain-text stdout as context that Claude can see"). 사용자용 메시지는 반드시 `{"systemMessage": ...}`로 보낸다. matcher를 `*`로 두면 `compact`/`fork`마다 재실행되므로 `startup|resume`으로 제한한다.

### db-guard 판정표

대상: `node|python[3.x]|bun|deno|tsx|ts-node|npx|uv run|poetry run|pipenv run|pnpm/yarn exec|dlx|npm exec`로 시작하는 세그먼트. 명령 문자열 + 참조된 `.js/.ts/.py` 파일 내용을 스캔한다.

| 쓰기 SQL 시그니처 | DB 접속 시그니처 | 판정 |
|---|---|---|
| 있음 | 있음 | **deny** (exit 2) |
| 있음 | 없음 | ask — 주석/문자열 오탐 가능성 |
| 없음 | 있음 | ask — SELECT 등 읽기 포함 |
| 실행 대상 코드 확인 불가 (REPL/파이프/확장자 없음) | | ask |
| 둘 다 없음 | | 통과 |

긴급 우회: `CLAUDE_DB_GUARD=off` (audit.log에 명령이 남는다). 오탐 사례는 `tests/hooks/run.sh`에 픽스처로 추가한다.

### audit.log 회전 정책

| 항목 | 값 |
|---|---|
| 회전 주기 | 일 1회 (자정 넘어 첫 SessionStart) |
| 회전 방식 | gzip → `~/.claude/backups/audit.log.YYYY-MM-DD.gz` (모드 600) |
| 보관 기간 | 30일 (이후 자동 삭제) |
| 안전망 | 1MB 초과 시 즉시 `tail -10000`로 trim |
| 시크릿 마스킹 | 기록 시점(audit-log.sh) + 출력 시점(sessionstart.sh) 이중. 두 파일의 `mask=` 표현식은 동일해야 하며 `tests/hooks/run.sh` 가 일치를 검사한다 |
| 마스킹 범위 | `-u user:pass` · `Bearer/Basic/Token <값>` · 접두접미 포함 `KEY=VALUE`/`KEY: VALUE`(AWS_SECRET_ACCESS_KEY, X-Api-Key 등) · 고정 프리픽스 토큰. **정규식 기반이라 완전하지 않다** — 새 누출 형태를 발견하면 회귀 픽스처부터 추가한다 |

### 심링크 운영 — setup.sh와 자동 복구의 역할 분담

| | `scripts/setup.sh` | SessionStart 자동 복구 |
|---|---|---|
| 실행 시점 | 사람이 명시적으로 | 매 세션 시작 |
| 없는 링크 생성 | ✅ | ✅ |
| 실파일·다른 곳을 가리키는 링크 교체 | ✅ (`.bak.<ts>`로 백업) | ❌ 건드리지 않음 |
| clean 필터 등록·의존성 확인 | ✅ | ❌ |

링크 대상은 하드코딩하지 않고 저장소 루트의 `*.sh` 글롭으로 잡는다. 새 훅을 추가해도 목록을 고칠 필요가 없다.
자동 복구는 기준 링크(`~/.claude/CLAUDE.md`)에서 저장소 경로를 역추적하므로 저장소를 다른 위치에 두어도 동작한다.
`setup.sh`는 마지막에 **settings.json이 참조하는 훅 파일이 실제로 존재하는지** 확인한다. 여기서 누락이 나면 세션 시작이나 모든 Bash 호출이 막힐 수 있다.

## 권한 모델과 위협 모델

**권한 규칙은 모델의 실수를 막는 가드레일이고, 실제 경계는 sandbox다.** 공식 permissions 문서도 "Bash permission patterns that try to constrain command arguments are fragile"라고 명시한다. `python3 -c`, `xargs rm`, `tee`, 변수 치환 등으로 deny 패턴은 우회될 수 있으므로, 시크릿·네트워크 보호는 OS 레벨(sandbox)에 둔다.

| 계층 | 담당 | 설정 |
|---|---|---|
| sandbox (macOS Seatbelt / Linux bubblewrap) | 파일 읽기 차단(`~/.aws`, `~/.gnupg`, `~/.netrc`, `~/.config/gcloud`, `~/.kube`), 네트워크 허용 도메인 목록 | `sandbox.*` |
| deny | 파괴적 git, `rm -rf` 변형, 시크릿 파일 cat/Read, `claude --dangerously-skip-permissions`, `gh repo delete`, `Edit/Write(~/.claude, ~/dotfiles)` | `permissions.deny` |
| ask | `git push/commit/merge/rebase/stash/tag`, `docker`, `rm`, `gh pr merge/create`, `gh release/secret/variable` | `permissions.ask` |
| allow | git 읽기, 패키지 매니저, 일반 유틸, `gh` **읽기 명령만** (`pr view/list/diff/checks`, `issue view/list`, `repo view`, `run list/view`, `api repos/*`) | `permissions.allow` |

`curl`, `claude`, `gh` 전체 허용은 제거했다 (데이터 외부 전송, 권한 우회, 원격 파괴 작업 경로). `~/.ssh`는 sandbox denyRead에 넣지 않았다 — git over ssh가 sandbox 안에서 깨진다. 대신 Read/cat deny 규칙으로 보호하며, 더 강한 보호가 필요하면 ssh-agent 사용 후 denyRead에 추가한다.

sandbox 네트워크는 `allowedDomains` 밖의 호스트에 처음 접근할 때 프롬프트를 띄우고 "다시 묻지 않음"으로 누적된다. sandbox에서 실패한 명령은 `allowUnsandboxedCommands: true`로 비sandbox 재시도 프롬프트를 받는다.

### settings.json 변경 (Edit/Write 도구가 deny이므로)
1. 임시 디렉토리에 새 settings.json 작성 (`jq`로 변환하면 포맷이 유지된다)
2. `diff -u settings.json /tmp/.../settings.json`으로 변경분 확인
3. `cp`로 적용 → `sh scripts/check.sh`
4. 훅 변경의 세션 내 즉시 반영 여부는 공식 문서에 명시되어 있지 않다. 새 세션에서 확인한다.

## skills (슬래시 커맨드)

`commands/`는 `skills/<name>/SKILL.md`로 이관했다 (공식: "Custom commands have been merged into skills"). 세 스킬 모두 `disable-model-invocation: true`로 사용자가 `/name`으로만 호출한다.

| 스킬 | 인자 | 용도 | 모델 자동 호출 |
|---|---|---|---|
| `/plan` | `[작업 이름]` | 작업 계획서 골격 | 허용 — 계획이 필요한 상황이면 알아서 |
| `/bugfix` | `[버그 요약]` | 버그 리포트 골격 | 허용 |
| `/review` | `[base-branch]` | 플로우 기반 QA 리뷰 (범위 선언 → 추적 → 격리 반증) | 차단 |
| `/pr-desc` | `[base-branch]` | 커밋 diff 기반 PR 제목·설명 생성 | 차단 |
| `/tasks-dashboard` | `[all\|recent\|sync\|<file>] [--include-git]` | 태스크 파일 진행 대시보드 | 차단 |

`/plan`·`/bugfix`는 산출물 골격이라 모델이 상황에 맞춰 불러오는 게 이득이다.
나머지 셋은 사용자가 의도적으로 돌리는 절차라 `disable-model-invocation: true`로 자동 호출을 막았다.
이 둘은 예전에 `templates/`에 있던 것을 스킬로 옮긴 것이다 — 공식 문서가 "여러 단계 절차나 일부 상황에서만 쓰는 내용은 스킬로 옮기라"고 권한다.

`~/.claude/skills/`는 외부 스킬(`~/.agents/skills/*`)과 공존해야 하므로 디렉토리 전체가 아니라 **스킬별 심링크**를 건다 (`scripts/setup.sh`가 처리).

## agents (서브에이전트)

`codebase-investigator`, `cross-project-researcher`, `git-history-researcher`, `log-analyzer`. 모두 `model: sonnet`, `disallowedTools: Edit, Write, NotebookEdit`, `permissionMode: plan`으로 **하네스 레벨에서 읽기 전용**을 보장한다 (프롬프트 약속만으로는 Bash 쓰기가 가능했다).

## 머신 전용 설정 분리 — Orca 훅

Orca는 설치 시 `~/.claude/settings.json`(이 저장소 파일의 심링크)에 훅 11종을 직접 주입한다. git **clean 필터**가 커밋 스냅샷에서만 제거하므로 작업 파일에는 남아 Orca가 정상 동작하고, 다른 기기는 훅을 받지 않는다. 필터 등록은 `scripts/setup.sh`가 한다 (git config는 커밋되지 않으므로 clone마다 필요).

- `jq`가 없는 기기에서는 필터가 그대로 통과시켜 커밋을 막지 않는다.
- `git checkout`·`pull`·`merge`가 settings.json을 다시 꺼내면 로컬 Orca 훅이 사라진다 (smudge 필터 없음). Orca를 재시작하면 재주입된다.

## 환경 변수

| 키 | 값 | 설명 |
|---|---|---|
| `CLAUDE_CODE_NO_FLICKER` | `1` | 화면 깜빡임 방지 |
| `BASH_DEFAULT_TIMEOUT_MS` | `120000` | Bash 기본 timeout (2분) |
| `BASH_MAX_TIMEOUT_MS` | `600000` | Bash 최대 timeout (10분) |
| `MAX_MCP_OUTPUT_TOKENS` | `25000` | MCP 출력 토큰 상한 |
| `CLAUDE_DB_GUARD` | (미설정) | `off`면 db-guard 우회 (긴급용, 셸에서 지정) |

## 운영 팁

### 설정을 바꾼 뒤 확인 절차

```bash
sh scripts/check.sh          # 1. 무결성·이식성·훅 회귀 (여기서 실패하면 멈춘다)
claude doctor                # 2. 설치·설정 진단 (세션 밖에서)
```
그다음 **새 세션을 열고** 세션 안에서:

| 명령 | 무엇을 확인하나 |
|---|---|
| `/context` | 의도한 CLAUDE.md·rules 가 실제로 로드됐는지, 컨텍스트를 얼마나 먹는지 |
| `/doctor` | `claude doctor` 의 세션 내 확장판. 미사용 스킬·에이전트, CLAUDE.md 군살 진단 |
| `/hooks` | 훅이 등록된 대로 보이는지 |
| `/memory` | 로드된 메모리 파일 목록, 자동 메모리 on/off |

`model`·`sandbox` 같은 키는 새 세션부터 반영된다. `/context` 로 눈으로 확인하는 습관이 문서 드리프트를 가장 싸게 잡는다.

```bash
tail -50 ~/.claude/audit.log                          # 최근 명령
zcat ~/.claude/backups/audit.log.2026-08-28.gz | grep push   # 과거 로그
sh scripts/check.sh                                   # 변경 후 무결성 + 훅 테스트
sh tests/hooks/run.sh                                 # 훅 테스트만
sh scripts/check.sh --no-tests                        # 무결성·이식성만 (빠름)
```

## 학습 자료 · 작업 기록

| 문서 | 용도 |
|---|---|
| `docs/claude-code-concepts.md` | Claude Code 설정 개념 학습용 정리 — 용어, 로딩 모델, 계층, 장단점 |
| `docs/decisions.md` | **왜** 그렇게 했는지. git log 가 담지 못하는 판단 근거만 한 줄씩 |
| `docs/history/` | 완료된 대형 마이그레이션 기록 |

무엇이 바뀌었는지는 `git log`가 정본이다. `docs/decisions.md`는 중복하지 않고 **되돌리기 쉬운 판단의 이유**만 남긴다.
