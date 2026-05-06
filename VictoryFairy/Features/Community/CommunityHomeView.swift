import SwiftUI

struct CommunityHomeView: View {
    @EnvironmentObject private var appData: AppDataStore
    @State private var posts: [CommunityPostDTO] = []
    @State private var state: RemoteDataState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "응원톡", subtitle: "건강한 응원 문화를 위한 신고/관리 기능을 준비하고 있어요.")
                DataStateBanner(state: state)

                rulesCard

                if posts.isEmpty {
                    EmptyStateView(
                        title: "응원톡은 준비 중이에요.",
                        message: "건강한 응원 문화를 위한 신고/관리 기능을 준비하고 있어요.",
                        buttonTitle: "새로고침",
                        systemImage: "bubble.left.and.bubble.right"
                    ) {
                        Task { await loadPosts() }
                    }
                } else {
                    LazyVStack(spacing: VFSpacing.md) {
                        ForEach(posts) { post in
                            CommunityPostCard(post: post)
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("응원톡")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPosts()
        }
        .vfScreenBackground()
    }

    private var rulesCard: some View {
        VFCard(background: VFColor.backgroundWarm) {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack(spacing: VFSpacing.sm) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(VFColor.victoryOrange)
                    Text("커뮤니티 이용 안내")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                }
                Text("욕설/비방, 혐오 표현, 개인정보 노출, 도박/베팅 홍보, 저작권 침해 영상, 선수/구단 사칭은 허용되지 않아요.")
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("community-policy.html")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VFColor.victoryOrange)
                    .padding(.horizontal, VFSpacing.sm)
                    .frame(minHeight: 26)
                    .background(VFColor.victoryOrange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    @MainActor
    private func loadPosts() async {
        state = .loading
        do {
            let response = try await appData.fetchCommunityPosts()
            posts = response.items
            state = response.items.isEmpty ? .empty : .loaded
        } catch {
            posts = []
            state = .serverErrorUsingLocal("응원톡 서버가 아직 준비되지 않았어요.")
        }
    }
}

private struct CommunityPostCard: View {
    let post: CommunityPostDTO

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack {
                    Text(post.authorDisplayName ?? "팬")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.victoryOrange)
                    Spacer()
                    Button {
                    } label: {
                        Label("신고", systemImage: "flag")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
                Text(post.body)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let createdAt = post.createdAt {
                    Text(createdAt)
                        .font(.caption)
                        .foregroundStyle(VFColor.secondaryText)
                }
            }
        }
    }
}

#Preview("응원톡") {
    NavigationStack {
        CommunityHomeView()
    }
    .environmentObject(AppDataStore(preferences: .preview(suiteName: "CommunityPreview")))
}
