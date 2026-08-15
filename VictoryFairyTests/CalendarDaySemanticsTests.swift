import XCTest
@testable import VictoryFairy

/// 날짜 칸의 정체성과, 색 없이도 남는 의미를 확인한다.
///
/// 화면 없이 검사할 수 있도록 순수 계산으로 만들어 두었기 때문에,
/// 여기서 확인한 문장이 곧 VoiceOver가 읽는 문장이다.
final class CalendarDaySemanticsTests: XCTestCase {

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

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, inMonth: Bool = true) -> CalendarDay {
        let target = date(year, month, dayOfMonth)
        let geometry = CalendarMonth.make(containing: target, calendar: calendar)
        return geometry.days.first {
            calendar.isDate($0.date, inSameDayAs: target) && $0.isInDisplayedMonth == inMonth
        }!
    }

    private func record(
        day dayOfMonth: Int,
        result: GameResult,
        matchup: String = "삼성 vs LG",
        photos: [String] = []
    ) -> AttendanceLogViewState {
        AttendanceLogViewState(
            // 결과까지 ID에 반영한다. 실제 기록은 ID가 겹치지 않는다.
            id: UUID(uuidString: String(
                format: "DA1E0000-0000-4000-8000-%06d%06d",
                dayOfMonth, GameResult.allCases.firstIndex(of: result) ?? 0
            ))!,
            date: date(2026, 4, dayOfMonth),
            dateText: "",
            matchup: matchup,
            stadium: "잠실야구장",
            result: result,
            ourScore: 6,
            opponentScore: 3,
            seat: "",
            companion: "",
            memo: "",
            caption: "",
            diary: "",
            tags: [],
            photoLocalRefs: photos
        )
    }

    // MARK: - 정체성

    /// 날짜 칸의 식별자는 ISO 날짜다. 격자 순번이나 표시 문구가 아니다.
    func testDayIdentifierIsTheISODate() {
        XCTAssertEqual(day(2026, 4, 12).identifier, "2026-04-12")
        XCTAssertEqual(day(2026, 4, 12).accessibilityIdentifier, "calendar.day.2026-04-12")
        XCTAssertEqual(day(2026, 12, 31).accessibilityIdentifier, "calendar.day.2026-12-31")
        XCTAssertEqual(day(2024, 2, 29).accessibilityIdentifier, "calendar.day.2024-02-29")
    }

    /// 한 달 안의 모든 칸이 서로 다른 식별자를 갖는다. 앞뒤 달 칸도 포함한다.
    func testEveryCellInAMonthHasAUniqueIdentifier() {
        for month in 1...12 {
            let geometry = CalendarMonth.make(containing: date(2026, month, 1), calendar: calendar)
            let identifiers = geometry.days.map(\.accessibilityIdentifier)
            XCTAssertEqual(Set(identifiers).count, identifiers.count,
                           "2026-\(month) 격자에 같은 식별자가 두 번 나온다")
            for identifier in identifiers {
                XCTAssertTrue(identifier.hasPrefix("calendar.day."))
                XCTAssertEqual(identifier.count, "calendar.day.2026-04-12".count,
                               "식별자 형식이 흔들린다: \(identifier)")
            }
        }
    }

    /// 앞뒤 달에서 넘어온 칸은 그 달의 실제 날짜로 식별된다.
    func testAdjacentMonthCellsCarryTheirOwnRealDate() {
        let april = CalendarMonth.make(containing: date(2026, 4, 12), calendar: calendar)
        XCTAssertEqual(april.days.first?.accessibilityIdentifier, "calendar.day.2026-03-29")
        XCTAssertEqual(april.days.last?.accessibilityIdentifier, "calendar.day.2026-05-02")
    }

    /// 같은 날짜라면 어느 달의 격자에서 보든 식별자가 같다.
    func testTheSameDateHasTheSameIdentifierAcrossMonthGrids() {
        let fromApril = CalendarMonth.make(containing: date(2026, 4, 12), calendar: calendar)
            .days.first { $0.day == 30 && !$0.isInDisplayedMonth }
        let fromMarch = CalendarMonth.make(containing: date(2026, 3, 12), calendar: calendar)
            .days.first { $0.day == 30 && $0.isInDisplayedMonth }
        XCTAssertEqual(fromApril?.accessibilityIdentifier, "calendar.day.2026-03-30")
        XCTAssertEqual(fromMarch?.accessibilityIdentifier, "calendar.day.2026-03-30")
    }

    // MARK: - 색 없이 남는 의미

    func testEmptyDayAnnouncesOnlyItsDate() {
        let semantics = CalendarDaySemantics(
            day: day(2026, 4, 20), events: [], isSelected: false, isToday: false
        )
        XCTAssertEqual(semantics.label, "4월 20일 월요일")
        XCTAssertEqual(semantics.value, "")
    }

    func testResultIsAnnouncedAsWordsNotColour() {
        for (result, expected) in [(GameResult.win, "승"), (.loss, "패"), (.draw, "무"), (.canceled, "취소")] {
            let semantics = CalendarDaySemantics(
                day: day(2026, 4, 12), events: [record(day: 12, result: result)],
                isSelected: false, isToday: false
            )
            XCTAssertTrue(semantics.value.contains(expected),
                          "\(result) 결과가 읽히지 않는다: \(semantics.value)")
            XCTAssertTrue(semantics.value.contains("삼성 vs LG"))
        }
    }

    func testSelectedTodayAndAdjacentAreAllAnnounced() {
        let selected = CalendarDaySemantics(
            day: day(2026, 4, 12), events: [], isSelected: true, isToday: false
        )
        XCTAssertTrue(selected.value.contains("선택됨"))

        let today = CalendarDaySemantics(
            day: day(2026, 4, 12), events: [], isSelected: false, isToday: true
        )
        XCTAssertTrue(today.value.contains("오늘"))

        let adjacent = CalendarDaySemantics(
            day: CalendarMonth.make(containing: date(2026, 4, 1), calendar: calendar).days[0],
            events: [], isSelected: false, isToday: false
        )
        XCTAssertTrue(adjacent.value.contains("다른 달"), "앞 달 칸임을 알리지 않는다")
    }

    func testMultipleEventsAnnounceTheCountAndTheRepresentativeResult() {
        let semantics = CalendarDaySemantics(
            day: day(2026, 4, 12),
            events: [record(day: 12, result: .win), record(day: 12, result: .loss)],
            isSelected: true, isToday: false
        )
        XCTAssertTrue(semantics.value.contains("기록 2개"), semantics.value)
        XCTAssertTrue(semantics.value.contains("선택됨"))
        XCTAssertNotNil(semantics.primaryEvent)
    }

    func testPhotoPresenceIsAnnounced() {
        let withPhoto = CalendarDaySemantics(
            day: day(2026, 4, 12), events: [record(day: 12, result: .win, photos: ["a.jpg"])],
            isSelected: false, isToday: false
        )
        XCTAssertTrue(withPhoto.hasPhoto)
        XCTAssertTrue(withPhoto.value.contains("사진 있음"))

        let withoutPhoto = CalendarDaySemantics(
            day: day(2026, 4, 12), events: [record(day: 12, result: .win)],
            isSelected: false, isToday: false
        )
        XCTAssertFalse(withoutPhoto.value.contains("사진"))
    }

    /// 읽어 주는 문장에 내부 이름이나 자원 키가 섞이면 안 된다.
    func testSpokenTextCarriesNoInternalIdentifiers() {
        let semantics = CalendarDaySemantics(
            day: day(2026, 4, 12),
            events: [record(day: 12, result: .win)],
            isSelected: true, isToday: true
        )
        let spoken = semantics.label + " " + semantics.value
        for forbidden in ["calendar.", "CA1E0DA0", "win", "loss", "draw", "canceled",
                          "rawValue", "_", "Identifier"] {
            XCTAssertFalse(spoken.contains(forbidden), "읽는 문장에 내부 이름이 섞였다: \(forbidden)")
        }
    }

    /// 같은 입력이면 언제나 같은 문장을 읽는다.
    func testSemanticsAreDeterministic() {
        let events = [record(day: 12, result: .win), record(day: 12, result: .loss)]
        let first = CalendarDaySemantics(day: day(2026, 4, 12), events: events,
                                         isSelected: true, isToday: false)
        let second = CalendarDaySemantics(day: day(2026, 4, 12), events: events.reversed(),
                                          isSelected: true, isToday: false)
        XCTAssertEqual(first.value, second.value, "넣는 순서에 따라 읽는 문장이 달라진다")
    }

    /// 화면이 날짜 식별자를 직접 만들지 않고 도메인 값을 쓴다.
    func testViewUsesTheDomainIdentifierRatherThanBuildingItsOwn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(
            contentsOf: root.appendingPathComponent("VictoryFairy/Features/Calendar/CalendarViews.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(view.contains("day.accessibilityIdentifier"),
                      "화면이 도메인 식별자를 쓰지 않는다")
        XCTAssertTrue(view.contains("CalendarDaySemantics"),
                      "화면이 의미 모델을 쓰지 않는다")
        XCTAssertFalse(view.contains("\"calendar.day.\\("),
                       "화면이 날짜 식별자를 직접 조립한다")
    }
}
