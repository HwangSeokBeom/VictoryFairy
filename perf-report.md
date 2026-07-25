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

---

## 작업 B-2 ②-a / ②-b — 표시 다운샘플 + 저장 경로 (커밋 d770d55)

### 착수 전: 첨부 사진 표시 지점 전수와 목표 픽셀 [정적]

| 지점 | 코드 | 표시 크기(pt) | 목표 픽셀 |
|---|---|---|---|
| 캘린더 사진 보기 셀 | `CalendarViews.swift:1022` | 최장변 54 | 54 × scale = 162 |
| 피드 카드 첨부 스트립 | `FeedViews.swift:121` (maxHeight 150) | 240 × 150 | 240 × scale = 720 |
| 직관 상세 첨부 스트립 | `FeedViews.swift:251` (maxHeight 210) | 240 × 210 | 240 × scale = 720 |
| 기록 편집 첨부 목록 | `LogEditorView.swift:1565` | 92 × 92 | 92 × scale = 276 |
| 사진 분석 선택 격자 | `LogEditorView.swift:1614` | 최소 92 | 92 × scale = 276 |
| 공유 카드(다이어리 스타일) | `ShareCardPreviewView.swift:182` | 높이 420, 1080×1920 캔버스 | **1080** |

공유 카드는 `ImageRenderer(...).scale = 1`로 1080×1920 캔버스에 그리므로 pt가 곧 픽셀이다. 다른 지점과 목표가 한 자릿수 배 다르므로 별도 케이스로 두었다. `PhotoDisplayTarget` enum으로 지점별 목표를 분리했고, 하나로 뭉뚱그리지 않았다.

`CGImageSourceCreateThumbnailAtIndex` 옵션 3개를 모두 명시했다.

| 옵션 | 값 | 없으면 |
|---|---|---|
| `kCGImageSourceCreateThumbnailFromImageAlways` | true | EXIF 내장 썸네일(수백 px)을 집어와 화질이 뭉개짐 |
| `kCGImageSourceThumbnailMaxPixelSize` | 지점별 목표 픽셀 | 다운샘플이 일어나지 않음 |
| `kCGImageSourceCreateThumbnailWithTransform` | true | EXIF 방향이 적용되지 않아 사진이 돌아감 |

### ②-a 결과 — 반드시 기존 5400px 사진으로 측정 [실측(Debug/시뮬)]

레거시 5400×5400 사진 20장을 그대로 둔 상태(신규 저장분 아님).

| 상태 | 캘린더 사진모드 footprint (peak) |
|---|---|
| ② 적용 전 | 2252.8 MB (**2355.2 MB**) |
| ② 적용 후 | 46.0 MB (**55.5 MB**) |

**목표 250MB 대비 55.5MB로 통과(42배 감소).** 홈 화면도 첨부 사진 1장을 스트립으로 그리므로 함께 개선됐다: 149.2 MB → **37.4 MB**.

캘린더 재진입 3회 누적 여부:

| 회차 | 캘린더 진입 (peak) | 홈 복귀 (peak) |
|---|---|---|
| 1 | 46.0 MB (48.2 MB) | 42.6 MB (55.5 MB) |
| 2 | 43.8 MB (55.5 MB) | 42.1 MB (55.5 MB) |
| 3 | 46.0 MB (55.5 MB) | 46.1 MB (55.5 MB) |

**누적 없음.** peak가 55.5MB에서 정체하고 footprint도 42~46MB 사이를 오간다. B-1에서 확인된 "1회성 미해제"는 절대량이 1.2GB일 때 문제였고, 이제 그 절대량 자체가 사라졌다.

### ②-b 결과 — 저장 경로 [실측(Debug/시뮬)]

`savePhoto`가 `UIImage(data:)`로 전체 디코딩하던 것을 `CGImageSourceCreateWithData` + 목표 크기 디코딩으로 교체.

| 단계 | 12MP(4032×3024) 저장 시 footprint peak |
|---|---|
| 원래 | 209.0 MB |
| ① scale 고정 후 | 107.2 MB |
| ②-b ImageIO 경로 | **63.4 MB** |

### EXIF 방향 회귀 검증 [실측(Debug/시뮬)]

Orientation 1 / 3 / 6 / 8 네 가지로 같은 세로 사진을 만들어(6·8은 저장 픽셀이 2016×1512 가로) 새 저장 경로를 통과시켰다.

| 검증 | 결과 |
|---|---|
| 저장 결과 크기 | 4장 모두 **1350 × 1800**(세로) — 가로로 저장된 6·8도 세워짐 |
| 4장 상호 픽셀 차이 | 평균 채널차 **0.04 ~ 0.06** (JPEG 노이즈 수준, 사실상 동일) |
| 방향 표식 | 상단 = 빨강(220,40,41), 하단 = 파랑(41,80,220), 좌측 = 노랑(240,200,40) — 모두 기대와 일치 |

방향 회귀 없음.

### 화질 확인 [실측(Debug/시뮬), 스크린샷]

| 화면 | 결과 |
|---|---|
| 캘린더 사진 보기(레거시 5400px 20장) | 정상. 썸네일 선명, 뭉개짐/계단 없음 |
| 피드 카드(240×150pt) | 정상. 줄무늬 경계 선명 |
| 직관 상세(240×210pt) | 정상 |
| 공유 카드 | **미확인** — 사진이 나오는 "다이어리 카드" 스타일로 전환하려면 상단 스타일 칩을 눌러야 하는데, 작업 C에서 확인된 상단 히트테스트 자동화 한계로 전환 실패. 목표를 1080px(캔버스 폭과 동일)로 잡아 구조상 손실이 없으나 육안 확인은 남음 |

---

## 마이그레이션 — 실제 사진 기준 수치 (착수 안 함)

합성 시드는 압축이 과도하게 잘 들어 실태를 왜곡한다. 그라데이션 + 노이즈가 있는 12MP(4032×3024, 3.58MB) 사진을 각 파이프라인에 통과시켜 측정했다.

| 저장 규격 | 크기 | 파일 |
|---|---|---|
| 기존 파이프라인 | 5400 × 4050 | **4269.5 KB** |
| ① 이후 | 1800 × 1350 | **456.0 KB** |
| 표시용 썸네일(피드) | 720 × 540 | 41.1 KB |
| 표시용 썸네일(캘린더) | 216 × 162 | 3.0 KB |

장당 낭비 3813.5 KB, **배수 9.4배**.

| 직관 40건 기준 | 기존 | ① 이후 | 낭비 |
|---|---|---|---|
| 사진 1장/건 | 166.8 MB | 17.8 MB | **149.0 MB** |
| 사진 3장/건 | 500.3 MB | 53.4 MB | 446.9 MB |
| 사진 5장/건 | 833.9 MB | 89.1 MB | 744.8 MB |

### 옵션별 평가 (묶지 않고 각각)

**A. 방치**

| 항목 | 내용 |
|---|---|
| 세대 손실 | **없음.** 기존 파일을 건드리지 않는다 |
| 데이터 손실 위험 | 없음 |
| 비용 | 0 |
| 대가 | 사진 1장/건 기준 사용자당 약 149MB가 영구 잔존. 3장/건이면 447MB. 기기 백업·이전 용량에도 그대로 반영됨 |

**B. 다음 접근 시 재인코딩**

| 항목 | 내용 |
|---|---|
| 재인코딩 목표 크기 | **1800px여야 한다.** ②의 표시용 썸네일(캘린더 162px / 피드 720px)로 덮어쓰면 상세·공유 카드(1080px 필요)의 원본이 사라져 되돌릴 수 없다 |
| 세대 손실 | **발생.** 이미 q0.82로 인코딩된 5400px를 디코딩해 다시 q0.82로 인코딩. 1회 재압축이므로 눈에 띄는 수준은 아니나 A와 달리 0이 아니다 |
| 데이터 손실 위험 | 임시 파일에 쓰고 원자적 교체(`options: [.atomic]`)하면 쓰기 중 크래시에도 원본이 남는다. 교체 후 크래시는 무해 |
| 비용 | 장당 5400px 디코딩(116MB) + 1800px 인코딩 + 4.2MB 읽기 / 0.46MB 쓰기. **스크롤 중에 이게 돌면 안 된다** — ②로 표시 경로는 이미 162px만 디코딩하므로, 재인코딩을 표시 경로에 얹으면 ②의 이득을 그 순간 되돌린다. 별도 백그라운드 큐에서 화면과 무관하게, 동시 1장씩 처리해야 안전 |
| 회수 속도 | 사용자가 실제로 열어본 사진만 회수되므로 오래된 사진은 영영 남을 수 있다 |

