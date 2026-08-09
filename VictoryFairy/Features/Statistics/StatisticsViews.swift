import SwiftUI

/// Pencil `07_Statistics_SeasonArchive` 한 장이 필요로 하는 값.
///
/// 계산은 모두 `StatisticsService`가 한다. 이 타입은 뷰가 아니므로 화면 밖에서
/// 그대로 만들 수 있고, 화면은 여기 담긴 의미 모델을 그리기만 한다.
struct StatisticsViewModel {
    let archive: SeasonArchivePresentation
    let dataState: RemoteDataState
    /// 하위 화면(구장별·상대팀별 통계)이 쓰는 집계. 같은 기록에서 만든다.
    let derived: StatisticsViewState
    /// 리그 순위표. 이 화면이 만들지 않고 서버 응답을 그대로 들고 간다.
    let leagueStandings: StatisticsViewState
    let logs: [AttendanceLogViewState]

    init(
        logs: [AttendanceLogViewState],
        season: Int,
        seasonOptions: [SeasonArchiveOption],
        favoriteTeam: KBOTeam?,
        dataState: RemoteDataState,
        leagueStandings: StatisticsViewState
    ) {
        let service = StatisticsService()
        self.logs = logs
        self.dataState = dataState
        self.leagueStandings = leagueStandings
        derived = service.summary(logs: logs, season: season)
        archive = service.seasonArchive(
            logs: logs,
            season: season,
            seasonOptions: seasonOptions,
            favoriteTeam: favoriteTeam
        )
    }

    static let sample = StatisticsViewModel(
        logs: AttendanceLogSample.logs,
        season: 2026,
        seasonOptions: [SeasonArchiveOption(season: 2026, hasRecords: true)],
        favoriteTeam: KBOSeed.team(id: "lg-twins"),
        dataState: .loaded,
        leagueStandings: .sample
    )
}

