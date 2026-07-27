import XCTest
@testable import VictoryFairy

/// 탭 경로 계약과 날짜·숫자 표기가 흔들리지 않는지 확인한다.
final class NavigationAndFormattingTests: XCTestCase {

    // MARK: - 탭 경로 계약

    /// Pencil이 라벨을 기록·시즌으로 바꿨어도 경로 식별자는 그대로여야 한다.
    func testTabRouteIdentifiersRemainStable() {
        XCTAssertEqual(MainTab.home.rawValue, "home")
        XCTAssertEqual(MainTab.feed.rawValue, "feed")
        XCTAssertEqual(MainTab.calendar.rawValue, "calendar")
        XCTAssertEqual(MainTab.statistics.rawValue, "statistics")
        XCTAssertEqual(MainTab.my.rawValue, "my")
    }

    /// 재설계 이전의 네 경로가 하나도 사라지지 않았는지 본다.
    func testPreExistingRoutesAreAllStillPresent() {
        let routes = Set(MainTab.allCases.map(\.rawValue))
        for legacy in ["home", "feed", "calendar", "statistics"] {
            XCTAssertTrue(routes.contains(legacy), "\(legacy) 경로가 사라졌다")
        }
    }

    func testTabOrderMatchesPencilTabBar() {
        XCTAssertEqual(MainTab.allCases, [.home, .feed, .calendar, .statistics, .my])
    }

    func testTabAccessibilityIdentifiersAreStableAndUnique() {
        let identifiers = MainTab.allCases.map(\.accessibilityIdentifier)
        XCTAssertEqual(identifiers, ["tab.home", "tab.feed", "tab.calendar", "tab.statistics", "tab.my"])
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func testEveryTabHasKoreanLabelAndIcon() {
        for tab in MainTab.allCases {
            XCTAssertFalse(tab.title.isEmpty, "\(tab.rawValue) 라벨 없음")
            XCTAssertFalse(tab.systemImage.isEmpty, "\(tab.rawValue) 아이콘 없음")
        }
        XCTAssertEqual(MainTab.allCases.map(\.title), ["홈", "기록", "캘린더", "시즌", "마이"])
    }

    // MARK: - 날짜 표기

    /// 앱의 모든 표시 포매터는 같은 로캘과 시간대를 써야 한다.
    func testDisplayFormattersAreLocaleAndTimeZoneSafe() {
        let formatters: [(String, DateFormatter)] = [
            ("vfAPIDate", .vfAPIDate),
            ("vfDisplayDate", .vfDisplayDate),
            ("vfDisplayDateTime", .vfDisplayDateTime),
            ("vfHomeGreetingDate", .vfHomeGreetingDate),
            ("vfRecordStubMonth", .vfRecordStubMonth),
            ("vfRecordStubDay", .vfRecordStubDay),
            ("vfRecordStubWeekday", .vfRecordStubWeekday),
            ("vfFeedMonthKey", .vfFeedMonthKey),
            ("vfFeedMonthLabel", .vfFeedMonthLabel)
        ]
        for (name, formatter) in formatters {
            XCTAssertEqual(formatter.locale.identifier, "ko_KR", "\(name) 로캘이 다르다")
            XCTAssertEqual(formatter.timeZone.identifier, "Asia/Seoul", "\(name) 시간대가 다르다")
        }
    }

    /// 시간대 경계에서 날짜가 하루 밀리면 안 된다.
    /// 한국시각 2026-04-13 00:30은 UTC로는 전날 15:30이다.
    func testRecordStubUsesKoreanCalendarDayAcrossTimeZoneBoundary() {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 13
        components.hour = 0
        components.minute = 30
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        let date = try! XCTUnwrap(components.date)

        XCTAssertEqual(DateFormatter.vfRecordStubDay.string(from: date), "13")
        XCTAssertEqual(DateFormatter.vfRecordStubMonth.string(from: date), "4월")
        XCTAssertEqual(DateFormatter.vfFeedMonthKey.string(from: date), "2026-04")
    }

    // MARK: - 피드 월 묶기

    func testFeedMonthSectionsGroupAndSortNewestFirst() {
        let logs = [
            makeLog(year: 2026, month: 4, day: 5),
            makeLog(year: 2026, month: 4, day: 12),
            makeLog(year: 2026, month: 3, day: 28)
        ]
        let sections = FeedViewModel.monthSections(from: logs)

        XCTAssertEqual(sections.map(\.id), ["2026-04", "2026-03"], "최신 월이 먼저 와야 한다")
        XCTAssertEqual(sections.first?.title, "4월")
        XCTAssertEqual(sections.first?.logs.count, 2)
        // 월 안에서도 최신 기록이 먼저.
        XCTAssertEqual(
            sections.first?.logs.map { Calendar(identifier: .gregorian).component(.day, from: $0.date) },
            [12, 5]
        )
    }

    func testFeedMonthSectionsAreEmptyForNoLogs() {
        XCTAssertTrue(FeedViewModel.monthSections(from: []).isEmpty)
    }

    func testFeedSummaryNeverInventsCounts() {
        XCTAssertEqual(FeedViewModel(logs: []).summaryText, "아직 기록이 없어요")
        XCTAssertEqual(FeedViewModel(logs: [makeLog(year: 2026, month: 4, day: 1)]).summaryText, "1개의 기억")
    }

    // MARK: - 상태 모델

    /// 로딩·빈 상태·오류가 모두 화면에서 도달 가능한 값으로 남아 있어야 한다.
    func testRemoteDataStatesRemainReachable() {
        let states: [RemoteDataState] = [
            .loading,
            .loaded,
            .empty,
            .localOnly("오프라인"),
            .serverErrorUsingLocal("서버 오류"),
            .error("연결 실패")
        ]
        XCTAssertEqual(states.count, 6)
    }

    // MARK: - 도우미

    private func makeLog(year: Int, month: Int, day: Int) -> AttendanceLogViewState {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 19
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        let date = components.date ?? .now
        return AttendanceLogViewState(
            id: UUID(),
            date: date,
            dateText: "\(year).\(month).\(day)",
            matchup: "삼성 vs LG",
            stadium: "잠실야구장",
            result: .win,
            ourScore: 6,
            opponentScore: 3,
            seat: "3루 원정석",
            companion: "엄마랑",
            memo: "",
            caption: "",
            diary: "9회말 역전.",
            tags: [],
            photoLocalRefs: []
        )
    }
}
