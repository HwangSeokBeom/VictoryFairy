import SwiftUI

struct MatchOutlookView: View {
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL
    @State private var selectedOpponentID: String = "doosan-bears"
    @State private var selectedDate = Date()
    @State private var state: MatchOutlookScreenState = .idle("팀과 날짜를 선택하고 관전 포인트를 확인해 보세요.")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(
                    title: "경기 전망",
                    subtitle: "오늘 경기 전망과 응원 포인트를 확인해 보세요."
                )

                disclaimerCard
                selectorCard
                resultSection
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("경기 전망")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !state.isLoaded {
                normalizeOpponent()
            }
        }
        .onChange(of: selectedOpponentID) {
            markSelectionChanged()
        }
        .onChange(of: selectedDate) {
            markSelectionChanged()
        }
        .onChange(of: preferences.favoriteTeamID) {
            normalizeOpponent()
            markSelectionChanged()
        }
        .vfScreenBackground()
    }

    private var favoriteTeam: KBOTeam {
        let favoriteTeamID = KBOSeed.normalizedTeamID(preferences.favoriteTeamID) ?? "samsung-lions"
        return appData.team(id: favoriteTeamID)
            ?? KBOSeed.team(id: favoriteTeamID)
            ?? KBOSeed.team(id: "samsung-lions")
            ?? KBOSeed.teams[0]
    }

    private var opponentTeam: KBOTeam {
        appData.team(id: validOpponentID) ?? KBOSeed.team(id: validOpponentID) ?? opponentOptions[0]
    }

    private var pickerTeams: [KBOTeam] {
        KBOSeed.teams.reduce(into: [KBOTeam]()) { teams, team in
            guard team.active, !teams.contains(where: { $0.id == team.id }) else { return }
            teams.append(team)
        }
    }

    private var opponentOptions: [KBOTeam] {
        let options = pickerTeams.filter { $0.id != favoriteTeam.id }
        return options.isEmpty ? pickerTeams : options
    }

    private var validOpponentID: String {
        if opponentOptions.contains(where: { $0.id == selectedOpponentID }) {
            return selectedOpponentID
        }
        return opponentOptions.first?.id ?? "samsung-lions"
    }

    private var opponentSelection: Binding<String> {
        Binding(
            get: { validOpponentID },
            set: { selectedOpponentID = $0 }
        )
    }

    private var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(VFColor.victoryOrange)
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                Text("재미로 보는 경기 전망")
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                Text("AI가 최근 야구 소식과 내 직관 기록을 참고해 관전 포인트를 정리해요.")
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
                    Picker("상대팀", selection: opponentSelection) {
                        ForEach(opponentOptions) { team in
                            Text(team.shortName).tag(team.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VFColor.primaryText)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("경기 날짜")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.primaryText)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(theme.primary)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 42)
                        .background(VFColor.backgroundWarm)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                                .stroke(theme.primary.opacity(0.35), lineWidth: 1)
                        )
                }

                VFPrimaryButton(title: isLoading ? "AI가 정리 중..." : "관전 포인트 보기", systemImage: "sparkles") {
                    Task { await loadOutlook() }
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.72 : 1)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch state {
        case .idle(let message):
            messageCard(message: message, systemImage: "sparkles", tint: theme.primary)
        case .loading:
            loadingCard
        case .loaded(let outlook, let updatedAt, let isStale):
            outlookCard(outlook, updatedAt: updatedAt, isStale: isStale)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .error(let message):
            errorCard(message: message)
        }
    }

    private func outlookCard(_ outlook: MatchOutlookResponse, updatedAt: Date, isStale: Bool) -> some View {
        let visibleNewsReferences = displayedNewsReferences(outlook.newsReferences)

        return VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                if isStale {
                    staleNotice
                }

                HStack {
                    Text(outlook.title)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Spacer()
                }

                HStack(spacing: VFSpacing.xs) {
                    badge(generatedByLabel(for: outlook.generatedBy), tint: theme.primary)
                    if let confidenceLabel = outlook.confidenceLabel {
                        badge(confidenceLabel, tint: VFColor.victoryOrange)
                    }
                }

                Text(outlook.summary)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if outlook.points.isEmpty {
                    Text("아직 표시할 관전 포인트가 충분하지 않아요.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VFColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(outlook.points, id: \.self) { point in
                        HStack(alignment: .top, spacing: VFSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.primary)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                if let title = point.title {
                                    Text(title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(VFColor.primaryText)
                                }
                                Text(point.body)
                                    .font(.subheadline)
                                    .foregroundStyle(VFColor.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !visibleNewsReferences.isEmpty {
                    newsReferencesSection(visibleNewsReferences)
                }

                Text(outlook.disclaimer ?? "공식 예측이나 베팅 정보가 아닙니다.")
                    .font(.caption)
                    .foregroundStyle(VFColor.secondaryText)
                    .padding(.top, VFSpacing.xs)

                Text("방금 업데이트됨")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.victoryOrange)
            }
        }
    }

    private var loadingCard: some View {
        VFCard(background: VFColor.backgroundWarm) {
            HStack(alignment: .center, spacing: VFSpacing.sm) {
                ProgressView()
                    .tint(theme.primary)
                Text("AI가 관전 포인트를 정리 중이에요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VFColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    private var staleNotice: some View {
        HStack(alignment: .top, spacing: VFSpacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.bold))
                .foregroundStyle(VFColor.victoryOrange)
                .padding(.top, 2)
            Text("선택한 조건이 바뀌었어요. 다시 확인해 주세요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VFSpacing.sm)
        .background(VFColor.victoryOrange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, VFSpacing.sm)
            .frame(minHeight: 26)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func newsReferencesSection(_ references: [MatchOutlookNewsReference]) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            Text("참고한 야구 소식")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(VFColor.primaryText)

            ForEach(references) { reference in
                HStack(alignment: .top, spacing: VFSpacing.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reference.sourceName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VFColor.victoryOrange)
                        Text(reference.title)
                            .font(.subheadline)
                            .foregroundStyle(VFColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: VFSpacing.sm)
                    if let urlString = reference.url, let url = URL(string: urlString) {
                        Button {
                            openURL(url)
                        } label: {
                            Text("기사 보기")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.primary)
                        }
                    }
                }
                .padding(VFSpacing.sm)
                .background(VFColor.backgroundWarm)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            }

            Text("뉴스는 외부 매체로 이동해 확인해 주세요.")
                .font(.caption)
                .foregroundStyle(VFColor.secondaryText)
        }
    }

    private func displayedNewsReferences(_ references: [MatchOutlookNewsReference]) -> [MatchOutlookNewsReference] {
        let allowedKeywords = newsKeywords(for: favoriteTeam) + newsKeywords(for: opponentTeam)
        let unrelatedKeywords = KBOSeed.teams
            .filter { $0.id != favoriteTeam.id && $0.id != opponentTeam.id }
            .flatMap(newsKeywords(for:))

        return references.filter { reference in
            guard !reference.title.containsAnyKeyword(in: allowedKeywords) else {
                return true
            }
            guard reference.title.containsAnyKeyword(in: unrelatedKeywords) else {
                return true
            }
            debugLog("hiddenUnrelatedNewsReference title=\(reference.title)")
            return false
        }
    }

    private func newsKeywords(for team: KBOTeam) -> [String] {
        switch team.id {
        case "lg-twins":
            return ["LG", "엘지", "LG 트윈스"]
        case "doosan-bears":
            return ["두산", "두산 베어스"]
        case "kiwoom-heroes":
            return ["키움", "키움 히어로즈"]
        case "ssg-landers":
            return ["SSG", "SSG 랜더스"]
        case "kt-wiz":
            return ["KT", "케이티", "KT 위즈", "kt wiz"]
        case "hanwha-eagles":
            return ["한화", "한화 이글스"]
        case "samsung-lions":
            return ["삼성", "삼성 라이온즈"]
        case "kia-tigers":
            return ["KIA", "기아", "KIA 타이거즈", "최형우"]
        case "lotte-giants":
            return ["롯데", "롯데 자이언츠"]
        case "nc-dinos":
            return ["NC", "엔씨", "NC 다이노스"]
        default:
            return [team.shortName, team.name]
        }
    }

    private func generatedByLabel(for value: String?) -> String {
        value?.lowercased() == "ai" ? "AI 정리" : "기본 정리"
    }

    private func messageCard(message: String, systemImage: String, tint: Color) -> some View {
        VFCard(background: VFColor.backgroundWarm) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VFColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    private func errorCard(message: String) -> some View {
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
                    Task { await loadOutlook() }
                }
            }
        }
    }

    @MainActor
    private func loadOutlook() async {
        normalizeOpponent()
        let request = MatchOutlookRequest(
            favoriteTeamID: favoriteTeam.id,
            opponentTeamID: validOpponentID,
            date: DateFormatter.vfAPIDate.string(from: selectedDate),
            stadiumName: favoriteTeam.homeStadiumName
        )
        debugLog("buttonTapped favorite=\(request.favoriteTeamID) opponent=\(request.opponentTeamID) date=\(request.date)")

        guard request.favoriteTeamID != request.opponentTeamID else {
            state = .error("상대팀을 다시 선택해 주세요.")
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            state = .loading
        }
        debugLog("loading")
        do {
            let outlook = try await appData.fetchMatchOutlook(request: request)
            withAnimation(.snappy(duration: 0.22)) {
                state = .loaded(outlook, updatedAt: Date(), isStale: false)
            }
            debugLog("loaded points=\(outlook.points.count)")
        } catch {
            debugLog("failed code=\(serverCode(error) ?? "network")")
            state = .error(error.localizedDescription)
        }
    }

    private func normalizeOpponent() {
        let normalizedOpponentID = validOpponentID
        if selectedOpponentID != normalizedOpponentID {
            selectedOpponentID = normalizedOpponentID
        }
    }

    private func markSelectionChanged() {
        guard case let .loaded(outlook, updatedAt, false) = state else { return }
        withAnimation(.snappy(duration: 0.18)) {
            state = .loaded(outlook, updatedAt: updatedAt, isStale: true)
        }
    }

    private func serverCode(_ error: Error) -> String? {
        if case let APIError.server(code, _) = error {
            return code
        }
        if case let APIError.httpStatus(status) = error {
            return "\(status)"
        }
        return nil
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[MatchOutlook] \(message)")
        #endif
    }
}

private extension String {
    func containsAnyKeyword(in keywords: [String]) -> Bool {
        keywords.contains { keyword in
            range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

private enum MatchOutlookScreenState {
    case idle(String)
    case loading
    case loaded(MatchOutlookResponse, updatedAt: Date, isStale: Bool)
    case error(String)

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
}

private extension DateFormatter {
    static let vfOutlookUpdated: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm 업데이트"
        return formatter
    }()
}

#Preview("경기 전망") {
    NavigationStack {
        MatchOutlookView()
    }
    .environmentObject(UserPreferencesStore.preview(suiteName: "OutlookPreferences"))
    .environmentObject(AppDataStore(preferences: .preview(suiteName: "OutlookAppData")))
}
