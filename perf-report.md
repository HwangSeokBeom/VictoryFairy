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

> 이 절의 10/20일 수치는 **추정**이었고, 아래 "작업 3 — 이미지 메모리(재현 성공)"의 실측으로 대체된다.
> 실측 결과 실제 피크는 여기 추정치(~247MB)보다 훨씬 크다(20장 기준 2355MB).

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

---

## 작업 1 (2차) — preferences / seasons 병렬화 (커밋 be641ae)

### 착수 전 selectedSeason 읽기·쓰기 지점 전수 [정적]

쓰기 (`self.selectedSeason`):

| 위치 | 맥락 | 콜드 스타트 |
|---|---|---|
| init | `preferences.selectedSeason`(로컬 시드) | 예(네트워크 이전) |
| selectSeason | 사용자 시즌 선택 | 아니오 |
| selectCalendarMonth | 연도 변경 | 아니오 |
| syncPreferencesFromServer | 원격 설정의 selectedSeason | 예 |
| refreshSeasons | 죽은 클램프 | 예(실행 안 됨) |

쓰기 (`preferences.selectedSeason`): selectSeason, selectCalendarMonth, refreshSeasons(클램프), `applyRemote`.

읽기: `activeSeason`(refreshFeed/refreshStatistics/loadKBOStandings/refreshContent), `selectedSeasonLabel`(UI), `syncPreferencesToServer`, **`refreshSeasons`가 availableSeasons 구성에 사용** ← 경합 지점, `localSeasonOptions`.

### 조치

`loadRemotePreferences` / `loadRemoteSeasons`는 응답만 반환하고 상태를 쓰지 않는다. 모든 쓰기는 두 응답이 도착한 뒤 `applySeasonResolution` 한 곳에서만 일어난다. 쓰기 순서(preferences → seasons)는 기존 직렬 구현과 동일. 죽은 클램프는 그대로 복사(이번 커밋에서 미변경).

### 검증 [실측(Debug/시뮬)]

| 경로 | 요청 수 | 스팬 (3회) |
|---|---|---|
| 기존 사용자(40건) | 8 | 0.356 / 0.362 / 0.381s |
| 신규 사용자(0건) | 11 (statistics 3 유지) | 0.478 / 0.476 / 0.479s |

무응답 파동: **4 → 3** (t=0에 preferences·seasons·profile·legal·teams 동시 도착 / t=16 feed·calendar·standings / t=32 statistics×3). 프로덕션 투영 32s → **24s**.

시즌 UI: 시즌 칩이 직전 빌드와 **픽셀 차이 0/40800** — selectedSeason·availableSeasons 해석 결과 동일. 시즌 선택 시트 자체는 좌표 자동화로 열지 못해 미검증(탭바 탭은 동작, 상단 칩은 히트테스트 실패). selectSeason 경로는 이번 diff에서 미변경.

### 스팬 종합

| 단계 | 스팬 | 무응답 최악(프로덕션 투영) |
|---|---|---|
| 원본(직렬) | 1.418s | 72s (9파동) |
| 작업1 | 0.717s | 32s (4파동) |
| 작업1.5a | 0.476s | 32s |
| 작업1 2차(seasons) | 0.366s | 24s (3파동) |

---

## 작업 2 — 죽은 클램프 조사 (수정 승인 전)

### 재현 [실측(Debug/시뮬)]

조건: 로컬 `selectedSeason = 2024`, 서버 시즌 목록 `[2026, 2025]`, `currentSeason = 2026`, 서버는 시즌별로 기록을 구분해 응답.

| 관찰 | 결과 |
|---|---|
| 나간 요청 | `feed?season=2024`, `calendar?year=2024`, `statistics/*?season=2024`, `kbo/standings?season=2024` |
| 서버 응답 | 전부 빈 결과(2024는 유효 시즌이 아님) |
| 화면 | 홈이 "아직 기록한 직관이 없어요" 빈 상태 |
| 클램프 | 실행 안 됨 — selectedSeason이 2026으로 스냅되지 않음 |

즉 서버가 무효라고 한 시즌이 살아남고, **기록이 있는 사용자가 기록이 없는 것처럼 보인다.** 덤으로 통계 3요청도 매번 낭비된다(mergedLogs가 비므로 스킵이 걸리지 않음).

