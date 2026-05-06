import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTeamSelection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("설정")
                    .font(VFTypography.title)
                    .foregroundStyle(VFColor.primaryText)
                    .padding(.top, VFSpacing.sm)

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
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
                                    .foregroundStyle(VFColor.primaryText)
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
                            .font(VFTypography.section)
                            .foregroundStyle(VFColor.primaryText)
                        Text("기록은 우선 이 기기에 저장돼요.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.secondaryText)
                        ProfileSettingsRow(title: "데이터 내보내기", value: "추후 제공", systemImage: "square.and.arrow.up")
                    }
                }

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        Text("AI 기능 안내")
                            .font(VFTypography.section)
                            .foregroundStyle(VFColor.primaryText)
                        Text("AI 후기 초안은 서버에서 만들고 저장 전 직접 확인해요.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.primaryText)
                        Text("사진, 정확한 위치, 동행자 실명은 기본적으로 AI에 전송하지 않도록 설계합니다.")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VFCard {
                    ProfileSettingsRow(title: "앱 정보", value: "승리요정 0.1.0", systemImage: "info.circle")
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
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
                .foregroundStyle(VFColor.primaryText)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(VFColor.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 44)
    }
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
