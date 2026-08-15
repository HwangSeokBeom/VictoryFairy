import XCTest
@testable import VictoryFairy

/// 달력 기하 구조가 Pencil 표본이 아니라 실제 날짜 계산에서 나오는지 확인한다.
final class CalendarTests: XCTestCase {

    /// 모든 계산은 명시한 달력·시간대에서 한다. 시뮬레이터 설정에 흔들리지 않게 한다.
    private let calendar = CalendarMonth.referenceCalendar()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        return components.date!
    }

    private func inMonthDays(_ month: CalendarMonth) -> [CalendarDay] {
        month.days.filter(\.isInDisplayedMonth)
    }

    // MARK: - 시간대 정책

    func testReferenceCalendarPolicyIsExplicit() {
        XCTAssertEqual(calendar.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(calendar.identifier, .gregorian)
        XCTAssertEqual(calendar.firstWeekday, 1, "요일 행이 일요일부터 시작해야 한다")
    }

    // MARK: - 달 길이

    func testFebruaryInLeapYearHas29Days() {
        let month = CalendarMonth.make(containing: date(2024, 2, 10), calendar: calendar)
        XCTAssertEqual(inMonthDays(month).count, 29)
    }

    func testFebruaryInNonLeapYearHas28Days() {
        let month = CalendarMonth.make(containing: date(2026, 2, 10), calendar: calendar)
        XCTAssertEqual(inMonthDays(month).count, 28)
    }

    /// 100의 배수지만 400의 배수가 아닌 해는 윤년이 아니다.
    func testCenturyNonLeapYearIsHandled() {
        let month = CalendarMonth.make(containing: date(2100, 2, 10), calendar: calendar)
        XCTAssertEqual(inMonthDays(month).count, 28)
    }

    func testThirtyDayMonth() {
        let month = CalendarMonth.make(containing: date(2026, 4, 15), calendar: calendar)
        XCTAssertEqual(inMonthDays(month).count, 30)
    }

    func testThirtyOneDayMonth() {
        let month = CalendarMonth.make(containing: date(2026, 5, 15), calendar: calendar)
        XCTAssertEqual(inMonthDays(month).count, 31)
    }

    // MARK: - 격자 구조

    /// 모든 달은 7의 배수 칸으로 채워져야 주 배열이 어긋나지 않는다.
    func testGridIsAlwaysWholeWeeks() {
        for month in 1...12 {
            for year in [2024, 2025, 2026] {
                let geometry = CalendarMonth.make(containing: date(year, month, 1), calendar: calendar)
                XCTAssertEqual(
                    geometry.days.count % 7, 0,
                    "\(year)-\(month) 격자가 주 단위로 떨어지지 않는다"
                )
                XCTAssertEqual(geometry.weeks.count, geometry.days.count / 7)
                for week in geometry.weeks {
                    XCTAssertEqual(week.count, 7, "\(year)-\(month)에 7칸이 아닌 주가 있다")
                }
            }
        }
    }

    /// 2026년 3월 1일은 일요일이라 앞쪽 채움이 없어야 한다.
    func testMonthBeginningOnSundayHasNoLeadingCells() {
        let month = CalendarMonth.make(containing: date(2026, 3, 5), calendar: calendar)
        XCTAssertTrue(month.days.first?.isInDisplayedMonth == true, "일요일 시작인데 앞 칸이 생겼다")
        XCTAssertEqual(month.days.first?.day, 1)
        XCTAssertEqual(month.days.first?.isSunday, true)
    }

    /// 2026년 8월 1일은 토요일이라 앞쪽에 6칸이 채워져야 한다.
    func testMonthBeginningOnSaturdayHasSixLeadingCells() {
        let month = CalendarMonth.make(containing: date(2026, 8, 5), calendar: calendar)
        let leading = month.days.prefix { !$0.isInDisplayedMonth }
        XCTAssertEqual(leading.count, 6)
        XCTAssertEqual(month.days[6].day, 1)
        XCTAssertEqual(month.days[6].isSaturday, true)
    }

    /// 첫날과 마지막 날이 올바른 열에 놓여야 한다.
    func testFirstAndLastDayLandInTheCorrectColumn() {
        let month = CalendarMonth.make(containing: date(2026, 4, 12), calendar: calendar)
        let inMonth = inMonthDays(month)
        let firstIndex = month.days.firstIndex { $0.isInDisplayedMonth }!
        let lastIndex = month.days.lastIndex { $0.isInDisplayedMonth }!

        // 2026-04-01은 수요일 → 0-based 열 3.
        XCTAssertEqual(firstIndex % 7, 3, "첫날 열이 어긋났다")
        // 2026-04-30은 목요일 → 0-based 열 4.
        XCTAssertEqual(lastIndex % 7, 4, "마지막 날 열이 어긋났다")
        XCTAssertEqual(inMonth.first?.day, 1)
        XCTAssertEqual(inMonth.last?.day, 30)
    }

    /// 앞뒤 채움 칸은 이전·다음 달의 실제 날짜여야 한다.
    func testAdjacentCellsCarryRealNeighbouringDates() {
        let month = CalendarMonth.make(containing: date(2026, 4, 12), calendar: calendar)
        let leading = month.days.prefix { !$0.isInDisplayedMonth }
        XCTAssertEqual(leading.map(\.day), [29, 30, 31], "3월 말일이 앞 칸에 오지 않았다")
        let trailing = month.days.reversed().prefix { !$0.isInDisplayedMonth }.reversed()
        XCTAssertEqual(trailing.map(\.day), [1, 2], "5월 초가 뒤 칸에 오지 않았다")
    }

    /// 날짜는 기준 시간대의 자정으로 정규화돼야 같은 날이 하나로 모인다.
    func testDatesAreNormalisedToStartOfDay() {
        let month = CalendarMonth.make(containing: date(2026, 4, 12), calendar: calendar)
        for day in month.days {
            XCTAssertEqual(calendar.startOfDay(for: day.date), day.date, "자정으로 정규화되지 않았다")
        }
        XCTAssertEqual(Set(month.days.map(\.date)).count, month.days.count, "같은 날짜 칸이 중복된다")
    }

    // MARK: - 달 이동

    func testMovingForwardCrossesYearBoundary() {
        let december = date(2026, 12, 10)
        let january = CalendarMonth.month(byAdding: 1, to: december, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: january), 2027)
        XCTAssertEqual(calendar.component(.month, from: january), 1)
    }

    func testMovingBackwardCrossesYearBoundary() {
        let january = date(2026, 1, 10)
        let december = CalendarMonth.month(byAdding: -1, to: january, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: december), 2025)
        XCTAssertEqual(calendar.component(.month, from: december), 12)
    }

    /// 달 이동은 항상 그 달의 1일로 정규화돼야 반복 이동이 어긋나지 않는다.
    func testMonthNavigationNormalisesToFirstOfMonth() {
        var cursor = date(2026, 1, 31)
        for _ in 0..<12 {
            cursor = CalendarMonth.month(byAdding: 1, to: cursor, calendar: calendar)
            XCTAssertEqual(calendar.component(.day, from: cursor), 1, "달 이동이 1일로 정규화되지 않았다")
        }
        XCTAssertEqual(calendar.component(.year, from: cursor), 2027)
        XCTAssertEqual(calendar.component(.month, from: cursor), 1)
    }

    // MARK: - 선택 날짜 보정

    /// 31일을 고른 채 30일까지인 달로 가면 30일로 당겨야 한다.
    func testSelectionClampsWhenTargetMonthIsShorter() {
        let april = date(2026, 4, 1)
        let clamped = CalendarMonth.clampedSelection(day: 31, in: april, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: clamped!), 30)
        XCTAssertEqual(calendar.component(.month, from: clamped!), 4, "다른 달로 넘어가 버렸다")
    }

    func testSelectionClampsIntoFebruary() {
        let february = date(2026, 2, 1)
        let clamped = CalendarMonth.clampedSelection(day: 31, in: february, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: clamped!), 28)
        XCTAssertEqual(calendar.component(.month, from: clamped!), 2)
    }

    func testSelectionKeepsValidDay() {
        let april = date(2026, 4, 1)
        let clamped = CalendarMonth.clampedSelection(day: 12, in: april, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: clamped!), 12)
    }

    // MARK: - 요일 라벨

    /// 요일 라벨은 배열을 직접 적어두지 않고 로캘에서 가져온다.
    func testWeekdaySymbolsComeFromLocaleAndStartOnSunday() {
        let symbols = CalendarMonth.weekdaySymbols(calendar: calendar, locale: Locale(identifier: "ko_KR"))
        XCTAssertEqual(symbols.count, 7)
        XCTAssertEqual(symbols.first, "일", "요일 행이 일요일부터 시작해야 한다")
        XCTAssertEqual(symbols.last, "토")
    }

    /// 로캘이 바뀌어도 날짜 정체성은 바뀌지 않는다. 라벨만 달라진다.
    func testLocaleChangesLabelsButNotDateIdentity() {
        let korean = CalendarMonth.weekdaySymbols(calendar: calendar, locale: Locale(identifier: "ko_KR"))
        let english = CalendarMonth.weekdaySymbols(calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertNotEqual(korean, english, "로캘이 달라도 라벨이 같다")

        let month = CalendarMonth.make(containing: date(2026, 4, 12), calendar: calendar)
        XCTAssertEqual(month.days.count, 35)
        XCTAssertEqual(inMonthDays(month).count, 30)
    }

    // MARK: - 화면이 날짜를 직접 계산하지 않는지

    func testCalendarViewDelegatesGeometryToTheDomainModel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(
            contentsOf: root.appendingPathComponent("VictoryFairy/Features/Calendar/CalendarViews.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(view.contains("CalendarMonth.make"), "화면이 달 기하 구조를 도메인 모델에서 받지 않는다")
        XCTAssertTrue(view.contains("CalendarMonth.weekdaySymbols"), "요일 라벨을 직접 적어두고 있다")
        XCTAssertFalse(
            view.contains("range(of: .day, in: .month"),
            "화면이 달 길이를 직접 계산한다"
        )
        XCTAssertFalse(view.contains("StatisticsService("), "캘린더가 통계를 직접 계산한다")
    }

    /// 캘린더는 저장소를 바꾸지 않는다.
    func testCalendarDoesNotMutatePersistence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(
            contentsOf: root.appendingPathComponent("VictoryFairy/Features/Calendar/CalendarViews.swift"),
            encoding: .utf8
        )
        for forbidden in ["modelContext.insert", "modelContext.delete", "try context.save"] {
            XCTAssertFalse(view.contains(forbidden), "캘린더가 저장소를 직접 바꾼다: \(forbidden)")
        }
    }
}
