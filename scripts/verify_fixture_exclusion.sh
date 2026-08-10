#!/bin/bash
# 화면별 테스트 픽스처가 배포 바이너리에 들어가지 않았는지 확인한다.
#
# 소스에 `#if DEBUG`가 있다는 사실만으로는 부족하다. 조건이 잘못 걸리거나 파일이
# 실수로 다른 타깃에 들어가면 소스는 그대로인데 결과물에는 남는다. 그래서 실제로
# 만들어진 실행 파일을 훑는다.
#
# 현재 검사 대상: 캘린더 픽스처, 시즌 아카이브 픽스처, 기록 상세 픽스처.
#
# 사용법:
#   scripts/verify_fixture_exclusion.sh [<앱 경로 또는 .xcarchive 경로>]
# 인자가 없으면 흔한 위치에서 찾아본다.

set -uo pipefail

# 바이너리에는 UTF-8이 아닌 바이트가 섞여 있다. 로캘을 바이트 단위로 고정하지 않으면
# `sort`가 "Illegal byte sequence"로 실패하고, 빈 목록을 훑느라 모든 검사가 그냥
# 통과해 버린다. 통과처럼 보이지만 아무것도 확인하지 않은 상태가 된다.
export LC_ALL=C

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
failures=0

fail() { echo "${RED}✘${RESET} $1"; failures=$((failures + 1)); }
pass() { echo "${GREEN}✓${RESET} $1"; }

# --- 검사 대상 찾기 ---------------------------------------------------------

target="${1:-}"

if [[ -z "$target" ]]; then
  for candidate in \
    "$(ls -dt /tmp/VictoryFairy-archives/*.xcarchive 2>/dev/null | head -1)" \
    "$(ls -dt "$HOME/Library/Developer/Xcode/Archives"/*/*.xcarchive 2>/dev/null | head -1)"
  do
    if [[ -n "$candidate" && -e "$candidate" ]]; then target="$candidate"; break; fi
  done
fi

if [[ -z "$target" || ! -e "$target" ]]; then
  echo "${RED}검사할 아카이브나 앱을 찾지 못했다.${RESET}"
  echo "사용법: $0 <앱 경로 또는 .xcarchive 경로>"
  exit 2
fi

