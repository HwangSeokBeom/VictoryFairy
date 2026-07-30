# Pencil 디자인 구현 기록

VictoryFairy iOS 앱을 Pencil 원본에 맞춰 다시 그린 작업의 결정 사항을 남긴다.
저장소 아키텍처 문서를 대신하지 않으며, 디자인 판단만 다룬다.

## 디자인 원본

- 파일: `/Users/hwangseokbeom/Documents/VictoryFairy.pen` (저장소 밖, 추적하지 않음)
- 열람 방법: Pencil MCP — `get_app_state`(문서·스키마), `execute`의 `GetVariables`/`Get`
  (변수와 노드 트리, `ctx.bounds`로 배치 확인), `get_screenshot`(시각 확인).
  `get_editor_state`·`get_variables`·`batch_get`·`snapshot_layout`은 **이 서버에 없는
  이름이다.** 그 이름으로 부르면 "No handler found for method"가 나고, MCP가 고장난 것으로
  오인하기 쉽다.
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

---

## 캘린더 — 06_Calendar_Month_GameSelected (부분 구현)

- Pencil 원본 SHA-256 `04e9f6710479b708705425d5a792149d94a9131371d6dacadf6aadf9d6c49874` (변동 없음)
- 이전 상태 **TOKEN_ONLY_MIGRATION** → 현재 상태 **PARTIAL** (프레임 단위 완료 아님)

### 이번 패스에서 완료

- `Domain/CalendarMonth.swift` — 달 기하 구조를 뷰에서 꺼내 순수 계산으로 옮겼다.
  기준 달력을 그레고리력 / Asia/Seoul / 일요일 시작으로 **명시**한다. 이전에는
  `Calendar.current`를 써서 기기 시간대에 따라 격자가 달라질 수 있었다.
- 주 단위로 떨어지는 격자, 자정 정규화, 앞뒤 달 실제 날짜 채움
- `month(byAdding:)` — 항상 1일로 정규화해 반복 이동이 어긋나지 않는다
- `clampedSelection(day:in:)` — 31일 선택 후 30일까지인 달로 가면 30일로 당긴다.
  조용히 다음 달로 넘어가지 않는다
- 요일 라벨을 로캘에서 가져온다(하드코딩 배열 제거)
- 헤더를 Pencil 구성으로: 달 자체가 화면 제목(+월 선택 chevron), 아래 월 요약,
  오른쪽 원형 이전/다음 버튼. 달 이동 연산을 버튼 클로저에서 빼 한 곳으로 모았다
- 범례를 Pencil 4개 항목으로: 승리한 직관 / 아쉬운 직관 / 무승부 / 홈구장(플레이트 글리프).
  큰 글자에서도 닿도록 가로 스크롤
- 단위 테스트 22개

### 의도한 편차

Pencil 캘린더는 승리 점을 금색(`gold`)으로 그리지만, 금색은 이미 **선택된 날 원의 채움색**
이자 브랜드 액션 색이다. 결과 색과 선택 상태 색이 겹치면 구분이 무너지므로,
승/패/무 점은 앱 전체가 쓰는 `gameWin`/`gameLoss`/`gameDraw` 토큰을 유지했다.
범례 색도 같은 토큰에서 나온다.

### 이어진 패스에서 추가로 완료

- 선택일 미리보기를 Pencil 구성으로 재배치: `VFSectionHeader` + `VFRecordCard`.
  피드와 같은 카드를 쓰므로 팀·구장 표현이 앱 전체에서 일치한다
- `CalendarSelectedDatePresentation` — 선택일 표시용 의미 모델.
  같은 날 기록을 하나도 버리지 않고 모두 들고 있으면서 대표 하나를 결정적으로 고르고,
  전체 개수를 접근성으로 알린다
- 카드가 보여주는 구장은 **기록의 구장**이다. 사용자의 주 관람 구장으로 대체하지 않는다
- 기록이 없는 날은 경기를 지어내지 않고 정직한 빈 패널 + 기존 기록 추가 경로
- Pencil "자세히"가 `navigationDestination`으로 실제 기록 상세를 연다
  (이전에는 아무도 읽지 않는 상태만 세팅하는 죽은 동작이었다)

### 아직 남은 것 (프레임 단위 완료 아님)

- 예정·진행 중·연기 등 결과 이전 상태의 마커 의미(제품에 데이터원 없음)
- 캘린더 전용 결정적 UI 테스트 픽스처
- 캘린더 XCUITest
- 캘린더 좁은 폭 / AccessibilityXXXL 확인
- 캘린더 캡처 매트릭스(26장 중 2장만 확보)
- 앱 타깃 파일 추가 이후 Release 아카이브 재확인

### 캘린더 — 결정적 픽스처와 디자인 전용 상태 (검증 패스)

- `Services/VFCalendarFixtures.swift` — 시나리오 22개. 파일 전체가 `#if DEBUG`다.
  고정 Asia/Seoul 날짜와 시드 UUID만 쓰고, SwiftData에 쓰지 않으며 사진 파일도 만들지
  않는다. 반복 실행해도 시뮬레이터에 흔적이 남지 않는다.
- `VFUITestConfiguration`에 `calendarLogs` / `calendarMonth` / `calendarState` /
  `calendarPreselectedDate` 이음새를 추가했다. DEBUG 블록이 사라지면 인자를 그대로
  돌려주므로 제품 대체 데이터가 될 수 없다.
- **디자인 전용 상태**: 예정·진행 중·연기는 제품에 데이터원이 없다.
  `CalendarDesignOnlyStatus`로만 존재하며 DEBUG 픽스처를 통해서만 그려진다.
  제품의 `GameResult`에서는 나올 수 없고, 시각으로 추론하지도 않는다.
- **픽스처 활성화 표식**: 화면에 `calendar.scenario.<이름>` 요소를 심어, 요청한 픽스처가
  조용히 제품 상태로 되돌아갔는지 UI 테스트가 화면에서 확인할 수 있게 했다.
  (온보딩에서 실행 인자만 믿었다가 놓쳤던 실패 방식을 막기 위한 것이다.)

### 캘린더 — 이 패스에서 고친 결함

모두 재현 → 원인 → 최소 수정 → 회귀 검사 순으로 처리했다. 절반은 **캡처를 눈으로 보고**
발견했다. 빌드와 테스트는 통과하고 있었다.

1. **선택일 상세를 시트가 덮었다.** 날짜를 고르면 `selectedDay`가 `.sheet(item:)`도 함께
   열어 Pencil 인라인 상세를 가렸다. 인라인 상세가 구현된 지금 그 시트는 역할이 겹치므로
   자동 표시와 도달 불가능해진 `CalendarDayDetailSheet`를 함께 제거했다.
2. **픽스처 표식을 찾을 수 없었다.** `accessibilityHidden(true)`를 붙여 접근성 트리에서
   통째로 빠져 있었다. 캘린더 UI 테스트 37개가 모두 같은 이유로 실패해 드러났다.
3. **화면이 기기 달력을 썼다.** 날짜 숫자·요일·기록 묶기·월 선택기가 `Calendar.current`를
   썼다. 기기 시간대가 다르면 Asia/Seoul 자정으로 정규화한 날짜에 다른 숫자가 찍힐 수
   있다. 도메인이 이미 계산해 둔 `day.day`·`day.isSunday`를 쓰고 나머지는 기준 달력으로
   옮겼다. 화면과 도메인 양쪽에서 `Calendar.current`를 금지하는 검사를 함께 넣었다.
4. **오류에서 빠져나올 방법이 없었다.** 문구만 띄우고 다시 시도할 방법이 없었다. 피드와
   같은 `VFErrorPanel`을 붙였다. 다시 시도해도 보고 있던 달·고른 날짜·보기 모드는 그대로다.
5. **컨테이너 식별자가 자식 식별자를 덮어썼다.** 평범한 `VStack`에 식별자만 얹으면
   SwiftUI가 그 값을 자식들에게 내려보낸다. 그래서 기록 카드가 `calendar.detailRecord`가
   아니라 `calendar.selectedDetail`을 달고 있었고, 안쪽 식별자가 전부 사라졌다.
   `accessibilityElement(children: .contain)`으로 먼저 담는 요소를 만든 뒤 이름을 붙인다.
6. **픽스처가 달 이동을 막았다.** 달을 화면 그릴 때마다 픽스처 값으로 덮어써서, 화살표를
   눌러도 곧바로 되돌아왔다. 픽스처는 이제 **시작 달만** 정하고 그 뒤는 제품 경로 그대로다.
7. **큰 글자에서 날짜가 "…"로 잘렸다.** AccessibilityXXXL에서 두 자리 날짜가 모두 잘려
   달력을 읽을 수 없었다. 일곱 칸 고정 격자이므로 **날짜 숫자에만** 상한을 두고
   (`accessibility1`), `minimumScaleFactor`를 0.9로 올려 잘림 대신 크기를 지켰다.
   요약·범례·선택일 상세는 제한 없이 그대로 커진다. 보기 모드 줄은 큰 글자에서 가로로
   밀어 볼 수 있게 해, 이름을 줄여 자르지 않는다.
8. **큰 글자 검증이 사실은 보통 크기를 검사하고 있었다.** 실행 인자 값을
   `UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`로 적었는데 실제 값은
   `UICTContentSizeCategoryAccessibilityXXXL`이다. 앱은 조용히 기본 크기로 떴고 여덟 개
   검사가 모두 통과했다. 캡처를 보고 알아챘다. 지금은 월 제목 높이를 재서 큰 글자가
   정말 적용됐는지 확인한 뒤에야 다음 단언으로 넘어간다.
9. **아카이브 검사가 아무것도 검사하지 않고 통과했다.** 바이너리에 UTF-8이 아닌 바이트가
   섞여 `sort`가 실패했고, 빈 목록을 훑느라 모든 항목이 "없음"으로 통과했다. 로캘을
   바이트 단위로 고정하고, 제품 캘린더가 **있는지**도 함께 확인하도록 바꿨다.

### 캘린더 — 검증 범위

- 단위·거버넌스: `CalendarTests`(22) · `CalendarFixtureGovernanceTests`(30) ·
  `CalendarDaySemanticsTests`(12)
- UI: `CalendarUITests`(38) — 픽스처 활성화, 루트와 쉘, 날짜 기하, 선택 의미, 기록과
  정체성, 결과·디자인 전용 상태, 데이터 상태와 재시도, 이동 경로
- 반응형: `CalendarResponsiveUITests`(15) — 좁은 폭 기하 7개(iPhone SE 3세대) +
  AccessibilityXXXL 8개
- 캡처 도구: `CalendarCaptureUITests`(9) — 조작이 필요한 상태의 증거를 남긴다

좁은 폭 검사는 375pt급 기기에서만 뜻이 있으므로, 넓은 기기에서 돌면 통과로 위장하지 않고
건너뛴다고 명시적으로 알린다. 큰 글자 검사도 같은 이유로 적용 여부를 먼저 확인한다.

### 캘린더 — Release 격리 증명

소스의 `#if DEBUG`는 필요하지만 충분하지 않다. 조건이 잘못 걸리거나 파일이 다른 타깃에
들어가면 소스는 그대로인데 결과물에는 남는다. `scripts/verify_fixture_exclusion.sh`가
아카이브 안의 **모든 실행 코드**를 훑어 확인한다. 주 실행 파일만 보면 놓친다 — Debug
빌드는 대부분의 코드를 `*.debug.dylib`에 두고 주 실행 파일은 40KB 껍데기다.

- 픽스처 타입 이름, 시나리오 이름, 실행 인자 키, 고정 UUID 접두사, 화면 표식 접두사,
  디자인 전용 문구가 **없을 것**
- `CalendarMonth`, `calendar.selectedDetail`, `calendar.detailAddRecord`,
  `calendar.previousMonth`, `AttendanceCalendar`가 **있을 것**

뒤쪽 확인이 없으면 "캘린더를 통째로 빼면 통과"하는 게이트가 된다. `live`·`scheduled` 같은
흔한 낱말은 쓰지 않는다. 다른 곳에서 정당하게 나올 수 있어 거짓 실패를 만든다.

확인 토큰은 15바이트를 넘는 것만 고른다. 짧은 문자열은 Swift가 코드 안에 즉시값으로 심어
`strings`에 잡히지 않는다. 없어서가 아니라 보이지 않아서 실패한다.

이 게이트는 양쪽으로 확인했다. Release 아카이브에서는 통과하고, 픽스처가 실제로 들어 있는
Debug 번들에서는 실패한다. 한쪽만 확인하면 "아무것도 못 찾는 검사"와 구분되지 않는다.

### 온보딩 건너뛴 검사 — 분류 정정

예전 사유는 사실이 아니었다. "`-VFUITestReset`이 UserDefaults만 지우고 응원 팀은
프로필/저장소 계층에서 되살아난다"고 적어 두었는데, 실제로 팀과 완료 플래그를 심어 저장한
뒤 초기화하고 다시 띄우니 온보딩 첫 화면이 정상으로 나온다. **초기화는 동작한다.**

진짜 이유는 열세 개가 재설계 **이전** 흐름(환영 → 소개 → 팀)을 전제로 쓰여 있고
`onboarding.overview.next` 같은 식별자를 찾는다는 것이다. 재설계된 온보딩은 쪽 넘김 소개
화면이라 그 단계가 없다. 되살리려면 새 흐름에 맞춘 재작성이 필요하고, 그것은 캘린더
마무리가 아니라 온보딩 작업이다.

새 흐름에서도 뜻이 통하는 두 개(test10, test13)는 건너뛰지 않고 계속 돌린다. 통째로
건너뛰면 실제로 지켜지고 있는 것까지 확인을 멈추게 된다.

---

## 시즌 아카이브 — 07_Statistics_SeasonArchive (프레임 단위 구현 완료)

- Pencil 원본 SHA-256 `9b5af6aee3ed8cc72383d4d465dae2b62e75462dc5da3507d22f5f5055bb1a4a`
- 935,281 바이트 · 최상위 프레임 22개 · 재사용 컴포넌트 49개 · 문서 변수 46개
- 이전 상태 **TOKEN_ONLY_MIGRATION** → 최종 상태 **FRAME_LEVEL_IMPLEMENTATION**
- 프레임 노드 `N9cSUg`, 393×1197

### Pencil 원본 변화 — STATISTICS_ONLY_DELTA

캘린더 작업 시점의 원본은 `04e9f671…c49874` / 935,197바이트 / 변수 45개였다. 지금은
`9b5af6ae…5b1a4a` / 935,281바이트 / 변수 46개다. 컴포넌트 수(49)와 최상위 프레임 수(22)는
그대로이고, 늘어난 것은 **문서 변수 하나와 84바이트**뿐이다.

문서 변수 46개의 값을 `VFDesignSystem`과 하나씩 대조했다. paper·ink·line·navy·butter·
coral·sage·gold·live·win·night 계열, 반경(10/14/20), 간격(4/8/16/24), 팀 10색까지 전부
이미 구현된 토큰과 **값이 같다**. 값이 바뀐 변수가 없으므로 완성된 홈·피드·캘린더가
이번 변화로 다시 칠해질 일이 없다. 시즌 아카이브 프레임이 쓰는 변수도 모두 기존 토큰에
대응된다. 따라서 이번 변화는 **STATISTICS_ONLY_DELTA**로 분류한다.

프레임이 쓰는 값 가운데 토큰이 없던 것은 리터럴 두 개뿐이라 **덧붙이기만** 했다.
공유 토큰의 값은 하나도 바꾸지 않았다.

- `bodyOnDarkSecondary` `#8FAEC6` — 남색 커버 위의 보조 글자
- `chartEmptyMark` `#A59C8C` 25% — 기록이 없는 달의 빈 점
- `VFTypography.numericDisplay` — Pencil font-mono 48/700 자리. 고정 48pt 대신
  `largeTitle` 역할이라 Dynamic Type을 그대로 따른다

### 프레임 → 소스 매핑

