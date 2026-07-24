# VictoryFairy 클라이언트 성능 리포트

측정 원칙: 추측 금지, 측정 → 수정 → 재측정. 각 항목에 근거 태그를 붙인다.
`[실측(Release/실기기)]` `[실측(Debug/시뮬)]` `[정적]` `[도출]`.

## 측정 환경

| 항목 | 값 |
|---|---|
| 기기 | iPhone 17 Pro 시뮬레이터, iOS 26.4 (실행 후 삭제하는 임시 기기) |
| 빌드 | VictoryFairy-Dev, Debug (요청 수·파동 구조·재렌더 횟수는 최적화 수준과 무관) |
| 백엔드 | 로컬 파이썬 스텁, 응답당 150ms 고정 지연. 정상 shape 응답. 기존 사용자=직관 40건, 신규 사용자=0건 |
| 계측 | 스텁 수신 타임라인(요청 도착 시각), 앱 stdout `_printChanges`/`[API]` 로그, `@Published` didSet 카운터(측정 후 전량 제거) |
| 실기기 | 없음(iPhone 26.2 offline). Release/실기기 항목은 "미측정" |

주의: Dev 빌드는 `fallbackBaseURL`(127.0.0.1) 재시도가 있어 요청 1건당 타임아웃이 8s×2=16s. 프로덕션은 `fallbackBaseURL: nil`이라 8s 1회. 아래 timeout 수치는 Dev 실측과 프로덕션 투영을 함께 표기한다.

---

## 작업 1 — 콜드 스타트 waterfall 병렬화 + 낭비 통계 요청 제거 (커밋 7eeef9a)

`refreshAll`/`refreshContent`의 순차 await를 시즌 확정 체인만 직렬로 남기고 나머지를 `async let`으로 병렬화. `refreshStatistics`는 로컬 기록이 있으면 통계 3요청을 보내지 않음(기존엔 받고 버렸음).

| 지표 | BASELINE(직렬) | 작업1(병렬) | 태그 |
|---|---|---|---|
| 첫 요청→마지막 응답 스팬(150ms 스텁, 40건) | 1.418s | 0.717s | 실측(Debug/시뮬) |
| 콜드 스타트 요청 수(40건) | 11 | 8 | 실측(Debug/시뮬) |
| body 평가(콜드) | 33 | 36 | 실측(Debug/시뮬) |
| serverStatus 변경 | 9 | 9 | 실측(Debug/시뮬) |

body 평가 +3은 병렬화로 `@Published` 쓰기가 다르게 인터리브된 결과. 절대량 미미, 네트워크 스팬 이득이 압도.

---

## 작업 1.5(a) — refreshKBOStandings 분리 (fetch 병렬화)

### 착수 전 코드 의존성 확인 [정적]

`refreshKBOStandings`는 두 부분으로 나뉜다.

| 부분 | 코드 | feedLogs/mergedLogs 의존 |
|---|---|---|
| FETCH | `kboStandingsRepository.fetchStandings(season:)` — season만 사용 | 없음. 병렬화 가능 |
| APPLY | `statistics = applyingKBOStandings(standings, to: statistics)` | `statistics`를 read-modify-write |

즉 순위 조회는 feedLogs와 무관하지만, 반영은 `statistics`(통계 계산 결과)에 얹으므로 통계 계산 이후여야 한다. 그래서 FETCH만 `async let`으로 병렬화하고 APPLY는 `refreshStatistics` 완료 후 호출하도록 `loadKBOStandings`(fetch)/`applyKBOStandings`(apply)로 분리했다. 통째로 async let에 넣으면 `refreshStatistics`와 `statistics` 쓰기가 경합한다.

### 결과 [실측(Debug/시뮬)] — 각 경로 3회 반복

| 경로 | 요청 수 | 스팬 | 통계 요청 |
|---|---|---|---|
| 기존 사용자(40건) run1/2/3 | 8 / 8 / 8 | 0.479 / 0.476 / 0.472s | 0 (스킵) |
| 신규 사용자(0건) run1/2/3 | 11 / 11 / 11 | 0.626 / 0.645 / 0.620s | 3 (정상 발생) |

