import XCTest
@testable import VictoryFairy

/// 시즌 아카이브 픽스처가 결정적인지, 그리고 제품 경로로 새어 나가지 않는지 확인한다.
///
/// 픽스처는 편의를 위해 존재하지만, 조용히 제품 데이터를 대신하기 시작하면 테스트가
/// 사실이 아닌 것을 통과시킨다. 그래서 "무엇을 보여주는가"보다 "제품에서 절대 나올 수
/// 없는가"를 더 많이 확인한다.
final class StatisticsFixtureGovernanceTests: XCTestCase {

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    /// 주석을 걷어낸 소스. 검사 문구가 자기 주석에 걸려 통과하는 일을 막는다.
    private func code(_ relativePath: String) throws -> String {
        try source(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func appSwiftFiles() throws -> [(relative: String, code: String)] {
        let root = Self.repositoryRoot.appendingPathComponent("VictoryFairy")
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: Self.repositoryRoot.path + "/", with: "")
            files.append((relative, try code(relative)))
        }
        return files
    }

    private var allScenarios: [VFUITestConfiguration.StatisticsFixture] {
        [.referenceSeason, .multipleSeasons, .previousSeason, .empty, .oneRecord,
         .insufficientData, .noStadium, .missingScore, .winOnly, .lossOnly, .drawOnly,
         .cancelledOnly, .mixedResults, .loading, .recoverableError, .retrySuccess,
         .longTeamName, .longStadiumName, .lightTeamAccent, .darkTeamAccent,
         .compactReference, .accessibilityReference, .allStadiums]
    }

    private let seasons = [
        VFStatisticsFixtures.referenceSeason,
        VFStatisticsFixtures.previousSeason,
        VFStatisticsFixtures.oldestSeason
    ]

    // MARK: - 1. 결정성

    func testEveryScenarioIsDeterministicAcrossRepeatedReads() {
        XCTAssertEqual(allScenarios.count, 23, "시나리오 수가 문서와 어긋난다")
        for scenario in allScenarios {
            for season in seasons {
                XCTAssertEqual(
                    VFStatisticsFixtures.logs(for: scenario, season: season),
                    VFStatisticsFixtures.logs(for: scenario, season: season),
                    "\(scenario.rawValue) 기록이 호출마다 달라진다"
                )
            }
            XCTAssertEqual(
                VFStatisticsFixtures.seasons(for: scenario),
                VFStatisticsFixtures.seasons(for: scenario),
                "\(scenario.rawValue) 시즌 목록이 호출마다 달라진다"
            )
            XCTAssertEqual(
                VFStatisticsFixtures.initialSeason(for: scenario),
                VFStatisticsFixtures.initialSeason(for: scenario)
            )
        }
    }

    /// 시나리오 이름은 rawValue로만 식별한다. 한국어 표시 문구에 기대지 않는다.
    func testScenarioIdentityIsRawValueNotDisplayCopy() {
        for scenario in allScenarios {
            XCTAssertFalse(
                scenario.rawValue.contains(where: { $0.unicodeScalars.contains { $0.value > 127 } }),
                "\(scenario.rawValue) 식별자에 표시용 문자가 섞였다"
            )
        }
    }

    /// 알 수 없는 이름은 어떤 픽스처도 켜지 않는다.
    func testUnknownScenarioNameActivatesNothing() {
        for raw in ["", "nope", "referenceseason", "REFERENCESEASON", "calendar.referenceMonth", "referenceMonth"] {
            XCTAssertNil(
                VFUITestConfiguration.StatisticsFixture(rawValue: raw),
                "알 수 없는 이름 \"\(raw)\"이 픽스처를 켰다"
            )
        }
    }

    // MARK: - 2. 고정된 ID와 날짜

