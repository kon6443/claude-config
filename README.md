# Claude Code Global Config

Claude Code 글로벌 설정 파일 모음.
`~/.claude/`에 심링크로 연결하여 여러 컴퓨터에서 동일한 환경을 유지.

## 구조

```
claude/
├── CLAUDE.md                # 글로벌 AI 코딩 에이전트 가이드라인
├── settings.json            # 권한(allow/ask/deny), hooks, statusline, 플러그인
├── statusline-command.sh    # 하단 상태바 커스터마이징 스크립트
├── commands/
│   └── review.md            # /review — 플로우 기반 QA 리뷰
└── agents/
    └── cross-project-researcher.md  # 연관 프로젝트 코드 분석
```

### 파일별 역할

| 파일 | 설명 |
|------|------|
| `CLAUDE.md` | 모든 프로젝트에 적용되는 AI 작업 원칙, 워크플로우, 코딩 컨벤션 |
| `settings.json` | permissions(allow/ask/deny), defaultMode, hooks, statusline, 플러그인 |
| `statusline-command.sh` | 프롬프트 하단 상태바 — 컨텍스트 잔량, 세션 사용량, Git 브랜치, 모델명 등 표시 |
| `commands/review.md` | `/review` 슬래시 커맨드 — 변경 코드 QA 리뷰 |
| `agents/cross-project-researcher.md` | 연관 프로젝트(프론트/백 등) 코드 분석 에이전트 |

## 새 컴퓨터 셋업

```bash
# 1. 클론
git clone git@github.com:OnamKwon/claude-config.git ~/dotfiles/claude

# 2. 심링크 (기존 파일이 있으면 백업 후 연결)
for f in commands CLAUDE.md agents settings.json statusline-command.sh; do
  [ -e ~/.claude/$f ] && mv ~/.claude/$f ~/.claude/$f.bak
  ln -s ~/dotfiles/claude/$f ~/.claude/$f
done
```

## 원커맨드 셋업 (클론 + 심링크)

```bash
git clone git@github.com:OnamKwon/claude-config.git ~/dotfiles/claude && \
for f in commands CLAUDE.md agents settings.json statusline-command.sh; do \
  [ -e ~/.claude/$f ] && mv ~/.claude/$f ~/.claude/$f.bak; \
  ln -s ~/dotfiles/claude/$f ~/.claude/$f; \
done
```

## settings.json 주요 설정

### permissions

| 구분 | 동작 | 예시 |
|------|------|------|
| `allow` | 묻지 않고 자동 실행 | `git status`, `pnpm build`, `grep` 등 |
| `ask` | 항상 허가 확인 | `git push`, `git commit`, `rm`, `docker` 등 |
| `deny` | 무조건 차단 (허가 불가) | `rm -rf /`, `git push --force`, `cat ~/.ssh/*` 등 |
| `defaultMode: auto` | allow/ask/deny에 해당 안 되면 AI가 위험도 판단 | - |

### hooks

| 이벤트 | 동작 |
|--------|------|
| `Notification` | 작업 완료/입력 대기 시 macOS 알림센터 팝업 |

### 기타

| 설정 | 값 | 설명 |
|------|-----|------|
| `language` | Korean | 응답 언어 |
| `showTurnDuration` | true | 턴별 소요시간 표시 |
| `attribution` | 빈 문자열 | Co-Authored-By 미표시 |
| `env.CLAUDE_CODE_NO_FLICKER` | 1 | 화면 깜빡임 방지 |

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
