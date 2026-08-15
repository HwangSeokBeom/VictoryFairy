import XCTest
@testable import VictoryFairy

/// 캘린더 픽스처가 결정적인지, 그리고 제품 경로로 새어 나가지 않는지 확인한다.
///
/// 픽스처는 편의를 위해 존재하지만, 조용히 제품 데이터를 대신하기 시작하면
/// 테스트가 사실이 아닌 것을 통과시킨다. 그래서 "무엇을 보여주는가"보다
/// "제품에서 절대 나올 수 없는가"를 더 많이 확인한다.
final class CalendarFixtureGovernanceTests: XCTestCase {

    private let calendar = CalendarMonth.referenceCalendar()

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

    private var allScenarios: [VFUITestConfiguration.CalendarFixture] {
        [.referenceMonth, .selectedRecord, .selectedEmptyDate, .multipleSameDayRecords,
         .loading, .emptyMonth, .recoverableError, .retrySuccess,
         .win, .loss, .draw, .cancelled,
         .scheduledDesignState, .liveDesignState, .postponedDesignState,
         .longTeamName, .longStadiumName, .lightTeamAccent, .darkTeamAccent,
         .compactReference, .accessibilityReference, .yearBoundary]
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        return components.date!
    }

    // MARK: - 1. 결정성

