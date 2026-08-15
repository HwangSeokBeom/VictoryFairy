import SwiftUI

struct NewsView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @State private var items: [NewsItemDTO] = []
    @State private var state: RemoteDataState = .loading
    @State private var selectedFilter: NewsTeamFilter = .all
    @State private var didSetInitialFilter = false
    @State private var sourceDisclosure = "뉴스는 외부 매체로 이동해 확인해 주세요."
    @State private var safariRoute: SafariRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                filterChips

                switch state {
                case .loading:
                    NewsLoadingView()
                case .error, .serverErrorUsingLocal, .localOnly:
                    EmptyStateView(
                        title: "야구 소식을 불러오지 못했어요.",
                        message: "잠시 후 다시 시도해 주세요.",
                        buttonTitle: "새로고침",
                        systemImage: "exclamationmark.triangle.fill"
                    ) {
                        Task { await loadNews() }
                    }
                case .empty, .loaded:
                    if items.isEmpty {
                        EmptyStateView(
                            title: "아직 표시할 야구 소식이 없어요.",
                            message: "새로운 소식이 준비되면 여기에 표시돼요.",
                            buttonTitle: "새로고침",
                            systemImage: "newspaper"
                        ) {
                            Task { await loadNews() }
                        }
                    } else {
                        LazyVStack(spacing: VFSpacing.md) {
                            ForEach(items) { item in
                                NewsCard(item: item) { url in
                                    safariRoute = SafariRoute(url: url)
                                }
                            }
                        }

                        Text(sourceDisclosure)
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("야구 소식")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        .task {
            configureInitialFilterIfNeeded()
            await loadNews()
        }
        .onChange(of: preferences.favoriteTeamID) {
            configureInitialFilterIfNeeded(force: true)
            Task { await loadNews() }
        }
        .vfScreenBackground()
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VFSpacing.sm) {
                filterChip(title: "전체", filter: .all)
                if favoriteTeamID != nil {
                    filterChip(title: "응원팀", filter: .favorite)
                }
            }
        }
    }

    private func filterChip(title: String, filter: NewsTeamFilter) -> some View {
        Button {
            guard selectedFilter != filter else { return }
            selectedFilter = filter
            Task { await loadNews() }
        } label: {
            VFChip(title: title, isSelected: selectedFilter == filter, tint: theme.primary)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func configureInitialFilterIfNeeded(force: Bool = false) {
        guard force || !didSetInitialFilter else { return }
        selectedFilter = favoriteTeamID == nil ? .all : .favorite
        didSetInitialFilter = true
    }

    @MainActor
    private func loadNews() async {
        state = .loading
        do {
            let response = try await appData.fetchNews(teamID: selectedTeamID, limit: 20)
            items = response.items
            sourceDisclosure = response.sourceDisclosure.nonBlank ?? "뉴스는 외부 매체로 이동해 확인해 주세요."
            state = response.items.isEmpty ? .empty : .loaded
        } catch {
            items = []
            state = .error("야구 소식을 불러오지 못했어요.")
        }
    }

    private var favoriteTeamID: String? {
        KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
    }

    private var selectedTeamID: String? {
        switch selectedFilter {
        case .all:
            return nil
        case .favorite:
            return favoriteTeamID
        }
    }
}

private enum NewsTeamFilter {
    case all
    case favorite
}

private struct NewsLoadingView: View {
    var body: some View {
        VFCard {
            HStack(spacing: VFSpacing.sm) {
                ProgressView()
                Text("야구 소식을 불러오는 중")
                    .font(.subheadline)
                    .foregroundStyle(VFColor.bodySecondary)
                Spacer()
            }
        }
    }
}

private struct NewsCard: View {
    let item: NewsItemDTO
    let onOpen: (URL) -> Void

    var body: some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack(spacing: VFSpacing.xs) {
                    Text(item.sourceName ?? "야구 소식")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.primaryAction)
                    if let publishedText {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                        Text(publishedText)
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                }

                Text(item.title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let summary = item.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                        .lineLimit(2)
                }

                Button {
                    if let url = articleURL {
                        onOpen(url)
                    }
                } label: {
                    Label(linkTitle, systemImage: "safari")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .background(VFColor.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(articleURL == nil)
                .opacity(articleURL == nil ? 0.45 : 1)
            }
        }
    }

    private var linkTitle: String {
        let source = item.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if source == "victoryfairy" || source == "sample" || source.contains("victoryfairy/sample") {
            return "관련 안내 보기"
        }
        return "기사 보기"
    }

    private var articleURL: URL? {
        guard
            let value = item.url?.trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: value),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    private var publishedText: String? {
        guard let value = item.publishedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if let date = ISO8601DateFormatter().date(from: value) {
            return DateFormatter.vfDisplayDateTime.string(from: date)
        }
        return value
    }
}

private extension Optional where Wrapped == String {
    var nonBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

#Preview("뉴스") {
    let preferences = UserPreferencesStore.preview(suiteName: "NewsPreview", favoriteTeamID: "samsung-lions")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        NewsView()
    }
    .environmentObject(preferences)
    .environmentObject(appData)
}
