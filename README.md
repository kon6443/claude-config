# Claude Code Global Config

Claude Code 글로벌 설정 모음. `~/.claude/`에 심링크로 연결하여 여러 컴퓨터에서 동일 환경 유지.

## 구조

```
claude-config/
├── CLAUDE.md                 # 핵심 원칙 + DoD(SSOT) + Communication + 자동 라우팅 표 (~100줄)
├── settings.json             # permissions, hooks, statusline, 플러그인, env
├── statusline-command.sh     # 하단 상태바
├── audit-log.sh              # PreToolUse hook — Bash 명령 audit
├── check-secrets.sh          # UserPromptSubmit hook — 시크릿 패턴 차단
├── sessionstart.sh           # SessionStart hook — 활동 요약 + 위험 명령 + 로그 회전
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
| `SessionStart` | `sessionstart.sh` — 직전 활동 요약(cwd 매칭/노이즈 필터/시크릿 마스킹/24h 윈도) + 위험 명령 강조 + audit.log 일 1회 gzip 회전 + 1MB 초과 시 즉시 trim + 프로젝트 CLAUDE.md 미존재 시 1회 안내. **stdout 출력만 — 컨텍스트 토큰 0** |
| `UserPromptSubmit` | `check-secrets.sh` — 시크릿 패턴 발견 시 모델 전송 전 차단 |
| `PreToolUse(Bash)` | `audit-log.sh` — 모든 Bash 명령을 `~/.claude/audit.log`에 누적 |
| `Notification` | macOS osascript 또는 Linux notify-send 알림 |

### audit.log 회전 정책

| 항목 | 값 |
|---|---|
| 회전 주기 | 일 1회 (자정 넘어 첫 SessionStart) |
| 회전 방식 | gzip 압축 → `~/.claude/backups/audit.log.YYYY-MM-DD.gz` |
| 보관 기간 | 30일 (이후 자동 삭제) |
| 안전망 | 1MB 초과 시 즉시 `tail -10000`로 trim |
| 시크릿 마스킹 | stdout 출력 시 토큰·키 패턴 `[REDACTED]` |
| 외부 의존성 | 없음 (launchd/cron/logrotate 불필요) |

## permissions

| 구분 | 동작 | 예시 |
|---|---|---|
| `allow` | 자동 실행 | git 읽기 명령, 패키지 매니저, 일반 유틸 (`grep`, `find`, `jq`, `gh`) |
| `ask` | 매번 확인 | `git push/commit/merge/rebase/stash/tag`, `docker`, `rm` |
| `deny` | 무조건 차단 | `rm -rf /` 변형, `git push --force/-f`, `git reset --hard`, ssh/env/credentials/pem/key 읽기, `Edit/Write(~/.claude/**)`, `Edit/Write(~/dotfiles/**)`, `npm publish` 등 |

`Edit/Write(~/.claude/**)`, `Edit/Write(~/dotfiles/**)` 차단은 **자기 자신의 글로벌 설정을 보호**한다. 갱신 작업이 필요할 때는 임시 디렉토리에 작성 후 사용자가 직접 `cp`로 이동.

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

## 셋업 (멱등 — 재실행 안전)

```bash
[ -d ~/dotfiles/claude-config ] || git clone <repo> ~/dotfiles/claude-config
mkdir -p ~/.claude
TS=$(date +%Y%m%d_%H%M%S)
for f in CLAUDE.md settings.json statusline-command.sh audit-log.sh check-secrets.sh sessionstart.sh agents commands rules templates; do
  src="$HOME/dotfiles/claude-config/$f"
  dst="$HOME/.claude/$f"
  [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && { echo "✓ $f: skip"; continue; }
  ([ -e "$dst" ] || [ -L "$dst" ]) && mv "$dst" "$dst.bak.$TS"
  ln -s "$src" "$dst"
  echo "✓ $f: 연결됨"
done
chmod +x ~/dotfiles/claude-config/*.sh
```

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

### 라우팅 디버그
```bash
# CLAUDE.md 라우팅 표가 모든 분할 파일을 가리키는지
grep -E 'rules/|templates/' ~/.claude/CLAUDE.md

# 신규 rules 파일 추가 후 라우팅 표 갱신 누락 확인
diff <(ls ~/.claude/rules/*.md | xargs -n1 basename) \
     <(grep -oE 'rules/[a-z-]+\.md' ~/.claude/CLAUDE.md | sort -u | xargs -n1 basename)
```

### settings.json 변경 (deny에 막혀 있으므로)
1. 임시 디렉토리에 새 settings.json 작성
2. `cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%Y%m%d-%H%M%S)`
3. `cp /tmp/.../settings.json ~/dotfiles/claude-config/settings.json`
4. 새 세션 시작 → 동작 검증

### 전수조사 스크립트 (변경 후 무결성 검증)

설정 파일을 변경할 때마다 다음을 실행해 라우팅·심링크·권한·SSOT 무결성을 한 번에 확인.

```bash
cd ~/dotfiles/claude-config

echo "═══ 1. 파일 존재 + 크기 ═══"
for f in CLAUDE.md rules/workflow.md rules/context.md rules/engineering.md rules/error-recovery.md rules/git-hygiene.md templates/plan.md templates/bugfix.md sessionstart.sh settings.json README.md TASKS.md .gitignore; do
  [ -e "$f" ] && printf "  OK   %-30s %5s bytes  %3s lines\n" "$f" "$(wc -c<"$f"|tr -d ' ')" "$(wc -l<"$f"|tr -d ' ')" || printf "  MISS %s\n" "$f"
done

echo "═══ 2. ~/.claude 심링크 ═══"
for f in CLAUDE.md settings.json statusline-command.sh audit-log.sh check-secrets.sh sessionstart.sh agents commands rules templates; do
  link="$HOME/.claude/$f"
  if [ -L "$link" ] && [ -e "$link" ]; then echo "  OK $f"
  elif [ -L "$link" ]; then echo "  BROKEN $f"
  elif [ -e "$link" ]; then echo "  FILE $f (not a symlink)"
  else echo "  MISS $f"; fi
done

echo "═══ 3. JSON / shell 문법 ═══"
jq empty ~/.claude/settings.json && echo "  settings.json OK"
for f in *.sh; do sh -n "$f" && echo "  $f OK"; done

echo "═══ 4. DoD SSOT (정의 1곳) ═══"
grep -l "^## Definition of Done" CLAUDE.md rules/*.md templates/*.md 2>/dev/null

echo "═══ 5. 프로젝트 특화 잔재 ═══"
grep -niE 'mobisell|laravel|nestjs|swagger' CLAUDE.md rules/*.md templates/*.md README.md 2>/dev/null || echo "  OK: 없음"

echo "═══ 6. 실행 권한 ═══"
for f in *.sh; do [ -x "$f" ] && echo "  OK $f" || echo "  CHMOD NEEDED $f"; done

echo "═══ 7. .gitignore 동작 ═══"
git status --porcelain | grep -E '\.bak(\.|$)' && echo "  FAIL: 백업 추적됨" || echo "  OK"
```
