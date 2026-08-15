# VictoryFairy App Store Review Notes — 1.2.0

## Candidate

- App: 승리요정 - 직관 기록
- Bundle identifier: `com.hwangseokbeom.victoryfairy`
- Marketing version: `1.2.0`
- Build number: `2`
- Minimum iOS version: `17.0`
- Production backend: `https://victoryfairy.duckdns.org`
- Upload state: pending final-source upload
- Build-number uniqueness: must be confirmed in the signed-in App Store Connect

## Review Summary

승리요정은 별도 회원가입 없이 앱이 생성한 장치 식별자로 개인 직관 기록과 설정을
관리합니다. 사용자는 응원 팀과 주 관람 구장을 선택하고, 경기 날짜·팀·구장·결과·
점수·메모·일기·태그·선택적 사진을 포함한 직관 기록을 작성할 수 있습니다.

커뮤니티 글 작성에는 서버가 요구할 때 앱 내 프로필이 필요합니다. 프로필에는 닉네임,
응원 팀, 선택적 이모지 또는 프로필 이미지가 포함될 수 있습니다. 앱 안의 법적 고지
링크에서 계정 및 서버 데이터 삭제 안내를 제공합니다.

경기 전망은 공식 예측이나 베팅 정보가 아니며, 뉴스는 앱 안의 Safari 화면으로 외부
매체를 엽니다. 앱은 KBO 또는 구단의 공식 앱이 아닙니다.

## App Privacy Mapping

The bundled `PrivacyInfo.xcprivacy` conservatively declares the data paths that
exist in the 1.2.0 source. All listed data is used for app functionality, linked
through the app-generated device identity, and not used for tracking.

| App Store privacy category | Current source path | Linked | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Device ID | `X-Device-ID` on authenticated app API requests | Yes | No | App functionality |
| User ID | Profile nickname / screen identity | Yes | No | App functionality |
| Other User Content | Attendance records, diary text, tags and community posts | Yes | No | App functionality |
| Photos or Videos | Optional profile-image upload and photo-analysis request | Yes | No | App functionality |

`UserDefaults` is declared as the required-reason API category
`NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`, because the app
reads and writes only its own app-accessible settings.

## Privacy and Metadata Reconciliation

Completed outside App Store Connect:

1. The public privacy policy now documents the app-generated device identity,
   server-backed attendance records, profile/community paths, operational logs,
   retention, deletion, AWS processing, and the current photo/AI feature state.
2. The account/data-deletion page now explains that deleting the app does not
   automatically delete server records and provides an actionable full-deletion
   request flow.
3. Production `/api/v1/app-config` reports community and profile-image upload as
   disabled. The deployed server source disables photo analysis. External AI is
   also kept disabled for this release; template drafts remain server-local.
4. Legal deployment source: `VictoryFairy-legal` merge commit
   `79b4ccd9e90cca1f625643d49d99f871c3a8a0f6`.

Still required in App Store Connect before submission:

1. Replace the public `Data Not Collected` answer with the four disclosures in
   the table above and publish the updated responses.
2. Set the privacy policy URL to
   `https://hwangseokbeom.github.io/VictoryFairy-legal/privacy.html` and the
   optional privacy choices URL to
   `https://hwangseokbeom.github.io/VictoryFairy-legal/delete-account.html`.
3. Revisit every locale after saving and verify the selected version and build.

## What's New Draft (ko-KR)

```text
승리요정 1.2.0 업데이트

• 온보딩의 응원 팀·주 관람 구장 선택 경험을 개선했습니다.
• 직관 기록 작성과 구장 선택, 기록 상세 화면을 더 명확하게 다듬었습니다.
• 한 경기의 추억을 이미지 카드로 공유하거나 사진에 저장할 수 있습니다.
• 앱 아이콘과 시작 화면을 새롭게 정리했습니다.
• 작은 화면, 큰 글자 및 VoiceOver 사용성을 개선했습니다.
• 전반적인 안정성과 화면 완성도를 높였습니다.
```

## Review Notes Draft (en-US)

```text
VictoryFairy does not require a traditional sign-in. The app creates an
app-specific device identifier and uses it to access the user's records and
profile on the backend.

To exercise profile and community features, create an in-app profile with a
nickname and favorite team. A profile emoji or image is optional. Account and
server-data deletion guidance is available from the legal links in Settings.

Match Outlook is fan-oriented context only. It is not official forecasting,
betting, wagering, or odds information. News items open the original publisher
in an in-app Safari view. VictoryFairy is not affiliated with KBO or its clubs.
```

## Export Compliance

`ITSAppUsesNonExemptEncryption` remains `NO`. The codebase contains no custom
cryptography, third-party cryptography package, VPN, secure-messaging protocol,
certificate pinning or custom TLS stack. Network transport uses Apple-provided
`URLSession` and HTTPS. Reconfirm these facts if encryption-related code or a
third-party SDK is added before upload.

## Local Artifact Evidence

- Archive: `/tmp/VictoryFairy-archives/VictoryFairy-1.2.0-2-privacy-final.xcarchive`
- Exported IPA: `/tmp/VictoryFairy-exports/1.2.0-2-privacy-final/VictoryFairy.ipa`
- IPA SHA-256: `4c0c254f753fd2709e16e223b12963fcfd434545e82055ae13a19b28960731df`
- Distribution signature: Apple Distribution, team `63SB2B8YJ5`
- Store profile UUID: `51ea0ce1-c16a-4cfe-a349-71db038166fb`
- Profile expiry: 2027-04-21
- `get-task-allow`: false
- `beta-reports-active`: true

The archive and IPA paths are temporary local paths. This file records
preparation evidence; it does not assert that a build was uploaded, processed,
installed from TestFlight, submitted for review or released.