### 어디서 터지는가 [도출 + 정적]

`UserPreferencesStore.init`은 저장값이 없으면 `selectedSeason = 현재 연도`를 쓴다.

| 시나리오 | 터지는가 | 이유 |
|---|---|---|
| 시즌 오프(11~3월) | **예 — 신규 설치/데이터 초기화 한정** | 예: 2027년 1월 신규 설치 → selectedSeason=2027. 서버는 아직 2027을 목록에 넣지 않음 → 무효 시즌 고착. 기존 사용자는 저장된 2026이 유효해 무사 |
| 오랜만에 앱 실행 | **예 — 가장 직접적** | 2024에 쓰던 사용자가 2026에 복귀. 서버가 오래된 시즌을 목록에서 정리했으면 그대로 무효 시즌 고착 (위 재현과 동일) |
| 서버 시즌 목록 변경 | **예** | 서버가 특정 시즌을 목록에서 빼면 그 시즌에 있던 사용자가 동일 증상 |

세 경우 모두 같은 메커니즘(선택 시즌이 서버 목록에 없음)이며, 연 1회 전원에게 위험한 것은 **연도 전환기 신규 설치**, 개별 사용자에게 가장 흔한 것은 **오랜만에 실행 + 서버 목록 정리**다.

### 원인 [정적]

```
availableSeasons = normalizedSeasonOptions(remoteOptions + [SeasonOption(season: selectedSeason, hasRecords: true)])
if let currentSeason = response.currentSeason, !availableSeasons.contains(where: { $0.season == selectedSeason }) { ... }
```
바로 앞 줄에서 selectedSeason을 목록에 **자기삽입**하고, `normalizedSeasonOptions`는 season 기준 dedup만 하므로 `contains`는 항상 true → `!contains`는 항상 false → 클램프 미실행.

부수 발견: 같은 자기삽입 때문에 `normalizedSeasonOptions`의 병합 규칙(`option.label.isEmpty ? existing.label : option.label`)에서 나중 항목(기본 라벨 `"\(season) 시즌"`)이 **서버 라벨을 덮어쓴다.** 서버가 "2026 정규시즌"을 줘도 칩에는 "2026 시즌"이 표시된다(baseline 대조로 기존 동작임을 확인).

### 수정안과 깨질 수 있는 동작 (승인 전 미착수)

수정안 A — 클램프 판정을 서버 목록으로만 하고, 자기삽입은 클램프 이후에:
```
if let currentSeason = response.currentSeason,
   !remoteOptions.isEmpty,
   !remoteOptions.contains(where: { $0.season == selectedSeason }) {
    selectedSeason = currentSeason; preferences.selectedSeason = currentSeason
    selectedCalendarMonth = Self.monthStart(year: currentSeason, matching: selectedCalendarMonth)
}
availableSeasons = normalizedSeasonOptions(remoteOptions + [SeasonOption(season: selectedSeason, hasRecords: true)])
```

| 깨질 수 있는 동작 | 설명 | 완화 |
|---|---|---|
| 오프라인/로컬 기록 시즌 강제 이동 | 서버 목록엔 없지만 로컬에 기록이 있는 시즌을 쓰던 사용자가 강제로 스냅됨 | 로컬 보유 시즌도 유효 집합에 포함(수정안 B) |
| 새 시즌 선점 사용자 되돌림 | 새 시즌이 시작됐는데 서버 목록 반영이 늦으면 이전 시즌으로 되돌아감 | `currentSeason`이 있을 때만 스냅(이미 조건에 포함) |
| 서버가 빈 목록을 200으로 반환 | 전 사용자가 일괄 스냅될 위험 | `!remoteOptions.isEmpty` 가드(위에 포함) |
| 라벨 표시 변경 | 자기삽입 순서를 바꾸면 서버 라벨이 살아나 칩 문구가 바뀜 | 의도된 개선이나 UI 문구 변화이므로 사전 합의 필요 |

수정안 B(더 안전) — 유효 집합 = 서버 목록 ∪ 로컬 기록 보유 시즌. 오프라인 사용자를 지키면서 무효 시즌만 정리.

