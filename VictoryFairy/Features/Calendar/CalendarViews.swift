import SwiftUI

struct AttendanceCalendarView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    let logs: [AttendanceLogViewState]
    var dataState: RemoteDataState = .loaded
    var month = Date.vfDate(year: 2026, month: 4, day: 1)
    @State private var selectedDay: CalendarSelectedDay?
    @State private var editorDate: Date?
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "직관 캘린더") {
                    HeaderIconButton(systemImage: "calendar.badge.plus", accessibilityLabel: "직관 기록 추가") {
                        openEditor(date: selectedDay?.date ?? month)
                    }
                }

                DataStateBanner(state: dataState)

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        HStack(spacing: VFSpacing.sm) {
                            monthButton(systemImage: "chevron.left", accessibilityLabel: "이전 달") {
                                selectedDay = nil
                                Task { await appData.moveCalendarMonth(by: -1) }
                            }
                            Text(monthTitle)
                                .font(VFTypography.section)
                                .foregroundStyle(VFColor.primaryText)
                                .frame(maxWidth: .infinity)
                            monthButton(systemImage: "chevron.right", accessibilityLabel: "다음 달") {
                                selectedDay = nil
                                Task { await appData.moveCalendarMonth(by: 1) }
                            }
                        }

                        Text("이번 달 \(logs.count)경기")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(theme.primary)

                        FlowLayout(spacing: VFSpacing.sm) {
                            summaryChip("승 \(count(.win))", color: VFColor.winGreen)
                            summaryChip("패 \(count(.loss))", color: VFColor.lossRed)
                            summaryChip("무 \(count(.draw))", color: VFColor.drawGray)
                            summaryChip("취소 \(count(.canceled))", color: VFColor.canceledGray)
                        }
                    }
                }

                CalendarMonthView(month: month, logs: logs, selectedDate: selectedDay?.date) { date in
                    selectedDay = CalendarSelectedDay(date: date, logs: logs(on: date))
                }

                legend

                if logs.isEmpty {
                    EmptyStateView(
                        title: "아직 이번 달 직관 기록이 없어요.",
                        message: "캘린더에서 날짜를 눌러 새 직관을 남길 수 있어요.",
                        buttonTitle: "이 날짜에 기록 추가",
                        systemImage: "calendar.badge.plus"
                    ) {
                        openEditor(date: selectedDay?.date ?? month)
                    }
                } else if let log = selectedDay?.logs.first ?? logs.first {
                    selectedPreview(log)
                }
            }
            .padding(VFSpacing.lg)
        }
        .sheet(item: $selectedDay) { day in
            CalendarDayDetailSheet(day: day) { date in
                openEditor(date: date)
            }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                LogEditorView(initialDate: editorDate)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .vfScreenBackground()
    }

    private func openEditor(date: Date) {
        selectedDay = nil
        editorDate = date
        DispatchQueue.main.async {
            isShowingLogEditor = true
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: month)
    }

    private func monthButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.primary)
                .frame(width: 44, height: 44)
                .background(theme.primary.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func logs(on date: Date) -> [AttendanceLogViewState] {
        logs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func count(_ result: GameResult) -> Int {
        logs.filter { $0.result == result }.count
    }

    private func summaryChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, VFSpacing.sm)
            .frame(minHeight: 30)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var legend: some View {
        HStack(spacing: VFSpacing.md) {
            ForEach(GameResult.allCases) { result in
                HStack(spacing: VFSpacing.xs) {
                    CalendarResultDot(result: result)
                    Text(result.title)
                        .font(.caption)
                        .foregroundStyle(VFColor.secondaryText)
                }
            }
        }
        .padding(.horizontal, VFSpacing.xs)
    }

    private func selectedPreview(_ log: AttendanceLogViewState) -> some View {
        VFCard {
            HStack(spacing: VFSpacing.md) {
                RoundedRectangle(cornerRadius: VFRadius.pill)
                    .fill(theme.primary)
                    .frame(width: 5)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text(log.matchup)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Text(log.resultScoreText)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(log.result.color)
                    Text(log.stadium)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.up")
                    .foregroundStyle(VFColor.secondaryText)
            }
        }
    }
}

