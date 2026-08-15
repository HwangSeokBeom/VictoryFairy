#!/bin/bash
# VictoryFairy 앱 아이콘 검증.
#
# Pencil `01_AppIcon_VictoryFairies` 보드에서 내보낸 네 페어리 쿼텟 아이콘이 실제로
# 빌드에 들어가는지 확인한다. macOS 기본 도구(sips, plutil, shasum)만 쓰고 별도
# 이미지 라이브러리를 넣지 않는다.
#
# 이 스크립트는 "예전 아이콘이 아님"만 보지 않는다. **지금 실려야 할 아이콘이
# 맞는지**를 해시로 직접 확인한다. 그래야 아이콘이 통째로 빠져도 통과하지 않는다.
#
# 코너 픽셀·전체 출혈 같은 픽셀 단위 검사는 CGImage를 쓸 수 있는
# `AppIconContractTests`가 맡는다. 여기서는 sips가 확실히 답할 수 있는 것만 본다.
#
# 사용: bash scripts/verify_app_icon.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SET="$ROOT/VictoryFairy/Assets.xcassets/AppIcon.appiconset"
CONTENTS="$SET/Contents.json"
PBXPROJ="$ROOT/VictoryFairy.xcodeproj/project.pbxproj"

# 지금 실려야 할 쿼텟 아이콘. Pencil 노드에서 scale 1로 내보내 알파를 없앤 결과다.
#   Default   <- AppIcon_VictoryFairies_Default_1024  (ZCOI9)
#   Dark      <- AppIcon_VictoryFairies_Dark_1024     (NHBAs)
#   Tinted    <- AppIcon_VictoryFairies_Tinted_1024   (nN1Mw)
EXPECTED_DEFAULT_SHA="43323e1a2948fc7e14c8aa4f0f4ad85da3606a410a5a609c582f79d134c0c9b8"
EXPECTED_DARK_SHA="6fde4d723d04def12e96d59da04824f603e2b53c00947364dd79c65c8c4a370d"
EXPECTED_TINTED_SHA="ed4672b6bfc7070d668cda0c2c73ae375def52174bf5fb5b247c904e82d32692"

# 물러난 세대. 이 해시가 다시 나타나면 예전 아이콘이 살아난 것이다.
#   RETIRED_CORAL_SHA  — Pencil 재설계 이전 산호색 아이콘
#   RETIRED_VWING_*    — 쿼텟 직전에 실려 있던 V-Wing 세대
RETIRED_CORAL_SHA="64be923a2f82c4b3a46d2ccfd040a145ed95bd1bb8f76872ac3fba0a08c0b17e"
RETIRED_VWING_DEFAULT_SHA="323baf6d55a97e75ff0b68d125ce2d53ed7174e4da8aa26850c47eb8b75f6507"
RETIRED_VWING_DARK_SHA="9bac8cda2f812b082a07d43adddce2b5c3455321557a3da0c02a0fc4fedc9a50"
RETIRED_VWING_TINTED_SHA="80e31400b494f67d72e25ae35e61c141882afaa45891a0d26ea8dbb798a26fca"

# 자산 카탈로그가 지원하는 렌디션 슬롯은 셋뿐이다.
# 네 번째(Monochrome)를 파일로 넣으면 안 된다 — Pencil의 Monochrome 프레임은
# Icon Composer 레이어 참고용이지 카탈로그 렌디션이 아니다.
EXPECTED_RENDITION_COUNT=3

FAILURES=0
fail() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }
ok()   { echo "  ok: $*"; }

echo "== AppIcon 자산 =="

if [ ! -f "$CONTENTS" ]; then
  fail "Contents.json이 없다: $CONTENTS"
  echo "앱 아이콘 검증 실패 ($FAILURES)"; exit 1
fi

# plutil -lint 는 확장자를 보고 plist로 판단하므로 JSON에는 쓸 수 없다.
if ! plutil -convert json -o /dev/null "$CONTENTS" >/dev/null 2>&1; then
  fail "Contents.json이 올바른 JSON이 아니다"
else
  ok "Contents.json 형식 정상"
fi

IMAGES_JSON=$(plutil -extract images json -o - "$CONTENTS" 2>/dev/null)
FILENAMES=$(echo "$IMAGES_JSON" | grep -o '"filename":"[^"]*"' | sed 's/"filename":"//; s/"$//')

if [ -z "$FILENAMES" ]; then
  fail "Contents.json에 이미지 항목이 없다"
fi

# 렌디션 수가 정확히 셋이어야 한다.
COUNT=$(echo "$FILENAMES" | grep -c .)
if [ "$COUNT" != "$EXPECTED_RENDITION_COUNT" ]; then
  fail "렌디션이 ${COUNT}개다. ${EXPECTED_RENDITION_COUNT}개여야 한다 (지원되지 않는 네 번째 렌디션 금지)"
else
  ok "렌디션 ${EXPECTED_RENDITION_COUNT}개"
fi

# 파일 이름이 정확히 기대한 셋이어야 한다.
EXPECTED_NAMES=$'AppIcon-1024-Dark.png\nAppIcon-1024-Tinted.png\nAppIcon-1024.png'
ACTUAL_NAMES=$(echo "$FILENAMES" | sort)
if [ "$ACTUAL_NAMES" != "$EXPECTED_NAMES" ]; then
  fail "렌디션 파일 이름이 다르다: $(echo "$ACTUAL_NAMES" | tr '\n' ' ')"
else
  ok "렌디션 파일 이름 정상"
fi