/// Pencil `07_Statistics_SeasonArchive`.
///
/// 개인 시즌 아카이브다. 리그 대시보드가 아니라 "내가 이 시즌을 어떻게 보냈는가"를
/// 한 장에 담는다. 화면에 있는 모든 숫자와 문장은 실제 직관 기록에서 나온다.
struct StatisticsView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: StatisticsViewModel
    @State private var isShowingSeasonPicker = false
    @State private var isShowingSeasonReportUnavailable = false

    private var archive: SeasonArchivePresentation { viewModel.archive }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                seasonHeader

                dataStateSection

                if archive.hasRecords {
                    SeasonCoverCard(archive: archive, teamAccent: theme.primary)

                    insufficientDataNotice

                    SeasonResultDistributionView(distribution: archive.distribution)

                    highlightsSection

                    trendSection

                    stadiumSection

                    seasonReportButton
                } else if showsEmptySeason {
                    emptySeasonPanel
                }

                leagueStandingsLink

                fixtureScenarioMarker
            }
            .padding(VFSpacing.md)
            .vfTabContentPadding()
        }
        // 좁은 폭과 큰 글자 검증이 스크롤 컨테이너의 실제 경계를 재야 하므로 루트에도 이름을 둔다.
        .accessibilityIdentifier(StatisticsAccessibilityID.root)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingSeasonPicker) {
            SeasonPickerSheet(
                seasons: archive.seasonOptions,
                selectedSeason: archive.season
            ) { season in
                Task { await appData.selectSeason(season) }
            }
            .presentationDetents([.medium])
        }
        // `SEASON_SHARE_REQUIRES_SEPARATE_PRODUCT_DESIGN`
        // Statistics는 시즌 엔티티만 소유한다. 별도 canonical 시즌 renderer가 생기기 전까지
        // 실제 시즌 값에 샘플 직관 기록을 섞어 내보내지 않고, 정직한 unavailable 상태를 쓴다.
        .alert("시즌 리포트는 준비 중이에요", isPresented: $isShowingSeasonReportUnavailable) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("시즌 전체를 정확히 담는 별도 카드 디자인이 필요해요. 개별 기록은 기록 상세나 피드에서 추억 카드로 공유할 수 있어요.")
        }
        .vfScreenBackground()
    }

    // MARK: - 헤더

    /// Pencil `시즌 헤더`. 화면 제목이 곧 보고 있는 시즌이고, 오른쪽에 시즌 선택 칩이 온다.
    private var seasonHeader: some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(archive.title)
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(StatisticsAccessibilityID.title)
                    .accessibilityAddTraits(.isHeader)

                Text(archive.subtitle)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodyTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(StatisticsAccessibilityID.subtitle)
            }

            Spacer(minLength: VFSpacing.xs)

            seasonSelector
        }
        .padding(.top, VFSpacing.xs)
        .accessibilityElement(children: .contain)
    }

    /// Pencil `시즌 선택` 칩. 종이색 캡슐에 연도와 아래 화살표.
    private var seasonSelector: some View {
        Button {
            isShowingSeasonPicker = true
        } label: {
            HStack(spacing: VFSpacing.xxs) {
                Text(archive.seasonOptions.first { $0.season == archive.season }?.shortLabel
                     ?? String(archive.season))
                    .font(Font.system(.footnote, design: .default).weight(.semibold))
                    .foregroundStyle(VFColor.bodyPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VFColor.bodyTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, VFSpacing.xs)
            .frame(minHeight: VFControl.minimumTouchTarget)
            .background(VFColor.elevatedSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(VFColor.hairline, lineWidth: VFStroke.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(StatisticsAccessibilityID.selectedSeason)
        // 연도를 그대로 보간하면 `LocalizedStringKey`가 숫자로 읽고 자릿수 구분 기호를
        // 붙여 "2,026 시즌"이 된다. 연도는 수량이 아니므로 문자 그대로 읽어야 한다.
        .accessibilityLabel(Text(verbatim: "시즌 선택, \(archive.title)"))
        .accessibilityHint("다른 시즌의 기록을 봅니다")
    }

    // MARK: - 불러오기 상태

    private var isLoading: Bool { viewModel.dataState == .loading }

    private var isRecoverableError: Bool {
        if case .error = viewModel.dataState { return true }
        return false
    }

    /// 기록이 없을 때 빈 안내를 띄울지. 불러오는 중이거나 오류일 때는 그 상태가 먼저다.
    private var showsEmptySeason: Bool { !isLoading && !isRecoverableError }

    /// 복구할 수 있는 오류에는 문구만 띄우지 않고 다시 시도할 방법을 함께 준다.
    /// 다시 불러오는 동안에도 보고 있던 시즌은 그대로 둔다.
    @ViewBuilder
    private var dataStateSection: some View {
        switch viewModel.dataState {
        case .loading:
            VFLoadingPanel(message: "시즌 기록을 불러오는 중이에요")
                .accessibilityIdentifier(StatisticsAccessibilityID.loading)
        case .error(let message):
            VFErrorPanel(
                message: message,
                retryAccessibilityIdentifier: StatisticsAccessibilityID.retry
            ) {
                Task { await appData.refreshContent() }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(StatisticsAccessibilityID.error)
        default:
            DataStateBanner(state: viewModel.dataState)
        }
    }

    /// 표본이 적을 때만 나온다. 승률을 숨기지 않고, 얼마나 믿을 수 있는지 함께 알린다.
    @ViewBuilder
    private var insufficientDataNotice: some View {
        if let message = archive.record.insufficientDataMessage {
            HStack(alignment: .top, spacing: VFSpacing.xs) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: VFIconSize.small, weight: .semibold))
                    .foregroundStyle(VFColor.primaryActionDeep)
                Text(message)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(VFSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VFColor.highlightSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
            .accessibilityIdentifier(StatisticsAccessibilityID.insufficientData)
        }
    }

    // MARK: - 올해의 기록들

    /// Pencil `시즌 기록 섹션`. 네 줄 모두 실제 기록에서 나온다.
    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "올해의 기록들")

            ForEach(archive.highlights) { highlight in
                highlightRow(highlight)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(StatisticsAccessibilityID.highlights)
    }

    @ViewBuilder
    private func highlightRow(_ highlight: SeasonHighlight) -> some View {
        switch highlight.kind {
        // 들어갈 수 있는지(`isDetailReachable`)와 강조할 값이 있는지
        // (`hasHighlightedValue`)를 따로 본다. 예전에는 `isAvailable` 하나가 둘을
        // 겸해서, 값이 없으면 상세 화면 자체가 잠겼다 — 그 화면이 갖고 있던 빈 상태와
        // 기록 추가 동선에 도달할 방법이 사라졌다.
        case .mostVisitedStadium:
            NavigationLink {
                StadiumStatsView(stats: viewModel.derived.stadiumStats)
            } label: {
                SeasonHighlightRow(highlight: highlight, showsDisclosure: highlight.hasHighlightedValue)
            }
            .buttonStyle(.plain)
            .disabled(!highlight.isDetailReachable)
        case .mostFacedOpponent:
            NavigationLink {
                OpponentStatsView(stats: viewModel.derived.opponentStats)
            } label: {
                SeasonHighlightRow(highlight: highlight, showsDisclosure: highlight.hasHighlightedValue)
            }
            .buttonStyle(.plain)
            .disabled(!highlight.isDetailReachable)
        case .longestWinStreak, .largestWinMargin:
            SeasonHighlightRow(highlight: highlight, showsDisclosure: false)
        }
    }

    // MARK: - 월별 직관

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "월별 직관")

            SeasonTrendChart(
                trend: archive.trend,
                usesCompactList: prefersTrendList
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(StatisticsAccessibilityID.trend)
    }

    /// 점을 세로로 쌓는 표현은 칸이 많아지거나 글자가 커지면 읽기 어려워진다.
    /// 그럴 때는 같은 값을 순위 목록으로 보여 준다. 숫자가 더 분명하게 전달된다.
    private var prefersTrendList: Bool {
        dynamicTypeSize.isAccessibilitySize || archive.trend.points.count > 6
    }

    // MARK: - 구장

    /// 기록에 실제로 남은 구장만 센다. 주 관람 구장이나 팀 홈 구장으로 대체하지 않는다.
    private var stadiumSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            // "전체 보기"를 두지 않는다. 이 목록은 기록에 남은 구장을 상위 몇 개로 자르지
            // 않고 **전부** 보여주므로 더 볼 것이 없다. 정렬과 세부 전적이 필요하면
            // `가장 많이 간 구장` 줄에서 구장별 통계로 이어진다.
            VFSectionHeader(title: "구장별 직관")

            if archive.stadiums.isEmpty {
                Text("구장이 적힌 기록이 아직 없어요. 기록에 구장을 남기면 여기에서 함께 볼 수 있어요.")
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(VFSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VFColor.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                            .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
                    )
                    .accessibilityIdentifier(StatisticsAccessibilityID.stadiumAnalysisEmpty)
            } else {
                ForEach(archive.stadiums) { stadium in
                    SeasonStadiumRow(stadium: stadium, rankTint: theme.primary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(StatisticsAccessibilityID.stadiumAnalysis)
    }

    // MARK: - 마무리

    /// Pencil이 저작한 시즌 액션은 유지하되, 한 기록용 jYs0S로 보내지 않는다.
    private var seasonReportButton: some View {
        VFSecondaryButton(title: "시즌 리포트 만들기", systemImage: "square.and.arrow.up") {
            isShowingSeasonReportUnavailable = true
        }
        .accessibilityIdentifier(StatisticsAccessibilityID.seasonReport)
        .accessibilityHint("시즌 전체 카드가 아직 준비되지 않았다는 안내를 엽니다")
    }

    /// Pencil 프레임에는 없다. 기존 제품 기능(리그 순위표)을 지우지 않기 위해
    /// 아카이브 본문 밖의 한 줄로 남긴다.
    private var leagueStandingsLink: some View {
        NavigationLink {
            KBOStandingsView(state: viewModel.leagueStandings)
        } label: {
            HStack(spacing: VFSpacing.sm) {
                Image(systemName: "list.number")
                    .font(.system(size: VFIconSize.medium, weight: .semibold))
                    .foregroundStyle(VFColor.bodySecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("KBO 순위표")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("참고용 리그 순위를 따로 봐요")
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyTertiary)
                }
                Spacer(minLength: VFSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VFColor.bodyTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, VFSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
            .background(VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                    .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(StatisticsAccessibilityID.leagueStandings)
    }

    /// 이 시즌에 기록이 없을 때. 다른 시즌의 값을 끌어와 채우지 않는다.
    private var emptySeasonPanel: some View {
        VFEmptyStatePanel(
            title: "\(archive.title) 기록이 아직 없어요",
            message: emptySeasonMessage,
            illustration: .pennant,
            // Pencil `09_States > 빈 시즌`의 48px 페어리.
            fairy: .emptySeason
        )
        .accessibilityIdentifier(StatisticsAccessibilityID.empty)
    }

    /// 응원 팀을 골랐으면 그 이름까지 부른다. 팀 이름 말고는 아무것도 덧붙이지 않는다.
    private var emptySeasonMessage: String {
        guard let team = archive.team else {
            return "직관 기록을 남기면 이 시즌이 한 장으로 정리돼요."
        }
        return "\(team.name)와 함께한 직관을 남기면 이 시즌이 한 장으로 정리돼요."
    }

    /// UI 테스트가 픽스처 적용 여부를 화면에서 확인하기 위한 표식.
    /// 조용히 제품 상태로 되돌아가면 이 요소가 없으므로 테스트가 실패한다.
    @ViewBuilder
    private var fixtureScenarioMarker: some View {
        if let identifier = VFUITestConfiguration.activeStatisticsScenarioIdentifier {
            // 조회할 수 있는 요소여야 한다. `accessibilityHidden`을 붙이면 접근성 트리에서
            // 통째로 빠져 UI 테스트가 영영 찾지 못한다. 대신 읽을 이름을 비워 둔다.
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(verbatim: ""))
        }
    }
}

// MARK: - 시즌 커버

/// Pencil `시즌 커버`. 남색 카드 한 장에 이번 시즌을 한 문장과 승률로 담는다.
///
/// Pencil 원본은 사람이 쓴 예시 문장("잠실의 기적을 두 눈으로 본 사람")과 전적과 맞지
/// 않는 표본 승률(`.625`)을 보여 준다. 둘 다 제품에 옮기지 않는다. 문장은 실제 전적에서
/// 만들고, 승률은 승 ÷ 승패로 계산한다.
struct SeasonCoverCard: View {
    let archive: SeasonArchivePresentation
    var teamAccent: Color

    private var record: SeasonRecord { archive.record }

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            eyebrow

            Text(archive.headline.text)
                .font(Font.system(.title3, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodyOnDark)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(StatisticsAccessibilityID.headline)

            coverRecord

            // Pencil `커버 반짝`은 커버 왼쪽 아래에 그대로 남는다. 페어리가 이 자리를
            // 대신하지 않는다 — 원본은 둘을 **함께** 둔다.
            VFIllustrationView(.sparkle, height: 22)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, VFSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.deepAccent)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous)
                .stroke(VFColor.inkOutline, lineWidth: 1.4)
        )
        // Pencil `시즌 시그니처 페어리`는 커버 오른쪽 위 모서리에 얹힌다
        // (커버 361×246 안에서 x=297 y=12, 즉 오른쪽 16 · 위 12). 커버 라벨은
        // x=20에서 135폭이라 겹치지 않는다.
        .overlay(alignment: .topTrailing) {
            seasonSignatureFairy
                .padding(.trailing, VFSpacing.md)
                .padding(.top, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(StatisticsAccessibilityID.hero)
    }

    /// Pencil `시즌 시그니처 페어리` — `Fairy48_Victory` 48×48.
    ///
    /// 원본이 이 자리를 **시그니처**라고 이름 붙였다. 같은 컴포넌트를 쓰는 캘린더 쪽은
    /// `선택일 승리 페어리`라고 부르는 것과 대비된다. 즉 이것은 그 시즌이 이겼다는
    /// 신호가 아니라 시즌 커버에 찍는 브랜드 표식이다.
    ///
    /// 그래서 결과에 따라 바꾸지 않고, VoiceOver에서는 숨긴다. 지는 시즌에 "승리"라고
    /// 읽어 주면 계산된 전적과 정면으로 어긋난다. 실제 성적은 헤드라인·승률·전적이
    /// 이미 말하고 있다.
    private var seasonSignatureFairy: some View {
        VFFairyGlyph(.victory, size: .compact)
            .frame(width: VFFairySize.compact.canvas, height: VFFairySize.compact.canvas)
            .accessibilityIdentifier(StatisticsAccessibilityID.seasonCoverFairy)
            .accessibilityHidden(true)
    }

    /// Pencil `커버 라벨`과 응원 팀 표시.
    ///
    /// 한 줄에 나란히 두는 것이 Pencil 배치지만, 큰 글자에서는 팀 이름이 잘린다.
    /// 팀 이름은 이 화면이 누구의 시즌인지 말해 주는 값이라 줄여서는 안 되므로,
    /// 좁아지면 아래로 접어 온전히 보여 준다.
    private var eyebrow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.xs) {
                eyebrowLabel
                if let team = archive.team { teamMark(team, wraps: false) }
            }
            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                eyebrowLabel
                if let team = archive.team { teamMark(team, wraps: true) }
            }
        }
    }

    private var eyebrowLabel: some View {
        Text("이번 시즌을 한 문장으로")
            .font(Font.system(.caption2, design: .default).weight(.semibold))
            .tracking(2)
            .foregroundStyle(VFColor.bodyOnDarkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(StatisticsAccessibilityID.heroEyebrow)
    }

    /// Pencil `커버 전적`. 큰 승률 옆에 라벨과 전적 한 줄.
    /// 좁은 폭과 큰 글자에서는 가로로 나란히 두면 잘리므로 세로로 접는다.
    private var coverRecord: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: VFSpacing.sm) {
                winRateText
                recordColumn
            }
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                winRateText
                recordColumn
            }
        }
    }

    private var winRateText: some View {
        Text(record.winRateText)
            .font(VFTypography.numericDisplay)
            .foregroundStyle(VFColor.attentionAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityIdentifier(StatisticsAccessibilityID.winRate)
            // 읽어 주는 말은 퍼센트로 풀고, 화면에 찍힌 야구식 표기는 값으로 남긴다.
            // 값까지 지워 버리면 화면에 무엇이 보이는지 자동으로 확인할 방법이 사라진다.
            .accessibilityLabel(record.accessibleWinRateText)
            .accessibilityValue(record.winRateText)
    }

    private var recordColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("나의 직관 승률")
                .font(Font.system(.caption2, design: .default))
                .foregroundStyle(VFColor.bodyOnDarkSecondary)
            Text(record.recordText)
                .font(Font.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodyOnDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.accessibleRecordText)
    }

    /// 이 시즌이 누구의 시즌인지 밝힌다. 팀 색은 작은 점에만 쓰고 이름은 글자로 남긴다.
    private func teamMark(_ team: SeasonTeamIdentity, wraps: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Circle()
                .fill(teamAccent)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(VFColor.bodyOnDark.opacity(0.7), lineWidth: 1))
            Text(team.name)
                .font(Font.system(.caption2, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodyOnDark)
                .lineLimit(wraps ? nil : 1)
                .fixedSize(horizontal: false, vertical: wraps)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("응원 팀 \(team.name)")
        .accessibilityIdentifier(team.accessibilityIdentifier)
    }
}