**C. 실행 시 1회 일괄** — B-1 보고에서 이미 위험 대비 이득이 작다고 평가했고, 위 수치로도 판단이 바뀌지 않는다(40건×3장이면 120장 × 116MB 디코딩을 실행 직후에 몰아서 수행).

### 권고

②로 메모리 문제는 끝났고 남은 것은 순수 디스크 낭비다. 사진 1장/건이면 149MB로 "무시할 수 있는" 크기는 아니지만 크래시를 유발하지 않는다. **B를 택한다면 반드시 (1) 목표 1800px, (2) 표시 경로가 아닌 백그라운드 큐, (3) 원자적 교체** 세 조건을 함께 걸어야 하며, 그렇지 않으면 A가 낫다. 결정은 승인 사항.

---

## 작업 [1] — ③(NSCache)·④(오프메인) 필요 여부 측정 (코드 수정 없음)

### 동기 디코딩이 남아 있는 지점 [정적]

②-a 이후에도 디코딩은 전부 body 평가 경로에서 동기로 돈다.

| 파일·라인 | 형태 |
|---|---|
| `CalendarViews.swift:1022` | `CalendarDayCell.thumbnailImage` computed property → `photoContent`(body)에서 호출 |
| `FeedViews.swift:474` | `PhotoAttachmentStrip.body`의 ForEach 내부 직접 호출 |
| `LogEditorView.swift:1565` | 첨부 목록 ForEach body 내부 |
| `LogEditorView.swift:1614` | 사진 분석 선택 격자 body 내부 |
| `ShareCardPreviewView.swift:300` | `firstImage` computed property → 카드 body |

### 디코딩 호출 횟수와 누적 wall time [실측(Debug/시뮬), os_signpost + CFAbsoluteTimeGetCurrent]

레거시 5400px 사진 20장, 캘린더 사진 보기 모드.

| 구간 | 디코딩 호출 | 누적 wall time |
|---|---|---|
| 홈 진입 | 2회 (720px) | 57.1 ms |
| 캘린더 진입 | +40회 (162px) | +491.0 ms |
| 스크롤 1회 | +0회 | +0 ms |
| 합계 | 42회 | **548.1 ms** |

| 목표 픽셀 | 호출 | 누적 | 평균 |
|---|---|---|---|
| 162px (캘린더) | 40회 | 491.0 ms | **12.28 ms** |
| 720px (피드) | 2회 | 57.1 ms | 28.53 ms |

**전제가 다시 바뀐다.** 162px 썸네일 1장 디코딩이 12.28ms다. 프레임 예산 16.7ms의 74%이며, 캘린더 진입 1회가 **491ms = 약 29프레임**을 메인 스레드에서 소비한다. 이유는 `kCGImageSourceCreateThumbnailFromImageAlways: true`가 EXIF 썸네일 대체를 막기 위해 **원본 5400px JPEG를 먼저 완전히 디코딩**한 뒤 축소하기 때문이다. 메모리는 즉시 해제되어 footprint에 안 잡히지만(그래서 ②에서 55.5MB로 보였다) CPU 비용은 원본 크기에 그대로 비례한다.

### 재진입 시 재디코딩 [실측(Debug/시뮬)]

| 동작 | 디코딩 증분 |
|---|---|
| 캘린더 진입 1회차 | +40 |
| 홈 복귀 1회차 | +42 |
| 캘린더 진입 2회차 | +40 |
| 홈 복귀 2회차 | +2 |
| 세션 누적 | 126회 / **1557.1 ms** |

캐시가 없으므로 화면을 오갈 때마다 전량 재디코딩한다.

### 판단

| 항목 | 결론 | 근거 |
|---|---|---|
| ④ 오프메인 | **필요** | 캘린더 진입 1회에 메인 스레드 491ms 동기 점유. 약 29프레임 드랍이므로 눈에 보이는 멈춤이다 |
| ③ NSCache | **필요** | 진입할 때마다 491ms를 다시 낸다. 세션 누적 1557ms. 캐시가 있으면 2회차부터 0에 수렴 |
| ③ 없이 ④만 | **부족** | 멈춤은 사라지지만 진입마다 40회 × 12.28ms의 CPU·배터리를 계속 쓰고, 디코딩 완료 전까지 빈 셀이 보였다가 채워지는 팝인이 매번 반복된다 |
| ④ 없이 ③만 | **부족** | 2회차부터는 해결되지만 **첫 진입 491ms 멈춤은 그대로** 남는다 |

둘 다 필요하며, ③이 반복 비용을, ④가 첫 진입 멈춤을 담당한다.

### ③이 되돌리는 메모리량 [도출]

현재 캘린더 피크 55.5MB 기준, 캐시가 추가로 점유하는 양:

| 목표 | 비트맵 1장 | 20장 캐시 시 |
|---|---|---|
| 162px (캘린더) | 162×162×4 = 105 KB | 2.1 MB |
| 276px (편집) | 276×276×4 = 305 KB | 6.1 MB |
| 720px (피드·상세) | 720×540×4 = 1.56 MB | 31.1 MB |
| 1080px (공유 카드) | 1080×810×4 = 3.5 MB | 1장만 사용 |

`totalCostLimit`을 32MB로 두면 최악 55.5 + 32 = **약 88MB**로, 목표 250MB 대비 여유가 크다. 16MB로 조이면 약 72MB. cost는 비트맵 바이트 수(`width × height × 4`)로 계산하면 된다.

---

## 작업 [2] — 마이그레이션 비용 재산출

### 정정

이전 보고의 "B는 장당 5400px 디코딩 116MB"는 **틀렸다.** ②-b에서 쓴 `CGImageSourceCreateThumbnailAtIndex(maxPixelSize: 1800)` 경로를 그대로 쓰면 전체 비트맵을 만들지 않는다. 실측으로 정정한다.

### 재인코딩 실측 [실측(Debug/시뮬)]

레거시 5400×5400 파일 20장을 1800px로 재인코딩(`autoreleasepool` + 임시 파일 쓰기 → `replaceItemAt` 원자적 교체).

| 항목 | 값 |
|---|---|
| 변환 | 20 / 20장 성공 |
| 총 소요 | **954.1 ms** |
| 장당 | **47.7 ms** |
| 처리 중 footprint peak | **86.3 MB** |
| 디스크 | 11 MB → **1.8 MB** |
| 결과 파일 | 1800 × 1800 / 92~96 KB |

40건 환산: 약 **1.9초**, peak는 동일(한 장씩 처리 + autoreleasepool이라 장수와 무관).

### 세대 손실 [실측, 12MP 실사진]

| 경로 | 파일 크기 |
|---|---|
| A. 원본 → 1800px 직접 저장 (① 이후 신규) | 456.0 KB |
| B. 원본 → 5400px 저장 → 디코딩 → 1800px 재인코딩 | 456.7 KB |

| 지표 | 값 |
|---|---|
| 평균 절대 차이 (MAE) | 1.62 / 255 |
| PSNR | **40.9 dB** |

40dB 이상은 통상 육안 구분이 어려운 구간이고, 동일 크롭을 나란히 놓고 봐도 차이가 보이지 않는다. **세대 손실은 존재하지만 무시할 수 있는 수준이다.**

### 원자적 교체와 중단 복구 설계 (제안)

1. 대상 파일 `<ref>.jpg`를 같은 디렉터리의 `<ref>.jpg.tmp`로 재인코딩해 쓴다(`Data.write(options: [.atomic])`).
2. `FileManager.replaceItemAt(original, withItemAt: tmp)`로 교체한다. 이 API는 교체가 원자적이라 중간 상태가 노출되지 않는다.
3. 중단 시 복구: 원본은 2단계 직전까지 그대로 남으므로 손실이 없다. 남은 `.tmp`는 다음 실행 시 시작 전에 일괄 삭제한다.
4. 재진입 안전성: 이미 1800px인 파일은 `CGImageSourceCopyPropertiesAtIndex`로 픽셀 크기를 먼저 읽어 1800 이하면 건너뛴다. 따라서 여러 번 돌려도 재압축이 누적되지 않는다(세대 손실 1회로 고정).
5. 진행 상태는 별도 플래그가 필요 없다. 파일 크기 검사가 곧 멱등성 보장이다.

### A / B 재평가

