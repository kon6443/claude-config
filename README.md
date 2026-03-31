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
