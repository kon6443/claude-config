# Claude Code 설정 개념 정리 (학습용)

이 저장소가 무엇을 왜 그렇게 설정했는지 이해하기 위한 배경 지식.
"이 파일이 뭐 하는 거지?"에 답하는 것이 목적이다. 실제 설정값은 `README.md`, 판단 근거는 `decisions.md`에 있다.

기준: Claude Code 2.1.x, 공식 문서 `code.claude.com/docs`.

---

## 1. 한눈에 보는 계층

Claude Code 설정은 **성격이 다른 네 계층**으로 나뉜다. 이걸 구분하는 게 가장 중요하다.

| 계층 | 예 | 성격 | 어기면 |
|---|---|---|---|
| **강제 (OS)** | `sandbox` | 커널이 막는다. 우회 불가 | 명령이 실패한다 |
| **강제 (하네스)** | `permissions`, `hooks` | Claude Code가 도구 호출을 막는다 | 차단되거나 확인을 묻는다 |
| **지침 (컨텍스트)** | `CLAUDE.md`, `rules/` | 모델에게 읽히는 글. 설정이 아니다 | 모델이 안 지킬 수 있다 |
| **절차 (호출형)** | `skills/`, `agents/` | 필요할 때 불러오는 지시서 | 안 불러오면 적용 안 됨 |

> 공식 문서 표현: 메모리(CLAUDE.md·rules)는 "context, not enforced configuration"이다.
> **무조건 막아야 하는 것은 훅이나 sandbox로 내려야 한다.** 글로 적어두는 것만으로는 경계가 아니다.

---

## 2. CLAUDE.md — 상시 지침

**무엇**: 매 세션 시작 시 자동으로 컨텍스트에 들어가는 마크다운. Claude가 "항상 알고 있어야 하는 사실"을 적는다.

**위치와 범위** (넓은 것부터 로드되고, 좁은 쪽이 우선한다):

| 범위 | 위치 | 용도 |
|---|---|---|
| 조직 정책 | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) | 회사 표준 |
| **사용자** | `~/.claude/CLAUDE.md` | 모든 프로젝트에 적용되는 개인 취향 ← **이 저장소** |
| 프로젝트 | `./CLAUDE.md` 또는 `./.claude/CLAUDE.md` | 팀 공유. 빌드 명령, 아키텍처 |
| 로컬 | `./CLAUDE.local.md` | 개인용 프로젝트 설정. gitignore 대상 |

**넣을 것**: 빌드 명령, 컨벤션, 프로젝트 구조, "항상 X 해라" 규칙.
**빼야 할 것**: 여러 단계로 이뤄진 절차, 일부 상황에서만 쓰는 내용. → 스킬이나 경로 한정 규칙으로 옮긴다.

**장점**: 확실히 로드된다. 압축이 일어나도 다시 로드되므로 세션 후반에 사라지지 않는다.
**단점**: 항상 토큰을 쓴다. 길어지면 개별 문장의 영향력이 희석된다. 서로 모순되는 규칙이 있으면 모델이 임의로 하나를 고른다.

**핵심 함정**: 사용자 레벨 파일은 **모든** 프로젝트에 적용된다. 특정 언어나 프레임워크 전제를 넣으면 다른 프로젝트에서 오작동한다.

---

## 3. rules/ — 주제별로 쪼갠 지침

**무엇**: `~/.claude/rules/*.md` 또는 `.claude/rules/*.md`. 하위 디렉토리까지 재귀 탐색된다.

**핵심 특징 두 가지.**

1. **`paths:` 없는 파일은 CLAUDE.md와 같이 세션 시작 시 무조건 로드된다.** 로드 순서만 다르고 성격은 CLAUDE.md와 같다.
2. **`paths:` 프론트매터를 쓰면 조건부가 된다.** 해당 패턴의 파일을 읽을 때만 활성화된다.

```markdown
---
paths:
  - "src/**/*.{ts,tsx}"
  - "tests/**/*.test.ts"
---

# TypeScript 규칙
- any 금지
```

**왜 쪼개는가**: 한 파일에 다 넣으면 관리가 안 되고, 주제별로 나누면 사람이 고치기 쉽다. 토큰 절감 효과는 `paths:`를 쓸 때만 생긴다. 조건 없는 rules는 CLAUDE.md에 넣은 것과 토큰 비용이 같다.

**이 저장소**: 5개 파일 280줄, 전부 조건 없음. 엔지니어링·에러 복구·git 위생·워크플로·컨텍스트 관리.

**흔한 오해**: "트리거 단어가 나오면 그때 읽는다"고 착각하기 쉽다. 아니다. 조건 없는 rules는 처음부터 다 들어와 있다. 그래서 각 파일 헤더에 "적용 상황"을 적어 판단을 돕는다.