---

## 작업 3 — 이미지 메모리 (재현 성공, 메모리 결함 확정)

### 재현 환경 [실측(Debug/시뮬)]

`#if DEBUG` 임시 시드로 1800×1800 JPEG N장을 `App Support/VictoryFairyPhotos/`에 만들고 이를 참조하는 로컬 SwiftData 로그 N건을 2026-04월에 하루씩 분산 생성. 캘린더 뷰 모드는 `@AppStorage("calendarViewMode")`를 `record`(사진 보기)로 직접 설정. **시드 코드는 측정 후 전량 제거**(`git diff` 비어 있음, 빌드 통과).

주의: 캘린더 "기본" 모드는 점만 그려 사진을 디코딩하지 않는다. 사진 디코딩은 **"사진" 보기 모드에서만** 발생한다.

### 메모리 피크 [실측(Debug/시뮬), vmmap Physical footprint]

| 사진 일수 | 홈 footprint (peak) | 캘린더 사진모드 (peak) | 사진 렌더 증가(peak) |
|---|---|---|---|
| 10일 | 144.5 MB (187.7 MB) | 1126.4 MB (**1228.8 MB**) | **+1041 MB** |
| 20일 | 144.5 MB (187.2 MB) | 2252.8 MB (**2355.2 MB**) | **+2168 MB** |

장당 약 **104~108 MB**로 거의 선형. 원본 비트맵(12.4MB/장)의 약 8.4배인데, 1800px 이미지를 54pt 셀에 `scaledToFill().clipped()`로 그리면서 CA가 별도 렌더 버퍼/IOSurface를 잡고, 캐시가 없어 body 평가마다 다시 준비되기 때문으로 보인다.

**200MB 기준을 10장에서 이미 6배, 20장에서 11배 초과 → "성능 개선"이 아니라 메모리 결함으로 확정.** 실기기에서는 jetsam 강제 종료 구간이다.

### 메인 스레드 비율 [실측(Debug/시뮬), macOS sample 콜스택 프로파일]

`UIImage(contentsOfFile:)` 자체는 지연 디코딩 핸들이라 프로파일에 거의 안 잡히고, 실제 비용은 **메인 스레드 CoreAnimation 커밋 단계**에서 나타난다: `CA::Transaction::commit` → `CA::Layer::prepare_contents` → `_SwiftUIProxyImage CA_prepareRenderValue` → `CA::Render::prepare_image` → `IIOImageProviderInfo::CopyIOSurface`.

| 항목 | 비율 |
|---|---|
| 메인 스레드 유휴(runloop 대기) | 90.5% |
| 메인 스레드 실제 작업 | 9.5% |
| 이미지 준비(디코딩→IOSurface) / 전체 메인 스레드 | **2.0%** |
| 이미지 준비 / 메인 스레드 실제 작업 시간 | **21.2%** |
| 참고: CA::Transaction::commit / 실제 작업 | 78.4% |

`CopyIOSurface` 188샘플 중 **155샘플이 pthread mutex 대기** — 메인 스레드가 이미지 서피스 복사에서 블로킹된다(히치 원인). 지시대로 절대 시간은 보고하지 않는다.

### 수정안 (측정 보고 후 승인 필요, 미착수)

| 조치 | 내용 | 기대 효과 |
|---|---|---|
| 다운샘플링 | `PhotoAttachmentService.image(for:)`를 `CGImageSourceCreateThumbnailAtIndex`(`kCGImageSourceThumbnailMaxPixelSize` = 표시 크기 × scale, `kCGImageSourceCreateThumbnailFromImageAlways`)로 교체 | 캘린더 54pt 셀 기준 1800px → 162px, 비트맵 약 **1/123** |
| NSCache | `NSCache<NSString, UIImage>`에 ref+표시크기 키로 캐시, `countLimit`/`totalCostLimit` 설정 | body 재평가마다 재디코딩 제거 |
| 디코딩 오프메인 | 썸네일 생성을 백그라운드에서 수행하고 완료 시 반영 | 메인 스레드 commit 블로킹 제거 |
| 호출부 | `CalendarViews.swift`(thumbnailImage), `FeedViews.swift`(PhotoAttachmentStrip) 2곳 | 표시 크기를 인자로 전달 |

