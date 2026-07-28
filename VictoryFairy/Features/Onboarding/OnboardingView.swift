import SwiftUI

/// Pencil `04_Onboarding` 프레임의 실제 구현.
///
/// 다섯 단계로 이루어지며 응원 팀과 주 관람 구장은 모두 필수다.
/// 건너뛰기가 없고, 온보딩 중에는 탭바를 띄우지 않는다.
struct OnboardingView: View {
    @EnvironmentObject private var preferences: UserPreferencesStore
    @State private var viewModel = OnboardingViewModel(entry: .firstRun)

    var body: some View {
        VStack(spacing: 0) {
            if let step = viewModel.currentStep {
                content(for: step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: viewModel.stepIndex)
        .onAppear(perform: configureForStoredState)
        .accessibilityIdentifier("onboarding.root")
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

            Spacer(minLength: VFSpacing.md)

            VFPrimaryButton(title: "다음", action: onContinue)
                .accessibilityIdentifier("onboarding.overview.next")
        }
        .padding(.horizontal, VFSpacing.lg)
        .padding(.bottom, VFSpacing.xl)
        .accessibilityIdentifier(OnboardingStep.overview.accessibilityIdentifier)
    }
}

// MARK: - 3단계 · 응원 팀

/// Pencil `Onboarding_03_SelectTeam`. 열 개 구단 중 하나를 반드시 고른다.
private struct OnboardingTeamStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: VFSpacing.sm)]

    var body: some View {
        OnboardingStepScaffold(
            title: "어느 팀을 응원하세요?",
            subtitle: "선택한 팀에 맞춰 화면과 기록이 정리돼요",
            progress: viewModel.progress,
            primaryTitle: "다음",
            isPrimaryEnabled: viewModel.isTeamSelectionValid,
            primaryIdentifier: "onboarding.team.next",
            onPrimary: { viewModel.advance() },
            onBack: viewModel.isFirstStep ? nil : { viewModel.goBack() }
        ) {
            LazyVGrid(columns: columns, spacing: VFSpacing.sm) {
                ForEach(KBOSeed.teams) { team in
                    OnboardingTeamCard(
                        team: team,
                        isSelected: viewModel.selectedTeamID == team.id
                    ) {
                        viewModel.selectTeam(team.id)
                    }
                }
            }
        }
        .accessibilityIdentifier(OnboardingStep.selectTeam.accessibilityIdentifier)
    }
}

/// Pencil `OnboardingTeamCard`. 팀 강조색 링과 이름.
private struct OnboardingTeamCard: View {
    let team: KBOTeam
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VFSpacing.xs) {
                Text(team.badgeInitial)
                    .font(Font.system(size: team.badgeInitial.count > 1 ? 11 : 15, weight: .bold))
                    .foregroundStyle(team.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(team.accentColor, lineWidth: 2))

                VStack(alignment: .leading, spacing: 1) {
                    Text(team.name)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(team.city)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyTertiary)
                }
                Spacer(minLength: 0)

                // 색뿐 아니라 체크 표시로도 선택을 알린다.
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(team.accentColor)
                }
            }
            .padding(VFSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isSelected ? team.accentColor.opacity(0.08) : VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                    .stroke(isSelected ? team.accentColor : VFColor.hairline,
                            lineWidth: isSelected ? 2 : VFStroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.team.\(team.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(team.name)
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
        VStack(spacing: VFSpacing.xl) {
            Spacer()

            VFBrandMark(height: 80)

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

            Spacer()

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
        .accessibilityIdentifier(OnboardingStep.complete.accessibilityIdentifier)
    }
}

// MARK: - 공통 골격

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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: VFSpacing.sm) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
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
                Text("\(progress.current) / \(progress.total)")
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodyTertiary)
                    .accessibilityLabel("\(progress.total)단계 중 \(progress.current)단계")
            }

            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(title)
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, VFSpacing.md)

            ScrollView {
                content
                    .padding(.bottom, VFSpacing.md)
            }

            VFPrimaryButton(title: primaryTitle, isEnabled: isPrimaryEnabled, action: onPrimary)
                .accessibilityIdentifier(primaryIdentifier)
                .padding(.top, VFSpacing.xs)
        }
        .padding(.horizontal, VFSpacing.lg)
        .padding(.bottom, VFSpacing.md)
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
