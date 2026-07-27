import PhotosUI
import SwiftUI
import UIKit

struct ProfileSettingsView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTeamSelection = false
    @State private var isShowingProfileEditor = false
    @State private var isShowingBlockedUsers = false
    @State private var safariRoute: SafariRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("설정")
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .padding(.top, VFSpacing.sm)

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        Button {
                            isShowingProfileEditor = true
                        } label: {
                            if let profile = appData.userProfile {
                                ProfileSummaryRow(profile: profile)
                            } else {
                                ProfileSettingsRow(title: "프로필 만들기", value: "선택", systemImage: "person.crop.circle.badge.plus")
                            }
                        }
                        .buttonStyle(.plain)
                        Divider()
                        ProfileSettingsRow(title: "응원팀", value: appData.teamName(id: preferences.favoriteTeamID), systemImage: "star.fill")
                        Divider()
                        Button {
                            isShowingTeamSelection = true
                        } label: {
                            ProfileSettingsRow(title: "응원팀 변경", value: "선택", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.plain)
                        Divider()
                        Toggle(isOn: Binding(
                            get: { preferences.teamThemeEnabled },
                            set: { appData.updateTeamThemeEnabled($0) }
                        )) {
                            HStack(spacing: VFSpacing.md) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(theme.primary)
                                    .frame(width: 36, height: 36)
                                    .background(theme.primary.opacity(0.1))
                                    .clipShape(Circle())
                                Text("팀 컬러 테마 사용")
                                    .font(.subheadline)
                                    .foregroundStyle(VFColor.bodyPrimary)
                            }
                        }
                        .tint(theme.primary)
                        Divider()
                        ProfileSettingsRow(title: "총 기록 수", value: "\(appData.feedLogs.count)경기", systemImage: "rectangle.stack.fill")
                    }
                }

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        ProfileSettingsRow(title: "데이터 동기화 상태", value: appData.serverStatus.title, systemImage: serverStatusIcon)
                        Divider()
                        Text("데이터 저장")
                            .font(VFTypography.sectionTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text("기록은 우선 이 기기에 저장돼요.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodySecondary)
                        ProfileSettingsRow(title: "데이터 내보내기", value: "추후 제공", systemImage: "square.and.arrow.up")
                    }
                }

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        Text("AI 기능 안내")
                            .font(VFTypography.sectionTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text("AI 후기 초안은 서버에서 만들고 저장 전 직접 확인해요.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text("사진, 정확한 위치, 동행자 실명은 기본적으로 AI에 전송하지 않도록 설계합니다.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodySecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                legalLinksCard

                VFCard {
                    Button {
                        isShowingBlockedUsers = true
                    } label: {
                        ProfileSettingsRow(title: "차단한 사용자", value: "관리", systemImage: "person.crop.circle.badge.xmark")
                    }
                    .buttonStyle(.plain)
                }

                VFCard {
                    ProfileSettingsRow(title: "앱 정보", value: "승리요정 0.1.0", systemImage: "info.circle")
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appData.loadUserProfileIfNeeded()
            await appData.loadLegalLinksIfNeeded()
        }
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        .sheet(isPresented: $isShowingProfileEditor) {
            NavigationStack {
                ProfileCreationView(title: appData.userProfile == nil ? "프로필 만들기" : "프로필 수정")
            }
            .environmentObject(appData)
            .environmentObject(preferences)
            .environment(\.appTheme, theme)
        }
        .sheet(isPresented: $isShowingBlockedUsers) {
            NavigationStack {
                BlockedUsersView()
            }
            .environmentObject(appData)
            .environment(\.appTheme, theme)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
                .foregroundStyle(theme.primary)
            }
        }
        .sheet(isPresented: $isShowingTeamSelection) {
            NavigationStack {
                ScrollView {
                    TeamSelectionView(
                        selectedTeamID: Binding(
                            get: { preferences.favoriteTeamID },
                            set: { appData.updateFavoriteTeam($0) }
                        ),
                        teams: appData.teams
                    )
                    .padding(VFSpacing.lg)
                }
                .navigationTitle("응원팀 변경")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") {
                            isShowingTeamSelection = false
                        }
                        .foregroundStyle(theme.primary)
                    }
                }
                .vfScreenBackground()
            }
            .environment(\.appTheme, theme)
        }
        .vfScreenBackground()
    }

    private var legalLinksCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("지원 및 정책")
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                legalButton(title: "이용약관", url: appData.legalURL(\.terms), systemImage: "doc.text")
                Divider()
                legalButton(title: "개인정보 처리방침", url: appData.legalURL(\.privacy), systemImage: "lock.shield")
                Divider()
                legalButton(title: "고객지원", url: appData.legalURL(\.support), systemImage: "questionmark.circle")
                Divider()
                legalButton(title: "계정 삭제 안내", url: appData.legalURL(\.accountDeletion), systemImage: "person.crop.circle.badge.xmark")
                Divider()
                legalButton(title: "커뮤니티 정책 보기", url: appData.legalURL(\.communityPolicy), systemImage: "shield.checkered")
                Divider()
                legalButton(title: "경기 전망 안내", url: appData.legalURL(\.disclaimer), systemImage: "heart.text.square")
            }
        }
    }

    private func legalButton(title: String, url: URL, systemImage: String) -> some View {
        Button {
            safariRoute = SafariRoute(url: url)
        } label: {
            ProfileSettingsRow(title: title, value: "열기", systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private var serverStatusIcon: String {
        switch appData.serverStatus {
        case .checking:
            return "arrow.clockwise"
        case .connected:
            return "checkmark.circle.fill"
        case .localMode:
            return "wifi.slash"
        }
    }
}

struct ProfileSettingsRow: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: VFSpacing.md) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primary)
                .frame(width: 36, height: 36)
                .background(theme.primary.opacity(0.1))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline)
                .foregroundStyle(VFColor.bodyPrimary)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 44)
    }
}