---

## 백로그 (성능 항목에서 내림)

| 항목 | 사유 |
|---|---|
| 요청 timeout 값 조정 / 전역 데드라인 | 앱이 스피너로 막히지 않고 즉시 사용 가능한 UI를 보여주는 것이 확인되어 우선순위에서 제외 |
| `let id = UUID()` 제거 + HomeViewModel 위치 이동 + serverStatus guard | 작업 1~3 이후로 순연 |

---

## 작업 A — 죽은 클램프 수정 (안 B, 커밋 282ae79)

유효 시즌 = 서버 목록 ∪ 로컬 SwiftData 기록이 있는 시즌. 자기삽입 제거, 합집합 기준 클램프, 합집합이 비면 클램프하지 않고 기존 값 유지. `normalizedSeasonOptions`가 나중 항목의 라벨을 채택하므로 서버 옵션을 뒤에 배치해 서버 라벨을 우선하고, 로컬 전용 시즌은 `"<연도> 시즌"` 기본 라벨로 폴백.

### 검증 [실측(Debug/시뮬)] — 서버 목록 [2026, 2025], currentSeason 2026

| 케이스 | 로컬 selectedSeason | 로컬 기록 | 요청에 쓰인 season | 저장된 season | 판정 |
|---|---|---|---|---|---|
| 1. 로컬 기록 보유 | 2024 | 2024년 5건 | 2024 | 2024 | 유지 — 홈에 5경기 표시, "기록 없음" 안 뜸 |
| 2. 로컬 기록 없음 | 2024 | 0건 | 2026 | 2026 | 2026으로 클램프 |
| 3. 연도 전환기 신규 설치 | 2026 | 0건 | 2025 | 2025 | 서버 currentSeason(2025)으로 클램프 |
| 4. 정상 사용자 | 2026 | 0건 | 2026 | 2026 | 무변경 |

케이스 3은 서버 목록을 [2025, 2024] / currentSeason 2025로 바꿔 재현. 케이스 1 스크린샷에서 홈이 "5경기 · 100% · 2024.04.05"로 로컬 기록을 정상 표시함을 확인.

부수 수정 확인: 자기삽입이 사라져 **서버 시즌 라벨이 살아남는다.** 서버가 "2026 정규시즌"을 주면 칩도 "2026 정규시즌"으로 표시(수정 전에는 "2026 시즌"으로 덮어써졌고, 수정 전/후 칩 이미지 픽셀 차이 6503/40800으로 변화 확인).

---

## 작업 B-1 — 이미지 메모리 배수 규명 (수정 전, 보고만)

가설이었던 "한 장이 8~9벌 살아 있다"는 **틀렸다.** 한 장이 여러 벌 있는 게 아니라 **한 장이 의도보다 9배 크게 저장돼 있다.**

### 1) thumbnailImage getter 호출 횟수 [실측(Debug/시뮬)]

사진 10장 기준 getter 호출 **30회 = 장당 3회**. 캘린더를 나갔다 다시 들어오기를 3회 반복해도 **30회에서 늘지 않음**. 즉 body 평가마다 무한히 재디코딩되는 구조는 아니며, 배수의 원인이 아니다.

### 2) 메모리가 쌓이는 지역 [실측(Debug/시뮬), vmmap 지역별]

| 지역 | 크기 | region 수 |
|---|---|---|
| **Image IO** | **1.1 GB** | 20 |
| MALLOC_SMALL | 30.8 MB | 133 |
| CoreAnimation | 1.2 MB | 72 |

전량이 **Image IO**(ImageIO 디코딩 버퍼)에 있다. CoreAnimation/IOSurface 쪽은 무시할 수준. 사진 10장에 region 20개 = 장당 2개, 장당 약 110 MB.

### 3) 캘린더 재진입 시 누적 여부 [실측(Debug/시뮬)]

| 회차 | 캘린더 진입 footprint (peak) | 홈 복귀 footprint (peak) |
|---|---|---|
| 1 | 1.1 GB (1.2 GB) | 1.1 GB (1.2 GB) |
| 2 | 1.1 GB (1.2 GB) | 1.1 GB (1.2 GB) |
| 3 | 1.1 GB (1.2 GB) | 1.1 GB (1.2 GB) |