기존 사용자 스팬이 작업1의 0.717s → **0.476s로 목표 0.5초 통과**. 순위 fetch가 feed와 겹치면서 ~240ms 단축. 신규 사용자는 feed→통계 3요청 직렬(300ms)이 남아 0.62s이고 통계 3요청 순서는 유지된다.

### 콜드 스타트 스팬 종합

| 단계 | 스팬(150ms 스텁, 40건) |
|---|---|
| 원본(직렬) | 1.418s |
| 작업1(요청 병렬 + 통계 스킵) | 0.717s |
| 작업1.5a(+순위 fetch 병렬) | 0.476s |

---

## 작업 1.5(b) — preferences → seasons 직렬 조사 (수정 없음, 보고만)

### 질문에 대한 답 [정적]

1. `/seasons` 응답이 `selectedSeason`을 덮어쓰나, `availableSeasons`만 채우나?
   - 실질적으로 **`availableSeasons`만 채운다.** 덮어쓰기(클램프)는 존재하지만 **죽은 코드**다.
2. 덮어쓴다면 "유효 시즌 클램프"인가?
   - 코드상 의도는 클램프다: `if let currentSeason = response.currentSeason, !availableSeasons.contains(where: { $0.season == selectedSeason }) { selectedSeason = currentSeason }`. "선택 시즌이 목록에 없으면 currentSeason으로 스냅".
   - 그러나 바로 앞줄에서 `availableSeasons = normalizedSeasonOptions(remoteOptions + [SeasonOption(season: selectedSeason, ...)])`로 selectedSeason을 **명시적으로 목록에 추가**한다. `normalizedSeasonOptions`는 season 기준 dedup만 하고 이 항목을 제거하지 않으므로 `availableSeasons.contains(selectedSeason)`은 **항상 true** → 클램프 조건 `!contains`는 **항상 false → 절대 실행되지 않는다.**

### 진짜 직렬 의존 [정적]

클램프가 죽어 있어도 `refreshSeasons`는 `selectedSeason`을 **읽어서** availableSeasons에 넣는다. `syncPreferencesFromServer`가 원격 저장 시즌으로 `selectedSeason`을 갱신하므로, 병렬 실행 시 refreshSeasons가 갱신 전/후 어느 값을 읽는지 비결정적 → availableSeasons에 잘못된 시즌이 들어갈 수 있는 경합. 그래서 현재 두 요청은 직렬이 맞다.

### 제안 (승인 후 착수) [도출]

두 요청을 병렬로 받고, 응답을 모두 받은 뒤 단일 후처리로 (1) preferences에서 selectedSeason 확정 → (2) seasons 응답 + 확정된 selectedSeason으로 availableSeasons 구성 → (3) (원한다면) 클램프를 올바르게 1회 수행.

| 항목 | 내용 |
|---|---|
| 예상 절감 | 시즌 체인 300ms(직렬 2파동) → 150ms(1파동). 콜드 스타트 스팬 약 **-150ms** (0.476s → ~0.33s 예상) |
| timeout 최악 개선 | 시즌 체인 2파동 → 1파동. 프로덕션 all-hang 32s → 24s(4파동→3파동) |
| 리스크 (낮음) | preferences/seasons는 서로의 응답 데이터를 소비하지 않음(둘 다 selectedSeason에만 영향). 후처리 1회로 순서 의존 제거 가능 |
| 리스크 (중) | 죽은 클램프를 "살려서" 올바르게 만들면 동작 변경(사용자 저장 시즌이 서버 목록에 없을 때 스냅). 현재는 절대 스냅 안 함. 클램프는 죽은 채로 두고 병렬화만 하면 동작 보존 |
| 범위 | `refreshAll` + `syncPreferencesFromServer` + `refreshSeasons` 구조 변경. 작업1의 "내부만" 범위를 넘음 → 별도 승인 필요 |