| Pencil 노드 | 화면 | 실제 데이터원 |
| --- | --- | --- |
| `시즌 헤더` / `화면 제목` | `StatisticsView.seasonHeader` | 고른 시즌 |
| `시즌 부제` | 같은 곳 | 직관 횟수 + 실제 구장 수 |
| `시즌 선택` | `seasonSelector` + `SeasonPickerSheet` | `AppDataStore.availableSeasons` |
| `시즌 커버` | `SeasonCoverCard` | 시즌 전적 |
| `커버 라벨` + 팀 표시 | `SeasonCoverCard.eyebrow` | `UserPreferencesStore.favoriteTeamID` |
| `커버 문장` | `SeasonHeadline` | 실제 승·패·무·취소 |
| `승률` `.625` | `SeasonRecord.winRateText` | 승 ÷ 승패 |
| `커버 전적` | `SeasonRecord.recordText` | 결과별 집계 |
| `커버 반짝` | `VFIllustrationView(.sparkle)` | 장식 |
| `사진 콜라주` | — | 구현하지 않음(아래 참고) |
| `시즌 기록 섹션` | `highlightsSection` | 네 줄 모두 실제 기록 |
| `가장 많이 간 구장` | `SeasonHighlight.mostVisitedStadium` | 기록에 남은 구장 |
| `가장 많이 만난 상대` | `.mostFacedOpponent` | `AttendanceMatchup` |
| `올해의 순간` | `.largestWinMargin`으로 대체 | 실제 점수 |
| `최다 연승` | `.longestWinStreak` | 승패 순서 |
| `타임라인 섹션` | `SeasonTrendChart` | 월별 직관 횟수 |
| `리포트 공유` | `ShareCardPreviewView(seasonWinRateText:)` | 계산된 승률 |
| — | `SeasonResultDistributionView` | 결과별 집계(추가) |
| — | `stadiumSection` | 실제 구장 순위(추가) |
| — | `KBOStandingsView` | 서버 순위표(기존 기능 보존) |

### 계산 소유권

`StatisticsService`는 Foundation만 쓰는 순수 계산 계층으로 남아 있다. 뷰 본문에서
계산하던 것을 모두 옮겼다.

- 문장 생성 · 합계 · 승률 · 취소 처리 규칙 · 결과 분포 · 월별 흐름 · 구장 정렬과 집계 ·
  연승 · 최다 점수 차 · 시즌 발견과 정렬 · 차트 요약

화면은 `SeasonArchivePresentation` 하나를 받아 그리기만 한다. `StatisticsViewModel`은
뷰가 아니므로 화면 없이도 같은 값을 만들 수 있고, 그래서 계산을 전부 단위 테스트로
검증할 수 있다. DI 프레임워크나 유스케이스 계층은 도입하지 않았다.

### 승률 분모 규칙

**승률 = 승 ÷ (승 + 패).** 무승부와 취소 경기는 분모에 넣지 않는다.

- 이 규칙은 앱이 이미 쓰던 것과 같다(`StatisticsService.summary`의 `decided`,
  `StatisticsMapper`). 새로 만든 규칙이 아니라 기존 제품 규칙을 명시화했다.
- 취소는 경기가 열리지 않은 것이고 무승부는 승패가 갈리지 않은 것이라, 둘 다 "이길 수
  있었던 경기"가 아니다.
- 승패가 하나도 없으면 0%가 아니라 **값 자체가 없다**(`—`). 0%는 "다 졌다"는 뜻이라
  거짓말이 된다.
- 취소·무승부는 **직관 횟수**에는 그대로 들어간다. 간 것은 사실이다.
- 표기는 야구 관례를 따른다. 소수 셋째 자리, 앞의 0을 뗀 `.714`. VoiceOver는 숫자를
  그대로 읽으면 알아듣기 어려우므로 "승률 71.4퍼센트, 5승 2패 기준"으로 풀어 읽고,
  화면에 찍힌 `.714`는 접근성 **값**으로 남겨 자동 검증이 가능하게 했다.

### 의도한 편차

1. **`.625`를 옮기지 않았다.** Pencil은 `8경기 · 5승 2패 1무` 옆에 `.625`를 적어 두었지만
   자기 전적으로 계산하면 5÷7 = `.714`다. 표본 값이라 규칙대로 다시 계산한다.
2. **커버 문장을 만들어 쓴다.** "잠실의 기적을 두 눈으로 본 사람"은 사람이 쓴 예시다.
   그런 문장을 주는 필드가 서버에도 기기에도 없다. 실제 숫자와 실제 구장 이름만으로
   여덟 갈래의 결정적 문장을 만든다. 같은 기록에서는 언제나 같은 문장이 나온다.
3. **`올해의 순간`을 `가장 크게 이긴 날`로 바꿨다.** "박병호의 9회 역전 스리런"을 만들려면
   선수·이닝·타구 데이터가 필요한데 이 앱에는 없다. 지어내지 않고, 실제 점수로 확인할 수
   있는 최다 점수 차 승리로 **구조가 같은 자리**를 채운다. 점수가 없으면 값을 만들지 않고
   "점수가 적힌 승리가 아직 없어요"로 남긴다.
4. **타임라인 기간이 다르다.** Pencil은 3월~9월 일곱 칸을 고정으로 그리지만, 이 앱에는
   시즌이 언제 시작하고 끝나는지 알려 주는 데이터원이 없다. 없는 기간을 만들어 내지 않고
   **첫 기록이 있는 달부터 마지막 기록이 있는 달까지**를 그린다. 그 사이의 빈 달은 Pencil과
   같은 빈 점으로 남아 시즌의 모양이 그대로 보인다.
5. **사진 콜라주를 넣지 않았다.** Pencil은 Unsplash 사진 세 장을 붙여 두었다. 제품에는
   시즌 대표 사진을 고르는 규칙도, 기록 사진을 가져오는 경로도 없다(피드 사진 과제와 같은
   미해결 항목). 남의 사진을 제품에 심지 않고 자리를 비웠다.
6. **결과 분포와 구장 순위를 더했다.** Pencil 프레임에는 없지만 과제가 요구하는 값이고,
   둘 다 실제 집계에서 나온다. 도넛 대신 **라벨이 붙은 가로 막대**를 쓴다. 색만으로
   뜻을 전하지 않도록 승·패·무·취소 네 항목을 0이어도 모두 적는다.
7. **리그 순위표를 별도 화면으로 옮겼다.** 이전 화면은 `KBO 현재 / 내 직관` 두 구획을
   탭으로 갈랐다. Pencil 시즌 아카이브는 순수하게 개인 아카이브라 순위표가 없다. 기능을
   지우는 대신 아카이브 맨 아래 한 줄에서 `KBOStandingsView`로 이어지게 했다.
8. **`SeasonStatsView`를 지웠다.** 어디서도 열리지 않는 화면인데 `7승 4패 1무`,
   `잠실 8회`, `KIA 4회` 같은 값이 소스에 박혀 있었다. 제품에 표본 통계가 남아 있을
   이유가 없다.
9. **섹션 헤더의 "전체 보기"는 두지 않았다.** Pencil도 비활성으로 그렸고, 구장 목록은
   상위 몇 개로 자르지 않고 전부 보여주므로 더 볼 것이 없다. 대신 `가장 많이 간 구장`과
   `가장 많이 만난 상대` 줄이 각각 구장별·상대팀별 통계 화면으로 이어진다. 아무 일도
   하지 않는 버튼을 화면에 두지 않는다.

### 상태 범위

| 상태 | 화면 | 근거 |
| --- | --- | --- |
| 불러오는 중 | `VFLoadingPanel` | `statistics.loading` |
| 기록 없음 | `VFEmptyStatePanel` | `statistics.empty` |
| 기록 한 건 | 아카이브 전체 | 문장이 `firstRecord`로 바뀐다 |
| 표본 부족 | 안내 줄 | 승률을 숨기지 않고 흔들릴 수 있다고 알린다 |
| 승패 없음 | 승률 `—` | 0%로 쓰지 않는다 |
| 취소만 | 전용 문장 | "발걸음했지만 경기는 열리지 않았어요" |
| 구장 없음 | `statistics.stadiumAnalysis.empty` | 구장을 지어내지 않는다 |
| 점수 없음 | 하이라이트 비활성 | 합계·승률은 그대로 계산된다 |
| 복구 가능한 오류 | `VFErrorPanel` + 재시도 | 시즌을 잃지 않는다 |

### 결정적 픽스처 경계

`VFStatisticsFixtures`는 파일 전체가 `#if DEBUG`다. 시나리오 **23개**를 갖고 있고,
날짜와 ID는 모두 고정값이다. `Date.now`·무작위 `UUID`·`Calendar.current`를 쓰지 않고,
SwiftData에 쓰지 않으며 파일도 만들지 않는다. 사진 참조도 두지 않는다.

- 기준 시즌은 Pencil이 그린 **모양**과 같다. 8경기 · 5승 2패 1무, 3월 3번 / 4월 5번,
  라이온즈파크 5번, KIA 3번, 4월 3연승. 승률만 규칙대로 `.714`가 된다.
- 픽스처는 **시작 시즌만** 정한다. 그 뒤의 시즌 선택은 제품 경로(`selectSeason`) 그대로
  흐른다. 화면을 그릴 때마다 덮어쓰면 시즌을 바꿀 수 없게 된다 — 캘린더에서 겪은 결함이다.
- 캘린더와 시나리오 이름이 겹치는 것(`loading`, `recoverableError` 등)은 의도한 것이다.
  화면마다 같은 개념을 가리킨다. 켜는 **실행 인자 키**가 서로 다르고
  (`-VFUITestCalendarFixture` / `-VFUITestStatisticsFixture`), 각 이음새가 자기 키만
  읽는다는 것을 테스트가 확인한다.

### 픽스처 활성화 증명

모든 UI 테스트가 첫 단언으로 화면에서 `statistics.scenario.<시나리오>`를 찾는다. 표식이
없으면 조용히 제품 상태로 돌아간 것이므로 그 자리에서 실패한다. 표식은
`accessibilityHidden`을 붙이지 않는다 — 붙이면 접근성 트리에서 통째로 빠져 UI 테스트가
영영 찾지 못한다(캘린더에서 겪은 결함). 거버넌스 테스트가 이 조건을 소스에서 확인한다.

알 수 없는 이름은 어떤 픽스처도 켜지 않는다는 것도 따로 확인한다.

### 이 패스에서 테스트가 잡은 결함

1. **시즌 칩이 "2,026 시즌"으로 읽혔다.** `accessibilityLabel("… \(archive.season) 시즌")`은
   `LocalizedStringKey`로 해석돼 연도를 **수량**으로 포맷했다. 연도는 수량이 아니므로
   `Text(verbatim:)`으로 문자 그대로 읽게 고쳤다. 같은 실수를 막는 거버넌스 테스트를 뒀다.
2. **큰 글자에서 팀 이름이 "삼성 라…"로 잘렸다.** 커버 라벨과 팀 표시를 한 줄에 두어
   AccessibilityXXXL에서 자리가 모자랐다. 팀 이름은 이 화면이 누구의 시즌인지 말해 주는
   값이라 줄일 수 없으므로, 좁아지면 아래로 접히도록 `ViewThatFits`를 뒀다.
   접근성 이름은 잘려도 그대로 남아 **이름으로는 잡히지 않는다.** 그래서 줄바꿈이 실제로
   일어났는지를 좌표로 확인하는 검사를 따로 뒀다(`testSR18`, `testSR19`).

### 접근성 식별자

한국어 표시 문구를 정체성으로 쓰지 않는다. 읽어 주는 이름과 식별자는 서로 다른 값이다.

`statistics.root` · `.title` · `.subtitle` · `.selectedSeason` · `.season.<연도>` ·
`.seasonPicker` · `.hero` · `.hero.eyebrow` · `.headline` · `.winRate` ·
`.totalAttendance` · `.wins` · `.losses` · `.draws` · `.canceled` · `.distribution` ·
`.distribution.summary` · `.trend` · `.trend.month.<월>` · `.trend.summary` ·
`.highlights` · `.highlight.<종류>` · `.stadiumAnalysis` · `.stadiumAnalysis.empty` ·
`.stadium.<구장ID 또는 rank<n>>` · `.team.<팀ID>` · `.loading` · `.empty` ·
`.insufficientData` · `.error` · `.retry` · `.seasonReport` · `.leagueStandings` ·
`.scenario.<시나리오>`

등록부에 없는 구장은 순위로 구분한다(`statistics.stadium.rank1`). 한국어 구장 이름을
식별자로 만들지 않는다.

### 차트 규칙

두 차트 모두 의미 모델에서 값을 받고, 뷰 본문에서 기하를 계산하지 않는다. 비율은
서비스가 이미 계산해 두고, 화면은 그 비율을 폭으로 옮기기만 한다.

- **결과 분포** — 라벨이 붙은 가로 막대. 승·패·무·취소를 0이어도 모두 적어 색 없이도
  값이 남는다. 0건이면 막대를 그리지 않고 문장만 남긴다. 한 종류뿐이면 막대 하나가
  전체 폭을 차지한다.
- **월별 직관** — Pencil 점 쌓기. 한 칸에 그리는 점은 10개까지고, 넘으면 숫자로 말한다.
  칸이 여섯 개를 넘거나 접근성 글자 크기이면 **같은 값을 목록으로** 바꾼다. 어느 쪽이든
  달마다 `statistics.trend.month.<월>` 식별자와 읽어 줄 값이 그대로 남는다.
- 두 차트 모두 요약 문장을 화면에 함께 띄운다. 차트를 볼 수 없어도 같은 값이 남는다.
- 그라디언트·글로·의사 3D·무작위 애니메이션은 쓰지 않는다.

### 검증 범위

- 단위·거버넌스: `StatisticsTests`(38) · `StatisticsFixtureGovernanceTests`(32)
- UI: `StatisticsUITests`(42) — 픽스처 활성화와 화면 구조, 시즌 선택, 핵심 수치,
  상태 9종, 차트, 팀 아이덴티티 10구단 전수, 구장 아이덴티티 9구장 전수, 탐색
- 반응형: `StatisticsResponsiveUITests`(19) — 좁은 폭 8개(iPhone SE 3세대) +
  AccessibilityXXXL 11개
- 캡처 도구: `StatisticsCaptureUITests`(28)

좁은 폭 검사는 375pt급 기기에서만 뜻이 있으므로, 넓은 기기에서 돌면 통과로 위장하지 않고
건너뛴다고 명시적으로 알린다. 큰 글자 검사는 월 제목이 아니라 **시즌 제목 높이**를 재서
적용 여부를 먼저 확인한다.

### Release 격리 증명

`scripts/verify_calendar_fixture_exclusion.sh`는 이번에 두 화면을 함께 보도록
`scripts/verify_fixture_exclusion.sh`로 이름을 바꾸고 시즌 아카이브 항목을 더했다.

- **없을 것**: `VFStatisticsFixtures`, `StatisticsFixture`, 시나리오 이름 12개,
  `-VFUITestStatisticsFixture`, UUID 접두사 `57A7DA7A`, 표식 접두사 `statistics.scenario.`
- **있을 것**: `SeasonArchivePresentation`, `statistics.selectedSeason`,
  `statistics.stadiumAnalysis`, `statistics.distribution`, `SeasonCoverCard`

`insufficientData`는 검사 목록에서 뺐다. 제품 식별자 `statistics.insufficientData`와 글자가
겹쳐, 픽스처가 완전히 빠진 아카이브에서도 걸린다. 제품에서 정당하게 나올 수 있는 토큰은
이 검사에 쓸 수 없다 — 거짓 실패만 만든다. 실제로 첫 실행에서 이 항목이 걸려 알아냈다.

게이트는 양쪽으로 확인했다. Release 아카이브에서 통과(0건)하고, 픽스처가 실제로 들어 있는
Debug 번들에서 실패(38건)한다. 한쪽만 확인하면 "아무것도 못 찾는 검사"와 구분되지 않는다.

### 검증 근거 (실행 결과)

- 단위 테스트: **229개 통과, 실패 0** (`VictoryFairyTests`, iPhone 17 Pro)
  - 이 중 시즌 아카이브 몫은 `StatisticsTests` 38개 + `StatisticsFixtureGovernanceTests` 32개
- UI 테스트: **208개 실행, 실패 0, 건너뜀 28** (`VictoryFairyUITests`, iPhone 17 Pro)
  - 건너뛴 28개 = 캘린더 좁은 폭 7 + 시즌 좁은 폭 8 + 온보딩 13
  - 좁은 폭 15개는 넓은 기기에서 뜻이 없어 스스로 건너뛴다. 통과로 위장하지 않는다.
