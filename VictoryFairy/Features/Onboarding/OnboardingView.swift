import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        TabView(selection: $viewModel.pageIndex) {
            introPage
                .tag(0)
            featurePage
                .tag(1)
            teamPage
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomControls
        }
        .vfScreenBackground()
        .onAppear {
            viewModel.selectedTeamID = preferences.favoriteTeamID
        }
    }

    private var introPage: some View {
        OnboardingPageShell {
            Spacer()
            Image(systemName: "baseball.diamond.bases")
                .font(.system(size: 62, weight: .bold))
                .foregroundStyle(VFColor.grassGreen)
                .frame(width: 104, height: 104)
                .background(VFColor.grassGreen.opacity(0.12))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(spacing: VFSpacing.sm) {
                Text("승리요정")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(VFColor.primaryText)
                    .multilineTextAlignment(.center)
                Text("내 직관 시즌을 기록해보세요")
                    .font(VFTypography.section)
                    .foregroundStyle(VFColor.primaryText)
                    .multilineTextAlignment(.center)
                Text("직접 본 KBO 경기만 모아 나만의 시즌 다이어리를 만들어보세요.")
                    .font(.body)
                    .foregroundStyle(VFColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var featurePage: some View {
        OnboardingPageShell {
            Spacer()
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                featureRow(icon: "rectangle.stack.fill", title: "피드처럼 남기고")
                featureRow(icon: "calendar", title: "캘린더로 돌아보고")
                featureRow(icon: "chart.bar.fill", title: "데이터로 확인해요")
            }
            .frame(maxWidth: .infinity)

            Text("직관한 경기를 카드로 기록하고, 캘린더와 통계로 나만의 야구 시즌을 확인할 수 있어요.")
                .font(.body)
                .foregroundStyle(VFColor.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, VFSpacing.lg)

            Spacer()
        }
    }

    private var teamPage: some View {
        ScrollView {
            VStack(spacing: VFSpacing.lg) {
                TeamSelectionView(selectedTeamID: $viewModel.selectedTeamID, teams: appData.teams)
            }
            .padding(VFSpacing.lg)
            .padding(.top, VFSpacing.lg)
            .padding(.bottom, OnboardingLayout.bottomContentInset)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: VFSpacing.md) {
            PageIndicator(pageCount: 3, currentIndex: viewModel.pageIndex)
                .padding(.bottom, VFSpacing.xs)

            VStack(spacing: VFSpacing.sm) {
                VFPrimaryButton(title: primaryButtonTitle, systemImage: primaryButtonIcon) {
                    if viewModel.pageIndex == 2 {
                        appData.completeOnboarding(favoriteTeamID: viewModel.selectedTeamID)
                    } else {
                        viewModel.moveNext()
                    }
                }

                VFSecondaryButton(title: "건너뛰기", systemImage: "forward.fill") {
                    viewModel.selectedTeamID = nil
                    appData.completeOnboarding(favoriteTeamID: nil)
                }
            }
        }
        .padding(.horizontal, VFSpacing.lg)
        .padding(.top, VFSpacing.lg)
        .padding(.bottom, VFSpacing.lg)
        .background(.ultraThinMaterial)
    }

    private var primaryButtonTitle: String {
        switch viewModel.pageIndex {
        case 0: "시작하기"
        case 1: "다음"
        default: "선택 완료"
        }
    }

    private var primaryButtonIcon: String {
        viewModel.pageIndex == 2 ? "checkmark" : "arrow.right"
    }

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: VFSpacing.md) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(VFColor.grassGreen)
                .frame(width: 48, height: 48)
                .background(VFColor.grassGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(VFColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(VFSpacing.md)
        .background(VFColor.card)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                .stroke(VFColor.mutedLine.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct OnboardingPageShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: VFSpacing.xl) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(VFSpacing.lg)
            .padding(.bottom, OnboardingLayout.bottomContentInset)
        }
        .scrollIndicators(.hidden)
    }
}

private enum OnboardingLayout {
    static let bottomContentInset: CGFloat = 176
}

#Preview("온보딩 소개") {
    let preferences = UserPreferencesStore.preview(suiteName: "OnboardingIntroPreview", hasCompletedOnboarding: false)
    let appData = AppDataStore(preferences: preferences)
    OnboardingView()
        .environmentObject(preferences)
        .environmentObject(appData)
}