---

## 4. skills/ — 호출형 절차

**무엇**: `~/.claude/skills/<name>/SKILL.md`. `/name`으로 호출하는 슬래시 커맨드이자, 모델이 상황에 맞춰 스스로 불러오는 지시서.

**`commands/`는 여기로 통합됐다.** 공식 문서: "Custom commands have been merged into skills." 기존 `commands/*.md`도 계속 동작하지만 프론트매터 기능을 못 쓴다.

**로딩 방식이 rules와 결정적으로 다르다.** 이름과 설명만 상시 노출되고, **본문은 호출될 때 들어온다.** 그래서 절차가 길어도 상시 토큰 비용이 거의 없다.

**주요 프론트매터**

| 키 | 뜻 |
|---|---|
| `name`, `description` | 필수. 설명이 곧 "언제 불러야 하는가"의 판단 근거다 |
| `when_to_use` | 트리거 문구·예시 요청을 덧붙인다 |
| `argument-hint` | 자동완성에 보이는 인자 힌트 |
| `disable-model-invocation: true` | 모델이 스스로 못 부르게 한다. 사람이 의도적으로 돌리는 절차에 쓴다 |
| `user-invocable: false` | 반대. 사람은 못 부르고 모델만 부른다 |
| `allowed-tools` | 그 턴 동안 확인 없이 쓸 도구 |
| `arguments` | 이름 있는 위치 인자. 본문에서 `$name`으로 치환 |

**본문에서 쓰는 치환**: `$ARGUMENTS`(전체), `$0`·`$1`(위치), `$name`(이름 있는 인자).

**장점**: 긴 절차를 공짜로 보관한다. 직접 호출과 자동 호출을 선택할 수 있다.
**단점**: 자동 호출은 설명문 품질에 좌우된다. 설명이 모호하면 안 불린다.

**이 저장소**: 5개. `/plan`·`/bugfix`는 자동 호출 허용(산출물 골격이라 상황에 맞춰 불리는 게 이득), `/review`·`/pr-desc`·`/tasks-dashboard`는 자동 호출 차단(사람이 의도적으로 돌리는 절차).

---

## 5. agents/ — 별도 컨텍스트의 하위 작업자

**무엇**: `~/.claude/agents/<name>.md`. 자기만의 컨텍스트 창에서 도는 서브에이전트.

**존재 이유는 컨텍스트 보호다.** 20개 파일을 훑어야 하는 조사를 메인 대화에서 하면 그 내용이 다 남는다. 서브에이전트에 맡기면 **요약된 리포트만** 메인으로 돌아온다.

**주요 프론트매터**: `name`, `description`(필수), `tools`/`disallowedTools`, `model`(`sonnet`·`opus`·`haiku`·`inherit`), `permissionMode`, `skills`, `memory`, `maxTurns`, `isolation: worktree`.

**중요한 제약**: 서브에이전트는 **사용자와 직접 대화할 수 없다.** "사용자에게 물어보고 중단"은 불가능하다. 리포트에 "정보 필요"를 명시해 메인이 묻게 해야 한다.

**읽기 전용을 보장하는 법**: 프롬프트에 "수정하지 않는다"고 적는 것만으로는 부족하다. Bash가 허용되면 실제로 쓸 수 있다. `disallowedTools: Edit, Write, NotebookEdit`처럼 **하네스 레벨로 내려야** 한다.

**이 저장소**: 4개. 코드베이스 조사, 연관 프로젝트 조사, git 이력 조사, 로그 분석. 전부 읽기 전용을 하네스로 강제.

---

## 6. hooks — 결정적으로 실행되는 셸

**무엇**: 특정 시점에 Claude Code가 실행하는 셸 명령. 모델의 판단이 개입하지 않는다. **"항상 X 해라"를 확실히 보장하는 유일한 수단.**

**자주 쓰는 이벤트**

| 이벤트 | 시점 | 대표 용도 |
|---|---|---|
| `SessionStart` | 세션 시작 (`startup`/`resume`/`clear`/`compact`/`fork`) | 컨텍스트 주입, 정리 작업 |
| `UserPromptSubmit` | 프롬프트 전송 직전 | 시크릿 차단, 컨텍스트 추가 |
| `PreToolUse` | 도구 실행 직전 | 감사 로그, 허용/차단 판정 |
| `PostToolUse` | 도구 실행 직후 | 자동 포맷·린트 |
| `SessionEnd` | 세션 종료 | 정리, 통계 |
| `Notification` | 사용자 주의 필요 시 | 데스크톱 알림 |

**입출력 규약** (가장 헷갈리는 부분)

