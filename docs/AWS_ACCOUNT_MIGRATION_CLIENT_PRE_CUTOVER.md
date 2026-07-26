# VictoryFairy iOS: AWS account migration pre-cutover

## Verified client identity

- Xcode project: `VictoryFairy.xcodeproj`
- Production scheme: `VictoryFairy-Production`
- Bundle identifier: `com.hwangseokbeom.victoryfairy`
- Apple team: `63SB2B8YJ5`
- Minimum iOS: 17.0
- Marketing version/build: 1.0.0 (1)
- Current Swift language mode: Swift 5

There is no push-notification entitlement, associated-domain entitlement,
Firebase plist, or custom URL scheme in the current target. Those are not
required by the implemented attendance-recording product.

## Release endpoint contract

Release uses an HTTPS, non-loopback API endpoint. The current value is:

```text
https://victoryfairy.duckdns.org
```

The production environment rejects HTTP and loopback URLs and falls back to the
canonical HTTPS endpoint. Debug remains local on port 8081.

During the AWS account move, preserve the public hostname until the replacement
server passes `/health` and `/ready`. The client does not need a new binary when
only the DNS target changes.

## Pre-cutover verification

Run without uploading:

```bash
scripts/verify_release_readiness.sh

xcodebuild \
  -project VictoryFairy.xcodeproj \
  -scheme VictoryFairy-Production \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/victoryfairy-release-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project VictoryFairy.xcodeproj \
  -scheme VictoryFairy-Production \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/VictoryFairy.xcarchive \
  -derivedDataPath /tmp/victoryfairy-archive-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  archive
```

Unsigned archive validation proves compilation and packaging only. A signed
archive and App Store Connect upload remain explicit post-cutover actions.

## Cutover acceptance

- Replacement server returns 200 from HTTPS `/health`.
- Replacement server returns 200 from HTTPS `/ready` with PostgreSQL available.
- All iOS API paths in `VFRepositories.swift` pass contract smoke tests.
- DNS has not been changed before backup restore and rehearsal are complete.
- No TestFlight/App Store upload occurs until server rollback is proven.
