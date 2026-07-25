#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="$repo_root/VictoryFairy.xcodeproj/project.pbxproj"
info_plist="$repo_root/VictoryFairy/Info.plist"
environment_file="$repo_root/VictoryFairy/Core/Networking/APIEnvironment.swift"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "== VictoryFairy Release configuration =="
build_settings="$(
  /usr/bin/xcodebuild \
    -project "$repo_root/VictoryFairy.xcodeproj" \
    -scheme VictoryFairy-Production \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -showBuildSettings
)"

grep -Eq 'PRODUCT_BUNDLE_IDENTIFIER = com\.hwangseokbeom\.victoryfairy$' <<<"$build_settings" \
  || fail "unexpected Release bundle identifier"
grep -Eq 'DEVELOPMENT_TEAM = 63SB2B8YJ5$' <<<"$build_settings" \
  || fail "unexpected Apple development team"
grep -Eq 'API_BASE_URL = https://[^[:space:]]+$' <<<"$build_settings" \
  || fail "Release API_BASE_URL must use HTTPS"
grep -Eq 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = .*VICTORYFAIRY_PRODUCTION' <<<"$build_settings" \
  || fail "Production compilation condition is missing"

echo "== Transport security =="
if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSExceptionDomains' "$info_plist" >/dev/null 2>&1; then
  fail "Release plist contains an App Transport Security exception domain"
fi
grep -q 'fallback: "https://victoryfairy.duckdns.org"' "$environment_file" \
  || fail "production fallback is not HTTPS"
if grep -n 'API_BASE_URL = "http://' "$project_file" | grep -v 'localhost' >/dev/null; then
  fail "non-local HTTP API_BASE_URL remains in project settings"
fi

echo "== Capabilities =="
if grep -Eq 'CODE_SIGN_ENTITLEMENTS|com\.apple\.developer\.associated-domains|aps-environment' "$project_file" "$info_plist"; then
  echo "Review capability output above before archive."
else
  echo "No associated-domain or push entitlement is configured (expected for the current product)."
fi

echo "VictoryFairy Release readiness checks passed."
