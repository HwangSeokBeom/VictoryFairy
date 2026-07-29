import SwiftUI

/// 피드를 월 단위로 끊어 보여주기 위한 구간.
struct FeedMonthSection: Identifiable, Equatable {
    /// "2026-04" 형태의 안정 키. 정렬도 이 값으로 한다.
    let id: String
    /// Pencil 월 구분 헤더의 한글 라벨. 예: "4월".
    let title: String
    /// 같은 헤더의 영문 라벨. 예: "APRIL".
    let romanTitle: String
    let logs: [AttendanceLogViewState]
}

struct FeedViewModel {
    let logs: [AttendanceLogViewState]
    var selectedResultFilter: FeedResultFilter = .all
    var dataState: RemoteDataState = .loaded

    static let sample = FeedViewModel(logs: AttendanceLogSample.logs)
    static let empty = FeedViewModel(logs: [])

    /// 기록을 월별로 묶는다. 뷰가 아니라 여기서 계산하며 SwiftUI에 의존하지 않는다.
    /// 정렬은 최신 월이 먼저 오고, 월 안에서도 최신 기록이 먼저 온다.
    var monthSections: [FeedMonthSection] {
        Self.monthSections(from: logs)
    }

    /// 기록을 월별로 묶는다.
    ///
    /// 묶는 기준은 미리 만들어둔 표시 문자열이 아니라 `date`라는 의미 있는 값이다.
    /// 최신 월이 먼저 오고, 월 안에서도 최신 기록이 먼저 온다. 날짜가 같으면
    /// 기록 ID로 순서를 고정해 실행할 때마다 결과가 흔들리지 않게 한다.
    static func monthSections(from logs: [AttendanceLogViewState]) -> [FeedMonthSection] {
        let grouped = Dictionary(grouping: logs) { log in
            DateFormatter.vfFeedMonthKey.string(from: log.date)
        }
        return grouped
            .map { key, value in
                let sorted = value.sorted { lhs, rhs in
                    if lhs.date != rhs.date { return lhs.date > rhs.date }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                let reference = sorted.first?.date
                return FeedMonthSection(
                    id: key,
                    title: reference.map { DateFormatter.vfFeedMonthLabel.string(from: $0) } ?? key,
                    romanTitle: reference.map {
                        DateFormatter.vfFeedMonthRoman.string(from: $0).uppercased()
                    } ?? "",
                    logs: sorted
                )
            }
            .sorted { $0.id > $1.id }
    }

    /// Pencil 피드 헤더의 부제. 실제 기록 수만 쓰고 값을 지어내지 않는다.
    /// 시즌 라벨과 전적은 화면이 실제 집계에서 받아 넘긴다.
    func summaryText(seasonLabel: String?, recordText: String?) -> String {
        guard !logs.isEmpty else { return "아직 기록이 없어요" }
        var parts: [String] = []
        if let seasonLabel, !seasonLabel.isEmpty { parts.append(seasonLabel) }
        parts.append("\(logs.count)개의 기록")
        if let recordText, !recordText.isEmpty { parts.append(recordText) }
        return parts.joined(separator: " · ")
    }
}

extension DateFormatter {
    /// 월 그룹 정렬용 키. 앱 전체와 같은 ko_KR / Asia/Seoul 기준이다.
    static let vfFeedMonthKey: DateFormatter = vfFeedMonth(format: "yyyy-MM")
    /// 월 구분 헤더 라벨.
    static let vfFeedMonthLabel: DateFormatter = vfFeedMonth(format: "M월")