struct CalendarMonthView: View {
    let month: Date
    let logs: [AttendanceLogViewState]
    var selectedDate: Date?
    let onDateTap: (Date) -> Void

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: VFSpacing.xs), count: 7)

    var body: some View {
        VFCard {
            VStack(spacing: VFSpacing.sm) {
                LazyVGrid(columns: columns, spacing: VFSpacing.xs) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(VFColor.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }

                    ForEach(days, id: \.date) { day in
                        CalendarDayCell(
                            day: day,
                            result: log(on: day.date)?.result,
                            isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false
                        ) {
                            onDateTap(day.date)
                        }
                    }
                }
            }
        }
    }

    private var days: [CalendarDay] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingCount = firstWeekday - 1
        let previousDates = (0..<leadingCount).compactMap {
            calendar.date(byAdding: .day, value: $0 - leadingCount, to: monthInterval.start)
        }
        let monthDates = monthRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        let trailingCount = (7 - ((previousDates.count + monthDates.count) % 7)) % 7
        let trailingDates = (0..<trailingCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monthInterval.end)
        }

        return (previousDates.map { CalendarDay(date: $0, isInDisplayedMonth: false) }
            + monthDates.map { CalendarDay(date: $0, isInDisplayedMonth: true) }
            + trailingDates.map { CalendarDay(date: $0, isInDisplayedMonth: false) })
    }

    private func log(on date: Date) -> AttendanceLogViewState? {
        logs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

struct CalendarDay: Hashable {
    let date: Date
    let isInDisplayedMonth: Bool
}

struct CalendarDayCell: View {
    @Environment(\.appTheme) private var theme
    let day: CalendarDay
    let result: GameResult?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VFSpacing.xxs) {
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(.subheadline, design: .rounded).weight(day.isInDisplayedMonth ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.textOnPrimary : (day.isInDisplayedMonth ? VFColor.primaryText : VFColor.secondaryText.opacity(0.45)))
                if let result {
                    CalendarResultDot(result: result)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? theme.primary : (result.map { $0.color.opacity(0.08) } ?? Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                    .stroke(isSelected ? theme.primary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "날짜 \(Calendar.current.component(.day, from: day.date)), 선택됨" : "날짜 \(Calendar.current.component(.day, from: day.date))")
    }
}

struct CalendarResultDot: View {
    let result: GameResult

    var body: some View {
        Circle()
            .fill(result.color)
            .frame(width: 8, height: 8)
            .accessibilityLabel(result.title)
    }
}

struct CalendarSelectedDay: Identifiable {
    let id = UUID()
    let date: Date
    let logs: [AttendanceLogViewState]

    var title: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: date)) 직관 기록"
    }
}

struct CalendarDayDetailSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let day: CalendarSelectedDay
    var onAddLog: (Date) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text(day.title)
                    .font(VFTypography.section)
                    .foregroundStyle(VFColor.primaryText)

                if day.logs.isEmpty {
                    Text("선택한 날짜에 기록이 없어요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                } else {
                    ForEach(day.logs) { log in
                        VFCard {
                            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                                HStack {
                                    Text(log.matchup)
                                        .font(VFTypography.cardTitle)
                                    Spacer()
                                    ResultBadge(result: log.result, scoreText: log.result == .canceled ? nil : log.scoreText)
                                }
                                Text(log.stadium)
                                    .font(.subheadline)
                                    .foregroundStyle(VFColor.secondaryText)
                                Text(log.memo)
                                    .font(VFTypography.body)
                                    .foregroundStyle(VFColor.primaryText)
                            }
                        }

                        NavigationLink {
                            AttendancePostDetailView(log: log)
                        } label: {
                            Label("자세히 보기", systemImage: "arrow.right")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(theme.textOnPrimary)
                                .background(theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    dismiss()
                    onAddLog(day.date)
                } label: {
                    Label("이 날짜에 기록 추가", systemImage: "calendar.badge.plus")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(VFColor.primaryText)
                        .background(VFColor.offWhite)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(VFSpacing.lg)
            .vfScreenBackground()
        }
    }
}

#Preview("캘린더 데이터") {
    NavigationStack {
        AttendanceCalendarView(logs: AttendanceLogSample.logs)
    }
}

#Preview("캘린더 빈 상태") {
    NavigationStack {
        AttendanceCalendarView(logs: [])
    }
}
