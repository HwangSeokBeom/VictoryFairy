# VictoryFairy iOS redeployment readiness

검증 기준일: 2026-07-26
상태: `SERVER_READY_CLIENT_RELEASE_PENDING`

## 릴리스 계약

- scheme: `VictoryFairy-Production`
- Bundle ID: `com.hwangseokbeom.victoryfairy`
- Apple Team ID: `63SB2B8YJ5`
- minimum iOS: 17.0
- production API: `https://victoryfairy.duckdns.org`

현재 제품에는 FCM, push entitlement, associated domain, custom URL scheme가
없다. 따라서 서버 이전의 필수 계약은 HTTPS REST, 리뷰 프로필, 팀·경기·순위
데이터이다.

## 완료된 검증

- Debug/Release simulator build
- unsigned device archive
- release readiness script
- secret scan과 `git diff --check`
- 공개 `/health`와 `/ready`
- 리뷰 프로필 생성·조회
- KBO 팀 목록 10개 조회
- production Playwright Chromium 설치와 일일 KBO refresh 활성화
- 2026 시즌 675건 수집·삽입, warning 0건
- public 경기 5건과 순위 10팀이 `참고용 경기 정보`로 표시됨
- VictoryFairy Legal의 모든 공개 페이지가 HTTPS 200으로 응답

저장소에는 XCTest target이 없어 자동 단위/UI 테스트 결과를 주장하지 않는다.

## 현재 차단 항목

1. Community 기능은 production contract에 따라 비활성 상태다.
2. Spring Boot dependency 보안 업데이트가 서버 cutover blocker로 남아 있다.
3. SNS alarm 이메일 구독이 아직 `PendingConfirmation`이다.
4. signed archive와 App Store Connect 설치 검증은 수행하지 않았다.

참고용 경기·순위와 일일 갱신은 준비됐지만 서버 dependency 보안 업데이트와
서명된 client 검증이 남아 있으므로 현재 결론은
`NO-GO_FOR_APP_STORE_UPLOAD`이다.

## 업로드 전 게이트

1. 리뷰 프로필로 출석 기록 핵심 흐름 검증
2. Spring Boot dependency 보안 업데이트와 서버 회귀 검증
3. 필요 시 Community 기능의 리뷰 범위와 비활성 UX 확인
4. 서명된 Release archive 후 별도 승인으로 TestFlight/App Store 업로드