# 외형 매핑이 정확해야 한다.
if echo "$IMAGES_JSON" | grep -q '"value":"dark"'; then
  ok "dark 외형 매핑 존재"
else
  fail "dark 외형 매핑이 없다"
fi
if echo "$IMAGES_JSON" | grep -q '"value":"tinted"'; then
  ok "tinted 외형 매핑 존재"
else
  fail "tinted 외형 매핑이 없다"
fi

# Contents.json이 참조하는 모든 파일이 실제로 있고 1024x1024여야 한다.
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

  # 셋 다 알파가 없어야 한다. 알파가 없다는 것은 곧 바깥 투명 여백도,
  # 투명하게 깎인 라운드 코너도 없다는 뜻이다.
  alpha=$(sips -g hasAlpha "$path" 2>/dev/null | awk '/hasAlpha/{print $2}')
  if [ "$alpha" != "no" ]; then
    fail "$name 에 알파 채널이 있다 (hasAlpha=$alpha) — 투명 여백·라운드 코너 위험"
  else
    ok "$name 불투명(알파 없음 = 외부 투명 여백 없음)"
  fi
done

# 카탈로그가 참조하지 않는 아이콘 파일이 세트에 남아 있으면 안 된다.
ORPHANS=""
while IFS= read -r f; do
  base="$(basename "$f")"
  if ! echo "$FILENAMES" | grep -qx "$base"; then
    ORPHANS="$ORPHANS $base"
  fi
done < <(find "$SET" -maxdepth 1 -name '*.png' -type f)
if [ -n "$ORPHANS" ]; then
  fail "카탈로그가 참조하지 않는 아이콘 파일이 있다:$ORPHANS"
else
  ok "참조되지 않는 아이콘 파일 없음"
fi

echo "== 쿼텟 아이덴티티 =="

check_sha() {
  local label="$1" name="$2" expected="$3"
  local path="$SET/$name"
  if [ ! -f "$path" ]; then
    fail "$label 파일이 없다: $name"
    return
  fi
  local sha
  sha=$(shasum -a 256 "$path" | awk '{print $1}')
  if [ "$sha" = "$expected" ]; then
    ok "$label 쿼텟 아이콘 일치 (${sha:0:16}...)"
  else
    fail "$label 이 기대한 쿼텟 아이콘이 아니다. got ${sha:0:16}... want ${expected:0:16}..."
  fi
}

check_sha "Default" "AppIcon-1024.png"        "$EXPECTED_DEFAULT_SHA"
check_sha "Dark"    "AppIcon-1024-Dark.png"   "$EXPECTED_DARK_SHA"
check_sha "Tinted"  "AppIcon-1024-Tinted.png" "$EXPECTED_TINTED_SHA"

# 물러난 세대가 어느 렌디션에도 남아 있으면 안 된다.
RETIRED_FOUND=""
for f in "$SET"/*.png; do
  [ -f "$f" ] || continue
  sha=$(shasum -a 256 "$f" | awk '{print $1}')
  case "$sha" in
    "$RETIRED_CORAL_SHA"|"$RETIRED_VWING_DEFAULT_SHA"|"$RETIRED_VWING_DARK_SHA"|"$RETIRED_VWING_TINTED_SHA")
      RETIRED_FOUND="$RETIRED_FOUND $(basename "$f")"
      ;;
  esac
done
if [ -n "$RETIRED_FOUND" ]; then
  fail "물러난 아이콘 세대가 살아 있다:$RETIRED_FOUND"
else
  ok "물러난 산호색·V-Wing 세대 없음"
fi

# 세 렌디션이 서로 달라야 한다. Dark가 Default를 그대로 베끼면 안 된다.
D=$(shasum -a 256 "$SET/AppIcon-1024.png" 2>/dev/null | awk '{print $1}')
K=$(shasum -a 256 "$SET/AppIcon-1024-Dark.png" 2>/dev/null | awk '{print $1}')
T=$(shasum -a 256 "$SET/AppIcon-1024-Tinted.png" 2>/dev/null | awk '{print $1}')
if [ "$D" = "$K" ] || [ "$D" = "$T" ] || [ "$K" = "$T" ]; then
  fail "두 렌디션이 같은 파일이다. Pencil은 셋을 다르게 그렸다"
else
  ok "세 렌디션이 서로 다르다"
fi

# 예전 다중 크기 파일이 남아 있으면 안 된다.
STALE=$(find "$SET" -name 'AppIcon-*x*@*x.png' -o -name 'AppIcon-1024x1024.png' 2>/dev/null)
if [ -n "$STALE" ]; then
  fail "예전 아이콘 파일이 남아 있다: $(echo "$STALE" | tr '\n' ' ')"
else
  ok "예전 다중 크기 아이콘 파일 없음"
fi

echo "== 빌드 설정 =="

NAMES=$(grep -o 'ASSETCATALOG_COMPILER_APPICON_NAME = [^;]*' "$PBXPROJ" | sed 's/.*= //' | sort -u)
if [ -z "$NAMES" ]; then
  fail "ASSETCATALOG_COMPILER_APPICON_NAME 설정이 없다"
elif [ "$NAMES" != "AppIcon" ]; then
  fail "아이콘 세트 이름이 AppIcon이 아니다: $NAMES"
else
  ok "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon (모든 구성 동일)"
fi

if grep -q 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' "$PBXPROJ"; then
  fail "대체 아이콘 설정이 있다. 기본 아이콘을 덮을 수 있다"
else
  ok "대체 아이콘 설정 없음"
fi

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
