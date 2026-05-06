import SwiftUI

private enum CalendarResultFilter: String, CaseIterable, Identifiable {
    case all
    case win
    case loss
    case draw
    case canceled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체"
        case .win: "승"
        case .loss: "패"
        case .draw: "무"
        case .canceled: "취소"
        }
    }

    var result: GameResult? {
        switch self {
        case .all: nil
        case .win: .win
        case .loss: .loss
        case .draw: .draw
        case .canceled: .canceled
        }
    }

    func matches(_ log: AttendanceLogViewState) -> Bool {
        result.map { log.result == $0 } ?? true
    }
}

private enum CalendarTeamFilter: Hashable {
    case all
    case favorite
    case team(String)

    var title: String {
        switch self {
        case .all: "전체 팀"
        case .favorite: "응원팀"
        case .team(let name): name
        }
    }

    func matches(_ log: AttendanceLogViewState, favoriteTeam: KBOTeam?) -> Bool {
        switch self {
        case .all:
            return true
        case .favorite:
            guard let favoriteTeam else { return true }
            return log.matchup.localizedCaseInsensitiveContains(favoriteTeam.name)
                || log.matchup.localizedCaseInsensitiveContains(favoriteTeam.shortName)
        case .team(let name):
            return log.matchup.localizedCaseInsensitiveContains(name)
        }
    }
}

private enum CalendarPhotoFilter: String, CaseIterable, Identifiable {
    case all
    case withPhoto
    case withoutPhoto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체"
        case .withPhoto: "사진 있음"
        case .withoutPhoto: "사진 없음"
        }
    }

    func matches(_ log: AttendanceLogViewState) -> Bool {
        switch self {
        case .all: true
        case .withPhoto: !log.photoLocalRefs.isEmpty
        case .withoutPhoto: log.photoLocalRefs.isEmpty
        }
    }
}

private enum CalendarRecordFilter: String, CaseIterable, Identifiable {
    case all
    case recorded
    case unrecorded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체 날짜"
        case .recorded: "기록 있는 날짜"
        case .unrecorded: "기록 없는 날짜"
        }
    }
}