- 좁은 폭·큰 글자 실기기 검증: **iPhone SE 3세대(375pt)에서 19개 전부 실행, 건너뜀 0, 실패 0**
- 캡처: 28개 상태 × 2기기(iPhone 17 Pro / iPhone SE 3세대) = **56장**
- Debug 빌드 성공 · Release 아카이브 성공
- `verify_app_icon.sh` 통과 · `verify_release_readiness.sh` 통과
- `verify_fixture_exclusion.sh`: Release 아카이브 통과(0건) / Debug 번들 실패(38건)

### Release 아카이브 근거

- 스킴 `VictoryFairy-Production`, 구성 Release, 결과 **ARCHIVE SUCCEEDED**
- 번들 식별자 `com.hwangseokbeom.victoryfairy`, 마케팅 버전 1.1.0, 빌드 번호 1 (변동 없음)
- `Assets.car`에 AppIcon 세 렌디션(default / UIAppearanceDark / ISAppearanceTintable) 포함
- `LaunchMark`, `LaunchBackground`(라이트·다크) 포함, `UILaunchScreen` 키 유지
- 테스트 번들 미포함, 아이콘·알파 경고 없음
- 서명 설정은 손대지 않았다(`CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM` 그대로).
  다만 이 아카이브는 `CODE_SIGNING_ALLOWED=NO`로 만든 **미서명** 결과물이므로,
  App Store 배포 서명이 검증됐다고 말할 수 없다.

### 온보딩 건너뛴 검사 — 이번 실행 결과

`OnboardingUITests` 15개 가운데 **2개 통과, 13개 건너뜀**. 건너뛴 13개는 재설계 이전
흐름의 `onboarding.overview.next` 단계를 찾는다. 앞선 패스에서 정정한 분류 그대로이며,
이번 작업이 온보딩을 건드리지 않았음을 이 숫자가 함께 보여 준다.

### 남은 시즌 아카이브 과제 — 없음

시즌 아카이브의 구현·테스트·반응형·캡처·아카이브가 모두 통과했다. 아래 항목들은 이 화면의
미완성 부분이 **아니므로** 성격에 맞게 옮겨 적는다.

- **사진 콜라주를 넣지 않은 것** → *의도한 실데이터 편차*. 시즌 대표 사진을 고르는 규칙도,
  기록 사진을 읽는 경로도 없다. 없는 것을 만들지 않기로 한 결정이지 빠뜨린 일이 아니다.
- **`MetricCard`·`StatRankingRow`가 참조되지 않는 것** → *정리 부채*. 공용 컴포넌트
  라이브러리에 남아 있을 뿐 시즌 아카이브의 기능과 무관하다.
- **프로젝트 전체 다크 모드가 없는 것** → *프로젝트 전역 과제*. 원본에 다크 변형이 없어
  어느 한 화면에서 결정할 수 있는 일이 아니다.
- **픽셀 단위 비교를 하지 않은 것** → *주장하지 않은 검증 수준*. 측정 비교 없이 픽셀 일치를
  말하지 않기로 한 것이며, 하지 못한 검증이 아니다.

`AttendanceLogViewState.ourScore`는 이름이 "우리 팀 점수"지만 실제로는 응원 팀 점수다.
API 호환을 위해 그대로 두었고, 최다 점수 차 계산도 이 의미를 그대로 따른다.

---

## 기록 상세 — 08_RecordDetail (프레임 단위 구현 완료)

- Pencil 원본 SHA-256 `9b5af6aee3ed8cc72383d4d465dae2b62e75462dc5da3507d22f5f5055bb1a4a`
  (시즌 아카이브 패스와 **변동 없음**)
- 935,281 바이트 · 최상위 프레임 22개 · 재사용 컴포넌트 49개 · 문서 변수 46개
- 이전 상태 **TOKEN_ONLY_MIGRATION** → 최종 상태 **FRAME_LEVEL_IMPLEMENTATION**
- 프레임 노드 `XwqMs`, 393×1581

### Pencil 델타 — RECORD_DETAIL_ONLY_DELTA

원본 해시가 직전 패스와 **완전히 같다.** 즉 이번 패스 동안 디자인 문서는 한 글자도 바뀌지
않았다. 그러므로 다뤄야 할 차이는 "Pencil이 바뀐 것"이 아니라 "Pencil 프레임과 현재 구현이
다른 것"이고, 그 범위는 기록 상세 화면 하나에 갇힌다. 프레임이 쓰는 변수는 모두 이미 구현된
토큰에 대응되어 새 전역 토큰을 만들지 않았다. 완성된 홈·피드·캘린더·시즌 아카이브는 이번
작업으로 다시 칠해지지 않는다.

### 이 프레임이 표현하는 것

저장된 **직관 기록 한 건**이다. 경기 상세도 아니고 별도의 "추억" 개체도 아니다. Pencil은
이닝별 라인스코어처럼 경기 상세에 가까운 요소도 그리지만, 제품의 도메인(`AttendanceLog`)이
가진 것은 날짜·매치업·구장·결과·점수·좌석·동행·메모·일기·태그·사진 참조뿐이다. 화면은 그
경계를 그대로 따른다.

### 프레임 → 소스 매핑

| Pencil 노드 | 화면 | 실제 데이터원 | 없을 때 |
| --- | --- | --- | --- |
| `내비바` 제목 | `navigationTitle` | 기록 날짜 | 항상 있음 |
| `히어로 사진` | `RecordDetailMediaView` | `photoLocalRefs` | 상태별 안내 |
| `승 스탬프` | `VFResultStamp` | `result` | 항상 있음 |
| `손글씨 제목` | `RecordDetailPresentation.title` | `memo` | 줄 자체를 뺀다 |
| `장소 메타` | `.placeMeta` | 구장 + 좌석 | 있는 것만 잇는다 |
| `스코어보드` | `RecordDetailScoreboard` | 매치업 + 점수 | 점수 자리에 사유 |
| `라인스코어` | — | 없음 | 구현하지 않음 |
| `구장 히어로` | `RecordDetailStadiumView` | 기록 구장 | 등록 여부별 안내 |
| `일기 섹션` | `noteSection` | `diary` | 없음 안내 |
| `일기 서명` | `.note.signature` | 구장 + 사용자 이름 | 둘 중 하나만 없어도 뺀다 |
| `순간 섹션` | `highlightSection` | `highlightTags` | 섹션 자체를 뺀다 |
| `디테일 섹션` | `detailsSection` | 동행 · 좌석 | 셀 단위로 뺀다 |
| `무드 섹션` | `moodRow` | `moodTags.first` | 줄 자체를 뺀다 |
| `상세 액션` | `actions` | 공유 · 수정 경로 | 항상 있음 |
| — | 삭제 | `AppDataStore` | Pencil에 없어 더보기로 |

### 매핑 소유권

`RecordDetailService`는 Foundation만 쓰는 순수 계산 계층이다. 매치업 해석, 구장 확인,
결과 매핑, 점수 형식, 날짜 정책, 저장소 표시 문구 걸러내기가 모두 여기에 있고 화면에는
없다. 화면은 `RecordDetailPresentation` 하나를 받아 그리기만 한다. 미디어 상태만은 파일
시스템을 봐야 알 수 있어 밖에서 확인해 넘긴다 — 서비스는 파일을 읽지 않는다.

거버넌스 테스트가 화면 소스에 `log.matchup`·`log.stadium`·`AttendanceMatchup.resolve`
같은 재해석이 다시 생기지 않는지 확인한다.

### 저장소가 채운 표시 문구를 되돌린다

`AttendanceLogMapper`는 값이 비어 있으면 `"좌석 미정"`·`"미입력"`·`"직관 기록"`을 채운다.
상세가 그 문구를 사용자가 쓴 값처럼 보여 주면 없는 사실을 있는 것처럼 말하게 된다.
서비스가 이 세 값을 다시 "없음"으로 되돌리고, 그러면 제목·좌석·동행 줄이 조용히 사라진다.

### 팀과 구장

- 팀은 canonical 등록부(`KBOSeed`)에서만 온다. 상세 전용 팀 목록을 만들지 않았고,
  테스트가 소스에 팀 이름 리터럴이 없는지 확인한다.
- 응원 팀이 매치업 문자열 어디에 적혀 있든 **나의 팀** 자리로 온다. 응원 팀을 모르면
  적힌 순서를 그대로 쓴다.
- 구장은 기록에 적힌 것을 그대로 쓴다. 주 관람 구장·팀 홈 구장·기본 구장으로 바꾸지
  않는다. 홈/원정 표시는 등록부의 홈 팀 목록으로만 판단하고, 응원 팀을 모르면 단정하지
  않는다.
- 등록부에 없는 이름은 지우지 않고 "등록되지 않은 구장"으로 이름과 함께 보여 준다.
  구장이 아예 없으면 "구장 정보 없음"이다. 아홉 구장 전부와 미등록·미기록 두 경우를
  테스트한다.

### 사진 상태

"사진 없음"과 "파일이 사라짐"과 "열 수 없음"을 각각 다르게 말한다. 셋을 같은 회색
사각형으로 뭉개면 무엇이 잘못됐는지 알 수 없다. `PhotoAttachmentService.mediaState(for:)`가
참조 → 파일 존재 → 디코딩 순으로 확인해 상태를 정하고, 화면은 상태마다 다른 문구와 다른
식별자를 쓴다.

테스트용 사진은 **파일을 만들지 않는다.** `vf-uitest-inmemory-photo` 접두사를 가진 참조만
그릴 때마다 메모리에서 그린다. 그래서 번들에 넣을 테스트 전용 이미지 리소스가 아예 없고,
시뮬레이터에도 흔적이 남지 않는다. 접두사가 맞지 않으면 `nil`이라 제품이 만든 참조는 절대
이 그림으로 대체되지 않는다.

### 편집과 삭제

- 편집은 기존 `LogEditorView(editingLog:)` 경로를 그대로 연다. 두 번째 편집기를 만들지
  않았고, 테스트가 기존 좌석·동행 값이 채워져 열리는지 확인한다.
- 삭제는 화면이 아니라 `AppDataStore`가 수행한다. **기기 저장소에서 지우지 못하면 아무것도
  지우지 않고 실패를 알린다.** 예전에는 실패를 삼키고 화면에서만 사라지게 해서, 다시 열면
  되살아나는 기록을 사용자가 지웠다고 믿게 만들었다. 서버 삭제 실패는 다르다 — 기기에서
  이미 지웠으므로 오프라인 삭제로 보고 성공으로 다룬다.
- 확인 대화상자 문구는 Pencil `09_States`의 `삭제 다이얼로그`를 그대로 쓴다.

### 이 패스에서 테스트가 잡은 결함

1. **취소 버튼에 이름이 없었다.** `confirmationDialog`로 만들었더니 취소 버튼이 접근성
   트리에 **이름 없는 버튼**(`|`)으로 나왔다. 화면을 읽는 사람에게는 무엇을 누르는지 알 수
   없는 칸이다. 수정자를 떼어도 그대로였다. Pencil `09_States`의 삭제 다이얼로그는 원래
   화면 가운데 뜨는 카드에 두 버튼이 나란한 형태 — 즉 액션 시트가 아니라 얼럿이다.
   얼럿으로 바꾸니 두 버튼의 이름과 식별자가 모두 정상으로 노출된다. Pencil에 더 맞으면서
   접근성 결함도 사라졌다.
2. **대화상자 버튼이 접근성 트리에 두 번 노출된다.** 제품 결함은 아니지만 조회가 실패하므로
   테스트가 `firstMatch`로 집는다.

### 의도한 편차

1. **이닝별 라인스코어를 넣지 않았다.** 이닝 기록 데이터원이 없다. 숫자를 지어내는 대신
   최종 점수만 보여 준다.
2. **경기 시작 시각을 넣지 않았다.** Pencil `장소 메타`는 "18:30 경기"까지 적지만 도메인에
   시각이 없다. 구장과 좌석만 잇는다.
3. **날씨·먹은 것·응원 준비물을 넣지 않았다.** `그날의 작은 것들` 네 칸 가운데 도메인이
   실제로 저장하는 것은 동행과 좌석뿐이다. 나머지 두 칸은 만들지 않았다.
4. **별점을 넣지 않았다.** 평점 필드가 없다. 기분 태그만 남긴다.
5. **`순간` 문장을 태그로 바꿨다.** Pencil은 "9회초 박병호, 역전 스리런"처럼 선수와 이닝을
   적지만 그런 데이터원이 없다. 실제로 저장되는 하이라이트 태그를 보여 준다.
6. **일기 서명의 이름은 사용자 설정에서 온다.** 없으면 서명을 만들지 않는다.
7. **내비 오른쪽을 공유가 아니라 더보기로 두었다.** Pencil은 공유 아이콘을 두지만 바로
   아래에 "추억 카드로 공유하기" 버튼이 이미 있어 같은 동작이 두 번 나온다. 대신 내비바
   컴포넌트의 기본값인 더보기 메뉴로 두고, Pencil 프레임에 자리가 없는 삭제를 여기에 담았다.
8. **탭바가 상세에서도 보인다.** 커스텀 탭바가 셸(`MainTabView`)의 `safeAreaInset`이라
   밀어 넣은 화면에서도 남는다. Pencil 프레임에는 탭 영역이 없지만, 이를 바꾸려면 완성된 네
   화면이 공유하는 셸을 건드려야 해서 이번 범위 밖으로 두었다. 대신 탭바가 하나뿐인지와
   마지막 콘텐츠가 그 위에 남는지를 테스트한다.
9. **공식 기록 링크를 남겼다.** Pencil에는 없지만 서버가 주는 실제 값이고 기존 기능이다.

### 접근성 식별자

한국어 표시 문구를 정체성으로 쓰지 않는다. 읽어 주는 이름과 식별자는 서로 다른 값이다.

`recordDetail.root` · `.title` · `.placeMeta` · `.scoreboard` · `.result` · `.score` ·
`.team.<팀ID>` · `.opponent.<팀ID 또는 missing>` · `.stadium.<구장ID 또는 unknown|missing>` ·
`.media` · `.media.<photo|empty|missingFile|decodeFailed|loading>` · `.note` ·
`.note.empty` · `.mood` · `.highlights` · `.details` · `.fact.<companion|seat>` ·
`.share` · `.edit` · `.overflow` · `.delete` · `.delete.confirm` · `.delete.cancel` ·
`.officialRecord` · `.loading` · `.error` · `.retry` · `.scenario.<시나리오>`

뒤로 가기와 날짜에는 따로 식별자를 두지 않았다. 뒤로 가기는 시스템 내비게이션 버튼
(`BackButton`)이 이미 정체성을 갖고, 날짜는 화면 제목 자체라 내비게이션 바 이름으로
조회한다(`app.navigationBars["2026년 4월 12일"]`). 같은 것에 이름을 두 번 붙이지 않는다.
매치업 히어로는 `scoreboard`가 그 영역이다.

### 결정적 픽스처

`VFRecordDetailFixtures`는 파일 전체가 `#if DEBUG`다. 시나리오 **27개**를 갖고 있고,
날짜와 ID는 고정값(`D37A11ED` 접두사)이다. `Date.now`·무작위 `UUID`·`Calendar.current`를
쓰지 않고, SwiftData에 쓰지 않으며 **사진 파일도 만들지 않는다**.

상세는 스스로 뜨는 화면이 아니라 눌러서 들어가는 화면이다. 그래서 픽스처는 상세만 정하고,
목록은 기존 피드/캘린더 픽스처가 만든다. 모든 UI 테스트가 실제로 목록에서 기록을 눌러
들어간 뒤 `recordDetail.scenario.<시나리오>` 표식을 확인한다. 이렇게 하면 Feed→상세와
캘린더→상세 두 경로가 검증에 함께 딸려 온다.

삭제 실패는 저장소를 건드리지 않고 결과만 정하는 이음새로 만든다. 그래서 실패 경로를
확인해도 실제 기록이 사라지지 않는다.

### 피드 사진 캡처 공백 — 닫힘

`AttachmentPhotoView`에 DEBUG 전용 분기를 하나 더했다. `vf-uitest-inmemory-photo` 접두사를
가진 참조만 메모리에서 그림을 만들어 돌려준다. 피드와 상세가 같은 컴포넌트를 쓰므로 이
장치 하나로 두 화면 모두 사진을 그릴 수 있다.

