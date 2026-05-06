import SwiftUI

struct ScreenHeaderView<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(title)
                    .font(VFTypography.title)
                    .foregroundStyle(VFColor.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: VFSpacing.sm)
            trailing
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
        .padding(.top, VFSpacing.xs)
    }
}

struct HeaderIconButton: View {
    @Environment(\.appTheme) private var theme
    let systemImage: String
    let accessibilityLabel: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(theme.primary)
                .frame(width: 44, height: 44)
                .background(VFColor.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(VFColor.mutedLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ResultBadge: View {
    let result: GameResult
    var scoreText: String?

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            Circle()
                .fill(result.color)
                .frame(width: 8, height: 8)
            Text(scoreText.map { "\($0) \(result.title)" } ?? result.title)
                .font(.system(.caption, design: .rounded).weight(.bold))
        }
        .foregroundStyle(result.color)
        .padding(.horizontal, VFSpacing.sm)
        .frame(minHeight: 30)
        .background(result.color.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel(scoreText.map { "\($0) \(result.title)" } ?? result.title)
    }
}

struct VictoryFairyIndexCard: View {
    @Environment(\.appTheme) private var theme
    let index: String
    let label: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("승리요정 지수")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(label)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(VFColor.offWhite)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }

            HStack(alignment: .lastTextBaseline, spacing: VFSpacing.sm) {
                Text(index)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                Text("점")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(footnote)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, VFSpacing.sm)
                    .frame(minHeight: 30)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(VFSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [theme.gradientStart, theme.secondary.opacity(0.9), theme.gradientEnd.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
        .shadow(color: theme.primary.opacity(0.22), radius: 18, y: 10)
    }
}

struct MetricCard: View {
    let metric: MetricViewState

    var body: some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                Text(metric.title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(VFColor.secondaryText)
                Text(metric.value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(VFColor.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(metric.detail)
                    .font(.caption)
                    .foregroundStyle(VFColor.secondaryText)
            }
        }
    }
}

struct RecentResultStrip: View {
    let results: [GameResult]

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                Text(result.title)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(result.color)
                    .clipShape(Circle())
                    .accessibilityLabel(result.title)
            }
        }
    }
}

struct StatRankingRow: View {
    @Environment(\.appTheme) private var theme
    let rank: Int
    let item: RankingViewState

    var body: some View {
        HStack(spacing: VFSpacing.md) {
            Text("\(rank)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(rank == 1 ? theme.textOnPrimary : .white)
                .frame(width: 32, height: 32)
                .background(rank == 1 ? theme.primary : VFColor.scoreboardNavy)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(item.title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
            }

            Spacer()

            Text(item.trailing)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.primary)
        }
        .padding(.vertical, VFSpacing.xs)
    }
}

struct EmptyStateView: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let message: String
    let buttonTitle: String
    var systemImage: String = "baseball"
    var action: () -> Void = {}

    var body: some View {
        VFCard(padding: VFSpacing.xl) {
            VStack(spacing: VFSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 58, height: 58)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
                    .multilineTextAlignment(.center)
                VFPrimaryButton(title: buttonTitle, systemImage: "plus", action: action)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TeamPickerCard: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let selectedTeam: String

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text(title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
                    ForEach(KBOSeed.teams) { team in
                        Text(team.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(team.name == selectedTeam ? theme.textOnPrimary : VFColor.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(team.name == selectedTeam ? theme.primary : VFColor.offWhite)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                    }
                }
            }
        }
    }
}

struct PageIndicator: View {
    @Environment(\.appTheme) private var theme
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? theme.primary : VFColor.mutedLine)
                    .frame(width: index == currentIndex ? 22 : 8, height: 8)
                    .animation(.snappy(duration: 0.2), value: currentIndex)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20)
        .accessibilityLabel("온보딩 \(currentIndex + 1) / \(pageCount) 페이지")
    }
}

struct DataStateBanner: View {
    @Environment(\.appTheme) private var theme
    let state: RemoteDataState

    var body: some View {
        switch state {
        case .loading:
            statusView(title: "데이터를 불러오는 중이에요", systemImage: "arrow.clockwise", tint: theme.primary)
        case .localOnly(let message):
            statusView(title: message, systemImage: "wifi.slash", tint: VFColor.drawGray)
        case .serverErrorUsingLocal(let message):
            statusView(title: message, systemImage: "wifi.slash", tint: VFColor.drawGray)
        case .error(let message):
            statusView(title: message, systemImage: "exclamationmark.triangle.fill", tint: VFColor.lossRed)
        case .empty, .loaded:
            EmptyView()
        }
    }

    private func statusView(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: VFSpacing.sm) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(VFColor.secondaryText)
            Spacer()
        }
        .padding(.horizontal, VFSpacing.md)
        .frame(minHeight: 36)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
    }
}
