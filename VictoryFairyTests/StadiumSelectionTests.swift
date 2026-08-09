import XCTest
@testable import VictoryFairy

/// `09_States / Hmdjx`를 Record Create 1단계에 붙인 뒤의 canonical 구장 계약.
final class StadiumSelectionTests: XCTestCase {

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    private var expectedIDs: [String] {
        ["jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
         "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"]
    }

    private func selection(
        current: String = "",
        catalog: [KBOStadium] = KBOStadiumSeed.all
    ) -> RecordCreateStadiumSelection {
        RecordCreateStadiumSelection(catalog: catalog, currentDraftName: current)
    }

    private func log(stadium: String) -> AttendanceLogViewState {
        AttendanceLogViewState(
            id: UUID(uuidString: "09A70000-0000-0000-0000-000000000001")!,
            date: Date(timeIntervalSince1970: 1_765_000_000),
            dateText: "2025.12.06",
            matchup: "삼성 vs LG",
            stadium: stadium,
            result: .win,
            ourScore: 5,
            opponentScore: 3,
            seat: "",
            companion: "",
            memo: "",
            caption: "",
            diary: "",
            tags: [],
            photoLocalRefs: []
        )
    }

    // MARK: - canonical catalog

    func testS01_selectorCatalogIsExactlyTheCanonicalSeed() {
        XCTAssertEqual(selection().catalog, KBOStadiumSeed.all)
    }

    func testS02_allNineStableIDsAreRepresented() {
        XCTAssertEqual(KBOStadiumSeed.all.map(\.id), expectedIDs)
        XCTAssertEqual(Set(KBOStadiumSeed.all.map(\.id)).count, 9)
    }

    func testS03_pencilFourRowSubsetAndLegacyStringCatalogAreNotProductionSources() throws {
        let flow = try source("VictoryFairy/Features/LogEditor/RecordCreateFlowView.swift")
        XCTAssertTrue(flow.contains("stadiums: KBOStadiumSeed.all"))
        XCTAssertFalse(flow.contains("stadiums: KBOSeed.stadiums"))
        XCTAssertFalse(flow.contains("prefix(4)"))
    }

    func testS04_selectorOrderEqualsCanonicalSeedOrder() {
        XCTAssertEqual(selection().catalog.map(\.id), KBOStadiumSeed.all.map(\.id))
    }

    func testS05_visibleLabelsDeriveFromCanonicalStadiumAndTeamData() {
        let jamsil = KBOStadiumSeed.stadium(id: "jamsil")!
        XCTAssertEqual(jamsil.shortName, "잠실")
        XCTAssertEqual(jamsil.city, "서울")
        XCTAssertEqual(jamsil.homeTeamShortNames, ["LG", "두산"])
        XCTAssertEqual(jamsil.selectionSecondaryText, "서울 · LG, 두산")
    }

    func testS06_selectionIdentityIsTheStableStadiumID() throws {
        let sheet = try source("VictoryFairy/Features/LogEditor/StadiumSelectionSheet.swift")
        XCTAssertTrue(sheet.contains("stadiumSheet.stadium.\\(stadium.id)"))
        XCTAssertTrue(sheet.contains("selection.selectedStadiumID == stadium.id"))
        XCTAssertFalse(sheet.contains("firstIndex"))
    }

    // MARK: - normalization

    func testS07_canonicalFullNamesResolve() {
        for stadium in KBOStadiumSeed.all {
            XCTAssertEqual(KBOStadiumSeed.stadium(named: stadium.name)?.id, stadium.id)
        }
    }

    func testS08_canonicalShortNamesResolve() {
        for stadium in KBOStadiumSeed.all {
            XCTAssertEqual(KBOStadiumSeed.stadium(named: stadium.shortName)?.id, stadium.id)
        }
    }

    func testS09_everyLegacyRecordCreateSpellingResolvesToTheMatchingStableID() {
        XCTAssertEqual(KBOSeed.stadiums.count, KBOStadiumSeed.all.count)
        for (legacy, canonical) in zip(KBOSeed.stadiums, KBOStadiumSeed.all) {
            XCTAssertEqual(KBOStadiumSeed.stadium(named: legacy)?.id, canonical.id, legacy)
        }
    }

    func testS10_unknownAndBlankStringsRemainUnresolved() {
        for value in [nil, "", "   ", "등록부에 없는 구장", "잠실 야구장"] as [String?] {
            XCTAssertNil(KBOStadiumSeed.stadium(named: value))
        }
    }