**누적되지 않는다.** 대신 한 번 잡은 뒤 **해제되지도 않는다.** 증가하는 누수가 아니라 해제되지 않는 1회성 점유다.

### 4) 배수의 진짜 원인 [실측 + 정적]

저장된 첨부 사진의 실제 픽셀 크기를 확인하니 **5400 × 5400** 이었다(`maxPixel: 1800`으로 저장했는데도).

```
func resizedForAttachment(maxPixel: CGFloat) -> UIImage {
    let longestSide = max(size.width, size.height)      // size는 pt
    ...
    let renderer = UIGraphicsImageRenderer(size: targetSize)   // 기본 format.scale = 화면 scale
    return renderer.image { _ in draw(in: CGRect(origin: .zero, size: targetSize)) }
}
```

`size`는 포인트인데 `maxPixel`(픽셀 의도)과 직접 비교하고, `UIGraphicsImageRenderer`가 기본 포맷(화면 scale = 3x)으로 렌더하므로 "1800pt" 결과물이 실제로는 **5400px**가 된다.

| 항목 | 값 |
|---|---|
| 의도한 크기 | 1800 × 1800 → 디코딩 12.4 MB |
| 실제 저장 크기 | 5400 × 5400 → 디코딩 **116.6 MB** |
| 실측 장당 점유 | 약 110 MB |

116.6MB(계산)와 110MB(실측)가 일치한다. **배수 9배는 3x 스케일 렌더 때문이며, 캐시로 해결되는 문제가 아니다.** 캐시는 재디코딩을 줄일 뿐 한 장의 크기를 줄이지 못한다.

실사용자 경로도 동일하다 [정적]: `savePhoto`는 `UIImage(data:)`(scale 1, size == 픽셀)로 읽은 뒤 같은 `resizedForAttachment`를 타므로, 4032px 원본도 "1800pt" → 5400px로 저장된다. 즉 **모든 사용자의 첨부 사진이 의도의 3배 해상도(9배 용량)로 저장되고 있다.**

### B-2에 반영할 우선순위 (승인 후 착수)

| 순서 | 조치 | 근거 |
|---|---|---|
| 1 | `resizedForAttachment`에 `format.scale = 1` 지정 | 근본 원인. 저장 크기 9배 감소, 신규 저장분은 12.4MB/장으로 정상화 |
| 2 | 표시 시 `CGImageSourceCreateThumbnailAtIndex` 다운샘플 | 이미 5400px로 저장된 기존 사용자 사진도 구제. 캘린더 54pt 기준 162px → 약 105KB/장 |
| 3 | `NSCache` (키 = ref + 목표 크기) | 장당 3회 디코딩 제거, 크기별 썸네일 혼용 방지 |
| 4 | 디코딩 오프메인 | 메인 스레드 CA 커밋 블로킹 제거 |

1번만으로도 9배가 줄지만, 이미 저장된 사진에는 소급되지 않으므로 2번이 함께 필요하다.

---

## 작업 C — 시즌 선택 시트 (자동화 한계로 결론)

### 결론: 앱 오버레이가 아니라 **테스트 자동화의 좌표 문제**다. 사용자 조작에는 영향 없을 가능성이 높으나 수동 확인 권장.

근거:

| 확인 | 결과 |
|---|---|
| 코드상 오버레이 | 없음. 칩은 `ScreenHeaderView` trailing의 평범한 `Button` + `.buttonStyle(.plain)`. `.overlay` / `.zIndex` / `allowsHitTesting` 없음 |
| 화면 하단(탭바, device y≈807) | 합성 클릭 **정상 동작** |
| 화면 중단(섹션 선택기, device y≈233) | 합성 클릭 **정상 동작**(screen y=230에서 섹션 전환 확인) |
| 화면 상단(통계 시즌 칩, device y≈112) | screen y 112~214 전 구간 스윕 **무반응** |
| 화면 상단(홈 프로필 버튼, device y≈116) | 같은 대역 스윕 **무반응** |