| 항목 | A. 방치 | B. 재인코딩 |
|---|---|---|
| 세대 손실 | 없음 | PSNR 40.9dB, 육안 구분 불가 |
| 데이터 손실 위험 | 없음 | 원자적 교체 + `.tmp` 정리로 사실상 없음 |
| 디스크 회수 (40건 × 1장) | 0 | **149 MB** |
| 비용 | 0 | 40장 1.9초, peak 86.3MB |
| 재인코딩 목표 크기 | — | **1800px 고정.** 표시용 썸네일(162/720px)로 덮으면 상세·공유 카드(1080px)가 복구 불가하게 손상된다 |
| 실행 위치 | — | 표시 경로가 아닌 백그라운드. 단, 장당 47.7ms이므로 스크롤 중이라도 치명적이지 않다 |

**권고: B로 전환한다.** 이전 권고(A 또는 조건부 B)를 뒤집는다. 근거는 세 가지다. 첫째, 실제 비용이 40장 1.9초 / peak 86.3MB로 처음 추정보다 훨씬 작다. 둘째, 세대 손실이 PSNR 40.9dB로 측정되어 "손실이 있으니 피하자"는 논거가 성립하지 않는다. 셋째, 회수량이 사진 1장/건에서도 149MB로 무시할 수 없다. 다만 ③④보다 우선순위는 낮다 — 마이그레이션은 디스크만 돌려주고, ③④는 눈에 보이는 멈춤을 없앤다.

---

## 작업 [3] — 미검증 화질 (일부 확인)

| 화면 | 목표 | 결과 |
|---|---|---|
| LogEditor 첨부 목록 (92pt) | 276px | **확인 완료.** 레거시 5400px 사진이 92pt 썸네일로 선명하게 렌더 |
| LogEditor 사진 분석 격자 (92pt) | 276px | 미확인. 동일한 `.editorThumbnail` 목표와 동일 디코딩 경로를 쓰므로 구조상 위 항목과 같다 |
| 공유 카드 (1080px) | 1080px | 미확인. 사진이 나오는 "다이어리 카드" 스타일로 전환하려면 상단 스타일 칩을 눌러야 하는데 작업 C의 상단 히트테스트 한계에 막힘. 작업 [4] 결과 대기 |

---

## 작업 [1] — 12.28ms 원인 확정 (이전 설명 정정)

### peak 측정 방식 [실측]

`vmmap --summary`의 `Physical footprint (peak)` 필드를 읽었다. 주기 샘플링이 아니라 **커널이 유지하는 high-water mark**다. 300MB를 할당했다 해제하는 테스트로 확인했다.

| 시점 | peak |
|---|---|
| 할당 전 | 7520 K |
| 300MB 상주 중 | 307.5 M |
| 해제 후 | 307.5 M (값 유지) |

즉 짧은 스파이크도 포착된다. **55.5MB 측정은 스파이크를 놓친 것이 아니며, 116MB짜리 전체 디코딩은 실제로 일어나지 않았다.** 지적이 맞았다.

### 디코딩 시간 매트릭스 [실측(Debug/시뮬), 각 조합 20회 평균]

동일 내용의 5400×5400 파일(562KB)과 1800×1800 파일(93KB).

| 파일 | maxPixel 162 | maxPixel 1800 |
|---|---|---|
| 5400px | **15.01 ms** | 53.63 ms |
| 1800px | **2.48 ms** | 8.82 ms |

### 확정된 원인

| 관찰 | 해석 |
|---|---|
| 같은 5400px 파일에서 목표 162가 1800보다 3.6배 빠름 | **DCT 스케일링은 정상 동작한다.** 전체 비트맵을 만든 뒤 축소하는 것이 아니다. 그래서 메모리가 55.5MB로 유지된 것 |
| 같은 목표 162에서 1800px 파일이 5400px 파일보다 6.1배 빠름 | **비용을 지배하는 것은 저장 파일의 해상도다** |

정확한 메커니즘: JPEG 엔트로피(허프만) 디코딩은 출력 배율과 무관하게 **스트림의 모든 MCU를 훑어야** 한다. 이 비용이 원본 픽셀 수에 비례한다. DCT 스케일링이 줄여주는 것은 그 뒤의 IDCT·리샘플링·출력 버퍼이고, 그래서 메모리는 작지만 CPU는 원본 크기를 따라간다.

**이전 보고의 "FromImageAlways가 5400px 전체 디코딩을 유발한다"는 틀렸다.** 메모리 근거가 성립하지 않는다. 플래그는 제 역할(EXIF 내장 썸네일 대체 차단)을 하고 있을 뿐이며 그대로 둔다.

---

## 작업 [2][3] — 오프메인 디코딩 + NSCache (커밋 f4ff3fe)

`AttachmentPhotoView`를 추가해 body 평가 경로의 동기 디코딩 4곳을 비동기로 옮겼다.

| 지점 | 처리 |
|---|---|
| `CalendarViews.swift` 캘린더 셀 | 비동기 전환 |
| `FeedViews.swift` 피드·상세 스트립 | 비동기 전환 |
| `LogEditorView.swift` 첨부 목록 | 비동기 전환 |
| `LogEditorView.swift` 사진 분석 격자 | 비동기 전환 |
| `ShareCardPreviewView.swift` 공유 카드 | **동기 유지(의도)** — `ImageRenderer`는 뷰 트리를 즉시 렌더하므로 비동기로 바꾸면 빈 카드가 내보내진다. 스크롤 경로가 아니라 화면 진입 시 1장이므로 유지가 안전하다 |

셀 재사용 방어: `.task(id: ref)`가 ref 변경 시 이전 작업을 취소하고, 완료 시점에도 `requestedRef == ref`를 다시 비교한 뒤에만 반영한다. 로딩 중에는 같은 크기의 플레이스홀더를 그려 레이아웃이 흔들리지 않는다.

캐시 키는 `ref + 목표픽셀`이라 캘린더용 162px 썸네일이 피드(720px)에 재사용되지 않는다. cost는 `width × height × 4`.

### 검증 [실측(Debug/시뮬), 레거시 5400px 20장]

| 지표 | 이전 | 이후 |
|---|---|---|
| 캘린더 진입 시 메인 스레드 디코딩 | 491 ms (40회) | **0 ms (0회)** |
| 캘린더 3회 진입 총 디코딩 | 120회 | **20회** (2·3회차는 0) |
| 장당 디코딩 횟수 | 2회 | **1회** |
| Physical footprint peak | 55.5 MB | **58.9 MB** |

모든 디코딩이 백그라운드에서 일어났다(`main=Y` 0건 / `main=N` 21건).

### totalCostLimit 조정 근거

| 설정 | peak | ② 대비 증가 |
|---|---|---|
| 32 MB | 69.3 MB | +13.8 MB |
| **8 MB** | **58.9 MB** | **+3.4 MB** |

32MB에서는 NSCache가 한도에 닿기 전까지 축출하지 않아 필요 이상으로 보유했다. 실제 캐시 내용물은 20×105KB + 720px 1장 ≈ 3.7MB뿐이므로 8MB로 충분하며, 이 값에서 재진입 캐시 적중(재디코딩 0회)은 그대로 유지된다. 지시하신 "+10MB 초과 시 조정"에 따라 8MB로 확정했다.

---

## 작업 [4] — 마이그레이션 재평가 (착수 안 함)

### [1] 측정값으로 산출한 디코딩 이득

마이그레이션(5400px → 1800px)은 디스크뿐 아니라 **디코딩 시간도 줄인다.**

| 항목 | 5400px | 1800px | 배수 |
|---|---|---|---|
| 캘린더 썸네일(162px) 1장 | 15.01 ms | 2.48 ms | **6.1배** |
| 피드 썸네일(720px) 1장 | 약 53.63 ms(1800 기준) | 8.82 ms | 6.1배 |
| 캘린더 첫 진입 20장 디코딩 총량(실측) | 631.5 ms | 약 104 ms (추정) | 6.1배 |

단 ④ 적용 후 이 시간은 **백그라운드**에서 소비되므로 멈춤으로 보이지는 않는다. 이득은 (1) 첫 진입 시 사진이 채워지는 지연 단축, (2) CPU·배터리 절감이다.

### 종합 (이전 지시 항목 유지)

| 항목 | 값 |
|---|---|
| 재인코딩 peak | 86.3 MB |
| 40장 일괄 소요 | 약 1.9초 (20장 954.1ms, 장당 47.7ms) |
| 세대 손실 | PSNR 40.9 dB, MAE 1.62/255 — 육안 구분 불가 |
| 디스크 회수 (40건 × 1장) | 149 MB |
| 원자적 교체 | `.tmp` 쓰기 → `replaceItemAt`. 중단 시 원본 보존, 잔여 `.tmp`는 다음 실행 시 정리 |
| 멱등성 | `CGImageSourceCopyPropertiesAtIndex`로 픽셀 크기를 먼저 읽어 1800 이하면 건너뛴다. 여러 번 돌려도 재압축이 누적되지 않는다 |

