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

### 남은 것

- **사진 콜라주** — Pencil `사진 콜라주` 자리는 비어 있다. 시즌 대표 사진을 고르는 규칙과
  기록 사진을 읽는 경로가 없다. 피드의 사진 과제와 같은 뿌리다.
- **`MetricCard`·`StatRankingRow`** — 이전 통계 화면만 쓰던 공용 컴포넌트라 지금은 참조가
  없다. 공용 컴포넌트 라이브러리의 일부라 지우지 않았고, 정리는 별도 작업으로 남긴다.
- **다크 모드** — 원본에 다크 변형이 없다는 기존 과제 그대로다. 시즌 커버는 이미 야간
  표면을 쓰지만, 화면 전체의 다크 팔레트는 여전히 없다.
- **`AttendanceLogViewState.ourScore`** — 이름이 "우리 팀 점수"지만 실제로는 응원 팀 점수다.
  API 호환을 위해 그대로 두었고, 최다 점수 차 계산도 이 의미를 그대로 따른다.
