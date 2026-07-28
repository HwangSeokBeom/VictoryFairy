# Pencil 디자인 구현 기록

VictoryFairy iOS 앱을 Pencil 원본에 맞춰 다시 그린 작업의 결정 사항을 남긴다.
저장소 아키텍처 문서를 대신하지 않으며, 디자인 판단만 다룬다.

## 디자인 원본

- 파일: `/Users/hwangseokbeom/Documents/VictoryFairy.pen` (저장소 밖, 추적하지 않음)
- 열람 방법: Pencil MCP (`get_editor_state`, `get_variables`, `batch_get`, `snapshot_layout`)
- 최상위 프레임 **16개**, 재사용 컴포넌트 **30개**, 문서 변수 **40개**
- `.pen` 파일은 수정하지 않았다.

## 프레임 인벤토리와 매핑

### 실제 화면 (393pt, `clip: true`) — 11개

| Pencil 프레임 | 성격 | 대응 |
| --- | --- | --- |
| 홈 | 전체 화면 | `Features/Home/HomeView.swift` |
| 기록 피드 | 전체 화면 | `Features/Feed/FeedViews.swift` |
| 기록 상세 | 전체 화면 | `AttendancePostDetailView` (토큰 재적용) |
| 캘린더 | 전체 화면 | `Features/Calendar/CalendarViews.swift` |
| 기록 작성 1·2·3단계 | 전체 화면 3개 | `Features/LogEditor/LogEditorView.swift` (단계형 편집) |
| 시즌 아카이브 | 전체 화면 | `Features/Statistics/StatisticsViews.swift` |
| 마이 | 전체 화면 | `Features/Profile/ProfileSettingsView.swift` (`마이` 탭) |
| 온보딩 팀선택 | 전체 화면 | `Features/Onboarding/TeamSelectionView.swift` |
| 스플래시 | 전체 화면 | iOS 런치 스크린이 담당. 별도 SwiftUI 화면을 만들지 않았다. |

### 화면이 아닌 프레임 — 5개

| Pencil 프레임 | 성격 | 대응 |
| --- | --- | --- |
| 일러스트 키트 | 컴포넌트 모음 | `DesignSystem/VFIllustrations.swift` |
| 컴포넌트 시스템 | 컴포넌트 모음 | `SharedComponents/VFCoreComponents.swift` |
| 상태와 피드백 | 상태 변형 모음 (3열) | 빈 상태·로딩·오류·토스트·다이얼로그·바텀시트 컴포넌트 |
| 팀 포인트 컬러 시스템 | 토큰 명세 | `Domain/TeamTheme.swift`의 `VFTeamAccent` |
| 앱 아이콘 | 산출물 명세 | 기존 `AppIcon.appiconset` 유지 |

> 과제 설명은 프레임 약 18개를 예상했지만 실제 문서의 최상위 프레임은 16개다.
> `상태와 피드백` 한 프레임 안에 상태 변형이 여러 개 들어 있어 세는 기준에 따라 달라진다.

## 디자인 토큰

`DesignSystem/VFDesignSystem.swift`에 Pencil 문서 변수를 그대로 옮겼다.

- **배경/표면**: `appBackground`(paper), `elevatedSurface`(surface), `subtleSurface`(cream),
  `highlightSurface`(butter-pale), `translucentSurface`
- **글자**: `bodyPrimary`(ink), `bodySecondary`(ink-soft), `bodyTertiary`(ink-faint), `bodyOnDark`
- **강조**: `primaryAction`(coral), `primaryActionDeep`, `primaryActionPale`, `deepAccent`(navy),
  `supportAccent`(sage), `infoAccent`(sky), `attentionAccent`(butter)
- **선**: `hairline`(line, 1.2pt), `inkOutline`(line-ink, 1.4~1.5pt)
- **경기 결과**: `gameWin`(stamp-red), `gameLoss`(navy), `gameDraw`/`gameCanceled`(ink-faint)
- **간격**: 4 / 8 / 12 / 16 / 20 / 24 / 32, 화면 좌우 여백 16, 섹션 간격 22
- **모서리**: photo 6, sm 10, field 12, md 14, card 16, panel 18, lg 20, sheet 24, pill
- **그림자**: card(blur 8/y2), lifted(14/y5), overlay(22/y8), button(y3)
- **모션**: 탭 전환 0.22s, 선택 0.18s, 로딩 0.9s 주기. 모두 Reduce Motion을 존중한다.

