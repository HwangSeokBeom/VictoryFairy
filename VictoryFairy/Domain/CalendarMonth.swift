import Foundation

/// 달력 한 칸.
///
/// 표시에 필요한 의미만 담는다. 색은 들어 있지 않다. 화면이 이 값을 보고
/// 색과 모양을 정하며, 색 없이도 의미가 남도록 라벨을 따로 만든다.
struct CalendarDay: Identifiable, Hashable {
    /// 그 날 자정(기준 시간대)의 시각. 셀의 정체성이다.
    let date: Date
    /// 화면에 찍는 숫자.
    let day: Int
    /// 지금 보고 있는 달에 속하는지. 앞뒤 달에서 넘어온 칸은 false다.
    let isInDisplayedMonth: Bool
    /// 기준 시간대에서 일요일인지.
    let isSunday: Bool
    /// 기준 시간대에서 토요일인지.
    let isSaturday: Bool

    var id: Date { date }
}

/// 한 달의 실제 기하 구조.
///
/// Pencil이 그린 5주 배치를 그대로 베끼지 않는다. 달마다 필요한 주 수가 다르므로
/// 실제 날짜에서 계산한다. 달력 계산이 기기 설정에 흔들리지 않도록 달력 종류와
/// 시간대를 명시적으로 받는다.
struct CalendarMonth: Equatable {
    /// 표시 중인 달의 첫날.
    let start: Date
    /// 앞뒤 달에서 채운 칸까지 포함한 전체 칸.
    let days: [CalendarDay]
    /// 7칸씩 끊은 주 단위 배열.
    let weeks: [[CalendarDay]]

    /// 앱 전체가 쓰는 기준 달력. 한국 시간 기준으로 날짜 경계를 정한다.
    static func referenceCalendar(
        timeZoneIdentifier: String = "Asia/Seoul",
        firstWeekday: Int = 1
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        // 1 = 일요일. Pencil 요일 행이 일요일부터 시작한다.
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// 주어진 날짜가 속한 달의 기하 구조를 만든다.
    static func make(containing date: Date, calendar: Calendar = referenceCalendar()) -> CalendarMonth {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: date) else {
            return CalendarMonth(start: date, days: [], weeks: [])
        }
        let monthStart = interval.start

        // 앞쪽 채움: 첫날의 요일에서 시작 요일을 뺀 만큼.
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [CalendarDay] = []
        cells.reserveCapacity(42)

        for offset in stride(from: -leading, to: 0, by: 1) {
            if let date = calendar.date(byAdding: .day, value: offset, to: monthStart) {
                cells.append(makeDay(date, inMonth: false, calendar: calendar))
            }
        }
        for index in 0..<dayRange.count {
            if let date = calendar.date(byAdding: .day, value: index, to: monthStart) {
                cells.append(makeDay(date, inMonth: true, calendar: calendar))
            }
        }
        // 뒤쪽 채움: 마지막 주를 7칸으로 맞춘다.
        let trailing = (7 - (cells.count % 7)) % 7
        for index in 0..<trailing {
            if let date = calendar.date(byAdding: .day, value: index, to: interval.end) {
                cells.append(makeDay(date, inMonth: false, calendar: calendar))
            }
        }

        var weeks: [[CalendarDay]] = []
        var cursor = 0
        while cursor < cells.count {
            weeks.append(Array(cells[cursor..<min(cursor + 7, cells.count)]))
            cursor += 7
        }

        return CalendarMonth(start: monthStart, days: cells, weeks: weeks)
    }

    private static func makeDay(_ date: Date, inMonth: Bool, calendar: Calendar) -> CalendarDay {
        let weekday = calendar.component(.weekday, from: date)
        return CalendarDay(
            date: calendar.startOfDay(for: date),
            day: calendar.component(.day, from: date),
            isInDisplayedMonth: inMonth,
            isSunday: weekday == 1,
            isSaturday: weekday == 7
        )
    }

    /// 앞뒤 달로 이동한다. 달 자체만 옮기고 선택 날짜는 건드리지 않는다.
    static func month(byAdding months: Int, to date: Date, calendar: Calendar = referenceCalendar()) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let moved = calendar.date(byAdding: .month, value: months, to: interval.start) else {
            return date
        }
        return moved
    }

    /// 달을 옮길 때 선택 날짜를 어디로 둘지 정한다.
    ///
    /// 31일을 고른 채 30일까지인 달로 넘어가면 그 달의 마지막 날로 당긴다.
    /// 조용히 다른 달로 넘어가 버리는 일이 없도록 명시적으로 잘라낸다.
    static func clampedSelection(
        day: Int,
        in month: Date,
        calendar: Calendar = referenceCalendar()
    ) -> Date? {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return nil
        }
        let clamped = min(max(day, 1), range.count)
        return calendar.date(byAdding: .day, value: clamped - 1, to: interval.start)
    }

    /// 요일 머리글. 기준 달력의 시작 요일을 따르고, 라벨은 로캘에서 가져온다.
    static func weekdaySymbols(
        calendar: Calendar = referenceCalendar(),
        locale: Locale = Locale(identifier: "ko_KR")
    ) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? ["일", "월", "화", "수", "목", "금", "토"]
        let offset = calendar.firstWeekday - 1
        guard offset > 0, offset < symbols.count else { return symbols }
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }
}