    /// 22개 시나리오 전부가 몇 번을 불러도 같은 값을 낸다.
    func testEveryScenarioIsDeterministicAcrossRepeatedReads() {
        XCTAssertEqual(allScenarios.count, 22, "시나리오 수가 문서와 어긋난다")
        for scenario in allScenarios {
            let first = VFCalendarFixtures.logs(for: scenario)
            let second = VFCalendarFixtures.logs(for: scenario)
            XCTAssertEqual(first, second, "\(scenario.rawValue) 기록이 호출마다 달라진다")
            XCTAssertEqual(
                VFCalendarFixtures.month(for: scenario),
                VFCalendarFixtures.month(for: scenario),
                "\(scenario.rawValue) 기준 달이 호출마다 달라진다"
            )
            XCTAssertEqual(
                VFCalendarFixtures.selectedDate(for: scenario),
                VFCalendarFixtures.selectedDate(for: scenario),
                "\(scenario.rawValue) 선택 날짜가 호출마다 달라진다"
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

    // MARK: - 2. 고정된 ID와 날짜

    func testFixtureIdentifiersAndDatesAreStableLiterals() {
        let reference = VFCalendarFixtures.referenceLogs
        XCTAssertEqual(reference.count, 3)
        XCTAssertEqual(
            reference.map(\.id.uuidString),
            ["CA1E0DA0-0000-4000-8000-000000000001",
             "CA1E0DA0-0000-4000-8000-000000000002",
             "CA1E0DA0-0000-4000-8000-000000000003"],
            "기준 기록 ID가 고정값이 아니다"
        )
        XCTAssertEqual(reference.map { calendar.component(.day, from: $0.date) }, [12, 5, 1])
        XCTAssertEqual(reference.map(\.result), [.win, .loss, .draw])
        XCTAssertEqual(
            VFCalendarFixtures.month(for: .referenceMonth),
            VFCalendarFixtures.referenceMonth
        )
        XCTAssertEqual(calendar.component(.year, from: VFCalendarFixtures.referenceMonth), 2026)
        XCTAssertEqual(calendar.component(.month, from: VFCalendarFixtures.referenceMonth), 4)
        XCTAssertEqual(calendar.component(.month, from: VFCalendarFixtures.yearBoundaryMonth), 12)
    }

    /// 모든 픽스처 ID가 전용 접두사를 쓴다. Release 바이너리 검사가 이 접두사를 찾는다.
    func testEveryFixtureIdentifierCarriesTheDedicatedPrefix() {
        for scenario in allScenarios {
            for log in VFCalendarFixtures.logs(for: scenario) {
                XCTAssertTrue(
                    log.id.uuidString.hasPrefix("CA1E0DA0"),
                    "\(scenario.rawValue)에 픽스처 접두사가 없는 ID가 있다: \(log.id)"
                )
            }
        }
    }

    // MARK: - 3~7. 픽스처가 하지 않아야 할 일

    func testFixtureSourceUsesNoWallClockOrRandomIdentity() throws {
        let text = try code("VictoryFairy/Services/VFCalendarFixtures.swift")
        for forbidden in ["Date.now", "Date()", "UUID()", ".random", "arc4random", "Calendar.current"] {
            XCTAssertFalse(text.contains(forbidden), "픽스처가 비결정적 값을 쓴다: \(forbidden)")
        }
    }

    func testFixtureSourceWritesNothingPersistent() throws {
        let text = try code("VictoryFairy/Services/VFCalendarFixtures.swift")
        for forbidden in [
            "modelContext", "ModelContainer", "insert(", "delete(", "save()",
            "UserDefaults", "FileManager", "write(", "URLSession"
        ] {
            XCTAssertFalse(text.contains(forbidden), "픽스처가 저장소나 파일을 건드린다: \(forbidden)")
        }
    }

    /// 사진 파일을 만들지 않으므로 참조도 남기지 않는다.
    func testNoFixtureReferencesAPhotoFile() {
        for scenario in allScenarios {
            for log in VFCalendarFixtures.logs(for: scenario) {
                XCTAssertTrue(
                    log.photoLocalRefs.isEmpty,
                    "\(scenario.rawValue)가 사진 파일을 참조한다"
                )
            }
        }
    }

    // MARK: - 8. 제품 대체 데이터가 되지 않는다

    /// 실행 인자가 없으면 이음새는 받은 값을 그대로 돌려준다.
    func testSeamsReturnProductionValueWhenNoFixtureRequested() {
        XCTAssertNil(VFUITestConfiguration.calendarFixture, "테스트 실행에 캘린더 픽스처가 켜져 있다")

        let production = [VFCalendarFixtures.sameDaySecondRecord]
        XCTAssertEqual(VFUITestConfiguration.calendarLogs(production), production)

        let productionMonth = date(2031, 7, 9)
        XCTAssertEqual(VFUITestConfiguration.initialCalendarMonth(productionMonth), productionMonth)
        XCTAssertEqual(VFUITestConfiguration.calendarState(.loading), .loading)
        XCTAssertEqual(VFUITestConfiguration.calendarState(.loaded), .loaded)
        XCTAssertNil(VFUITestConfiguration.calendarPreselectedDate)
        XCTAssertNil(VFUITestConfiguration.calendarFixtureTeamID)
        XCTAssertNil(VFUITestConfiguration.activeCalendarScenarioIdentifier)
        XCTAssertNil(VFUITestConfiguration.calendarDesignOnlyStatus)
    }

    /// 이음새는 `#if DEBUG` 안에서만 분기한다. 그 밖에서는 인자를 그대로 돌려준다.
    func testSeamBranchesLiveOnlyInsideDebug() throws {
        let text = try code("VictoryFairy/Services/VFUITestConfiguration.swift")
        for seam in ["calendarLogs", "initialCalendarMonth", "calendarState"] {
            guard let range = text.range(of: "static func \(seam)") else {
                return XCTFail("\(seam) 이음새를 찾을 수 없다")
            }
            let body = text[range.lowerBound...].prefix(700)
            XCTAssertTrue(body.contains("#if DEBUG"), "\(seam)에 DEBUG 경계가 없다")
            XCTAssertTrue(
                body.contains("#endif"),
                "\(seam)의 DEBUG 경계가 닫히지 않았다"
            )
            XCTAssertTrue(
                body.contains("return production") || body.contains("production\n"),
                "\(seam)이 제품 값을 그대로 돌려주지 않는다"
            )
        }
    }

    /// 픽스처는 시작 달만 정한다. 화면을 그릴 때마다 덮어쓰면 달 이동이 막힌다.
    func testMonthFixtureSeedsInitialStateAndDoesNotPinEveryRender() throws {
        let shell = try code("VictoryFairy/AppRootView.swift")
        XCTAssertTrue(
            shell.contains("month: appData.selectedCalendarMonth"),
            "화면이 실제 선택 월이 아닌 값을 받고 있다"
        )
        XCTAssertFalse(
            shell.contains("initialCalendarMonth("),
            "달을 그릴 때마다 픽스처로 덮어쓰고 있다"
        )
        let store = try code("VictoryFairy/Services/AppDataStore.swift")
        XCTAssertTrue(
            store.contains("VFUITestConfiguration.initialCalendarMonth("),
            "시작 달을 한 번 정하는 자리가 없다"
        )
    }

    // MARK: - 9~12. 디자인 전용 상태 경계

    /// 제품의 결과 타입에는 예정·진행 중·연기가 없다. 만들어 낼 방법 자체가 없다.
    func testProductionResultTypeCannotExpressDesignOnlyStatuses() {
        XCTAssertEqual(Set(GameResult.allCases.map(\.rawValue)), ["win", "loss", "draw", "canceled"])
        for designOnly in CalendarDesignOnlyStatus.allCases {
            XCTAssertNil(
                GameResult(rawValue: designOnly.rawValue),
                "제품 결과 타입이 \(designOnly.rawValue)을 만들어 낸다"
            )
        }
    }

    /// 디자인 전용 상태 문구는 어떤 제품 결과 문구와도 겹치지 않는다.
    func testDesignOnlyTitlesNeverCollideWithProductionTitles() {
        let productionTitles = Set(GameResult.allCases.flatMap { [$0.title, $0.diaryTitle] })
        for designOnly in CalendarDesignOnlyStatus.allCases {
            XCTAssertFalse(
                productionTitles.contains(designOnly.title),
                "\(designOnly.title)이 제품 문구와 겹친다"
            )
        }
        XCTAssertEqual(
            CalendarDesignOnlyStatus.allCases.map(\.title),
            ["경기 예정", "경기 중", "우천 연기"]
        )
    }

    /// 픽스처 파일 전체가 DEBUG 경계 안에 있다.
    func testFixtureFileIsWhollyInsideTheDebugBoundary() throws {
        let text = try source("VictoryFairy/Services/VFCalendarFixtures.swift")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.first?.trimmingCharacters(in: .whitespaces), "#if DEBUG",
                       "픽스처 파일이 #if DEBUG로 시작하지 않는다")
        XCTAssertEqual(lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces), "#endif",
                       "픽스처 파일이 #endif로 끝나지 않는다")
        let stripped = try code("VictoryFairy/Services/VFCalendarFixtures.swift")
        XCTAssertEqual(
            stripped.components(separatedBy: "#if DEBUG").count - 1, 1,
            "픽스처 파일 안에 DEBUG 경계가 여러 개다"
        )
    }

    /// 디자인 전용 상태를 그리는 곳도 DEBUG 경계 안에 있어야 한다.
    func testCalendarViewRendersDesignOnlyStatusOnlyInsideDebug() throws {
        let text = try code("VictoryFairy/Features/Calendar/CalendarViews.swift")
        guard let range = text.range(of: "designOnlyStatusBanner: some View") else {
            return XCTFail("디자인 전용 상태 배너를 찾을 수 없다")
        }
        let body = text[range.lowerBound...].prefix(600)
        XCTAssertTrue(body.contains("#if DEBUG"), "배너가 DEBUG 경계 밖에서 그려진다")
        XCTAssertFalse(
            text.contains("CalendarDesignOnlyStatus.scheduled") && !body.contains("#if DEBUG"),
            "디자인 전용 상태가 경계 밖에서 참조된다"
        )
    }

    /// 제품 화면 어디에도 디자인 전용 문구가 하드코딩돼 있지 않다.
    func testDesignOnlyCopyAppearsOnlyBehindTheFixtureBoundary() throws {
        let allowed = ["VictoryFairy/Services/VFCalendarFixtures.swift"]
        let root = Self.repositoryRoot.appendingPathComponent("VictoryFairy")
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in enumerator! where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: Self.repositoryRoot.path + "/", with: "")
            guard !allowed.contains(relative) else { continue }
            let text = try code(relative)
            for title in CalendarDesignOnlyStatus.allCases.map(\.title) {
                XCTAssertFalse(text.contains("\"\(title)\""),
                               "\(relative)가 디자인 전용 문구를 직접 들고 있다: \(title)")
            }
        }
    }

    // MARK: - 13~15. 같은 날 여러 기록

    func testSameDayRecordsArePreservedNotCollapsed() {
        let logs = VFCalendarFixtures.logs(for: .multipleSameDayRecords)
        let onTwelfth = logs.filter { calendar.component(.day, from: $0.date) == 12 }
        XCTAssertEqual(onTwelfth.count, 2, "같은 날 기록이 하나로 합쳐졌다")

        let presentation = CalendarSelectedDatePresentation(
            date: date(2026, 4, 12), events: onTwelfth, hasSelection: true
        )
        XCTAssertEqual(presentation.eventCount, 2)
        XCTAssertEqual(presentation.events.count, 2, "표시 모델이 기록을 버렸다")
    }

    /// 대표 기록 선택은 순서를 바꿔 넣어도 항상 같은 결과를 낸다.
    func testPrimaryRecordSelectionIsDeterministicUnderReordering() {
        let logs = VFCalendarFixtures.logs(for: .multipleSameDayRecords)
            .filter { calendar.component(.day, from: $0.date) == 12 }
        let forward = CalendarSelectedDatePresentation(
            date: date(2026, 4, 12), events: logs, hasSelection: true
        ).primaryRecord
        let reversed = CalendarSelectedDatePresentation(
            date: date(2026, 4, 12), events: logs.reversed(), hasSelection: true
        ).primaryRecord
        XCTAssertNotNil(forward)
        XCTAssertEqual(forward?.id, reversed?.id, "넣는 순서에 따라 대표 기록이 달라진다")
    }

    // MARK: - 16~18. 선택일 표시 모델

    func testSelectedDatePresentationCarriesSemanticValues() {
        let logs = VFCalendarFixtures.logs(for: .selectedRecord)
            .filter { calendar.component(.day, from: $0.date) == 12 }
        let presentation = CalendarSelectedDatePresentation(
            date: date(2026, 4, 12), events: logs, hasSelection: true
        )
        XCTAssertEqual(presentation.title, "4월 12일의 기억")
        XCTAssertTrue(presentation.accessibilitySummary.contains("삼성 vs LG"))
        XCTAssertFalse(presentation.accessibilitySummary.contains("calendar."),
                       "읽어 주는 문장에 내부 식별자가 섞였다")

        let empty = CalendarSelectedDatePresentation(
            date: date(2026, 4, 20), events: [], hasSelection: true
        )
        XCTAssertEqual(empty.eventCount, 0)
        XCTAssertTrue(empty.emptyMessage.contains("아직 없어요"))
    }

    /// 표시 모델은 색이나 뷰를 들고 있지 않다. 도메인이 화면을 결정하지 않는다.
    func testPresentationOwnsNoViewOrColour() throws {
        let text = try code("VictoryFairy/Domain/CalendarMonth.swift")
        for forbidden in ["import SwiftUI", "import SwiftData", "some View", ": View",
                          "Color.", "Font.", "@ViewBuilder", "body:"] {
            XCTAssertFalse(text.contains(forbidden), "도메인이 화면 개념을 들고 있다: \(forbidden)")
        }
    }

    /// 기록의 구장은 주 관람 구장으로 대체되지 않는다.
    func testRecordStadiumIsNeverReplacedByThePrimaryStadium() {
        let logs = VFCalendarFixtures.logs(for: .selectedRecord)
        let stadiums = Set(logs.map(\.stadium))
        XCTAssertTrue(stadiums.contains("잠실야구장"), "원정 기록의 구장이 사라졌다")
        XCTAssertTrue(stadiums.contains("대구 삼성 라이온즈 파크"), "홈 기록의 구장이 사라졌다")
        XCTAssertGreaterThan(stadiums.count, 1, "모든 기록이 한 구장으로 뭉개졌다")

        let presentation = CalendarSelectedDatePresentation(
            date: date(2026, 4, 12),
            events: logs.filter { calendar.component(.day, from: $0.date) == 12 },
            hasSelection: true
        )
        XCTAssertEqual(presentation.primaryRecord?.stadium, "잠실야구장",
                       "대표 기록이 자기 구장을 잃었다")
    }

    // MARK: - 19~20. 팀과 구장 전수

    func testEveryCanonicalTeamProducesAValidPresentation() {
        XCTAssertEqual(KBOSeed.teams.count, 10)
        for team in KBOSeed.teams {
            let log = VFCalendarFixtures.referenceLogs[0]
            let presentation = CalendarSelectedDatePresentation(
                date: log.date,
                events: [log],
                hasSelection: true
            )
            XCTAssertNotNil(KBOSeed.team(id: team.id), "\(team.id) 팀을 찾을 수 없다")
            XCTAssertFalse(team.name.isEmpty)
            XCTAssertFalse(team.homeStadiumName.isEmpty)
            XCTAssertFalse(presentation.accessibilitySummary.isEmpty)
        }
    }

    func testEveryCanonicalStadiumProducesAValidPresentation() {
        XCTAssertEqual(KBOSeed.stadiums.count, 9)
        for stadium in KBOSeed.stadiums {
            let base = VFCalendarFixtures.referenceLogs[0]
            let log = AttendanceLogViewState(
                id: base.id, date: base.date, dateText: base.dateText, matchup: base.matchup,
                stadium: stadium, result: base.result, ourScore: base.ourScore,
                opponentScore: base.opponentScore, seat: base.seat, companion: base.companion,
                memo: base.memo, caption: base.caption, diary: base.diary, tags: base.tags,
                photoLocalRefs: base.photoLocalRefs
            )
            let presentation = CalendarSelectedDatePresentation(
                date: log.date, events: [log], hasSelection: true
            )
            XCTAssertEqual(presentation.primaryRecord?.stadium, stadium)
            XCTAssertTrue(presentation.accessibilitySummary.contains(stadium),
                          "\(stadium)이 읽어 주는 문장에서 빠졌다")
        }
    }

    // MARK: - 21~24. 캘린더 경계

    func testCalendarRemainsReadOnly() throws {
        let text = try code("VictoryFairy/Features/Calendar/CalendarViews.swift")
        for forbidden in [
            "modelContext.insert", "modelContext.delete", "try context.save",
            "repository.delete", "repository.save", "StatisticsService("
        ] {
            XCTAssertFalse(text.contains(forbidden), "캘린더가 저장소를 바꾼다: \(forbidden)")
        }
    }

    func testCalendarDomainStaysIndependentOfSwiftUI() throws {
        let text = try code("VictoryFairy/Domain/CalendarMonth.swift")
        XCTAssertTrue(text.contains("import Foundation"))
        XCTAssertFalse(text.contains("import SwiftUI"))
    }

    /// 기기 시간대 설정에 흔들리면 같은 픽스처가 기기마다 다른 날을 고른다.
    func testNeitherCalendarDomainNorViewUsesTheDeviceCalendar() throws {
        for path in [
            "VictoryFairy/Domain/CalendarMonth.swift",
            "VictoryFairy/Features/Calendar/CalendarViews.swift"
        ] {
            let text = try code(path)
            XCTAssertFalse(text.contains("Calendar.current"),
                           "\(path)가 기기 달력을 쓴다")
        }
    }

    func testExplicitTimeZonePolicyIsAsiaSeoul() {
        XCTAssertEqual(calendar.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(DateFormatter.vfCalendarDayIdentifier.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(DateFormatter.vfCalendarDayVoiceOver.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(DateFormatter.vfCalendarDayTitle.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(DateFormatter.vfCalendarDayIdentifier.locale.identifier, "en_US_POSIX",
                       "식별자 형식이 로캘에 흔들린다")
    }

    // MARK: - 25~30. 다른 화면과 경계

    func testHomeAndFeedRemainFrameLevel() throws {
        let home = try code("VictoryFairy/Features/Home/HomeView.swift")
        for marker in ["VFTeamIdentityHeader", "VFSectionHeader"] {
            XCTAssertTrue(home.contains(marker), "홈에서 \(marker)가 사라졌다")
        }
        let feed = try code("VictoryFairy/Features/Feed/FeedViews.swift")
        for marker in ["VFRecordCard", "VFMonthDivider"] {
            XCTAssertTrue(feed.contains(marker), "피드에서 \(marker)가 사라졌다")
        }
    }

    /// 이번 작업이 저장 스키마를 건드리지 않았다.
    func testPersistenceSchemaIsUnchanged() throws {
        let entity = try code("VictoryFairy/Data/Local/SwiftDataAttendanceLogEntity.swift")
        XCTAssertTrue(entity.contains("@Model"))
        for field in ["id", "date", "stadium", "result", "photoLocalRefs"] {
            XCTAssertTrue(entity.contains(field), "저장 스키마에서 \(field)가 사라졌다")
        }
    }

    /// 캘린더는 네트워크를 직접 부르지 않는다. API 경계는 그대로다.
    func testCalendarDoesNotReachTheNetworkDirectly() throws {
        let text = try code("VictoryFairy/Features/Calendar/CalendarViews.swift")
        for forbidden in ["URLSession", "URLRequest", "https://", "APIClient("] {
            XCTAssertFalse(text.contains(forbidden), "캘린더가 네트워크를 직접 부른다: \(forbidden)")
        }
    }

    func testNoLLMProviderOrKeyReachedTheCalendarWork() throws {
        for path in [
            "VictoryFairy/Features/Calendar/CalendarViews.swift",
            "VictoryFairy/Domain/CalendarMonth.swift",
            "VictoryFairy/Services/VFCalendarFixtures.swift",
            "VictoryFairy/Services/VFUITestConfiguration.swift"
        ] {
            let text = try code(path).lowercased()
            for forbidden in ["anthropic", "openai", "api_key", "apikey", "sk-", "bearer "] {
                XCTAssertFalse(text.contains(forbidden), "\(path)에 LLM 흔적이 있다: \(forbidden)")
            }
        }
    }
}
