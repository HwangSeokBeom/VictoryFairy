import SwiftUI

/// Pencil `04_Onboarding` 프레임의 실제 구현.
///
/// 다섯 단계로 이루어지며 응원 팀과 주 관람 구장은 모두 필수다.
/// 건너뛰기가 없고, 온보딩 중에는 탭바를 띄우지 않는다.
struct OnboardingView: View {
    @EnvironmentObject private var preferences: UserPreferencesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = OnboardingViewModel(entry: .firstRun)

    var body: some View {
        VStack(spacing: 0) {
            if let step = viewModel.currentStep {
                content(for: step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .animation(
            VFMotion.respectingReduceMotion(
                .easeInOut(duration: 0.2),
                reduceMotion: reduceMotion
            ),
            value: viewModel.stepIndex
        )
        .onAppear(perform: configureForStoredState)
        // 여기에 `onboarding.root` 식별자를 두지 않는다.
        //
        // 이 VStack과 단계 컨테이너는 화면 전체를 채우는 같은 크기의 컨테이너라
        // 접근성 트리에서 하나로 합쳐지고, 그때 바깥 식별자가 이긴다. 그래서
        // 루트에 식별자를 붙이면 `onboarding.welcome` 같은 단계 식별자가 통째로
        // 사라진다(측정으로 확인했다).
        //
        // 온보딩 루트는 언제나 다섯 단계 중 하나다. 단계 식별자가 곧 루트 식별자
        // 역할을 하고, 어느 단계인지까지 알려주므로 더 정확하다.
    }

    /// 저장된 값에 맞춰 시작 지점을 다시 잡는다.
    /// 팀과 구장이 모두 있으면 온보딩을 완료로 승격하고 지나간다.
    private func configureForStoredState() {
        let entry = preferences.onboardingEntry
        if entry == .completed {
            preferences.migrateOnboardingIfSatisfied()
            return
        }
        viewModel = OnboardingViewModel(
            entry: entry,
            existingTeamID: preferences.favoriteTeamID,
            existingStadiumID: preferences.primaryStadiumID
        )
    }

    private var backgroundColor: Color {
        switch viewModel.currentStep {
        case .welcome, .complete: VFColor.nightSurface
        default: VFColor.appBackground
        }
    }

    @ViewBuilder
    private func content(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            OnboardingWelcomeView { viewModel.advance() }
        case .overview:
            OnboardingOverviewView { viewModel.advance() }
        case .selectTeam:
            OnboardingTeamStepView(viewModel: viewModel)
        case .selectStadium:
            OnboardingStadiumStepView(viewModel: viewModel)
        case .complete:
            OnboardingCompleteView(viewModel: viewModel, preferences: preferences)
        }
    }
}

// MARK: - 1단계 · 환영

/// Pencil `Onboarding_01_Welcome`. 야간 무대 위 브랜드 마크.
private struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: VFSpacing.xl) {
            Spacer()
            VFBrandMark(height: 96)
            VStack(spacing: VFSpacing.sm) {
                Text("승리요정")
                    .font(Font.system(.largeTitle, design: .default).weight(.heavy))
                    .foregroundStyle(VFColor.bodyOnDark)
                Text("직관한 경기를 기록하고\n나만의 시즌을 모아보세요")
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodyOnDark.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VFPrimaryButton(title: "시작하기", action: onContinue)
                .accessibilityIdentifier("onboarding.welcome.start")
        }
        .padding(.horizontal, VFSpacing.lg)
        .padding(.bottom, VFSpacing.xl)
        // 이 컨테이너는 접근성 요소로 남아 있어야 한다. 요소가 아니면 SwiftUI가
        // 위에서 내려온 식별자를 자식마다 덮어써 단계 식별자와 버튼 식별자가 모두
        // 사라진다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(OnboardingStep.welcome.accessibilityIdentifier)
    }
}