권고: 클램프는 죽은 채로 유지하고 fetch만 병렬화하는 저위험안. 승인 시 착수.

---

## 작업 1.5(c) — timeout 실패 모드 (무응답 스텁)

500은 즉시 응답이라 timeout을 재현 못 한다. 연결을 유지한 채 응답하지 않는(120s sleep) 스텁으로 재현. 앱 timeout=8s, Dev는 fallback 재시도로 파동당 16s.

핵심 관찰: **앱은 어떤 경우에도 전체 스피너로 막히지 않는다.** 실행 즉시 사용 가능한 빈 홈(바로가기·탭 동작)을 보여주고, 네트워크 hang은 UI를 막지 않고 해당 데이터 표시만 지연시킨다. (스크린샷: 무응답 6초 시점에도 홈 사용 가능)

### 케이스 1 — 전 요청 무응답: 파동 구조 [실측(Debug/시뮬)]

스텁 수신 타임라인이 파동 구조를 직접 보여준다.

AFTER(작업1.5a) — 4 파동:

| 파동 | 도착(Dev) | 요청 |
|---|---|---|
| 1 | 0s | preferences, profile, legal, teams (동시) |
| 2 | 16s | seasons (시즌 체인 직렬) |
| 3 | 32s | calendar, standings, feed (동시) |
| 4 | 48s | statistics×3 (feed 뒤 직렬) |

BEFORE(원본 직렬) — 9 파동: preferences(0) → profile(16) → legal(32) → seasons(48) → teams(64) → feed(80) → calendar(96) → statistics×3(112) → standings(128), 각 16s 간격 완전 직렬.

| | 파동 수 | Dev 정착(fallback 포함) | 프로덕션 투영(8s×파동) |
|---|---|---|---|
| BEFORE(직렬) | 9 | 144s | **72s** |
| AFTER(병렬) | 4 | 64s | **32s** |

사용자 추정 "개선 후 32초" = **정확히 일치**. "개선 전 88초"는 과대 — 통계 3요청이 async let 1파동이라 9파동=72s가 정확(11요청×8s=88s로 셈한 값). 확정: **개선 전 72s / 개선 후 32s (프로덕션 투영), 최악 대기 55% 단축.**

### 케이스 2 — preferences만 무응답, 나머지 정상 [실측(Debug/시뮬)]

| 관찰 | 결과 |
|---|---|
| profile/legal/teams | t=0 즉시 응답. 화면 반영됨 |
| feed/calendar/statistics | 시즌 체인(preferences→seasons)을 기다려 preferences 타임아웃(16s Dev / 8s 프로덕션) 후에야 시작 |
| 최종 화면(40s) | 홈에 40경기·통계 **완전 표시** — 앱이 회복 |

결론: preferences hang은 콘텐츠를 1 타임아웃만큼 지연시키지만 막지 않는다. (1.5b 제안이 이 지연을 절반으로 줄임)

### 케이스 3 — feed만 무응답, 나머지 정상 [실측(Debug/시뮬)]

| 관찰 | 결과 |
|---|---|
| preferences/seasons/calendar/standings/profile | t=0 동시 응답 |
| statistics | feed→statistics 직렬이라 feed 타임아웃(16s Dev / 8s 프로덕션)까지 지연 |
| 홈 대시보드 | **빈 상태 유지** — 홈은 feedLogs 전용 소스라 feed 실패 시 비어 있음 |
| 앱 전체 | 사용 가능(바로가기·다른 탭 동작), 통계 탭은 데이터 있음 |

### timeout 조정 제안 (착수 안 함, 제안만) [도출]

| 제안 | 근거 |
|---|---|
| 요청 timeout 8s → 4~5s 하향 | all-hang 프로덕션 32s → 16~20s. 150ms 정상 응답엔 영향 없음 |
| 전역 데드라인(예: 최초 데이터 표시까지 상한) 도입 | 부분 hang 시 UI가 무한정 로컬 폴백을 늦추지 않도록 |
| feed 우선 로드 | 홈 대시보드가 feed 전용이므로 feed를 시즌 체인과 겹쳐 먼저 확정하면 케이스 2/3 체감 개선 |