### 타이포그래피

Pencil은 Jua(display) / Gaegu(hand) / Gothic A1(ui)을 쓴다. 세 글꼴 모두 저장소에
라이선스 파일이 없고, 이번 작업에서 폰트 파일을 추가하지 않기로 했다. 시스템 서체의
디자인 변형으로 역할을 대신한다.

- display → `.rounded` 굵게
- hand → `.serif` (일기 같은 개인적인 목소리)
- ui / mono → `.default`, 숫자는 `monospacedDigit()`

모든 역할이 `Font.TextStyle` 기반이라 Dynamic Type을 그대로 따른다.

## 재사용 컴포넌트

`SharedComponents/VFCoreComponents.swift` — 카드, 프라이머리/세컨더리 버튼, 칩,
팀 뱃지, 결과 스탬프, 섹션 헤더, 메타 행, 폼 필드, 토스트, 테이프, 월 구분선,
원형 아이콘 버튼, 빈 상태/로딩/오류 패널.

`SharedComponents/VFRecordComponents.swift` — 홈 폴라로이드 카드, 피드 티켓 기록 카드.

`DesignSystem/VFIllustrations.swift` — 야구공, 페넌트, 반짝, 테이프, 구름, 비구름,
글러브, 티켓, 야간조명. Pencil 벡터를 그대로 옮겼고 SF Symbol로 대체하지 않았다.
`DesignSystem/VFVectorPath.swift`의 작은 SVG 파서가 원본 path 데이터를 그린다.

컴포넌트는 표시용 데이터만 받는다. 팀 이름·스코어·날짜 같은 예시 값을 내부에 넣지
않으며 네트워크나 저장소에 접근하지 않는다.

## 반응형 결정

- 고정 높이를 쓰지 않고 Pencil 값을 **최소 높이**로 둔다. 글자가 커지면 세로로 자란다.
- 기록 카드(티켓)는 접근성 글자 크기에서 가로 티켓 배치로는 잘리므로 **세로 배치로
  전환**한다. 정보는 하나도 숨기지 않는다.
- 홈 시즌 스트립은 `ViewThatFits`로 3칸 가로 → 세로로 접힌다.
- 탭바는 자체 Dynamic Type 범위를 `.large`까지로 묶는다. AccessibilityXXXL에서 다섯
  라벨이 겹치고 잘리는 것을 시뮬레이터 캡처로 확인한 뒤 내린 결정이다. VoiceOver는
  여전히 각 탭의 온전한 이름을 읽고, 화면 본문은 제한 없이 커진다.
- 캘린더 월 이동 버튼은 Pencil이 38pt지만 보이는 원만 38pt로 두고 탭 영역은 44pt다.

## 접근성 결정

- 경기 결과는 **색만으로 구분하지 않는다**. 승·패·무 글자 자체가 구분 수단이라
  Differentiate Without Color에서도 의미가 남는다.
- 팀 뱃지 위 글자색은 상대 휘도 계산으로 정하며 팀마다 테스트로 검증한다.
- 일러스트는 기본적으로 장식이라 VoiceOver에서 숨기고, 의미를 전달해야 할 때만
  라벨을 붙인다.
- 탭·카드·행은 `accessibilityElement`로 묶어 읽는 순서를 정리했다.
- 최소 터치 영역 44pt를 토큰으로 고정하고 테스트로 확인한다.

## Pencil에 없는 상태

Pencil은 이상적인 화면 위주라, 아래는 앱 동작에 맞춰 같은 디자인 언어로 채웠다.

- 오프라인 / 로컬 캐시 사용 중 (`DataStateBanner`의 `localOnly`, `serverErrorUsingLocal`)
- 서버 오류 후 로컬 데이터로 계속 보여주는 상태
- 필터 적용 결과가 0건인 경우 (Pencil `검색 없음` 패널을 재사용)
- 사진 없는 기록 (폴라로이드/티켓 모두 종이 질감으로 채움)
- 통계 데이터 부족 상태

