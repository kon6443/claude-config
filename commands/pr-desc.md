커밋 diff 기반으로 PR 제목과 설명을 한국어로 자동 생성합니다.

## 절차

### 1단계: 브랜치/베이스 파악
- 현재 브랜치: git rev-parse --abbrev-ref HEAD
- 베이스 브랜치 추정: origin/main 또는 origin/develop (git rev-parse --verify로 확인)
- 사용자가 PR 대상 브랜치를 지정했으면 그대로 사용

### 2단계: 변경 수집
- git log <base>..HEAD --oneline : 포함될 커밋 목록
- git diff <base>...HEAD --stat : 파일별 변경량
- git diff <base>...HEAD : 실제 변경 내용

### 3단계: 변경 카테고리화
커밋 메시지 prefix(feat/fix/refactor/test/docs/chore)와 파일 경로 패턴으로 분류:
- 신규 기능 (feat)
- 버그 수정 (fix)
- 리팩토링 (refactor)
- 테스트 (test)
- 문서 (docs)
- 인프라/설정 (chore/ci)

### 4단계: PR 초안 작성
제목: 70자 이내, 브랜치의 핵심 변경 요약
본문 구조:
- 요약 (Summary): 1~3 bullet
- 주요 변경 (Changes): 카테고리별 목록
- 테스트 계획 (Test plan): 체크박스 목록
- 관련 이슈/티켓 (있으면)

### 5단계: 출력
- 마크다운 블록으로 제목/본문 제공
- pbcopy가 있으면 본문을 클립보드에 복사 여부를 물음 (자동 복사 금지)

## 규칙

- 추측 금지: 커밋 메시지와 diff에 있는 내용만 근거
- 한국어 작성
- 깔끔한 bullet 리스트, 이모지 없음
- breaking change가 있으면 최상단에 명시
- 민감정보/토큰 값이 diff에 포함되어도 PR 설명에는 노출하지 않음

## 출력 예시

제목: feat: 스로틀링 jti 키 기반 글로벌 가드 도입

## Summary
- JWT jti 기반 스로틀링으로 계정/IP 공유 환경까지 커버
- Redis 없이 인메모리 저장 (replica 별 독립)

## Changes
### feat
- ThrottlerGuard 커스텀 구현
- 글로벌 가드 등록

### test
- 스로틀링 초과 시 429 반환 케이스 추가

## Test plan
- [ ] 동일 jti로 초과 요청 시 429 확인
- [ ] 다른 jti는 독립 카운트 확인
- [ ] 헬스체크/로그인 API는 제외 확인
