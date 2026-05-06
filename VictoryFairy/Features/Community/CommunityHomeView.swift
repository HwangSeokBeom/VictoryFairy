import SwiftUI

struct CommunityHomeView: View {
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @State private var posts: [CommunityPostDTO] = []
    @State private var state: CommunityScreenState = .loading
    @State private var inputText = ""
    @State private var isPosting = false
    @State private var message: String?
    @State private var postPendingReport: CommunityPostDTO?
    @State private var postPendingBlock: CommunityPostDTO?
    @State private var reportPendingProfile: CommunityPostDTO?
    @State private var reportReasonPendingProfile: CommunityReportReason?
    @State private var blockPendingProfile: CommunityPostDTO?
    @State private var reportedPostIDs: Set<String> = []
    @State private var blockedAuthorIDs: Set<String> = []
    @State private var selectedTeamID = KBOSeed.teams[0].id
    @State private var isShowingProfileCreation = false
    @State private var isShowingBlockedUsers = false
    @State private var pendingPostContent: String?
    @State private var safariRoute: SafariRoute?
    @State private var communityAlertMessage: String?
    @State private var toastMessage: String?

    private let maxLength = 300

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "응원톡", subtitle: "팬들과 응원 메시지를 나누고 건강한 응원 문화를 함께 지켜요.")

                if let bannerState {
                    DataStateBanner(state: bannerState)
                }

                rulesCard

                switch state {
                case .loading:
                    loadingCard
                case .enabled:
                    composerCard
                    if posts.isEmpty {
                        emptyCard
                    } else {
                        postsList
                    }
                case .disabled(let disabledMessage):
                    disabledCard(message: disabledMessage)
                case .error(let errorMessage):
                    retryCard(message: errorMessage)
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("응원톡")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            syncSelectedTeamWithProfile()
            await appData.loadLegalLinksIfNeeded()
            await appData.loadUserProfileIfNeeded()
            syncSelectedTeamWithProfile()
            await loadPosts()
        }
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        .sheet(isPresented: $isShowingProfileCreation) {
            NavigationStack {
                ProfileCreationView {
                    Task { await continueAfterProfileCreation() }
                }
            }
            .environmentObject(appData)
            .environmentObject(preferences)
        }
        .sheet(isPresented: $isShowingBlockedUsers) {
            NavigationStack {
                BlockedUsersView()
            }
            .environmentObject(appData)
        }
        .confirmationDialog("신고 사유를 선택해 주세요", isPresented: Binding(
            get: { postPendingReport != nil },
            set: { if !$0 { postPendingReport = nil } }
        ), titleVisibility: .visible) {
            ForEach(CommunityReportReason.allCases) { reason in
                Button(reason.title) {
                    if let postPendingReport {
                        Task { await report(postPendingReport, reason: reason) }
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
        .alert("이 사용자의 응원톡을 숨길까요?", isPresented: Binding(
            get: { postPendingBlock != nil },
            set: { if !$0 { postPendingBlock = nil } }
        )) {
            Button("차단하기", role: .destructive) {
                if let postPendingBlock {
                    Task { await block(postPendingBlock) }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("차단하면 이 사용자의 응원톡이 내 화면에 표시되지 않아요.")
        }
        .alert("응원톡 안내", isPresented: Binding(
            get: { communityAlertMessage != nil },
            set: { if !$0 { communityAlertMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(communityAlertMessage ?? "")
        }
        .onChange(of: inputText) {
            if inputText.count > maxLength {
                inputText = String(inputText.prefix(maxLength))
            }
        }
        .onChange(of: isShowingBlockedUsers) {
            if !isShowingBlockedUsers {
                Task { await loadPosts() }
            }
        }
        .refreshable {
            await loadPosts()
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                CommunityToast(message: toastMessage)
                    .padding(.horizontal, VFSpacing.lg)
                    .padding(.bottom, VFTabBarMetrics.tabContentBottomPadding - 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .vfScreenBackground()
    }

    private var bannerState: RemoteDataState? {
        switch state {
        case .loading:
            return .loading
        case .error(let message):
            return .error(message)
        case .enabled, .disabled:
            if let message {
                return .error(message)
            }
            return nil
        }
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
                Text("신고는 운영 검토를 위한 기능이고, 차단은 내 화면에서 특정 사용자의 응원톡을 숨기는 기능이에요.")
                    .font(.caption)
                    .foregroundStyle(VFColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: VFSpacing.sm) {
                    Button {
                        safariRoute = SafariRoute(url: communityPolicyURL)
                    } label: {
                        Label("커뮤니티 정책 보기", systemImage: "safari")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.victoryOrange)
                            .padding(.horizontal, VFSpacing.sm)
                            .frame(minHeight: 30)
                            .background(VFColor.victoryOrange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingBlockedUsers = true
                    } label: {
                        Label("차단 관리", systemImage: "person.crop.circle.badge.xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.primaryText)
                            .padding(.horizontal, VFSpacing.sm)
                            .frame(minHeight: 30)
                            .background(VFColor.card.opacity(0.72))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var communityPolicyURL: URL {
        URL(string: LegalLinksDTO.fallback.communityPolicy)!
    }

    private var loadingCard: some View {
        statusCard(
            title: "응원톡을 불러오는 중이에요.",
            message: "잠시만 기다려 주세요.",
            systemImage: "arrow.clockwise",
            tint: VFColor.victoryOrange
        )
    }

    private var composerCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack(spacing: VFSpacing.sm) {
                    ProfileAvatarView(
                        imageURLString: appData.userProfile?.profileImageURL,
                        emoji: appData.userProfile?.profileEmoji ?? "⚾",
                        size: 34
                    )
                    Picker("응원팀", selection: $selectedTeamID) {
                        ForEach(KBOSeed.teams) { team in
                            Text(team.shortName).tag(team.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VFColor.primaryText)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputText)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.primaryText)
                        .frame(minHeight: 104)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .scrollContentBackground(.hidden)
                        .background(VFColor.backgroundWarm)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                                .stroke(VFColor.mutedLine.opacity(0.9), lineWidth: 1)
                        )
                        .disabled(isPosting)

                    if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("응원 메시지를 남겨보세요")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.secondaryText)
                            .padding(.top, 16)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Text("\(inputText.count)/\(maxLength)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(inputText.count >= maxLength ? VFColor.lossRed : VFColor.secondaryText)
                    Spacer()
                    Button {
                        Task { await submitPost() }
                    } label: {
                        Label(isPosting ? "올리는 중..." : "올리기", systemImage: "paperplane.fill")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, VFSpacing.md)
                            .frame(minHeight: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(canSubmit ? VFColor.victoryOrange : VFColor.victoryOrange.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var emptyCard: some View {
        statusCard(
            title: responseMessage ?? "아직 응원톡이 없어요. 첫 응원을 남겨보세요.",
            message: nil,
            systemImage: "bubble.left.and.bubble.right",
            tint: VFColor.victoryOrange
        )
    }

    private var postsList: some View {
        LazyVStack(spacing: VFSpacing.md) {
            ForEach(posts) { post in
                CommunityPostCard(
                    post: post,
                    isReported: reportedPostIDs.contains(post.id),
                    onReport: {
                    postPendingReport = post
                    },
                    onBlock: {
                        postPendingBlock = post
                    }
                )
            }
        }
    }

    private func disabledCard(message: String) -> some View {
        statusCard(
            title: "응원톡은 준비 중이에요.",
            message: message,
            systemImage: "bubble.left.and.bubble.right",
            tint: VFColor.drawGray
        )
    }

    private func retryCard(message: String) -> some View {
        VFCard(background: VFColor.lossRed.opacity(0.08)) {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack(alignment: .top, spacing: VFSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(VFColor.lossRed)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VFColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                VFSecondaryButton(title: "다시 시도", systemImage: "arrow.clockwise") {
                    Task { await loadPosts() }
                }
            }
        }
    }

    private func statusCard(title: String, message: String?, systemImage: String, tint: Color) -> some View {
        VFCard(background: tint.opacity(0.08)) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VFColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(VFColor.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
        }
    }

    private var canSubmit: Bool {
        !isPosting && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var responseMessage: String? {
        if case .enabled(let responseMessage) = state {
            return responseMessage
        }
        return nil
    }

    @MainActor
    private func loadPosts() async {
        state = .loading
        message = nil
        debugLog("loadStarted")
        do {
            if appData.userProfile != nil {
                blockedAuthorIDs = Set((try? await appData.fetchBlockedUsers().items.map(\.authorID)) ?? [])
            }
            let response = try await appData.fetchCommunityPosts()
            posts = response.items.filter { post in
                (post.status ?? "visible") == "visible" && !blockedAuthorIDs.contains(post.authorID ?? "")
            }
            if response.enabled == false {
                state = .disabled(response.message ?? "건강한 응원 문화를 위한 신고/관리 기능을 준비하고 있어요.")
            } else {
                state = .enabled(response.message)
            }
            debugLog("loadSuccess enabled=\(response.enabled ?? true) count=\(posts.count)")
        } catch {
            posts = []
            if isCommunityDisabled(error) {
                state = .disabled(error.localizedDescription)
            } else {
                state = .error(error.localizedDescription)
            }
            debugLog("loadFailed code=\(serverCode(error) ?? "network")")
        }
    }

    @MainActor
    private func submitPost() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        if appData.userProfile == nil {
            await appData.loadUserProfileIfNeeded(force: true)
        }
        guard appData.userProfile != nil else {
            pendingPostContent = content
            isShowingProfileCreation = true
            debugLog("profileRequired")
            return
        }

        isPosting = true
        message = nil
        debugLog("postStarted length=\(content.count)")
        defer { isPosting = false }

        do {
            let created = try await appData.createCommunityPost(
                CreateCommunityPostRequest(content: content, teamID: KBOSeed.normalizedTeamID(selectedTeamID))
            )
            inputText = ""
            if !posts.contains(where: { $0.id == created.id }) {
                posts.insert(created, at: 0)
            }
            state = .enabled(responseMessage)
            debugLog("postSuccess id=\(created.id)")
        } catch {
            let code = serverCode(error)
            debugLog("postFailed code=\(code ?? "network")")
            if code == "COMMUNITY_DISABLED" {
                state = .disabled(error.localizedDescription)
            } else if code == "COMMUNITY_CONTENT_REJECTED" {
                message = error.localizedDescription
                communityAlertMessage = error.localizedDescription
            } else if code == "PROFILE_REQUIRED" {
                pendingPostContent = content
                isShowingProfileCreation = true
                debugLog("profileRequired")
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func report(_ post: CommunityPostDTO, reason: CommunityReportReason) async {
        postPendingReport = nil
        if appData.userProfile == nil {
            await appData.loadUserProfileIfNeeded(force: true)
        }
        guard appData.userProfile != nil else {
            reportPendingProfile = post
            reportReasonPendingProfile = reason
            isShowingProfileCreation = true
            debugLog("profileRequired")
            return
        }
        do {
            try await appData.reportCommunityPost(id: post.id, reason: reason.serverValue)
            reportedPostIDs.insert(post.id)
            showToast("신고가 접수됐어요.")
            debugLog("reportSuccess id=\(post.id)")
        } catch {
            if serverCode(error) == "PROFILE_REQUIRED" {
                reportPendingProfile = post
                reportReasonPendingProfile = reason
                isShowingProfileCreation = true
                debugLog("profileRequired")
            } else {
                message = error.localizedDescription
                debugLog("reportFailed code=\(serverCode(error) ?? "network")")
            }
        }
    }

    @MainActor
    private func block(_ post: CommunityPostDTO) async {
        postPendingBlock = nil
        if appData.userProfile == nil {
            await appData.loadUserProfileIfNeeded(force: true)
        }
        guard appData.userProfile != nil else {
            blockPendingProfile = post
            isShowingProfileCreation = true
            debugLog("profileRequired")
            return
        }
        guard let authorID = post.authorID, !authorID.isEmpty else {
            communityAlertMessage = "차단할 사용자를 확인할 수 없어요."
            return
        }
        do {
            try await appData.blockCommunityAuthor(authorID: authorID)
            blockedAuthorIDs.insert(authorID)
            posts.removeAll { $0.authorID == authorID }
            showToast("해당 사용자의 응원톡을 숨겼어요.")
            debugLog("blockSuccess authorID=\(authorID)")
        } catch {
            if serverCode(error) == "PROFILE_REQUIRED" {
                blockPendingProfile = post
                isShowingProfileCreation = true
                debugLog("profileRequired")
            } else {
                message = error.localizedDescription
                debugLog("blockFailed code=\(serverCode(error) ?? "network")")
            }
        }
    }

    @MainActor
    private func continueAfterProfileCreation() async {
        syncSelectedTeamWithProfile()
        if let pendingPostContent {
            self.pendingPostContent = nil
            inputText = pendingPostContent
            showToast("프로필을 저장했어요. 내용을 확인한 뒤 올리기를 눌러 주세요.")
            return
        }
        if let reportPendingProfile {
            self.reportPendingProfile = nil
            let reason = reportReasonPendingProfile ?? .other
            reportReasonPendingProfile = nil
            await report(reportPendingProfile, reason: reason)
            return
        }
        if let blockPendingProfile {
            self.blockPendingProfile = nil
            await block(blockPendingProfile)
        }
    }

    @MainActor
    private func showToast(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastMessage == text {
                toastMessage = nil
            }
        }
    }

    private func syncSelectedTeamWithProfile() {
        selectedTeamID = KBOSeed.normalizedTeamID(appData.userProfile?.favoriteTeamID)
            ?? KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
            ?? KBOSeed.teams[0].id
    }

    private func isCommunityDisabled(_ error: Error) -> Bool {
        serverCode(error) == "COMMUNITY_DISABLED"
    }

    private func serverCode(_ error: Error) -> String? {
        if case let APIError.server(code, _) = error {
            return code
        }
        return nil
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[Community] \(message)")
        #endif
    }
}

private enum CommunityScreenState: Equatable {
    case loading
    case enabled(String?)
    case disabled(String)
    case error(String)
}

private enum CommunityReportReason: String, CaseIterable, Identifiable {
    case abusive
    case hate
    case privacy
    case betting
    case copyright
    case impersonation
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .abusive:
            return "욕설/비방"
        case .hate:
            return "혐오 표현"
        case .privacy:
            return "개인정보 노출"
        case .betting:
            return "도박/베팅 홍보"
        case .copyright:
            return "저작권 침해"
        case .impersonation:
            return "사칭"
        case .spam:
            return "스팸"
        case .other:
            return "기타"
        }
    }

    var serverValue: String { title }
}

private struct CommunityPostCard: View {
    let post: CommunityPostDTO
    let isReported: Bool
    let onReport: () -> Void
    let onBlock: () -> Void

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack(alignment: .top) {
                    HStack(spacing: VFSpacing.sm) {
                        ProfileAvatarView(
                            imageURLString: post.authorProfileImageURL,
                            emoji: post.authorProfileEmoji,
                            size: 40
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorDisplayName ?? "익명 팬")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(VFColor.primaryText)
                            HStack(spacing: VFSpacing.xs) {
                                Text(teamBadgeText)
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(VFColor.victoryOrange)
                                    .padding(.horizontal, VFSpacing.xs)
                                    .frame(minHeight: 22)
                                    .background(VFColor.victoryOrange.opacity(0.11))
                                    .clipShape(Capsule())
                                if let createdAt = formattedCreatedAt {
                                    Text(createdAt)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(VFColor.secondaryText)
                                }
                            }
                        }
                    }
                    Spacer()
                    Menu {
                        Button {
                            onReport()
                        } label: {
                            Label(isReported ? "신고됨" : "신고하기", systemImage: isReported ? "checkmark.circle.fill" : "flag")
                        }
                        .disabled(isReported || post.reportable == false)

                        if post.authorID?.isEmpty == false {
                            Button(role: .destructive) {
                                onBlock()
                            } label: {
                                Label("차단하기", systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(VFColor.secondaryText)
                            .frame(width: 34, height: 34)
                            .background(VFColor.backgroundWarm)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("더보기")
                }
                Text(post.body)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, VFSpacing.xs)
            }
        }
    }

    private var teamBadgeText: String {
        if let teamID = post.teamID, let team = KBOSeed.team(id: KBOSeed.normalizedTeamID(teamID)) {
            return team.shortName
        }
        if let teamName = post.teamName {
            return teamName
        }
        return "팬"
    }

    private var formattedCreatedAt: String? {
        guard let createdAt = post.createdAt else { return nil }
        if let date = ISO8601DateFormatter.vfCommunity.date(from: createdAt) {
            return DateFormatter.vfCommunityDisplay.string(from: date)
        }
        return createdAt
    }
}

private struct CommunityToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, VFSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(VFColor.scoreboardNavy.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
    }
}

private extension ISO8601DateFormatter {
    static let vfCommunity: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static let vfCommunityDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter
    }()
}

#Preview("응원톡") {
    NavigationStack {
        CommunityHomeView()
    }
    .environmentObject(UserPreferencesStore.preview(suiteName: "CommunityPreview", favoriteTeamID: "samsung-lions"))
    .environmentObject(AppDataStore(preferences: .preview(suiteName: "CommunityPreview")))
}
