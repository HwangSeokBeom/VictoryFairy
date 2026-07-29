import XCTest
@testable import VictoryFairy

/// 기록 상세 픽스처가 결정적인지, 그리고 제품 경로로 새어 나가지 않는지 확인한다.
///
/// 픽스처는 편의를 위해 존재하지만, 조용히 제품 데이터를 대신하기 시작하면 테스트가
/// 사실이 아닌 것을 통과시킨다. 그래서 "무엇을 보여주는가"보다 "제품에서 절대 나올 수
/// 없는가"를 더 많이 확인한다.
final class RecordDetailFixtureGovernanceTests: XCTestCase {

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

    private var allScenarios: [VFUITestConfiguration.RecordDetailFixture] {
        [.referenceRecord, .withPhoto, .withoutPhoto, .missingPhotoFile, .failedPhotoDecode,
         .longNote, .noNote, .missingScore, .missingOpponent, .missingStadium, .unknownStadium,
         .win, .loss, .draw, .cancelled, .loading, .recoverableError, .retrySuccess,
         .deleteConfirmation, .deleteSuccess, .deleteFailure, .longTeamName, .longStadiumName,
         .lightTeamAccent, .darkTeamAccent, .compactReference, .accessibilityReference]
    }

    // MARK: - 1. 결정성

