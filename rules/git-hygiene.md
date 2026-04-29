# Git and Change Hygiene

> 자동 라우팅: "커밋 / PR / 머지 / 리베이스 / 태그 / 브랜치 정리 / git 이력 작업" 시 즉시 로드.

---

## 1. Atomic Commits

- 커밋은 원자적이고 설명 가능해야 한다.
- "misc fixes", "wip", "various changes" 같은 묶음 커밋 금지.
- 한 커밋 = 한 의도. 두 의도는 두 커밋.

## 2. History Rewrite

- 명시적 요청이 없는 한 히스토리 재작성 금지 (rebase -i, push --force, amend 등).
- 이미 push된 커밋의 amend는 신중. 협업 브랜치라면 거의 금기.

## 3. 포맷팅 vs 행위 변경

- 포맷팅 전용 변경과 행위 변경을 같은 커밋에 섞지 않는다.
- 단, 레포 표준이 그렇게 요구하면 따른다.

## 4. Generated Files

- 생성 파일은 신중히 다룬다:
  - 프로젝트가 커밋을 기대하는 경우에만 커밋.
  - lock 파일(package-lock.json, pnpm-lock.yaml 등)은 보통 커밋.
  - 빌드 산출물(dist/, build/)은 보통 커밋 금지.

## 5. Commit Messages

- "왜"를 우선 — "무엇"은 diff가 말한다.
- 1줄 제목 (50자 이내) + 빈 줄 + 본문 (필요 시).
- 프로젝트 컨벤션이 있으면 (Conventional Commits 등) 따른다.

## 6. PR Discipline

- 작은 PR 선호 — 리뷰 가능 단위로.
- PR 설명: 변경 요약 / 테스트 방법 / 위험·롤백.
- `/pr-desc` 슬래시 커맨드 활용 가능.

## 7. Destructive Operations

다음은 사용자의 명시 요청 없이 실행 금지:
- `git push --force`, `git push -f`, `git push * +`
- `git reset --hard`
- `git clean -f`, `git checkout -- .`, `git restore .`
- `git branch -D`
- `--no-verify`, `--no-gpg-sign`

(권한 시스템 deny 정책으로도 차단되어 있으나, 의도적으로 우회 시도하지 않는다.)

## 8. Pre-commit Hook 실패

- 훅 실패 시 amend로 우회 금지 — 원인을 고치고 **새 커밋** 생성.
- 훅 우회 (`--no-verify`)는 사용자가 명시 요청한 경우에만.

## 9. Verification

상세는 `~/.claude/CLAUDE.md`의 **Definition of Done** 섹션 참조 (SSOT).
커밋·PR 작업도 DoD를 따른다 — 검증 스토리 1~2줄 필수.
