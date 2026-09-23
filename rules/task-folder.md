---
paths:
  - "**/tasks/*/STATUS.md"
  - "**/tasks/*/DECISIONS.md"
  - "**/tasks/*/WORKLOG.md"
---

# 3층 태스크 폴더 유지 규칙

> **경로 한정 규칙**: 3층 태스크 폴더(`/task-folder` 스킬로 만든 `<태스크 디렉토리>/<작업명>/`)의 파일을 다룰 때만 로드된다.
> 만드는 법·템플릿은 `/task-folder` 스킬이 정본이다. 프로젝트 규약이 있으면 그쪽을 따른다.

- **STATUS.md는 150줄 상한** — 넘으면 완료 항목·상세를 WORKLOG.md로 옮기고 1줄 요약만 남긴다.
- **DECISIONS.md·WORKLOG.md는 append-only** — 새 항목은 맨 아래에. 뒤집힌 결정은 기존 항목을 고치지 말고 새 항목에 `supersedes D-00N`.
- **WORKLOG.md는 통째로 읽지 않는다** — `grep -n "^## "`로 목차를 본 뒤 필요한 절만 읽는다.
- 결정 근거는 DECISIONS에, 현황은 STATUS에만 — 같은 내용을 두 곳에 쓰지 않는다.
- 세션을 끝낼 때 STATUS의 **"다음 할 일"**을 갱신한다. 인계가 필요하면 `/session-handoff` 양식으로 `handoff/`에 쓴다.
