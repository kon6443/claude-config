# Claude Code Global Config

Claude Code 글로벌 설정 파일 모음.
`~/.claude/`에 심링크로 연결하여 여러 컴퓨터에서 동일한 환경을 유지.

## 구조

```
claude-config/
├── CLAUDE.md                # 글로벌 AI 코딩 에이전트 가이드라인
├── settings.json            # 권한(allow/ask/deny), hooks, statusline, 플러그인
├── statusline-command.sh    # 하단 상태바 커스터마이징 스크립트
├── commands/
│   ├── review.md            # /review  — 플로우 기반 QA 리뷰
│   └── pr-desc.md           # /pr-desc — 커밋 diff 기반 PR 제목/설명 생성
└── agents/
    ├── codebase-investigator.md     # 다중 파일·모듈 로직 추적
    ├── cross-project-researcher.md  # 연관 프로젝트(프론트/백 등) 코드 분석
    ├── git-history-researcher.md    # Git 변경 이력 추적
    └── log-analyzer.md              # 대용량 로그 근본 원인 분석
```

### 파일별 역할

| 파일 | 설명 |
|------|------|
| `CLAUDE.md` | 모든 프로젝트에 적용되는 AI 작업 원칙, 워크플로우, 코딩 컨벤션 |
| `settings.json` | permissions(allow/ask/deny), defaultMode, hooks, statusline, 플러그인, env |
| `statusline-command.sh` | 프롬프트 하단 상태바 — 컨텍스트 잔량, 세션 사용량, Git 브랜치, 모델명 등 표시 |

#### commands/ — 슬래시 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/review` | 변경 코드 QA 리뷰. 측정·실행 기반 판단만 허용(추측·"~정도" 표현 불합격) |
| `/pr-desc` | 커밋 diff 기반 PR 제목·설명 한국어 자동 생성 |

#### agents/ — 서브에이전트

| 에이전트 | 설명 |
|----------|------|
| `codebase-investigator` | 3개 이상 파일 읽기 또는 복잡한 호출 체인 추적. 구조화 리포트 반환, 불확실한 부분은 "메인 검증 요청" 명시 |
| `cross-project-researcher` | 프론트↔백 등 연관 프로젝트 코드 조사로 스펙 불일치 사전 방지 |
| `git-history-researcher` | 특정 파일/함수/라인의 변경 이력을 커밋·PR 기반으로 요약. 버그 도입 시점 역추적에 유용 |
| `log-analyzer` | 서버/CI/브라우저/DB 로그에서 에러 필터링, trace-id 묶기, 스택트레이스 추적 |

## 새 컴퓨터 셋업

```bash
# 1. 클론
git clone git@github.com:kon6443/claude-config.git ~/dotfiles/claude-config

# 2. 심링크 (기존 파일이 있으면 백업 후 연결)
for f in commands CLAUDE.md agents settings.json statusline-command.sh; do
  [ -e ~/.claude/$f ] && mv ~/.claude/$f ~/.claude/$f.bak
  ln -s ~/dotfiles/claude-config/$f ~/.claude/$f
done
```

## 원커맨드 셋업 (클론 + 심링크)

```bash
git clone git@github.com:kon6443/claude-config.git ~/dotfiles/claude-config && \
for f in commands CLAUDE.md agents settings.json statusline-command.sh; do \
  [ -e ~/.claude/$f ] && mv ~/.claude/$f ~/.claude/$f.bak; \
  ln -s ~/dotfiles/claude-config/$f ~/.claude/$f; \
done
```

## settings.json 주요 설정

### permissions

| 구분 | 동작 | 예시 |
|------|------|------|
| `allow` | 묻지 않고 자동 실행 | `git status/log/diff/branch/show/fetch`, `pnpm`, `npx eslint/jest/tsc`, `grep`, `find`, `jq`, `gh`, `WebSearch` 등 |
| `ask` | 항상 허가 확인 | `git push`, `git commit`, `git merge/rebase/stash/tag`, `docker`, `rm` |
| `deny` | 무조건 차단 (허가 불가) | `rm -rf /`, `git push --force`, `git reset --hard`, `cat ~/.ssh/*`, `cat */.env*`, `curl \| bash`, `npm publish`, `Edit/Write(~/.claude/**)` 등 |
| `defaultMode: default` | 위 3종에 해당 안 되면 기본 허가 프롬프트 표시 | - |

### hooks

| 이벤트 | 동작 |
|--------|------|
| `Notification` | 작업 완료/입력 대기 시 macOS(`osascript`) 또는 Linux(`notify-send`) 알림 |

### 플러그인 / 마켓플레이스

| 항목 | 값 |
|------|-----|
| `enabledPlugins` | `figma@claude-plugins-official`, `redis-development@redis` |
| `extraKnownMarketplaces.redis` | `https://github.com/redis/agent-skills.git` |

### 기타

| 설정 | 값 | 설명 |
|------|-----|------|
| `language` | Korean | 응답 언어 |
| `showTurnDuration` | true | 턴별 소요시간 표시 |
| `attribution.commit` / `attribution.pr` | `""` | Co-Authored-By·PR 꼬리말 미표시 |
| `env.CLAUDE_CODE_NO_FLICKER` | `1` | 화면 깜빡임 방지 |

## statusline-command.sh 표시 항목

| 표시 | 항목 |
|------|------|
| `📂 project-name` | 현재 디렉토리 |
| `⎇ feat-branch` | Git 브랜치 |
| `🧠 Opus` | 사용 중인 모델 |
| `⏳ 87%` | 컨텍스트 윈도우 잔량 |
| `🔋 session 38%` | 5시간 세션 사용량 잔량 |
| `⏱ 3m25s` | 세션 누적 응답시간 |
| `📊 +150/-30` | 코드 변경량 |

## 새 프로젝트 로컬 설정

글로벌 설정은 범용 규칙만 담고 있으므로, 각 프로젝트에 로컬 설정을 추가하면 정밀도가 올라갑니다.
세션 시작 시 `CLAUDE.md`가 없으면 AI가 자동으로 생성을 제안합니다.

### 필수: 프로젝트 CLAUDE.md

프로젝트 루트에 `CLAUDE.md` 생성. 포함할 내용:
- 프로젝트 소개 (스택, 구조)
- 빌드/실행 커맨드
- 컨벤션 (날짜 처리, 에러 핸들링, 네이밍 등)
- 연관 프로젝트 경로 (예: `../project-front`)
- 태스크 관리 경로 (체크리스트, lessons 파일 위치)

### 선택: 프로젝트 로컬 설정

```
프로젝트/
├── CLAUDE.md                          # 필수
└── .claude/
    ├── settings.local.json            # 선택 — 프로젝트별 권한, additionalDirectories
    ├── commands/
    │   └── review.md                  # 선택 — 프로젝트 특화 QA
    └── agents/
        └── frontend-researcher.md     # 선택 — 프로젝트 특화 에이전트
```