// MARK: - 2단계 · 앱 소개

/// Pencil `Onboarding_02_AppOverview`. 핵심 기능 세 가지를 짧게 소개한다.
private struct OnboardingOverviewView: View {
    let onContinue: () -> Void

    private let highlights: [(illustration: VFIllustration, title: String, detail: String)] = [
        (.ticket, "직관을 기록해요", "날짜와 팀만 고르면 경기 정보가 채워져요."),
        (.pennant, "시즌이 쌓여요", "승률과 구장별 전적을 한눈에 볼 수 있어요."),
        (.stadiumLight, "구장을 기억해요", "자주 가는 구장의 기록이 따로 모여요.")
    ]

    var body: some View {
        // 소개 내용은 스크롤에 싣고 "다음"은 아래에 고정한다. 예전에는 한 덩어리
        // VStack이라 AccessibilityXXXL에서 버튼이 화면 밖(y≈942 / 화면 874)으로
        // 밀려나 스크롤도 되지 않았다 — 다음 단계로 갈 방법이 없었다.
        VStack(alignment: .leading, spacing: VFSpacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.xl) {
                    VStack(alignment: .leading, spacing: VFSpacing.xs) {
                        Text("이렇게 쓰면 돼요")
                            .font(VFTypography.display)
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text("30초면 준비가 끝나요")
                            .font(VFTypography.supporting)
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                    .padding(.top, VFSpacing.xl)

                    VStack(spacing: VFSpacing.sm) {
                        ForEach(highlights, id: \.title) { item in
                            HStack(spacing: VFSpacing.sm) {
                                VFIllustrationView(item.illustration, height: 34)
                                    .frame(width: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(VFTypography.cardTitle)
                                        .foregroundStyle(VFColor.bodyPrimary)
                                    Text(item.detail)
                                        .font(VFTypography.supporting)
                                        .foregroundStyle(VFColor.bodySecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(VFSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VFColor.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                                    .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(item.title), \(item.detail)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            VFPrimaryButton(title: "다음", action: onContinue)
                .accessibilityIdentifier("onboarding.overview.next")
        }
        .padding(.horizontal, VFSpacing.lg)
        .padding(.bottom, VFSpacing.xl)
        // 이 컨테이너는 접근성 요소로 남아 있어야 한다. 요소가 아니면 SwiftUI가
        // 위에서 내려온 식별자를 자식마다 덮어써 단계 식별자와 버튼 식별자가 모두
        // 사라진다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(OnboardingStep.overview.accessibilityIdentifier)
    }
}

// MARK: - 3단계 · 응원 팀

/// Pencil 온보딩 팀 단계의 표현 순서와 반응형 열 규칙.
///
/// 팀의 정체성과 저장 소유권은 계속 `KBOSeed`와 `OnboardingViewModel`에 있다.
/// 이 타입은 `Onboarding_03_SelectTeam_*`, `Onboarding_CompactWidth`,
/// `Onboarding_AccessibilityXXXL`이 그린 **보이는 순서와 열 수**만 담당한다.
enum OnboardingTeamLayout {
    static let visualOrderTeamIDs = [
        "lg-twins", "doosan-bears",
        "samsung-lions", "kia-tigers",
        "ssg-landers", "kt-wiz",
        "nc-dinos", "lotte-giants",
        "kiwoom-heroes", "hanwha-eagles"
    ]

    static func orderedTeams(from teams: [KBOTeam]) -> [KBOTeam] {
        let byID = Dictionary(grouping: teams, by: \.id).compactMapValues(\.first)
        let authored = visualOrderTeamIDs.compactMap { byID[$0] }
        let authoredIDs = Set(authored.map(\.id))

        // 서버 목록이 훗날 늘어나도 Pencil에 없다는 이유로 옵션을 버리지 않는다.
        return authored + teams.filter { !authoredIDs.contains($0.id) }
    }

    static func columnCount(isAccessibilitySize: Bool) -> Int {
        isAccessibilitySize ? 1 : 2
    }
}

/// Pencil `Onboarding_03_SelectTeam`. 열 개 구단 중 하나를 반드시 고른다.
private struct OnboardingTeamStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var teams: [KBOTeam] {
        OnboardingTeamLayout.orderedTeams(from: KBOSeed.teams)
    }

    private var columns: [GridItem] {
        let count = OnboardingTeamLayout.columnCount(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        return (0..<count).map { index in
            GridItem(.flexible(), spacing: index == count - 1 ? 0 : 10)
        }
    }

    /// Pencil `Onboarding_AccessibilityXXXL`은 무제한 시스템 확대가 아니라
    /// 제목 32, 설명 20, 카드 제목 21, 메타 15, CTA 21pt의 별도 배치를 그린다.
    /// 그 크기를 재현해 한 열 목록이 제목에 밀려 쓸 수 없게 되는 것도 막는다.
    private var usesAuthoredAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var titleFont: Font {
        usesAuthoredAccessibilityLayout ? .system(size: 32, weight: .heavy) : VFTypography.display
    }

    private var subtitleFont: Font {
        usesAuthoredAccessibilityLayout ? .system(size: 20) : VFTypography.supporting
    }

    private var primaryFont: Font {
        usesAuthoredAccessibilityLayout ? .system(size: 21, weight: .bold) : VFTypography.button
    }

    var body: some View {
        GeometryReader { proxy in
            OnboardingStepScaffold(
                title: "어느 팀을 응원하시나요?",
                subtitle: "선택한 팀을 기준으로 경기와 기록을 먼저 보여드릴게요.",
                progress: viewModel.progress,
                primaryTitle: viewModel.isTeamSelectionValid
                    ? "이 팀으로 응원할게요"
                    : "응원팀을 선택해 주세요",
                isPrimaryEnabled: viewModel.isTeamSelectionValid,
                primaryIdentifier: "onboarding.team.next",
                onPrimary: { viewModel.advance() },
                onBack: viewModel.isFirstStep ? nil : { viewModel.goBack() },
                progressStyle: .dots,
                backSystemImage: "arrow.left",
                horizontalPadding: proxy.size.width <= 340 ? VFSpacing.md : VFSpacing.xl,
                titleFont: titleFont,
                subtitleFont: subtitleFont,
                primaryFont: primaryFont,
                primaryMinimumHeight: usesAuthoredAccessibilityLayout ? 66 : VFControl.buttonHeight
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(teams) { team in
                            OnboardingTeamCard(
                                team: team,
                                isSelected: viewModel.selectedTeamID == team.id
                            ) {
                                viewModel.selectTeam(team.id)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("onboarding.team.grid")

                    Label("응원팀은 나중에 설정에서 변경할 수 있어요.",
                          systemImage: "info.circle")
                        .font(usesAuthoredAccessibilityLayout ? .system(size: 15) : VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("onboarding.team.note")
                }
            }
        }
        // 이 컨테이너는 접근성 요소로 남아 있어야 한다. 요소가 아니면 SwiftUI가
        // 위에서 내려온 식별자를 자식마다 덮어써 단계 식별자와 버튼 식별자가 모두
        // 사라진다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(OnboardingStep.selectTeam.accessibilityIdentifier)
    }
}

/// Pencil `OnboardingTeamCard`. 팀 강조색 링과 이름.
private struct OnboardingTeamCard: View {
    let team: KBOTeam
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var badgeSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 48 : 36
    }

    private var cardPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? VFSpacing.md : VFSpacing.sm
    }

    private var titleFont: Font {
        dynamicTypeSize.isAccessibilitySize
            ? .system(size: 21, weight: .bold)
            : VFTypography.cardTitle
    }

    private var metadataFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .system(size: 15) : VFTypography.metadata
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(team.badgeInitial)
                    .font(Font.system(
                        size: dynamicTypeSize.isAccessibilitySize
                            ? (team.badgeInitial.count > 1 ? 14 : 19)
                            : (team.badgeInitial.count > 1 ? 11 : 15),
                        weight: .bold
                    ))
                    .foregroundStyle(team.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay(Circle().stroke(team.accentColor, lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(titleFont)
                        .fontWeight(isSelected ? .heavy : .bold)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 3) {
                        Text(team.city)
                            .foregroundStyle(VFColor.bodyTertiary)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VFColor.primaryAction)
                            Text("선택됨")
                                .fontWeight(.bold)
                                .foregroundStyle(VFColor.primaryActionDeep)
                        }
                    }
                    .font(metadataFont)
                }
                Spacer(minLength: 0)
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isSelected ? team.accentColor.opacity(0.08) : VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                    .stroke(isSelected ? team.accentColor : VFColor.hairline,
                            lineWidth: isSelected
                                ? (dynamicTypeSize.isAccessibilitySize ? 2.5 : 2)
                                : VFStroke.hairline)
            )
            .shadow(
                color: isSelected ? VFColor.bodyPrimary.opacity(0.12) : .clear,
                radius: isSelected ? 6 : 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.team.\(team.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isSelected
                ? "\(team.name), \(team.city), 선택됨"
                : "\(team.name), \(team.city)"
        )
        .accessibilityValue(isSelected ? "선택됨" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 4단계 · 주 관람 구장

/// Pencil `Onboarding_04_SelectStadium`. 아홉 개 구장 중 하나를 반드시 고른다.
private struct OnboardingStadiumStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepScaffold(
            title: "주로 어디서 보세요?",
            subtitle: subtitle,
            progress: viewModel.progress,
            primaryTitle: "시작하기",
            isPrimaryEnabled: viewModel.isStadiumSelectionValid,
            primaryIdentifier: "onboarding.stadium.next",
            onPrimary: { viewModel.advance() },
            onBack: viewModel.isFirstStep ? nil : { viewModel.goBack() }
        ) {
            VStack(spacing: VFSpacing.xs) {
                ForEach(viewModel.orderedStadiums) { stadium in
                    OnboardingStadiumCard(
                        stadium: stadium,
                        isRecommended: stadium.id == viewModel.recommendedStadium?.id,
                        isSelected: viewModel.selectedStadiumID == stadium.id
                    ) {
                        viewModel.selectStadium(stadium.id)
                    }
                }
            }
        }
        // 이 컨테이너는 접근성 요소로 남아 있어야 한다. 요소가 아니면 SwiftUI가
        // 위에서 내려온 식별자를 자식마다 덮어써 단계 식별자와 버튼 식별자가 모두
        // 사라진다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(OnboardingStep.selectStadium.accessibilityIdentifier)
    }

    private var subtitle: String {
        if let team = KBOSeed.team(id: viewModel.selectedTeamID) {
            return "\(team.name)의 홈 구장을 맨 위에 두었어요"
        }
        return "가장 자주 가는 구장을 골라주세요"
    }
}

/// Pencil `OnboardingStadiumCard`. 구장 그래픽과 이름, 추천 표시.
private struct OnboardingStadiumCard: View {
    let stadium: KBOStadium
    let isRecommended: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VFSpacing.sm) {
                VFStadiumGlyph(stadiumID: stadium.id)
                    .frame(width: 52, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stadium.name)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: VFSpacing.xxs) {
                        Text(stadium.city)
                            .font(VFTypography.metadata)
                            .foregroundStyle(VFColor.bodyTertiary)
                        if isRecommended {
                            Text("홈 구장")
                                .font(Font.system(.caption2, design: .default).weight(.bold))
                                .foregroundStyle(VFColor.primaryActionDeep)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(VFColor.primaryActionPale)
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VFColor.primaryActionDeep)
                }
            }
            .padding(.horizontal, VFSpacing.sm)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .background(isSelected ? VFColor.primaryActionPale.opacity(0.5) : VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                    .stroke(isSelected ? VFColor.primaryActionDeep : VFColor.hairline,
                            lineWidth: isSelected ? 2 : VFStroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.stadium.\(stadium.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRecommended ? "\(stadium.name), 홈 구장" : stadium.name)
        .accessibilityValue(isSelected ? "선택됨" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 5단계 · 완료

/// Pencil `Onboarding_05_Complete`와 `Onboarding_Error_SaveFailed`.
private struct OnboardingCompleteView: View {
    @Bindable var viewModel: OnboardingViewModel
    let preferences: UserPreferencesStore

    private var team: KBOTeam? { KBOSeed.team(id: viewModel.selectedTeamID) }
    private var stadium: KBOStadium? { KBOStadiumSeed.stadium(id: viewModel.selectedStadiumID) }

    var body: some View {
        // 완료 내용은 스크롤에 싣고 CTA는 아래에 고정한다. 96px 페어리 두 개가
        // 들어오면서 AccessibilityXXXL에서 세로가 모자랄 수 있어, 큰 글자에서도
        // "승리요정 시작하기"에 반드시 닿을 수 있게 한다.
        VStack(spacing: VFSpacing.md) {
            ScrollView {
                VStack(spacing: VFSpacing.xl) {
                    Spacer(minLength: VFSpacing.xl)

                    VFBrandMark(height: 80)

                    // Pencil `Onboarding_05_Complete`의 두 페어리.
                    //
                    // 원본은 `선택 확인` 안에 삼성 팀 페어리를, 프레임에 성공 페어리를 그려 두었다.
                    // 삼성은 원본 표본이므로 옮기지 않는다 — **실제로 고른 팀**으로 그린다.
                    // 팀을 아직 모르면 중립 페어리가 된다.
                    //
                    // 둘 다 VoiceOver에서는 숨긴다. 아래 "준비됐어요"와 팀·구장 이름이 이미
                    // 완료와 선택을 말하고 있어서, 페어리까지 읽으면 같은 말을 두 번 한다.
                    HStack(spacing: VFSpacing.lg) {
                        VFTeamFairy(teamID: viewModel.selectedTeamID)
                            .frame(
                                width: VFTeamFairySize.regular.canvas,
                                height: VFTeamFairySize.regular.canvas
                            )
                            .accessibilityIdentifier("onboarding.complete.teamFairy")
                            .accessibilityHidden(true)

                        VFFairyGlyph(.success)
                            .frame(width: VFFairySize.regular.canvas, height: VFFairySize.regular.canvas)
                            .accessibilityIdentifier("onboarding.complete.successFairy")
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: VFSpacing.sm) {
                        Text("준비됐어요")
                            .font(Font.system(.title, design: .default).weight(.heavy))
                            .foregroundStyle(VFColor.bodyOnDark)

                        if let team, let stadium {
                            Text("\(team.name) · \(stadium.name)")
                                .font(VFTypography.body)
                                .foregroundStyle(VFColor.bodyOnDark.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("설정에서 언제든 바꿀 수 있어요")
                            .font(VFTypography.metadata)
                            .foregroundStyle(VFColor.bodyOnDark.opacity(0.55))
                    }

                    if let message = viewModel.saveErrorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                            Text(message)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(VFTypography.supporting)
                        .foregroundStyle(VFColor.statusError)
                        .padding(VFSpacing.sm)
                        .background(VFColor.statusError.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        .accessibilityIdentifier("onboarding.complete.error")
                    }

                    Spacer(minLength: VFSpacing.md)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            VFPrimaryButton(title: "승리요정 시작하기") {
                viewModel.complete(preferences: preferences)
            }
            .accessibilityIdentifier("onboarding.complete.finish")

            Button("이전으로") { viewModel.goBack() }
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodyOnDark.opacity(0.6))
                .frame(minHeight: VFControl.minimumTouchTarget)
        }
        .padding(.horizontal, VFSpacing.lg)
        .padding(.bottom, VFSpacing.md)
        // 이 컨테이너는 접근성 요소로 남아 있어야 한다. 요소가 아니면 SwiftUI가
        // 위에서 내려온 식별자를 자식마다 덮어써 단계 식별자와 버튼 식별자가 모두
        // 사라진다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(OnboardingStep.complete.accessibilityIdentifier)
    }
}

// MARK: - 공통 골격

private enum OnboardingProgressStyle {
    case count
    case dots
}

/// 선택 단계가 공유하는 배치: 진행 표시 + 제목 + 스크롤 목록 + 하단 고정 버튼.
private struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let progress: (current: Int, total: Int)
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    let primaryIdentifier: String
    let onPrimary: () -> Void
    var onBack: (() -> Void)?
    var progressStyle: OnboardingProgressStyle = .count
    var backSystemImage = "chevron.left"
    var horizontalPadding = VFSpacing.lg
    var titleFont = VFTypography.display
    var subtitleFont = VFTypography.supporting
    var primaryFont = VFTypography.button
    var primaryMinimumHeight = VFControl.buttonHeight
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: VFSpacing.sm) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: backSystemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(VFColor.bodySecondary)
                            .frame(width: VFControl.minimumTouchTarget,
                                   height: VFControl.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이전")
                    .accessibilityIdentifier("onboarding.back")
                }
                Spacer()

                HStack(spacing: VFSpacing.sm) {
                    if progressStyle == .dots {
                        HStack(spacing: 6) {
                            ForEach(1...max(progress.total, 1), id: \.self) { step in
                                Capsule()
                                    .fill(progressColor(for: step))
                                    .frame(width: step == progress.current ? 18 : 6, height: 6)
                            }
                        }
                    }

                    Text("\(progress.current) / \(progress.total)")
                        .font(VFTypography.metadata.monospacedDigit())
                        .foregroundStyle(VFColor.bodyTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(progress.total)단계 중 \(progress.current)단계")
                .accessibilityIdentifier("onboarding.progress")
            }
            .frame(minHeight: 48)

            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, VFSpacing.md)

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, VFSpacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("onboarding.scroll")

            VFPrimaryButton(
                title: primaryTitle,
                isEnabled: isPrimaryEnabled,
                labelFont: primaryFont,
                minimumHeight: primaryMinimumHeight,
                action: onPrimary
            )
                .accessibilityIdentifier(primaryIdentifier)
                .padding(.top, VFSpacing.xs)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, VFSpacing.md)
    }

    private func progressColor(for step: Int) -> Color {
        if step == progress.current { return VFColor.primaryAction }
        if step < progress.current { return VFColor.onboardingProgressCompleted }
        return VFColor.onboardingProgressUpcoming
    }
}

// MARK: - 프리뷰

#Preview("온보딩 · 첫 실행") {
    let preferences = UserPreferencesStore.preview(
        suiteName: "OnboardingFirstRunPreview",
        hasCompletedOnboarding: false
    )
    OnboardingView().environmentObject(preferences)
}

#Preview("온보딩 · 기존 사용자 구장 보완") {
    let preferences = UserPreferencesStore.preview(
        suiteName: "OnboardingRepairPreview",
        hasCompletedOnboarding: true,
        favoriteTeamID: "lg-twins"
    )
    OnboardingView().environmentObject(preferences)
}

#Preview("온보딩 · AccessibilityXXXL") {
    let preferences = UserPreferencesStore.preview(
        suiteName: "OnboardingXXXLPreview",
        hasCompletedOnboarding: false
    )
    OnboardingView()
        .environmentObject(preferences)
        .environment(\.dynamicTypeSize, .accessibility3)
}