struct AttendanceCalendarView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    let logs: [AttendanceLogViewState]
    var dataState: RemoteDataState = .loaded
    var month = Date.vfDate(year: 2026, month: 4, day: 1)
    @State private var selectedDay: CalendarSelectedDay?
    @State private var editorDate: Date?
    @State private var isShowingLogEditor = false
    @State private var resultFilter: CalendarResultFilter = .all
    @State private var teamFilter: CalendarTeamFilter = .all
    @State private var photoFilter: CalendarPhotoFilter = .all
    @State private var recordFilter: CalendarRecordFilter = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "직관 캘린더", subtitle: "날짜별 직관 기록과 결과를 확인해요") {
                    HeaderIconButton(systemImage: "calendar.badge.plus", accessibilityLabel: "직관 기록 추가") {
                        openEditor(date: selectedDay?.date ?? month)
                    }
                }

                DataStateBanner(state: dataState)

                VFCard(background: VFColor.backgroundWarm) {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        HStack(spacing: VFSpacing.sm) {
                            monthButton(systemImage: "chevron.left", accessibilityLabel: "이전 달") {
                                selectedDay = nil
                                Task { await appData.moveCalendarMonth(by: -1) }
                            }
                            Text(monthTitle)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(VFColor.primaryText)
                                .frame(maxWidth: .infinity)
                            monthButton(systemImage: "chevron.right", accessibilityLabel: "다음 달") {
                                selectedDay = nil
                                Task { await appData.moveCalendarMonth(by: 1) }
                            }
                        }

                        HStack {
                            Text(summaryTitle)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(VFColor.primaryText)
                            Spacer()
                        }

                        FlowLayout(spacing: VFSpacing.xs) {
                            summaryChip("승 \(count(.win))", color: VFColor.winGreen)
                            summaryChip("패 \(count(.loss))", color: VFColor.lossRed)
                            summaryChip("무 \(count(.draw))", color: VFColor.drawGray)
                            summaryChip("취소 \(count(.canceled))", color: VFColor.canceledGray)
                        }
                    }
                }

                calendarFilters

                CalendarMonthView(month: month, logs: displayedCalendarLogs, selectedDate: selectedDay?.date) { date in
                    selectedDay = CalendarSelectedDay(date: date, logs: logs(on: date))
                }

                legend

                if shouldShowFilteredEmptyState {
                    EmptyStateView(
                        title: emptyStateTitle,
                        message: emptyStateMessage,
                        buttonTitle: "이 날짜에 기록 추가",
                        systemImage: "calendar.badge.plus"
                    ) {
                        openEditor(date: selectedDay?.date ?? month)
                    }
                } else if let log = selectedDay?.logs.first ?? matchingLogs.first {
                    selectedPreview(log)
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
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
        guard recordFilter != .unrecorded else { return [] }
        return matchingLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func count(_ result: GameResult) -> Int {
        matchingLogs.filter { $0.result == result }.count
    }

    private var matchingLogs: [AttendanceLogViewState] {
        logs.filter { log in
            resultFilter.matches(log)
                && teamFilter.matches(log, favoriteTeam: favoriteTeam)
                && photoFilter.matches(log)
        }
    }

    private var displayedCalendarLogs: [AttendanceLogViewState] {
        recordFilter == .unrecorded ? [] : matchingLogs
    }

    private var favoriteTeam: KBOTeam? {
        appData.team(id: preferences.favoriteTeamID)
    }

    private var summaryTitle: String {
        if recordFilter == .unrecorded {
            return "기록 없는 날짜 보기"
        }
        return activeFilterCount == 0 ? "이번 달 \(matchingLogs.count)경기" : "조건에 맞는 \(matchingLogs.count)경기"
    }

    private var activeFilterCount: Int {
        [resultFilter != .all, teamFilter != .all, photoFilter != .all, recordFilter != .all].filter { $0 }.count
    }

    private var shouldShowFilteredEmptyState: Bool {
        recordFilter == .unrecorded ? false : matchingLogs.isEmpty
    }

    private var emptyStateTitle: String {
        activeFilterCount == 0 ? "아직 이번 달 직관 기록이 없어요." : "조건에 맞는 직관 기록이 없어요."
    }

    private var emptyStateMessage: String {
        activeFilterCount == 0 ? "캘린더에서 날짜를 눌러 새 직관을 남길 수 있어요." : "필터를 초기화하거나 다른 조건을 선택해 보세요."
    }

    private var calendarFilters: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack {
                    Text("필터")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Spacer()
                    Button("초기화") {
                        resetFilters()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VFColor.victoryOrange)
                    .disabled(activeFilterCount == 0)
                    .opacity(activeFilterCount == 0 ? 0.45 : 1)
                }

                filterRow {
                    ForEach(CalendarResultFilter.allCases) { filter in
                        filterChip(title: filter.title, isSelected: resultFilter == filter, tint: filter.result?.color ?? theme.primary) {
                            resultFilter = filter
                            refreshSelectedDay()
                        }
                    }
                }

                filterRow {
                    ForEach(teamFilterOptions, id: \.self) { filter in
                        filterChip(title: filter.title, isSelected: teamFilter == filter, tint: theme.secondary) {
                            teamFilter = filter
                            refreshSelectedDay()
                        }
                    }
                }

                filterRow {
                    ForEach(CalendarPhotoFilter.allCases) { filter in
                        filterChip(title: filter.title, isSelected: photoFilter == filter, tint: VFColor.scoreboardNavy) {
                            photoFilter = filter
                            refreshSelectedDay()
                        }
                    }
                }

                filterRow {
                    ForEach(CalendarRecordFilter.allCases) { filter in
                        filterChip(title: filter.title, isSelected: recordFilter == filter, tint: VFColor.victoryOrange) {
                            recordFilter = filter
                            refreshSelectedDay()
                        }
                    }
                }
            }
        }
    }

    private func filterRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VFSpacing.xs) {
                content()
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VFChip(title: title, isSelected: isSelected, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(title), 선택됨" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var teamFilterOptions: [CalendarTeamFilter] {
        var filters: [CalendarTeamFilter] = [.all]
        if favoriteTeam != nil {
            filters.append(.favorite)
        }
        for filter in detectedTeams.map({ CalendarTeamFilter.team($0.shortName) }) where !filters.contains(filter) {
            filters.append(filter)
        }
        return filters
    }

    private var detectedTeams: [KBOTeam] {
        KBOSeed.teams.filter { team in
            logs.contains { log in
                log.matchup.localizedCaseInsensitiveContains(team.name)
                    || log.matchup.localizedCaseInsensitiveContains(team.shortName)
            }
        }
    }

    private func resetFilters() {
        resultFilter = .all
        teamFilter = .all
        photoFilter = .all
        recordFilter = .all
        refreshSelectedDay()
    }

    private func refreshSelectedDay() {
        guard let selectedDay else { return }
        self.selectedDay = CalendarSelectedDay(date: selectedDay.date, logs: logs(on: selectedDay.date))
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
        .padding(.vertical, VFSpacing.xs)
    }

    private func selectedPreview(_ log: AttendanceLogViewState) -> some View {
        VFCard {
            HStack(spacing: VFSpacing.md) {
                RoundedRectangle(cornerRadius: VFRadius.pill)
                    .fill(log.result.color)
                    .frame(width: 5)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text(log.dateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VFColor.tertiaryText)
                    Text(log.matchup)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    HStack(spacing: VFSpacing.xs) {
                        Text(log.stadium)
                        if !log.photoLocalRefs.isEmpty {
                            Label("사진 있음", systemImage: "photo.fill")
                                .accessibilityLabel("사진 있음")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
                    Text(log.memo)
                        .font(.caption)
                        .foregroundStyle(VFColor.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                ResultBadge(result: log.result, scoreText: log.result == .canceled ? nil : log.scoreText)
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
                            logs: logs(on: day.date),
                            isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false,
                            isToday: Calendar.current.isDateInToday(day.date)
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

    private func logs(on date: Date) -> [AttendanceLogViewState] {
        logs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

struct CalendarDay: Hashable {
    let date: Date
    let isInDisplayedMonth: Bool
}

struct CalendarDayCell: View {
    let day: CalendarDay
    let logs: [AttendanceLogViewState]
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: VFSpacing.xxs) {
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(.system(.subheadline, design: .rounded).weight(day.isInDisplayedMonth ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : (day.isInDisplayedMonth ? VFColor.primaryText : VFColor.secondaryText.opacity(0.45)))

                    if logs.isEmpty {
                        Circle()
                            .fill(.clear)
                            .frame(width: 7, height: 7)
                    } else {
                        HStack(spacing: 2) {
                            ForEach(Array(logs.prefix(3))) { log in
                                CalendarResultDot(result: log.result, size: logs.count > 1 ? 6 : 8)
                                    .accessibilityHidden(true)
                            }
                        }
                        if let teamShortName {
                            Text(teamShortName)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(isSelected ? .white.opacity(0.9) : VFColor.secondaryText)
                                .frame(maxWidth: 28)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)

                if logs.count > 1 {
                    Text("\(logs.count)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 17, height: 17)
                        .background(VFColor.scoreboardNavy)
                        .clipShape(Circle())
                        .accessibilityLabel("\(logs.count)개 기록")
                } else if hasPhoto {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? VFColor.victoryOrange : VFColor.scoreboardNavy)
                        .frame(width: 17, height: 17)
                        .background(.white.opacity(0.92))
                        .clipShape(Circle())
                        .accessibilityLabel("사진 있음")
                }
            }
            .background(isSelected ? VFColor.scoreboardNavy : (logs.first.map { $0.result.color.opacity(0.08) } ?? Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                    .stroke(isSelected ? VFColor.victoryOrange : (isToday ? VFColor.victoryOrange.opacity(0.55) : Color.clear), lineWidth: isSelected || isToday ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var hasPhoto: Bool {
        logs.contains { !$0.photoLocalRefs.isEmpty }
    }

    private var teamShortName: String? {
        guard let matchup = logs.first?.matchup else { return nil }
        return KBOSeed.teams.first {
            matchup.localizedCaseInsensitiveContains($0.name) || matchup.localizedCaseInsensitiveContains($0.shortName)
        }?.shortName
    }

    private var accessibilityLabel: String {
        let dayText = "날짜 \(Calendar.current.component(.day, from: day.date))"
        var parts = [dayText]
        if isSelected {
            parts.append("선택됨")
        }
        if logs.count > 1 {
            parts.append("\(logs.count)개 기록")
        }
        if let first = logs.first {
            parts.append(first.result.title)
            parts.append(first.matchup)
        }
        if hasPhoto {
            parts.append("사진 있음")
        }
        return parts.joined(separator: ", ")
    }
}

struct CalendarResultDot: View {
    let result: GameResult
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(result.color)
            .frame(width: size, height: size)
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
                                HStack(spacing: VFSpacing.xs) {
                                    Text(log.scoreText)
                                    Text("·")
                                    Text(log.dateText)
                                    if !log.seat.isEmpty {
                                        Text("·")
                                        Text(log.seat)
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VFColor.secondaryText)
                                if !log.photoLocalRefs.isEmpty {
                                    PhotoAttachmentStrip(photoLocalRefs: log.photoLocalRefs, maxHeight: 86)
                                        .accessibilityLabel("사진 있음")
                                }
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