- 입력: stdin으로 JSON. `cwd`, `tool_input`, `prompt`, `session_id` 등.
- 종료 코드: `0` 성공, `2` 차단(stderr가 사용자/모델에게 보인다), 그 외는 비차단 오류.
- **stdout 취급이 이벤트마다 다르다.** 대부분은 디버그 로그로만 간다. 그런데 `SessionStart`, `UserPromptSubmit`, `UserPromptExpansion`, `PostModelSwitch`는 **평문 stdout을 모델 컨텍스트에 넣는다.**
- stdout이 `{`로 시작하고 `}`로 끝나면 JSON으로 파싱된다. 그러면 평문 취급이 아니다.
- 사용자에게만 보이려면 `{"systemMessage": "..."}`를 쓴다. 모델에게 주려면 `{"hookSpecificOutput": {"additionalContext": "..."}}`를 쓴다.

**함정**: 사용자에게 보여줄 요약을 `SessionStart`에서 평문으로 출력하면, 의도와 달리 매 세션 그 내용이 모델 컨텍스트에 실린다. matcher를 `*`로 두면 압축마다 재실행되어 반복 주입된다.

**설계 원칙**: 훅이 실패해도 세션 전체가 멈추지 않게 한다(fail-open). 단, 정말 막아야 할 것이 확실히 감지됐을 때만 `exit 2`로 차단한다.

---

## 7. permissions — 도구 호출 게이트

**무엇**: `settings.json`의 `permissions`. 어떤 도구 호출을 자동 허용/확인/차단할지 정한다.

```json
{ "permissions": {
    "allow": ["Bash(git status:*)"],
    "ask":   ["Bash(git push *)"],
    "deny":  ["Read(**/*.pem)"],
    "defaultMode": "default" } }
```

**패턴 문법**

- `Bash(prefix:*)` — 접두 일치. `Bash(ls:*)`와 `Bash(ls *)`는 같다.
- `*`는 패턴 어디에나 놓을 수 있다.
- 복합 명령(`a && b`, `a | b`)은 **각 부분이 따로 검사된다.** 한 부분이라도 허용되지 않으면 확인을 묻는다.
- 파일 경로: `//abs`는 절대경로, `~/x`는 홈 기준, `/x`는 **설정 파일 위치 기준**(절대경로 아님), `x`는 현재 디렉토리 기준.

**결정적으로 중요한 한계**: 공식 문서가 명시한다 — 인자를 제약하려는 Bash 패턴은 **취약하다(fragile)**. 옵션 순서, 변수 치환, 리다이렉트, 다른 도구로의 우회가 모두 가능하다.

즉 `Read(**/*.pem)`으로 막아도 `python3 -c`나 `cat`으로 읽을 수 있다. `python3`이 허용돼 있으면 그 차단은 사실상 없다.

**그래서 결론**: permissions는 **모델의 실수를 줄이는 가드레일**로 쓴다. 적대적 경계는 sandbox가 담당한다.

---

## 8. sandbox — 진짜 경계

**무엇**: macOS Seatbelt, Linux/WSL2 bubblewrap을 이용한 OS 레벨 격리. Windows 네이티브는 미지원.

```json
{ "sandbox": {
    "enabled": true,
    "filesystem": { "denyRead": ["~/.aws"], "allowWrite": ["/tmp/build"] },
    "network": { "allowedDomains": ["github.com", "*.npmjs.org"] } } }
```

**두 계층이 독립적이다.** 파일시스템 격리(어떤 경로를 읽고 쓸 수 있나)와 네트워크 격리(어떤 호스트에 나갈 수 있나).

**특징**

- OS가 강제하므로 **자식 프로세스까지 적용된다.** 셸 스크립트가 띄운 파이썬도 못 벗어난다.
- 넓은 `allowRead` 안의 `denyRead`가 이긴다. 넓게 열어도 특정 경로는 계속 막힌다.
- 네트워크는 기본 허용 도메인이 없다. 새 호스트에 처음 나갈 때 확인을 묻고 누적된다.
- sandbox 안에서 실패한 명령은 `allowUnsandboxedCommands`가 켜져 있으면 비sandbox 재시도 확인을 받는다.

**장점**: 우회가 어렵다. 실수로 자격증명을 읽거나 데이터를 외부로 보내는 사고를 실제로 막는다.
**단점**: 마찰이 생긴다. 도구에 따라 인증서 검증에서 걸리기도 하고, 임시 파일 경로 가정이 깨지기도 한다. 도커 소켓 같은 유닉스 소켓도 기본 차단이다.

---

## 9. settings.json — 나머지 전부

우선순위는 좁은 쪽이 이긴다: 조직 관리 설정 → `~/.claude/settings.json` → `.claude/settings.json` → `.claude/settings.local.json`.