서로 다른 화면·다른 뷰 계층에 있는 두 상단 컨트롤이 **동시에** 무반응인데 중단·하단은 정상이므로, 앱 쪽 오버레이로는 설명되지 않는다. 시뮬레이터 창의 device→screen 좌표 매핑이 상단에서 어긋나거나(2점 보정 시 기울기가 0.91과 0.99로 불일치) 시뮬레이터 자체 크롬이 상단 클릭을 소비하는 것으로 보인다.

남은 확인(수동): 시뮬레이터에서 시즌 칩을 직접 탭해 시트가 열리는지. 열리면 자동화 한계로 종결, 안 열리면 그때 Debug View Hierarchy로 재조사한다. 수정은 승인 후.

---

## 작업 B-2 착수 전 조사

### 1) 같은 버그의 다른 발생 지점 [정적]

`UIGraphicsImageRenderer` / `UIGraphicsBeginImageContext` / `ImageRenderer` 전수 검색 결과, **scale을 지정하지 않은 곳은 `resizedForAttachment` 한 곳뿐**이다. 나머지는 모두 명시하고 있어 3배 렌더 문제가 없다.

| 위치 | 용도 | scale 지정 | 상태 |
|---|---|---|---|
| `PhotoAttachmentService.swift:83` `resizedForAttachment` | 직관 기록 첨부 사진 저장 | **없음(기본 = 화면 3x)** | 버그 — ①에서 수정 |
| `ProfileImageProcessor.swift:61` `resizedForProfileUpload` | 프로필 이미지 업로드 리사이즈 | `format.scale = 1` | 정상. 동일 패턴의 올바른 참조 구현 |
| `TicketOCRService.swift:58` `preprocessedCGImage` | 티켓 OCR 전처리 리사이즈 | `format.scale = 1` | 정상 |
| `TicketOCRService.swift:85` `normalizedImage` | EXIF 방향 정규화(크기 유지) | `format.scale = image.scale` | 정상(원본 배율 보존이 의도) |
| `ShareCardPreviewView.swift:154` `renderCard` | 공유 카드 1080×1920 렌더 | `renderer.scale = 1` | 3배 문제 없음. 다만 공유물이 1080×1920 1x로 고정이라 화질 상향 여지는 있음(별건) |

### 2) 디스크 실태 [실측(Debug/시뮬)]

수정 전 시드 20장 기준.

| 항목 | 값 |
|---|---|
| 파일 픽셀 크기 | 전부 5400 × 5400 (의도 1800 × 1800) |
| 픽셀 수 배수 | 29.16M vs 3.24M = **9배** |
| 파일 1장 | 약 544~560 KB |
| 20장 총 디스크 | 11 MB |

주의: 시드 이미지는 단색+줄무늬라 JPEG 압축이 매우 잘 든다. 실제 사진이라면 같은 5400px에서 파일 크기가 훨씬 커진다(픽셀 9배 = 용량도 대략 9배). ① 적용 후 같은 시드는 1800×1800 / 92KB, 10장 928KB로 줄었다(장당 약 6배 감소).

### 3) `resizedForAttachment` 입력 처리와 저장 시점 스파이크 [실측 + 정적]

구조상 원본을 `UIImage`로 **전체 디코딩한 뒤** 렌더 대상에 다시 그린다. 12MP(4032×3024, scale 1) 첨부를 재현해 측정:

| 항목 | 수정 전 | ① 적용 후 |
|---|---|---|
| 저장 시 Physical footprint (peak) | **209.0 MB** | **107.2 MB** |
| 저장된 파일 | 5400 × 4050 / 340 KB | 1800 × 1350 / 40 KB |

수정 전 209MB의 내역(계산): 원본 디코딩 4032×3024×4 = 48.8MB + 렌더 타깃 5400×4050×4 = 87.5MB + JPEG 인코딩 버퍼. ①로 렌더 타깃이 1800×1350×4 = 9.7MB로 줄어 절반이 사라졌다.