다만 그것만으로는 부족했다. 기존 피드 픽스처의 기록에는 사진 참조가 하나도 없어서, 장치가
있어도 피드에는 여전히 사진이 나오지 않았다. 그래서 피드 픽스처에 사진을 든 상태
(`withPhoto`)를 하나 더하고, 그 상태를 찍는 캡처를 두어 공백을 닫았다.

닫아도 되는 조건을 모두 확인했다.

- 제품 사진 동작이 바뀌지 않는다 — 접두사가 맞지 않으면 `nil`이라 기존 경로로 그대로 간다
- 파일을 쓰지 않는다 — 그릴 때마다 메모리에서 만든다
- Release에 남지 않는다 — 분기 자체가 `#if DEBUG`이고, 아카이브 게이트가 접두사 부재를 확인한다
- 피드를 다시 설계하지 않았다 — 피드 소스는 한 줄도 바뀌지 않았다
- 기존 피드 테스트가 그대로 통과한다

### 검증 범위와 결과

- 단위·거버넌스: `RecordDetailTests`(29) · `RecordDetailFixtureGovernanceTests`(31)
- UI: `RecordDetailUITests`(41) — 진입 경로, 내비게이션, 매치업과 정체성, 미디어 4상태,
  일기 3상태, 결과 6상태, 불러오기와 복구, 편집, 삭제, 그 밖의 내용
- 반응형: `RecordDetailResponsiveUITests`(19) — 좁은 폭 9개(iPhone SE 3세대) +
  AccessibilityXXXL 10개
- 캡처 도구: `RecordDetailCaptureUITests`(32) · `FeedPhotoCaptureUITests`(2)

실행 결과(iPhone 17 Pro):

- 단위 테스트 **290개 통과, 실패 0**
- UI 테스트 **302개 실행, 실패 0, 건너뜀 37**
  - 건너뛴 37개 = 캘린더 좁은 폭 7 + 시즌 좁은 폭 8 + 기록 상세 좁은 폭 9 + 온보딩 13
- 좁은 폭·큰 글자 실기기 검증: iPhone SE 3세대(375pt)에서 **19개 전부 실행, 건너뜀 0, 실패 0**
- 캡처: iPhone 17 Pro 33장 + iPhone SE 3세대 32장 = **65장**
- Debug 빌드 성공 · Release 아카이브 성공
- `verify_app_icon.sh` 통과 · `verify_release_readiness.sh` 통과
- `verify_fixture_exclusion.sh`: Release 아카이브 통과(0건) / Debug 번들 실패(57건)

### Release 아카이브 근거

- 스킴 `VictoryFairy-Production`, 구성 Release, 결과 **ARCHIVE SUCCEEDED**
- 아카이브 경로 `/tmp/VictoryFairy-archives/VictoryFairy-RecordDetail.xcarchive` (저장소 밖)
- 번들 식별자 `com.hwangseokbeom.victoryfairy`, 마케팅 버전 1.1.0, 빌드 번호 1 (변동 없음)
- AppIcon 세 렌디션 · `LaunchMark` · `LaunchBackground` · `UILaunchScreen` 유지
- 테스트 번들 미포함, 아이콘·런치 경고 없음
- 서명 설정은 손대지 않았다. 다만 `CODE_SIGNING_ALLOWED=NO`로 만든 **미서명** 결과물이므로
  App Store 배포 서명이 검증됐다고 말할 수 없다.

### 이번 패스에서 고친 회귀

캘린더 테스트 세 곳이 예전 상세 화면의 매치업 원문(`"삼성 vs LG"`)을 찾고 있었다. 새 상세는
두 팀을 각각 온전한 이름으로 보여 주므로 그 문자열이 화면에서 사라졌다. 문구가 아니라
화면 정체성(`recordDetail.root`)으로 도착을 확인하도록 고쳤다. 검사 강도는 그대로이고,
오히려 표시 문구가 바뀌어도 깨지지 않는다.

### 다음 화면

기록 작성 1·2·3단계, 마이(프로필), 팀 선택기가 남아 있다. 이번 패스는 그 화면들을
시작하지 않았다.

---

## 개정 Pencil — Victory Fairy 기반 (토큰과 기본 글리프)

이 절부터는 **개정된 Pencil 원본**을 다룬다. 위쪽의 완료된 화면 기록은 그때의 원본을
근거로 한 것이며 그대로 유효하다. 지우거나 고치지 않는다.

### 개정 원본

- SHA-256 `8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2`
- 1,882,899 바이트 · 수정 시각 2026-07-30 09:36:28 +0900
- 최상위 프레임 **27개** · 재사용 컴포넌트 **98개** · 문서 변수 **58개** · 테마 없음
- 이전 원본 `9b5af6ae…5b1a4a`(935,281바이트 · 22프레임 · 49컴포넌트 · 46변수)는
  홈·피드·캘린더·시즌 아카이브·기록 상세의 근거로 **계속 남는다**

감사 결론은 화면 재설계가 아니라 **아이콘 시스템 개정**이었다. 늘어난 49개 컴포넌트는
전부 페어리 계열이고, 기존 46개 변수는 값이 하나도 바뀌지 않았다.

### 읽은 보드

- `02_VictoryFairy_Glyph_System` — 공통 구축 규격(바디 블롭 · 도트 눈 · 미니멀 입 ·
  다이아몬드 안테나)과 `FairyGlyph_*` 12종, `Fairy48_*` 8종
- `10_Fairy_Validation` — 어피어런스 행, 표면 대비(라이트/다크), 소형 사이즈 재검증,
  평가 체크리스트

### 페어리 변수 12개

값은 `execute`/`GetVariables`로 직접 읽었다. 다섯은 원본에 처음 등장한 값이고
일곱은 이미 있는 토큰과 **같은 값**이다.

새로 생긴 값 — `VFFairyColor`에 리터럴로 둔다.

- `fairyMemory` `#9D93C8` → `VFFairyColor.memory`
- `fairyMemorySurface` `#EDEAF5` → `VFFairyColor.memorySurface`
- `fairyConcern` `#B95F55` → `VFFairyColor.concern`
- `fairyFaceOnDark` `#F6F3EA` → `VFFairyColor.faceOnDark`
- `fairyIconBgDark` `#070C16` → `VFFairyColor.iconBackgroundDark`

별칭 — 기존 토큰을 **가리킨다.** 같은 hex를 다시 적지 않는다. 값을 복제해 두면
나중에 한쪽만 바뀌어 조용히 어긋나기 때문이다.

- `fairyVictory` `#F2B63C` → `VFColor.primaryAction` (gold/coral/butter)
- `fairyTeam` `#5E7FA6` → `VFColor.infoAccent` (sky)
- `fairyStadium` `#2F7A56` → `VFColor.supportAccent` (sage)
- `fairyLive` `#E5484D` → `VFColor.gameLive` (live/stamp-red)
- `fairyNeutral` `#8B909E` → `VFColor.bodyTertiary` (ink-faint)
- `fairyFaceOnLight` `#14171F` → `VFColor.bodyPrimary` (ink)
- `fairyIconBg` `#0E1526` → `VFColor.nightSurface` (night/navy)

