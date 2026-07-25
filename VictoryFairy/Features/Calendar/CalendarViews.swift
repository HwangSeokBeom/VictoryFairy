import SwiftUI
import UIKit

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
        case .all: "전체"
        case .recorded: "기록 있음"
        case .unrecorded: "기록 없음"
        }
    }
}

private enum CalendarViewMode: String, CaseIterable, Identifiable {
    case basic = "basic"
    case teamResult = "detail"
    case photo = "record"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: "기본"
        case .teamResult: "팀결과"
        case .photo: "사진"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .basic: "기본 보기"
        case .teamResult: "팀결과 보기"
        case .photo: "사진 보기"
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
    @AppStorage("calendarViewMode") private var calendarViewModeRaw = CalendarViewMode.basic.rawValue
    @State private var selectedDay: CalendarSelectedDay?
    @State private var editorDate: Date?
    @State private var isShowingLogEditor = false
    @State private var isShowingFilters = false
    @State private var isShowingMonthPicker = false
    @State private var resultFilter: CalendarResultFilter = .all
    @State private var teamFilter: CalendarTeamFilter = .all
    @State private var photoFilter: CalendarPhotoFilter = .all
    @State private var recordFilter: CalendarRecordFilter = .all
    @State private var draftResultFilter: CalendarResultFilter = .all
    @State private var draftTeamFilter: CalendarTeamFilter = .all
    @State private var draftPhotoFilter: CalendarPhotoFilter = .all
    @State private var draftRecordFilter: CalendarRecordFilter = .all
    @State private var pickerYear = 2026
    @State private var pickerMonth = 4

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
                            Button {
                                openMonthPicker()
                            } label: {
                                HStack(spacing: VFSpacing.xs) {
                                    Text(monthTitle)
                                        .font(.system(size: 21, weight: .bold, design: .rounded))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(VFColor.primaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(monthTitle), 월 선택")
                            .accessibilityHint("연도와 월을 직접 선택합니다")
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

                viewModeToolbar

                activeFilterSummary

                CalendarMonthView(month: month, logs: displayedCalendarLogs, viewMode: viewMode, selectedDate: selectedDay?.date) { date in
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingFilters) {
            CalendarFilterSheet(
                resultFilter: $draftResultFilter,
                teamFilter: $draftTeamFilter,
                photoFilter: $draftPhotoFilter,
                recordFilter: $draftRecordFilter,
                teamOptions: teamFilterOptions,
                favoriteTint: theme.primary,
                onApply: applyDraftFilters,
                onReset: resetDraftFilters
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingMonthPicker) {
            CalendarMonthPickerSheet(
                years: monthPickerYears,
                selectedYear: $pickerYear,
                selectedMonth: $pickerMonth,
                onToday: applyTodayMonth,
                onApply: applyPickedMonth
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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

    private var viewMode: CalendarViewMode {
        CalendarViewMode(rawValue: calendarViewModeRaw) ?? .basic
    }

    private var monthPickerYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let fallbackYears = Array((currentYear - 5)...(currentYear + 1))
        let seasonYears = appData.availableSeasons.map(\.season)
        return Array(Set(fallbackYears + seasonYears + [2026])).sorted()
    }

    private func setViewMode(_ mode: CalendarViewMode) {
        withAnimation(.snappy(duration: 0.2)) {
            calendarViewModeRaw = mode.rawValue
        }
        refreshSelectedDay()
    }

    private func openMonthPicker() {
        pickerYear = Calendar.current.component(.year, from: month)
        pickerMonth = Calendar.current.component(.month, from: month)
        isShowingMonthPicker = true
    }

    private func applyPickedMonth() {
        selectedDay = nil
        isShowingMonthPicker = false
        Task {
            await appData.selectCalendarMonth(year: pickerYear, month: pickerMonth)
        }
    }

    private func applyTodayMonth() {
        let today = Date()
        pickerYear = Calendar.current.component(.year, from: today)
        pickerMonth = Calendar.current.component(.month, from: today)
        applyPickedMonth()
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

    private var viewModeToolbar: some View {
        HStack(spacing: VFSpacing.sm) {
            HStack(spacing: VFSpacing.xs) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Button {
                        setViewMode(mode)
                    } label: {
                        Text(mode.title)
                            .font(.system(.subheadline, design: .rounded).weight(viewMode == mode ? .bold : .semibold))
                            .foregroundStyle(viewMode == mode ? VFColor.victoryOrange : VFColor.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .contentShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .background {
                        if viewMode == mode {
                            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                                .fill(VFColor.victoryOrange.opacity(0.12))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                            .stroke(viewMode == mode ? VFColor.victoryOrange.opacity(0.3) : Color.clear, lineWidth: 1)
                    }
                    .accessibilityLabel(viewMode == mode ? "\(mode.accessibilityTitle), 선택됨" : mode.accessibilityTitle)
                    .accessibilityAddTraits(viewMode == mode ? .isSelected : [])
                }
            }
            .padding(VFSpacing.xs)
            .background(VFColor.cardTranslucent)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 0.8)
            )

            Button {
                openFilterSheet()
            } label: {
                Label("필터", systemImage: activeFilterCount == 0 ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(activeFilterCount == 0 ? VFColor.primaryText : VFColor.victoryOrange)
                    .frame(width: 76, height: 46)
                    .background(VFColor.cardTranslucent)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(activeFilterCount == 0 ? .white.opacity(0.9) : VFColor.victoryOrange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeFilterCount == 0 ? "필터" : "필터, \(activeFilterCount)개 적용됨")
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var activeFilterSummary: some View {
        if !activeFilterLabels.isEmpty {
            FlowLayout(spacing: VFSpacing.xs) {
                ForEach(activeFilterLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.victoryOrange)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 28)
                        .background(VFColor.victoryOrange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, VFSpacing.xs)
        }
    }

    private var activeFilterLabels: [String] {
        var labels: [String] = []
        if resultFilter != .all {
            labels.append(resultFilter.title)
        }
        if teamFilter != .all {
            labels.append(teamFilter.title)
        }
        if photoFilter != .all {
            labels.append(photoFilter.title)
        }
        if recordFilter != .all {
            labels.append(recordFilter.title)
        }
        return labels
    }

    private func openFilterSheet() {
        draftResultFilter = resultFilter
        draftTeamFilter = teamFilter
        draftPhotoFilter = photoFilter
        draftRecordFilter = recordFilter
        isShowingFilters = true
    }

    private func applyDraftFilters() {
        resultFilter = draftResultFilter
        teamFilter = draftTeamFilter
        photoFilter = draftPhotoFilter
        recordFilter = draftRecordFilter
        isShowingFilters = false
        refreshSelectedDay()
    }

    private func resetDraftFilters() {
        draftResultFilter = .all
        draftTeamFilter = .all
        draftPhotoFilter = .all
        draftRecordFilter = .all
        resetFilters()
        isShowingFilters = false
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

private struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var resultFilter: CalendarResultFilter
    @Binding var teamFilter: CalendarTeamFilter
    @Binding var photoFilter: CalendarPhotoFilter
    @Binding var recordFilter: CalendarRecordFilter
    let teamOptions: [CalendarTeamFilter]
    let favoriteTint: Color
    let onApply: () -> Void
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    filterSection("결과") {
                        ForEach(CalendarResultFilter.allCases) { filter in
                            filterChip(title: filter.title, isSelected: resultFilter == filter, tint: filter.result?.color ?? favoriteTint) {
                                resultFilter = filter
                            }
                        }
                    }

                    filterSection("팀") {
                        ForEach(teamOptions, id: \.self) { filter in
                            filterChip(title: filter.title, isSelected: teamFilter == filter, tint: favoriteTint) {
                                teamFilter = filter
                            }
                        }
                    }

                    filterSection("사진") {
                        ForEach(CalendarPhotoFilter.allCases) { filter in
                            filterChip(title: filter.title, isSelected: photoFilter == filter, tint: VFColor.scoreboardNavy) {
                                photoFilter = filter
                            }
                        }
                    }

                    filterSection("기록 여부") {
                        ForEach(CalendarRecordFilter.allCases) { filter in
                            filterChip(title: filter.title, isSelected: recordFilter == filter, tint: VFColor.victoryOrange) {
                                recordFilter = filter
                            }
                        }
                    }
                }
                .padding(VFSpacing.lg)
                .padding(.top, VFSpacing.sm)
                .padding(.bottom, VFTabBarMetrics.extraBreathingRoom)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: VFSpacing.sm) {
                    VFSecondaryButton(title: "초기화", systemImage: "arrow.counterclockwise") {
                        onReset()
                    }
                    VFPrimaryButton(title: "적용", systemImage: "checkmark") {
                        onApply()
                    }
                }
                .padding(.horizontal, VFSpacing.lg)
                .padding(.top, VFSpacing.sm)
                .padding(.bottom, VFSpacing.sm)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("캘린더 필터")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            Text(title)
                .font(VFTypography.cardTitle)
                .foregroundStyle(VFColor.primaryText)
            FlowLayout(spacing: VFSpacing.xs) {
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
}

private struct CalendarMonthPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let years: [Int]
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    let onToday: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: VFSpacing.lg) {
                HStack(spacing: VFSpacing.md) {
                    Picker("연도", selection: $selectedYear) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)년").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("월", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)월").tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 190)

                HStack(spacing: VFSpacing.sm) {
                    VFSecondaryButton(title: "오늘", systemImage: "calendar") {
                        onToday()
                    }
                    VFPrimaryButton(title: "적용", systemImage: "checkmark") {
                        onApply()
                    }
                }
                .padding(.bottom, VFSpacing.sm)
            }
            .padding(VFSpacing.lg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("월 선택")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }
}

private struct CalendarMonthView: View {
    let month: Date
    let logs: [AttendanceLogViewState]
    var viewMode: CalendarViewMode = .basic
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
                            viewMode: viewMode,
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

private struct CalendarDay: Hashable {
    let date: Date
    let isInDisplayedMonth: Bool
}

private struct CalendarDayCell: View {
    let day: CalendarDay
    let logs: [AttendanceLogViewState]
    var viewMode: CalendarViewMode = .basic
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void
    private let photoService = PhotoAttachmentService()

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        switch viewMode {
        case .basic:
            baseContainer {
                VStack(spacing: VFSpacing.xxs) {
                    dayNumber()
                    if logs.isEmpty {
                        Color.clear.frame(width: 7, height: 7)
                    } else {
                        resultDots
                        if logs.count > 1 {
                            Text("\(logs.count)개")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundStyle(isSelected ? .white.opacity(0.88) : VFColor.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
        case .teamResult:
            baseContainer {
                VStack(spacing: 2) {
                    dayNumber()
                    if let first = logs.first {
                        Text(teamShortName ?? matchupShortLabel)
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : VFColor.secondaryText)
                            .frame(maxWidth: 38)
                        Text(teamResultText(for: first))
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                            .foregroundStyle(isSelected ? .white : first.result.color)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 14)
                            .background(isSelected ? .white.opacity(0.14) : first.result.color.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Color.clear.frame(height: 24)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .overlay(alignment: .topTrailing) {
                    if logs.count > 1 {
                        countBadge
                    }
                }
            }
        case .photo:
            photoContent
        }
    }

    private func baseContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(isSelected ? VFColor.scoreboardNavy : (logs.first.map { $0.result.color.opacity(0.08) } ?? Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                    .stroke(isSelected ? VFColor.victoryOrange : (isToday ? VFColor.victoryOrange.opacity(0.55) : Color.clear), lineWidth: isSelected || isToday ? 1.4 : 1)
            )
            .opacity(dayOpacity)
    }

    @ViewBuilder
    private var photoContent: some View {
        if let thumbnailRef {
            ZStack(alignment: .topTrailing) {
                AttachmentPhotoView(ref: thumbnailRef, target: .calendarCell)
                    .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
                    .clipped()
                LinearGradient(colors: [.black.opacity(0.58), .clear, .black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading) {
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    Spacer()
                    resultDots
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(5)
                if logs.count > 1 {
                    countBadge
                        .padding(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                    .stroke(isSelected ? VFColor.victoryOrange : (isToday ? VFColor.victoryOrange.opacity(0.55) : Color.clear), lineWidth: isSelected || isToday ? 1.4 : 1)
            )
            .opacity(dayOpacity)
        } else {
            baseContainer {
                VStack(spacing: 2) {
                    dayNumber()
                    if logs.isEmpty {
                        Color.clear.frame(height: 24)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : VFColor.scoreboardNavy.opacity(0.74))
                            .frame(width: 20, height: 18)
                        resultDots
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .overlay(alignment: .topTrailing) {
                    if logs.count > 1 {
                        countBadge
                    }
                }
            }
        }
    }

    private func dayNumber() -> some View {
        Text("\(Calendar.current.component(.day, from: day.date))")
            .font(.system(.subheadline, design: .rounded).weight(day.isInDisplayedMonth ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : (day.isInDisplayedMonth ? VFColor.primaryText : VFColor.secondaryText.opacity(0.45)))
    }

    private var resultDots: some View {
        HStack(spacing: 2) {
            ForEach(Array(logs.prefix(3))) { log in
                CalendarResultDot(result: log.result, size: logs.count > 1 ? 5.5 : 7.5)
                    .accessibilityHidden(true)
            }
        }
    }

    private var countBadge: some View {
        Text("\(logs.count)")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 17, height: 17)
            .background(VFColor.scoreboardNavy)
            .clipShape(Circle())
            .accessibilityLabel("\(logs.count)개 기록")
    }

    private var dayOpacity: Double {
        guard viewMode == .photo, logs.isEmpty, !isSelected, !isToday else { return 1 }
        return day.isInDisplayedMonth ? 0.42 : 0.28
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

    private var matchupShortLabel: String {
        logs.first?.matchup
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: "vs")
            .first?
            .prefix(3)
            .description ?? "팀"
    }

    private var thumbnailRef: String? {
        logs.lazy.flatMap(\.photoLocalRefs).first
    }

    private func teamResultText(for log: AttendanceLogViewState) -> String {
        guard log.result != .canceled else { return "취소" }
        if let ourScore = log.ourScore, let opponentScore = log.opponentScore {
            return "\(ourScore):\(opponentScore) \(log.result.title)"
        }
        return log.result.title
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

private struct CalendarResultDot: View {
    let result: GameResult
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(result.color)
            .frame(width: size, height: size)
            .accessibilityLabel(result.title)
    }
}

private struct CalendarSelectedDay: Identifiable {
    // 안정 ID: 날짜. 필터 변경 후 같은 날짜를 다시 세팅하면(refreshSelectedDay)
    // 시트가 다시 뜨지 않고 그 자리에서 로그만 갱신된다.
    var id: Date { date }
    let date: Date
    let logs: [AttendanceLogViewState]

    var title: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: date)) 직관 기록"
    }
}

private struct CalendarDayDetailSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let day: CalendarSelectedDay
    var onAddLog: (Date) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    Text(day.title)
                        .font(VFTypography.section)
                        .foregroundStyle(VFColor.primaryText)
                        .padding(.top, VFSpacing.sm)

                    if day.logs.isEmpty {
                        Text("선택한 날짜에 기록이 없어요.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.secondaryText)
                    } else {
                        ForEach(day.logs) { log in
                            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                                VFCard {
                                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                                        HStack(alignment: .top, spacing: VFSpacing.sm) {
                                            Text(log.matchup)
                                                .font(VFTypography.cardTitle)
                                                .foregroundStyle(VFColor.primaryText)
                                                .fixedSize(horizontal: false, vertical: true)
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
                                            .fixedSize(horizontal: false, vertical: true)
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
                    }
                }
                .padding(.horizontal, VFSpacing.lg)
                .padding(.top, VFSpacing.md)
                .padding(.bottom, 96)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    onAddLog(day.date)
                } label: {
                    Label("이 날짜에 기록 추가", systemImage: "calendar.badge.plus")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(VFColor.primaryText)
                        .background(VFColor.offWhite)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, VFSpacing.lg)
                .padding(.top, VFSpacing.sm)
                .padding(.bottom, VFSpacing.sm)
                .background(.ultraThinMaterial)
            }
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