### 권고

**B(재인코딩) 유지.** 이번 [1] 측정으로 근거가 하나 더 늘었다 — 디스크 149MB 회수에 더해 디코딩이 6.1배 빨라진다. 다만 ③④가 들어간 뒤로는 **긴급도가 내려갔다.** 멈춤(491ms)은 ④가 이미 제거했고 반복 비용은 ③이 제거했으므로, 마이그레이션은 이제 "디스크 회수 + 백그라운드 CPU 절감"의 성격이다. 별도 승인 후 별도 커밋으로 진행하는 것이 적절하다.

---

## 작업 [1] — 캐시 한도 재평가 (커밋 21a2db7)

### 지표 정정

이전에 쓰던 "적중률"은 결함이 있었다. `AttachmentPhotoView`가 `cachedImage`로 한 번 조회하고, miss면 `imageAsync`가 내부에서 또 조회하므로 **cold 1회가 MISS 2로 계상**된다. 그래서 적중률 50%가 천장이었다. 아래는 실제 지표인 **cold 디코딩 횟수**로 환산한 값이다(MISS ÷ 2).

### 측정 [실측(Debug/시뮬)] — 사진 40장(5400px), 피드 아래 15회 → 위 15회 → 캘린더 3회 재진입

| totalCostLimit | 162px cold | 720px cold | peak |
|---|---|---|---|
| 공유 8 MB | **44** (이상적 28) | 53 | 81.9 MB |
| 공유 16 MB | 28 | 48 | 84.9 MB |
| 공유 32 MB | 28 | 40 | 83.8 MB |
| **분리 8 + 32 MB** | **28** | **40** | **82.6 MB** |

### 판단

| 관찰 | 해석 |
|---|---|
| peak가 네 설정에서 82~85MB로 평탄 | **캐시 한도는 peak를 좌우하지 않는다.** peak는 동시 디코딩 작업 버퍼가 만든다. 8MB에서 32MB로 캐시 내용이 약 23MB 늘어도 peak는 2MB 차이다 |
| 공유 8MB에서만 162px cold가 44 (28이 하한) | 피드 720px 1장(약 2MB)이 캘린더 162px 썸네일(약 105KB) 20장을 밀어낸다. **등급 혼재가 실제로 문제를 일으켰다** |
| 공유 16MB 이상에서 162px가 28로 회복 | 다만 이는 "현재 사진 수에서 우연히 충분한" 것이지 구조적 보장이 아니다 |
| 분리(8+32MB)가 공유 32MB와 동일한 cold 수 | 같은 결과를 **썸네일에 8MB만 쓰고** 달성한다. 사진 수가 늘어도 썸네일은 밀려나지 않는다 |

**결론: 등급별 분리 채택.** 썸네일 캐시(≤320px) 8MB + 대형 캐시 32MB. 이전 10MB 기준은 폐기했고, peak는 모든 설정에서 100MB 아래(최대 84.9MB)였다.

32MB보다 큰 값은 측정하지 않았다(실행 중단). 다만 8→16→32MB에서 720px cold가 53→48→40으로 줄어드는 기울기가 완만해지고, 40장을 모두 담으려면 약 83MB가 필요해 peak가 100MB를 넘길 가능성이 크므로 32MB에서 멈추는 것이 타당하다고 판단했다.

---

## 작업 [2] — 미검증 화질 2곳

| 화면 | 결과 |
|---|---|
| LogEditor 첨부 목록 (92pt / 276px) | **확인 완료.** 레거시 5400px 사진이 92pt 썸네일로 선명하게 렌더(②-a 라운드 스크린샷). ③④는 로딩 시점만 바꿨을 뿐 `.editorThumbnail` 목표와 `downsampledCGImage` 경로가 동일하므로 렌더 결과는 같다 |
| LogEditor 사진 분석 격자 (92pt / 276px) | **미확인.** 동일 목표·동일 디코딩 경로를 쓰지만 화면 캡처에는 이르지 못했다 |

솔직히 적자면, 이 두 화면(및 공유 카드 다이어리 스타일)에 도달하려면 피드 → 자세히 보기 → 수정하기 순으로 좌표 탭을 연달아 맞춰야 하는데, 이번 라운드에서 여러 번 시도했으나 스크롤 위치에 따라 버튼 y가 매번 달라져 안정적으로 재현하지 못했다. 지시하신 대로 좌표 보정에 더 시간을 쓰지 않고 여기서 멈춘다. 부수적으로 피드·상세·캘린더는 레거시 사진으로 재확인했고 모두 선명했다.

---

## 작업 [3] — B(재인코딩) 세대 손실 검증

앱의 실제 ImageIO 파이프라인으로 동일 원본(12MP, 4032×3024)에서 두 경로를 생성했다.

| 경로 | 결과 | 파일 크기 |
|---|---|---|
| 중간 산출물 (기존 저장 규격) | 5400 × 4050 | 4276 KB |
| **A. 마이그레이션** 원본 → 5400px → 1800px 재인코딩 | 1800 × 1350 | **878.8 KB** |
| **B. 현재 정상** 원본 → 1800px 직접 | 1800 × 1350 | **877.1 KB** |

| 지표 | 값 |
|---|---|
| 평균 절대 차이 (MAE) | 1.481 / 255 |
| 최대 채널 차이 | 13 |
| PSNR | **42.2 dB** |

동일 영역 크롭을 나란히 놓고 비교했을 때 차이가 보이지 않는다(`gen2_compare.png`). 두 결과를 각각 첨부 사진으로 심어 피드·캘린더에서 렌더한 화면에서도 구분되지 않는다. 42.2dB는 통상 육안 구분이 어려운 40dB를 넘고, 최대 채널 차이 13은 JPEG 양자화 잡음 범위다.

**판정: B는 세대 손실 조건을 통과한다.**

### 마이그레이션 방식과 중단 복구 (제안, 착수 안 함)

**방식: on-access(접근 시 1장씩).** 일괄은 권하지 않는다. 40장 1.9초가 실행 직후에 몰리고, 중단 지점 관리가 필요하며, 사용자가 다시 열지도 않을 사진까지 재인코딩한다. on-access는 사진을 실제로 표시할 때 그 1장만 백그라운드에서 변환하므로 체감 비용이 0에 수렴한다.

```
func migrateIfNeeded(ref: String) async {
    let url = try? url(for: ref)
    guard let url else { return }
    // 1) 이미 1800px 이하면 아무 것도 하지 않는다(멱등)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int,
          let h = props[kCGImagePropertyPixelHeight] as? Int,
          max(w, h) > 1800 else { return }
    // 2) 목표 1800px로 재인코딩 (표시용 162/720px로 덮으면 상세·공유 카드가 손상된다)
    guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1800,
            kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
          let jpeg = UIImage(cgImage: cg, scale: 1, orientation: .up)
              .jpegData(compressionQuality: 0.82) else { return }
    // 3) 임시 파일에 먼저 쓰고 원자적으로 교체한다
    let tmp = url.appendingPathExtension("tmp")
    guard (try? jpeg.write(to: tmp, options: [.atomic])) != nil else { return }
    _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
}
```

중단 시 복구:

| 중단 시점 | 상태 | 복구 |
|---|---|---|
| 2단계 이전 | 원본 그대로 | 없음. 다음 접근 시 재시도 |
| 3단계 `write` 중 | 원본 그대로, `.tmp`만 불완전 | 앱 시작 시 `VictoryFairyPhotos/*.tmp` 일괄 삭제 |
| `replaceItemAt` 중 | 원자적이라 중간 상태가 노출되지 않음 | 없음 |
| 교체 완료 후 | 1800px로 정상 | 없음. 1단계 크기 검사가 재변환을 막으므로 세대 손실은 1회로 고정 |

사용자 사진은 되돌릴 수 없으므로, 원본을 지우는 경로는 존재하지 않고 교체만 일어난다는 점이 핵심이다.

**권고: B를 on-access로 진행.** 근거는 세대 손실 42.2dB(육안 구분 불가), 디스크 회수 149MB(40건×1장), 디코딩 6.1배 단축이다. 다만 우선순위는 낮다 — 멈춤과 반복 비용은 ③④가 이미 제거했다.

---

## 작업 [1] — 최종 배포 설정으로 재측정 (HEAD `58d3340`, 코드 수정 없음)

### 정정

이전 요약의 **55.5MB는 ③④ 이전(`d770d55`) 값**이다. ③(NSCache)·④(오프메인)와 등급 분리(`21a2db7`)가 들어간 뒤로 다시 잰 적이 없었다. 최종 배포 설정(썸네일 8MB + 대형 32MB)으로 같은 시나리오를 다시 쟀다.

