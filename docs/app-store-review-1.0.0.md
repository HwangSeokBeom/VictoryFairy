# VictoryFairy App Store Review Notes - 1.0.0

## App Summary

- App name: 승리요정
- Version: 1.0.0
- Build number: 1
- Production backend URL: http://victoryfairy.duckdns.org
- Development backend URL: http://localhost:8081
- Development simulator fallback URL: http://127.0.0.1:8081
- iOS client architecture: the app calls VictoryFairySpringServer only. It must not call Groq, Naver, KBO, or other upstream provider APIs directly from iOS.

## Account And Profile Behavior

VictoryFairy uses an app-generated device identifier for backend requests. Posting in the community requires an in-app profile when the server requires one. Profile creation collects a nickname, favorite team, and optional profile emoji or profile image. Account deletion information is available from the in-app policy links.

## Community Moderation

Community features include an in-app community policy link, reporting, and blocking controls. If the community backend is disabled or unavailable, the app shows a graceful 준비 중 or retry state rather than exposing development-only labels. Posting, reporting, and blocking require a profile when required by the backend.

## Baseball Data And Non-Affiliation Notes

VictoryFairy presents KBO-related game and standings information as 참고용 경기 정보 or similar reference wording. The app should not describe this data as official KBO data or official record provision. Detailed or official records should be verified through KBO-related official channels.

## Match Outlook Disclaimer

Match Outlook must display this disclaimer:

> 공식 예측이나 베팅 정보가 아닙니다.

This feature is positioned as fan-oriented context and cheering guidance, not betting, odds, official forecasting, or wagering advice.

## News Link-Out Behavior

News items are opened in Safari view. The production-safe disclosure is:

> 뉴스는 외부 매체로 이동해 확인해 주세요.

## Privacy And Legal URLs

- Homepage: https://hwangseokbeom.github.io/VictoryFairy-legal/
- Terms: https://hwangseokbeom.github.io/VictoryFairy-legal/terms.html
- Privacy policy: https://hwangseokbeom.github.io/VictoryFairy-legal/privacy.html
- Support: https://hwangseokbeom.github.io/VictoryFairy-legal/support.html
- Account deletion: https://hwangseokbeom.github.io/VictoryFairy-legal/delete-account.html
- Disclaimer: https://hwangseokbeom.github.io/VictoryFairy-legal/disclaimer.html
- Community policy: https://hwangseokbeom.github.io/VictoryFairy-legal/community-policy.html

The app attempts to fetch `/api/v1/legal-links` from VictoryFairySpringServer and falls back to these constants if the server response is unavailable.

## Encryption And Export Compliance Technical Assessment

Technical scan performed for:

- CryptoKit
- CommonCrypto
- Security framework encryption APIs such as SecKey
- AES, RSA, ECC, and HMAC implementation references
- Third-party crypto libraries
- End-to-end encryption logic
- Certificate pinning or a custom TLS stack
- Package dependencies

Result: no custom cryptography, third-party crypto dependency, end-to-end encryption logic, certificate pinning, or custom TLS stack was found in the iOS codebase. No Swift Package dependencies were present.

The app uses Apple-provided networking APIs such as URLSession. If HTTPS/TLS is used, it is standard platform/network transport security provided by iOS/Foundation. The app does not provide cryptographic functionality to end users, does not implement proprietary encryption, and does not provide VPN, secure messaging, file encryption, password management, crypto wallet, banking, or military/security encryption features.

The iOS target sets `ITSAppUsesNonExemptEncryption = NO` based on this technical assessment. This is not legal advice; it is a codebase-level assessment of the app's current technical implementation.

Suggested App Store Connect answer:

- If asked whether the app uses encryption: the app may use standard Apple networking/security functionality such as HTTPS/TLS when communicating over HTTPS.
- If asked whether the app uses non-exempt encryption: answer "No" based on the current codebase because VictoryFairy does not implement proprietary or non-exempt encryption and uses only Apple-provided standard networking/security functionality.
- If asked for export compliance documentation: "VictoryFairy does not implement custom encryption. The app uses Apple-provided standard networking APIs. It does not provide cryptographic functionality to end users."

Note: the current production backend URL is HTTP. This export-compliance assessment is based on whether the app contains non-exempt encryption, not on whether the current production URL uses HTTPS. Before App Store submission, moving the production backend to HTTPS is recommended for transport security and App Review posture.

Because the configured production backend currently uses HTTP, the iOS Info.plist contains a domain-scoped App Transport Security exception for `victoryfairy.duckdns.org`. ATS is not globally disabled.

## Secret Scan Summary

Searches for `gsk_`, `NAVER_CLIENT`, `GROQ_API_KEY`, `X-Naver-Client`, Groq/Naver client strings, and committed `.env` files found no iOS secrets and no committed `.env` files.

## Release Checklist

- Shared schemes exist: `VictoryFairy-Dev`, `VictoryFairy-Production`.
- Debug build is Dev and uses `http://localhost:8081` with simulator fallback `http://127.0.0.1:8081`.
- Release build is Production and uses `http://victoryfairy.duckdns.org`.
- The built Info.plist contains `API_BASE_URL` and `ITSAppUsesNonExemptEncryption = NO`.
- Production display name is `승리요정`.
- Dev display name is `승리요정 Dev`.
- Bundle identifier remains `com.hwangseokbeom.victoryfairy`.
- Marketing version is `1.0.0`.
- Build number is `1`.
- App icon asset catalog uses `AppIcon` and includes a 1024x1024 marketing icon with no alpha channel.
- Permission strings for camera and photo add access are Korean and user-facing.
- Production UI avoids official-data, betting, odds, and development-only wording.