# .xcarchive를 받으면 그 안의 .app을 찾는다.
if [[ "$target" == *.xcarchive ]]; then
  app=$(ls -d "$target"/Products/Applications/*.app 2>/dev/null | head -1)
else
  app="$target"
fi

if [[ -z "$app" || ! -d "$app" ]]; then
  fail "앱 번들을 찾을 수 없다: $target"
  exit 2
fi

executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist" 2>/dev/null || true)
if [[ -z "$executable" ]]; then
  fail "Info.plist에서 CFBundleExecutable을 읽을 수 없다: $app"
  exit 2
fi
binary="$app/$executable"
if [[ ! -f "$binary" ]]; then
  fail "실행 파일을 찾을 수 없다: $binary"
  exit 2
fi

# 번들 안의 모든 실행 코드를 훑는다. 주 실행 파일만 보면 놓친다 —
# Debug 빌드는 대부분의 코드를 `*.debug.dylib`에 두고 주 실행 파일은 40KB 껍데기다.
# 프레임워크나 실수로 들어간 테스트 번들로 새는 경우도 같은 이유로 잡아야 한다.
# macOS 기본 bash는 3.2라 `mapfile`이 없다. 이식성 있는 형태로 모은다.
machos=()
while IFS= read -r m; do
  # 실제 Mach-O만 남긴다. 이미지나 plist가 섞이면 무의미한 잡음이 늘어난다.
  if file -b "$m" 2>/dev/null | grep -q "Mach-O"; then machos+=("$m"); fi
done < <(find "$app" -type f \( -perm -u+x -o -name '*.dylib' \) 2>/dev/null | sort)
if [[ ${#machos[@]} -eq 0 ]]; then machos=("$binary"); fi

echo "검사 대상: $app"
echo "실행 코드 ${#machos[@]}개:"
for m in "${machos[@]}"; do echo "  - ${m#"$app"/}"; done
echo "빌드 구성: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist" 2>/dev/null || echo '알 수 없음')"
echo

# 문자열을 한 번만 뽑아 재사용한다. 짧은 토큰까지 잡히도록 최소 길이를 낮춘다.
dump=$(mktemp)
symbols=$(mktemp)
trap 'rm -f "$dump" "$symbols"' EXIT

# 정렬하지 않는다 — 이 검사에 필요 없고, 바이너리 바이트에서 실패할 위험만 만든다.
for m in "${machos[@]}"; do
  strings -n 4 -a "$m" >> "$dump" 2>/dev/null
  nm -a "$m" >> "$symbols" 2>/dev/null || true
done

if [[ ! -s "$dump" ]]; then
  echo "${RED}문자열을 하나도 뽑지 못했다. 이 상태로는 어떤 검사도 뜻이 없다.${RESET}"
  exit 2
fi
echo "문자열 $(wc -l < "$dump" | tr -d ' ')줄, 심볼 $(wc -l < "$symbols" | tr -d ' ')줄을 훑는다."

absent() {
  local needle="$1" label="$2"
  if grep -qF -- "$needle" "$dump" || grep -qF -- "$needle" "$symbols"; then
    fail "$label — 배포 바이너리에 '$needle'이 남아 있다"
    grep -F -- "$needle" "$dump" | head -3 | sed 's/^/      /'
  else
    pass "$label"
  fi
}

# --- 1. 픽스처 타입 이름 ----------------------------------------------------

echo "── 픽스처 타입"
absent "VFCalendarFixtures"        "캘린더 픽스처 타입이 없다"
absent "CalendarDesignOnlyStatus"  "디자인 전용 상태 타입이 없다"
absent "CalendarFixture"           "캘린더 시나리오 타입이 없다"
absent "VFStatisticsFixtures"      "시즌 픽스처 타입이 없다"
absent "StatisticsFixture"         "시즌 시나리오 타입이 없다"
absent "VFRecordDetailFixtures"    "기록 상세 픽스처 타입이 없다"
absent "RecordDetailFixture"       "기록 상세 시나리오 타입이 없다"
absent "VFStatesFixtures"           "09_States 픽스처 타입이 없다"
absent "StadiumSheetFixture"        "구장 시트 시나리오 타입이 없다"
absent "MemoryShareFixture"         "추억 카드 시나리오 타입이 없다"

# --- 1b. 마이 화면의 테스트 전용 실행 인자 ----------------------------------
#
# 이 이름들은 결정적 UI 검증에만 쓴다. 런타임 조건으로 동작만 막으면 문자열
# 리터럴은 그대로 배포 바이너리에 실린다 — 실제로 `-VFUITestDisplayName`이
# Release 아카이브에서 발견됐다. 그래서 리터럴 자체가 없는지 본다.

echo
echo "── 마이 화면 테스트 인자"
absent "-VFUITestDisplayName"    "표시 이름 테스트 인자가 없다"
absent "-VFUITestProfileFixture" "마이 픽스처 테스트 인자가 없다"
absent "-VFUITestTeamCatalog"    "팀 목록 테스트 인자가 없다"

# --- 2. 시나리오 이름 -------------------------------------------------------
#
# 'live'나 'scheduled' 같은 흔한 낱말은 쓰지 않는다. 다른 곳에서 정당하게 나올 수
# 있어서 거짓 실패를 만든다. 이 앱에서만 쓰는 형태로만 찾는다.

echo
echo "── 시나리오 이름 (캘린더)"
for scenario in \
  scheduledDesignState liveDesignState postponedDesignState \
  multipleSameDayRecords selectedEmptyDate recoverableError retrySuccess \
  compactReference accessibilityReference yearBoundary \
  lightTeamAccent darkTeamAccent longStadiumName longTeamName
do
  absent "$scenario" "시나리오 '$scenario'가 없다"
done

echo
echo "── 시나리오 이름 (시즌 아카이브)"
#
# 캘린더와 겹치지 않는, 시즌 아카이브에만 있는 이름으로만 확인한다.
# 겹치는 이름은 위에서 이미 걸러졌다.
#
# `insufficientData`는 뺐다. 제품 화면의 접근성 식별자 `statistics.insufficientData`와
# 글자가 겹쳐서, 픽스처가 완전히 빠진 아카이브에서도 걸린다. 제품 코드에서 정당하게
# 나올 수 있는 토큰은 이 검사에 쓸 수 없다 — 거짓 실패만 만든다.
for scenario in \
  referenceSeason multipleSeasons previousSeason oneRecord \
  noStadium noOpponent missingScore winOnly lossOnly drawOnly \
  cancelledOnly mixedResults allStadiums
do
  absent "$scenario" "시나리오 '$scenario'가 없다"
done

echo
echo "── 시나리오 이름 (기록 상세)"
#
# 다른 화면과 겹치지 않고, 제품 코드에서도 나올 수 없는 이름으로만 확인한다.
# `withPhoto`·`withoutPhoto`는 뺐다 — 캘린더의 제품 필터(`CalendarPhotoFilter`)가
# 같은 이름을 쓰므로 픽스처가 완전히 빠진 아카이브에서도 걸린다.
for scenario in \
  referenceRecord missingPhotoFile failedPhotoDecode longNote noNote \
  missingOpponent missingStadium unknownStadium \
  deleteConfirmation deleteSuccess deleteFailure
do
  absent "$scenario" "시나리오 '$scenario'가 없다"
done

echo
echo "── 시나리오 이름 (09_States)"
for scenario in \
  canonicalSelected invalidCurrent allNine unreadablePhoto scored
do
  absent "$scenario" "09_States 시나리오 '$scenario'가 없다"
done

# --- 3. 실행 인자 키 --------------------------------------------------------

echo
echo "── 실행 인자"
absent "-VFUITestCalendarFixture"     "캘린더 픽스처 실행 인자가 없다"
absent "-VFUITestStatisticsFixture"   "시즌 픽스처 실행 인자가 없다"
absent "-VFUITestRecordDetailFixture" "기록 상세 픽스처 실행 인자가 없다"
absent "-VFUITestStadiumSheetFixture"  "구장 시트 픽스처 실행 인자가 없다"
absent "-VFUITestMemoryShareFixture"   "추억 카드 픽스처 실행 인자가 없다"

# --- 4. 고정 ID 접두사와 테스트 전용 미디어 ---------------------------------

echo
echo "── 픽스처 식별자"
absent "CA1E0DA0" "캘린더 픽스처 UUID 접두사가 없다"
absent "57A7DA7A" "시즌 픽스처 UUID 접두사가 없다"
absent "D37A11ED" "기록 상세 픽스처 UUID 접두사가 없다"
absent "09F10000" "추억 카드 픽스처 UUID 접두사가 없다"

echo
echo "── 테스트 전용 사진"
#
# 사진은 번들 리소스가 아니라 메모리에서 그린다. 그래서 확인할 것은 파일이 아니라
# 그 참조 문자열과 그리는 코드가 배포본에 남지 않았는지다.
absent "vf-uitest-inmemory-photo"   "메모리 사진 참조 접두사가 없다"
absent "vf-uitest-missing-photo"    "파일 없음 확인용 참조가 없다"
absent "vf-uitest-undecodable-photo" "디코딩 실패 확인용 참조가 없다"
absent "vf-uitest-states-card-unreadable" "추억 카드 읽기 실패 참조가 없다"

# --- 5. 화면 표식과 디자인 전용 문구 ----------------------------------------

echo
echo "── 화면 표식"
absent "calendar.scenario." "캘린더 픽스처 표식 접두사가 없다"
absent "statistics.scenario." "시즌 픽스처 표식 접두사가 없다"
absent "recordDetail.scenario." "기록 상세 픽스처 표식 접두사가 없다"
absent "stadiumSheet.scenario." "구장 시트 픽스처 표식 접두사가 없다"
absent "memoryShare.scenario." "추억 카드 픽스처 표식 접두사가 없다"
absent "calendar.designStatus." "디자인 전용 상태 식별자가 없다"
absent "경기 예정" "디자인 전용 문구(경기 예정)가 없다"
absent "우천 연기" "디자인 전용 문구(우천 연기)가 없다"

# --- 6. 제품 캘린더는 반드시 남아 있어야 한다 -------------------------------
#
# 위 검사만 있으면 "캘린더를 통째로 빼면 통과"하는 게이트가 된다. 제품 코드가
# 실제로 들어 있는지도 함께 확인해야 이 검사가 뜻을 갖는다.

echo
echo "── 제품 화면 존재 확인"
present() {
  local needle="$1" label="$2"
  if grep -qF -- "$needle" "$dump" || grep -qF -- "$needle" "$symbols"; then
    pass "$label"
  else
    fail "$label — 제품 코드에서 '$needle'을 찾을 수 없다"
  fi
}
#
# 짧은 문자열(15바이트 이하)은 Swift가 코드 안에 즉시값으로 심어서 `strings`에
# 잡히지 않는다. `calendar.day.`나 "의 기억"이 그런 경우다. 없어서가 아니라
# 보이지 않아서 실패하므로, 확인 토큰은 데이터 영역에 남는 길이로만 고른다.
present "CalendarMonth"            "캘린더 달 계산이 들어 있다"
present "calendar.selectedDetail"  "선택일 상세가 들어 있다"
present "calendar.detailAddRecord" "기록 추가 경로가 들어 있다"
present "calendar.previousMonth"   "월 이동이 들어 있다"
present "AttendanceCalendar"       "캘린더 화면이 들어 있다"
present "SeasonArchivePresentation" "시즌 아카이브 계산이 들어 있다"
present "statistics.selectedSeason" "시즌 선택이 들어 있다"
present "statistics.stadiumAnalysis" "구장 분석이 들어 있다"
present "statistics.distribution"  "결과 분포가 들어 있다"
present "SeasonCoverCard"          "시즌 커버가 들어 있다"
present "RecordDetailPresentation" "기록 상세 매핑이 들어 있다"
present "recordDetail.scoreboard"  "스코어보드가 들어 있다"
present "recordDetail.stadium"     "구장 영역이 들어 있다"
present "RecordDetailMediaView"    "사진 영역이 들어 있다"
present "AttendancePostDetailView" "기록 상세 화면이 들어 있다"
# Release 아카이브의 최적화는 사용 중인 Swift 타입명도 제거할 수 있다. 타입명이 아니라
# 실제 제품 경로가 런타임에 소비하는 안정 ID와 접근성/출력 계약을 확인한다.
present "daejeon-hanwha"          "canonical 구장 안정 ID가 들어 있다"
present "StadiumSelectionSheet"    "구장 선택 시트가 들어 있다"
present "stadiumSheet.stadium."    "구장 행 안정 식별자가 들어 있다"
present "MemoryShareCardContent"   "한 기록 추억 카드 모델이 들어 있다"
present "memoryShare.geometry"     "결정적 추억 카드 출력 geometry가 들어 있다"
present "memoryShare.card"         "추억 카드 접근성 계약이 들어 있다"

# --- 결과 ------------------------------------------------------------------

echo
if [[ $failures -eq 0 ]]; then
  echo "${GREEN}통과: 캘린더·시즌·기록 상세 픽스처와 테스트 전용 사진이 배포 바이너리에 없고, 세 제품 화면은 들어 있다.${RESET}"
  exit 0
else
  echo "${RED}실패: $failures건.${RESET}"
  echo "${YELLOW}픽스처가 남았다면 해당 파일의 #if DEBUG 경계와 타깃 소속을 확인한다.${RESET}"
  exit 1
fi