    /// Pencil "4월 APRIL"의 영문 부분.
    /// 기기 언어와 무관하게 같은 영문이 나오도록 고정 로캘을 쓴다.
    static let vfFeedMonthRoman: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static func vfFeedMonth(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = format
        return formatter
    }
}

/// Pencil `기록 피드` 프레임.
/// 헤더 -> 필터 행 -> 월 구분 -> 티켓 카드 목록.
struct FeedView: View {
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: FeedViewModel
    @State private var isShowingLogEditor = false
    @State private var isShowingSeasonPicker = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VFSpacing.md) {
                header
                filterRow
                DataStateBanner(state: viewModel.dataState)
                content
            }
            .padding(.horizontal, VFSpacing.screenHorizontalMargin)
            .padding(.top, VFSpacing.xxs)
            .vfTabContentPadding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                LogEditorView()
            }
        }
        .sheet(isPresented: $isShowingSeasonPicker) {
            SeasonPickerSheet(
                seasons: appData.availableSeasons.map {
                    SeasonArchiveOption(season: $0.season, hasRecords: $0.hasRecords)
                },
                selectedSeason: appData.selectedSeason
            ) { season in
                Task {
                    await appData.selectSeason(season)
                }
            }
            .presentationDetents([.medium])
        }
        .vfScreenBackground()
    }

    /// Pencil 피드 본문. 상태에 따라 목록·로딩·빈 상태·오류 중 하나를 보여준다.
    /// 어떤 상태에서도 제목·필터·추가 버튼은 위에 그대로 남는다.
    @ViewBuilder
    private var content: some View {
        switch viewModel.dataState {
        case .loading where viewModel.logs.isEmpty:
            VFLoadingPanel(message: "직관 기록을 불러오는 중이에요")
                .accessibilityIdentifier("feed.loading")
        case .error(let message) where viewModel.logs.isEmpty:
            VFErrorPanel(message: message) {
                Task { await appData.refreshContent() }
            }
            .accessibilityIdentifier("feed.error")
        default:
            if viewModel.logs.isEmpty {
                emptyState
            } else {
                recordSections
            }
        }
    }

    private var recordSections: some View {
        ForEach(viewModel.monthSections) { section in
            Section {
                ForEach(section.logs) { log in
                    NavigationLink {
                        AttendancePostDetailView(log: log)
                    } label: {
                        VFRecordCard(log: log)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feed.record.\(log.id.uuidString)")
                }
            } header: {
                VFMonthDivider(title: section.title, romanTitle: section.romanTitle)
                    .padding(.top, VFSpacing.xxs)
                    .accessibilityIdentifier("feed.month.\(section.id)")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("직관 기록")
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(summaryText)
                    .font(Font.system(.caption, design: .default))
                    .foregroundStyle(VFColor.bodyTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: VFSpacing.xs)
            VFProminentIconButton(systemImage: "plus", accessibilityLabel: "직관 기록 추가") {
                isShowingLogEditor = true
            }
            .accessibilityIdentifier("feed.addRecord")
        }
        .padding(.top, VFSpacing.xs)
        .accessibilityElement(children: .contain)
    }

    /// Pencil "2026 시즌 · 8개의 기록 · 5승 2패 1무".
    /// 전적은 이미 집계된 통계에서 읽고, 화면에서 다시 세지 않는다.
    private var summaryText: String {
        let stats = appData.statistics
        let record = stats.totalGames > 0
            ? "\(stats.wins)승 \(stats.losses)패 \(stats.draws)무"
            : nil
        return viewModel.summaryText(seasonLabel: appData.selectedSeasonLabel, recordText: record)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VFSpacing.xs) {
                ForEach(FeedResultFilter.allCases) { filter in
                    Button {
                        Task {
                            await appData.selectFeedResultFilter(filter)
                        }
                    } label: {
                        VFChip(
                            title: filter.title,
                            isSelected: viewModel.selectedResultFilter == filter
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.selectedResultFilter == filter ? [.isButton, .isSelected] : .isButton)
                }

                // Pencil 시즌 칩: 종이색 바탕에 아래 화살표.
                Button {
                    isShowingSeasonPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(appData.selectedSeasonLabel)
                            .font(Font.system(.footnote, design: .default).weight(.medium))
                            .foregroundStyle(VFColor.bodySecondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VFColor.bodyTertiary)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .frame(minHeight: 32)
                    .background(VFColor.elevatedSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(VFColor.hairline, lineWidth: VFStroke.hairline))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("시즌 선택, \(appData.selectedSeasonLabel)")
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        VFEmptyStatePanel(
            title: viewModel.selectedResultFilter == .all ? "아직 직관 기록이 없어요" : "찾는 기록이 없어요",
            message: viewModel.selectedResultFilter == .all
                ? "첫 직관의 기억부터 차곡차곡 모아드릴게요.\n사진 한 장이면 충분해요."
                : "다른 결과를 선택하거나 새 직관 기록을 남겨보세요.",
            illustration: viewModel.selectedResultFilter == .all ? .glove : .baseball,
            actionTitle: "첫 기록 남기기"
        ) {
            isShowingLogEditor = true
        }
        .accessibilityIdentifier(
            viewModel.selectedResultFilter == .all ? "feed.empty" : "feed.filteredEmpty"
        )
    }
}

struct AttendancePostCard: View {
    @Environment(\.appTheme) private var theme
    let log: AttendanceLogViewState
    var showsActions = true

    var body: some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack(alignment: .center, spacing: VFSpacing.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.dateText)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(VFColor.bodyTertiary)
                        Text(log.matchup)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(VFColor.bodyPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    Spacer()
                    ResultBadge(result: log.result, scoreText: log.result == .canceled ? nil : log.scoreText)
                }

                scoreboardHeader

                if !log.photoLocalRefs.isEmpty {
                    PhotoAttachmentStrip(photoLocalRefs: log.photoLocalRefs, maxHeight: 150)
                }

                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text(log.caption.isEmpty ? log.memo : log.caption)
                        .font(VFTypography.body)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let sourceLabel = log.subtleSourceLabel {
                        Text(sourceLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VFColor.bodySecondary)
                            .padding(.horizontal, VFSpacing.sm)
                            .frame(minHeight: 26)
                            .background(VFColor.subtleSurface)
                            .clipShape(Capsule())
                    }
                }

                tagRow

                if showsActions {
                    HStack(spacing: VFSpacing.sm) {
                        NavigationLink {
                            AttendancePostDetailView(log: log)
                        } label: {
                            Label("자세히 보기", systemImage: "chevron.right")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(VFColor.deepAccent)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))

                        NavigationLink {
                            ShareCardPreviewView(log: log)
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .background(VFColor.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(log.accessibilitySummary)
    }

    private var scoreboardHeader: some View {
        HStack(spacing: VFSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCORE")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.58))
                Text(log.resultScoreText)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let team = selectedTeam {
                    Text(team.shortName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.primaryAction)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 24)
                        .background(.white.opacity(0.92))
                        .clipShape(Capsule())
                        .accessibilityLabel("응원팀 \(team.shortName)")
                }
                Text(log.stadium)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [VFColor.deepAccent, theme.secondary.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private var selectedTeam: KBOTeam? {
        KBOSeed.team(id: theme.teamID)
    }

    private var tagRow: some View {
        FlowLayout(spacing: VFSpacing.xs) {
            ForEach(log.tags.prefix(3), id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, VFSpacing.sm)
                    .frame(minHeight: 28)
                    .background(theme.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

struct AttendancePostDetailView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    @Environment(\.dismiss) private var dismiss
    let log: AttendanceLogViewState
    @State private var isShowingEditor = false
    @State private var isShowingDeleteConfirmation = false
    @State private var safariRoute: SafariRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                detailHeader

                if !log.photoLocalRefs.isEmpty {
                    PhotoAttachmentStrip(photoLocalRefs: log.photoLocalRefs, maxHeight: 210, target: .detailStrip)
                }

                infoCard
                officialRecordCard
                memoCard
                diaryCard

                FlowLayout(spacing: VFSpacing.xs) {
                    ForEach(log.tags, id: \.self) { tag in
                        VFChip(title: tag, isSelected: true, tint: theme.primary)
                    }
                }

                NavigationLink {
                    ShareCardPreviewView(log: log)
                } label: {
                    Label("카드 저장 및 공유", systemImage: "square.and.arrow.up")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(theme.textOnPrimary)
                        .background(theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)

                VFSecondaryButton(title: "수정하기", systemImage: "square.and.pencil") {
                    isShowingEditor = true
                }

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("삭제하기", systemImage: "trash")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(VFColor.gameLoss)
                        .background(VFColor.gameLoss.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("직관 상세")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                LogEditorView(editingLog: log)
            }
        }
        .confirmationDialog("이 직관 기록을 삭제할까요?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                Task {
                    await appData.deleteAttendanceLog(log)
                    dismiss()
                }
            }
            Button("취소", role: .cancel) {}
        }
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        .vfScreenBackground()
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            Text(log.matchup)
                .font(VFTypography.display)
                .foregroundStyle(VFColor.bodyPrimary)
            HStack {
                ResultBadge(result: log.result, scoreText: log.result == .canceled ? nil : log.scoreText)
                Text(log.stadium)
                Text(log.dateText)
            }
            .font(.subheadline)
            .foregroundStyle(VFColor.bodySecondary)
            if let sourceLabel = log.subtleSourceLabel {
                Text(sourceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
    }

    private var infoCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("경기 정보")
                    .font(VFTypography.cardTitle)
                infoRow("좌석", log.seat)
                infoRow("동행", log.companion)
            }
            .foregroundStyle(VFColor.bodyPrimary)
        }
    }

    private var memoCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Text("한 줄 메모")
                    .font(VFTypography.cardTitle)
                Text(log.memo)
                    .font(VFTypography.body)
            }
            .foregroundStyle(VFColor.bodyPrimary)
        }
    }

    @ViewBuilder
    private var officialRecordCard: some View {
        if let url = log.officialRecordURL.flatMap(URL.init(string:)) {
            VFCard {
                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    Text("공식 기록 보기")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("상세 기록은 KBO 공식 페이지에서 확인해 주세요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                    Button {
                        safariRoute = SafariRoute(url: url)
                        debugLogKBO("official link opened=true")
                    } label: {
                        Label("공식 기록 보기", systemImage: "safari")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(theme.textOnPrimary)
                            .background(theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("공식 기록 보기")
                }
            }
        }
    }

    private var diaryCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Text("직관 다이어리")
                    .font(VFTypography.cardTitle)
                Text(log.diary)
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(VFColor.bodySecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func debugLogKBO(_ message: String) {
        #if DEBUG
        print("[KBO] \(message)")
        #endif
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct PhotoAttachmentStrip: View {
    let photoLocalRefs: [String]
    var maxHeight: CGFloat = 160
    var target: PhotoDisplayTarget = .feedStrip
    private let service = PhotoAttachmentService()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VFSpacing.sm) {
                ForEach(photoLocalRefs, id: \.self) { ref in
                    AttachmentPhotoView(ref: ref, target: target)
                        .frame(width: photoLocalRefs.count == 1 ? 240 : 128, height: maxHeight)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                        .accessibilityLabel("첨부 사진")
                }
            }
        }
    }
}

#Preview("피드 데이터") {
    let preferences = UserPreferencesStore.preview(suiteName: "FeedPreview")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        FeedView(viewModel: .sample)
    }
    .environmentObject(appData)
}

#Preview("피드 빈 상태") {
    let preferences = UserPreferencesStore.preview(suiteName: "FeedEmptyPreview")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        FeedView(viewModel: .empty)
    }
    .environmentObject(appData)
}

#Preview("직관 상세") {
    NavigationStack {
        if let log = AttendanceLogSample.logs.first {
            AttendancePostDetailView(log: log)
        } else {
            Text("No sample log")
        }
    }
}