`CGImageSourceCreateThumbnailAtIndex` 교체 가능성: **가능하며 권장**. `savePhoto`는 원본 `Data`를 이미 갖고 있으므로 `CGImageSourceCreateWithData` + `kCGImageSourceThumbnailMaxPixelSize`로 **전체 비트맵을 만들지 않고 목표 크기로 바로 디코딩**할 수 있다. 그러면 남은 48.8MB 원본 디코딩분도 사라져 저장 스파이크가 거의 없어진다. 다만 `saveImage(_ image: UIImage, ...)` 시그니처가 `UIImage`를 받으므로 `savePhoto` 경로에 `Data` 기반 오버로드를 추가하는 형태가 된다. ②와 함께 다루는 것이 자연스럽다.

---

## 작업 B-2 ① — 저장 렌더 scale 고정 (커밋 0086617)

`UIGraphicsImageRendererFormat.default()`에 `scale = 1`을 지정해 renderer에 전달. 변경은 `resizedForAttachment` 한 함수, 5줄.

### 검증 [실측(Debug/시뮬)] — 코드가 아니라 기록된 파일을 직접 확인

| 항목 | 수정 전 | ① 적용 후 |
|---|---|---|
| 12MP 첨부 저장 결과 | 5400 × 4050 / 340 KB | **1800 × 1350 / 40 KB** |
| 저장 시 footprint peak | 209.0 MB | **107.2 MB** |
| 시드 10장 파일 크기 | 5400 × 5400 / 약 550 KB | **1800 × 1800 / 92 KB** |
| 시드 10장 총 디스크 | 약 5.5 MB | **928 KB** |
| 캘린더 사진모드 10장 peak | 1228.8 MB | **184.0 MB** |

화질: 캘린더 사진 모드 스크린샷에서 썸네일이 선명하고 줄무늬 뭉개짐이나 계단 현상 없음. 저장 1800px는 표시 크기(캘린더 54pt = 162px, 피드 최대 240pt = 720px)의 2.5배 이상이라 표시 화질 손실 없음.

### ①의 한계 — ②가 필요한 이유 [실측(Debug/시뮬)]

①이 적용된 빌드에서 **기존 5400px 사진 10장**을 그대로 두고 측정:

| 상태 | 캘린더 사진모드 footprint (peak) |
|---|---|
| ① 이후 새로 저장한 1800px 사진 10장 | 169.5 MB (**184.0 MB**) |
| 기존에 저장된 5400px 사진 10장 | 1.1 GB (**1.2 GB**) |

①은 **신규 저장분에만 적용**된다. 이미 디스크에 있는 5400px 사진은 그대로 1.2GB를 만든다. 따라서 표시 시점 다운샘플(②)이 기존 사용자 구제를 위해 반드시 필요하다.

---

## 기존 사진 마이그레이션 (제안만, 착수 안 함)

②로 메모리는 막히지만 디스크의 5400px 파일은 남는다.

| 옵션 | 내용 | 위험 |
|---|---|---|
| A. 방치 | 아무것도 하지 않음. 메모리는 ②가 막고 디스크만 낭비 | 사용자당 사진 수 × 약 9배 디스크 낭비가 영구 지속. 백업/기기 이전 용량도 함께 커짐. 구현·위험 0 |
| B. 다음 접근 시 재인코딩 | 해당 사진을 표시/업로드할 때 1800px로 다시 써 넣음 | 재인코딩 반복에 따른 세대 손실(JPEG 재압축). 쓰기 중 크래시 시 그 1장만 손상 — 원본을 지우기 전 임시 파일에 쓰고 원자적 교체하면 회피 가능. 사용자 눈에 띄는 지연 없음 |
| C. 실행 시 1회 일괄 마이그레이션 | 앱 실행 때 전체 스캔 후 변환 | 사진이 많으면 실행 지연이 체감됨. 중간 크래시 시 일부만 변환된 상태로 남음(원자적 교체 + 완료 플래그로 재개 가능하게 해야 함). 배터리·발열. 대량 재인코딩으로 세대 손실이 한 번에 발생 |

권고: **A + B의 절충** — 일괄 마이그레이션(C)은 위험 대비 이득이 작다. ②를 먼저 넣어 메모리를 막고, 디스크는 B(접근 시 재인코딩, 원자적 교체)로 점진 회수하되, 원본 손상 위험을 감수할 이유가 없다면 A(방치)도 합리적이다. 어느 쪽이든 ② 이후 별도 승인 사항.
