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

echo "== Native launch =="
# 런치 마크는 Pencil `01_Launch_and_Splash`의 `런치 마크 쿼텟`에서 내보낸 벡터 PDF다.
# 라이트와 다크가 서로 다른 파일인 것은 네거티브 스페이스를 배경색으로 도려내기 때문이다.
launch_set="$repo_root/VictoryFairy/Assets.xcassets/LaunchMark.imageset"
EXPECTED_LAUNCH_LIGHT_SHA="7b73585aa1538d03f68461a34bdcefa89fdc6319997175cf41efb94e76f366df"
EXPECTED_LAUNCH_DARK_SHA="3961018e70d79755433e84f5c361de8b25ee2947c63f421e4b88ec2742a0935e"
RETIRED_VWING_LAUNCH_SHA="2b60eeb3fc21148e5273a014ecf89b2666781183e3897a209ba4049ae5ce3528"

for pair in "LaunchMark.pdf:$EXPECTED_LAUNCH_LIGHT_SHA" "LaunchMark-Dark.pdf:$EXPECTED_LAUNCH_DARK_SHA"; do
  name="${pair%%:*}"; want="${pair##*:}"
  path="$launch_set/$name"
  if [ ! -f "$path" ]; then
    fail "launch mark is missing: $name"
    continue
  fi
  got=$(shasum -a 256 "$path" | awk '{print $1}')
  if [ "$got" != "$want" ]; then
    fail "$name is not the expected quartet launch mark (got ${got:0:16}...)"
  fi
  if [ "$got" = "$RETIRED_VWING_LAUNCH_SHA" ]; then
    fail "$name still carries the retired V-Wing launch mark"
  fi
done

grep -q 'LaunchMark' "$info_plist" || fail "UILaunchScreen no longer references LaunchMark"
grep -q 'LaunchBackground' "$info_plist" || fail "UILaunchScreen no longer references LaunchBackground"
[ -f "$repo_root/VictoryFairy/Assets.xcassets/LaunchBackground.colorset/Contents.json" ] \
  || fail "LaunchBackground colorset is missing"

# 네이티브 런치가 런치 화면의 소유자여야 한다.
#
# `VFBrandMark`가 같은 자산을 쓰는 것은 의도된 공유다 - 온보딩 안의 브랜드 마크가
# 런치 화면과 어긋나지 않게 한다. 금지하는 것은 그것이 아니라 **런치 화면을 흉내 내는
# 가짜 스플래시**다. 그래서 참조가 문서화된 그 한 곳뿐인지를 확인한다.
launch_refs=$(grep -rl '"LaunchMark"' --include='*.swift' "$repo_root/VictoryFairy" 2>/dev/null | sort)
expected_ref="$repo_root/VictoryFairy/SharedComponents/VFStadiumComponents.swift"
if [ "$launch_refs" != "$expected_ref" ]; then
  fail "LaunchMark is referenced outside the shared brand mark: $launch_refs"
fi
for entry in VictoryFairyApp.swift AppRootView.swift; do
  if grep -q 'LaunchMark' "$repo_root/VictoryFairy/$entry" 2>/dev/null; then
    fail "$entry draws the launch asset - that would be a fake splash"
  fi
done
if grep -rn 'struct SplashView\|struct LaunchView\|struct LaunchScreenView' --include='*.swift' "$repo_root/VictoryFairy" >/dev/null 2>&1; then
  fail "a runtime splash view exists - native launch must own the launch screen"
fi
if grep -rnE 'Thread\.sleep|Task\.sleep|asyncAfter' --include='*.swift' "$repo_root/VictoryFairy/VictoryFairyApp.swift" "$repo_root/VictoryFairy/AppRootView.swift" >/dev/null 2>&1; then
  fail "an artificial launch delay exists at app entry"
fi

bash "$repo_root/scripts/verify_app_icon.sh" >/dev/null 2>&1 \
  || fail "app icon verification failed (run scripts/verify_app_icon.sh)"

echo "== Capabilities =="
if grep -Eq 'CODE_SIGN_ENTITLEMENTS|com\.apple\.developer\.associated-domains|aps-environment' "$project_file" "$info_plist"; then
  echo "Review capability output above before archive."
else
  echo "No associated-domain or push entitlement is configured (expected for the current product)."
fi

echo "VictoryFairy Release readiness checks passed."
