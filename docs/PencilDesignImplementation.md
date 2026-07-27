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