**개인 설정에서 자주 쓰는 키**

| 키 | 뜻 |
|---|---|
| `model` | 기본 모델. `[1m]` 접미는 100만 토큰 컨텍스트 |
| `effortLevel`, `modelSettings` | 추론 강도. 모델별로 따로 저장 가능 |
| `env` | 세션에 주입할 환경 변수 |
| `statusLine` | 하단 상태바를 만드는 명령 |
| `language` | 응답 언어 |
| `outputStyle` | 역할·어조·형식을 바꾸는 저장된 지시 묶음 이름 |
| `autoMemoryEnabled` | 자동 메모리 on/off (기본 on) |
| `cleanupPeriodDays` | 대화 기록 보관 일수 |
| `attribution` | 커밋·PR에 붙는 서명 |
| `enabledPlugins`, `extraKnownMarketplaces` | 플러그인 |

---

## 10. 메모리 두 종류

같은 "메모리"라는 말이 두 가지를 가리킨다.

| | CLAUDE.md · rules | 자동 메모리 |
|---|---|---|
| 누가 쓰나 | 사람 | Claude가 스스로 |
| 무엇 | 지침. "이렇게 해라" | 관찰. "이 사람은 이런 걸 고쳤다" |
| 로딩 | 세션 시작 시 전부 | 관련될 때 회상 |
| 편집 | 직접 파일 수정 | `/memory` |

기본으로 켜져 있고 서로 보완 관계다. 원칙은 CLAUDE.md에, 사용자 교정 이력은 자동 메모리에 쌓인다.

---

## 11. 자주 쓰는 진단 명령

| 명령 | 용도 |
|---|---|
| `/context` | 지금 무엇이 로드됐고 컨텍스트를 얼마나 썼는지 |
| `/memory` | 로드된 메모리 파일 관리, 자동 메모리 토글 |
| `/hooks` | 등록된 훅 확인 |
| `/sandbox` | sandbox 상태와 예외 관리 |
| `claude doctor` | 설치·설정 진단 |
| `/usage` | 사용량과 한도 |
| `/rewind` | 체크포인트로 되돌리기 |

---

## 12. "무엇을 어디에 둘까" 결정표

새 규칙이나 절차를 추가할 때 이 순서로 판단한다.

1. **무조건 막아야 하나?** → 훅(`exit 2`) 또는 sandbox. 글로 적지 않는다.
2. **매번 확인받고 싶은가?** → `permissions.ask`.
3. **모든 세션에서 항상 참인 짧은 사실인가?** → `CLAUDE.md`.
4. **주제가 뚜렷하고 계속 참인가?** → `rules/<주제>.md`.
5. **특정 파일 종류에서만 참인가?** → `rules/<주제>.md` + `paths:`.
6. **여러 단계 절차이거나 산출물 골격인가?** → `skills/<name>/SKILL.md`.
7. **파일을 많이 읽어야 하는 조사인가?** → `agents/<name>.md`.

**가장 흔한 실수**: 3번에 다 넣는 것. CLAUDE.md가 길어지면 모든 문장의 영향력이 같이 떨어진다.

---

## 13. 이 저장소에 적용된 결과

| 파일·디렉토리 | 계층 | 왜 여기에 |
|---|---|---|
| `CLAUDE.md` | 지침(상시) | 완료 정의, 커뮤니케이션 규약처럼 매 응답에 적용되는 것만 |
| `rules/*.md` | 지침(상시) | 주제별 상세. 사람이 고치기 쉽게 쪼갬 |
| `skills/*/SKILL.md` | 절차(호출형) | 산출물 골격과 다단계 절차. 본문은 호출 시에만 로드 |
| `agents/*.md` | 절차(별도 컨텍스트) | 대량 파일 조사. 읽기 전용을 하네스로 강제 |
| `*.sh` + `settings.json` 훅 | 강제(하네스) | 감사 로그, 시크릿 차단, DB 게이트 |
| `settings.json` sandbox | 강제(OS) | 자격증명 읽기 차단, 네트워크 허용 목록 |
| `scripts/check.sh` + `tests/` | 검증 | 위 설정이 실제로 그렇게 동작하는지 |

---

## 더 읽을 곳

| 주제 | 링크 |
|---|---|
| 메모리와 rules | https://code.claude.com/docs/en/memory |
| 스킬 | https://code.claude.com/docs/en/skills |
| 서브에이전트 | https://code.claude.com/docs/en/sub-agents |
| 훅 | https://code.claude.com/docs/en/hooks |
| 권한 | https://code.claude.com/docs/en/permissions |
| sandbox | https://code.claude.com/docs/en/sandboxing |
| 설정 전체 목록 | https://code.claude.com/docs/en/settings-reference |