---

## 작업 2 — 이미지 메모리 측정 (코드 수정 없음)

### 디코딩 경로 [정적]

첨부 사진은 `PhotoAttachmentService.savePhoto(maxPixel: 1800)`으로 최대 1800px 저장. 표시는 `image(for:)` = `UIImage(contentsOfFile:)`가 **원본 전체를 디코딩**.

| 표시 지점 | 코드 | 표시 크기 | 다운샘플 | 캐시 |
|---|---|---|---|---|
| 캘린더 셀 | `CalendarDayCell.thumbnailImage`(computed, body 중 호출) | 54pt | 없음 | 없음 |
| 피드 | `PhotoAttachmentStrip.body` ForEach | 128~240pt | 없음 | 없음 |

`NSCache`/`URLCache`/`CGImageSourceCreateThumbnailAtIndex` 전 소스 0건. 캘린더 월 그리드는 `LazyVGrid`지만 한 달(약 35~42셀)이 대부분 동시에 화면에 떠 사진 있는 날이 동시 디코딩됨.

### 단일 사진 디코딩 할당량 [실측(디코딩 비트맵)]

| 항목 | 값 |
|---|---|
| 저장 JPEG(1800×1800, q82) | ~1.5 MB/파일 |
| 디코딩 RGBA 비트맵(이론) | 1800×1800×4 = **12.36 MB/장** |
| 실측 10장 동시 디코딩 상주 증가 | **136.7 MB** (장당 13.67 MB; PIL 프록시 — 비트맵 크기는 디코더 무관 W×H×4) |

### 추정 및 분류 [도출]

측정된 장당 12.4MB × 동시 표시 장수:

| 월 사진 일수 | 사진 비트맵 추정(동시) |
|---|---|
| 10일 | ~124 MB |
| 20일 | ~247 MB |

캘린더 월 그리드는 사진 있는 날을 동시 렌더 + 캐시/다운샘플 없음(정적 확인) → 20장 월이면 사진 비트맵만 **~247MB로 200MB 초과**. 앱 베이스라인이 더해짐.

**분류: 잠재적 "메모리 결함"** (성능 개선이 아니라). 근거는 실측 장당 비트맵 크기 + 정적 확인된 무캐시/무다운샘플/원본 디코딩 + 동시 렌더 구조.

디코딩은 `UIImage(contentsOfFile:)`가 body 평가 중 동기 호출되므로 **메인 스레드**에서 발생(정적 확인) → 20장 월 진입 시 ~247MB 디코딩이 메인에서 일어나 히치 유발.

### 측정 한계 (정직하게 명시)

- **10/20일 캘린더 in-app Allocations 피크는 직접 캡처 못 함.** 사진을 표시하려면 로컬 SwiftData 직관 로그 + 사진 파일을 심어야 하는데, 원격 feed/calendar는 `photoLocalRefs: []`로 매핑되어 API로 주입 불가하고, SwiftData 스토어 직접 주입은 CoreData 내부 스키마라 안전하지 않으며, 코드 수정은 [2] 범위 밖.
- 따라서 위 10/20일 수치는 **실측 장당 비트맵 × 장수 추정**이며, 현재 코드(무캐시·body 내 원본 디코딩·동시 렌더)에서 동시 보유가 유력하다는 정적 근거로 뒷받침됨.
- **Time Profiler 메인 스레드 비율(%)**: 사진 in-app 주입 불가로 직접 % 미산출. 디코딩이 메인 스레드 동기 호출임은 정적 확정.
- Instruments **Allocations**는 시뮬레이터에서 실행 가능 확인(앱 정상 launch). 사진 없는 앱 베이스라인 트레이스는 별도 첨부.

권고: task 3에서 디버그 시드(로컬 로그 N건 + 사진)를 넣으면 in-app 20장 피크를 직접 캡처해 분류를 확정할 수 있음. 그전까지는 위 추정 + 정적 근거로 "잠재적 메모리 결함" 유지.