## 의도한 차이

1. **탭 구성 5개.** Pencil `탭바`가 홈/기록/캘린더/시즌/마이를 정의한다. 기존 네
   경로(home·feed·calendar·statistics)는 식별자를 그대로 두고 라벨만 Pencil을 따랐고,
   `마이`는 기존 `ProfileSettingsView`를 홈 시트에서 최상위 탭으로 올린 것이다.
   화면이 사라지지 않았고 오히려 더 쉽게 닿는다.
2. **홈 알림 버튼 없음.** Pencil 홈 헤더에 종 아이콘이 있지만 앱에 알림 화면이 없다.
   동작하지 않는 버튼을 두는 대신 넣지 않았다. 설정은 `마이` 탭이 담당한다.
3. **시즌 커버 문장.** Pencil은 "잠실의 기적을 두 눈으로 본 사람" 같은 감성 문장을
   쓰지만 서버에 그런 필드가 없다. 지어내지 않고 실제 전적으로 문장을 만든다.
4. **lucide → SF Symbols.** Pencil 아이콘은 lucide다. 해당 세트를 앱에 넣지 않고 뜻이
   같은 SF Symbol로 옮겼다. 반면 **일러스트는 앱의 정체성**이라 벡터를 그대로 옮겼다.
5. **글꼴 대체.** 위 타이포그래피 항목 참고.
6. **팀 표현은 로고가 아니라 약칭.** 저장소에 구단 로고 에셋이 없고 Pencil도 약칭
   표기를 쓴다. 한글 팀은 한 글자(삼·두·롯·키·한), 로마자 팀은 약칭 그대로
   (LG·KIA·KT·SSG·NC).
7. **구단 공식 색은 데이터에 그대로 남는다.** 화면 강조색만 Pencil의 채도 낮춘
   팀 포인트 컬러를 쓴다. `KBOTeam.primaryColorHex`는 건드리지 않았다.
8. **다크 모드.** Pencil은 밝은 외형 하나만 정의한다. 추측으로 다크 팔레트를 만들지
   않았다. 아래 남은 과제 참고.

## 남은 과제

- **다크 모드 팔레트가 없다.** Pencil이 다크 변형을 정의하지 않아 이번 작업에서는
  만들지 않았다. 종이 팔레트는 밝은 외형을 전제로 하므로, 다크를 지원하려면 디자인
  원본에 다크 변형이 먼저 필요하다.
- **기록 작성 1·2·3단계**는 기존 `LogEditorView`의 단계 흐름에 토큰만 재적용했다.
  Pencil 3개 프레임의 세부 배치까지 1:1로 맞추지는 않았다.
- **기록 상세 / 마이 / 온보딩 팀선택**도 같은 수준이다. 디자인 언어는 일치하지만
  프레임 단위 재배치는 하지 않았다.
- **스플래시**는 iOS 런치 스크린이 담당한다. Pencil 스플래시의 장식(반짝 요소)은
  런치 스크린 정적 이미지로 옮기지 않았다.
- UI 테스트(XCUITest) 타깃은 아직 없다. 탭 전환을 자동으로 캡처하려면 필요하다.

---

## 갱신 기록 — 최신 Pencil 문서 반영 (진행 중)

이 문서의 위쪽 내용은 **이전 Pencil 문서**를 설명한다. 최신 문서로 바뀐 부분만 아래에 적는다.
아직 전체를 다시 쓰지 않았으므로, 위 내용과 아래 내용이 충돌하면 아래가 맞다.

### 최신 원본

- SHA-256 `04e9f6710479b708705425d5a792149d94a9131371d6dacadf6aadf9d6c49874`
- 935,197 바이트
- 최상위 프레임 22개, 재사용 컴포넌트 49개, 변수 45개

### 커밋 수 정정

이전 보고서는 `20be841` 이후 "새 커밋 5개"라고 적었으나 실제로는 **4개**였다
(`git rev-list --count 20be841..HEAD` = 4): 9fce4be, 27c539b, c82273b, 46dddd2.
이번 패스에서 커밋이 추가되며, 정확한 수는 `git log --oneline 20be841..HEAD`로 확인한다.

### 이번 패스에서 완료

