# VictoryFairy iOS redeployment readiness

검증 기준일: 2026-07-26
상태: `PARTIALLY_READY`

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

저장소에는 XCTest target이 없어 자동 단위/UI 테스트 결과를 주장하지 않는다.

## 현재 차단 항목

1. 신규 database의 경기와 순위가 비어 있다.
2. production KBO refresh는 Playwright Chromium runtime 부재로 실패했다.
3. t3.small에서 브라우저를 현장 설치하면 메모리/CPU 포화가 발생했으므로 같은
   설치를 재시도하지 않는다.
4. Community 기능은 production contract에 따라 비활성 상태다.
5. signed archive와 App Store Connect 설치 검증은 수행하지 않았다.

실제 경기·순위 데이터가 없는 상태로는 핵심 제품 경험을 리뷰할 수 없으므로
현재 결론은 `NO-GO_FOR_APP_STORE_UPLOAD`이다.

## 업로드 전 게이트

1. CI 또는 별도 빌드 환경에서 검증된 Chromium/Playwright runtime artifact 준비
2. KBO production refresh 성공 및 경기·순위 데이터 확인
3. 리뷰 프로필로 출석 기록 핵심 흐름 검증
4. 필요 시 Community 기능의 리뷰 범위와 비활성 UX 확인
5. 서명된 Release archive 후 별도 승인으로 TestFlight/App Store 업로드
