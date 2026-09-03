---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.zsh"
---

# Shell Script Portability

> **경로 한정 규칙**: 셸 스크립트를 다룰 때만 로드된다 (`paths:` frontmatter).
> 다른 작업에서는 컨텍스트를 차지하지 않는다.
>
> **이 파일이 이식성 규칙의 정본(SSOT)이다.** README 는 여기를 가리키고, `scripts/check.sh` 9절이 위반을 검사한다.
> 규칙을 바꿀 때는 이 파일 → `check.sh` 순서로 고친다.

셸 스크립트는 macOS(bash 3.2 / BSD 유틸)와 Linux·WSL(dash / GNU 유틸)에서 같이 동작해야 한다.
아래는 실제로 깨진 적이 있는 항목만 남긴 목록이다.

## 1. POSIX sh 로만 쓴다

`#!/bin/sh` 로 시작하는 파일에서 bash 확장 금지:

- 프로세스 치환 `<(…)`, `>(…)` — `/dev/fd` 가 없는 환경에서 실패
- `[[ … ]]`, 배열, `${var^^}`·`${var,,}`
- `local` (dash 는 지원하지만 POSIX 아님 — 함수 안 변수는 이름을 유일하게)

bash 기능이 꼭 필요하면 `#!/bin/bash` 로 명시하고, 그 의존성을 파일 주석에 적는다.

## 2. OS 전용 명령에는 폴백을 붙인다

| 명령 | 이식 가능한 형태 |
|---|---|
| 날짜 연산 | `date -v-24H … 2>/dev/null \|\| date -d '24 hours ago' …` |
| 파일 권한 | `stat -c '%a' f 2>/dev/null \|\| stat -f '%Lp' f` — **GNU 를 먼저** |
| 파일 mtime | `date -r f … \|\| stat -f %Sm -t … f \|\| echo unknown` |
| 알림 | `command -v osascript >/dev/null && … \|\| command -v notify-send >/dev/null && …` |

**`stat` 순서가 중요하다.** GNU `stat -f` 는 실패해도 파일시스템 정보를 stdout 에 뱉는다.
BSD 문법을 먼저 시도하면 Linux 에서 출력이 오염된다. macOS 의 `stat` 은 `-c` 를 거부하므로 GNU 를 먼저 두는 순서가 양쪽에서 안전하다.

## 3. `sed -i` 를 쓰지 않는다

BSD 는 `sed -i ''`, GNU 는 `sed -i` 를 요구한다. 이식 가능한 형태가 없다.
임시 파일에 쓰고 `mv` 한다: `sed 's/a/b/' f > "$tmp" && mv "$tmp" f`

## 4. 경로는 `$HOME`·`~` 기준으로만

`/Users/…`, `/home/…`, `/mnt/c/…`, `C:\…` 하드코딩 금지.
스크립트 자기 위치가 필요하면 `ROOT=$(cd "$(dirname "$0")/.." && pwd)`.

## 5. 그 밖에 실제로 문제가 됐던 것

- **`echo` 대신 `printf '%s'`** — `/bin/sh` 의 `echo` 는 `\n` 등을 해석해 JSON 을 훼손한다.
- **here-document 는 임시 파일을 만든다** — 샌드박스나 읽기 전용 `TMPDIR` 에서 실패한다. 값 파싱에는 쓰지 않는다.
- **`$(( ))` 에 소수가 들어가면 셸이 즉시 종료된다** — 숫자는 `jq … | floor` 로 정수화한 뒤 넘긴다.
- **글롭 루프에는 가드를 붙인다** — `for f in dir/*/; do [ -d "$f" ] || continue` 없이 쓰면 매칭 실패 시 리터럴 `*` 가 들어온다.
- **`mktemp` 실패를 대비한다** — 쓰기 불가한 `TMPDIR` 환경이 있다.
- **`eval` 에는 `jq @sh` 로 인용한 값만 넘긴다** — 인용 없이 넘기면 셸 인젝션이 된다.

## 6. 검증

`shellcheck -s sh --severity=warning` 을 통과해야 한다. 심각도를 고정하는 이유는 `info` 진단이 버전마다 달라 CI 만 실패하기 때문이다.

이 저장소에서는 `scripts/check.sh` 9절이 위 1·2·3·4 를 자동으로 검사하고, `tests/hooks/run.sh` 가 5의 항목들을 회귀로 고정한다.