- XCUITest 타깃 `VictoryFairyUITests` 생성, 공유 스킴 Test 액션에 연결
- 탭·화면 루트 접근성 식별자(`tab.*`, `screen.*`)와 온보딩 단계 식별자
- `VFUITestConfiguration` — `-VFUITest` 실행 인자로만 동작하는 테스트 전용 상태 설정
- 내비게이션 UI 테스트 8개 통과(탭 도달, 선택 상태, 탭바 중복 없음, 안전 영역, 좁은 폭, 큰 글자)
- Release 아카이브 생성 및 내용 검증

### Release 아카이브 근거

- 스킴 `VictoryFairy-Production`, 구성 Release, 결과 ARCHIVE SUCCEEDED
- 번들 식별자 `com.hwangseokbeom.victoryfairy`, 마케팅 버전 1.1.0, 빌드 번호 1
- `Assets.car`에 AppIcon 세 가지 렌디션(기본 / UIAppearanceDark / ISAppearanceTintable) 포함
- `LaunchMark`, `LaunchBackground`(라이트·다크) 포함, `UILaunchScreen` 키 유지
- 아이콘·알파 관련 경고 없음
- 배포 서명은 검증하지 않았다(로컬 미서명 아카이브)

### 아직 남은 것

10개 전용 화면(홈·피드·캘린더·시즌·기록 상세·기록 작성 1~3·마이·팀 선택)은 여전히
토큰만 적용된 상태이며 프레임 단위 재구성이 남아 있다. 온보딩 UI 테스트 15개는 결정적
첫 실행 상태를 만들 수 없어 건너뛴 상태다(아래 참고).

### 온보딩 UI 테스트가 건너뛰기인 이유

`-VFUITestReset`은 UserDefaults의 앱 관리 키를 지우지만, 응원 팀이 앱의 프로필/저장소
계층에서 다시 복원된다. 시뮬레이터에서 초기화 후에도 이전 팀이 남고 온보딩이 보완 단계로
시작하는 것을 확인했다. 제대로 고치려면 테스트 훅이 해당 저장소까지 초기화해야 하는데,
이번 작업 범위에서 건드리지 않기로 한 영속성 계층을 수정해야 한다. 실패를 숨기지 않고
`XCTSkip`으로 명시했으며, 통과로 보고하지 않는다.

---

## 홈 — 04_Home_Default_TeamSelected (프레임 단위 구현 완료)

- Pencil 원본 SHA-256 `04e9f6710479b708705425d5a792149d94a9131371d6dacadf6aadf9d6c49874` (변동 없음)
- 이전 상태 **TOKEN_ONLY_MIGRATION** → 최종 상태 **FRAME_LEVEL_IMPLEMENTATION**

### 프레임 → 소스 매핑

- `04_Home_Default_TeamSelected` → `Features/Home/HomeView.swift`
- `TeamIdentityHeader` → `VFTeamIdentityHeader` (SharedComponents/VFHomeComponents.swift)
- `MatchupCard_Expanded` → `VFMatchupHeroCard`
- 매치업 카드 내 `구장 스트립` → `VFStadiumGameStrip`
- `Glyph_HomePlate` → `VFHomePlateGlyph`
- `시즌 스트립` → `VFSeasonStrip`
- `폴라로이드 카드` → 기존 `VFPolaroidCard`
- `기록 CTA` → 기존 `VFPrimaryButton`

순서도 원본을 따른다: 워드마크 → 팀 아이덴티티 헤더 → 매치업 히어로 →
가장 최근의 직관 → 기록 CTA → 시즌 스트립. 그 아래 승리요정 지수와 바로가기는
Pencil에 없지만 이미 있는 기능이라 삭제하지 않고 남겼다.

### 팀 아이덴티티

레일 + 심볼 + 팀명 + "응원 중" 칩이 함께 정체성을 만든다. 색 하나에 기대지 않는다.
`Color.vfOnDarkVariant`가 팀 색을 밝은 쪽으로 유도해 남색 카드 위 대비를 확보하므로,
팀마다 별도 색을 적어두지 않는다. 열 팀 모두 단위 테스트와 UI 테스트로 확인한다.

### 구장 아이덴티티