`fairyFaceOnDark`(#F6F3EA)와 본문용 `bodyOnDark`(#F6F5F0)는 **값이 다르다.**
비슷하다고 합치면 얼굴 대비가 원본과 어긋나므로 따로 둔다.

기존 토큰은 하나도 바뀌지 않았다. 완성된 화면이 이번 작업으로 다시 칠해지지 않는다.

### 기본 글리프 — `DesignSystem/VFFairyGlyphs.swift`

`FairyGlyph_*` 12종(base·victory·success·team·stadium·memory·loss·draw·cancelled·
live·empty·error)과 `Fairy48_*` 8종(victory·loss·draw·cancelled·success·empty·
error·memory)을 옮겼다. base·team·stadium·live는 원본에 48px 축소본이 없다.
team·stadium의 축소본은 `TeamFairy48`·`StadiumFairy48_*`라는 별개 컴포넌트이며
이후 패스의 몫이다.

공통 구조는 모든 종류가 똑같다. 몸통 경로 하나, 안테나 줄기, 안테나 다이아몬드,
눈 두 개, 입 하나. 종류마다 다른 것은 몸 색·얼굴 색·눈 모양·입 모양, 그리고
96px에서만 나타나는 곁들임(승리 스파크·저장 스파크·일시정지 바·라이브 펄스)뿐이다.
서로 다른 일러스트로 갈라지지 않는다.

### 48px은 절반이 아니다

배치는 정확히 절반이지만 **선 두께와 눈 지름은 아니다.** 그대로 줄이면 선이 사라지고
눈이 점으로 뭉개져서 Pencil이 광학 보정을 해 두었다.

- 몸통 외곽선 2.016 → 1.2 (절반이면 1.008)
- 선 요소 2.6 → 1.8 (절반이면 1.3)
- 뜬 눈 지름 7 → 4 (절반이면 3.5)
- 다이아몬드 외곽선 1.1 → 1.1 (그대로)
- 곁들임은 48px에서 전부 뺀다

그래서 `VFFairySize`는 배치를 배율로, 두께를 원본 값으로 따로 들고 있다.

### 광학 중심

몸통 여백이 대칭이 아니다. 왼쪽 17, 위·오른쪽·아래 16이다. 처음에는 실수로 보고
대칭을 기대하는 검사를 썼다가 실패해서 원본을 다시 읽었다. 안테나가 오른쪽 위로
뻗으므로 몸통을 0.5pt 오른쪽으로 밀어야 글리프 전체가 가운데 있어 보인다.
핸드오프의 "광학 중심 유지"가 이것이다. 대칭으로 "고치면" 원본과 어긋난다.

### 벡터 소유권

`DesignSystem/VFVectorPath.swift` 하나만 쓴다. 두 번째 파서를 들이지 않았다.
기존 파서가 M/L/H/V/C/S/Q/T/**A**/Z와 상대·절대, 명령 반복까지 이미 다루므로
고칠 것이 없었다. 라이브 펄스가 호(`a`) 명령을 쓰는데, 호가 직선으로 흐르면 그 모양만
조용히 사라지므로 실제로 펴지는지 확인하는 검사를 따로 두었다.

경로와 viewBox는 원본 문자열 그대로 옮겼다. 다시 그리지 않았으므로 테스트가 Pencil
노드 값과 직접 비교할 수 있다.

### 라이트 · 다크 · 모노크롬

`10_Fairy_Validation`의 `표면 대비 · 라이트/다크`는 **똑같은 인스턴스를 `paper` 위와
`night` 위에 아무 재정의 없이** 나란히 놓는다. 즉 인앱 글리프는 표면에 따라 다시
칠하지 않는다. 없는 다크 팔레트를 지어내지 않았고, 두 경우가 같은 값으로 풀린다는
사실 자체를 테스트가 지킨다.

어피어런스 행의 Default/Dark/Tinted/Monochrome 네 셀은 **앱 아이콘**의 렌디션이지
인앱 글리프가 아니다. 아이콘은 이번 패스에서 건드리지 않았다.

모노크롬은 아이콘 Monochrome 셀의 규칙(몸과 다이아몬드를 한 톤으로 눕히고 배경이
네거티브 스페이스로 비친다)을 글리프에 옮긴 것이다. 다만 **표정은 남긴다.** 아이콘에서
표정은 장식이지만 글리프에서는 색을 대신하는 유일한 의미 신호라, 지우면 모노크롬을
만든 이유가 사라진다. 몸 톤은 Pencil이 이미 무채색 페어리로 쓰고 있는 `cream`을
그대로 쓴다. 색을 지워도 승·패·무·취소·라이브가 서로 다른 표정으로 남는지 검사한다.

### 접근성 계약

읽어 줄 문장은 **부르는 쪽이 준다.** 컴포넌트가 문구를 지어내지 않고, 라벨을 주지
않으면 장식으로 보고 숨긴다. 기본값이 "숨김"이라 라벨을 깜빡한 페어리가 컴포넌트
이름이나 원시값으로 읽히는 일이 없다.

`VFFairyPairing`이 "혼자서는 뜻을 전하지 못한다"는 것을 타입으로 남긴다.

- `decorative` — 기본형만
- `requiresResultText` — 승·패·무·취소·라이브·저장·기록없음·오류·추억
- `requiresTeamName` — 팀 정체성
- `requiresStadiumName` — 구장 정체성

Pencil이 "결과·상태 글리프 라벨 병기 필수", "구장 페어리는 항상 구장명과 병기"라고
적어 둔 것을 문서가 아니라 코드에 둔 것이다. 팀·구장 래퍼가 이 계약을 지켜야 한다.

### 유틸리티 아이콘 카브아웃

`VFFairyIconPolicy.nativeUtilityActions` — 뒤로·닫기·수정·삭제·설정·chevron·더보기·
다시 시도·카메라·사진 선택·이전 달·다음 달·펼침·파괴적 동작은 네이티브로 남는다.
페어리로 바꾸지 않는다. 사용자가 시스템 전체에서 익힌 모양이 있고, 캐릭터로 바꾸면
무엇을 누르는 자리인지 알기 어려워진다. 되돌리기 어려운 동작일수록 더 그렇다.

페어리를 쓰는 자리는 브랜드·팀·구장·결과 정체성, 감정적 기억, 그리고 Pencil이 명시적으로
놓아 둔 빈 상태와 오류 상태뿐이다. 이번 패스는 어느 화면에도 놓지 않았다.

### 화면 밀도 지침

Pencil 평가 항목의 "화면당 페어리 1~3개 제한"을 `VFFairyIconPolicy`에 상수로 남겼다.
이후 배치 패스가 지켜야 할 규칙이다.

- 유틸리티 동작마다 페어리를 붙이지 않는다
- 캘린더 칸마다 얼굴을 넣지 않는다
- 기록 카드마다 캐릭터 장식을 넣지 않는다
- 바로 옆 문구와 같은 말을 하는 페어리를 겹쳐 두지 않는다
- 화면당 감정을 전하는 큰 페어리 하나, 또는 작은 정체성 뱃지 몇 개

문자열 세기만으로 판정하는 검사는 거짓 실패를 만들기 쉬워 두지 않았다. 대신 화면 소스가
아직 페어리를 쓰지 않는다는 것을 확인하는 검사를 두어, 배치가 시작되면 의식적으로
고치게 했다.

### 팀 · 구장 래퍼 경계

`VFFairyGlyphs.swift`는 팀도 구장도 알지 못한다. `KBOSeed`·`KBOTeam`·`KBOStadium`·
`VFTeamAccent`·저장소·네트워크를 들이지 않으며, 팀 이름이나 구장 이름 리터럴도 없다.
`import`는 `SwiftUI` 하나뿐이고 검사가 이를 지킨다. 팀 페어리와 구장 페어리는 이 기반
위에 얹는 별개 래퍼이며, 다시 쓰지 않고 감쌀 수 있도록 구조를 열어 두었다.

### 이번 패스에서 건드리지 않은 것

홈·피드·캘린더·시즌 아카이브·기록 상세·온보딩·기록 작성·마이·팀 선택기 소스,
AppIcon 자산, LaunchMark 자산, 픽스처, 아카이브 스크립트. 전부 그대로다.

`project.pbxproj`는 한 곳만 손댔다. 앱 타깃은 동기화 그룹이라 새 소스가 자동으로
들어가지만 **테스트 타깃은 명시 목록**이라, 새 테스트 파일을 넣지 않으면 46개 검사가
조용히 실행되지 않는다. 처음 실행했을 때 총계가 290개 그대로여서 알아챘다.

### 다음 패스

1. 팀 페어리 10구단 + 중립 + `TeamFairy48`
2. 구장 페어리 9구장 + 제네릭/미지정 + 뱃지·행·모노 변형
3. AppIcon 쿼텟 교체 (Monochrome 네 번째 렌디션 여부 결정 필요)
4. LaunchMark 쿼텟 교체
5. 공용 컴포넌트 배치 — `TeamIdentityHeader`의 팀 심볼, 빈/오류 패널
6. 화면 배치 — 온보딩 완료, 홈, 캘린더, 시즌 아카이브

---

## 개정 Pencil — Team Fairy (10구단 + 중립)

기본 글리프 위에 얹는 첫 번째 의미 래퍼다. 원본은 앞 절과 같다 —
SHA-256 `8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2`,
1,882,899바이트, 2026-07-30 09:36:28 +0900.

### 읽은 보드

`02_TeamFairy_System` — "Team Fairy — 10개 구단 · 크림 바디 + 팀컬러 캡 + 구단명 유래
무로고 특징". 선택 상태의 근거로 `OnboardingTeamCard`와 `08_TeamSelector 선택 팀
프리뷰`도 배치 참고로만 읽었다. 두 화면 모두 이번 패스에서 고치지 않았다.

### 컴포넌트

`TeamFairy_Samsung` `OXOEK` · `TeamFairy_LG` `sWD1i` · `TeamFairy_Doosan` `OMk4g` ·
`TeamFairy_KIA` `Kl4cR` · `TeamFairy_KT` `CukKm` · `TeamFairy_SSG` `b1C5P` ·
`TeamFairy_NC` `b4qwn` · `TeamFairy_Lotte` `iJM6Q` · `TeamFairy_Kiwoom` `LaM0I` ·
`TeamFairy_Hanwha` `wg4Vb` · `TeamFairy_Neutral` `I7iUy` — 모두 96×96.
`TeamFairy48` `B90BdV` — 48×48.

### 팀 등록부 소유권

팀 목록은 `KBOSeed`, 팀 색은 `VFTeamAccent`가 소유한다. `VFTeamFairies.swift`에는
두 번째 팀 등록부도, 팀 색 리터럴도, 팀 표시 이름도 없다. 특징 표는 canonical ID를
특징에 잇기만 하고, 색은 `VFTeamAccent.color(forTeamID:)`로 받아 온다. 예전 짧은 ID는
`KBOSeed.normalizedTeamID`가 정규화한다.

### 10구단 + 중립 매핑

구단 이름의 **뜻**에서 온 특징만 쓴다. 로고도 공식 마스코트도 옮기지 않았다.

- `samsung-lions` → 사자 갈기 (몸통 뒤)
- `lg-twins` → 안테나 둘 + 투톤 캡
- `doosan-bears` → 곰 귀와 귀 안쪽, 주둥이
- `kia-tigers` → 호랑이 귀, 이마 줄무늬, 볼 줄
- `kt-wiz` → 마법사 모자 (표준 캡 대신)
- `ssg-landers` → 로켓 핀과 창문
- `nc-dinos` → 공룡 스파이크와 등 가시 둘
- `lotte-giants` → 큰 몸 + 하이크라운 캡 (버튼 없음)
- `kiwoom-heroes` → 히어로 마스크와 망토, 마스크 위 밝은 눈
- `hanwha-eagles` → 독수리 날개 둘과 눈썹
- 중립 → 표준 캡에 `fairyTeam`(sky). 구단을 암시하지 않는다

### 요소 수가 원본과 같다

각 특징이 만드는 조각 수를 Pencil 컴포넌트의 자식 수와 그대로 맞췄고 테스트가 지킨다.
11 / 13 / 15 / 15 / 9 / 12 / 13 / 9 / 12 / 13 / 10, 그리고 48px은 모두 8.
조각을 빠뜨리거나 더하면 이 검사가 잡는다.

### 공유 기하

몸통 경로와 viewBox는 `VFFairyGeometry`의 것을 그대로 쓴다. 열한 종류가 **같은
실루엣**이고, 롯데만 자이언츠라는 이름에 맞춰 68×68로 키운다(경로는 같고 크기만 다르다).
얼굴과 안테나도 열한 종류가 같은 자리, 같은 크기다. LG만 안테나를 하나 더 단다.

얼굴은 기본 글리프보다 **2pt 아래**에 있다. 캡이 위쪽을 차지하기 때문이다. 그래서
`TeamFairy_*`는 `FairyGlyph_Team`과 다른 컴포넌트다 — 후자는 크림 바디도 캡도 없고
몸 자체가 sky색이다. 둘을 같은 것으로 보면 안 된다.

선 두께도 기본 글리프와 다르다: 몸통 2(2.016 아님), 선 요소 2.4(2.6 아님),
다이아몬드 1.3(1.1 아님).

### TeamFairy48

배치는 정확히 절반이지만 그대로 줄인 것이 아니다.

- 선: 몸통 2 → 1.4, 챙 1.8 → 1.2, 선 요소 2.4 → 1.6, 다이아몬드 1.3 → 1.1
- 눈 지름 7 → 4 (절반이면 3.5)
- **재봉선·버튼·구단 특징이 모두 빠진다.** 자식이 8개뿐이다
- 입 viewBox가 `[41,57,14,6]`에서 경로에 딱 맞는 `[43,59,10,3]`으로 좁아진다

48px에서는 열 팀이 **완전히 같은 모양**이고 캡 색만 다르다. 그래서 작은 크기에서
팀 이름을 곁에 두는 것은 권고가 아니라 필수다. 테스트가 이 두 가지를 함께 지킨다.

기본 글리프의 일반 축소본으로 대신할 수 없다. `VFFairyKind.team`에는 Pencil 48px
원본이 아예 없고, 팀 48px에는 기본 글리프에 없는 캡이 있다.

### 선택과 미선택

**Pencil에는 `TeamFairy_*_Selected`가 없다.** 구장 페어리에는
`StadiumFairy_Badge_Selected`가 따로 있지만 팀 페어리에는 없다. 선택은 페어리 그림이
아니라 감싸는 카드가 알린다.

- `OnboardingTeamCard` — 네이티브 체크 아이콘(`gold`) + "선택됨" 글자(`coral-deep`)
- `08_TeamSelector 선택 팀 프리뷰` — 팀 컬러 레일(4pt) + `circle-check` 아이콘

그래서 `VFTeamFairySelection`은 그림을 바꾸지 않는다(테스트가 확인한다). 대신 감싸는
쪽이 무엇을 반드시 그려야 하는지를 계약으로 남긴다 — 선택에는 **체크 표시가 필수**이고,
자리에 따라 "선택됨" 글자나 팀 레일이 더해진다. 색만으로 선택을 알리는 일이 없다.

체크 표시는 네이티브로 남는다. 페어리로 바꾸지 않으며, 페어리가 직접 그리지도 않는다.
탭 영역·선택 특성·동작·포커스는 모두 감싸는 버튼이 가진다.

### 라이트 · 다크 · 모노크롬

기본 글리프와 같다. Pencil이 같은 인스턴스를 `paper` 위와 `night` 위에 아무 재정의
없이 놓으므로, 표면에 따라 다시 칠하지 않는다. 테스트가 두 외형이 같은 팔레트로
풀리는지 확인한다.

모노크롬은 열 팀을 **한 톤으로 눕힌다.** 색이 사라지면 팀도 사라지므로 곁의 글자가
유일한 신호가 된다. 다만 구조는 남긴다 — 몸(가장 밝음) · 캡(중간) · 얼굴(가장 어두움)
세 단계를 유지해 캡이 몸에 녹아 사라지지 않게 했다. 기본 글리프 모노크롬과 같은
원칙이되, 팀 페어리는 층이 하나 더 있어 두 톤이 아니라 세 톤을 쓴다.

### 대비

캡이 팀 색이라, 몸이나 외곽선 가운데 **적어도 한쪽과는** 뚜렷이 갈려야 한다. 양쪽과
모두 어중간한 중간 톤이면 캡이 사라진다. 열 팀 모두 `max(캡:몸, 캡:외곽선) ≥ 3.9`로
통과한다.

밝기 양 끝은 기억이 아니라 저장소 값으로 계산해서 골랐다.

- 가장 어두운 강조색 **두산 `#1A2C55`** — 외곽선과는 1.05로 거의 붙지만 크림 몸과
  11.84라 형태가 또렷하다
- 가장 밝은 강조색 **한화 `#E5691F`** — 몸과는 2.85로 가장 낮지만 외곽선과 4.34라
  윤곽이 형태를 지킨다

얼굴은 팀 색과 닿지 않고 크림 몸 위에 놓이므로 열 팀 모두 15.51로 안전하다. 키움만
눈이 팀 색 마스크 위에 올라가는데 그 조합도 8.78이다.

### 접근성

읽어 줄 문장은 부르는 쪽이 준다. 라벨이 없으면 장식으로 보고 숨긴다 — 곁에 이미 팀
이름이 적혀 있는 카드 안에서는 그렇게 써야 같은 팀을 두 번 읽지 않는다.
`VFTeamFairy.pairing`은 기반의 `VFFairyPairing.requiresTeamName`을 그대로 따른다.

팀 ID·특징 이름·컴포넌트 이름은 VoiceOver로 새어 나가지 않는다. 소스에 고정 문구
라벨이 없고 원시값을 문장에 섞지 않는다는 것을 검사가 확인한다.

### 이번 패스에서 건드리지 않은 것

`VFTeamIdentityHeader`를 포함해 어떤 화면에도 팀 페어리를 놓지 않았다. 홈·피드·
캘린더·시즌 아카이브·기록 상세·온보딩·기록 작성·마이·팀 선택기 소스, AppIcon 자산,
LaunchMark 자산, 픽스처, 아카이브 스크립트 모두 그대로다. 화면과 공용 컴포넌트가
아직 팀 페어리를 쓰지 않는다는 것을 검사가 확인하므로, 배치가 시작되면 그 검사를
의식적으로 고쳐야 한다.

`project.pbxproj`는 새 테스트 파일 등록 하나만 더했다. 테스트 타깃이 명시 목록이라
넣지 않으면 56개 검사가 조용히 실행되지 않는다.

### 이 패스에서 검사가 잡은 것

프리뷰 하나가 "롯데 자이언츠"를 문자열로 박아 두고 있었다. 그리기 소스에 팀 표시
이름이 없어야 한다는 검사가 잡았고, 등록부에서 이름을 가져오도록 고쳤다. 나머지
프리뷰는 처음부터 등록부를 쓰고 있었다.

### 다음 패스

`pass/stadium-fairies` — 9구장 + 제네릭/미지정, 그리고 48px·모노·뱃지·선택 상태·
컴팩트 행 변형. 구장 페어리에는 팀과 달리 Pencil이 그린 선택 변형
(`StadiumFairy_Badge_Selected`, 골드 링 + 체크)이 있다.

---

## 개정 Pencil — Stadium Fairy (9구장 + 제네릭 + 미지정)

원본은 앞 절과 같다 — SHA-256
`8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2`, 1,882,899바이트.
이번 패스 시작 시각 기준 수정 시각은 2026-07-30 11:51:46 +0900으로, 앞 패스가 적어 둔
09:36:28과 다르다. **해시와 크기는 완전히 같으므로 내용은 한 바이트도 바뀌지 않았고**,
파일이 한 번 다시 저장되기만 했다.

### 읽은 보드

`02_StadiumFairy_System` (`uefu4`) — "Stadium Fairy — 9개 구장 · 잉크 라인 디테일 +
구장별 특징 (항상 구장명과 병기)". 컴포넌트 16개가 모두 이 보드에 있다.

### 컴포넌트

`StadiumFairy_Jamsil` `D0fWH` · `StadiumFairy_Gocheok` `hi9mL` ·
`StadiumFairy_SSG` `jPJTN` · `StadiumFairy_KT` `il6qe` · `StadiumFairy_Hanwha` `yO5zn` ·
`StadiumFairy_LionsPark` `puaOA` · `StadiumFairy_Sajik` `wiGab` · `StadiumFairy_NC` `ZnHfv` ·
`StadiumFairy_KIA` `c6Kbml` · `StadiumFairy_Generic` `BycI7` · `StadiumFairy_Unknown` `UVb5T`
— 모두 96×96. `StadiumFairy48_Generic` `dtk9c` · `StadiumFairy48_Mono` `J7wOGT` — 48×48.
`StadiumFairy_Badge` `XbcZ8` 136×60 · `StadiumFairy_Badge_Selected` `ZQic0` 160×60 ·
`StadiumFairy_Row` `y8upqi` 300×64.

### 팀 페어리와 다른 점 — 기본 글리프를 그대로 쓴다

팀 페어리는 크림 바디에 얼굴이 2pt 아래라 자기 치수를 따로 가졌다. 구장 페어리는
**`FairyGlyph_Stadium`과 몸통·안테나·눈·입이 완전히 같다** — 같은 경로, 같은 좌표,
같은 선 두께(2.016 / 2.6 / 1.1), 눈도 y=41이다. 그래서 몸통을 다시 그리지 않고
`VFFairyGlyph(.stadium)`을 합성하고, 그 위에 구장 특징만 얹는다. 테스트가 몸통·안테나
경로 문자열이 구장 파일에 다시 나타나지 않는지 확인한다.

### 구장 등록부 소유권

구장 목록·이름·짧은 이름·별칭은 `KBOStadiumSeed`가 소유한다. 구장 페어리 소스에는
두 번째 등록부도, 한국어 구장 이름도, 짧은 이름도 없다(테스트가 확인한다).
canonical ID 아홉 개: `jamsil` · `gocheok` · `incheon-ssg` · `suwon-kt` ·
`daejeon-hanwha` · `daegu-lions` · `gwangju-kia` · `sajik` · `changwon-nc`.

### 아홉 구장 특징

모두 잉크 선 한두 개다. 건축물의 초상이 아니라 "그 장소"를 가리키는 표식이다.

- `jamsil` → 조명탑 둘 (22,2,9,17) · (37,-2,9,19), 선 2.4. 구조적
- `gocheok` → 돔 아크 (16,2,42,12), 선 2.8. 구조적
- `incheon-ssg` → 전광판 기둥 + 보드 (26,4,16,14) · (26,4,16,9). 구조적
- `suwon-kt` → 페넌트 깃대 + 깃발 (26,1,3,16) · (28,2,12,8). 장식적
- `daejeon-hanwha` → 외야 담장 커브 (26,84,44,8), 선 2.6. 구조적
- `daegu-lions` → 직선 지붕 (16,4,38,12), 선 2.6. 구조적
- `gwangju-kia` → 관중석 단 (28,83,20,11), 선 2.6. 구조적
- `sajik` → 파도 라인 (26,84,44,8), 선 2.6. 장식적
- `changwon-nc` → 스카이라인 노치 (16,3,36,13), 선 2.4. 구조적

머리 쪽에 오는 것과 발치에 오는 것이 갈린다. 외야 담장·파도·관중석 단·홈플레이트만
몸 아래에 놓인다. 잠실 오른쪽 조명탑만 캔버스 위로 넘어간다(원본 y = −2).

### 제네릭

`StadiumFairy_Generic`은 구장색 몸에 **홈플레이트 베이스** (41,84,14,12)를 붙인다.
야구 공통 모티프이지 특정 구장이 아니다. 아홉 구장 어느 것의 대역도 아니고 기본 구장을
뜻하지도 않는다 — 테스트가 제네릭 특징이 아홉 구장 어느 것과도 같지 않은지 확인한다.

### 미지정

`StadiumFairy_Unknown`은 **중립색 몸에 구장 특징이 없다.** 값은 있는데 등록부가 풀지
못하는 경우다. 이름은 기록에 적힌 그대로 부르는 쪽이 보여 준다. 다른 구장으로 바꾸지
않는다 — "잠실"처럼 canonical 이름의 일부여도 정확히 일치하지 않으면 미지정이다.

Pencil은 물음표를 그리지 않았으므로 우리도 그리지 않았다.

### 구장 없음 — 미지정과 다르다

`identity(forRecordedStadiumNamed:)`는 값이 없거나 공백뿐이면 **`nil`을 돌려준다.**
그리면 안 되는 상태라 그릴 정체성 자체를 만들지 않는다. 앱이 이미 쓰는 구분과 같다 —
`RecordDetailStadium.accessibilityIdentifierSuffix`가 `missing` / `unknown` /
구장 ID로 나누는 그 경계다.

해석 함수는 **기록에 적힌 값 말고 아무것도 보지 않는다.** 응원 팀의 홈 구장이나
사용자의 주 관람 구장으로 되돌아가는 경로를 아예 만들지 않았고, 소스에
`recommendedStadium` · `primaryStadium` · `favoriteTeam` · `homeTeamIDs`가 없다는 것을
테스트가 확인한다.

### 선택과 미선택

팀 페어리와 달리 구장에는 Pencil이 **선택 변형을 그려 두었다** —
`StadiumFairy_Badge_Selected`. 다만 바뀌는 것은 페어리가 아니라 **뱃지**다:
`$fairyVictory` 2pt 테두리가 생기고 네이티브 체크 아이콘 16px이 붙는다. 페어리 그림은
그대로다. 그래서 `VFStadiumFairy`에는 선택 매개변수가 아예 없고, 뱃지와 행만 그것을
가진다(테스트가 타입 경계로 확인한다).

색만으로 알리지 않는다 — 체크는 형태이므로 색을 지워도 남는다.

### StadiumFairy48

Pencil이 그린 48px은 **`_Generic`과 `_Mono` 둘뿐이다. 구장별 48px 원본이 없다.**
그래서 작은 크기에서는 구장 특징이 사라지고 홈플레이트만 남으며, 아홉 구장이 똑같아진다.
구장을 구분하는 것은 언제나 곁의 글자다.

기하는 기본 글리프의 48px과 정확히 같다(몸통 8.5,8,31.5,32 선 1.2 · 눈 4×4 · 입 선 1.8).
팀 페어리와 달리 입 viewBox도 96px과 같은 `[41,55,14,7]`로, 좁히지 않았다.
홈플레이트만 다르다 — 96px은 옅은 면에 잉크 외곽선, 48px은 몸 색으로 채우고 외곽선을 뺀다.

미지정만 48px에서도 특징이 없다. 색이 같아지는 모노크롬에서 제네릭과 갈리는 유일한
형태 신호라 그렇게 두었다(원본에 `StadiumFairy48_Unknown`이 없어 파생한 결정이다).

### 뱃지와 컴팩트 행

`StadiumFairy_Badge` — 패딩 6/12/6/8, 간격 8, `$sage-pale` 바탕, 반경 12, 이름 13pt
`$sage`. 선택되면 `$fairyVictory` 2pt 테두리와 체크 16px이 더해진다.

`StadiumFairy_Row` — 폭 300, 패딩 8/14/8/10, 간격 10, `$surface` 바탕에 `$line` 1pt
테두리, 반경 12. 안쪽 텍스트는 세로 간격 1로 이름 14pt `$ink`와 도시 12pt `$ink-faint`,
오른쪽에 네이티브 chevron 16px.

둘 다 `StadiumFairy48_Generic`을 품는다 — 구장이 무엇이든 48px 제네릭이다. 이름이
정체성을 말한다는 규칙이 컴포넌트 구조에 그대로 들어 있다.

이름과 보조 문구는 **부르는 쪽이 준다.** 두 컴포넌트는 구장을 찾지도, 이름을 지어내지도,
탭을 받지도 않는다. 행은 최소 44pt 높이를 지키고 긴 이름은 줄바꿈으로 늘어난다.
Pencil 13pt·14pt 자리는 고정 크기 대신 `footnote`·`subheadline` 역할을 써서 Dynamic
Type을 따른다.

### 라이트 · 다크 · 모노크롬

라이트와 다크는 같은 아트워크다. 모노크롬은 앞선 두 시스템과 **다르다** —
Pencil `StadiumFairy48_Mono`는 회색으로 눕히는 것이 아니라 **잉크 몸에 종이색 얼굴로
뒤집는다.** 다이아몬드만 금색으로 남는다. 우리 규칙을 밀어붙이지 않고 원본을 그대로
따랐다.

### 색 소유권

구장색은 `VFFairyColor.stadium`(= `sage`) 하나다. **아홉 구장에 아홉 색을 만들지
않았다** — Pencil도 그러지 않는다. 구장은 색이 아니라 특징과 곁의 이름으로 갈린다.
미지정만 `VFFairyColor.neutral`을 쓴다. 팀 색·결과 색·브랜드 색은 건드리지 않았다.

### 대비 — 원본 쪽 발견 하나

- 아홉 구장과 제네릭: 얼굴 대비 **4.69:1** (`$fairyFaceOnDark` on `$fairyStadium`)
- 모노크롬: **16.27:1**
- 구장 특징 잉크 선: 어느 몸 위에서든 3:1 이상 (미지정 위에서 5.62:1)
- **미지정: 얼굴 대비 2.88:1** — 비-텍스트 기준 3:1에 0.12 모자란다

마지막 값은 우리가 잘못 옮긴 것이 아니라 **Pencil 원본이 그렇다**
(`$fairyNeutral` #8B909E 몸 + `$fairyFaceOnDark` #F6F3EA 얼굴). 원본을 마음대로 다시
칠하지 않고 그대로 두었고, 대신 값을 테스트에 못박아 더 나빠지면 실패하게 했다.
미지정 페어리는 혼자 뜻을 전하지 않고 "등록되지 않은 구장"과 기록에 적힌 이름이 반드시
곁에 있으므로 정보 접근을 막지는 않는다. 디자인 쪽에서 판단할 항목으로 남긴다.

### 접근성

읽어 줄 문장은 부르는 쪽이 준다. 라벨이 없으면 장식으로 보고 숨긴다 — 뱃지와 행 안에서는
곁의 글자가 이미 구장을 말하므로 그렇게 써야 같은 구장을 두 번 읽지 않는다. 뱃지와 행은
`accessibilityElement(children: .combine)`으로 하나로 읽고, 네이티브 체크와 chevron은
장식이라 숨긴다. `VFStadiumFairy.pairing`은 기반의 `requiresStadiumName`을 따른다.

구장 ID·특징 이름·컴포넌트 이름은 VoiceOver로 새어 나가지 않는다.

### 기본 글리프에 더한 이음새 하나

`VFFairyPaletteOverride` — 기하는 그대로 두고 칠만 바꾸는 최소 이음새다. Pencil에
그런 파생이 실제로 있어서 열었다: `StadiumFairy_Unknown`은 기본 글리프와 같은 몸통에
몸 색만 중립이고, `StadiumFairy48_Mono`는 같은 기하를 잉크·종이로 뒤집는다.
지정하지 않으면 종류와 외형이 정한 색 그대로이므로 `kind.spec(for:)`의 의미는 바뀌지
않는다. 기존 46개 기반 검사가 그대로 통과하는 것으로 확인했다.

### 레거시 VenueGlyph 분류

- Pencil `VenueGlyph_*` 9종 — 문서 안에서 **인스턴스가 0개**다. 새 구장 페어리가
  대신하지만 이번 패스는 `.pen`을 건드리지 않는다
- Swift `VFStadiumGlyph` (`SharedComponents/VFStadiumComponents.swift:30`) —
  **USED_IN_PRODUCTION**. `VFStadiumBadge`, `VFStadiumHero`, 그리고
  `OnboardingView.swift:302`가 실제로 쓴다. 지우지 않았다
- `VFStadiumBadge` · `VFStadiumHero` — USED_IN_PRODUCTION. 새 `VFStadiumFairyBadge`와
  이름이 다르므로 충돌하지 않는다
- 분류: **SAFE_TO_DEPRECATE_LATER**. 교체는 공유 배치 패스의 몫이고, 그전에 지우면
  온보딩 구장 선택이 빈다

### 이번 패스에서 건드리지 않은 것

홈·피드·캘린더·시즌 아카이브·기록 상세·기록 작성·마이·온보딩·팀 선택기,
그리고 현재 제품이 쓰는 구장 컴포넌트(`VFStadiumGlyph`·`VFStadiumBadge`·
`VFStadiumHero`) 모두 그대로다. AppIcon·LaunchMark·픽스처·아카이브 스크립트도 그대로다.
화면과 공용 컴포넌트가 아직 구장 페어리를 쓰지 않는다는 것을 테스트가 확인한다.

`project.pbxproj`는 새 테스트 파일 등록 하나만 더했다.

### 이 패스에서 검사가 잡은 것

1. 프리뷰의 미등록 구장 예시가 "부산 사직 보조구장"이었다. canonical 짧은 이름 "사직"을
   품고 있어 "그리기 소스에 구장 이름을 두지 않는다" 검사가 걸었다. 겹치지 않는 이름으로
   바꿨다.
2. 미지정 얼굴 대비 2.88:1을 4.5:1 일괄 기준이 걸었다. 확인해 보니 원본 값이라,
   기준을 낮춰 덮는 대신 아홉 구장·제네릭과 미지정을 나눠 검사하고 원본 값을 못박았다.

### 다음 패스

`pass/appicon-victory-fairies` — 네 페어리 쿼텟 앱 아이콘. 다만 Monochrome을 네 번째
렌디션으로 낼지, `SplashMark_OnDark`에 남은 V-Wing이 최신인지 두 가지 결정이 아직
열려 있다. 그 두 가지가 정해지기 전이라면 `pass/shared-component-placements`를 먼저
해도 된다.

---

## 개정 Pencil — AppIcon 네 페어리 쿼텟 교체

원본은 앞 절과 같다 — SHA-256
`8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2`, 1,882,899바이트.
수정 시각은 2026-07-30 11:51:46 +0900이며, 해시와 크기가 같으므로 내용은 그대로다.

### 두 보드가 경쟁하던 문제 — 해소

앱 아이콘 1024 프레임을 가진 보드가 둘이었다. 직접 읽어 정리했다.

- **CURRENT — `01_AppIcon_VictoryFairies` (`XjIUP`)**
  프레임에 **배경 fill이 들어 있고**(Default `$fairyIconBg`, Dark `$fairyIconBgDark`,
  Tinted `#000000`), 자식이 25개로 얼굴 레이어까지 갖췄다. 같은 보드의
  `AppIcon_VictoryFairies_ExportHandoff`가 **"플랫 1024 소스는
  AppIcon_VictoryFairies_Default_1024 프레임"**이라고 못박는다. 이것이 production 소스다.
- **SUPERSEDED — `01_Brand_and_AppIcon` (`a8seWk`)**
  `AppIcon_Any_1024` (`Xiqhl`) 등 세 프레임을 갖고 있지만 **프레임 fill이 없고**
  자식이 1개(래퍼 프레임)뿐이다. 이름 규칙(`Any`)과 레이어 수가 새 보드와 어긋난다.
- **VALIDATION_ONLY — `10_Fairy_Validation` (`vnsGp`)**
  어피어런스 네 셀과 소형 사이즈 재검증. 산출물이 아니라 검증 보드다.
- **LEGACY_REFERENCE — `11_Developer_Handoff` (`xpL8P`)**
  아직 `AppIcon_Any_1024` · "5개 레이어"를 적고 있다. 새 보드의 핸드오프 문구와
  충돌하므로 낡은 쪽으로 본다. Pencil은 이번 패스에서 고치지 않았다.

BLOCKING_CONFLICT는 없다. 세 production 렌디션이 하나의 보드에서 모호함 없이 나온다.
상태: **APPICON_SOURCE_RESOLVED**.

### Monochrome 역할 — ICON_COMPOSER_LAYER_REFERENCE

`AppIcon_VictoryFairies_Monochrome` (`VR6X3`)는 **카탈로그 렌디션이 아니다.**

- 자식이 13개뿐이다. 네 페어리(몸·줄기·다이아 ×4 = 12) + 네거티브 스페이스이며
  **얼굴 레이어가 통째로 없다.** 다른 세 프레임은 25개다
- 핸드오프의 Icon Composer 레이어 목록(Background / Fairy_Victory / Fairy_Team /
  Fairy_Stadium / Fairy_Memory / BaseballDiamond_NegativeSpace / FacialMarks)에서
  **FacialMarks만 뺀 모습**과 정확히 일치한다
- Tinted는 `AppIcon_VictoryFairies_Tinted_1024`로 **따로 그려져 있다.** 얼굴이 있고
  흰색 알파 계단(FF / D1 / B3 / 94)을 쓴다. Monochrome은 그 소스가 아니다
- iOS 앱 아이콘 자산 카탈로그가 지원하는 외형 슬롯은 기본 · `luminosity:dark` ·
  `luminosity:tinted` **셋뿐이다.** 네 번째 파일을 넣을 자리가 없다

따라서 Monochrome은 단일 톤 레이어 참고용으로 분류하고 **파일로 내보내지 않았다.**
검증 캡처로만 확인했다.

### 물러난 아이콘

교체 전 실려 있던 V-Wing 세대의 SHA-256을 남긴다.

- Default `323baf6d55a97e75ff0b68d125ce2d53ed7174e4da8aa26850c47eb8b75f6507`
- Dark `9bac8cda2f812b082a07d43adddce2b5c3455321557a3da0c02a0fc4fedc9a50`
- Tinted `80e31400b494f67d72e25ae35e61c141882afaa45891a0d26ea8dbb798a26fca`

그 이전 산호색 세대 `64be923a2f82c4b3a46d2ccfd040a145ed95bd1bb8f76872ac3fba0a08c0b17e`도
함께 금지 목록에 남긴다. 셋 다 1024×1024 · 알파 없음이었다.

### 새 production 렌디션

Pencil 노드에서 `export_nodes` scale 1로 내보낸 뒤 알파 채널만 제거했다.

- `AppIcon-1024.png` ← `AppIcon_VictoryFairies_Default_1024` (`ZCOI9`)
  SHA-256 `43323e1a2948fc7e14c8aa4f0f4ad85da3606a410a5a609c582f79d134c0c9b8`
- `AppIcon-1024-Dark.png` ← `AppIcon_VictoryFairies_Dark_1024` (`NHBAs`)
  SHA-256 `6fde4d723d04def12e96d59da04824f603e2b53c00947364dd79c65c8c4a370d`
- `AppIcon-1024-Tinted.png` ← `AppIcon_VictoryFairies_Tinted_1024` (`nN1Mw`)
  SHA-256 `ed4672b6bfc7070d668cda0c2c73ae375def52174bf5fb5b247c904e82d32692`

세 파일 모두 1024×1024 · `hasAlpha: no` · PNG. `Contents.json`은 파일 이름과 외형
매핑이 그대로라 **바꾸지 않았다.**

Dark는 Default의 복사본이 아니다. 배경만 `#0E1526` → `#070C16`으로 갈리며, Pencil이
의도적으로 그렇게 그렸다. 세 해시가 서로 다른 것을 스크립트가 확인한다.

### 내보내기와 알파

Pencil 내보내기는 알파 채널을 붙이지만 **실제로는 완전 불투명**이었다 —
`alphaMin=255`, 비-불투명 픽셀 0개. macOS에 PIL·Quartz·ImageMagick이 없고 `sips`는
알파를 지우지 못해, 순수 파이썬 PNG 디코더/인코더로 채널만 떼어 RGB로 다시 썼다.
**RGB 픽셀은 한 개도 바뀌지 않았다**(세 파일 모두 differing px = 0).

### 전체 출혈과 라운드 코너

- 네 코너 픽셀이 모두 배경색과 정확히 일치한다 (Default `(14,21,38)`,
  Dark `(7,12,22)`, Tinted `(0,0,0)`)
- 가장자리를 훑어 배경이 아닌 픽셀 **0개**
- 알파가 없으므로 투명 여백도, 투명하게 깎인 코너도 있을 수 없다

라운드 코너를 굽지 않았고 세이프 마진을 따로 넣지도 않았다. 핸드오프 규칙
"라운드 코너 미적용(시스템 마스크)"과 "외부 그림자 없음"을 그대로 지킨다.

### 소형 크기

1024 / 120 / 60 / 40 / 29 / 20 / 16에서 세 렌디션을 모두 측정하고 눈으로 봤다.

- 모든 크기에서 네 페어리 몸 색이 남는다 (4/4)
- 모든 크기에서 중앙 네거티브 스페이스가 배경색으로 뚫려 있다
- 모든 크기에서 코너가 배경색이다
- 29px에서 네 형상과 다이아몬드가 하나의 마크로 읽힌다
- 20px 아래부터 표정이 자연스럽게 사라진다 — Pencil 검증 항목
  "29px에서 4형상+다이아몬드 유지, 표정은 자연 소실 (16px는 실루엣만)" 그대로다

### 시스템 마스크

Default를 256px로 줄여 마스크별로 잘려 나가는 페어리 픽셀을 셌다.

- 표준 스퀘어클(n=5): **0.00%** — 네 페어리 모두 손실 없음
- 크게 자른 프리뷰(n=8): **0.00%**
- 원형: 최대 1.25% (Victory 안테나 끝만 스침). 몸이나 얼굴은 잘리지 않는다

원형은 iOS 홈 화면 마스크가 아니며, 스치는 것은 안테나 팁뿐이다. 라이트 · 다크 ·
컬러풀 배경화면 위에서도 확인했다.

### 그레이스케일과 틴트

세 렌디션 모두 색을 지워도 네 형상이 밝기로 갈린다. Tinted는 밝기 계단이 가장 넓다 —
순검정과 순백을 모두 포함하고, 네 몸이 `FF / D1 / B3 / 94`로 나뉜다.

Tinted에 잉크 외곽선(`$line-ink` #232A3C)이 남아 있다. 이는 Pencil이 Default와
**동일하게 그린 것**이지 내보내기 사고가 아니다. 휘도가 사실상 검정이라 시스템이
휘도로 틴트를 만들 때 배경과 함께 묻히며, 회색 몸과 검은 배경 사이 경계 역할만 한다.

### verify_app_icon.sh 갱신

낡은 전제를 걷어내고, **"예전 것이 아님"이 아니라 "지금 것이 맞음"**을 확인하도록 바꿨다.

- 소스 보드 참조를 `01_Brand_and_AppIcon` → `01_AppIcon_VictoryFairies`로
- `EXPECTED_DEFAULT_SHA` · `EXPECTED_DARK_SHA` · `EXPECTED_TINTED_SHA` 추가.
  아이콘이 통째로 빠져도 통과하지 않는다
- `RETIRED_CORAL_SHA` + `RETIRED_VWING_*` 세 개를 금지 목록으로
- 렌디션 수가 정확히 셋인지 (네 번째 금지)
- 파일 이름 집합이 정확한지
- dark · tinted 외형 매핑이 있는지
- 셋 다 1024×1024이고 알파가 없는지
- 카탈로그가 참조하지 않는 아이콘 파일이 남아 있지 않은지
- 세 렌디션이 서로 다른 파일인지 (Dark가 Default를 베끼면 실패)

게이트를 양쪽으로 확인했다. 쿼텟에서는 통과하고, V-Wing Default를 되돌려 놓으면
두 가지 이유로 실패한다.

코너 픽셀·전체 출혈·중앙 네거티브 스페이스처럼 픽셀을 읽어야 하는 검사는 sips가
답하지 못하므로 `AppIconContractTests`가 CGImage로 맡는다.

### 자산 카탈로그

`AppIcon.appiconset` 하나, 렌디션 셋, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`,
대체 아이콘 설정 없음 — 모두 그대로다. `Contents.json`은 손대지 않았다.

번들 식별자 · 마케팅 버전 1.1.0 · 빌드 번호 · 서명 설정도 바꾸지 않았다.

### 이번 패스에서 건드리지 않은 것

**LaunchMark는 그대로다.** 아직 V-Wing 마크이며
SHA-256 `2b60eeb3fc21148e5273a014ecf89b2666781183e3897a209ba4049ae5ce3528`로 못박아
두었다. 다음 패스에서 쿼텟으로 바꿀 때 이 해시도 함께 갱신해야 한다.
`LaunchBackground`와 `UILaunchScreen`도 그대로다.

화면 소스, 페어리·팀 페어리·구장 페어리 시스템, 픽스처, 도메인, 저장소, API도
모두 그대로다.

### 다음 패스

`pass/launch-mark-quartet` — `LaunchScreen_Light` / `LaunchScreen_Dark`의
`런치 마크 쿼텟`을 `LaunchMark.pdf`로 옮긴다. 그 보드의 `SplashMark_OnDark`에 아직
V-Wing이 남아 있어, 온다크 스플래시 마크가 최신인지 먼저 확인해야 한다.

---

## 개정 Pencil — LaunchMark 쿼텟 교체

원본은 앞 절과 같다 — SHA-256
`8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2`, 1,882,899바이트,
수정 시각 2026-07-30 11:51:46 +0900. 해시와 크기가 같으므로 내용은 그대로다.

### 읽은 보드

`01_Launch_and_Splash` (`r4MPjp`) — 자식 넷.

- `SplashMark_시트` (`PiKOI`) — 핸드오프 시트. 안에 `마크 프리뷰`가 있고
  라이트 칸은 `프리뷰 마크 쿼텟` (`HOAkt`, 140×140, 자식 25), 다크 칸은
  `SplashMark_OnDark` (`nPZGr`, 140×128.3, **자식 3**)
- `LaunchScreen_Light` (`wI81v`) 300×650, 배경 `$paper`, 안에 `런치 마크 쿼텟`
  (`i00UgJ`, 76×76, 자식 25)
- `LaunchScreen_Dark` (`XSoYU`) 300×650, 배경 `$night`, 안에 `런치 마크 쿼텟`
  (`ATfKL`, 76×76, 자식 25)
- `BrandSplash_Optional` (`nYDh8`) — 스스로 "선택적 브랜드 전환"이라고 적어 둔
  선택 사항. 런치 화면이 아니다

### 소스 충돌 해소 — LAUNCHMARK_SOURCE_RESOLVED

- **CURRENT_PRODUCTION_SOURCE** — `LaunchScreen_Light > 런치 마크 쿼텟` (`i00UgJ`)
- **CURRENT_APPEARANCE_VARIANT** — `LaunchScreen_Dark > 런치 마크 쿼텟` (`ATfKL`)
- **VALIDATION_ONLY** — `프리뷰 마크 쿼텟` (`HOAkt`). 140×140 핸드오프 프리뷰
- **SUPERSEDED_VWING_SOURCE** — `SplashMark_OnDark` (`nPZGr`). 자식이 셋뿐이고
  그 셋이 `V`(금색 그라디언트) · `Ball` · `Seams`다. 물러난 V-Wing이며 쓰지 않는다
- **LEGACY_REFERENCE** — `00_Cover_and_Direction`의 "승리 부적(V-윙) 아이덴티티" 문구
- **SHARED_MARK_SOURCE** — `BrandMark_FairyQuartet` (`nl01N`). 같은 쿼텟 계열이지만
  150×150이라 런치 규격이 아니다

BLOCKING_CONFLICT는 없다. 다크 스플래시 마크 하나가 낡았다고 해서 쿼텟이 흔들리지
않는다 — 실제 런치 화면 프레임 **둘 다** 쿼텟을 쓰고, 앞 패스에서 검증한 AppIcon도
쿼텟이다. 물러난 V-Wing은 `SplashMark_OnDark` 한 곳에만 남아 있다.

### 크기는 추론하지 않았다 — 핸드오프가 못박는다

`11_Developer_Handoff`가 스플래시 항목에서 직접 적는다.

> • SplashMark — SVG/PDF 단일 스케일 · transparent · 벡터 · 텍스트 없음
> • LaunchScreen_Light/Dark — 배경 토큰 + **76pt 마크만** · 마케팅 카피 금지

그래서 마크는 **76pt**다. 물러난 V-Wing은 100×92.1pt였는데, Pencil 프레임 비율
(76/300 = 25.3%)을 실기 폭에 맞춰 키운 값으로 보인다. 이번에는 비율을 추론하지 않고
핸드오프가 적어 둔 76pt를 그대로 썼다.

이 핸드오프 보드는 AppIcon 익스포트 이름에 대해서는 낡았지만(앞 절 참고) **런치
스펙에 대해서는 현행**이다. `LaunchScreen_Light/Dark`라는 현재 프레임 이름을 쓰고
76pt가 실제 노드와 정확히 맞는다. 보드 전체를 한 덩어리로 낡았다고 보지 않고
항목별로 판단했다.

### 라이트/다크 계약 — APPEARANCE_SPECIFIC_MARKS

두 런치 마크를 자식 단위로 비교했더니 **25개 중 13개가 다르다.** 다른 것은 정확히
네거티브 스페이스 다이아몬드와 모든 얼굴 자국이며, 그 칠이 배경색으로 도려내져 있다 —
라이트는 `$paper`, 다크는 `$night`. 나머지 12개(네 몸통·줄기·다이아몬드)는 같다.

즉 이 마크는 투명 도려내기가 아니라 **배경색 도려내기**로 그려졌다. 하나의 자산을
공유하면 어느 한쪽 배경에서 다이아몬드와 얼굴이 어긋난다. 그래서 두 소스를 각각
내보내고 자산 카탈로그 외형으로 매핑했다.

투명 도려내기로 "고쳐서" 하나로 합칠 수도 있었지만 그것은 원본을 다시 그리는 것이라
하지 않았다. Pencil이 라이트와 다크를 **각각 완성된 소스로** 그려 두었으므로 그대로 쓴다.

### 내보낸 파일

- `LaunchMark.pdf` ← `i00UgJ` (라이트)
  SHA-256 `7b73585aa1538d03f68461a34bdcefa89fdc6319997175cf41efb94e76f366df`
- `LaunchMark-Dark.pdf` ← `ATfKL` (다크)
  SHA-256 `3961018e70d79755433e84f5c361de8b25ee2947c63f421e4b88ec2742a0935e`

물러난 V-Wing 런치 마크 SHA-256
`2b60eeb3fc21148e5273a014ecf89b2666781183e3897a209ba4049ae5ce3528` —
스크립트와 테스트의 금지 목록에 남겼다.

### 벡터 PDF 증거

두 파일 모두 확인했다.

- 페이지 **1개**, `/Count 1`
- MediaBox `[0 0 76 76]`, CropBox 없음(MediaBox와 동일)
- `/Subtype /Image` **0개** — 전면 래스터 없음
- `/Type /Font` · `/BaseFont` **0개**, 텍스트 연산자(`BT`/`Tj`/`TJ`) **0개**
- 벡터 연산자 m=41 · l=95 · c=412 · fill=34 — 자식 25개 쿼텟에 맞는 양
- 자산 카탈로그 `preserves-vector-representation: true` 유지

컴파일된 `Assets.car`에서 `LaunchMark`가 **Image와 Vector 두 타입으로** 들어 있는 것을
확인했다. 확장자만 보고 벡터라고 말하지 않았다.

### 중앙 네거티브 스페이스와 광학 중심

렌더해서 쟀다. 두 마크의 경계 상자와 중심이 픽셀 단위로 같고(bbox (26,32)-(582,560),
중심 304,296), 라이트는 중앙이 `$paper`, 다크는 `$night`로 뚫려 있다. 실기 콜드런치
캡처에서도 마크 중심이 화면의 (50.0%, 49.8%)에 온다.

### 자산 카탈로그

`LaunchMark.imageset`에 두 항목을 두고 기본/`luminosity: dark`로 매핑했다.
`preserves-vector-representation`과 `template-rendering-intent: original`은 그대로다.
이미지 세트 이름 `LaunchMark`도 그대로라 `UILaunchScreen` 참조를 바꾸지 않았다.

### LaunchBackground — UNCHANGED_AND_CURRENT

건드리지 않았다. 현재 값이 Pencil 런치 프레임과 이미 정확히 맞는다 —
라이트 `#F4F4F2`(`$paper`), 다크 `#0E1526`(`$night`). 테스트가 네 채널을 직접 확인한다.

### 네이티브 런치 소유권 — 그리고 이 패스가 발견한 것

`UILaunchScreen`이 `UIImageName: LaunchMark` · `UIColorName: LaunchBackground`로
런치 화면을 소유한다. 인위적 지연도, 전체 화면 스플래시 뷰도 없다.

새 게이트를 처음 돌렸을 때 "런타임이 런치 자산을 그린다"고 걸렸다. 확인해 보니
`VFBrandMark`(`SharedComponents/VFStadiumComponents.swift:10`)가 `Image("LaunchMark")`를
쓰고 있었고, 스스로 **"런치 화면과 앱 안이 어긋나지 않게 한다"**고 적어 두었다.
온보딩 두 곳(`OnboardingView.swift:72`, `:369`)에서 실제 콘텐츠로 쓰인다.

이것은 가짜 스플래시가 아니라 **의도된 공유**다. 그래서 규칙을 "런치 자산 참조 금지"에서
**"문서화된 공유 브랜드 마크 한 곳으로 제한"**으로 좁혔다. 앱 진입점(`VictoryFairyApp`,
`AppRootView`)이 런치 자산을 그리는 것과 전체 화면 스플래시 뷰 타입은 여전히 금지한다.

**따라온 결과를 분명히 적는다.** 런치 자산을 바꾸었으므로 온보딩 안의 브랜드 마크도
V-Wing에서 쿼텟으로 함께 바뀐다. 화면 소스는 한 줄도 고치지 않았고, 이것은 그 컴포넌트가
존재하는 이유 그대로다 — 오히려 런치는 쿼텟인데 온보딩만 V-Wing으로 남는 쪽이 결함이다.

### 콜드런치 증거

`simctl launch --wait-for-debugger`로 프로세스를 main() 전에 붙잡아 **네이티브 런치
화면이 화면에 떠 있는 동안** 캡처했다. 웜런치도, 앱 루트가 뜬 뒤의 화면도 아니다.
각 회차마다 앱을 지우고 다시 설치해 콜드 상태를 만들었다.

- iPhone 17 Pro (iOS 26.3) · 라이트 · 클린 설치 — 쿼텟, 배경 `paper`,
  마크 중심 (49.9%, 49.9%)
- iPhone 17 Pro (iOS 26.3) · 다크 · 클린 설치 — 쿼텟, 배경 `night`,
  마크 중심 (50.0%, 49.8%)
- VF-CalendarCompact-SE3 (iOS 26.3, 375pt) · 라이트 · 클린 설치 — 쿼텟, 잘림 없음
- VF-CalendarCompact-SE3 (iOS 26.3, 375pt) · 다크 · 클린 설치 — 쿼텟, 잘림 없음

반복 실행으로 스냅샷 캐시도 확인했다. 라이트는 콜드와 반복 캡처가 **바이트 단위로
동일**하고, 다크는 상태 표시줄 밴드에서만 0.017% 다르며 **마크 밴드는 차이 0**이다.
낡은 V-Wing 스냅샷이 남아 있지 않다.

앱 루트 전환도 확인했다. 런치 뒤 온보딩 화면이 정상으로 뜨고, 런치 이미지가 오버레이로
남지 않으며, 배경 소유권이 어긋나서 생기는 흰/검은 번쩍임이 없다.

### AppIcon 회귀

이번 패스에서 AppIcon은 손대지 않았다. 세 해시가 그대로다 —
Default `43323e1a…`, Dark `6fde4d72…`, Tinted `ed4672b6…`. `verify_app_icon.sh`가
통과하고 `AppIconContractTests`도 통과한다. 아카이브에도 쿼텟 아이콘이 그대로 있다.

### 이번 패스에서 건드리지 않은 것

화면 소스, 페어리·팀 페어리·구장 페어리 시스템, AppIcon 자산과 스크립트, 픽스처,
도메인, 저장소, API. 번들 식별자 · 마케팅 버전 1.1.0 · 빌드 번호 · 서명 설정도 그대로다.

### 서명 한계

아카이브는 `CODE_SIGNING_ALLOWED=NO`로 만든 **미서명** 결과물이다. 구조는 확인했지만
App Store 배포 서명을 검증했다고 말할 수 없다.

### 다음 패스

`pass/shared-fairy-placements` — `VFTeamIdentityHeader`의 팀 심볼을 `TeamFairy48`로,
빈/오류 패널에 상태 페어리를, 그리고 기존 구장 컴포넌트를 구장 페어리로 옮긴다.
화면 배치는 아직 시작하지 않았다.

## 개정 Pencil — 완료 화면 페어리 배치

### 원본 확인

- SHA-256 `8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2`
- 1,882,899 bytes · mtime 2026-07-30 11:51:46 +0900
- 앞선 패스와 해시·크기가 같다. 내용이 바뀌지 않았다.

읽은 방법은 `get_app_state`와 `execute`의 `Get`(방문자 · `ctx.bounds`)뿐이다.
`get_editor_state` · `get_variables` · `batch_get` · `snapshot_layout`은 쓰지 않았다.

### 배치 노드 — 이름으로 다시 찾은 결과

문서 전체에서 이름에 "페어리/Fairy"가 들어간 노드는 564개다. 그중 **제품 화면에
실제로 놓인 인스턴스**는 아홉 개뿐이고, 나머지는 시스템 보드·검증 보드의 견본이다.

- `HdPbE` `팀 페어리` — `03_Shared_Components / TeamIdentityHeader`, 컴포넌트 `TeamFairy48`,
  48×48, 팀 레일(4×44) 오른쪽 x=32, 팀 텍스트는 x=92에서 시작한다.
- `YHevI` `선택 팀 페어리` — `04_Onboarding / Onboarding_05_Complete / 선택 확인`,
  컴포넌트 `TeamFairy_Samsung`(원본 표본), 96×96.
- `H3Vdn5` `완료 성공 페어리` — `Onboarding_05_Complete`, 컴포넌트 `FairyGlyph_Success`,
  96×96, 프레임 안 x=148 y=162.
- `MvVQp` `선택일 승리 페어리` — `06_Calendar_Month_GameSelected / 캘린더 콘텐츠 /
  선택일 미리보기`, 컴포넌트 `Fairy48_Victory`, 48×48, x=311 y=-12.
- `RCWPd` `시즌 시그니처 페어리` — `07_Statistics_SeasonArchive / 시즌 콘텐츠 / 시즌 커버`,
  컴포넌트 `Fairy48_Victory`, 48×48, x=297 y=12.
- `k6E0mo` `빈 기록 페어리` — `09_States / 열 A / 빈 기록`, `FairyGlyph_Empty`, 96×96.
- `qjpbO` `시즌 전 페어리` — `09_States / 열 A / 빈 시즌`, `Fairy48_Empty`, 48×48.
- `r7Eyoc` `오류 페어리` — `09_States / 열 B / 오류`, `Fairy48_Error`, 48×48.
- `dsu6v` `선택 팀 페어리` — `08_TeamSelector / 온보딩 콘텐츠 / 선택 팀 프리뷰`,
  `TeamFairy48`. **이번 패스 범위 밖**이라 놓지 않았다(Team Selector 미착수).

### TeamIdentityHeader 이관

`VFTeamIdentityHeader`의 팀 심볼을 이니셜 뱃지에서 `TeamFairy48`로 옮겼다.

- `VFTeamFairy(teamID: team.id, size: .compact)` — canonical 팀 ID가 정체성을 정한다.
- 열 개 구단 모두 서로 다른 특징(trait)으로 떨어진다. 중립으로 새는 팀이 없다.
- 팀 조회·이동·팀 이름은 헤더가 그대로 갖는다. 페어리는 그리기만 한다.
- 헤더가 `children: .ignore`로 팀 이름을 한 번만 읽어 주고, 페어리는 숨긴다.
  같은 팀을 두 번 말하지 않는다.
- 홈은 이 공용 헤더 하나만 물려받는다. 홈 소스에는 페어리 호출이 없다.

중립 상태는 정직하게 남는다 — 팀 ID가 없거나 등록부에 없으면 `.neutral`이고,
`VFTeamFairy.pairing == .requiresTeamName` 계약도 그대로다.

### 구장 페어리 — 공용 배치 없음

`VFStadiumFairy` · `VFStadiumFairyBadge` · `VFStadiumFairyRow`는 어떤 제품 화면에도
넣지 않았다. 원본이 이 컴포넌트들을 구장 페어리 시스템 보드와 검증 보드 안에서만
쓰기 때문이다. 일괄 치환은 하지 않았고, 화면별 판정은 다음과 같다.

- 기록 상세의 구장 표현 — `KEEP_LEGACY_GLYPH_FOR_CURRENT_FRAME`
- 홈 경기 스트립 · 구장 뱃지 · 구장 히어로 — `KEEP_LEGACY_GLYPH_FOR_CURRENT_FRAME`
- 온보딩 구장 카드 — `KEEP_LEGACY_GLYPH_FOR_CURRENT_FRAME`
- 09_States 구장 바텀시트 — 이번 패스 범위 밖

기록에 적힌 구장이 언제나 권위를 갖는다. 주 관람 구장·팀 홈 구장·마지막 구장·
제네릭 구장 어느 것도 기록 구장의 대체가 되지 않는다. 이름이 비면 "구장 없음"이고
등록부에 없으면 "미지정"이다. 둘은 계속 다른 상태다.

### 기존 `VFStadiumGlyph` 상태 — STILL_REQUIRED

실사용처가 남아 있다. `VFStadiumGlyph` · `VFStadiumBadge` · `VFStadiumHero`는 홈·
캘린더·기록 상세·온보딩이 계속 쓴다. 참조가 0이 아니므로 지우지 않는다. Pencil의
`VenueGlyph_*` 컴포넌트도 그대로 둔다(문서는 읽기 전용이다).

### 온보딩 완료 배치

`VFBrandMark` 아래에 두 페어리를 나란히 놓았다.

- 선택 팀 페어리 — `VFTeamFairy(teamID: viewModel.selectedTeamID)` 96×96.
  원본은 삼성 표본을 그려 두었지만 **고른 팀**으로 그린다. 아직 모르면 중립이다.
- 완료 성공 페어리 — `VFFairyGlyph(.success)` 96×96.

둘 다 장식으로 숨긴다. "준비됐어요"와 팀·구장 이름이 이미 완료와 선택을 말한다.
완료 제목·요약·CTA·오류 문구·이전으로 버튼은 그대로다. 다섯 단계 구조, 탭바 없음,
저장 동작, 홈 전환도 그대로다.

### 온보딩 건너뛴 테스트 재진단

앞선 설명("소개 단계가 사라졌다", "`onboarding.overview.next`가 없다")은 틀렸다.
그 가드를 걷어내고 실제로 돌려 보니 **건너뛰기가 아니라 실패**였고, 원인은 두 개였다.

1. `FIXTURE_ACTIVATION_DEFECT` — `-VFUITestReset`이 실제로 지우지 못했다.
   시뮬레이터에는 앱 컨테이너 밖(`<device>/data/Library/Preferences/<bundle>.plist`)에
   같은 번들 ID의 값이 남아 있었다(`favoriteTeamID=kia-tigers`,
   `hasCompletedOnboarding=false`, 2026-07-28 12:05 기록). 샌드박스 안에서 하는
   `removeObject`는 앱 자신의 도메인만 지우므로 이 값이 계속 살아남아, "첫 실행"이
   구장 보완 단계로 시작했다. 앱을 지우고 다시 설치해도 그대로였고, 그 plist를
   지운 뒤 시뮬레이터를 재시동하고 나서야 환영 화면이 나왔다.
   → `VFUITestConfiguration.maskResidualValues(in:)`을 더했다. 지운 뒤에도 값이 보이면
   앱 도메인에 "비어 있음"에 해당하는 값을 직접 써서 아래 도메인을 가린다.
   `UserPreferencesStore`는 빈 문자열을 값 없음으로 읽는다.
   증거: 그 잔재를 일부러 다시 심고(`simctl spawn defaults write`) 돌렸을 때
   `test01`·`test09`가 통과한다.

2. `IDENTIFIER_DEFECT` — 다섯 단계 컨테이너 식별자가 접근성 트리에 없었다.
   `OnboardingView`의 바깥 VStack이 `onboarding.root` 식별자를 갖고 있었고, 화면을
   가득 채우는 두 컨테이너가 하나로 합쳐지면서 바깥 식별자가 이겼다. 실제 트리에
   `onboarding.welcome`이 아예 없었다(접근성 스냅샷으로 확인).
   `.accessibilityElement(children: .contain)`을 떼면 이번에는 `onboarding.root`가
   자식마다 덮어써 `onboarding.welcome.start`까지 사라졌다(역시 스냅샷으로 확인).
   → 단계 컨테이너의 `children: .contain`은 그대로 두고, 아무도 참조하지 않던
   `onboarding.root` 식별자를 걷어냈다. 온보딩 루트는 언제나 다섯 단계 중 하나이므로
   단계 식별자가 루트 식별자 역할을 하고, 어느 단계인지까지 알려준다.

3. `FLOW_STATE_DEFECT` — 보완 단계에 도달할 수 없었다.
   `AppRootView`가 `hasCompletedOnboarding` 하나만 보고 갈림길을 정해서, 완료 표시가
   있지만 팀이나 구장이 빠졌거나 유효하지 않은 기존 설치본이 곧장 홈으로 들어갔다.
   `onboardingEntry`가 이미 그 경우를 `repairTeam`·`repairStadium`으로 나눠 두고
   `UserPreferencesStore` 단위 테스트가 그 뜻을 못박고 있는데, 화면이 그 값을 쓰지
   않았다. → `AppRootView`가 `onboardingEntry == .completed`로 판단하도록 고쳤다.
   완료 플래그는 프로필 동기화 DTO에도 실리므로 `migrateOnboardingIfSatisfied()`를
   루트의 `.task`에서 계속 승격한다.

세 원인 모두 해결한 뒤 온보딩 UI 15개가 **모두 통과**한다(실행 15 · 성공 15 ·
실패 0 · 건너뜀 0). 어떤 단정도 약하게 만들지 않았고, 실패를 건너뛰기로 바꾸지 않았다.

### 캘린더 배치 — 결과 정체성

원본 노드 이름이 `선택일 승리 페어리`다. 시즌 커버 쪽이 같은 컴포넌트를
`시즌 시그니처 페어리`라고 부르는 것과 대비된다. 즉 이 자리는 **선택한 기록의 결과**를
가리키는 `RESULT_IDENTITY`이고, 원본이 승리 표본을 그려 둔 것뿐이다.

`CalendarResultFairy.kind(for:)`가 결과를 페어리로 옮긴다 —
승 → `.victory`, 패 → `.loss`, 무 → `.draw`, 취소 → `.cancelled`. 네 결과가 서로
다른 페어리를 쓴다. 기록이 없는 날에는 아무것도 그리지 않는다. 지거나 비긴 날에
승리 페어리를 띄우지 않는다.

날짜 칸에는 페어리를 넣지 않았다. 달 이동·날짜 선택·기록 순서·탭바·좁은 폭·
큰 글자 배치는 그대로다. 선택일 컨테이너는 `children: .contain`으로 담는 요소를
먼저 만든 다음 이름을 붙여서, 안쪽 식별자
(`calendar.detailHeader` · `calendar.detailRecord` · `calendar.detailEventCount` ·
`calendar.detailEmpty` · `calendar.detailAddRecord`)가 모두 살아 있다.

### 시즌 아카이브 배치 — 브랜드 시그니처

`시즌 시그니처 페어리`는 이름 그대로 상수 브랜드 표식이다. 결과에 따라 바꾸지
않고 VoiceOver에서 숨긴다. 지는 시즌에 "승리"라고 읽어 주면 계산된 전적과 정면으로
어긋난다. 실제 성적은 헤드라인·승률·전적이 이미 말한다.

커버 오른쪽 위 모서리에 얹는다(원본 361×246 안에서 x=297 y=12 → 오른쪽 16 · 위 12).
`커버 반짝`은 왼쪽 아래에 그대로 남는다. 페어리가 반짝을 대체하지 않는다.
계산·헤드라인·승률·팀 정체성·타임라인·구장 분석은 손대지 않았다.

### 공용 상태 패널 슬롯

`VFEmptyStatePanel`과 `VFErrorPanel`에 **선택적인 의미 슬롯** `VFStatePanelFairy`를
더했다. 두 번째 상태 패널 틀을 만들지 않았다.

- `빈 기록` → `.emptyRecord` = `FairyGlyph_Empty` 96
- `빈 시즌` → `.emptySeason` = `Fairy48_Empty` 48
- `오류` → `.error` = `Fairy48_Error` 48

슬롯은 없음 · 장식 · 호출부가 준 라벨을 가진 의미 요소를 모두 표현한다. 기능별
문구를 일반 패널에 박아 넣지 않았다.

### 페어리를 두지 않은 상태

원본 `09_States`를 다시 훑어 확인했다. 페어리가 있는 프레임은 `빈 기록` ·
`빈 시즌` · `오류` 세 개뿐이다. 다음은 원본에 없으므로 코드에도 없다 —
`검색 없음`(돋보기 아이콘 그대로) · `로딩` · `입력 오류 필드` · `삭제 다이얼로그` ·
`토스트` · `구장 바텀시트` · `추억 카드`. 피드의 필터 결과 0건도 `검색 없음`에
해당하므로 페어리 자리를 비워 둔다.

### 화면당 페어리 밀도

- 홈 1(공용 헤더) · 온보딩 완료 2 · 캘린더 1 · 시즌 아카이브 1 · 상태 패널 1
- 모두 `VFFairyIconPolicy.maximumFairiesPerScreen`(3) 이하다.
- 카드마다·날짜 칸마다 얼굴을 넣지 않았다.
- 네이티브 유틸리티(뒤로·닫기·편집·삭제·설정·꺾쇠·더보기·재시도·카메라·사진
  선택·달 이동·선택 체크·파괴적 동작)는 모두 네이티브 그대로다.

### 접근성 소유권

새로 놓은 페어리는 전부 장식이라 `accessibilityHidden(true)`다. 식별자를 먼저
붙이고 그 다음에 감춘다 — 순서를 바꾸면(감춘 뒤 식별자) SwiftUI가 이름만 있고 읽을
것은 없는 요소를 새로 만든다.

측정해 보니 감춘 뒤에도 식별자를 가진 요소가 XCUITest 트리에는 남는다. 다만
**라벨이 비어 있어서 VoiceOver가 읽어 줄 것이 없다**. 그래서 UI 테스트는 "없다"가
아니라 "자리에 있고 말은 없다"로 확인한다 — `home.teamFairy` ·
`calendar.selectedDate.fairy` · `statistics.seasonCover.fairy` · `state.empty.fairy` ·
`state.emptySeason.fairy` · `state.error.fairy` · `brand.mark`. 스크롤 컨테이너 안에
있는 온보딩 완료 화면의 두 페어리와 브랜드 마크는 요소로 올라오지 않아, 배치 자체는
계약 테스트와 화면 캡처로 확인하고 UI 테스트는 "말하지 않는다"만 못박는다.

작업 중 발견해 고친 접근성 결함 두 개:

- **브랜드 마크가 자산 이름을 읽었다.** `Image("LaunchMark")`는 자산 이름을 그대로
  라벨로 삼아 VoiceOver가 "LaunchMark"라고 읽었다(`accessibilityHidden(true)`가
  붙어 있어도 그랬다). `Image(decorative: "LaunchMark")`로 바꿔 라벨 자체를 없앴다.
  같은 런치 자산을 그대로 쓰므로 사본은 생기지 않는다.
- **AccessibilityXXXL에서 온보딩 소개의 "다음"이 화면 밖으로 나갔다.** 한 덩어리
  VStack이라 버튼이 y≈942(화면 874)로 밀렸고 스크롤도 되지 않아 다음 단계로 갈
  방법이 없었다. 내용을 `ScrollView`에 싣고 버튼을 아래에 고정했다. 완료 화면도
  96px 페어리 두 개가 들어오면서 같은 위험이 있어 같은 구조로 바꿨다.

읽는 순서는 제목 → 설명 → 동작이다. 다시 시도와 빈 상태 CTA는 네이티브 버튼으로
남고, 페어리 자체에는 어떤 동작도 걸지 않았다. 페어리 열거 이름·컴포넌트 이름·
픽스처 이름·자산 이름은 VoiceOver에 닿지 않는다.

### 의도한 차이

- **캘린더 결과 페어리 위치.** 원본은 x=311 y=-12에 놓아 `더보기`(자세히) 컨트롤
  (x=309 y=2 52×19)을 덮고, Pencil 자신이 그 노드를 `partially clipped`로 표시한다.
  그대로 옮기면 네이티브 컨트롤을 가리게 되므로, 같은 오른쪽 정렬을 유지하되 기록
  카드 아래에 둔다. 잘리지 않고 아무 컨트롤도 가리지 않는다.
- **온보딩 완료의 선택 팀 페어리.** 원본은 `TeamFairy_Samsung` 인스턴스다. 표본을
  옮기지 않고 고른 팀으로 그린다.
- **`onboarding.root` 식별자 제거.** 위의 재진단 참조.

### 다크 표면

이번 패스는 프로젝트 전체 다크 모드 이관이 아니다. 이미 구현된 페어리의 밝음/어두움
동작과 기존 화면 표면만 쓴다. 온보딩 완료(야간 표면)와 시즌 커버(`deepAccent`)에서
새 배치가 읽히는지 확인했다. 프로젝트 전체 다크 외형은 남은 과제로 둔다.
