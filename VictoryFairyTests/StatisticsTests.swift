import XCTest
@testable import VictoryFairy

/// 시즌 아카이브의 계산이 실제 기록과 맞는지 확인한다.
///
/// 화면 없이 값만 본다. Pencil이 예시로 적어 둔 숫자가 아니라, 넘긴 기록에서 나와야 할
/// 값을 직접 계산해 비교한다.
final class StatisticsTests: XCTestCase {

    private let service = StatisticsService()
    private let calendar = StatisticsService.referenceCalendar()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 18
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        return components.date!
    }

    private func log(
        _ seed: Int,
        _ month: Int,
        _ day: Int,
        _ result: GameResult,
        ours: Int? = nil,
        theirs: Int? = nil,
        matchup: String = "삼성 vs LG",
        stadium: String = "잠실야구장",
        year: Int = 2026
    ) -> AttendanceLogViewState {
        let value = date(year, month, day)
        return AttendanceLogViewState(
            id: UUID(uuidString: String(format: "AAAAAAAA-0000-4000-8000-%012d", seed))!,
            date: value,
            dateText: DateFormatter.vfDisplayDate.string(from: value),
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ours,
            opponentScore: theirs,
            seat: "",
            companion: "",
            memo: "",
            caption: "",
            diary: "",
            tags: [],
            photoLocalRefs: []
        )
    }

    private func archive(
        _ logs: [AttendanceLogViewState],
        season: Int = 2026,
        teamID: String? = "samsung-lions",
        options: [SeasonArchiveOption] = []
    ) -> SeasonArchivePresentation {
        service.seasonArchive(
            logs: logs,
            season: season,
            seasonOptions: options,
            favoriteTeam: KBOSeed.team(id: teamID)
        )
    }

    // MARK: - 1. 전적 합계

    func testResultTotalsMatchTheRecords() {
        let logs = VFStatisticsFixtures.referenceLogs
        let record = archive(logs).record
        XCTAssertEqual(record.totalGames, 8)
        XCTAssertEqual(record.wins, 5)
        XCTAssertEqual(record.losses, 2)
        XCTAssertEqual(record.draws, 1)
        XCTAssertEqual(record.canceled, 0)
        XCTAssertEqual(record.wins + record.losses + record.draws + record.canceled, logs.count)
    }

    // MARK: - 2. 승률 분모 규칙

    /// 승률의 분모는 승 + 패다. 무승부와 취소는 들어가지 않는다.
    func testWinRateDenominatorExcludesDrawsAndCancellations() {
        let logs = [
            log(1, 4, 1, .win, ours: 3, theirs: 1),
            log(2, 4, 2, .win, ours: 4, theirs: 2),
            log(3, 4, 3, .loss, ours: 1, theirs: 5),
            log(4, 4, 4, .draw, ours: 2, theirs: 2),
            log(5, 4, 5, .canceled)
        ]
        let record = archive(logs).record
        XCTAssertEqual(record.totalGames, 5, "취소도 직관 횟수에는 들어간다")
        XCTAssertEqual(record.decidedGames, 3, "무승부와 취소가 분모에 들어갔다")
        XCTAssertEqual(record.winRate, 2.0 / 3.0)
        XCTAssertEqual(record.winRateText, ".667")
    }

    /// Pencil은 5승 2패 1무 옆에 `.625`를 적어 두었지만 그 값은 자기 전적과 맞지 않는다.
    /// 제품은 규칙대로 계산한다.
    func testReferenceSeasonWinRateFollowsTheRuleNotThePencilSample() {
        let record = archive(VFStatisticsFixtures.referenceLogs).record
        XCTAssertEqual(record.winRateText, ".714")
        XCTAssertNotEqual(record.winRateText, ".625", "Pencil 표본 값이 제품 계산을 덮어썼다")
    }

    func testWinRateTextUsesBaseballFormatAndDropsLeadingZero() {
        XCTAssertEqual(archive([log(1, 4, 1, .win)]).record.winRateText, "1.000")
        XCTAssertEqual(archive([log(1, 4, 1, .loss)]).record.winRateText, ".000")
    }

    // MARK: - 3. 승패가 없을 때

    func testUndecidedSeasonReportsNoWinRateInsteadOfZero() {
        let record = archive([log(1, 4, 1, .draw), log(2, 4, 2, .draw)]).record
        XCTAssertNil(record.winRate, "승패가 없는데 승률이 0으로 계산됐다")
        XCTAssertEqual(record.winRateText, "—")
        XCTAssertEqual(record.confidence, .undecided)
        XCTAssertNotNil(record.insufficientDataMessage)
    }

    /// 취소만 있는 시즌은 "경기가 열리지 않았다"고 말한다. 0승 0패로 뭉개지 않는다.
    func testCancelledOnlySeasonIsHonest() {
        let result = archive([log(1, 4, 1, .canceled), log(2, 4, 2, .canceled)])
        XCTAssertEqual(result.record.totalGames, 2)
        XCTAssertEqual(result.record.canceled, 2)
        XCTAssertNil(result.record.winRate)
        XCTAssertEqual(result.headline.kind, .canceledOnly)
        XCTAssertTrue(result.record.insufficientDataMessage?.contains("경기가 열리지 않아") == true)
    }

    // MARK: - 4. 빈 시즌과 한 건

    func testZeroRecordsProduceSafeEmptyValues() {
        let result = archive([])
        XCTAssertFalse(result.hasRecords)
        XCTAssertEqual(result.record, .empty)
        XCTAssertEqual(result.headline.kind, .noRecords)
        XCTAssertTrue(result.distribution.isEmpty)
        XCTAssertTrue(result.trend.isEmpty)
        XCTAssertTrue(result.stadiums.isEmpty)
        XCTAssertNil(result.record.insufficientDataMessage, "기록이 없는데 표본 경고가 떴다")
        XCTAssertEqual(result.record.winRateText, "—")
        XCTAssertTrue(result.highlights.allSatisfy { !$0.isAvailable })
    }

    func testOneRecordProducesSafeValues() {
        let result = archive([log(1, 4, 12, .win, ours: 6, theirs: 3)])
        XCTAssertEqual(result.record.totalGames, 1)
        XCTAssertEqual(result.headline.kind, .firstRecord)
        XCTAssertTrue(result.headline.text.contains("잠실야구장"), "한 건일 때 실제 구장을 부르지 않는다")
        XCTAssertEqual(result.trend.points.count, 1, "한 점짜리 흐름이 무너졌다")
        XCTAssertEqual(result.trend.points.first?.count, 1)
        XCTAssertEqual(result.stadiums.count, 1)
        XCTAssertEqual(result.distribution.shares.count, 1)
        XCTAssertEqual(result.distribution.shares.first?.fraction, 1)
    }

    // MARK: - 5. 결정성

    func testArchiveIsDeterministicUnderReordering() {
        let logs = VFStatisticsFixtures.referenceLogs
        let forward = archive(logs)
        let reversed = archive(logs.reversed())
        XCTAssertEqual(forward, reversed, "기록을 넣는 순서에 따라 결과가 달라진다")
    }

    func testArchiveIsDeterministicAcrossRepeatedCalls() {
        let logs = VFStatisticsFixtures.referenceLogs
        XCTAssertEqual(archive(logs), archive(logs))
    }

    /// 같은 날 기록도 하나로 합쳐지지 않는다.
    func testSameDayRecordsArePreserved() {
        let logs = [
            log(1, 4, 12, .win, ours: 3, theirs: 1),
            log(2, 4, 12, .loss, ours: 1, theirs: 3)
        ]
        let result = archive(logs)
        XCTAssertEqual(result.record.totalGames, 2)
        XCTAssertEqual(result.trend.points.first?.count, 2)
        XCTAssertEqual(result.record.wins, 1)
        XCTAssertEqual(result.record.losses, 1)
    }

    // MARK: - 6. 문장

    func testHeadlineIsDeterministicAndDerivedFromRealNumbers() {
        let result = archive(VFStatisticsFixtures.referenceLogs)
        XCTAssertEqual(result.headline.kind, .winning)
        XCTAssertEqual(result.headline.text, "7번 중 5번을 이긴 시즌")
        XCTAssertEqual(result.headline, archive(VFStatisticsFixtures.referenceLogs).headline)
    }

    func testHeadlineCoversEveryBranchWithoutInventingFacts() {
        let cases: [(logs: [AttendanceLogViewState], kind: SeasonHeadline.Kind)] = [
            ([], .noRecords),
            ([log(1, 4, 1, .canceled), log(2, 4, 2, .canceled)], .canceledOnly),
            ([log(1, 4, 1, .win, ours: 2, theirs: 1)], .firstRecord),
            ([log(1, 4, 1, .draw), log(2, 4, 2, .draw)], .undecided),
            ([log(1, 4, 1, .win), log(2, 4, 2, .loss)], .insufficient),
            ([log(1, 4, 1, .win), log(2, 4, 2, .win), log(3, 4, 3, .loss)], .winning),
            ([log(1, 4, 1, .win), log(2, 4, 2, .win), log(3, 4, 3, .loss), log(4, 4, 4, .loss)], .even),
            ([log(1, 4, 1, .win), log(2, 4, 2, .loss), log(3, 4, 3, .loss), log(4, 4, 4, .loss)], .losing)
        ]
        for (logs, expected) in cases {
            XCTAssertEqual(archive(logs).headline.kind, expected, "\(expected) 분기가 나오지 않았다")
        }
        XCTAssertEqual(Set(SeasonHeadline.Kind.allCases), Set(cases.map(\.kind)),
                       "검사하지 않은 문장 분기가 있다")
    }

    // MARK: - 7. 결과 분포

    func testDistributionFractionsSumToOneAndCarryLabels() {
        let distribution = archive(VFStatisticsFixtures.referenceLogs).distribution
        XCTAssertEqual(distribution.total, 8)
        XCTAssertEqual(distribution.shares.map(\.result), [.win, .loss, .draw])
        XCTAssertEqual(distribution.shares.reduce(0) { $0 + $1.fraction }, 1, accuracy: 0.0001)
        XCTAssertEqual(distribution.shares.map(\.label), ["승 5", "패 2", "무 1"])
        XCTAssertTrue(distribution.summary.contains("전체 8경기"))
    }

    func testDistributionIsSafeWithNoData() {
        let distribution = archive([]).distribution
        XCTAssertTrue(distribution.isEmpty)
        XCTAssertTrue(distribution.shares.isEmpty)
        XCTAssertFalse(distribution.summary.isEmpty, "빈 상태에서도 읽어 줄 문장은 남아야 한다")
    }

    // MARK: - 8. 월별 흐름

    func testTrendSpansTheRecordedMonthsAndKeepsInteriorGaps() {
        let logs = [
            log(1, 3, 20, .win),
            log(2, 6, 10, .loss)
        ]
        let trend = archive(logs).trend
        XCTAssertEqual(trend.points.map(\.month), [3, 4, 5, 6])
        XCTAssertEqual(trend.points.map(\.count), [1, 0, 0, 1], "빈 달이 사라졌다")
        XCTAssertEqual(trend.totalCount, 2)
        XCTAssertEqual(trend.maxCount, 1)
    }

    func testReferenceTrendMatchesTheRecordedMonths() {
        let trend = archive(VFStatisticsFixtures.referenceLogs).trend
        XCTAssertEqual(trend.points.map(\.month), [3, 4])
        XCTAssertEqual(trend.points.map(\.count), [3, 5])
        XCTAssertEqual(trend.busiestPoint?.month, 4)
    }

    func testTrendExposesASemanticSummaryInEveryShape() {
        XCTAssertEqual(archive([]).trend.summary, "아직 월별 기록이 없어요")
        let single = archive([log(1, 4, 12, .win)]).trend
        XCTAssertEqual(single.summary, "4월에 1번 직관했어요")
        let many = archive(VFStatisticsFixtures.referenceLogs).trend
        XCTAssertTrue(many.summary.contains("3월부터 4월까지"))
        XCTAssertTrue(many.summary.contains("가장 많았던 달은 4월"))
    }

    func testEveryTrendPointCarriesAnIdentifierAndSpokenValue() {
        for point in archive(VFStatisticsFixtures.referenceLogs).trend.points {
            XCTAssertEqual(point.accessibilityIdentifier, "statistics.trend.month.\(point.month)")
            XCTAssertFalse(point.accessibilityLabel.contains("statistics."),
                           "읽어 주는 문장에 내부 식별자가 섞였다")
        }
    }

    // MARK: - 9. 올해의 기록들

    func testHighlightsComeFromTheRecordsNotFromPencilSamples() {
        let highlights = archive(VFStatisticsFixtures.referenceLogs).highlights
        let byKind = Dictionary(uniqueKeysWithValues: highlights.map { ($0.kind, $0) })
        XCTAssertEqual(byKind[.mostVisitedStadium]?.value, "대구 삼성 라이온즈 파크 · 5번")
        XCTAssertEqual(byKind[.mostFacedOpponent]?.value, "KIA 타이거즈 · 3번")
        XCTAssertEqual(byKind[.longestWinStreak]?.value, "4월 · 3연승")
        XCTAssertEqual(byKind[.largestWinMargin]?.value, "4월 12일 · 9-1")
        XCTAssertTrue(highlights.allSatisfy(\.isAvailable))
        XCTAssertEqual(Set(highlights.map(\.kind)), Set(SeasonHighlight.Kind.allCases))
    }

    /// 무승부와 취소는 연승을 끊지도 잇지도 않는다. 승패만 이어서 본다.
    func testWinStreakSkipsDrawsAndCancellations() {
        let logs = [
            log(1, 4, 1, .win),
            log(2, 4, 2, .draw),
            log(3, 4, 3, .win),
            log(4, 4, 4, .canceled),
            log(5, 4, 5, .win),
            log(6, 4, 6, .loss)
        ]
        let streak = archive(logs).highlights.first { $0.kind == .longestWinStreak }
        XCTAssertEqual(streak?.value, "4월 · 3연승")
    }

    func testSingleWinIsNotReportedAsAStreak() {
        let streak = archive([log(1, 4, 1, .win), log(2, 4, 2, .loss)])
            .highlights.first { $0.kind == .longestWinStreak }
        XCTAssertEqual(streak?.isAvailable, false)
        XCTAssertTrue(streak?.value.contains("아직") == true)
    }

    /// 점수가 없으면 "가장 크게 이긴 날"을 만들지 않는다.
    func testMissingScoresLeaveTheMarginHighlightUnavailable() {
        let logs = [log(1, 4, 1, .win), log(2, 4, 2, .win)]
        let margin = archive(logs).highlights.first { $0.kind == .largestWinMargin }
        XCTAssertEqual(margin?.isAvailable, false)
        XCTAssertTrue(margin?.value.contains("점수가 적힌") == true)
    }

    func testMissingScoresStillProduceValidTotalsAndWinRate() {
        let result = archive(VFStatisticsFixtures.logs(for: .missingScore, season: 2026))
        XCTAssertEqual(result.record.totalGames, 3)
        XCTAssertEqual(result.record.wins, 2)
        XCTAssertEqual(result.record.losses, 1)
        XCTAssertEqual(result.record.winRateText, ".667")
    }

    // MARK: - 10. 구장

    func testStadiumBreakdownUsesRecordVenuesOnly() {
        let result = archive(VFStatisticsFixtures.referenceLogs)
        XCTAssertEqual(result.stadiums.map(\.name),
                       ["대구 삼성 라이온즈 파크", "잠실야구장", "광주-기아 챔피언스 필드"])
        XCTAssertEqual(result.stadiums.map(\.visits), [5, 2, 1])
        XCTAssertEqual(result.stadiums.map(\.rank), [1, 2, 3])
        XCTAssertEqual(result.stadiums.first?.stadiumID, "daegu-lions")
    }

    /// 기록의 구장은 주 관람 구장이나 응원 팀 홈 구장으로 대체되지 않는다.
    func testRecordStadiumIsNeverReplacedByThePrimaryOrHomeStadium() {
        // 응원 팀은 삼성(홈: 대구)이지만 기록은 사직에서 남겼다.
        let result = archive([log(1, 4, 12, .win, ours: 3, theirs: 1, stadium: "사직야구장")])
        XCTAssertEqual(result.stadiums.map(\.name), ["사직야구장"])
        XCTAssertEqual(result.team?.homeStadiumName, "대구 삼성 라이온즈 파크")
        XCTAssertNotEqual(result.stadiums.first?.name, result.team?.homeStadiumName)
        XCTAssertTrue(result.headline.text.contains("사직야구장"))
    }

    /// 구장이 적히지 않은 기록은 구장 분석에서 빠지되 전적에는 그대로 남는다.
    func testMissingStadiumIsHandledWithoutInventingAVenue() {
        let result = archive(VFStatisticsFixtures.logs(for: .noStadium, season: 2026))
        XCTAssertEqual(result.record.totalGames, 3, "구장이 없다고 기록이 사라졌다")
        XCTAssertTrue(result.stadiums.isEmpty)
        XCTAssertEqual(result.subtitle, "3번의 직관", "없는 구장 개수를 세고 있다")
        let highlight = result.highlights.first { $0.kind == .mostVisitedStadium }
        XCTAssertEqual(highlight?.isAvailable, false)
    }

    /// 등록부에 없는 이름이어도 기록에 남은 대로 보여 준다. ID만 없을 뿐이다.
    func testUnregisteredStadiumKeepsItsNameAndGetsARankIdentifier() {
        let result = archive([log(1, 4, 12, .win, stadium: "동대문운동장")])
        XCTAssertEqual(result.stadiums.first?.name, "동대문운동장")
        XCTAssertNil(result.stadiums.first?.stadiumID)
        XCTAssertEqual(result.stadiums.first?.accessibilityIdentifier, "statistics.stadium.rank1")
    }

    /// 아홉 개 정식 구장 전부가 값을 만들어 낸다.
    func testEveryCanonicalStadiumProducesAValidBreakdown() {
        XCTAssertEqual(KBOStadiumSeed.all.count, 9)
        for stadium in KBOStadiumSeed.all {
            let result = archive([log(1, 4, 12, .win, ours: 3, theirs: 1, stadium: stadium.name)])
            XCTAssertEqual(result.stadiums.first?.name, stadium.name)
            XCTAssertEqual(result.stadiums.first?.stadiumID, stadium.id, "\(stadium.name) ID를 찾지 못했다")
            XCTAssertEqual(result.stadiums.first?.accessibilityIdentifier,
                           "statistics.stadium.\(stadium.id)")
            XCTAssertTrue(result.stadiums.first?.accessibilityLabel.contains(stadium.name) == true)
        }
    }

    // MARK: - 11. 팀

    func testEveryCanonicalTeamProducesAValidIdentity() {
        XCTAssertEqual(KBOSeed.teams.count, 10)
        for team in KBOSeed.teams {
            // 상대는 언제나 자기 자신이 아닌 팀이어야 한다.
            let rival = KBOSeed.teams.first { $0.id != team.id }!
            let result = archive(
                [log(1, 4, 12, .win, ours: 3, theirs: 1, matchup: "\(team.shortName) vs \(rival.shortName)")],
                teamID: team.id
            )
            XCTAssertEqual(result.team?.teamID, team.id)
            XCTAssertEqual(result.team?.name, team.name)
            XCTAssertEqual(result.team?.accessibilityIdentifier, "statistics.team.\(team.id)")
            XCTAssertTrue(result.accessibilitySummary.contains(team.name),
                          "\(team.name)이 화면 요약에서 빠졌다")
            let opponent = result.highlights.first { $0.kind == .mostFacedOpponent }
            XCTAssertEqual(opponent?.value, "\(rival.name) · 1번", "\(team.name) 기준 상대 팀을 잘못 골랐다")
        }
    }

    func testNoFavoriteTeamStillProducesAValidArchive() {
        let result = archive(VFStatisticsFixtures.referenceLogs, teamID: nil)
        XCTAssertNil(result.team)
        XCTAssertEqual(result.record.totalGames, 8)
        XCTAssertFalse(result.accessibilitySummary.isEmpty)
    }

    // MARK: - 12. 시즌 목록

    func testSeasonOptionsAreDescendingAndUnique() {
        let options = archive(
            [],
            season: 2025,
            options: [
                SeasonArchiveOption(season: 2024, hasRecords: true),
                SeasonArchiveOption(season: 2026, hasRecords: false),
                SeasonArchiveOption(season: 2024, hasRecords: false)
            ]
        ).seasonOptions
        XCTAssertEqual(options.map(\.season), [2026, 2025, 2024])
        XCTAssertEqual(options.first { $0.season == 2024 }?.hasRecords, true, "기록 있음 표시가 사라졌다")
    }

    func testSelectedSeasonIsAlwaysSelectable() {
        let options = archive([], season: 2030, options: []).seasonOptions
        XCTAssertEqual(options.map(\.season), [2030])
    }

    func testSeasonDiscoveryFromRecordsIsDeterministic() {
        let logs = [
            log(1, 4, 12, .win, year: 2026),
            log(2, 5, 3, .loss, year: 2024),
            log(3, 6, 1, .draw, year: 2025),
            log(4, 7, 7, .win, year: 2026)
        ]
        let first = service.discoveredSeasons(logs: logs)
        let second = service.discoveredSeasons(logs: logs.reversed())
        XCTAssertEqual(first.map(\.season), [2026, 2025, 2024])
        XCTAssertEqual(first, second, "시즌 발견이 입력 순서에 흔들린다")
        XCTAssertTrue(first.allSatisfy(\.hasRecords))
    }

    func testSeasonOptionIdentifiersUseTheYearNotDisplayCopy() {
        for option in archive([], options: [SeasonArchiveOption(season: 2025, hasRecords: true)]).seasonOptions {
            XCTAssertEqual(option.accessibilityIdentifier, "statistics.season.\(option.season)")
            XCTAssertFalse(
                option.accessibilityIdentifier.contains(where: { $0.unicodeScalars.contains { $0.value > 127 } }),
                "식별자에 표시용 문자가 섞였다"
            )
        }
    }

    // MARK: - 13. 시간대

    /// 날짜 판단은 언제나 한국 시간 기준이다. 기기 시간대에 흔들리면 같은 기록이
    /// 기기마다 다른 달에 찍힌다.
    func testMonthBucketingUsesTheExplicitSeoulCalendar() {
        XCTAssertEqual(calendar.timeZone.identifier, "Asia/Seoul")
        // 한국 시간 4월 1일 00:30 = UTC 3월 31일 15:30.
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        components.hour = 0
        components.minute = 30
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        let midnightInSeoul = components.date!

        let entry = AttendanceLogViewState(
            id: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000099")!,
            date: midnightInSeoul, dateText: "", matchup: "삼성 vs LG", stadium: "잠실야구장",
            result: .win, ourScore: 1, opponentScore: 0, seat: "", companion: "",
            memo: "", caption: "", diary: "", tags: [], photoLocalRefs: []
        )
        XCTAssertEqual(archive([entry]).trend.points.map(\.month), [4])
    }

    // MARK: - 14. 서비스 순수성

    func testSeasonArchiveIsCallableWithoutAnyView() {
        let result = StatisticsService().seasonArchive(
            logs: AttendanceLogSample.logs,
            season: 2026,
            seasonOptions: [],
            favoriteTeam: nil
        )
        XCTAssertEqual(result.record.totalGames, AttendanceLogSample.logs.count)
    }

    /// 기존 요약 계산은 그대로 남아 있어야 한다. 다른 화면이 함께 쓴다.
    func testExistingSummaryContractIsUnchanged() {
        let state = StatisticsService().summary(logs: AttendanceLogSample.logs, season: 2026)
        XCTAssertEqual(state.season, 2026)
        XCTAssertEqual(state.totalGames, AttendanceLogSample.logs.count)
        XCTAssertFalse(state.kpis.isEmpty)
    }
}