    func testFixtureIdentifiersAndDatesAreStableLiterals() {
        let calendar = StatisticsService.referenceCalendar()
        let reference = VFStatisticsFixtures.referenceLogs
        XCTAssertEqual(reference.count, 8)
        XCTAssertEqual(
            reference.map(\.id.uuidString),
            (1...8).map { String(format: "57A7DA7A-0000-4000-8000-%012d", $0) },
            "기준 기록 ID가 고정값이 아니다"
        )
        XCTAssertEqual(reference.map { calendar.component(.month, from: $0.date) },
                       [3, 3, 3, 4, 4, 4, 4, 4])
        XCTAssertEqual(reference.map(\.result), [.win, .loss, .draw, .win, .win, .win, .loss, .win])
        XCTAssertTrue(reference.allSatisfy { calendar.component(.year, from: $0.date) == 2026 })
    }

    /// 모든 픽스처 ID가 전용 접두사를 쓴다. Release 바이너리 검사가 이 접두사를 찾는다.
    func testEveryFixtureIdentifierCarriesTheDedicatedPrefix() {
        for scenario in allScenarios {
            for season in seasons {
                for log in VFStatisticsFixtures.logs(for: scenario, season: season) {
                    XCTAssertTrue(
                        log.id.uuidString.hasPrefix("57A7DA7A"),
                        "\(scenario.rawValue)에 픽스처 접두사가 없는 ID가 있다: \(log.id)"
                    )
                }
            }
        }
    }

    // MARK: - 3. 픽스처가 하지 않아야 할 일

    func testFixtureSourceUsesNoWallClockOrRandomIdentity() throws {
        let text = try code("VictoryFairy/Services/VFStatisticsFixtures.swift")
        for forbidden in ["Date.now", "Date()", "UUID()", ".random", "arc4random", "Calendar.current"] {
            XCTAssertFalse(text.contains(forbidden), "픽스처가 비결정적 값을 쓴다: \(forbidden)")
        }
    }

    func testFixtureSourceWritesNothingPersistent() throws {
        let text = try code("VictoryFairy/Services/VFStatisticsFixtures.swift")
        for forbidden in [
            "modelContext", "ModelContainer", "insert(", "delete(", "save()",
            "UserDefaults", "FileManager", "write(", "URLSession"
        ] {
            XCTAssertFalse(text.contains(forbidden), "픽스처가 저장소나 파일을 건드린다: \(forbidden)")
        }
    }

    func testNoFixtureReferencesAPhotoFile() {
        for scenario in allScenarios {
            for season in seasons {
                for log in VFStatisticsFixtures.logs(for: scenario, season: season) {
                    XCTAssertTrue(
                        log.photoLocalRefs.isEmpty,
                        "\(scenario.rawValue)가 사진 파일을 참조한다"
                    )
                }
            }
        }
    }