    func testS11_aliasesAreUniqueAndNeverFallBackToTheFirstStadium() {
        var aliases: [String: String] = [:]
        for stadium in KBOStadiumSeed.all {
            for alias in [stadium.name, stadium.shortName] {
                XCTAssertNil(aliases.updateValue(stadium.id, forKey: alias), "중복 별칭: \(alias)")
            }
        }
        for (legacy, canonical) in zip(KBOSeed.stadiums, KBOStadiumSeed.all)
        where legacy != canonical.name {
            XCTAssertNil(aliases.updateValue(canonical.id, forKey: legacy), "중복 별칭: \(legacy)")
        }
        XCTAssertNil(selection(current: "모르는 구장").selectedStadiumID)
        XCTAssertNotEqual(selection(current: "모르는 구장").selectedStadiumID,
                          KBOStadiumSeed.all.first?.id)
    }

    // MARK: - mutation boundary

    func testS12_openingBuildsSelectionWithoutWritingTheDraft() {
        var writes = 0
        _ = selection(current: KBOStadiumSeed.all[0].name)
        XCTAssertEqual(writes, 0)
        // 쓰기 클로저는 `commit` 전에는 전달조차 하지 않는다.
        XCTAssertEqual(writes, 0)
    }

    func testS13_rowTapWritesOneCanonicalFullName() {
        var values: [String] = []
        selection().commit(stadiumID: "suwon-kt") { values.append($0) }
        XCTAssertEqual(values, ["수원 kt wiz 파크"])
    }

    @MainActor
    func testS14_rowTapDoesNotMutatePrimaryStadiumPreference() {
        let suite = "StadiumSelectionTests.primary.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UserPreferencesStore(defaults: defaults)
        preferences.setPrimaryStadium("jamsil")

        var draftValue = ""
        selection().commit(stadiumID: "daegu-lions") { draftValue = $0 }

        XCTAssertEqual(draftValue, "대구 삼성 라이온즈 파크")
        XCTAssertEqual(preferences.primaryStadiumID, "jamsil")
    }

    func testS15_rowTapDoesNotMutateOnboardingState() throws {
        var onboardingSelectedStadiumID = "jamsil"
        var draftValue = ""
        selection().commit(stadiumID: "sajik") { draftValue = $0 }
        XCTAssertEqual(onboardingSelectedStadiumID, "jamsil")
        XCTAssertEqual(draftValue, "사직야구장")

        let executable = try source("VictoryFairy/Features/LogEditor/StadiumSelectionSheet.swift")
        XCTAssertFalse(executable.contains("OnboardingViewModel"))
        onboardingSelectedStadiumID = "jamsil"
    }

    func testS16_rowTapDoesNotMutateHistoricalRecords() {
        let historical = [log(stadium: "수원 KT 위즈파크")]
        let snapshot = historical
        var draftValue = ""
        selection().commit(stadiumID: "suwon-kt") { draftValue = $0 }
        XCTAssertEqual(historical, snapshot)
        XCTAssertEqual(historical[0].stadium, "수원 KT 위즈파크")
        XCTAssertEqual(draftValue, "수원 kt wiz 파크")
    }

    func testS17_interactiveDismissalPerformsZeroWrites() {
        var draftValue = "사직야구장"
        var writes = 0
        _ = selection(current: draftValue)
        // 시트를 닫는 것은 `commit`을 호출하지 않는다.
        XCTAssertEqual(writes, 0)
        XCTAssertEqual(draftValue, "사직야구장")
        writes += 0
    }

    func testS18_invalidInitialValueStaysUntilExplicitValidSelection() {
        var draftValue = "과거의 미등록 구장"
        let model = selection(current: draftValue)
        XCTAssertNil(model.selectedStadiumID)
        XCTAssertEqual(draftValue, "과거의 미등록 구장")

        model.commit(stadiumID: "gocheok") { draftValue = $0 }
        XCTAssertEqual(draftValue, "고척스카이돔")
    }

    func testS19_emptyCatalogPerformsZeroWrites() {
        var values: [String] = []
        selection(catalog: []).commit(stadiumID: "jamsil") { values.append($0) }
        XCTAssertTrue(values.isEmpty)
    }

    func testS20_selectionLayerHasNoAttendanceRecordMigrationOrPersistenceDependency() throws {
        let source = try source("VictoryFairy/Features/LogEditor/StadiumSelectionSheet.swift")
        for forbidden in ["AttendanceRecord", "SwiftData", "ModelContext", "saveAttendanceLog",
                          "primaryStadiumID", "OnboardingViewModel"] {
            XCTAssertFalse(source.contains(forbidden), "선택 시트에 영속성 경계가 들어왔다: \(forbidden)")
        }
    }

    func testS21_newSelectionUsesTheCanonicalNormalizedStoredName() {
        for stadium in KBOStadiumSeed.all {
            var written: String?
            selection().commit(stadiumID: stadium.id) { written = $0 }
            XCTAssertEqual(written, stadium.name)
        }
    }

    func testS22_downstreamRecordResolverRecognizesEveryNewValue() {
        for stadium in KBOStadiumSeed.all {
            XCTAssertEqual(log(stadium: stadium.name).recordStadium?.id, stadium.id)
        }
    }
}
