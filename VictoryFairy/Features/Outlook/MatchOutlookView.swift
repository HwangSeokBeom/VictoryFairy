import SwiftUI

struct MatchOutlookView: View {
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @Environment(\.appTheme) private var theme
    @State private var selectedOpponentID: String = KBOSeed.teams.dropFirst().first?.id ?? "doosan-bears"
    @State private var selectedDate = Date()
    @State private var outlook: MatchOutlookResponse?
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(
                    title: "경기 전망",
                    subtitle: "내 직관 기록과 참고용 경기 정보를 바탕으로 만든 응원 포인트예요."
                )

                disclaimerCard
                selectorCard

                if let outlook {
                    outlookCard(outlook)
                } else if let message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VFColor.secondaryText)
                        .padding(.horizontal, VFSpacing.xs)
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("경기 전망")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeOpponent()
        }
        .vfScreenBackground()
    }

    private var favoriteTeam: KBOTeam {
        appData.team(id: preferences.favoriteTeamID) ?? KBOSeed.teams[0]
    }

    private var opponentTeam: KBOTeam {
        appData.team(id: selectedOpponentID) ?? KBOSeed.teams.first { $0.id != favoriteTeam.id } ?? KBOSeed.teams[0]
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(VFColor.victoryOrange)
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                Text("재미로 보는 경기 전망")
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                Text("공식 예측이나 베팅 정보가 아닙니다.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.secondaryText)
            }
            Spacer()
        }
        .padding(VFSpacing.md)
        .background(VFColor.victoryOrange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private var selectorCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text(favoriteTeam.shortName)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(theme.primary)
                    Text("vs")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.secondaryText)
                    Picker("상대팀", selection: $selectedOpponentID) {
                        ForEach(KBOSeed.teams.filter { $0.id != favoriteTeam.id }) { team in
                            Text(team.shortName).tag(team.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                }

                DatePicker("경기 날짜", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)

                VFPrimaryButton(title: isLoading ? "불러오는 중" : "관전 포인트 보기", systemImage: "sparkles") {
                    Task { await loadOutlook() }
                }
                .disabled(isLoading)
            }
        }
    }

    private func outlookCard(_ outlook: MatchOutlookResponse) -> some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text(outlook.title)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Spacer()
                    Text(outlook.confidenceLabel ?? "재미용")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.victoryOrange)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 26)
                        .background(VFColor.victoryOrange.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(outlook.summary)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(outlook.points, id: \.self) { point in
                    HStack(alignment: .top, spacing: VFSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.primary)
                            .padding(.top, 2)
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(VFColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(outlook.disclaimer ?? "공식 예측이나 베팅 정보가 아닙니다.")
                    .font(.caption)
                    .foregroundStyle(VFColor.secondaryText)
                    .padding(.top, VFSpacing.xs)
            }
        }
    }

    @MainActor
    private func loadOutlook() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        let request = MatchOutlookRequest(
            favoriteTeamID: favoriteTeam.id,
            opponentTeamID: opponentTeam.id,
            date: DateFormatter.vfAPIDate.string(from: selectedDate),
            stadiumName: favoriteTeam.homeStadiumName
        )
        do {
            outlook = try await appData.fetchMatchOutlook(request: request)
        } catch {
            outlook = .fallback
            message = "서버 응답이 없어 안전한 안내 문구로 표시했어요."
        }
    }

    private func normalizeOpponent() {
        if selectedOpponentID == favoriteTeam.id {
            selectedOpponentID = KBOSeed.teams.first { $0.id != favoriteTeam.id }?.id ?? selectedOpponentID
        }
    }
}

#Preview("경기 전망") {
    NavigationStack {
        MatchOutlookView()
    }
    .environmentObject(UserPreferencesStore.preview(suiteName: "OutlookPreferences"))
    .environmentObject(AppDataStore(preferences: .preview(suiteName: "OutlookAppData")))
}