### 측정 방법 [실측(Debug/시뮬)]

레거시 5400×5400 사진 20장 + 이를 참조하는 로컬 로그 20건. 콜드 실행 → 홈 14초 → 캘린더 탭(사진 보기 모드) → 12초 → `vmmap --summary`. 실행마다 새 프로세스이므로 NSCache는 매번 비어 있다. 계측(`VF_LOG_DECODE`)과 시드는 임시 패치이며 측정 후 전량 제거했다(`git status` 비어 있음).

캘린더 뷰 모드는 상단 칩 탭이 합성 클릭으로 안정적으로 눌리지 않아 `@AppStorage("calendarViewMode")`를 `record`로 직접 써서 고정했다. 시뮬레이터 창이 여러 개 열려 있으면 AppleScript의 `first window`가 다른 기기 창을 잡아 탭이 엉뚱한 곳에 떨어진다 — 창을 이름으로 지정해야 한다.

### 결과 — 5회 반복 [실측(Debug/시뮬)]

| 회차 | 홈 peak | 캘린더 peak | 정착 footprint | 162px 디코딩 | 메인 스레드 |
|---|---|---|---|---|---|
| 1 | 43.6 MB | 69.8 MB | 45.7 MB | 20회 | 0회 |
| 2 | 44.0 MB | 58.7 MB | 41.1 MB | 20회 | 0회 |
| 3 | 42.6 MB | 60.9 MB | 46.9 MB | 20회 | 0회 |
| 4 | 43.4 MB | 68.7 MB | 45.7 MB | 20회 | 0회 |
| 5 | 44.3 MB | 61.7 MB | 47.0 MB | 20회 | 0회 |
| **요약** | 42.6~44.3 | **58.7 ~ 69.8 (평균 64.0)** | 41.1~47.0 | 20회 | **0회** |

한 프로세스에서 캘린더를 3회 재진입한 경우:

| 회차 | 누적 162px 디코딩 | peak |
|---|---|---|
| 1 | 20회 | 66.9 MB |
| 2 | 20회 (추가 0) | 66.9 MB |
| 3 | 20회 (추가 0) | 66.9 MB |

캐시 적중은 그대로 유지된다. 20장 외에 홈 화면 스트립의 720px 디코딩 1회가 더 있어 프로세스 전체 디코딩은 21회다.

**요약의 55.5MB를 58.7~69.8MB(평균 64.0MB)로 교체한다.** ②(`d770d55`) 시점보다 평균 8.5MB 높은데, ③④가 백그라운드 디코딩 작업 버퍼를 동시에 여러 개 살려 두기 때문이다. 250MB 목표 대비로는 여전히 4분의 1 이하다.

---

## 작업 [2] — peak 변동폭과 이전 라운드 +13.8MB 재검증

### 같은 시나리오, 캐시 설정만 바꿔 반복 [실측(Debug/시뮬)]

`f4ff3fe` 라운드의 단일 캐시 구성을 임시로 되살려(`VF_SHARED_MB`) 같은 조건에서 반복했다.

| 캐시 구성 | 반복 | 최소 | 최대 | 평균 | 이전 라운드 단일 실행값 |
|---|---|---|---|---|---|
| 분리 8 + 32 MB (배포) | 5회 | 58.7 MB | 69.8 MB | 64.0 MB | — |
| 공유 8 MB | 3회 | 60.3 MB | 69.8 MB | 66.4 MB | 58.9 MB |
| 공유 32 MB | 3회 | 58.7 MB | 68.0 MB | 64.2 MB | 69.3 MB |

세 설정의 분포가 겹친다. **이전 라운드의 +13.8MB(58.9 → 69.3)는 캐시 한도의 효과가 아니라 단일 실행 편차였다.**

### 왜 캐시 한도가 이 시나리오의 peak를 바꿀 수 없는가 [도출]

이 시나리오에서 캐시에 들어가는 내용물은 162px 썸네일 20장(장당 약 105KB) + 720px 1장(약 2MB) ≈ **4.1MB**다. 8MB에서도 축출이 일어나지 않으므로 8 / 32MB / 등급 분리는 **보유 내용물이 완전히 같다.** 한도가 달라도 메모리가 달라질 경로가 없다. 이전 라운드의 "32MB에서는 필요 이상으로 보유했다"는 설명은 성립하지 않는다 — 그때도 캐시 내용은 4MB뿐이었다.

### peak가 어디서 생기는지 [실측(Debug/시뮬), 탭 이후 26회 연속 샘플링]

| 시점 | footprint | peak |
|---|---|---|
| 캘린더 탭 직전 | 37.0 MB | 44.0 MB |
| 탭 직후 첫 샘플(약 1초) | 49.1 MB | 70.0 MB |
| 이후 25회 샘플(약 25초) | 46.3 MB | 70.0 MB (변화 없음) |

peak를 만드는 26MB 초과분은 **탭 직후 1초 이내에 끝나는 일시적 스파이크**다. 정착 footprint(46MB)는 실행마다 ±3MB로 안정적인데, 이 1초짜리 스파이크만 실행마다 58.7~69.8MB로 흔들린다.

디코딩 동시 실행 수(로그 타임스탬프로 산출)는 실행마다 10~13개였고 peak와 상관이 없었다(동시 13개인 실행이 69.8이 아니라 60.9). 162px 버퍼는 장당 105KB라 20장을 모두 합쳐도 2.1MB이므로, 애초에 스파이크의 크기를 설명하지 못한다. **스파이크의 11MB 변동이 정확히 어디서 오는지는 규명하지 못했다** — 전환 애니메이션이 잡는 렌더 서피스 수가 유력하나 확인하지 못했다.

### 기록 규칙

- **단일 실행 peak은 재현되지 않을 수 있다.** 이 시나리오에서 동일 조건 반복의 폭은 약 11MB였다.
- 2355MB → 60MB대 같은 큰 수치는 영향이 없다.
- 이후 **수 MB 단위 판단은 3회 이상 반복 측정**하고 최소/최대/평균을 함께 남긴다. 이번 라운드부터 적용했다.

---

## 작업 [3] — 마이그레이션 B 동시성 (착수 안 함, 측정과 설계만)

### 측정 방법 [실측(Debug/시뮬)]

레거시 5400px 사진 **40장**. 피드 탭 진입 후 빠른 flick 16회로 40장을 연속 인스턴스화한다(느린 드래그가 아니라 관성 스크롤). 마이그레이션은 임시 계측 빌드에만 넣었고 **저장소에는 반영하지 않았다**(`git status` 비어 있음). 매 실행 전 40장을 5400px 원본으로 복원한다.

`naive`는 지시대로 표시 경로에 그대로 얹은 구조다 — 표시 완료 직후 제한 없이 `Task.detached`로 던진다.

### 40장 동시 트리거 시 peak [실측(Debug/시뮬), 각 3회]

| 구성 | peak 3회 | 평균 | 기준 대비 | 동시 실행 최대 |
|---|---|---|---|---|
| 마이그레이션 없음(기준) | 54.9 / 57.5 / 54.8 | **55.7 MB** | — | — |
| **naive on-access (제한 없음)** | 183.1 / 164.9 / 160.3 | **169.4 MB** | **+113.7 MB** | 3~4 |
| 큐 동시 실행 2 | 158.7 / 159.3 / 156.4 | **158.1 MB** | +102.4 MB | 2 |
| 큐 동시 실행 1 | 105.3 / 108.1 / 110.0 | **107.8 MB** | +52.1 MB | 1 |

**지적이 맞다. 표시 경로에 그대로 얹으면 peak가 55.7MB에서 169.4MB로 3배가 된다.**

주의할 점 하나: 40장이 동시에 *트리거*되지만 실제 동시 *실행*은 3~4개였다. Swift 동시성 풀이 코어 수로 제한하기 때문이다. 즉 169MB는 40개가 아니라 **3~4개가 겹친 결과**이며, 코어가 더 많은 기기에서는 더 나빠진다.

### 비용이 어디에 있는지 [실측(Debug/시뮬), 동시 실행 1 고정, 각 1회]

| 단계 | peak |
|---|---|
| 1800px 디코딩만 | 114.6 MB |
| 디코딩 + JPEG 인코딩 | 119.9 MB |
| 디코딩 + 인코딩 + 원자적 쓰기(전체) | 105.3 ~ 110.0 MB |
| 전체, 목표를 1350px로 | **76.3 MB** |