- **주 관람 구장**: 팀 아이덴티티 헤더 메타("주 관람 대구")와 빈 히어로의 구장 스트립
- **경기 구장**: 히어로의 구장 스트립. 표시 중인 기록이 실제로 열린 곳이다.

둘을 섞지 않는다는 것을 `testRecordStadiumIsNotConflatedWithPrimaryStadium`이 지킨다.
구장 그래픽은 추상 모티프이며 실제 구조물을 그린 것이 아니다. 수용 인원·주소·좌표·
교통·주차·날씨는 만들지 않았다.

### 실제 데이터 편차 (의도한 것)

Pencil 히어로는 "오늘 경기"(상대·시작 시각·선발 투수)를 보여주지만, 홈에는 예정 경기
데이터원이 없다. 유일한 경기 조회는 기록 작성용 후보 검색이라 홈의 데이터원이 아니다.
없는 경기를 지어내지 않고, 히어로 자리에 **실제 최근 직관**을 같은 구성으로 넣었다.
기록이 없으면 팀과 주 관람 구장만 남긴 정직한 빈 히어로를 보여준다.
Pencil 표본 값(원태인·네일·4.16 THU·18:30·삼성 6 : 3 LG·8번)이 제품 코드에 들어가지
않았음을 테스트가 확인한다.

### 상태 범위

개인화 성공, 기록 없음(빈 히어로 + 0 집계), 사진 없는 기록, 긴 한글 팀·구장 이름,
좁은 폭, AccessibilityXXXL. 승/패/무 결과는 히어로 상태 배지와 결과 색으로 구분되며
글자가 함께 있어 색에만 기대지 않는다.

### 접근성

팀 헤더는 접근성 글자 크기에서 세로로 접히고, 팀명·메타·"응원 중"을 자르지 않는다.
장식 벡터(레일·심볼·플레이트)는 VoiceOver에서 숨기고, 카드 단위로 라벨과 값을 준다.
안정 식별자: `home.root`, `home.wordmark`, `home.teamIdentity`, `home.matchupHero`,
`home.gameStadium`, `home.seasonStrip`, `home.recordCTA`, `home.recentRecord`.

### 검증 근거

- 단위 76개 통과(HomeTests 11 포함), UI 20개 통과 + 온보딩 15개 건너뜀
- 캡처: 기본 홈, 밝은 팀 강조색(한화), 어두운 팀 강조색(KT), AccessibilityXXXL,
  좁은 폭(SE 375pt)
- AccessibilityXXXL 캡처에서 팀명 잘림과 칩 붕괴를 발견해 수정한 뒤 재확인
- Debug(Dev)·Release(Production) 빌드, 아이콘·릴리스 게이트 모두 통과

### 남지 않은 것

홈 자체에 남은 과제는 없다. 나머지 아홉 개 전용 화면은 여전히 토큰만 적용된 상태다.

---

## 피드 — 05_Feed_RecordList (프레임 단위 구현 완료)

- Pencil 원본 SHA-256 `04e9f6710479b708705425d5a792149d94a9131371d6dacadf6aadf9d6c49874` (변동 없음)
- 이전 상태 **TOKEN_ONLY_MIGRATION** → 최종 상태 **FRAME_LEVEL_IMPLEMENTATION**

### 프레임 → 소스 매핑

- `05_Feed_RecordList` → `Features/Feed/FeedViews.swift`
- `피드 헤더` → `FeedView.header` (제목 + 요약 + `VFProminentIconButton`)
- `필터 행` → `FeedView.filterRow` (`VFChip` + 시즌 칩)
- `4월 헤더` / `3월 헤더` → `VFMonthDivider(title:romanTitle:)`
- `기록 카드` → `VFRecordCard`
- `스탬프/승·패·무` → `VFResultStamp`
- 로딩·빈 상태·오류 → `VFLoadingPanel` / `VFEmptyStatePanel` / `VFErrorPanel`

### 그룹과 정렬

`date`로 묶는다. 미리 만들어둔 표시 문자열은 쓰지 않는다. 월 키는 `yyyy-MM`,
정렬은 최신 월 → 최신 기록 순이며, 같은 날이면 기록 ID로 순서를 고정한다.
영문 월 라벨은 `en_US_POSIX`로 고정해 기기 언어와 무관하게 같은 값이 나온다.
연도 경계와 같은 날 중복까지 단위 테스트로 확인한다.