// MARK: - 결과 분포

/// 승·패·무·취소가 각각 얼마나 되는지 한 줄로 보여 준다.
///
/// 도넛 대신 가로 막대를 쓴다. 각 조각의 뜻은 색이 아니라 아래 라벨이 전한다.
/// 막대를 볼 수 없어도 라벨과 요약 문장에 같은 값이 남는다.
struct SeasonResultDistributionView: View {
    let distribution: SeasonResultDistribution

    private let barHeight: CGFloat = 12
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            VFSectionHeader(title: "결과 분포")

            Text("직관 \(distribution.total)경기")
                .font(Font.system(.subheadline, design: .default).weight(.semibold).monospacedDigit())
                .foregroundStyle(VFColor.bodyPrimary)
                .accessibilityIdentifier(StatisticsAccessibilityID.totalAttendance)

            if distribution.isEmpty {
                Text(distribution.summary)
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .accessibilityIdentifier(StatisticsAccessibilityID.distributionSummary)
            } else {
                bar
                legend
                Text(distribution.summary)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodyTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(StatisticsAccessibilityID.distributionSummary)
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(StatisticsAccessibilityID.distribution)
    }

    /// 조각의 비율은 서비스가 이미 계산했다. 여기서는 그 비율을 폭으로 옮기기만 한다.
    private var bar: some View {
        GeometryReader { proxy in
            let spacing = segmentSpacing * CGFloat(max(distribution.shares.count - 1, 0))
            let available = max(proxy.size.width - spacing, 0)
            HStack(spacing: segmentSpacing) {
                ForEach(distribution.shares) { share in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(share.result.color)
                        .frame(width: max(available * share.fraction, 3))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: barHeight)
        .accessibilityHidden(true)
    }

    /// 네 결과를 모두 적는다. 0이어도 빼지 않는다. 없다는 사실도 값이다.
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.sm) { legendItems }
            VStack(alignment: .leading, spacing: VFSpacing.xxs) { legendItems }
        }
    }

    @ViewBuilder
    private var legendItems: some View {
        ForEach(GameResult.allCases) { result in
            let count = distribution.shares.first { $0.result == result }?.count ?? 0
            HStack(spacing: 5) {
                Circle()
                    .fill(result.color)
                    .frame(width: 8, height: 8)
                Text("\(result.title) \(count)")
                    .font(Font.system(.caption, design: .default).weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(result.title) \(count)경기")
            .accessibilityIdentifier(identifier(for: result))
        }
    }

    private func identifier(for result: GameResult) -> String {
        switch result {
        case .win: StatisticsAccessibilityID.wins
        case .loss: StatisticsAccessibilityID.losses
        case .draw: StatisticsAccessibilityID.draws
        case .canceled: StatisticsAccessibilityID.canceled
        }
    }
}

// MARK: - 올해의 기록 한 줄

/// Pencil `기록 행`. 아이콘 하나와 라벨·값 두 줄.
struct SeasonHighlightRow: View {
    let highlight: SeasonHighlight
    var showsDisclosure = false

    var body: some View {
        HStack(spacing: VFSpacing.sm) {
            icon
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.label)
                    .font(Font.system(.caption2, design: .default))
                    .foregroundStyle(VFColor.bodyTertiary)
                Text(highlight.value)
                    .font(Font.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(highlight.hasHighlightedValue ? VFColor.bodyPrimary : VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VFColor.bodyTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, VFSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(highlight.accessibilityLabel)
        .accessibilityIdentifier(highlight.accessibilityIdentifier)
    }

    /// Pencil은 lucide 아이콘을 쓴다. 뜻이 같은 SF Symbol로 옮긴다.
    @ViewBuilder
    private var icon: some View {
        switch highlight.kind {
        case .mostVisitedStadium:
            // 구장은 팀 색과 섞지 않는다. 구장 계열 색(sage)으로 고정한다.
            VFHomePlateGlyph(tint: VFColor.supportAccent)
                .frame(width: 18, height: 16)
        case .mostFacedOpponent:
            Image(systemName: "flag.2.crossed.fill")
                .font(.system(size: VFIconSize.medium, weight: .medium))
                .foregroundStyle(VFColor.bodySecondary)
        case .longestWinStreak:
            Image(systemName: "flame.fill")
                .font(.system(size: VFIconSize.medium, weight: .medium))
                .foregroundStyle(VFColor.gameLive)
        case .largestWinMargin:
            Image(systemName: "bolt.fill")
                .font(.system(size: VFIconSize.medium, weight: .medium))
                .foregroundStyle(VFColor.primaryActionDeep)
        }
    }
}

// MARK: - 월별 직관 차트

/// Pencil `타임라인`. 달마다 간 횟수를 점으로 쌓는다.
///
/// Pencil은 3월부터 9월까지 고정된 일곱 칸을 그리지만, 이 앱에는 시즌 기간을 알려 주는
/// 데이터원이 없다. 그래서 첫 기록이 있는 달부터 마지막 기록이 있는 달까지만 그리고,
/// 그 사이의 빈 달은 빈 점으로 남긴다. 칸이 많거나 글자가 크면 같은 값을 목록으로 바꾼다.
struct SeasonTrendChart: View {
    let trend: SeasonAttendanceTrend
    var usesCompactList = false

    /// 한 칸에 그리는 점의 최대 개수. 넘으면 점 대신 숫자로 말한다.
    private let maxDots = 10

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            if trend.isEmpty {
                Text(trend.summary)
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if usesCompactList {
                monthList
            } else {
                dotColumns
            }

            Text(trend.summary)
                .font(VFTypography.metadata)
                .foregroundStyle(VFColor.bodySecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(StatisticsAccessibilityID.trendSummary)
        }
        .padding(.top, VFSpacing.md)
        .padding(.horizontal, VFSpacing.sm)
        .padding(.bottom, VFSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.highlightSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.inkOutline, lineWidth: VFStroke.hairline)
        )
    }

    private var dotColumns: some View {
        HStack(alignment: .bottom, spacing: VFSpacing.xxs) {
            ForEach(trend.points) { point in
                VStack(spacing: 5) {
                    dots(for: point)
                    Text(point.label)
                        .font(Font.system(.caption2, design: .default).weight(point.count > 0 ? .semibold : .regular))
                        .foregroundStyle(point.count > 0 ? VFColor.bodyPrimary : VFColor.bodyTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(point.accessibilityLabel)
                .accessibilityIdentifier(point.accessibilityIdentifier)
            }
        }
    }

    @ViewBuilder
    private func dots(for point: SeasonAttendancePoint) -> some View {
        if point.count == 0 {
            Circle()
                .fill(VFColor.chartEmptyMark)
                .frame(width: 6, height: 6)
        } else {
            VStack(spacing: VFSpacing.xxs) {
                if point.count > maxDots {
                    Text("\(point.count)")
                        .font(Font.system(.caption2, design: .default).weight(.bold).monospacedDigit())
                        .foregroundStyle(VFColor.bodyPrimary)
                }
                ForEach(0..<min(point.count, maxDots), id: \.self) { _ in
                    Circle()
                        .fill(VFColor.primaryAction)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(VFColor.inkOutline, lineWidth: 1))
                }
            }
        }
    }

    /// 점을 그리기 어려운 상황에서 쓰는 같은 값의 목록.
    private var monthList: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xxs) {
            ForEach(trend.points) { point in
                HStack(spacing: VFSpacing.xs) {
                    Text(point.label)
                        .font(Font.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(point.count > 0 ? VFColor.bodyPrimary : VFColor.bodyTertiary)
                    Spacer(minLength: VFSpacing.xs)
                    Text(point.count == 0 ? "기록 없음" : "\(point.count)번")
                        .font(Font.system(.subheadline, design: .default).weight(.semibold).monospacedDigit())
                        .foregroundStyle(point.count > 0 ? VFColor.bodyPrimary : VFColor.bodyTertiary)
                }
                .padding(.vertical, VFSpacing.xxs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(point.accessibilityLabel)
                .accessibilityIdentifier(point.accessibilityIdentifier)
            }
        }
    }
}

// MARK: - 구장 한 줄

/// 실제 기록에 남은 구장 한 곳. 방문 횟수와 그 구장에서의 전적을 함께 보여 준다.
struct SeasonStadiumRow: View {
    let stadium: SeasonStadiumVisit
    var rankTint: Color

    var body: some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            Text("\(stadium.rank)")
                .font(Font.system(.caption, design: .default).weight(.heavy).monospacedDigit())
                .foregroundStyle(rankTint.vfReadableForegroundColor)
                .frame(width: 26, height: 26)
                .background(rankTint)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(stadium.name)
                    .font(Font.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(stadium.visitsText) 방문 · \(stadium.recordText)")
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(stadium.winRateText)
                .font(Font.system(.subheadline, design: .default).weight(.bold).monospacedDigit())
                .foregroundStyle(VFColor.bodyPrimary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, VFSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stadium.accessibilityLabel)
        .accessibilityIdentifier(stadium.accessibilityIdentifier)
    }
}

// MARK: - 리그 순위표

/// 참고용 KBO 순위표.
///
/// Pencil 시즌 아카이브 프레임에는 없다. 개인 아카이브를 리그 대시보드로 만들지 않으려고
/// 본문에서 빼되, 이미 있던 제품 기능을 지우지 않기 위해 별도 화면으로 남긴다.
struct KBOStandingsView: View {
    let state: StatisticsViewState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                if state.kboSource == .unavailable || state.kboStandings.isEmpty {
                    EmptyKBOStatsPlaceholder(disclosureText: state.kboDisclosureText)
                } else {
                    SourceUpdatedInfoView(
                        sourceText: state.kboSourceText,
                        updatedText: state.kboUpdatedText
                    )
                    if let disclosureText = state.kboDisclosureText {
                        Text(disclosureText)
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                    KBOStandingsTable(items: state.kboStandings)
                }
            }
            .padding(VFSpacing.md)
            .vfTabContentPadding()
        }
        .navigationTitle("KBO 순위표")
        .navigationBarTitleDisplayMode(.inline)
        .vfScreenBackground()
    }
}

struct EmptyKBOStatsPlaceholder: View {
    var disclosureText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(spacing: VFSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(VFColor.deepAccent)
                    .frame(width: 36, height: 36)
                    .background(VFColor.deepAccent.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text("KBO 현재 통계 준비 중")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("데이터가 준비되면 현재 순위가 표시돼요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
            Text("최근 갱신: 갱신일 정보 없음")
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
                .padding(.top, VFSpacing.xs)
            if let disclosureText {
                Text(disclosureText)
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
    }
}

struct SourceUpdatedInfoView: View {
    let sourceText: String?
    let updatedText: String

    var body: some View {
        Text("\(sourceText ?? "참고용 경기 정보") · \(updatedText)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(VFColor.bodyPrimary)
            .lineLimit(2)
            .padding(VFSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }
}

struct KBOStandingsTable: View {
    let items: [KBOStandingViewState]

    var body: some View {
        VStack(spacing: VFSpacing.xs) {
            standingsHeader
            ForEach(items) { item in
                KBOStandingRow(item: item)
            }
        }
    }

    private var standingsHeader: some View {
        HStack(spacing: VFSpacing.sm) {
            Text("순위").frame(width: 34, alignment: .leading)
            Text("팀").frame(maxWidth: .infinity, alignment: .leading)
            Text("전적").frame(width: 64, alignment: .trailing)
            Text("승률").frame(width: 48, alignment: .trailing)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(VFColor.bodySecondary)
        .padding(.bottom, VFSpacing.xs)
    }
}

struct KBOStandingRow: View {
    let item: KBOStandingViewState

    var body: some View {
        HStack(spacing: VFSpacing.sm) {
            Text("\(item.rank)")
                .font(.system(.subheadline, design: .default).weight(.heavy))
                .foregroundStyle(item.rank <= 3 ? VFColor.bodyOnDark : VFColor.deepAccent)
                .frame(width: 32, height: 32)
                .background(item.rank <= 3 ? VFColor.deepAccent : VFColor.subtleSurface)
                .clipShape(Circle())
            Text(item.teamName)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text("\(item.wins)-\(item.losses)-\(item.draws)")
                    .frame(width: 64, alignment: .trailing)
                Text(item.winRateText)
                    .fontWeight(.bold)
                    .frame(width: 48, alignment: .trailing)
            }
            .font(.system(.caption, design: .default).monospacedDigit())
        }
        .foregroundStyle(VFColor.bodyPrimary)
        .padding(VFSpacing.sm)
        .background(VFColor.appBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }
}

// MARK: - 구장별 · 상대팀별 통계 (하위 화면)

struct StadiumStatsView: View {
    @Environment(\.appTheme) private var theme
    let stats: [StatGroupViewState]
    @State private var sort: WinRateRankingSort = .winRate
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                statsSortPicker

                if stats.isEmpty {
                    EmptyStateView(
                        title: "아직 구장별 통계가 없어요.",
                        message: "직관 기록을 추가하면 구장별 성적이 계산돼요.",
                        buttonTitle: "첫 직관 기록하기",
                        systemImage: "mappin.and.ellipse"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, item in
                        DetailedStatCard(rank: index + 1, item: item, rankTint: theme.primary, countTitle: "방문")
                    }
                }
            }
            .padding(VFSpacing.md)
            .vfTabContentPadding()
        }
        .navigationTitle("구장별 통계")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                // 보고 있던 화면이 구장별 통계라고 해서 구장을 미리 채우지 않는다.
                // 어느 구장이었는지는 사용자만 안다 — 1단계에서 직접 고른다.
                RecordCreateFlowView(context: .statisticsStadium())
            }
        }
        .vfScreenBackground()
    }

    private var statsSortPicker: some View {
        Picker("구장 통계 정렬", selection: $sort) {
            ForEach(WinRateRankingSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortedStats: [StatGroupViewState] {
        StatGroupSorter.sorted(stats, by: sort)
    }
}

struct OpponentStatsView: View {
    @Environment(\.appTheme) private var theme
    let stats: [StatGroupViewState]
    @State private var sort: WinRateRankingSort = .winRate
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                statsSortPicker

                if stats.isEmpty {
                    EmptyStateView(
                        title: "아직 상대팀별 통계가 없어요.",
                        message: "직관 기록을 추가하면 상대팀별 성적이 계산돼요.",
                        buttonTitle: "첫 직관 기록하기",
                        systemImage: "person.2"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, item in
                        DetailedStatCard(rank: index + 1, item: item, rankTint: theme.primary, countTitle: "상대")
                    }
                }
            }
            .padding(VFSpacing.md)
            .vfTabContentPadding()
        }
        .navigationTitle("상대팀별 통계")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                // 상대팀도 지어내지 않는다. 1단계에서 직접 고른다.
                RecordCreateFlowView(context: .statisticsOpponent())
            }
        }
        .vfScreenBackground()
    }

    private var statsSortPicker: some View {
        Picker("상대팀 통계 정렬", selection: $sort) {
            ForEach(WinRateRankingSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortedStats: [StatGroupViewState] {
        StatGroupSorter.sorted(stats, by: sort)
    }
}

private struct DetailedStatCard: View {
    let rank: Int
    let item: StatGroupViewState
    let rankTint: Color
    let countTitle: String

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack(alignment: .top, spacing: VFSpacing.sm) {
                    Text("\(rank)")
                        .font(.system(.caption, design: .default).weight(.heavy))
                        .foregroundStyle(rankTint.vfReadableForegroundColor)
                        .frame(width: 28, height: 28)
                        .background(rankTint)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                        Text(item.name)
                            .font(VFTypography.cardTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.latestDateText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                    Spacer()
                    if item.isSmallSample {
                        Text("표본 적음")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(VFColor.primaryActionDeep)
                            .padding(.horizontal, VFSpacing.xs)
                            .frame(minHeight: 24)
                            .background(VFColor.primaryActionPale)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: VFSpacing.sm) {
                    statPill(title: countTitle, value: "\(item.totalGames)경기", detail: "직관 기준", tint: VFColor.deepAccent)
                    statPill(title: "승률", value: item.winRateText, detail: "승패 기준", tint: VFColor.gameWin)
                }

                HStack(spacing: VFSpacing.xs) {
                    resultMiniPill("승", item.wins, VFColor.gameWin)
                    resultMiniPill("패", item.losses, VFColor.gameLoss)
                    resultMiniPill("무", item.draws, VFColor.gameDraw)
                    resultMiniPill("취소", item.canceled, VFColor.gameCanceled)
                }
            }
        }
    }

    private func statPill(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
            Text(value)
                .font(.system(.headline, design: .default).weight(.bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VFSpacing.md)
        .background(VFColor.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private func resultMiniPill(_ title: String, _ count: Int, _ color: Color) -> some View {
        Text("\(title) \(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, VFSpacing.sm)
            .frame(minHeight: 28)
            .background(VFColor.subtleSurface)
            .clipShape(Capsule())
    }
}

private enum StatGroupSorter {
    static func sorted(_ stats: [StatGroupViewState], by sort: WinRateRankingSort) -> [StatGroupViewState] {
        switch sort {
        case .winRate:
            stats.sorted {
                if ($0.winRate ?? -1) != ($1.winRate ?? -1) { return ($0.winRate ?? -1) > ($1.winRate ?? -1) }
                if $0.totalGames != $1.totalGames { return $0.totalGames > $1.totalGames }
                return ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast)
            }
        case .total:
            stats.sorted {
                if $0.totalGames != $1.totalGames { return $0.totalGames > $1.totalGames }
                if ($0.winRate ?? -1) != ($1.winRate ?? -1) { return ($0.winRate ?? -1) > ($1.winRate ?? -1) }
                return ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast)
            }
        case .recent:
            stats.sorted { ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast) }
        }
    }
}

#Preview("시즌 아카이브") {
    NavigationStack {
        StatisticsView(viewModel: .sample)
    }
    .environmentObject(AppDataStore(preferences: UserPreferencesStore.preview(suiteName: "StatisticsPreview")))
}
