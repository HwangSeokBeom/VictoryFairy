#!/bin/bash
# VictoryFairy 앱 아이콘 검증.
#
# Pencil `01_Brand_and_AppIcon` 프레임에서 내보낸 아이콘이 실제로 빌드에 들어가는지
# 확인한다. macOS 기본 도구(sips, plutil)만 쓰고 별도 이미지 라이브러리를 넣지 않는다.
#
# 사용: bash scripts/verify_app_icon.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SET="$ROOT/VictoryFairy/Assets.xcassets/AppIcon.appiconset"
CONTENTS="$SET/Contents.json"
PBXPROJ="$ROOT/VictoryFairy.xcodeproj/project.pbxproj"

# 재설계 이전 아이콘의 SHA-256. 이 해시가 다시 나타나면 예전 아이콘이 살아난 것이다.
LEGACY_ICON_SHA="64be923a2f82c4b3a46d2ccfd040a145ed95bd1bb8f76872ac3fba0a08c0b17e"

FAILURES=0
fail() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }
ok()   { echo "  ok: $*"; }

echo "== AppIcon 자산 =="

if [ ! -f "$CONTENTS" ]; then
  fail "Contents.json이 없다: $CONTENTS"
  echo "앱 아이콘 검증 실패 ($FAILURES)"; exit 1
fi

# plutil -lint 는 확장자를 보고 plist로 판단하므로 JSON에는 쓸 수 없다.
# 실제로 파싱시켜서 유효성을 확인한다.
if ! plutil -convert json -o /dev/null "$CONTENTS" >/dev/null 2>&1; then
  fail "Contents.json이 올바른 JSON이 아니다"
else
  ok "Contents.json 형식 정상"
fi

# Contents.json이 참조하는 모든 파일이 실제로 있어야 한다.
FILENAMES=$(plutil -extract images json -o - "$CONTENTS" 2>/dev/null \
  | grep -o '"filename":"[^"]*"' | sed 's/"filename":"//; s/"$//')

if [ -z "$FILENAMES" ]; then
  fail "Contents.json에 이미지 항목이 없다"
fi

for name in $FILENAMES; do
  path="$SET/$name"
  if [ ! -f "$path" ]; then
    fail "Contents.json이 참조하는 파일이 없다: $name"
    continue
  fi
  w=$(sips -g pixelWidth  "$path" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/{print $2}')
  if [ -z "$w" ] || [ -z "$h" ]; then
    fail "$name 을 이미지로 읽을 수 없다(손상 가능)"
    continue
  fi
  if [ "$w" != "1024" ] || [ "$h" != "1024" ]; then
    fail "$name 크기가 ${w}x${h}, 1024x1024 여야 한다"
  else
    ok "$name 1024x1024"
  fi
done

# 기본(Any) 아이콘은 알파 채널이 없어야 App Store 심사를 통과한다.
DEFAULT_ICON="$SET/AppIcon-1024.png"
if [ ! -f "$DEFAULT_ICON" ]; then
  fail "기본 1024 아이콘이 없다: AppIcon-1024.png"
else
  alpha=$(sips -g hasAlpha "$DEFAULT_ICON" 2>/dev/null | awk '/hasAlpha/{print $2}')
  if [ "$alpha" != "no" ]; then
    fail "기본 아이콘에 알파 채널이 있다 (hasAlpha=$alpha)"
  else
    ok "기본 아이콘 불투명(알파 없음)"
  fi

  sha=$(shasum -a 256 "$DEFAULT_ICON" | awk '{print $1}')
  if [ "$sha" = "$LEGACY_ICON_SHA" ]; then
    fail "예전 아이콘이 그대로다 (SHA-256 $LEGACY_ICON_SHA)"
  else
    ok "새 아이콘 적용됨 (SHA-256 ${sha:0:16}...)"
  fi
fi

# Pencil이 제공하는 외형 변형이 모두 있어야 한다.
for variant in AppIcon-1024-Dark.png AppIcon-1024-Tinted.png; do
  if [ ! -f "$SET/$variant" ]; then
    fail "외형 변형이 없다: $variant"
  else
    ok "외형 변형 존재: $variant"
  fi
done

# 예전 다중 크기 파일이 남아 있으면 안 된다.
STALE=$(find "$SET" -name 'AppIcon-*x*@*x.png' -o -name 'AppIcon-1024x1024.png' 2>/dev/null)
if [ -n "$STALE" ]; then
  fail "예전 아이콘 파일이 남아 있다: $(echo "$STALE" | tr '\n' ' ')"
else
  ok "예전 다중 크기 아이콘 파일 없음"
fi

echo "== 빌드 설정 =="

# 모든 구성이 AppIcon 세트를 가리켜야 한다.
NAMES=$(grep -o 'ASSETCATALOG_COMPILER_APPICON_NAME = [^;]*' "$PBXPROJ" | sed 's/.*= //' | sort -u)
if [ -z "$NAMES" ]; then
  fail "ASSETCATALOG_COMPILER_APPICON_NAME 설정이 없다"
elif [ "$NAMES" != "AppIcon" ]; then
  fail "아이콘 세트 이름이 AppIcon이 아니다: $NAMES"
else
  ok "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon (모든 구성 동일)"
fi

# 대체 아이콘이 기본 아이콘을 가로채면 안 된다.
if grep -q 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' "$PBXPROJ"; then
  fail "대체 아이콘 설정이 있다. 기본 아이콘을 덮을 수 있다"
else
  ok "대체 아이콘 설정 없음"
fi

# 아이콘 세트가 하나뿐이어야 한다.
SETS=$(find "$ROOT/VictoryFairy/Assets.xcassets" -name '*.appiconset' -type d | wc -l | tr -d ' ')
if [ "$SETS" != "1" ]; then
  fail "appiconset이 $SETS개다. 하나여야 한다"
else
  ok "appiconset 1개"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "앱 아이콘 검증 실패 ($FAILURES)"
  exit 1
fi
echo "앱 아이콘 검증 통과"