### 필터

정체성은 `FeedResultFilter`의 rawValue(all·win·loss·draw·canceled)다.
표시 문구는 Pencil을 따라 전체 / 승리한 날 / 아쉬운 날로 바꿨고, Pencil이 그리지
않은 무·취소는 같은 말투로 비긴 날 / 취소된 날로 확장했다(문구 확장, 범주 추가 아님).
선택 상태는 색뿐 아니라 접근성 선택 특성으로도 드러난다.

### 팀 아이덴티티

매치업 문자열을 `AttendanceMatchup`이 canonical 팀으로 풀어, 상대 팀도 동등하게
읽히도록 유지한다. 결과는 스탬프 글자(승·패·무)가 함께 말하므로 팀 색이나 결과 색
하나에 기대지 않는다.

### 구장 아이덴티티

카드의 구장 줄은 Pencil을 따라 잔디색(`supportAccent`) 세미볼드로 올렸다.
여기 나오는 구장은 **그 기록이 열린 구장**이며 사용자의 주 관람 구장이 아니다.
`testFeedCardShowsRecordStadiumNotPrimaryStadium`이 이를 지킨다.

### 실제 데이터 편차 (의도한 것)

Pencil 표본 기록(9회말 역전·엄마랑 등)은 제품 코드에 넣지 않았고 테스트가 확인한다.
사진이 있는 기록은 픽스처로 만들지 않는다. 사진 파일을 만들면 앱 컨테이너에 지워지지
않는 가짜 데이터가 남기 때문이다. 대신 사진 파일이 없을 때의 자리표시자를 고쳐,
사진 없음과 파일 유실이 같은 모습으로 보이게 했다.

### 상태 범위

채워진 목록, 여러 달, 같은 날 두 건, 연도 경계, 로딩, 기록 없음, 필터 결과 없음,
복구 가능한 오류와 다시 시도, 사진 없음, 긴 메모, 긴 구장 이름, 승·패·무·취소.

### 결정적 UI 테스트 픽스처 경계

`VFFeedFixtures.swift`는 파일 전체가 `#if DEBUG`다. `VFUITestConfiguration.feedLogs`와
`feedState`는 그 블록이 사라지면 인자를 그대로 돌려주므로 제품 대체 데이터가 될 수 없다.
Release 아카이브 바이너리에서 `VFFeedFixtures` 문자열이 **0회** 나오는 것으로 확인했다.
픽스처는 고정 날짜와 시드 UUID만 쓰고 사진 파일을 만들지 않는다.
`-VFUITestInitialTab`으로 특정 탭에서 바로 시작할 수 있게 한 것도 같은 DEBUG 경계 안에 있다.

### 접근성

카드는 하나의 요소로 묶여 날짜·매치업·결과·스코어·구장을 한 문장으로 읽는다.
접근성 글자 크기에서는 카드가 세로 배치로 바뀌어 아무 정보도 자르지 않는다.
장식(절취선·날짜 스텁·사진 영역)은 VoiceOver에서 숨긴다.
안정 식별자: `screen.feed`, `feed.addRecord`, `feed.month.<yyyy-MM>`,
`feed.record.<uuid>`, `feed.loading`, `feed.empty`, `feed.filteredEmpty`, `feed.error`.

### 검증 근거

- 단위 95개 통과(FeedTests 19 포함), UI 42개 통과 + 온보딩 15개 건너뜀
- 캡처 10장: 채워짐, 여러 달, 빈 상태, 오류, 로딩, 긴 구장 이름, 밝은/어두운 팀 강조색,
  AccessibilityXXXL, 좁은 폭(SE 375pt)
- Debug(Dev)·Release(Production) 빌드, 아이콘·릴리스 게이트, Release 아카이브 모두 통과

### 남은 것

사진이 실제로 있는 기록의 캡처는 만들지 않았다. 픽스처가 사진 파일을 쓰지 않기로 한
결정 때문이며, 사진이 있는 레이아웃은 홈 폴라로이드 캡처와 프리뷰로 대신 확인한다.