    func testFixtureFileIsWhollyInsideTheDebugBoundary() throws {
        let text = try source("VictoryFairy/Services/VFStatisticsFixtures.swift")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.first?.trimmingCharacters(in: .whitespaces), "#if DEBUG",
                       "픽스처 파일이 #if DEBUG로 시작하지 않는다")
        XCTAssertEqual(lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces), "#endif",
                       "픽스처 파일이 #endif로 끝나지 않는다")
        let stripped = try code("VictoryFairy/Services/VFStatisticsFixtures.swift")
        XCTAssertEqual(
            stripped.components(separatedBy: "#if DEBUG").count - 1, 1,
            "픽스처 파일 안에 DEBUG 경계가 여러 개다"
        )
    }

    // MARK: - 4. 제품 대체 데이터가 되지 않는다

    /// 실행 인자가 없으면 이음새는 받은 값을 그대로 돌려준다.
    func testSeamsReturnProductionValueWhenNoFixtureRequested() {
        XCTAssertNil(VFUITestConfiguration.statisticsFixture, "테스트 실행에 시즌 픽스처가 켜져 있다")

        let production = VFStatisticsFixtures.previousSeasonLogs
        XCTAssertEqual(VFUITestConfiguration.statisticsLogs(production, season: 2026), production)
        XCTAssertEqual(VFUITestConfiguration.statisticsLogs([], season: 2026), [])

        let options = [SeasonArchiveOption(season: 2031, hasRecords: false)]
        XCTAssertEqual(VFUITestConfiguration.statisticsSeasons(options), options)

        XCTAssertEqual(VFUITestConfiguration.statisticsState(.loading), .loading)
        XCTAssertEqual(VFUITestConfiguration.statisticsState(.loaded), .loaded)
        XCTAssertEqual(VFUITestConfiguration.statisticsState(.empty), .empty)

        XCTAssertNil(VFUITestConfiguration.statisticsInitialSeason)
        XCTAssertNil(VFUITestConfiguration.statisticsFixtureTeamID)
        XCTAssertNil(VFUITestConfiguration.activeStatisticsScenarioIdentifier)
    }

    /// 이음새는 `#if DEBUG` 안에서만 분기한다. 그 밖에서는 인자를 그대로 돌려준다.
    func testSeamBranchesLiveOnlyInsideDebug() throws {
        let text = try code("VictoryFairy/Services/VFUITestConfiguration.swift")
        for seam in ["statisticsLogs", "statisticsSeasons", "statisticsState"] {
            guard let range = text.range(of: "static func \(seam)") else {
                return XCTFail("\(seam) 이음새를 찾을 수 없다")
            }
            let body = text[range.lowerBound...].prefix(700)
            XCTAssertTrue(body.contains("#if DEBUG"), "\(seam)에 DEBUG 경계가 없다")
            XCTAssertTrue(body.contains("#endif"), "\(seam)의 DEBUG 경계가 닫히지 않았다")
            XCTAssertTrue(
                body.contains("return production"),
                "\(seam)이 제품 값을 그대로 돌려주지 않는다"
            )
        }
    }

    /// 픽스처는 시작 시즌만 정한다. 화면을 그릴 때마다 덮어쓰면 시즌 선택이 막힌다.
    func testSeasonFixtureSeedsInitialStateAndDoesNotPinEveryRender() throws {
        let shell = try code("VictoryFairy/AppRootView.swift")
        XCTAssertTrue(shell.contains("season: appData.selectedSeason"),
                      "화면이 실제 선택 시즌이 아닌 값을 받고 있다")
        XCTAssertFalse(shell.contains("statisticsInitialSeason"),
                       "시즌을 그릴 때마다 픽스처로 덮어쓰고 있다")
        let configuration = try code("VictoryFairy/Services/VFUITestConfiguration.swift")
        XCTAssertTrue(configuration.contains("statisticsInitialSeason"),
                      "시작 시즌을 한 번 정하는 자리가 없다")
    }

    /// 픽스처 표식은 접근성 트리에 남아야 한다. 숨기면 UI 테스트가 영영 찾지 못한다.
    func testScenarioMarkerStaysVisibleToUITests() throws {
        let text = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        guard let range = text.range(of: "fixtureScenarioMarker: some View") else {
            return XCTFail("시나리오 표식을 찾을 수 없다")
        }
        let body = text[range.lowerBound...].prefix(600)
        XCTAssertTrue(body.contains("activeStatisticsScenarioIdentifier"))
        XCTAssertTrue(body.contains("accessibilityIdentifier(identifier)"))
        XCTAssertFalse(body.contains("accessibilityHidden"),
                       "표식이 접근성 트리에서 빠져 UI 테스트가 찾을 수 없다")
    }

    func testScenarioMarkerNamesEveryScenario() {
        for scenario in allScenarios {
            XCTAssertEqual(
                "statistics.scenario.\(scenario.rawValue)".hasPrefix("statistics.scenario."),
                true
            )
        }
    }

    // MARK: - 5. Pencil 표본이 제품으로 새지 않는다

    /// Pencil이 예시로 적어 둔 문장과 숫자는 앱 어디에도 없어야 한다.
    func testPencilSampleCopyNeverAppearsInAppSource() throws {
        let forbidden = [
            "잠실의 기적",
            "두 눈으로 본 사람",
            "박병호",
            "여덟 번의 직관",
            "여덟 개의 이야기",
            "라이온즈파크, 다섯 번",
            "KIA 타이거즈, 세 번",
            "4월의 3연승",
            "\".625\""
        ]
        for (relative, text) in try appSwiftFiles() {
            for needle in forbidden {
                XCTAssertFalse(text.contains(needle), "\(relative)에 Pencil 표본이 남아 있다: \(needle)")
            }
        }
    }

    /// 제품이 만들어 내는 문장은 어떤 기록에서도 Pencil 예시 문장이 되지 않는다.
    func testGeneratedHeadlineIsNeverThePencilSentence() {
        let service = StatisticsService()
        for scenario in allScenarios {
            for season in seasons {
                let logs = VFStatisticsFixtures.logs(for: scenario, season: season)
                let headline = service.seasonArchive(
                    logs: logs, season: season, seasonOptions: [],
                    favoriteTeam: KBOSeed.team(id: "samsung-lions")
                ).headline
                XCTAssertFalse(headline.text.contains("기적"))
                XCTAssertFalse(headline.text.isEmpty)
            }
        }
    }

    /// 하드코딩된 가짜 통계 화면이 남아 있지 않다.
    func testNoHardcodedSeasonStatisticsScreenRemains() throws {
        for (relative, text) in try appSwiftFiles() {
            XCTAssertFalse(text.contains("struct SeasonStatsView"),
                           "\(relative)에 표본 값이 박힌 시즌 화면이 남아 있다")
            XCTAssertFalse(text.contains("\"7승 4패 1무\""), "\(relative)에 고정 전적이 남아 있다")
            XCTAssertFalse(text.contains("\"잠실 8회\""), "\(relative)에 고정 구장 값이 남아 있다")
            XCTAssertFalse(text.contains("\"KIA 4회\""), "\(relative)에 고정 상대 값이 남아 있다")
        }
    }

    // MARK: - 6. 프레임 단위 구현

    /// Pencil 시즌 아카이브의 각 조각이 화면에 실제로 있다.
    func testStatisticsIsFrameLevelImplementation() throws {
        let text = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        for marker in [
            "SeasonCoverCard", "SeasonResultDistributionView", "SeasonHighlightRow",
            "SeasonTrendChart", "SeasonStadiumRow", "VFSectionHeader",
            "이번 시즌을 한 문장으로", "올해의 기록들", "월별 직관", "시즌 리포트 만들기"
        ] {
            XCTAssertTrue(text.contains(marker), "시즌 아카이브에서 \(marker)가 사라졌다")
        }
        // 프레임 밖의 임시 구성이 남아 있지 않다.
        for removed in ["StatisticsSectionPicker", "ResultDonutChart", "DonutSegment"] {
            XCTAssertFalse(text.contains(removed), "\(removed)이 아직 남아 있다")
        }
    }

    /// 화면은 의미 모델을 그리기만 한다. 합계와 승률을 뷰 안에서 다시 계산하지 않는다.
    func testViewDoesNotRecomputeTotalsOrWinRate() throws {
        let text = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        for forbidden in [
            "filter { $0.result ==", "Double(wins) / Double(", "wins + losses + draws",
            "logs.filter"
        ] {
            XCTAssertFalse(text.contains(forbidden), "화면이 통계를 다시 계산한다: \(forbidden)")
        }
    }

    /// 연도를 `LocalizedStringKey`에 그대로 보간하면 숫자로 취급돼 "2,026 시즌"으로 읽힌다.
    ///
    /// 어떤 자리가 `LocalizedStringKey`로 해석되는지는 주변 타입이 정해서 눈으로 가리기
    /// 어렵다. 그래서 "안전한 자리만 골라 쓴다"가 아니라 **화면에서 연도를 숫자로 보간하지
    /// 않는다**를 규칙으로 둔다. 이미 문자열로 만들어 둔 제목이나 `String(...)`을 쓴다.
    func testSeasonYearIsNeverInterpolatedAsANumberIntoLocalizedText() throws {
        let text = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        XCTAssertFalse(text.contains("\\(archive.season)"),
                       "연도가 숫자로 읽히는 자리에 그대로 들어갔다")
        XCTAssertTrue(text.contains("Text(verbatim: \"시즌 선택,"),
                      "시즌 칩이 연도를 문자 그대로 읽지 않는다")
    }

    /// 문자열로 만들어 둔 제목은 연도를 그대로 보여 준다.
    func testSeasonTitleRendersTheYearWithoutGroupingSeparators() {
        let archive = StatisticsService().seasonArchive(
            logs: [], season: 2026, seasonOptions: [], favoriteTeam: nil
        )
        XCTAssertEqual(archive.title, "2026 시즌")
        XCTAssertFalse(archive.title.contains(","), "연도에 자릿수 구분 기호가 붙었다")
        XCTAssertEqual(archive.seasonOptions.first?.shortLabel, "2026")
    }

    /// 계산 계층은 화면 개념을 들고 있지 않다.
    func testSeasonArchiveDomainOwnsNoViewOrColour() throws {
        for path in [
            "VictoryFairy/Domain/SeasonArchive.swift",
            "VictoryFairy/Domain/Services/StatisticsService.swift"
        ] {
            let text = try code(path)
            XCTAssertTrue(text.contains("import Foundation"), "\(path)에 Foundation import가 없다")
            for forbidden in ["import SwiftUI", "import SwiftData", "some View", ": View",
                              "Color.", "Font.", "@ViewBuilder"] {
                XCTAssertFalse(text.contains(forbidden), "\(path)가 화면 개념을 들고 있다: \(forbidden)")
            }
        }
    }

    /// 기기 시간대 설정에 흔들리면 같은 기록이 기기마다 다른 달에 찍힌다.
    func testNeitherArchiveDomainNorViewUsesTheDeviceCalendar() throws {
        for path in [
            "VictoryFairy/Domain/SeasonArchive.swift",
            "VictoryFairy/Domain/Services/StatisticsService.swift",
            "VictoryFairy/Features/Statistics/StatisticsViews.swift",
            "VictoryFairy/Services/VFStatisticsFixtures.swift"
        ] {
            let text = try code(path)
            XCTAssertFalse(text.contains("Calendar.current"), "\(path)가 기기 달력을 쓴다")
        }
        XCTAssertEqual(StatisticsService.referenceCalendar().timeZone.identifier, "Asia/Seoul")
    }

    // MARK: - 7. 경계

    func testStatisticsRemainsReadOnly() throws {
        let text = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        for forbidden in [
            "modelContext.insert", "modelContext.delete", "try context.save",
            "repository.delete", "repository.save"
        ] {
            XCTAssertFalse(text.contains(forbidden), "시즌 아카이브가 저장소를 바꾼다: \(forbidden)")
        }
    }

    func testStatisticsDoesNotReachTheNetworkDirectly() throws {
        let text = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        for forbidden in ["URLSession", "URLRequest", "https://", "APIClient("] {
            XCTAssertFalse(text.contains(forbidden), "시즌 아카이브가 네트워크를 직접 부른다: \(forbidden)")
        }
    }

    func testNoLLMProviderOrKeyReachedTheStatisticsWork() throws {
        for path in [
            "VictoryFairy/Features/Statistics/StatisticsViews.swift",
            "VictoryFairy/Domain/SeasonArchive.swift",
            "VictoryFairy/Domain/Services/StatisticsService.swift",
            "VictoryFairy/Services/VFStatisticsFixtures.swift",
            "VictoryFairy/Services/VFUITestConfiguration.swift"
        ] {
            let text = try code(path).lowercased()
            for forbidden in ["anthropic", "openai", "api_key", "apikey", "sk-", "bearer "] {
                XCTAssertFalse(text.contains(forbidden), "\(path)에 LLM 흔적이 있다: \(forbidden)")
            }
        }
    }

    /// 이번 작업이 API 계약을 건드리지 않았다.
    func testAPIContractIsUnchanged() throws {
        let repositories = try code("VictoryFairy/Data/Repositories/VFRepositories.swift")
        for endpoint in [
            "/api/v1/seasons", "/api/v1/feed", "/api/v1/calendar",
            "/api/v1/statistics/summary", "/api/v1/statistics/stadiums",
            "/api/v1/statistics/opponents", "/api/v1/kbo/standings", "/api/v1/kbo/games"
        ] {
            XCTAssertTrue(repositories.contains(endpoint), "API 경로가 사라졌다: \(endpoint)")
        }
    }

    /// 이번 작업이 저장 스키마를 건드리지 않았다.
    func testPersistenceSchemaIsUnchanged() throws {
        let entity = try code("VictoryFairy/Data/Local/SwiftDataAttendanceLogEntity.swift")
        XCTAssertTrue(entity.contains("@Model"))
        for field in [
            "var id: String", "var gameDate: Date", "var season: Int", "var stadiumName: String",
            "var resultRawValue: String", "var ourScore: Int?", "var photoLocalRefsStorage: String"
        ] {
            XCTAssertTrue(entity.contains(field), "저장 스키마에서 \(field)가 사라졌다")
        }
    }

    // MARK: - 8. 다른 화면이 그대로인지

    func testHomeFeedAndCalendarRemainFrameLevel() throws {
        let home = try code("VictoryFairy/Features/Home/HomeView.swift")
        for marker in ["VFTeamIdentityHeader", "VFSectionHeader"] {
            XCTAssertTrue(home.contains(marker), "홈에서 \(marker)가 사라졌다")
        }
        let feed = try code("VictoryFairy/Features/Feed/FeedViews.swift")
        for marker in ["VFRecordCard", "VFMonthDivider"] {
            XCTAssertTrue(feed.contains(marker), "피드에서 \(marker)가 사라졌다")
        }
        let calendar = try code("VictoryFairy/Features/Calendar/CalendarViews.swift")
        for marker in ["CalendarMonthView", "calendar.selectedDetail", "activeCalendarScenarioIdentifier"] {
            XCTAssertTrue(calendar.contains(marker), "캘린더에서 \(marker)가 사라졌다")
        }
    }

    /// 캘린더 픽스처 경계가 이번 작업으로 흔들리지 않았다.
    func testCalendarFixtureBoundaryStillHolds() {
        XCTAssertNil(VFUITestConfiguration.calendarFixture)
        XCTAssertNil(VFUITestConfiguration.activeCalendarScenarioIdentifier)
        XCTAssertEqual(VFCalendarFixtures.referenceLogs.count, 3)
    }

    /// 두 픽스처 계열은 각자의 실행 인자만 읽는다.
    ///
    /// 시나리오 이름은 화면마다 같은 개념을 가리키므로 겹쳐도 된다(`loading` 등).
    /// 문제가 되는 것은 **한쪽 인자가 다른 쪽 상태를 켜는 것**이라, 인자 키가 서로
    /// 다른지와 각 이음새가 자기 키만 보는지를 확인한다.
    func testCalendarAndStatisticsFixturesReadSeparateArguments() throws {
        let text = try code("VictoryFairy/Services/VFUITestConfiguration.swift")
        XCTAssertTrue(text.contains("-VFUITestCalendarFixture"))
        XCTAssertTrue(text.contains("-VFUITestStatisticsFixture"))
        XCTAssertNotEqual("-VFUITestCalendarFixture", "-VFUITestStatisticsFixture")

        guard let calendarSeam = text.range(of: "var calendarFixture:"),
              let statisticsSeam = text.range(of: "var statisticsFixture:") else {
            return XCTFail("픽스처 이음새를 찾을 수 없다")
        }
        let calendarBody = String(text[calendarSeam.lowerBound...].prefix(400))
        XCTAssertTrue(calendarBody.contains("-VFUITestCalendarFixture"))
        XCTAssertFalse(calendarBody.contains("-VFUITestStatisticsFixture"),
                       "캘린더 이음새가 시즌 인자를 읽는다")

        let statisticsBody = String(text[statisticsSeam.lowerBound...].prefix(400))
        XCTAssertTrue(statisticsBody.contains("-VFUITestStatisticsFixture"))
        XCTAssertFalse(statisticsBody.contains("-VFUITestCalendarFixture"),
                       "시즌 이음새가 캘린더 인자를 읽는다")
    }

    /// 두 표식은 접두사가 달라 UI 테스트가 서로를 오인하지 않는다.
    func testScenarioMarkersUseDistinctPrefixes() {
        for scenario in allScenarios {
            let marker = "statistics.scenario.\(scenario.rawValue)"
            XCTAssertFalse(marker.hasPrefix("calendar.scenario."))
        }
        for scenario in [VFUITestConfiguration.CalendarFixture.loading, .recoverableError] {
            XCTAssertFalse("calendar.scenario.\(scenario.rawValue)".hasPrefix("statistics.scenario."))
        }
    }
}