    func testEveryScenarioIsDeterministicAcrossRepeatedReads() {
        XCTAssertEqual(allScenarios.count, 27, "시나리오 수가 문서와 어긋난다")
        for scenario in allScenarios {
            XCTAssertEqual(
                VFRecordDetailFixtures.log(for: scenario),
                VFRecordDetailFixtures.log(for: scenario),
                "\(scenario.rawValue) 기록이 호출마다 달라진다"
            )
            XCTAssertEqual(
                VFRecordDetailFixtures.media(for: scenario),
                VFRecordDetailFixtures.media(for: scenario)
            )
            XCTAssertEqual(
                VFRecordDetailFixtures.dataState(for: scenario),
                VFRecordDetailFixtures.dataState(for: scenario)
            )
            XCTAssertEqual(
                VFRecordDetailFixtures.scriptedDeletion(for: scenario),
                VFRecordDetailFixtures.scriptedDeletion(for: scenario)
            )
        }
    }

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
        for raw in ["", "nope", "referencerecord", "REFERENCERECORD", "referenceSeason", "referenceMonth"] {
            XCTAssertNil(
                VFUITestConfiguration.RecordDetailFixture(rawValue: raw),
                "알 수 없는 이름 \"\(raw)\"이 픽스처를 켰다"
            )
        }
    }

    // MARK: - 2. 고정된 ID와 날짜

    func testFixtureIdentifiersAndDatesAreStableLiterals() {
        let calendar = RecordDetailService.referenceCalendar()
        let reference = VFRecordDetailFixtures.referenceLog
        XCTAssertEqual(reference.id.uuidString, "D37A11ED-0000-4000-8000-000000000001")
        XCTAssertEqual(calendar.component(.year, from: reference.date), 2026)
        XCTAssertEqual(calendar.component(.month, from: reference.date), 4)
        XCTAssertEqual(calendar.component(.day, from: reference.date), 12)
        XCTAssertEqual(reference.result, .win)
        XCTAssertEqual(reference.ourScore, 6)
        XCTAssertEqual(reference.opponentScore, 3)
    }

    func testEveryFixtureIdentifierCarriesTheDedicatedPrefix() {
        for scenario in allScenarios {
            let entry = VFRecordDetailFixtures.log(for: scenario)
            XCTAssertTrue(
                entry.id.uuidString.hasPrefix("D37A11ED"),
                "\(scenario.rawValue)에 픽스처 접두사가 없는 ID가 있다: \(entry.id)"
            )
        }
    }

    // MARK: - 3. 픽스처가 하지 않아야 할 일

    func testFixtureSourceUsesNoWallClockOrRandomIdentity() throws {
        let text = try code("VictoryFairy/Services/VFRecordDetailFixtures.swift")
        for forbidden in ["Date.now", "Date()", "UUID()", ".random", "arc4random", "Calendar.current"] {
            XCTAssertFalse(text.contains(forbidden), "픽스처가 비결정적 값을 쓴다: \(forbidden)")
        }
    }

    /// 픽스처는 저장소에도 파일 시스템에도 쓰지 않는다. 사진도 파일로 만들지 않는다.
    func testFixtureSourceWritesNothingPersistent() throws {
        let text = try code("VictoryFairy/Services/VFRecordDetailFixtures.swift")
        for forbidden in [
            "modelContext", "ModelContainer", "insert(", "delete(", "save()",
            "UserDefaults", "FileManager", "write(", "URLSession", "savePhoto", "saveImage"
        ] {
            XCTAssertFalse(text.contains(forbidden), "픽스처가 저장소나 파일을 건드린다: \(forbidden)")
        }
    }

    /// 사진은 번들 리소스가 아니라 그릴 때마다 메모리에서 만든다.
    /// 그래서 Release 번들에 넣을 테스트 전용 이미지 파일이 애초에 없다.
    func testFixturePhotosAreDrawnInMemoryNotStored() throws {
        let text = try code("VictoryFairy/Services/VFRecordDetailFixtures.swift")
        XCTAssertTrue(text.contains("UIGraphicsImageRenderer"), "메모리 이미지 생성이 없다")
        XCTAssertFalse(text.contains("Bundle."), "픽스처가 번들 리소스를 찾는다")
        XCTAssertFalse(text.contains("UIImage(named:"), "픽스처가 에셋 이미지를 쓴다")

        let generated = VFRecordDetailFixtures.inMemoryImage(
            for: "\(VFRecordDetailFixtures.inMemoryPhotoPrefix)-1", maxPixel: 320
        )
        XCTAssertNotNil(generated, "메모리 이미지를 만들지 못했다")
        XCTAssertNil(
            VFRecordDetailFixtures.inMemoryImage(for: "9F1B2C3D-real-photo", maxPixel: 320),
            "제품 참조가 픽스처 그림으로 대체된다"
        )
    }

    func testFixtureFileIsWhollyInsideTheDebugBoundary() throws {
        let text = try source("VictoryFairy/Services/VFRecordDetailFixtures.swift")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.first?.trimmingCharacters(in: .whitespaces), "#if DEBUG")
        XCTAssertEqual(lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces), "#endif")
        let stripped = try code("VictoryFairy/Services/VFRecordDetailFixtures.swift")
        XCTAssertEqual(stripped.components(separatedBy: "#if DEBUG").count - 1, 1)
    }

    // MARK: - 4. 제품 대체 데이터가 되지 않는다

    func testSeamsReturnProductionValueWhenNoFixtureRequested() {
        XCTAssertNil(VFUITestConfiguration.recordDetailFixture, "테스트 실행에 상세 픽스처가 켜져 있다")

        let production = AttendanceLogSample.logs[0]
        XCTAssertEqual(VFUITestConfiguration.recordDetailLog(production), production)
        XCTAssertEqual(VFUITestConfiguration.recordDetailMedia(.none), .none)
        XCTAssertEqual(
            VFUITestConfiguration.recordDetailMedia(.missingFile(refs: ["a"])),
            .missingFile(refs: ["a"])
        )
        XCTAssertEqual(VFUITestConfiguration.recordDetailState(.loaded), .loaded)
        XCTAssertEqual(VFUITestConfiguration.recordDetailState(.loading), .loading)
        XCTAssertNil(VFUITestConfiguration.recordDetailFixtureTeamID)
        XCTAssertNil(VFUITestConfiguration.activeRecordDetailScenarioIdentifier)
    }

    /// 픽스처가 없으면 삭제 이음새는 실제 동작을 그대로 호출한다.
    func testDeletionSeamRunsProductionWorkWhenNoFixtureRequested() async {
        var didRunProduction = false
        let outcome = await VFUITestConfiguration.recordDetailDeletion {
            didRunProduction = true
            return .deleted
        }
        XCTAssertTrue(didRunProduction, "이음새가 실제 삭제를 건너뛰었다")
        XCTAssertEqual(outcome, .deleted)
    }

    func testSeamBranchesLiveOnlyInsideDebug() throws {
        let text = try code("VictoryFairy/Services/VFUITestConfiguration.swift")
        for seam in ["recordDetailLog", "recordDetailMedia", "recordDetailState", "recordDetailDeletion"] {
            guard let range = text.range(of: "static func \(seam)") else {
                return XCTFail("\(seam) 이음새를 찾을 수 없다")
            }
            let body = text[range.lowerBound...].prefix(700)
            XCTAssertTrue(body.contains("#if DEBUG"), "\(seam)에 DEBUG 경계가 없다")
            XCTAssertTrue(body.contains("#endif"), "\(seam)의 DEBUG 경계가 닫히지 않았다")
            XCTAssertTrue(
                body.contains("return production") || body.contains("await production()"),
                "\(seam)이 제품 값을 그대로 돌려주지 않는다"
            )
        }
    }

    /// 픽스처 표식은 접근성 트리에 남아야 한다. 숨기면 UI 테스트가 영영 찾지 못한다.
    func testScenarioMarkerStaysVisibleToUITests() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        guard let range = text.range(of: "fixtureScenarioMarker: some View") else {
            return XCTFail("시나리오 표식을 찾을 수 없다")
        }
        let body = text[range.lowerBound...].prefix(600)
        XCTAssertTrue(body.contains("activeRecordDetailScenarioIdentifier"))
        XCTAssertTrue(body.contains("accessibilityIdentifier(identifier)"))
        XCTAssertFalse(body.contains("accessibilityHidden"),
                       "표식이 접근성 트리에서 빠져 UI 테스트가 찾을 수 없다")
    }

    /// 세 화면의 픽스처는 각자의 실행 인자만 읽는다.
    func testEachScreenFixtureReadsItsOwnArgument() throws {
        let text = try code("VictoryFairy/Services/VFUITestConfiguration.swift")
        let keys = ["-VFUITestCalendarFixture", "-VFUITestStatisticsFixture", "-VFUITestRecordDetailFixture"]
        for key in keys { XCTAssertTrue(text.contains(key), "\(key) 인자가 없다") }
        XCTAssertEqual(Set(keys).count, keys.count)

        guard let seam = text.range(of: "var recordDetailFixture:") else {
            return XCTFail("상세 픽스처 이음새를 찾을 수 없다")
        }
        let body = String(text[seam.lowerBound...].prefix(400))
        XCTAssertTrue(body.contains("-VFUITestRecordDetailFixture"))
        XCTAssertFalse(body.contains("-VFUITestCalendarFixture"))
        XCTAssertFalse(body.contains("-VFUITestStatisticsFixture"))
    }

    // MARK: - 5. Pencil 표본이 제품으로 새지 않는다

    /// Pencil이 예시로 적어 둔 문장과 값은 앱 어디에도 없어야 한다.
    func testPencilSampleCopyNeverAppearsInAppSource() throws {
        let forbidden = [
            "박병호",
            "김재윤",
            "9회초 박병호",
            "유광 점퍼",
            "치킨과 생맥주",
            "맑고 바람 좋은 밤",
            "잠실에서, 민지",
            "HOME BALLPARK"
        ]
        for (relative, text) in try appSwiftFiles() {
            for needle in forbidden {
                XCTAssertFalse(text.contains(needle), "\(relative)에 Pencil 표본이 남아 있다: \(needle)")
            }
        }
    }

    /// 도메인에 없는 항목을 화면이 만들어 내지 않는다.
    func testUnsupportedDetailFieldsAreNotRendered() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        for forbidden in ["날씨", "먹은 것", "응원 준비물", "라인스코어", "경기 시작", "별점"] {
            XCTAssertFalse(text.contains("\"\(forbidden)"), "도메인에 없는 항목을 그린다: \(forbidden)")
        }
    }

    // MARK: - 6. 프레임 단위 구현

    func testRecordDetailIsFrameLevelImplementation() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        for marker in [
            "RecordDetailMediaView", "RecordDetailScoreboard", "RecordDetailStadiumView",
            "VFResultStamp", "VFStadiumHero", "VFSectionHeader",
            "이날의 일기", "가장 기억에 남는 순간", "그날의 작은 것들", "추억 카드로 공유하기", "기록 수정하기"
        ] {
            XCTAssertTrue(text.contains(marker), "기록 상세에서 \(marker)가 사라졌다")
        }
    }

    /// 화면은 의미 모델을 그리기만 한다. 매치업 해석과 결과 매핑을 뷰에서 다시 하지 않는다.
    func testViewDoesNotReparseMatchupOrResult() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        for forbidden in [
            "components(separatedBy:", "AttendanceMatchup.resolve", "KBOSeed.team(named:",
            "log.matchup", "log.ourScore", "log.opponentScore", "log.stadium", "log.diary"
        ] {
            XCTAssertFalse(text.contains(forbidden), "화면이 도메인 매핑을 다시 한다: \(forbidden)")
        }
    }

    func testDetailDomainOwnsNoViewOrColour() throws {
        for path in [
            "VictoryFairy/Domain/RecordDetail.swift",
            "VictoryFairy/Domain/Services/RecordDetailService.swift"
        ] {
            let text = try code(path)
            XCTAssertTrue(text.contains("import Foundation"))
            for forbidden in ["import SwiftUI", "import SwiftData", "import UIKit",
                              "some View", ": View", "Color.", "Font.", "@ViewBuilder"] {
                XCTAssertFalse(text.contains(forbidden), "\(path)가 화면 개념을 들고 있다: \(forbidden)")
            }
        }
    }

    func testNeitherDetailDomainNorViewUsesTheDeviceCalendar() throws {
        for path in [
            "VictoryFairy/Domain/RecordDetail.swift",
            "VictoryFairy/Domain/Services/RecordDetailService.swift",
            "VictoryFairy/Features/RecordDetail/RecordDetailViews.swift",
            "VictoryFairy/Services/VFRecordDetailFixtures.swift"
        ] {
            XCTAssertFalse(try code(path).contains("Calendar.current"), "\(path)가 기기 달력을 쓴다")
        }
    }

    // MARK: - 7. 삭제와 편집 소유권

    /// 삭제는 화면이 아니라 저장소 소유자가 수행한다.
    func testDeletionIsNotPerformedInsideTheView() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        for forbidden in [
            "modelContext", "ModelContext", "LocalAttendanceLogRepository",
            "attendanceLogRepository", "context.delete", "try context.save"
        ] {
            XCTAssertFalse(text.contains(forbidden), "화면이 저장소를 직접 만진다: \(forbidden)")
        }
        XCTAssertTrue(text.contains("appData.deleteAttendanceLog"), "삭제 소유자를 호출하지 않는다")
    }

    /// 기기 저장소에서 지우지 못하면 기록은 그대로 남는다.
    func testFailedLocalDeletionKeepsTheRecord() throws {
        let text = try code("VictoryFairy/Services/AppDataStore.swift")
        guard let range = text.range(of: "func deleteAttendanceLog") else {
            return XCTFail("삭제 함수를 찾을 수 없다")
        }
        let body = String(text[range.lowerBound...].prefix(900))
        guard let failure = body.range(of: "return .failed"),
              let removal = body.range(of: "removeLog(id:") else {
            return XCTFail("실패 경로 또는 제거 경로를 찾을 수 없다")
        }
        XCTAssertLessThan(
            failure.lowerBound, removal.lowerBound,
            "로컬 삭제에 실패했는데도 기록을 화면에서 지운다"
        )
    }

    func testDeletionFailureOutcomeCarriesAReadableMessage() {
        guard case .failed(let message) = RecordDeletionOutcome.failed("x") else {
            return XCTFail("실패 결과를 만들 수 없다")
        }
        XCTAssertEqual(message, "x")
        XCTAssertFalse(RecordDeletionOutcome.failed("x").didDelete)
        XCTAssertTrue(RecordDeletionOutcome.deleted.didDelete)

        for scenario in allScenarios {
            if let scripted = VFRecordDetailFixtures.scriptedDeletion(for: scenario),
               case .failed(let text) = scripted {
                XCTAssertFalse(text.isEmpty)
                XCTAssertFalse(text.contains("recordDetail."), "안내 문구에 식별자가 섞였다")
            }
        }
    }

    /// 편집은 기존 경로를 그대로 쓴다. 두 번째 편집기를 만들지 않는다.
    func testEditRoutePreservesRecordIdentity() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        XCTAssertTrue(text.contains("LogEditorView(editingLog:"), "기존 편집 경로를 쓰지 않는다")
        XCTAssertFalse(text.contains("LogEditorView()"), "빈 편집기를 연다")
        for (relative, source) in try appSwiftFiles() where relative.contains("RecordDetail") {
            XCTAssertFalse(source.contains("struct LogEditor"), "\(relative)에 두 번째 편집기가 있다")
        }
    }

    // MARK: - 8. 경계

    func testRecordDetailDoesNotReachTheNetworkDirectly() throws {
        let text = try code("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        for forbidden in ["URLSession", "URLRequest", "https://", "APIClient("] {
            XCTAssertFalse(text.contains(forbidden), "상세가 네트워크를 직접 부른다: \(forbidden)")
        }
    }

    func testNoLLMProviderOrKeyReachedTheRecordDetailWork() throws {
        for path in [
            "VictoryFairy/Features/RecordDetail/RecordDetailViews.swift",
            "VictoryFairy/Domain/RecordDetail.swift",
            "VictoryFairy/Domain/Services/RecordDetailService.swift",
            "VictoryFairy/Services/VFRecordDetailFixtures.swift"
        ] {
            let text = try code(path).lowercased()
            for forbidden in ["anthropic", "openai", "api_key", "apikey", "sk-", "bearer "] {
                XCTAssertFalse(text.contains(forbidden), "\(path)에 LLM 흔적이 있다: \(forbidden)")
            }
        }
    }

    func testAPIContractIsUnchanged() throws {
        let repositories = try code("VictoryFairy/Data/Repositories/VFRepositories.swift")
        for endpoint in [
            "/api/v1/seasons", "/api/v1/feed", "/api/v1/calendar",
            "/api/v1/statistics/summary", "/api/v1/statistics/stadiums",
            "/api/v1/statistics/opponents", "/api/v1/kbo/standings", "/api/v1/kbo/games"
        ] {
            XCTAssertTrue(repositories.contains(endpoint), "API 경로가 사라졌다: \(endpoint)")
        }
        XCTAssertTrue(repositories.contains("func deleteAttendanceLog(id: String) async throws"),
                      "삭제 API 계약이 바뀌었다")
    }

    func testPersistenceSchemaIsUnchanged() throws {
        let entity = try code("VictoryFairy/Data/Local/SwiftDataAttendanceLogEntity.swift")
        XCTAssertTrue(entity.contains("@Model"))
        for field in [
            "var id: String", "var gameDate: Date", "var season: Int", "var stadiumName: String",
            "var resultRawValue: String", "var ourScore: Int?", "var photoLocalRefsStorage: String",
            "var seatText: String?", "var companionType: String?", "var diaryText: String?"
        ] {
            XCTAssertTrue(entity.contains(field), "저장 스키마에서 \(field)가 사라졌다")
        }
    }

    // MARK: - 9. 다른 화면이 그대로인지

    func testHomeFeedCalendarAndStatisticsRemainFrameLevel() throws {
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
        let statistics = try code("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        for marker in ["SeasonCoverCard", "SeasonTrendChart", "activeStatisticsScenarioIdentifier"] {
            XCTAssertTrue(statistics.contains(marker), "시즌 아카이브에서 \(marker)가 사라졌다")
        }
    }

    /// 앞선 화면들의 픽스처 경계가 이번 작업으로 흔들리지 않았다.
    func testEarlierFixtureBoundariesStillHold() {
        XCTAssertNil(VFUITestConfiguration.calendarFixture)
        XCTAssertNil(VFUITestConfiguration.statisticsFixture)
        XCTAssertNil(VFUITestConfiguration.activeCalendarScenarioIdentifier)
        XCTAssertNil(VFUITestConfiguration.activeStatisticsScenarioIdentifier)
        XCTAssertEqual(VFCalendarFixtures.referenceLogs.count, 3)
        XCTAssertEqual(VFStatisticsFixtures.referenceLogs.count, 8)
    }

    /// 세 화면의 표식 접두사는 서로 겹치지 않는다.
    func testScenarioMarkersUseDistinctPrefixes() {
        for scenario in allScenarios {
            let marker = "recordDetail.scenario.\(scenario.rawValue)"
            XCTAssertFalse(marker.hasPrefix("calendar.scenario."))
            XCTAssertFalse(marker.hasPrefix("statistics.scenario."))
        }
    }
}
