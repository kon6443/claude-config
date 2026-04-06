# Claude Code Global Config

Claude Code 글로벌 설정 (commands, agents, CLAUDE.md).
`~/.claude/`에 심링크로 연결하여 사용.

## 구조

```
claude/
├── CLAUDE.md              # 글로벌 AI 코딩 에이전트 가이드라인
├── commands/
│   └── review.md          # /review — 플로우 기반 QA 리뷰
└── agents/
    └── cross-project-researcher.md  # 연관 프로젝트 코드 분석
```

## 새 컴퓨터 셋업

```bash
# 1. 클론
git clone git@github.com:OnamKwon/claude-config.git ~/dotfiles/claude

# 2. 심링크 (기존 파일이 있으면 백업 후 삭제)
[ -e ~/.claude/commands ] && mv ~/.claude/commands ~/.claude/commands.bak
[ -e ~/.claude/CLAUDE.md ] && mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
[ -e ~/.claude/agents ] && mv ~/.claude/agents ~/.claude/agents.bak

ln -s ~/dotfiles/claude/commands ~/.claude/commands
ln -s ~/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/dotfiles/claude/agents ~/.claude/agents
```

## 원커맨드 셋업 (클론 + 심링크)

```bash
git clone git@github.com:OnamKwon/claude-config.git ~/dotfiles/claude && \
for f in commands CLAUDE.md agents; do [ -e ~/.claude/$f ] && mv ~/.claude/$f ~/.claude/$f.bak; ln -s ~/dotfiles/claude/$f ~/.claude/$f; done
```

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

### 선택: 로컬 /review 커맨드

프로젝트별 QA 체크리스트가 필요하면 `.claude/commands/review.md` 생성.
로컬이 글로벌보다 우선 적용됩니다.

```
프로젝트/
├── CLAUDE.md                          # 필수
└── .claude/
    ├── commands/
    │   └── review.md                  # 선택 — 프로젝트 특화 QA
    └── agents/
        └── frontend-researcher.md     # 선택 — 프로젝트 특화 에이전트
```