**비용은 전부 디코딩이다.** 인코딩과 쓰기는 측정 한계 안에서 0이다. 5400px에서 1800px는 JPEG DCT 배율(n/8)에 딱 떨어지지 않아 ImageIO가 중간 크기(3/8 = 2025px)로 디코딩한 뒤 리샘플한다. 1350px는 5400의 정확히 1/4(2/8)이라 중간 버퍼가 없고, 그래서 peak가 32MB 낮다.

### 표시를 막는가 [실측(Debug/시뮬)]

| 구성 | 표시용 720px 디코딩 중앙값 | 최댓값 | 40장 표시 완료까지 |
|---|---|---|---|
| 마이그레이션 없음 | 19.5 / 19.5 / 20.6 ms | 34.5 ms | 23.8~26.2초 |
| naive | 19.8 / 19.8 / 19.4 ms | 38.9 ms | 24.1~25.6초 |
| 큐 동시 실행 1 | 19.5 / 19.2 / 19.3 ms | 37.6 ms | 24.8~26.2초 |

**표시 지연은 어느 구성에서도 늘지 않았다.** 마이그레이션을 표시 완료 뒤에 `.utility` 우선순위로 던지면 표시 경로와 경쟁하지 않는다. 문제는 지연이 아니라 메모리다.

마이그레이션 자체 비용은 장당 중앙값 50.1ms, 40장 합계 CPU 2.05초다. 스크롤이 26초에 걸쳐 일어나므로 **동시 실행 1이어도 큐가 밀리지 않는다** — 처리량 손해 없이 peak만 62MB 줄인다. 동시 실행 2를 쓸 이유가 없다.

### 결과 검증 [실측(Debug/시뮬)]

| 항목 | 결과 |
|---|---|
| 변환된 파일 | 40/40 (모두 1800px 이하) |
| 디스크 | 22 MB → **3.7 MB** (1350px 목표면 2.4 MB) |
| 잔여 `.tmp` | **0개** |
| 표시 화질 | 피드·캘린더 렌더 정상 |

### 제안하는 구조 (승인 전 미착수)

**1) 동시 실행 1의 직렬 큐**

```
actor PhotoMigrationQueue {
    static let shared = PhotoMigrationQueue()
    private var pending: [String] = []
    private var queued: Set<String> = []     // 같은 ref 중복 적재 방지
    private var running = 0
    private var suspended = false
    private let limit = 1                     // 측정 근거: 1 = 107.8MB, 2 = 158.1MB

    func enqueue(_ ref: String) {
        guard queued.insert(ref).inserted else { return }
        pending.append(ref)
        pump()
    }

    func setSuspended(_ value: Bool) {        // 백그라운드 진입/복귀
        suspended = value
        if !value { pump() }
    }

    private func pump() {
        while !suspended, running < limit, !pending.isEmpty {
            let ref = pending.removeFirst()
            running += 1
            Task.detached(priority: .utility) {
                PhotoMigrator.migrate(ref: ref)
                await PhotoMigrationQueue.shared.finish()
            }
        }
    }

    private func finish() { running -= 1; pump() }
}
```

**2) 표시 먼저, 변환은 뒤에**

```
.task(id: ref) {
    await load(for: ref)                       // 162px 또는 720px 표시 완료
    await PhotoMigrationQueue.shared.enqueue(ref)   // 그 다음에만 적재
}
```

핵심은 세 가지다. 표시 경로(`load`)는 마이그레이션을 **기다리지 않는다**. 적재는 표시가 끝난 뒤에만 한다. 큐 작업은 `.utility`라 표시 디코딩(`.userInitiated`)에 밀린다. 위 표에서 표시 지연이 늘지 않은 것이 이 구조의 실측 근거다.

**3) 백그라운드 진입 / 종료 시 중단과 재개**

| 사건 | 처리 |
|---|---|
| `scenePhase == .background` | `setSuspended(true)`. 실행 중인 1장은 끝까지 두고(50ms), 대기열은 그대로 유지 |
| `scenePhase == .active` | `setSuspended(false)` → `pump()`가 대기열부터 재개 |
| 앱 종료 | 대기열은 메모리에만 있으므로 사라진다. 복구 불필요 — 다음 실행에서 그 사진을 다시 표시하면 다시 적재된다 |
| 강제 종료 / 크래시 | 아래 4)의 원자적 교체가 원본을 지킨다 |

대기열을 디스크에 남기지 않는 것이 의도다. on-access는 "본 사진만 변환"이므로 진행 상태를 저장할 필요가 없고, 저장하면 오히려 재개 로직이 복잡해진다.

**4) 실패 시 원본 유지 보장**

```
guard max(width, height) > 1800 else { return }          // 1) 멱등: 이미 작으면 아무 것도 안 함
guard let cg = CGImageSourceCreateThumbnailAtIndex(...)   // 2) 실패하면 return, 원본 그대로
      let jpeg = ...jpegData(compressionQuality: 0.82) else { return }
let tmp = url.appendingPathExtension("tmp")
guard (try? jpeg.write(to: tmp, options: [.atomic])) != nil else { return }   // 3) 임시 파일에 먼저
_ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)             // 4) 원자적 교체
```

| 중단 시점 | 원본 상태 | 복구 |
|---|---|---|
| 크기 검사 / 디코딩 / 인코딩 실패 | 손대지 않음 | 없음. 다음 접근 시 재시도 |
| `.tmp` 쓰기 중 중단 | 손대지 않음 | 앱 시작 시 `VictoryFairyPhotos/*.tmp` 일괄 삭제 |
| `replaceItemAt` 중 중단 | 원자적이라 중간 상태 없음 | 없음 |
| 교체 완료 후 | 1800px 정상 | 없음. 크기 검사가 재변환을 막아 세대 손실은 1회로 고정 |

원본을 지우는 경로는 존재하지 않는다. 교체만 일어난다. 이번 측정에서 40/40 변환에 잔여 `.tmp` 0개였다.

### A / B 결정에 필요한 수치 정리

| 항목 | 값 | 근거 |
|---|---|---|
| 얻는 것 — 디스크 | 40건×1장 기준 149 MB 회수 | 실사진 12MP 기준, `c4530f5` |
| 얻는 것 — 디코딩 | 표시 디코딩 6.1배 단축(백그라운드) | `c6714f7` |
| 치르는 것 — peak | 55.7 → 107.8 MB (동시 실행 1) | 이번 라운드 |
| 치르는 것 — CPU | 40장 합계 2.05초, 장당 50ms | 이번 라운드 |
| 치르는 것 — 화질 | PSNR 42.2 dB, 육안 구분 불가 | `58d3340` |
| 위험 | 사용자 사진 덮어쓰기(원자적 교체로 방어) | 설계 |

**보고자 의견:** 동시 실행 1이면 peak 107.8MB로 250MB 목표 안이고 표시도 막지 않는다. 다만 기준(55.7MB) 대비 2배이며, 이 비용은 사진을 볼 때마다 잠깐씩 발생한다. 목표를 1350px로 낮추면 76.3MB까지 내려가지만 저장 규격을 바꾸는 결정이라 임의로 정하지 않았다. **A / B 판단은 지시대로 넘긴다.**

---

## 보류 항목 착수 전 조사 (`let id = UUID()` 6개 타입 / `HomeViewModel` / `serverStatus`)

### 1) 대상 6개 타입과 안정 ID 후보 [정적]

| 타입 | 위치 | 후보 | 유일성 근거 | 판정 |
|---|---|---|---|---|
| `MetricViewState` | `VFDomain.swift:270` | `title` | 생성 지점 4곳 모두 리터럴 배열(4~5개, 제목 전부 다름) | **안전** |
| `RankingViewState` | `VFDomain.swift:277` | `title` | 로컬 경로는 `Dictionary(grouping:)` 키 = 제목 | 로컬 안전 / 서버 아래 참조 |
| `StatGroupViewState` | `VFDomain.swift:284` | `name` | 같음 | 로컬 안전 / 서버 아래 참조 |
| `KBOStandingViewState` | `VFDomain.swift:458` | `teamID` | `KBOStandingDTO.id == teamID`, 팀 10개 전부 다름 | **안전** (`rank`는 불가) |
| `CalendarSelectedDay` | `CalendarViews.swift:1062` | `date` | `@State` 단일 옵셔널(시트 item), `ForEach` 아님 | **안전** |
| `AnalysisRankingRowModel` | `WinRateAnalysisView.swift:317` | `title` | `Dictionary(grouping:)` 또는 위 랭킹 배열에서 파생 | 위와 동일 |

### 2) 실제 데이터 중복 검사 [실측 + 정적]

앱에 실려 있는 참조 데이터(`KBOSeed.teams`, 10팀)를 전수 검사했다.