struct ProfileSummaryRow: View {
    let profile: UserProfileDTO

    var body: some View {
        HStack(spacing: VFSpacing.md) {
            ProfileAvatarView(
                imageURLString: profile.profileImageURL,
                emoji: profile.profileEmoji,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("프로필")
                    .font(.subheadline)
                    .foregroundStyle(VFColor.bodyPrimary)
                Text(profile.nickname)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
            }

            Spacer()

            Text("수정")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
        }
        .frame(minHeight: 48)
    }
}

struct ProfileAvatarView: View {
    let imageURLString: String?
    let emoji: String?
    var uiImage: UIImage?
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(VFColor.subtleSurface)
            avatarContent
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = imageURLString,
                  let url = URL(string: urlString),
                  !urlString.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackContent
                }
            }
        } else {
            fallbackContent
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        if let emoji, !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: size * 0.42))
        } else {
            Image(systemName: "baseball.fill")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(VFColor.primaryAction)
        }
    }
}

struct ProfileCreationView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @Environment(\.dismiss) private var dismiss
    var title: String = "프로필 만들기"
    @State private var nickname = ""
    @State private var favoriteTeamID = KBOSeed.teams[0].id
    @State private var profileEmoji = "⚾"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPreviewImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedImageMimeType = "image/jpeg"
    @State private var shouldDeleteExistingImage = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isProcessingImage = false

    var onCompleted: (() -> Void)?

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        (2...12).contains(trimmedNickname.count) && !isSaving && !isProcessingImage
    }

    private var saveButtonTitle: String {
        if isSaving {
            return "저장 중..."
        }
        return appData.userProfile == nil ? "시작하기" : "저장하기"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(
                    title: title,
                    subtitle: "응원톡과 개인화 기능에 사용할 간단한 프로필이에요."
                )

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        profilePhotoSection

                        Divider()

                        Text("닉네임")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.bodyPrimary)
                        TextField("닉네임을 입력해 주세요", text: $nickname)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodyPrimary)
                            .padding(.horizontal, VFSpacing.md)
                            .frame(minHeight: 46)
                            .background(VFColor.subtleSurface)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        Text("2~12자로 입력해 주세요.")
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)

                        Divider()

                        Text("응원팀")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.bodyPrimary)
                        Picker("응원팀", selection: $favoriteTeamID) {
                            ForEach(KBOSeed.teams) { team in
                                Text(team.name).tag(team.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(theme.primary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, VFSpacing.sm)
                        .background(VFColor.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))

                        Divider()

                        Text("프로필 이모지")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.bodyPrimary)
                        TextField("⚾", text: $profileEmoji)
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodyPrimary)
                            .padding(.horizontal, VFSpacing.md)
                            .frame(minHeight: 46)
                            .background(VFColor.subtleSurface)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))

                        Text("이 정보는 승리요정 안에서 응원톡 작성자 표시와 개인화에 사용돼요.")
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VFColor.gameLoss)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(spacing: VFSpacing.sm) {
                    VFPrimaryButton(title: saveButtonTitle, systemImage: "checkmark.circle.fill") {
                        Task { await saveProfile() }
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.55)

                    VFSecondaryButton(title: "나중에", systemImage: "clock") {
                        dismiss()
                    }
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hydrateFields()
        }
        .onChange(of: selectedPhotoItem) {
            Task { await loadSelectedPhoto() }
        }
        .onChange(of: nickname) {
            if nickname.count > 12 {
                nickname = String(nickname.prefix(12))
            }
        }
        .onChange(of: profileEmoji) {
            if profileEmoji.count > 2 {
                profileEmoji = String(profileEmoji.prefix(2))
            }
        }
        .vfScreenBackground()
    }

    private var profilePhotoSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.md) {
            HStack(alignment: .center, spacing: VFSpacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatarView(
                        imageURLString: shouldDeleteExistingImage ? nil : appData.userProfile?.profileImageURL,
                        emoji: previewEmoji,
                        uiImage: selectedPreviewImage,
                        size: 86
                    )

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "camera.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(theme.primary)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .accessibilityLabel("사진 변경")
                    }
                    .disabled(isProcessingImage || isSaving)
                }

                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("프로필 사진")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("프로필 사진은 응원톡 작성자 표시에 사용돼요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: VFSpacing.sm) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label(isProcessingImage ? "처리 중..." : "사진 선택", systemImage: "photo")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 34)
                        .background(theme.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .disabled(isProcessingImage || isSaving)

                Button {
                    removeSelectedPhoto()
                } label: {
                    Label("사진 삭제", systemImage: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.gameLoss)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 34)
                        .background(VFColor.gameLoss.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!hasProfileImageToRemove || isSaving)
                .opacity(hasProfileImageToRemove ? 1 : 0.45)
            }
        }
    }

    private var hasProfileImageToRemove: Bool {
        selectedPreviewImage != nil || (!shouldDeleteExistingImage && appData.userProfile?.profileImageURL?.isEmpty == false)
    }

    private var previewEmoji: String {
        let trimmed = profileEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "⚾" : trimmed
    }

    private func hydrateFields() {
        if let profile = appData.userProfile {
            nickname = profile.nickname
            favoriteTeamID = KBOSeed.normalizedTeamID(profile.favoriteTeamID) ?? profile.favoriteTeamID
            profileEmoji = profile.profileEmoji ?? "⚾"
        } else {
            nickname = preferences.userDisplayName ?? ""
            favoriteTeamID = KBOSeed.normalizedTeamID(preferences.favoriteTeamID) ?? KBOSeed.teams[0].id
            profileEmoji = "⚾"
        }
        selectedPhotoItem = nil
        selectedPreviewImage = nil
        selectedImageData = nil
        shouldDeleteExistingImage = false
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        isProcessingImage = true
        errorMessage = nil
        defer { isProcessingImage = false }
        do {
            let payload = try await ProfileImageProcessor().payload(from: selectedPhotoItem)
            selectedPreviewImage = payload.previewImage
            selectedImageData = payload.data
            selectedImageMimeType = payload.mimeType
            shouldDeleteExistingImage = false
        } catch {
            selectedPreviewImage = nil
            selectedImageData = nil
            self.selectedPhotoItem = nil
            errorMessage = error.localizedDescription
        }
    }

    private func removeSelectedPhoto() {
        selectedPhotoItem = nil
        selectedPreviewImage = nil
        selectedImageData = nil
        shouldDeleteExistingImage = appData.userProfile?.profileImageURL?.isEmpty == false
    }

    @MainActor
    private func saveProfile() async {
        guard canSave else {
            errorMessage = "닉네임은 2~12자로 입력해 주세요."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await appData.saveUserProfile(
                UpsertUserProfileRequest(
                    nickname: trimmedNickname,
                    favoriteTeamID: favoriteTeamID,
                    profileEmoji: profileEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "⚾" : profileEmoji
                )
            )
            if let selectedImageData {
                try await appData.uploadProfileImage(data: selectedImageData, mimeType: selectedImageMimeType)
            } else if shouldDeleteExistingImage {
                try await appData.deleteProfileImage()
            }
            onCompleted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BlockedUsersView: View {
    @EnvironmentObject private var appData: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var users: [BlockedUserDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unblockingAuthorIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "차단한 사용자", subtitle: "내 응원톡 화면에서 숨긴 사용자를 관리해요.")

                if isLoading {
                    blockedUsersStatusCard(title: "차단 목록을 불러오는 중이에요.", message: nil, systemImage: "arrow.clockwise", tint: VFColor.primaryAction)
                } else if let errorMessage {
                    blockedUsersStatusCard(title: "차단 목록을 불러오지 못했어요.", message: errorMessage, systemImage: "exclamationmark.triangle.fill", tint: VFColor.gameLoss)
                } else if users.isEmpty {
                    blockedUsersStatusCard(title: "차단한 사용자가 없어요.", message: nil, systemImage: "person.2", tint: VFColor.gameDraw)
                } else {
                    LazyVStack(spacing: VFSpacing.sm) {
                        ForEach(users) { user in
                            blockedUserRow(user)
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationTitle("차단한 사용자")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedUsers()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
                .foregroundStyle(VFColor.primaryAction)
            }
        }
        .vfScreenBackground()
    }

    private func blockedUserRow(_ user: BlockedUserDTO) -> some View {
        VFCard {
            HStack(spacing: VFSpacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
                    .frame(width: 42, height: 42)
                    .background(VFColor.subtleSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.authorDisplayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text(formattedBlockedAt(user.blockedAt) ?? "차단됨")
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                }

                Spacer()

                Button {
                    Task { await unblock(user) }
                } label: {
                    Text(unblockingAuthorIDs.contains(user.authorID) ? "해제 중" : "차단 해제")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.primaryAction)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 32)
                        .background(VFColor.primaryAction.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(unblockingAuthorIDs.contains(user.authorID))
            }
        }
    }

    private func blockedUsersStatusCard(title: String, message: String?, systemImage: String, tint: Color) -> some View {
        VFCard(background: tint.opacity(0.08)) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VFColor.bodyPrimary)
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadBlockedUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await appData.fetchBlockedUsers().items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func unblock(_ user: BlockedUserDTO) async {
        unblockingAuthorIDs.insert(user.authorID)
        defer { unblockingAuthorIDs.remove(user.authorID) }
        do {
            try await appData.unblockCommunityAuthor(authorID: user.authorID)
            users.removeAll { $0.authorID == user.authorID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formattedBlockedAt(_ value: String?) -> String? {
        guard let value else { return nil }
        if let date = ISO8601DateFormatter.vfProfileBlocked.date(from: value) {
            return "\(DateFormatter.vfProfileBlockedDisplay.string(from: date)) 차단"
        }
        return value
    }
}

private extension ISO8601DateFormatter {
    static let vfProfileBlocked: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static let vfProfileBlockedDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter
    }()
}

#Preview("설정") {
    let preferences = UserPreferencesStore.preview(suiteName: "SettingsPreview", favoriteTeamID: "lg-twins")
    let appData = AppDataStore(preferences: preferences)
    let theme = TeamTheme(team: KBOSeed.teams[0])
    NavigationStack {
        ProfileSettingsView()
    }
    .environmentObject(preferences)
    .environmentObject(appData)
    .environment(\.appTheme, theme)
}
