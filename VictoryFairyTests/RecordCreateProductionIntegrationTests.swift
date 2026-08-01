import XCTest
@testable import VictoryFairy

/// 세 단계 기록 작성 흐름을 **제품 생성 경로에 붙인 뒤**의 계약.
///
/// 지키는 것은 네 가지다.
/// 1. 다섯 개 생성 경로가 흐름을, 두 개 수정 경로가 지금 편집기를 쓴다.
/// 2. 새로 만드는 기록에는 고르지 않은 기분이 몰래 실리지 않는다.
/// 3. 지금 있던 보조 기능 넷(티켓 OCR·경기 자동 찾기·사진 분석·AI 초안)이 그대로
///    닿을 수 있고, 모두 **같은 서비스와 같은 매핑**을 쓴다.
/// 4. 어떤 보조 동작도 스스로 저장하지 않는다.
final class RecordCreateProductionIntegrationTests: XCTestCase {

    // MARK: - 소스 접근

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }

    private func source(_ relativePath: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("소스를 찾을 수 없다: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func executableSource(_ relativePath: String) throws -> String {
        stripComments(try source(relativePath))
    }

    /// 주석과 문자열 밖의 코드만 남긴다. 주석에 적힌 이름이 계약처럼 읽히지 않게 한다.
    private func stripComments(_ text: String) -> String {
        var output = ""
        let characters = Array(text)
        var index = 0
        var inLineComment = false, inBlockComment = false, inString = false
        while index < characters.count {
            let character = characters[index]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            if inLineComment {
                if character == "\n" { inLineComment = false; output.append(character) }
                index += 1; continue
            }
            if inBlockComment {
                if character == "*", next == "/" { inBlockComment = false; index += 2; continue }
                index += 1; continue
            }
            if inString {
                if character == "\\" { index += 2; continue }
                if character == "\"" { inString = false }
                output.append(character); index += 1; continue
            }
            if character == "/", next == "/" { inLineComment = true; index += 2; continue }
            if character == "/", next == "*" { inBlockComment = true; index += 2; continue }
            if character == "\"" { inString = true }
            output.append(character); index += 1
        }
        return output
    }

    /// 앱 소스 전체. 파일 이름과 주석을 걷어낸 본문을 함께 준다.
    private func productionSources() throws -> [(name: String, body: String)] {
        let urls = (FileManager.default.enumerator(at: Self.appSourceRoot, includingPropertiesForKeys: nil)?
            .allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
        return try urls.map { url in
            (url.lastPathComponent, stripComments(try String(contentsOf: url, encoding: .utf8)))
        }
    }

    private var flowSource: String { (try? executableSource("Features/LogEditor/RecordCreateFlowView.swift")) ?? "" }
    private var assistanceSource: String { (try? executableSource("Features/LogEditor/RecordCreateAssistance.swift")) ?? "" }
    private var mappingSource: String { (try? executableSource("Features/LogEditor/RecordEditorAssistance.swift")) ?? "" }
    private var step1Source: String { (try? executableSource("Features/LogEditor/RecordCreateStep1View.swift")) ?? "" }
    private var step3Source: String { (try? executableSource("Features/LogEditor/RecordCreateStep3View.swift")) ?? "" }
    private var editorSource: String { (try? executableSource("Features/LogEditor/LogEditorView.swift")) ?? "" }

    // MARK: - 표본

    private static let fixedID = UUID(uuidString: "6B1E1A2C-0000-4000-8000-00000000ABCD")!
    private static let calendarDate = Date.vfDate(year: 2026, month: 4, day: 16)
    private static let today = Date.vfDate(year: 2026, month: 5, day: 2)

    private func makeRecord(tags: [String]) -> AttendanceLogViewState {
        AttendanceLogViewState(
            id: Self.fixedID,
            date: Date.vfDate(year: 2026, month: 4, day: 12),
            dateText: "4월 12일",
            matchup: "삼성 vs LG",
            stadium: "잠실야구장",
            result: .win,
            ourScore: 6,
            opponentScore: 3,
            seat: "3루 원정석 K열",
            companion: "엄마랑",
            memo: "9회말 역전",
            caption: "",
            diary: "첫 줄",
            tags: tags,
            photoLocalRefs: ["photo-a"],
            gameSource: "adminResult",
            linkedKBOGameID: "kbo-2026-04-12-1",
            officialRecordURL: "https://example.com/record"
        )
    }

    private func editDraft(tags: [String]) -> RecordEditorDraft {
        let record = makeRecord(tags: tags)
        return RecordEditorDraft.make(
            mode: .edit(recordID: record.id),
            existingRecord: record,
            preferredFavoriteTeamName: nil,
            defaultMoodTag: "짜릿함",
            defaultHighlightTag: "홈런",
            fallbackDate: Self.today
        )
    }

    /// 서버가 돌려주는 모양 그대로 후보를 만든다. DTO는 디코딩으로만 만들어진다.
    private func makeCandidate(
        status: String = "final",
        homeScore: Int? = 3,
        awayScore: Int? = 6,
        highlightTags: [String] = ["역전승"]
    ) throws -> KBOGameCandidateDTO {
        let json: [String: Any] = [
            "gameID": "kbo-2026-04-16-1",
            "date": "2026-04-16",
            "homeTeamID": "lg-twins",
            "awayTeamID": "samsung-lions",
            "homeTeamName": "LG 트윈스",
            "awayTeamName": "삼성 라이온즈",
            "stadiumName": "잠실야구장",
            "status": status,
            "homeScore": homeScore as Any,
            "awayScore": awayScore as Any,
            "source": "adminResult",
            "sourceLabel": "구단 공식 기록",
            "sourceDisclosure": "구단이 공개한 기록을 그대로 옮겼어요.",
            "officialLinks": ["kboRecordURL": "https://example.com/kbo/record"],
            "highlightTags": highlightTags
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(KBOGameCandidateDTO.self, from: data)
    }

    private func makePhotoAnalysis(
        mood: String,
        highlight: String,
        hint: String?
    ) throws -> PhotoAnalysisDTO {
        var json: [String: Any] = [
            "summaryText": "잠실 야경",
            "suggestedMoodTags": [mood],
            "suggestedHighlightTags": [highlight]
        ]
        if let hint { json["diaryHintText"] = hint }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(PhotoAnalysisDTO.self, from: data)
    }

    // MARK: - 1~7. 다섯 개 생성 경로가 흐름을 쓴다

    /// 경로마다 **그 파일에서** 흐름을 여는지 본다. 이름 개수만 세지 않는다.
    func test01_eachProductionCreateRouteOwnsTheFlow() throws {
        let expectations: [(path: String, call: String)] = [
            ("Features/Home/HomeView.swift", "RecordCreateFlowView(context: .home())"),
            ("Features/Feed/FeedViews.swift", "RecordCreateFlowView(context: .feed())"),
            ("Features/Calendar/CalendarViews.swift", "RecordCreateFlowView(context: .calendar(date: route.date))"),
            ("Features/Statistics/StatisticsViews.swift", "RecordCreateFlowView(context: .statisticsStadium())"),
            ("Features/Statistics/StatisticsViews.swift", "RecordCreateFlowView(context: .statisticsOpponent())")
        ]
        for expectation in expectations {
            let body = try executableSource(expectation.path)
            XCTAssertTrue(body.contains(expectation.call),
                          "\(expectation.path)가 \(expectation.call)를 열지 않는다")
        }
    }

    func test02_exactlyFiveCreateCallSitesExist() throws {
        var sites: [String] = []
        for entry in try productionSources() where entry.name != "RecordCreateFlowView.swift" {
            for line in entry.body.split(separator: "\n") where line.contains("RecordCreateFlowView(context:") {
                sites.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(sites.count, 5, "생성 호출부가 다섯이 아니다: \(sites)")
    }

    func test03_exactlyTwoEditCallSitesRemain() throws {
        var sites: [String] = []
        for entry in try productionSources() where entry.name != "LogEditorView.swift" {
            for line in entry.body.split(separator: "\n") where line.contains("LogEditorView(") {
                sites.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(sites.count, 2, "수정 호출부가 둘이 아니다: \(sites)")
        XCTAssertTrue(sites.allSatisfy { $0.contains("editingLog:") }, "생성 호출부가 편집기에 남았다")
        XCTAssertTrue(sites.contains { $0.hasPrefix("HomeView.swift") && $0.contains("startsAIPreflightOnAppear: true") },
                      "홈 AI 사전 점검 수정 경로가 사라졌다")
        XCTAssertTrue(sites.contains { $0.hasPrefix("RecordDetailViews.swift") },
                      "기록 상세 수정 경로가 사라졌다")
    }

    func test04_noCreateRouteRemainsOnTheCurrentEditor() throws {
        for entry in try productionSources() where entry.name != "LogEditorView.swift" {
            XCTAssertFalse(entry.body.contains("LogEditorView()"), "\(entry.name)에 빈 생성 편집기가 남았다")
            XCTAssertFalse(entry.body.contains("LogEditorView(initialDate:"),
                           "\(entry.name)에 날짜 생성 편집기가 남았다")
        }
    }

    func test05_noEditRouteMovedToTheFlow() {
        // 흐름에는 수정 모드가 없다 — 기록 정체성도, 수정 저장 경계도 갖지 않는다.
        for forbidden in ["editingLog", "editingRecordID", ".edit(", "updateAttendanceLog"] {
            XCTAssertFalse(flowSource.contains(forbidden), "흐름에 수정 개념 \(forbidden)이 생겼다")
        }
        XCTAssertTrue(flowSource.contains("mode: RecordEditorMode { .create("), "흐름이 생성 모드가 아니다")
    }

    func test06_theOnlyOtherFlowHostIsTheDebugStagingHost() throws {
        var hosts: [String] = []
        for entry in try productionSources() where entry.name != "RecordCreateFlowView.swift" {
            for line in entry.body.split(separator: "\n") where line.contains("RecordCreateStagedHostView(") {
                hosts.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(hosts.count, 1, "검증 호스트를 부르는 곳이 늘었다: \(hosts)")
        XCTAssertTrue(hosts[0].hasPrefix("AppRootView.swift"))
        let root = try source("AppRootView.swift")
        XCTAssertTrue(root.contains("VFUITestConfiguration.activeRecordCreateStagedScenarioIdentifier"),
                      "검증 호스트의 픽스처 게이트가 사라졌다")
    }

    func test07_releaseCannotActivateAnyFixtureRoute() throws {
        let configuration = try source("Services/VFUITestConfiguration.swift")
        for accessor in ["recordCreateStagedFixture", "recordCreateStagedInitialDate",
                         "recordCreateStagedInitialStep", "activeRecordCreateStagedScenarioIdentifier"] {
            guard let range = configuration.range(of: "static var \(accessor)") else {
                return XCTFail("\(accessor)가 없다")
            }
            let body = String(configuration[range.lowerBound...].prefix(700))
            guard let end = body.range(of: "#endif") else { return XCTFail("\(accessor)에 #endif가 없다") }
            let gated = String(body[..<end.upperBound])
            XCTAssertTrue(gated.contains("#if DEBUG"), "\(accessor)가 DEBUG 밖에 있다")
            XCTAssertTrue(gated.contains("#else"), "\(accessor)에 Release 가지가 없다")
            XCTAssertTrue(gated.contains("return nil"), "\(accessor)의 Release 값이 nil이 아니다")
        }
    }

    // MARK: - 8~14. 시작 컨텍스트가 아무것도 지어내지 않는다

    func test08_everyOriginHasExactlyOneFactory() {
        XCTAssertEqual(RecordCreateLaunchContext.Origin.allCases.count, 5)
        XCTAssertEqual(RecordCreateLaunchContext.home().origin, .home)
        XCTAssertEqual(RecordCreateLaunchContext.feed().origin, .feed)
        XCTAssertEqual(RecordCreateLaunchContext.calendar(date: Self.calendarDate).origin, .calendar)
        XCTAssertEqual(RecordCreateLaunchContext.statisticsStadium().origin, .statisticsStadium)
        XCTAssertEqual(RecordCreateLaunchContext.statisticsOpponent().origin, .statisticsOpponent)
    }

    func test09_calendarPreservesTheSuppliedDateExactly() {
        let context = RecordCreateLaunchContext.calendar(date: Self.calendarDate)
        XCTAssertEqual(context.initialDate, Self.calendarDate)
        let draft = context.makeDraft(today: Self.today)
        XCTAssertEqual(draft.date, Self.calendarDate, "캘린더가 정해 준 날짜가 바뀌었다")
        XCTAssertNotEqual(draft.date, Self.today, "오늘로 바꿔 버렸다")
    }

    func test10_routesWithoutASuppliedDateUseTodayAndNothingElse() {
        for context in [RecordCreateLaunchContext.home(), .feed(), .statisticsStadium(), .statisticsOpponent()] {
            XCTAssertNil(context.initialDate, "\(context.origin)가 날짜를 지어냈다")
            XCTAssertEqual(context.makeDraft(today: Self.today).date, Self.today)
        }
    }

    func test11_statisticsRoutesFabricateNoStadiumOrOpponent() {
        for context in [RecordCreateLaunchContext.statisticsStadium(), .statisticsOpponent()] {
            let draft = context.makeDraft(today: Self.today)
            XCTAssertTrue(draft.stadiumName.isEmpty, "\(context.origin)가 구장을 지어냈다")
            XCTAssertTrue(draft.opponentTeamName.isEmpty, "\(context.origin)가 상대팀을 지어냈다")
        }
        // 화면이 갖고 있는 통계 값이 흐름으로 새어 들어갈 길이 없다.
        let statistics = (try? executableSource("Features/Statistics/StatisticsViews.swift")) ?? ""
        XCTAssertFalse(statistics.contains("RecordCreateFlowView(context: .statisticsStadium(stadium"),
                       "구장을 넘기는 인자가 생겼다")
        XCTAssertFalse(statistics.contains("RecordCreateFlowView(context: .statisticsOpponent(opponent"),
                       "상대팀을 넘기는 인자가 생겼다")
    }

    func test12_everyRouteStartsFromAnEmptyDraft() {
        for context in [RecordCreateLaunchContext.home(), .feed(), .calendar(date: Self.calendarDate),
                        .statisticsStadium(), .statisticsOpponent()] {
            let draft = context.makeDraft(today: Self.today)
            XCTAssertNil(draft.editingRecordID, "\(context.origin)가 기록 정체성을 만들었다")
            XCTAssertTrue(draft.favoriteTeamName.isEmpty, "\(context.origin)가 응원팀을 미리 넣었다")
            XCTAssertTrue(draft.opponentTeamName.isEmpty)
            XCTAssertTrue(draft.stadiumName.isEmpty)
            XCTAssertNil(draft.result, "\(context.origin)가 결과를 지어냈다")
            XCTAssertNil(draft.ourScore)
            XCTAssertNil(draft.opponentScore)
            XCTAssertTrue(draft.seat.isEmpty)
            XCTAssertTrue(draft.companion.isEmpty)
            XCTAssertTrue(draft.shortMemo.isEmpty)
            XCTAssertTrue(draft.diary.isEmpty)
            XCTAssertTrue(draft.photo.refs.isEmpty, "\(context.origin)가 사진을 지어냈다")
            XCTAssertNil(draft.linkedKBOGameID)
            XCTAssertNil(draft.officialRecordURL)
            XCTAssertNil(draft.gameSource)
        }
    }

    func test13_theFlowBuildsExactlyOneDraft() {
        XCTAssertEqual(flowSource.components(separatedBy: "RecordEditorDraft.make(").count - 1, 1,
                       "초안을 만드는 곳이 둘 이상이다")
        XCTAssertTrue(flowSource.contains("_draft = State(initialValue: context.makeDraft(today: Date()))"),
                      "흐름이 시작 컨텍스트를 통하지 않고 초안을 만든다")
        for forbidden in ["struct RecordCreateDraft", "struct CreateDraft", "class RecordCreateModel"] {
            XCTAssertFalse(flowSource.contains(forbidden), "두 번째 초안 \(forbidden)이 생겼다")
        }
    }

    func test14_initializationPersistsNothing() {
        for forbidden in ["UserDefaults", "AppStorage", "modelContext", "saveAttendanceLog", "insert("] {
            XCTAssertFalse(mappingSource.contains(forbidden), "매핑이 \(forbidden)을 건드린다")
        }
        // 흐름이 저장 경계를 부르는 곳은 하나뿐이다.
        XCTAssertEqual(flowSource.components(separatedBy: "appData.saveAttendanceLog(").count - 1, 1,
                       "저장 호출부가 둘 이상이다")
    }

    // MARK: - 15~20. 숨은 기본 기분 교정

    func test15_newCreateDraftHasNoMood() {
        XCTAssertEqual(RecordCreateFlowView.newRecordMoodTag, "", "새 기록의 기분이 비어 있지 않다")
        for context in [RecordCreateLaunchContext.home(), .feed(), .calendar(date: Self.calendarDate),
                        .statisticsStadium(), .statisticsOpponent()] {
            XCTAssertTrue(context.makeDraft(today: Self.today).moodTag.isEmpty,
                          "\(context.origin)가 기분을 미리 넣었다")
        }
    }

    func test16_noChipIsSelectedForANewDraft() {
        let draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        XCTAssertNil(RecordCreateStep3View.moodSelection(for: draft.moodTag),
                     "고르지 않았는데 칩이 선택돼 보인다")
    }

    func test17_anUnchosenMoodIsNotSaved() {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        draft.favoriteTeamName = KBOSeed.teams[0].name
        draft.opponentTeamName = KBOSeed.teams[1].name
        draft.stadiumName = KBOSeed.stadiums[0]
        draft.result = .win
        XCTAssertFalse(draft.saveTags.contains(""), "이름 없는 태그가 저장에 실린다")
        XCTAssertEqual(draft.saveTags, [RecordCreateFlowView.defaultHighlightTag],
                       "고르지 않은 기분이 저장 태그에 남았다")
    }

    func test18_choosingAMoodReplacesTheEmptyValueAndIsSaved() {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        for mood in RecordCreateStep3View.moods {
            draft.moodTag = mood
            XCTAssertEqual(RecordCreateStep3View.moodSelection(for: draft.moodTag), mood)
            XCTAssertEqual(draft.saveTags.first, mood, "고른 기분이 저장 태그의 첫 자리가 아니다")
        }
    }

    func test19_editInitializationKeepsTheExistingMood() {
        let draft = editDraft(tags: ["감동", "끝내기"])
        XCTAssertEqual(draft.moodTag, "감동", "수정하기의 기분이 바뀌었다")
        XCTAssertEqual(draft.highlightTag, "끝내기")
        XCTAssertEqual(draft.saveTags, ["감동", "끝내기"])
    }

    func test20_anUnknownStoredMoodSurvivesEditingAndSaving() {
        let draft = editDraft(tags: ["설렘", "홈런"])
        XCTAssertEqual(draft.moodTag, "설렘", "모르는 기분이 지워졌다")
        XCTAssertNil(RecordCreateStep3View.moodSelection(for: draft.moodTag), "모르는 값이 칩으로 선택돼 보인다")
        XCTAssertEqual(draft.saveTags.first, "설렘", "모르는 기분이 저장에서 사라졌다")
    }

    // MARK: - 21~30. 보조 기능 파리티 — 같은 서비스, 같은 매핑

    func test21_ticketOCRIsReachableFromStepOneAndReusesTheMapping() {
        XCTAssertTrue(step1Source.contains("RecordCreateStep1AssistanceSection("), "1단계에 도우미 영역이 없다")
        XCTAssertTrue(assistanceSource.contains("기록 도우미"), "도우미 영역의 제목이 없다")
        XCTAssertTrue(assistanceSource.contains("티켓에서 불러오기"), "1단계에서 티켓 OCR에 닿을 수 없다")
        XCTAssertTrue(assistanceSource.contains("TicketOCRView(currentFavoriteTeamName:"),
                      "지금 쓰는 티켓 OCR 화면을 쓰지 않는다")
        XCTAssertTrue(assistanceSource.contains("RecordEditorAssistance.applyTicketSuggestion("),
                      "티켓 매핑을 다시 만들었다")
        XCTAssertTrue(editorSource.contains("RecordEditorAssistance.applyTicketSuggestion("),
                      "지금 편집기가 같은 매핑을 쓰지 않는다")
    }

    func test22_ticketMappingOnlyTouchesSupportedFields() {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        draft.diary = "직접 쓴 일기"
        draft.moodTag = "벅차오름"
        let suggestion = TicketFieldSuggestion(
            gameDate: Self.calendarDate,
            favoriteTeamName: KBOSeed.teams[0].name,
            opponentTeamName: KBOSeed.teams[1].name,
            stadiumName: KBOSeed.stadiums[0],
            seatText: "3루 K열 12번",
            rawText: "티켓 원문"
        )
        let message = RecordEditorAssistance.applyTicketSuggestion(suggestion, to: &draft)

        XCTAssertEqual(draft.date, Self.calendarDate)
        XCTAssertEqual(draft.favoriteTeamName, KBOSeed.teams[0].name)
        XCTAssertEqual(draft.opponentTeamName, KBOSeed.teams[1].name)
        XCTAssertEqual(draft.stadiumName, KBOSeed.stadiums[0])
        XCTAssertEqual(draft.seat, "3루 K열 12번")
        // 티켓이 말하지 않은 것은 건드리지 않는다.
        XCTAssertEqual(draft.diary, "직접 쓴 일기")
        XCTAssertEqual(draft.moodTag, "벅차오름")
        XCTAssertNil(draft.result)
        XCTAssertNil(draft.ourScore)
        XCTAssertFalse(message.isEmpty, "확인을 부탁하는 안내가 없다")
    }

    func test23_kboLookupIsReachableFromStepOneAndReusesTheService() {
        XCTAssertTrue(assistanceSource.contains("경기 자동 찾기"), "1단계에서 경기 찾기에 닿을 수 없다")
        XCTAssertTrue(step1Source.contains("onFindGames: onFindGames"), "1단계가 찾기 동작을 연결하지 않는다")
        XCTAssertTrue(flowSource.contains("appData.fetchKBOGameCandidates(date:"),
                      "지금 쓰는 경기 조회 서비스를 쓰지 않는다")
        XCTAssertTrue(editorSource.contains("appData.fetchKBOGameCandidates(date:"),
                      "지금 편집기의 조회가 사라졌다")
        XCTAssertTrue(assistanceSource.contains("KBOGameCandidateSelectionSheet("),
                      "지금 쓰는 후보 선택 시트를 쓰지 않는다")
        XCTAssertTrue(assistanceSource.contains("RecordEditorAssistance.applyKBOGameCandidate("),
                      "경기 매핑을 다시 만들었다")
        XCTAssertTrue(editorSource.contains("RecordEditorAssistance.applyKBOGameCandidate("),
                      "지금 편집기가 같은 매핑을 쓰지 않는다")
    }

    func test24_kboCandidateApplicationCarriesSourceAndOfficialURL() throws {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        draft.favoriteTeamName = "삼성 라이온즈"
        let candidate = try makeCandidate()
        let message = RecordEditorAssistance.applyKBOGameCandidate(
            candidate, to: &draft, favoriteTeamID: "samsung-lions",
            lookupSource: "kboOpenAPI", shouldOverwriteDiary: false
        )

        XCTAssertEqual(draft.linkedKBOGameID, "kbo-2026-04-16-1", "경기 정체성이 실리지 않았다")
        XCTAssertEqual(draft.officialRecordURL, "https://example.com/kbo/record", "공식 기록 주소가 사라졌다")
        XCTAssertEqual(draft.gameSource, "adminResult", "출처가 사라졌다")
        XCTAssertEqual(draft.opponentTeamName, "LG 트윈스")
        XCTAssertEqual(draft.stadiumName, "잠실야구장")
        XCTAssertEqual(draft.result, .win)
        XCTAssertEqual(draft.ourScore, 6)
        XCTAssertEqual(draft.opponentScore, 3)
        XCTAssertFalse(message.isEmpty, "확인을 부탁하는 안내가 없다")
    }

    func test25_kboApplicationNeverOverwritesWrittenTextWithoutAsking() throws {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        draft.favoriteTeamName = "삼성 라이온즈"
        draft.diary = "내가 쓴 일기"
        draft.shortMemo = "내가 쓴 한 줄"
        let candidate = try makeCandidate()

        XCTAssertTrue(
            RecordEditorAssistance.requiresDiaryOverwriteConfirmation(
                for: candidate, draft: draft, favoriteTeamID: "samsung-lions"
            ),
            "쓴 일기가 있는데 묻지 않는다"
        )
        _ = RecordEditorAssistance.applyKBOGameCandidate(
            candidate, to: &draft, favoriteTeamID: "samsung-lions",
            lookupSource: nil, shouldOverwriteDiary: false
        )
        XCTAssertEqual(draft.diary, "내가 쓴 일기", "묻지 않고 일기를 덮어썼다")
        XCTAssertEqual(draft.shortMemo, "내가 쓴 한 줄", "묻지 않고 한 줄 메모를 덮어썼다")
    }

    func test26_photoAnalysisIsReachableFromStepThreeAndReusesTheService() {
        XCTAssertTrue(step3Source.contains("사진 분석"), "3단계에서 사진 분석에 닿을 수 없다")
        XCTAssertTrue(step3Source.contains("recordCreate.step3.analyzePhotos"), "사진 분석 동작의 식별자가 없다")
        XCTAssertTrue(assistanceSource.contains("appData.analyzePhotos(localRefs:"),
                      "지금 쓰는 사진 분석 서비스를 쓰지 않는다")
        XCTAssertTrue(assistanceSource.contains("PhotoAnalysisSelectionSheet("), "선택 고지 시트를 쓰지 않는다")
        XCTAssertTrue(assistanceSource.contains("PhotoAnalysisResultSheet("), "결과 확인 시트를 쓰지 않는다")
        XCTAssertTrue(assistanceSource.contains("RecordEditorAssistance.applyPhotoAnalysis("),
                      "사진 분석 매핑을 다시 만들었다")
        XCTAssertTrue(editorSource.contains("RecordEditorAssistance.applyPhotoAnalysis("),
                      "지금 편집기가 같은 매핑을 쓰지 않는다")
        // 사진이 있어야 열린다 — 지금 편집기와 같은 조건이다.
        XCTAssertTrue(flowSource.contains("guard !draft.photo.refs.isEmpty else"),
                      "사진 없이도 분석을 시작한다")
    }

    func test27_photoAnalysisAppliesOnlyKnownFieldsAndKeepsPhotos() throws {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        draft.photo = RecordEditorPhotoDraft(originalRefs: [], refs: ["photo-a", "photo-b"])
        draft.diary = "먼저 쓴 글"
        let analysis = try makePhotoAnalysis(mood: "감동", highlight: "끝내기", hint: "9회 끝내기")
        RecordEditorAssistance.applyPhotoAnalysis(analysis, to: &draft)

        XCTAssertEqual(draft.moodTag, "감동", "아는 기분이 적용되지 않았다")
        XCTAssertEqual(draft.highlightTag, "끝내기")
        XCTAssertEqual(draft.diary, "먼저 쓴 글\n\n9회 끝내기", "쓴 글을 지웠다")
        XCTAssertEqual(draft.photo.refs, ["photo-a", "photo-b"], "사진이 사라졌다")

        // 모르는 어휘는 넣지 않는다.
        var other = draft
        let unknown = try makePhotoAnalysis(mood: "무아지경", highlight: "삼중살", hint: nil)
        RecordEditorAssistance.applyPhotoAnalysis(unknown, to: &other)
        XCTAssertEqual(other.moodTag, "감동", "모르는 기분을 넣었다")
        XCTAssertEqual(other.highlightTag, "끝내기", "모르는 하이라이트를 넣었다")
    }

    func test28_aiDraftIsReachableFromStepThreeAndReusesTheProvider() {
        XCTAssertTrue(step3Source.contains("AI 초안"), "3단계에서 AI 초안에 닿을 수 없다")
        XCTAssertTrue(step3Source.contains("recordCreate.step3.aiDraft"), "AI 초안 동작의 식별자가 없다")
        XCTAssertTrue(assistanceSource.contains("AIPreflightDisclosureSheet"), "사전 고지를 건너뛴다")
        XCTAssertTrue(assistanceSource.contains("AIDiaryDraftSheet("), "초안 확인 화면이 없다")
        XCTAssertTrue(assistanceSource.contains("appData.createDiaryDraft("), "지금 쓰는 제공자를 쓰지 않는다")
        XCTAssertTrue(assistanceSource.contains("appData.createTemplateDraft("), "기본 문장 경로가 없다")
        XCTAssertTrue(assistanceSource.contains("RecordEditorAssistance.makeDiaryDraftRequest("),
                      "AI 요청 매핑을 다시 만들었다")
        XCTAssertTrue(editorSource.contains("RecordEditorAssistance.makeDiaryDraftRequest("),
                      "지금 편집기가 같은 요청 매핑을 쓰지 않는다")
        // 새 제공자도 새 키도 만들지 않았다.
        for forbidden in ["apiKey", "Authorization:", "openai", "anthropic", "URLSession("] {
            XCTAssertFalse(assistanceSource.lowercased().contains(forbidden.lowercased()),
                           "새 AI 경로 \(forbidden)이 생겼다")
        }
    }

    func test29_aiDraftRequestOmitsUnchosenTags() {
        var draft = RecordCreateLaunchContext.home().makeDraft(today: Self.today)
        draft.favoriteTeamName = KBOSeed.teams[0].name
        draft.opponentTeamName = KBOSeed.teams[1].name
        draft.stadiumName = KBOSeed.stadiums[0]
        draft.result = .win
        draft.ourScore = 6
        draft.opponentScore = 3
        draft.highlightTag = ""
        let request = RecordEditorAssistance.makeDiaryDraftRequest(from: draft, tone: "담백하게")
        XCTAssertTrue(request.moodTags.isEmpty, "고르지 않은 기분을 서버로 보낸다")
        XCTAssertTrue(request.highlightTags.isEmpty, "빈 하이라이트를 서버로 보낸다")
        XCTAssertEqual(request.scoreText, "6:3 승", "점수 문구가 달라졌다")
    }

    func test30_generatedTextIsAlwaysReviewedBeforeItReplacesWriting() {
        XCTAssertEqual(
            RecordEditorAssistance.diaryApplyPlan(for: "  ", existingDiary: ""),
            .none
        )
        XCTAssertEqual(
            RecordEditorAssistance.diaryApplyPlan(for: "새 초안", existingDiary: ""),
            .replaceEmpty("새 초안")
        )
        XCTAssertEqual(
            RecordEditorAssistance.diaryApplyPlan(for: "새 초안", existingDiary: "이미 쓴 글"),
            .needsChoice("새 초안")
        )
        XCTAssertEqual(RecordEditorAssistance.appendingDiary("새 초안", to: "이미 쓴 글"), "이미 쓴 글\n\n새 초안")
        XCTAssertEqual(RecordEditorAssistance.appendingDiary("새 초안", to: "   "), "새 초안")
    }

    // MARK: - 31~34. 어떤 보조 동작도 스스로 저장하지 않는다

    func test31_noAssistanceSurfaceTouchesTheSaveBoundary() {
        for boundary in ["saveAttendanceLog", "updateAttendanceLog", "CreateAttendanceLogRequest",
                         "UpdateAttendanceLogRequest"] {
            XCTAssertFalse(assistanceSource.contains(boundary), "보조 기능이 \(boundary)을 부른다")
            XCTAssertFalse(mappingSource.contains(boundary), "매핑이 \(boundary)을 부른다")
            XCTAssertFalse(step1Source.contains(boundary), "1단계 화면이 \(boundary)을 부른다")
            XCTAssertFalse(step3Source.contains(boundary), "3단계 화면이 \(boundary)을 부른다")
        }
    }

    func test32_assistanceFailurePreservesTheDraft() throws {
        // 실패 경로가 하는 일은 안내 문구 하나뿐이다. 초안·사진에 손대지 않는다.
        guard let range = assistanceSource.range(of: "private func analyzePhotos(") else {
            return XCTFail("사진 분석 함수가 없다")
        }
        let body = String(assistanceSource[range.lowerBound...].prefix(900))
        guard let catchRange = body.range(of: "} catch {") else { return XCTFail("실패 가지가 없다") }
        guard let end = body.range(of: "\n    }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("실패 가지의 끝을 찾지 못했다")
        }
        let failureBranch = String(body[catchRange.upperBound..<end.lowerBound])
        XCTAssertTrue(failureBranch.contains("state.message ="), "실패를 알리지 않는다")
        XCTAssertFalse(failureBranch.contains("draft"), "실패가 초안을 건드린다")
        XCTAssertFalse(failureBranch.contains("photo"), "실패가 사진을 건드린다")
    }

    func test33_theFlowKeepsOneSaveBoundaryAndTheOfflineFallback() {
        XCTAssertTrue(flowSource.contains("appData.saveAttendanceLog("), "저장 경계가 사라졌다")
        XCTAssertEqual(flowSource.components(separatedBy: "appData.saveAttendanceLog(").count - 1, 1)
        // 서버 동기화 실패는 여전히 저장으로 친다 — 지금 편집기와 같은 정책이다.
        XCTAssertFalse(flowSource.contains("guard didSave else"), "오프라인 정책이 바뀌었다")
        XCTAssertTrue(flowSource.contains("guard appData.lastSaveMessage != nil else { return }"),
                      "저장이 아예 이뤄지지 않은 경우의 방어가 사라졌다")
    }

    func test34_duplicateSubmissionIsStillGuarded() {
        XCTAssertTrue(flowSource.contains("guard !isSaving else { return }"), "중복 저장 방어가 사라졌다")
        XCTAssertEqual(flowSource.components(separatedBy: "guard !isSaving else { return }").count - 1, 2,
                       "최소 저장과 완성 저장 둘 다 방어하지 않는다")
    }

    // MARK: - 35~38. 지금 편집기와 스키마가 그대로다

    func test35_theCurrentEditorStillOwnsAllFourCapabilities() {
        for capability in ["TicketOCRView(", "AIPreflightDisclosureSheet", "AIDiaryDraftSheet(",
                           "PhotoAnalysisSelectionSheet(", "PhotoAnalysisResultSheet(",
                           "KBOGameCandidateSelectionSheet(", "lookupKBOGameCandidates()",
                           "startsAIPreflightOnAppear"] {
            XCTAssertTrue(editorSource.contains(capability), "지금 편집기에서 \(capability)이 사라졌다")
        }
        XCTAssertTrue(editorSource.contains("logEditor.cancel"), "편집기의 취소가 사라졌다")
    }

    func test36_bothEditorsShareOneAssistanceVocabulary() {
        XCTAssertTrue(editorSource.contains("RecordEditorAssistance.moods"), "어휘가 두 벌이 됐다")
        XCTAssertTrue(editorSource.contains("RecordEditorAssistance.highlights"))
        XCTAssertEqual(RecordEditorAssistance.moods.count, 6)
        XCTAssertEqual(RecordEditorAssistance.highlights.count, 7)
        // 3단계가 그리는 다섯 가지는 여전히 따로다 — 서로 모르는 값은 보존된다.
        XCTAssertEqual(RecordCreateStep3View.moods, ["벅차오름", "행복", "뿌듯", "아쉬움", "약오름"])
    }

    func test37_noUnsupportedFieldEnteredTheFlowOrItsAssistance() {
        for path in [flowSource, assistanceSource, mappingSource, step1Source, step3Source] {
            for forbidden in ["날씨", "먹은 것", "응원 준비물", "별점", "0 / 500", "임시저장",
                              "weatherText", "foodText", "cheeringGear"] {
                XCTAssertFalse(path.contains(forbidden), "지원하지 않는 \(forbidden)이 생겼다")
            }
        }
    }

    func test38_noSchemaAPIOrBackendContractChanged() throws {
        let dto = try source("Domain/APIDTOs.swift")
        for field in ["gameDate", "favoriteTeamID", "opponentTeamID", "stadiumName", "ourScore",
                      "opponentScore", "seatText", "companionType", "shortMemo", "diaryText",
                      "moodTags", "highlightTags", "photoLocalRefs", "gameSource", "linkedKBOGameID",
                      "officialRecordURL"] {
            XCTAssertTrue(dto.contains(field), "\(field) 계약이 사라졌다")
        }
        let domain = try executableSource("Domain/VFDomain.swift")
        for forbidden in ["weather", "cheeringGear", "isPartial", "currentStep", "resumableDraft"] {
            XCTAssertFalse(domain.contains(forbidden), "도메인에 \(forbidden)이 생겼다")
        }
        let store = try executableSource("Services/AppDataStore.swift")
        XCTAssertTrue(store.contains("CreateAttendanceLogRequest("), "생성 요청 DTO가 바뀌었다")
        XCTAssertTrue(store.contains("UpdateAttendanceLogRequest("), "수정 요청 DTO가 바뀌었다")
    }
}