| 필드 | 서로 다른 값 | 중복 |
|---|---|---|
| `id` | 10 | 없음 |
| `name` | 10 | 없음 |
| `shortName` | 10 | 없음 |
| `homeStadiumName` | 9 | **잠실야구장 2건 (LG · 두산)** |

구장 이름에 중복이 하나 있지만 문제되지 않는다. 구장 랭킹 배열은 구장 이름 자체를 키로 그룹핑하므로 잠실야구장 행은 하나뿐이다. 상대팀 배열과 구장 배열은 `ForEach`가 서로 분리되어 있어(`WinRateAnalysisView.swift:115`, `:132`) 두 배열이 합쳐지는 지점도 없다.

로컬 경로는 데이터와 무관하게 안전하다. `Dictionary(grouping:)`의 키는 정의상 유일하므로 배열 안에서 제목이 겹칠 수 없다. 이번 라운드의 시드 40건은 전부 같은 구장·같은 상대라 그룹이 1개로 접히는 것까지 확인했다.

### 3) 서버 경로에서 남는 위험 [정적]

| DTO | `id` 채우는 순서 | 위험 |
|---|---|---|
| `StadiumStatsDTO` | `id` → 없으면 `name` | 없음. `name`보다 나빠지지 않는다 |
| `OpponentStatsDTO` | `id` → `opponentTeamID` → **없으면 `UUID()`** | 서버가 둘 다 빠뜨리면 매 디코딩마다 새 UUID — **DTO `id`를 안정 키로 쓰면 안 된다** |
| `KBOStandingDTO` | `id == teamID`(옵셔널 아님) | 없음 |

서버가 같은 구장/상대를 두 행으로 내려보내면 제목이 겹칠 수 있고, 이는 로컬에서 막을 수 없다. 실서버는 오프라인이라 확인하지 못했다(`실기기/실서버 미측정`).

**제안:** 상대팀은 DTO `id`가 아니라 `name`을 쓰고, 매핑 시점에서 한 번 중복을 접거나(같은 이름 합산) 그대로 두되 `ForEach(Array(...enumerated()), id: \.offset)` 형태로 렌더 쪽에서 방어한다. 어느 쪽을 택할지는 착수 시 결정할 사항이다.

### 4) `HomeViewModel` 생성 위치 [정적]

`AppRootView.swift:47`에서 `MainTabView.body` 안에 있다.

```
case .home:
    NavigationStack {
        HomeView(viewModel: HomeViewModel(dashboard: .sample(logs: appData.feedLogs)))
    }
```

`appData`가 `@EnvironmentObject`이므로 `AppDataStore`의 `@Published` 하나만 바뀌어도 `MainTabView.body`가 다시 평가되고, 그때마다 `DashboardViewState.sample(logs:)`가 로그 전체를 다시 집계해 `MetricViewState` 4개를 **새 UUID로** 만든다. 같은 형태의 생성이 피드(`:51`)·통계(`:59`)에도 있다.

### 5) `serverStatus` 중복 대입 [정적]

`AppDataStore.swift`에서 `serverStatus = .connected` 대입이 **30곳**이다. API 호출이 성공할 때마다 무조건 대입하므로 값이 이미 `.connected`여도 `@Published`가 발행된다. `ServerConnectionStatus`는 이미 `Equatable`(`AppDataStore.swift:22`)이라 guard는 한 줄로 끝난다.

### 착수 전 확인이 필요한 것

지시대로 여기서 멈춘다. 착수 시 검증 지표는 `MetricCard` 재생성 횟수 / `MainTabView.body` 평가 횟수 / `@Published` 변경 24회 전·후이며, 위 3)의 상대팀 키 선택만 결정해 주면 나머지는 정적으로 안전하다.

---

## 사진 분석 격자 + 히트테스트 (대기)

지시대로 손대지 않았다. 다만 이번 라운드에서 부수적으로 확인한 사실 하나를 남긴다: 상단 칩(기본/팀결과/사진)이 합성 클릭에 반응하지 않은 경우가 있었는데, 원인 중 하나는 **시뮬레이터 창이 여러 개 열려 있을 때 자동화가 다른 기기 창을 잡는 것**이었다. 창을 이름으로 지정한 뒤 탭 바 탭은 안정적으로 동작했다. 상단 칩 자체가 실제 손가락 입력에도 문제가 있는지는 확인 대상이 아니므로 판단하지 않는다.

---

## 메모리 트랙 최종 요약 (측정 시점 명시)

각 수치가 어느 커밋의 트리에서 측정된 값인지 함께 적는다. 시점이 섞이면 회귀를 추적할 수 없다.

| 지표 | 시작 | 시작 측정 시점 | 최종 | 최종 측정 시점 |
|---|---|---|---|---|
| 캘린더 사진모드 peak (레거시 5400px 20장) | **2355 MB** | `0086617` 트리 (② 이전), 기록 `c4530f5` | **58.7 ~ 69.8 MB** (5회, 평균 64.0) | **`58d3340` (HEAD, 이번 라운드)** |
| 캘린더 진입 시 메인 스레드 디코딩 | **491 ms** (40회) | `d770d55` 트리, 기록 `7e8ebc8` | **0 ms** (0회) | **`58d3340` (HEAD, 이번 라운드)** |
| 캘린더 3회 진입 총 디코딩 | 120회 | `d770d55` 트리, 기록 `7e8ebc8` | 20회 | **`58d3340` (HEAD, 이번 라운드)** |
| 12MP 첨부 저장 peak | 209.0 MB | `0086617` 이전 트리, 기록 `c4530f5` | 63.4 MB | `d770d55` 트리, 기록 `c4530f5` (재측정 안 함) |
| 저장 해상도 | 5400 × 5400 (의도의 3배) | `0086617` 이전 트리 | 1800 × 1800 | `0086617` 트리, 기록 `5d14ddd` |
| 사진 1장 디스크 (실사진 12MP) | 4269 KB | `0086617` 이전 트리, 기록 `c4530f5` | 456 KB | `d770d55` 트리, 기록 `c4530f5` |

캘린더 peak의 최종값이 ②(`d770d55`) 시점의 55.5MB보다 평균 8.5MB 높은 것은 회귀가 아니라 ③④의 구조적 대가다(백그라운드 디코딩 작업 버퍼가 동시에 여러 개 산다). 대신 메인 스레드 멈춤 491ms와 재진입 재디코딩 100회가 사라졌다.

| 커밋 | 내용 |
|---|---|
| `0086617` | 저장 렌더 scale 1 고정 (maxPixel이 실제 픽셀이 되도록) |
| `d770d55` | 표시 지점 다운샘플 + 저장 경로 ImageIO 전환 |
| `f4ff3fe` | 오프메인 디코딩 + NSCache |
| `21a2db7` | 캐시 등급별 분리 (썸네일 8MB + 대형 32MB) |

측정 리포트 커밋: `5d14ddd`, `c4530f5`, `7e8ebc8`, `c6714f7`, `58d3340`.

메모리 트랙은 종료 상태를 유지한다. 대기 중인 항목: 마이그레이션 B(A/B 결정 대기), `let id = UUID()` 제거 6개 타입 + `HomeViewModel` 생성 위치 이동 + `serverStatus` guard(착수 전 조사 완료, 승인 대기), 사진 분석 격자·히트테스트(사용자 확인 대기), timeout / 전역 데드라인(백로그 유지).

---

## 작업 [5] — 재렌더 위생 (커밋 대상, [5-a] 조사 → [5-b/c/d] 착수)

### [5-a] 상대팀 키 — 착수 전 확인

**실서버 응답은 확보하지 못했다.** `API_BASE_URL`은 Dev가 `localhost:8081`, Production이 `victoryfairy.duckdns.org`인데 둘 다 오프라인이라 `/api/v1/statistics/opponents`의 실제 바디를 받아 name 중복을 직접 셀 수 없었다. 대신 계약과 코드 경로로 확인했다.

| 확인 | 결과 |
|---|---|
| 엔드포인트 의미 | 기획서상 "상대팀별 성적" — 상대팀 단위 집계라 팀당 1행 |
| `OpponentStatsDTO` 필드 | id, name, totalGames, wins, losses, draws, canceled, winRate — **홈/원정·구장 같은 분리 축이 없다.** 한 팀을 두 행으로 쪼갤 필드가 구조적으로 없음 |
| 로컬 집계 경로 | `Dictionary(grouping: logs, by: opponentName)` — 키가 곧 name이라 배열 안에서 유일 |
| 팀 이름 실데이터 | `KBOSeed.teams` 10팀 이름 전부 다름 |

