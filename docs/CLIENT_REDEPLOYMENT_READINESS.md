# VictoryFairy iOS redeployment readiness

검증 기준일: 2026-07-26
상태: `SIGNED_RELEASE_READY_SERVER_UPDATE_PENDING`

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
- App Store distribution certificate를 사용한 signed Release archive와 IPA export
- signed IPA 식별자 `com.hwangseokbeom.victoryfairy`, Team `63SB2B8YJ5`
- `get-task-allow=false`, `beta-reports-active=true`
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
2. Spring Boot `3.5.16`과 Jackson/Netty/PostgreSQL JDBC 보안 패치의 전체
   회귀·bootJar·OSV 검증은 완료됐지만 아직 서버에 배치되지 않았다.
3. SNS alarm 이메일 구독은 확인 완료됐다.
4. TestFlight 업로드·설치와 review profile 실제 기기 검증은 수행하지 않았다.

참고용 경기·순위와 일일 갱신, signed IPA는 준비됐다. 현재 제품에는 push
capability가 없으므로 실제 기기 push는 적용 대상이 아니다. 보안 업데이트가
배치되고 별도 승인을 받아 TestFlight에 업로드하기 전까지 현재 결론은
`READY_FOR_SERVER_UPDATE_THEN_TESTFLIGHT`이다.

## 업로드 전 게이트

1. 리뷰 프로필로 출석 기록 핵심 흐름 검증
2. 검증된 Spring Boot dependency 보안 업데이트를 별도 배포 승인 후 서버에
   배치하고 `/health`, `/ready`, KBO 일일 갱신 회귀 확인
3. 필요 시 Community 기능의 리뷰 범위와 비활성 UX 확인
4. 생성된 signed IPA를 별도 승인 후 TestFlight에 업로드하고 실제 기기에서
   리뷰 프로필 핵심 흐름 검증
