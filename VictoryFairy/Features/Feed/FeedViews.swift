import SwiftUI

struct FeedViewModel {
    let logs: [AttendanceLogViewState]
    var selectedResultFilter: FeedResultFilter = .all
    var dataState: RemoteDataState = .loaded

    static let sample = FeedViewModel(logs: AttendanceLogSample.logs)
    static let empty = FeedViewModel(logs: [])
}

struct FeedView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: FeedViewModel
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "직관 피드") {
                    HeaderIconButton(systemImage: "plus", accessibilityLabel: "직관 기록 추가") {
                        isShowingLogEditor = true
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VFSpacing.sm) {
                        VFChip(title: "2026 시즌", isSelected: true)
                        ForEach(FeedResultFilter.allCases) { filter in
                            Button {
                                Task {
                                    await appData.selectFeedResultFilter(filter)
                                }
                            } label: {
                                VFChip(
                                    title: filter.title,
                                    isSelected: viewModel.selectedResultFilter == filter,
                                    tint: filter.result?.color ?? theme.secondary
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                DataStateBanner(state: viewModel.dataState)

                if viewModel.logs.isEmpty {
                    EmptyStateView(
                        title: viewModel.selectedResultFilter == .all ? "아직 피드에 남긴 직관이 없어요." : "해당 결과의 직관 기록이 없어요.",
                        message: viewModel.selectedResultFilter == .all ? "첫 직관을 피드에 남겨보세요." : "다른 결과를 선택하거나 새 직관 기록을 남겨보세요.",
                        buttonTitle: "직관 기록 추가"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    LazyVStack(spacing: VFSpacing.lg) {
                        ForEach(viewModel.logs) { log in
                            AttendancePostCard(log: log)
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                LogEditorView()
            }
        }
        .vfScreenBackground()
    }
}

struct AttendancePostCard: View {
    @Environment(\.appTheme) private var theme
    let log: AttendanceLogViewState
    var showsActions = true

    var body: some View {
        VFCard(padding: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 5)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    scoreboardHeader

                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                                Text(log.dateText)
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundStyle(VFColor.secondaryText)
                                Text(log.stadium)
                                    .font(.subheadline)
                                    .foregroundStyle(VFColor.secondaryText)
                            }
                            Spacer()
                            ResultBadge(result: log.result, scoreText: log.result == .canceled ? nil : log.scoreText)
                        }

                        if !log.photoLocalRefs.isEmpty {
                            PhotoAttachmentStrip(photoLocalRefs: log.photoLocalRefs, maxHeight: 150)
                        }

                        Text(log.caption)
                            .font(VFTypography.body)
                            .foregroundStyle(VFColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if let sourceLabel = log.subtleSourceLabel {
                            Text(sourceLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VFColor.secondaryText)
                        }

                        tagRow

                        if showsActions {
                            HStack(spacing: VFSpacing.sm) {
                                NavigationLink {
                                    AttendancePostDetailView(log: log)
                                } label: {
                                    Text("자세히 보기")
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .background(theme.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))

                                NavigationLink {
                                    ShareCardPreviewView()
                                } label: {
                                    Text("공유")
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(VFColor.primaryText)
                                .background(VFColor.offWhite)
                                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                            }
                        }
                    }
                    .padding(VFSpacing.md)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(log.accessibilitySummary)
    }

    private var scoreboardHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [theme.gradientStart, theme.secondary.opacity(0.9), theme.gradientEnd.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack(spacing: VFSpacing.sm) {
                    Text(log.matchup)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.78)
                    if let team = selectedTeam {
                        Text(team.shortName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, VFSpacing.sm)
                            .frame(minHeight: 26)
                            .background(.white.opacity(0.9))
                            .clipShape(Capsule())
                            .accessibilityLabel("응원팀 \(team.shortName)")
                    }
                }
                Text(log.resultScoreText)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(VFColor.offWhite)
                Text(log.stadium)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(VFSpacing.lg)
        }
        .frame(minHeight: 170)
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
                    PhotoAttachmentStrip(photoLocalRefs: log.photoLocalRefs, maxHeight: 210)
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
                    ShareCardPreviewView()
                } label: {
                    Label("공유 카드 만들기", systemImage: "square.and.arrow.up")
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
                        .foregroundStyle(VFColor.lossRed)
                        .background(VFColor.lossRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(VFSpacing.lg)
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
                .font(VFTypography.title)
                .foregroundStyle(VFColor.primaryText)
            HStack {
                ResultBadge(result: log.result, scoreText: log.result == .canceled ? nil : log.scoreText)
                Text(log.stadium)
                Text(log.dateText)
            }
            .font(.subheadline)
            .foregroundStyle(VFColor.secondaryText)
            if let sourceLabel = log.subtleSourceLabel {
                Text(sourceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.secondaryText)
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
            .foregroundStyle(VFColor.primaryText)
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
            .foregroundStyle(VFColor.primaryText)
        }
    }

    @ViewBuilder
    private var officialRecordCard: some View {
        if let url = log.officialRecordURL.flatMap(URL.init(string:)) {
            VFCard {
                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    Text("공식 기록")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Text("상세 기록은 KBO 공식 페이지에서 확인해 주세요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.secondaryText)
                    Button {
                        safariRoute = SafariRoute(url: url)
                        debugLogKBO("official link opened=true")
                    } label: {
                        Label("KBO 공식 기록실로 이동", systemImage: "safari")
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
                    .foregroundStyle(VFColor.secondaryText)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(VFColor.secondaryText)
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
    private let service = PhotoAttachmentService()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VFSpacing.sm) {
                ForEach(photoLocalRefs, id: \.self) { ref in
                    if let image = service.image(for: ref) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: photoLocalRefs.count == 1 ? 240 : 128, height: maxHeight)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                            .accessibilityLabel("첨부 사진")
                    }
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