**결론: 정상 응답에서 name 중복은 발생할 수 없다. 복합 키 불필요, name을 그대로 ForEach 키로 쓴다.** 홈/원정 분리 같은 구분 축은 DTO에 존재하지 않으므로 구분자도 없다.

한 가지 남는 엣지는 기록해 둔다: 서버가 `id`/`teamName`을 모두 비운 미지의 상대 2건을 보내면 DTO가 name을 `"상대팀"`으로 채워 중복이 생긴다(구장은 `"구장 미정"`). 고정 10팀 KBO에서 일어날 계약은 아니지만 구조적으로 불가능하진 않다. 이 경우에도 크래시가 아니라 SwiftUI ForEach의 행 재사용 경고 수준이며, 필요해지면 매퍼에서 name 합산으로 접으면 된다. 지금은 지시대로 name 키로 진행한다.

**UUID를 쓴 이유:** 코드·커밋에 의도적 근거가 없다. 6개 타입의 `let id = UUID()`는 모두 초기 커밋(`590fbc5`, `f61976c`, `9bd3de5`)에서 왔고 설명 주석·메시지가 없다. "Identifiable을 빨리 만족시키는 SwiftUI 기본 관용구"이지 서버 중복 방어 의도가 아니다. **착수를 막을 이유 없음.**

### [5-b] 6개 타입 안정 ID (커밋 대상)

| 타입 | 파일 | 이전 | 이후 |
|---|---|---|---|
| `MetricViewState` | VFDomain.swift | `let id = UUID()` | `var id: String { title }` |
| `RankingViewState` | VFDomain.swift | `let id = UUID()` | `var id: String { title }` |
| `StatGroupViewState` | VFDomain.swift | `let id = UUID()` | `var id: String { name }` |
| `KBOStandingViewState` | VFDomain.swift | `let id = UUID()` | `var id: String { teamName }` |
| `CalendarSelectedDay` | CalendarViews.swift | `let id = UUID()` | `var id: Date { date }` |
| `AnalysisRankingRowModel` | WinRateAnalysisView.swift | `let id = UUID()` | `var id: String { title }` |

`KBOStandingViewState`는 순위(rank)가 동순위 타이로 겹칠 수 있어 `teamName`을 골랐다(팀 이름 10개는 항상 다름). `CalendarSelectedDay`는 `.sheet(item:)`에 쓰이는데, 날짜 기반 ID로 바꾸면 필터 변경 후 같은 날짜를 다시 세팅하는 `refreshSelectedDay()`에서 시트가 다시 뜨지 않고 그 자리에서 로그만 갱신된다(UUID일 때는 매번 새 ID라 재표시=깜빡임이었다). 개선이다.

`Set`/직접 `==` 사용처는 전수 조사에서 0곳이었다. `id`를 stored UUID에서 computed로 바꿔도 `Equatable`/`Hashable` 합성이 나머지 저장 프로퍼티로 유지되고, 렌더는 `ForEach(id: \.element.id)` 경로뿐이라 영향이 국소적이다.

### [5-c] HomeViewModel 생성 위치 이동 (커밋 대상)

`HomeViewModel(dashboard: .sample(logs: appData.feedLogs))`가 `MainTabView.body` 안에 있어, `@EnvironmentObject`의 어떤 `@Published`가 바뀌어도 body가 재평가될 때마다 로그 40건을 다시 정렬·그룹핑했다. `AppDataStore.feedLogs`에 `didSet`을 달아 **feedLogs가 바뀔 때만** 대시보드를 1회 집계해 `@Published homeDashboard`로 보관하고, body는 그 값을 참조만 한다.

### [5-d] serverStatus guard (같은 커밋)

`serverStatus = X` 대입 54곳을 `setServerStatus(X)`로 바꾸고, 그 안에서 `guard newValue != serverStatus else { return }`로 중복 대입을 막았다. `ServerConnectionStatus`는 이미 `Equatable`이다. 매 요청 성공/실패마다 무조건 대입하며 값이 같아도 `@Published`가 발행되던 것을 없앤다.

### 검증 [실측(Debug/시뮬), `#if DEBUG` 프로브, 각 3회] — 콜드 스타트 후 탭 3바퀴

계측: `MainTabView.body`·`MetricCard.body`·`HomeDashboard.sample` 카운터와 `AppDataStore.objectWillChange` 구독. **프로브는 측정 후 전량 제거**(`grep VFProbe` 0건, `git status`에 계측 흔적 없음, Debug/Release 둘 다 빌드 통과).

| 지표 | 이전(HEAD+프로브) | 이후(전체 적용) | 담당 |
|---|---|---|---|
| `MetricCard.body` (콜드) | 8 / 12 / 8 | **4 / 4 / 4** | [5-b] 안정 ID가 재생성 제거 |
| `HomeDashboard.sample` 호출 (콜드) | 7 | **1** | [5-c] 집계를 feedLogs 변경 시 1회로 |
| `HomeDashboard.sample` 호출 (탭 3바퀴 후) | 10 | **1** | [5-c] 탭 복귀·재렌더에도 재집계 없음 |
| `AppDataStore.objectWillChange` (콜드) | 18 | **15** | [5-d] guard가 중복 발행 제거 |
| `MainTabView.body` (콜드) | 6~9 | 6~7 | 변화 없음(의도) |

핵심을 분해하면 두 가지다. **[5-b]** 안정 ID만으로 `MetricCard.body`가 9→4로 떨어진다(제목이 같으면 SwiftUI가 같은 셀로 보고 재생성하지 않음). **[5-c]** 는 `MetricCard` 수를 더 줄이진 않지만 40건 정렬·그룹핑 실행을 7→1(탭을 돌려도 1)로 없앤다 — 셀이 재생성되지 않아도 매 body마다 돌던 CPU 작업이다.

정직하게 적을 점: `MetricCard.body`의 **탭 복귀 증가분(바퀴당 약 4)은 전후가 같다.** 탭 전환은 `selectedContent` switch가 Home 뷰 트리를 통째로 헐고 복귀 시 다시 만들기 때문이며, 안정 ID로는 막지 못한다(이번 작업 범위 밖). 이번 변경이 없애는 것은 (1) Home에 머문 채 `@Published`가 바뀔 때의 재렌더와 (2) 매 body의 40건 재집계다. 회귀는 없다.

`@Published` 수치가 지시서의 참조값(콜드 24회)과 다른 것은 측정창 차이다. 이번 프로브는 `objectWillChange` 구독을 init 끝에 걸어 **init 내부의 초기 대입(약 7건)을 세지 않는다** — 그래서 절대값이 낮다. 전후를 같은 방법으로 재서 얻은 델타(18→15)가 판단 근거다. `feedLogs.didSet`이 `homeDashboard` 발행을 1건 더하지만, guard가 serverStatus 중복 약 4건을 없애 순감이다.

### 렌더 정상 확인 [실측(Debug/시뮬), 스크린샷]

레거시 40장 시드 상태에서 클린 빌드로 홈·통계(내 직관)를 렌더: 홈 지표 카드 4개(총 직관/시즌 승률/최근 흐름/최다 구장), 통계 KPI 4개, 승률 분석 진입점이 모두 정상. ID를 name/title로 바꾼 뒤에도 ForEach가 깨지지 않았다.

### 파일 범위 주의

지시서는 "VFDomain.swift / MainTabView.swift / AppDataStore.swift만 건드린다"였으나 실제로 **5개 파일**을 건드렸다. `MainTabView`는 별도 파일이 아니라 `AppRootView.swift`에 있고, `CalendarSelectedDay`(CalendarViews.swift)·`AnalysisRankingRowModel`(WinRateAnalysisView.swift)은 [5-b]가 지정한 6개 타입에 포함되지만 VFDomain에 없다. 두 파일 모두 탭바 파일이 아니므로 **탭바 작업과의 병렬 가능성은 그대로 유지된다.**

| 파일 | 변경 |
|---|---|
| `Domain/VFDomain.swift` | Metric/Ranking/StatGroup/KBOStanding 4개 타입 안정 ID |
| `AppRootView.swift` | MainTabView.body가 `appData.homeDashboard` 참조 |
| `Services/AppDataStore.swift` | homeDashboard 파생 + feedLogs.didSet + setServerStatus guard |
| `Features/Calendar/CalendarViews.swift` | CalendarSelectedDay 안정 ID |
| `Features/Analysis/WinRateAnalysisView.swift` | AnalysisRankingRowModel 안정 ID |

남은 대기 항목: 마이그레이션 B(A/B 결정 대기), 사진 분석 격자·히트테스트(사용자 확인 대기), timeout / 전역 데드라인(백로그 유지).
