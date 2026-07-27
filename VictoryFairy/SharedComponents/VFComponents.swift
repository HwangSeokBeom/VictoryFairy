import SwiftUI

// 앱 화면들이 함께 쓰는 조합 컴포넌트.
// 형태와 색은 모두 `VFCoreComponents`의 Pencil 컴포넌트와 디자인 토큰에서 온다.

// MARK: - 화면 헤더

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
        HStack(alignment: .top, spacing: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(title)
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(VFTypography.supporting)
                        .foregroundStyle(VFColor.bodySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: VFSpacing.xs)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, VFSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

typealias AppScreenHeader<Trailing: View> = ScreenHeaderView<Trailing>

/// Pencil 홈 헤더의 원형 아이콘 버튼. 종이색 원에 얇은 테두리.
struct HeaderIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: VFIconSize.medium, weight: .medium))
                .foregroundStyle(VFColor.bodySecondary)
                .frame(width: VFControl.minimumTouchTarget, height: VFControl.minimumTouchTarget)
                .background(VFColor.elevatedSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(VFColor.hairline, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - 시즌 선택 시트

struct SeasonPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let seasons: [SeasonOption]
    let selectedSeason: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(seasons) { option in
                        Button {
                            onSelect(option.season)
                            dismiss()
                        } label: {
                            HStack(spacing: VFSpacing.sm) {
                                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                                    Text(option.label)
                                        .font(VFTypography.cardTitle)
                                        .foregroundStyle(VFColor.bodyPrimary)
                                    if option.hasRecords {
                                        Text("기록 있음")
                                            .font(VFTypography.metadata)
                                            .foregroundStyle(VFColor.bodySecondary)
                                    }
                                }
                                Spacer(minLength: VFSpacing.xs)
                                if option.season == selectedSeason {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(VFColor.primaryActionDeep)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, VFSpacing.lg)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .background(option.season == selectedSeason ? VFColor.highlightSurface : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option.season == selectedSeason ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .navigationTitle("시즌 선택")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }
}

// MARK: - 결과 표시

/// 경기 결과를 글자와 색으로 함께 보여준다.
/// 색을 못 보는 환경에서도 승·패·무 글자가 남으므로 의미가 유지된다.
struct ResultBadge: View {
    let result: GameResult
    var scoreText: String?

    private var label: String {
        scoreText.map { "\($0) \(result.title)" } ?? result.title
    }

    var body: some View {
        Text(label)
            .font(Font.system(.caption, design: .default).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(result.color)
            .padding(.horizontal, VFSpacing.sm)
            .padding(.vertical, 5)
            .frame(minHeight: 28)
            .background(result.color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(result.color.opacity(0.35), lineWidth: 1))
            .accessibilityLabel(label)
    }
}

/// 최근 경기 결과를 작은 도장들로 늘어놓는다.
struct RecentResultStrip: View {
    let results: [GameResult]

    var body: some View {
        HStack(spacing: VFSpacing.xxs) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                Text(result.title)
                    .font(Font.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(result.color)
                    .frame(width: 26, height: 26)
                    .background(VFColor.elevatedSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(result.color, lineWidth: 1.3))
                    .accessibilityLabel(result.diaryTitle)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 승리요정 지수

/// Pencil에는 없는 카드지만 앱의 핵심 지표라 종이 언어로 다시 칠해 유지한다.
struct VictoryFairyIndexCard: View {
    let index: String
    let label: String
    let footnote: String
    var aiAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(footnote)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: VFSpacing.xs)
                if let aiAction {
                    Button(action: aiAction) {
                        VFIllustrationView(.sparkle, height: 22)
                            .frame(width: VFControl.minimumTouchTarget, height: VFControl.minimumTouchTarget)
                            .background(VFColor.elevatedSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(VFColor.hairline, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("AI 직관 기록 도우미")
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: VFSpacing.xxs) {
                Text(index)
                    .font(VFTypography.numericEmphasis)
                    .foregroundStyle(VFColor.primaryActionDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("점")
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.highlightSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                .stroke(VFColor.inkOutline.opacity(0.65), lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 지표·순위

struct MetricCard: View {
    let metric: MetricViewState

    var body: some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(metric.title)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metric.value)
                    .font(Font.system(.title3, design: .default).weight(.bold).monospacedDigit())
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metric.detail)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodyTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) \(metric.value)")
        .accessibilityValue(metric.detail)
    }
}

struct StatRankingRow: View {
    let rank: Int
    let item: RankingViewState

    var body: some View {
        HStack(spacing: VFSpacing.sm) {
            Text("\(rank)")
                .font(Font.system(.footnote, design: .default).weight(.bold).monospacedDigit())
                .foregroundStyle(rank == 1 ? VFColor.bodyOnDark : VFColor.bodySecondary)
                .frame(width: 28, height: 28)
                .background(rank == 1 ? VFColor.primaryAction : VFColor.subtleSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(VFColor.inkOutline.opacity(rank == 1 ? 0.7 : 0.2), lineWidth: 1.2))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.subtitle)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: VFSpacing.xs)

            Text(item.trailing)
                .font(VFTypography.numericSupporting)
                .foregroundStyle(VFColor.primaryActionDeep)
        }
        .padding(.vertical, VFSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank)위 \(item.title), \(item.subtitle), \(item.trailing)")
    }
}

// MARK: - 빈 상태

/// Pencil `빈 기록` 패널을 쓰는 화면용 어댑터.
///
/// 시각적 구현은 `VFEmptyStatePanel` 하나뿐이다. 이 타입은 기존 호출부가 쓰던
/// 이름과 인자를 그대로 받아 그쪽으로 넘겨주기만 한다.
struct EmptyStateView: View {
    let title: String
    let message: String
    let buttonTitle: String
    /// 예전 SF Symbol 인자. Pencil 일러스트로 옮기는 동안 호출부 호환을 위해 남긴다.
    var systemImage: String = "baseball"
    var action: () -> Void = {}

    var body: some View {
        VFEmptyStatePanel(
            title: title,
            message: message,
            illustration: Self.illustration(forLegacySymbol: systemImage),
            actionTitle: buttonTitle.isEmpty ? nil : buttonTitle,
            action: buttonTitle.isEmpty ? nil : action
        )
    }

    /// 예전 아이콘 이름을 뜻이 가장 가까운 Pencil 일러스트로 옮긴다.
    static func illustration(forLegacySymbol symbol: String) -> VFIllustration {
        switch symbol {
        case "calendar", "calendar.badge.plus": .ticket
        case "chart.bar", "chart.line.uptrend.xyaxis", "trophy": .pennant
        case "newspaper", "newspaper.fill": .ticket
        case "wifi.slash", "exclamationmark.triangle", "exclamationmark.triangle.fill": .rainCloud
        default: .glove
        }
    }
}

// MARK: - 팀 선택

struct TeamPickerCard: View {
    let title: String
    let selectedTeam: String

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Text(title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: VFSpacing.xs)],
                    spacing: VFSpacing.xs
                ) {
                    ForEach(KBOSeed.teams) { team in
                        let isSelected = team.name == selectedTeam
                        HStack(spacing: VFSpacing.xs) {
                            VFTeamBadge(team: team, size: 26)
                            Text(team.name)
                                .font(VFTypography.supporting)
                                .foregroundStyle(VFColor.bodyPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, VFSpacing.xs)
                        .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
                        .background(isSelected ? VFColor.highlightSurface : VFColor.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                                .stroke(isSelected ? team.accentColor : Color.clear, lineWidth: 1.4)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(team.name)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
            }
        }
    }
}

// MARK: - 페이지 인디케이터

struct PageIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? VFColor.primaryAction : VFColor.hairline)
                    .frame(width: index == currentIndex ? 22 : 8, height: 8)
                    .animation(
                        VFMotion.respectingReduceMotion(VFMotion.selection, reduceMotion: reduceMotion),
                        value: currentIndex
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("온보딩 \(currentIndex + 1) / \(pageCount) 페이지")
    }
}

// MARK: - 데이터 상태 배너

struct DataStateBanner: View {
    let state: RemoteDataState

    var body: some View {
        switch state {
        case .loading:
            statusView(title: "데이터를 불러오는 중이에요", systemImage: "arrow.clockwise", tint: VFColor.primaryActionDeep)
        case .localOnly(let message):
            statusView(title: message, systemImage: "icloud.slash", tint: VFColor.infoAccent)
        case .serverErrorUsingLocal(let message):
            statusView(title: message, systemImage: "icloud.slash", tint: VFColor.infoAccent)
        case .error(let message):
            statusView(title: message, systemImage: "exclamationmark.circle", tint: VFColor.statusError)
        case .empty, .loaded:
            EmptyView()
        }
    }

    private func statusView(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: VFSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: VFIconSize.small, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(VFTypography.metadata)
                .foregroundStyle(VFColor.bodySecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VFSpacing.sm)
        .padding(.vertical, VFSpacing.xs)
        .frame(minHeight: 36)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
