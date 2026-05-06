import SwiftUI

struct ShareCardPreviewView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: VFSpacing.lg) {
                Text("공유 카드 미리보기")
                    .font(VFTypography.title)
                    .foregroundStyle(VFColor.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                storyCard

                HStack(spacing: VFSpacing.sm) {
                    futureActionLabel("이미지 저장 추후 제공", systemImage: "square.and.arrow.down")
                    futureActionLabel("공유하기 추후 제공", systemImage: "square.and.arrow.up")
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("공유 카드")
        .navigationBarTitleDisplayMode(.inline)
        .vfScreenBackground()
    }

    private var storyCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.gradientStart, theme.secondary.opacity(0.9), theme.gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                HStack {
                    Text("추후 제공")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.secondary)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 28)
                        .background(VFColor.offWhite)
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundStyle(VFColor.offWhite)
                }

                Spacer()

                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    Text("나의 2026 직관 기록")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.86))
                    Text("LG 직관 12경기")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)
                    Text("7승 4패 1무")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.offWhite)
                }

                VStack(spacing: VFSpacing.sm) {
                    shareMetric("승률 63%")
                    shareMetric("승리요정 지수 63")
                    shareMetric("잠실 8회")
                }
            }
            .padding(VFSpacing.xl)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: 360)
        .shadow(color: theme.primary.opacity(0.24), radius: 24, y: 12)
        .accessibilityElement(children: .combine)
    }

    private func shareMetric(_ text: String) -> some View {
        Text(text)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(VFColor.primaryText)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private func futureActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(VFColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(VFColor.mutedLine.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }
}

#Preview("공유 카드 미리보기") {
    NavigationStack {
        ShareCardPreviewView()
    }
}
