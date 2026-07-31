import XCTest
@testable import VictoryFairy

/// Record Create 단계 모델 기반(foundation)의 계약.
///
/// 이 패스는 **보이는 세 단계 화면을 만들지 않는다**. 뒤에 올 흐름이 안전하게
/// 올라설 수 있도록, 초안·모드·단계 정체성·필드 소유·검증·더티 비교만 세운다.
/// 기대값은 모두 개정 Pencil `08_RecordCreate_Step1~3`과 현재 저장소 증거에서 왔다.
final class RecordCreateFoundationTests: XCTestCase {

    static let revisedPencilSHA256 = "8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2"

    /// 개정 Pencil이 그린 세 프레임. 이름과 ID를 함께 못박는다.
    static let recordCreateFrames: [(id: String, name: String, step: RecordCreateStep)] = [
        ("m34WD", "08_RecordCreate_Step1", .game),
        ("Dotbx", "08_RecordCreate_Step2", .details),
        ("z0G0P", "08_RecordCreate_Step3", .memory)
    ]

    /// Pencil이 그렸지만 이 패스가 **결정하지 않는** 항목들.
    /// 런타임 타입으로 만들면 아무도 쓰지 않는 죽은 코드가 되므로 계약으로만 둔다.
    static let unresolvedPencilFields: [RecordCreateStep: [String]] = [
        .game: ["여기까지만 저장할게요"],
        .details: ["날씨", "먹은 것", "응원 준비물"],
        .memory: ["별점", "0 / 500"]
    ]

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

    func testCommentStripperActuallyRemovesComments() {
        let stripped = stripComments("// weather\nlet a = 1 /* rating */\nlet b = \"별점\"")
        XCTAssertFalse(stripped.contains("weather"))
        XCTAssertFalse(stripped.contains("rating"))
        XCTAssertTrue(stripped.contains("별점"), "문자열 안은 남아야 한다")
    }

    private func productionSources() throws -> [(name: String, body: String)] {
        var result: [(String, String)] = []
        for folder in ["Features", "SharedComponents", "DesignSystem", "Domain", "Services", "Data"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                result.append((url.lastPathComponent, stripComments(try String(contentsOf: url, encoding: .utf8))))
            }
        }
        return result
    }

    // MARK: - 고정 표본

    private static let fixedDate = Date.vfDate(year: 2026, month: 4, day: 12)
    private static let otherDate = Date.vfDate(year: 2026, month: 5, day: 3)
    private static let fixedID = UUID(uuidString: "D37A11ED-0000-4000-8000-000000000001")!

    private func makeRecord(
        ourScore: Int? = 6,
        opponentScore: Int? = 3,
        result: GameResult = .win,
        stadium: String = "잠실야구장",
        matchup: String = "삼성 vs LG",
        seat: String = "3루 원정석 K열",
        companion: String = "엄마랑",
        memo: String = "9회말 역전",
        diary: String = "첫 줄\n둘째 줄 🎉",
        tags: [String] = ["짜릿함", "역전승"],
        photos: [String] = ["photo-a", "photo-b"],
        linkedKBOGameID: String? = "kbo-2026-04-12-1",
        officialRecordURL: String? = "https://example.com/record"
    ) -> AttendanceLogViewState {
        AttendanceLogViewState(
            id: Self.fixedID,
            date: Self.fixedDate,
            dateText: "4월 12일",
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ourScore,
            opponentScore: opponentScore,
            seat: seat,
            companion: companion,
            memo: memo,
            caption: "",
            diary: diary,
            tags: tags,
            photoLocalRefs: photos,
            gameSource: "adminResult",
            linkedKBOGameID: linkedKBOGameID,
            officialRecordURL: officialRecordURL
        )
    }

    private func makeCreateDraft(initialDate: Date? = nil, preferredTeam: String? = nil) -> RecordEditorDraft {
        RecordEditorDraft.make(
            mode: .create(initialDate: initialDate),
            existingRecord: nil,
            preferredFavoriteTeamName: preferredTeam,
            defaultMoodTag: "짜릿함",
            defaultHighlightTag: "홈런",
            fallbackDate: Self.fixedDate
        )
    }

    private func makeEditDraft(_ record: AttendanceLogViewState? = nil) -> RecordEditorDraft {
        let record = record ?? makeRecord()
        return RecordEditorDraft.make(
            mode: .edit(recordID: record.id),
            existingRecord: record,
            preferredFavoriteTeamName: nil,
            defaultMoodTag: "짜릿함",
            defaultHighlightTag: "홈런",
            fallbackDate: Self.fixedDate
        )
    }

    // MARK: - 1~3. 원본과 감사

    func testRevisedPencilHashRemainsRecorded() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains(Self.revisedPencilSHA256), "개정 Pencil 해시가 문서에 없다")
    }

    func testAllThreeRecordCreateFramesAreMapped() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertEqual(Self.recordCreateFrames.count, RecordCreateStep.total)
        for frame in Self.recordCreateFrames {
            XCTAssertTrue(doc.contains(frame.id), "\(frame.name) 프레임 ID가 문서에 없다")
            XCTAssertTrue(doc.contains(frame.name), "\(frame.name) 프레임 이름이 문서에 없다")
        }
    }

    func testCurrentEditorArchitectureWasAudited() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        // 이전 문서가 "단계형 편집기가 이미 있다"고 잘못 말한 것을 바로잡았다.
        XCTAssertTrue(doc.contains("한 장짜리 스크롤 폼"), "현재 편집기 구조 정정이 문서에 없다")
    }

    // MARK: - 4~7. 정본 초안

    func testOneCanonicalDraftOwnsSupportedEditorData() {
        let draft = makeEditDraft()
        XCTAssertEqual(draft.editingRecordID, Self.fixedID)
        XCTAssertEqual(draft.seat, "3루 원정석 K열")
        XCTAssertEqual(draft.companion, "엄마랑")
        XCTAssertEqual(draft.diary, "첫 줄\n둘째 줄 🎉")
        XCTAssertEqual(draft.photo.refs, ["photo-a", "photo-b"])
    }

    func testProductionEditorUsesTheCanonicalDraft() throws {
        let body = try executableSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(body.contains("@State private var draft: RecordEditorDraft"), "제품 편집기가 초안을 쓰지 않는다")
        XCTAssertTrue(body.contains("RecordEditorDraft.make("), "초안 초기화 경로를 쓰지 않는다")
        XCTAssertTrue(body.contains("draft.makeSaveInput()"), "저장이 초안 매핑을 쓰지 않는다")
    }

    func testNoDuplicateProductionEditorDraftExists() throws {
        var owners: [String] = []
        for entry in try productionSources() where entry.body.contains("struct RecordEditorDraft") {
            owners.append(entry.name)
        }
        XCTAssertEqual(owners, ["RecordEditorDraft.swift"], "초안 타입이 여러 곳에 있다: \(owners)")
        for entry in try productionSources() {
            XCTAssertFalse(entry.body.contains("struct LogEditorDraft"), "\(entry.name)에 두 번째 초안이 있다")
        }
    }

    func testCreateAndEditUseTheSameDraftType() {
        let create = makeCreateDraft()
        let edit = makeEditDraft()
        XCTAssertTrue(type(of: create) == type(of: edit))
        XCTAssertNil(create.editingRecordID)
        XCTAssertNotNil(edit.editingRecordID)
    }

    // MARK: - 8. 모드

    func testExplicitCreateAndEditModesExist() {
        XCTAssertFalse(RecordEditorMode.create.isEditing)
        XCTAssertNil(RecordEditorMode.create.editingRecordID)
        XCTAssertEqual(RecordEditorMode.create(initialDate: Self.otherDate).initialDate, Self.otherDate)
        let edit = RecordEditorMode.edit(recordID: Self.fixedID)
        XCTAssertTrue(edit.isEditing)
        XCTAssertEqual(edit.editingRecordID, Self.fixedID)
        XCTAssertNil(edit.initialDate)
        XCTAssertEqual(RecordEditorMode.create.navigationTitle, "직관 기록 추가")
        XCTAssertEqual(edit.navigationTitle, "직관 기록 수정")
    }

    // MARK: - 9~13. 단계 정체성

    func testExactlyThreeStepIdentitiesExist() {
        XCTAssertEqual(RecordCreateStep.allCases.count, 3)
        XCTAssertEqual(RecordCreateStep.total, 3)
        XCTAssertEqual(RecordCreateStep.allCases, [.game, .details, .memory])
    }

    func testStepOrderIsDeterministic() {
        XCTAssertEqual(RecordCreateStep.game.position, 1)
        XCTAssertEqual(RecordCreateStep.details.position, 2)
        XCTAssertEqual(RecordCreateStep.memory.position, 3)
        XCTAssertEqual(RecordCreateStep.allCases.map(\.accessibilityTitle),
                       ["경기", "그날의 디테일", "나의 이야기"])
    }

    func testPreviousAndNextRelationshipsAreDeterministic() {
        XCTAssertNil(RecordCreateStep.game.previous)
        XCTAssertEqual(RecordCreateStep.game.next, .details)
        XCTAssertEqual(RecordCreateStep.details.previous, .game)
        XCTAssertEqual(RecordCreateStep.details.next, .memory)
        XCTAssertEqual(RecordCreateStep.memory.previous, .details)
        XCTAssertNil(RecordCreateStep.memory.next)
    }

    func testCurrentStepIsNotPersisted() throws {
        // 온보딩은 자기 단계를 갖는다. 여기서 보는 것은 Record Create 단계뿐이다.
        for entry in try productionSources() {
            guard entry.body.contains("RecordCreateStep") else { continue }
            XCTAssertFalse(entry.body.contains("@AppStorage"), "\(entry.name)이 단계를 설정에 저장한다")
            XCTAssertFalse(entry.body.contains("UserDefaults"), "\(entry.name)이 단계를 저장소에 쓴다")
            XCTAssertFalse(entry.body.contains("@Model"), "\(entry.name)이 단계를 SwiftData에 넣는다")
        }
        let preferences = try executableSource("Services/UserPreferencesStore.swift")
        XCTAssertFalse(preferences.contains("RecordCreateStep"), "사용자 설정이 단계를 저장한다")
        let dtos = try executableSource("Domain/APIDTOs.swift")
        XCTAssertFalse(dtos.contains("RecordCreateStep"), "API 계약이 단계를 나른다")
    }

    func testStepIdentityDoesNotChangeTheCurrentUI() throws {
        let body = try executableSource("Features/LogEditor/LogEditorView.swift")
        for forbidden in ["진행 표시", "다음 · ", "이 단계는 건너뛸게요", "여기까지만 저장할게요", "기록 완성하기"] {
            XCTAssertFalse(body.contains(forbidden), "보이는 마법사 조각 \(forbidden)이 들어갔다")
        }
        // 현재 폼의 저장 버튼은 그대로다.
        XCTAssertTrue(body.contains("\"저장하기\""), "현재 저장 버튼이 사라졌다")
    }

    // MARK: - 14~15. 필드 소유

    func testEverySupportedFieldMapsToAStep() {
        let mapped = RecordCreateStep.allCases.flatMap(\.supportedFields)
        XCTAssertEqual(Set(mapped), Set(RecordEditorField.allCases))
        XCTAssertEqual(mapped.count, RecordEditorField.allCases.count, "한 값이 두 단계에 속한다")
        XCTAssertEqual(Set(RecordCreateStep.game.supportedFields),
                       [.date, .stadium, .favoriteTeam, .opponentTeam, .result, .ourScore, .opponentScore, .linkedKBOGame])
        XCTAssertEqual(Set(RecordCreateStep.details.supportedFields), [.seat, .companion])
        XCTAssertEqual(Set(RecordCreateStep.memory.supportedFields),
                       [.photos, .shortMemo, .moodTag, .highlightTag, .diary])
    }

    func testUnresolvedPencilOnlyFieldsAreDocumented() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        for (step, fields) in Self.unresolvedPencilFields {
            XCTAssertTrue(step.hasUnresolvedPencilFields, "\(step.rawValue)에 미결 항목 표시가 없다")
            for field in fields {
                XCTAssertTrue(doc.contains(field), "미결 항목 \(field)이 문서에 없다")
            }
        }
    }

    // MARK: - 16~21. 미지원 항목을 넣지 않았다

    func testUnsupportedPencilFieldsAreNotAddedToTheDomain() throws {
        let forbidden = ["weather", "날씨", "food", "먹은 것", "cheeringGear", "응원 준비물", "rating", "별점"]
        let owners = ["Domain/VFDomain.swift", "Domain/APIDTOs.swift",
                      "Features/LogEditor/RecordEditorDraft.swift",
                      "Features/LogEditor/RecordCreateStep.swift"]
        for path in owners {
            let body = try executableSource(path)
            for needle in forbidden {
                XCTAssertFalse(body.contains(needle), "\(path)에 미지원 항목 \(needle)이 들어갔다")
            }
        }
    }

    func testNoDiaryLengthLimitIsIntroduced() throws {
        let editor = try executableSource("Features/LogEditor/LogEditorView.swift")
        let validation = try executableSource("Features/LogEditor/RecordEditorValidation.swift")
        for body in [editor, validation] {
            XCTAssertFalse(body.contains("500"), "500자 제한이 들어갔다")
            XCTAssertFalse(body.contains(".prefix(500)"), "일기 길이를 자르고 있다")
        }
    }

    func testNoPartialSaveBehaviourIsIntroduced() throws {
        for entry in try productionSources() {
            XCTAssertFalse(entry.body.contains("임시저장"), "\(entry.name)에 임시저장이 들어갔다")
            XCTAssertFalse(entry.body.contains("partialSave"), "\(entry.name)에 부분 저장이 들어갔다")
        }
    }

    // MARK: - 22~26. 초기화

    func testCreateFromHomeInitializesDeterministically() {
        let first = makeCreateDraft()
        let second = makeCreateDraft()
        XCTAssertEqual(first, second, "같은 입력이 다른 초안을 만든다")
        XCTAssertNil(first.editingRecordID)
        XCTAssertEqual(first.opponentTeamName, "", "상대팀을 지어냈다")
        XCTAssertEqual(first.stadiumName, "", "구장을 지어냈다")
        XCTAssertNil(first.result, "결과를 지어냈다")
        XCTAssertNil(first.ourScore, "점수를 지어냈다")
        XCTAssertNil(first.opponentScore, "점수를 지어냈다")
        XCTAssertEqual(first.seat, "", "좌석을 지어냈다")
        XCTAssertEqual(first.shortMemo, "", "메모를 지어냈다")
    }

    func testCreateHonoursAStoredFavouriteTeamOnly() {
        let draft = makeCreateDraft(preferredTeam: "LG 트윈스")
        XCTAssertEqual(draft.favoriteTeamName, "LG 트윈스")
        XCTAssertEqual(draft.stadiumName, "", "주 관람 구장을 끌어오지 않는다")
    }

    func testCalendarCreatePreservesTheInitialDate() {
        let draft = makeCreateDraft(initialDate: Self.otherDate)
        XCTAssertEqual(draft.date, Self.otherDate)
    }

    func testRecordDetailEditPreservesTheRecordIdentity() {
        XCTAssertEqual(makeEditDraft().editingRecordID, Self.fixedID)
    }

    func testEditPreloadsEverySupportedField() {
        let record = makeRecord()
        let draft = makeEditDraft(record)
        XCTAssertEqual(draft.date, record.date)
        XCTAssertEqual(draft.favoriteTeamName, "삼성 라이온즈")
        XCTAssertEqual(draft.opponentTeamName, "LG 트윈스")
        XCTAssertEqual(draft.stadiumName, record.stadium)
        XCTAssertEqual(draft.result, record.result)
        XCTAssertEqual(draft.ourScore, record.ourScore)
        XCTAssertEqual(draft.opponentScore, record.opponentScore)
        XCTAssertEqual(draft.seat, record.seat)
        XCTAssertEqual(draft.companion, record.companion)
        XCTAssertEqual(draft.shortMemo, record.memo)
        XCTAssertEqual(draft.diary, record.diary)
        XCTAssertEqual(draft.moodTag, "짜릿함")
        XCTAssertEqual(draft.highlightTag, "역전승")
        XCTAssertEqual(draft.photo.refs, record.photoLocalRefs)
        XCTAssertEqual(draft.linkedKBOGameID, record.linkedKBOGameID)
        XCTAssertEqual(draft.officialRecordURL, record.officialRecordURL)
    }

    // MARK: - 27~39. 왕복

    func testDiaryPreservesLineBreaksAndEmoji() {
        let record = makeRecord(diary: "첫 줄\n\n셋째 줄 ⚾️🎉")
        XCTAssertEqual(makeEditDraft(record).diary, "첫 줄\n\n셋째 줄 ⚾️🎉")
    }

    func testTagsRoundTrip() {
        let draft = makeEditDraft(makeRecord(tags: ["감동", "끝내기"]))
        XCTAssertEqual(draft.moodTag, "감동")
        XCTAssertEqual(draft.highlightTag, "끝내기")
        XCTAssertEqual(draft.saveTags, ["감동", "끝내기"])
    }

    func testAppliedHighlightTagsWinOverTheSingleChip() {
        var draft = makeEditDraft()
        draft.appliedHighlightTags = ["역전승", "홈런"]
        XCTAssertEqual(draft.saveTags, ["짜릿함", "역전승", "홈런"])
    }

    func testPhotoStateRoundTrips() {
        let draft = makeEditDraft()
        XCTAssertEqual(draft.photo.state, .existingUnchanged)
        XCTAssertFalse(draft.photo.hasChanges)
        XCTAssertEqual(draft.photo.removedRefs, [])
        XCTAssertEqual(draft.photo.addedRefs, [])
    }

    func testLinkedKBOGameAndOfficialURLRoundTrip() {
        let draft = makeEditDraft()
        let input = draft.makeSaveInput()
        XCTAssertEqual(input?.linkedKBOGameID, "kbo-2026-04-12-1")
        XCTAssertEqual(input?.officialRecordURL, "https://example.com/record")
        XCTAssertEqual(input?.gameSource, "adminResult")
    }

    func testMissingScoreStaysMissing() {
        let draft = makeEditDraft(makeRecord(ourScore: nil, opponentScore: nil))
        XCTAssertNil(draft.ourScore, "없는 점수가 0이 됐다")
        XCTAssertNil(draft.opponentScore, "없는 점수가 0이 됐다")
        XCTAssertNil(draft.makeSaveInput()?.ourScore, "저장 입력이 0을 지어냈다")
        XCTAssertNil(draft.makeSaveInput()?.opponentScore, "저장 입력이 0을 지어냈다")
    }

    func testCancelledResultRoundTripsWithoutInventingScores() {
        let draft = makeEditDraft(makeRecord(ourScore: nil, opponentScore: nil, result: .canceled))
        XCTAssertEqual(draft.result, .canceled)
        XCTAssertNil(draft.ourScore)
        XCTAssertEqual(draft.makeSaveInput()?.result, .canceled)
    }

    func testUnknownStadiumRemainsTheRecordedValue() {
        let draft = makeEditDraft(makeRecord(stadium: "부산 사직 보조구장"))
        XCTAssertEqual(draft.stadiumName, "부산 사직 보조구장")
        XCTAssertEqual(draft.makeSaveInput()?.stadium, "부산 사직 보조구장")
    }

    func testPrimaryOrHomeStadiumNeverReplacesARecordStadium() throws {
        let draftSource = try executableSource("Features/LogEditor/RecordEditorDraft.swift")
        XCTAssertFalse(draftSource.contains("primaryStadium"), "주 관람 구장이 초안에 끼어들었다")
        XCTAssertFalse(draftSource.contains("homeStadium"), "팀 홈 구장이 초안에 끼어들었다")
        XCTAssertFalse(draftSource.contains("KBOStadiumSeed"), "구장 등록부가 기록 구장을 덮어쓴다")
    }

    func testMissingOpponentIsNotInferred() {
        let draft = makeEditDraft(makeRecord(matchup: "삼성"))
        XCTAssertEqual(draft.favoriteTeamName, "삼성 라이온즈")
        XCTAssertEqual(draft.opponentTeamName, "", "없는 상대팀을 지어냈다")
    }

    func testEmptyOptionalFieldsSurvive() {
        let draft = makeEditDraft(makeRecord(seat: "", companion: "", memo: "", diary: "", photos: []))
        XCTAssertEqual(draft.seat, "")
        XCTAssertEqual(draft.companion, "")
        XCTAssertEqual(draft.diary, "")
        XCTAssertEqual(draft.photo.state, .none)
    }

    // MARK: - 40~41. 여는 것만으로 아무 일도 일어나지 않는다

    func testOpeningTheEditorPersistsNothingAndInventsNoIdentity() throws {
        let draft = makeCreateDraft()
        XCTAssertNil(draft.editingRecordID, "여는 것만으로 정체성을 만들었다")
        let draftSource = try executableSource("Features/LogEditor/RecordEditorDraft.swift")
        XCTAssertFalse(draftSource.contains("UUID()"), "초안이 임의의 UUID를 만든다")
        XCTAssertFalse(draftSource.contains("Date()"), "초안이 현재 시각을 쓴다")
        XCTAssertFalse(draftSource.contains("appData"), "초안이 저장소를 만진다")
        XCTAssertFalse(draftSource.contains("Repository"), "초안이 저장을 한다")
        XCTAssertFalse(draftSource.contains("import SwiftUI"), "초안이 뷰 계층을 끌어온다")
    }

    // MARK: - 42~46. 더티 비교

    func testUntouchedDraftsAreClean() {
        let create = makeCreateDraft()
        XCTAssertFalse(create.isDirty(comparedTo: create))
        let edit = makeEditDraft()
        XCTAssertFalse(edit.isDirty(comparedTo: edit))
    }

    func testUserChangesMakeTheDraftDirtyAndRestoringClearsIt() {
        let original = makeEditDraft()
        var draft = original
        draft.seat = "1루 내야석"
        XCTAssertTrue(draft.isDirty(comparedTo: original))
        draft.seat = original.seat
        XCTAssertFalse(draft.isDirty(comparedTo: original), "되돌렸는데 여전히 바뀐 것으로 본다")

        draft.diary += "!"
        XCTAssertTrue(draft.isDirty(comparedTo: original))
        draft.diary = original.diary
        XCTAssertFalse(draft.isDirty(comparedTo: original))
    }

    func testTransientEditorStateIsOutsideTheDraft() throws {
        let draftSource = try executableSource("Features/LogEditor/RecordEditorDraft.swift")
        for transient in ["isShowing", "isSaving", "isLoading", "PhotosPickerItem", "Sheet", "safariRoute"] {
            XCTAssertFalse(draftSource.contains(transient), "일시적 상태 \(transient)이 초안에 들어갔다")
        }
        // 편집기는 일시적 상태를 여전히 자기 것으로 갖는다.
        let editor = try executableSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(editor.contains("@State private var isShowingTicketOCR"), "OCR 시트 상태가 사라졌다")
        XCTAssertTrue(editor.contains("@State private var isSaving"), "저장 중 상태가 사라졌다")
    }

    func testPickerCancellationAndFailuresPreservePhotoState() {
        let original = makeEditDraft()
        var draft = original
        // 피커를 열었다 닫아도 초안은 그대로다. 취소는 초안을 건드리지 않는다.
        XCTAssertFalse(draft.isDirty(comparedTo: original))
        XCTAssertEqual(draft.photo.refs, ["photo-a", "photo-b"])
        // 지우는 것만이 명시적 의도다.
        draft.photo.remove("photo-a")
        XCTAssertEqual(draft.photo.state, .replacedExisting)
        XCTAssertEqual(draft.photo.removedRefs, ["photo-a"])
        draft.photo.remove("photo-b")
        XCTAssertEqual(draft.photo.state, .removedExisting)
    }

    func testFailedToolRunsPreserveTheDraft() throws {
        // OCR·사진 분석·AI 초안·경기 추천은 실패하면 문구만 바꾼다. 초안은 손대지 않는다.
        let body = try executableSource("Features/LogEditor/LogEditorView.swift")
        for marker in ["사진 분석 기능은 아직 사용할 수 없어요.",
                       "AI 초안을 만들지 못했어요. 기본 문장으로 채워볼게요.",
                       "서버에서 경기 정보를 가져오지 못했어요"] {
            XCTAssertTrue(body.contains(marker), "실패 안내 \(marker)가 사라졌다")
        }
        // 실패 경로가 초안을 비우지 않는다.
        XCTAssertFalse(body.contains("draft = RecordEditorDraft"), "실패가 초안을 갈아엎는다")
    }

    // MARK: - 47~51. 검증

    func testCanonicalValidationLivesOutsideSwiftUI() throws {
        let validation = try source("Features/LogEditor/RecordEditorValidation.swift")
        XCTAssertFalse(validation.contains("import SwiftUI"), "검증이 SwiftUI를 끌어온다")
        XCTAssertFalse(validation.contains(": View"), "검증이 뷰다")
        let editor = try executableSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(editor.contains("RecordEditorValidation.validate(draft)"), "화면이 정본 검증을 쓰지 않는다")
    }

    func testValidationRequiresOnlyTheCurrentRequiredFields() {
        var draft = makeCreateDraft()
        XCTAssertFalse(RecordEditorValidation.validate(draft).isValid)
        XCTAssertEqual(RecordEditorValidation.validate(draft).firstInvalidField, .favoriteTeam)

        draft.favoriteTeamName = "삼성 라이온즈"
        draft.opponentTeamName = "LG 트윈스"
        draft.stadiumName = "잠실야구장"
        draft.result = .win
        let result = RecordEditorValidation.validate(draft)
        XCTAssertTrue(result.isValid, "필수 넷을 채웠는데 저장을 막는다")
        XCTAssertTrue(result.isSaveReady)
        XCTAssertNil(result.blockingMessage)
        // 좌석·동행·사진·일기는 여전히 선택이다.
        XCTAssertEqual(draft.seat, "")
        XCTAssertTrue(RecordEditorValidation.validate(draft).isValid)
    }

    func testValidationGroupsByStep() {
        let draft = makeCreateDraft()
        let result = RecordEditorValidation.validate(draft)
        XCTAssertEqual(result.invalidSteps, [.game], "1단계 값만 막혀야 한다")
        XCTAssertTrue(RecordEditorValidation.validate(draft, step: .details).isValid)
        XCTAssertTrue(RecordEditorValidation.validate(draft, step: .memory).isValid)
    }

    func testScoreWarningMatchesTheCurrentRule() {
        var draft = makeEditDraft()
        draft.result = .win
        draft.ourScore = 1
        draft.opponentScore = 5
        XCTAssertTrue(RecordEditorValidation.validate(draft).warnings.contains(.scoreDisagreesWithResult))
        draft.ourScore = 6
        XCTAssertFalse(RecordEditorValidation.validate(draft).warnings.contains(.scoreDisagreesWithResult))
        // 점수가 아예 없으면 경고하지 않는다.
        draft.ourScore = nil
        XCTAssertFalse(RecordEditorValidation.validate(draft).warnings.contains(.scoreDisagreesWithResult))
    }

    // MARK: - 52~56. 기능과 저장 경계

    func testEveryShippedEditorFeatureRemainsReachable() throws {
        let body = try executableSource("Features/LogEditor/LogEditorView.swift")
        let features = [
            "TicketOCRView(",                    // 티켓 OCR
            "AIPreflightDisclosureSheet",        // AI 사전 고지
            "AIDiaryDraftSheet(",                // AI 초안
            "PhotoAnalysisSelectionSheet(",      // 사진 분석 선택
            "PhotoAnalysisResultSheet(",         // 사진 분석 결과
            "KBOGameCandidateSelectionSheet(",   // 경기 후보 선택
            "SourceDisclosureView(",             // 출처 고지
            "PhotosPicker(",                     // 사진 첨부
            "lookupKBOGameCandidates()",         // 경기 추천
            "startsAIPreflightOnAppear"          // AI 사전 진입 의도
        ]
        for feature in features {
            XCTAssertTrue(body.contains(feature), "\(feature) 기능이 사라졌다")
        }
    }

    func testCurrentSaveMutationOwnerRemainsUnchanged() throws {
        let body = try executableSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(body.contains("appData.saveAttendanceLog("), "생성 저장 주체가 바뀌었다")
        XCTAssertTrue(body.contains("appData.updateAttendanceLog("), "수정 저장 주체가 바뀌었다")
        let store = try executableSource("Services/AppDataStore.swift")
        XCTAssertTrue(store.contains("CreateAttendanceLogRequest("), "생성 요청 DTO가 바뀌었다")
        XCTAssertTrue(store.contains("UpdateAttendanceLogRequest("), "수정 요청 DTO가 바뀌었다")
    }

    // MARK: - 53~54. 진입점

    func testEveryEditorCallSiteStillUsesTheCompactAPI() throws {
        var callSites: [String] = []
        for entry in try productionSources() {
            for line in entry.body.split(separator: "\n") where line.contains("LogEditorView(") {
                callSites.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        // 미리보기를 뺀 제품 호출부.
        let production = callSites.filter { !$0.hasPrefix("LogEditorView.swift") }
        // 일곱 곳이다. 예전에는 홈 AI 시트 안에 최근 기록이 없을 때를 위한 여덟 번째
        // 호출부가 있었지만 구조적으로 도달할 수 없어 걷어냈다.
        XCTAssertEqual(production.count, 7, "진입점 수가 달라졌다: \(production)")
        XCTAssertTrue(production.contains { $0.contains("LogEditorView(initialDate:") }, "캘린더 진입점이 사라졌다")
        XCTAssertTrue(production.contains { $0.contains("LogEditorView(editingLog:") }, "수정 진입점이 사라졌다")
        XCTAssertTrue(production.contains { $0.contains("startsAIPreflightOnAppear: true") }, "AI 사전 진입점이 사라졌다")
    }

    func testNoDuplicateNavigationStackIsIntroduced() throws {
        let body = try executableSource("Features/LogEditor/LogEditorView.swift")
        // 편집기 자신은 NavigationStack을 만들지 않는다. 진입점이 감싼다.
        let editorBody = body[body.index(body.startIndex, offsetBy: 0)..<(body.range(of: "private struct KBOGameFavoritePerspective")?.lowerBound ?? body.endIndex)]
        XCTAssertFalse(editorBody.contains("NavigationStack {"), "편집기가 두 번째 내비게이션 컨테이너를 만든다")
    }

    // MARK: - 59~74. 경계 회귀

    func testFairyAndBrandSystemsRemainUnchanged() {
        XCTAssertEqual(VFFairyKind.allCases.count, 12)
        XCTAssertEqual(VFTeamFairyTrait.allCases.count, 11)
        XCTAssertEqual(VFStadiumFairyTrait.allCases.count, 11)
        XCTAssertEqual(VFFairyIconPolicy.maximumFairiesPerScreen, 3)
    }

    func testCompletedScreensRemainFrameLevel() throws {
        let expectations: [(String, String)] = [
            ("Features/Home/HomeView.swift", "home.root"),
            ("Features/Feed/FeedViews.swift", "feed.addRecord"),
            ("Features/Calendar/CalendarViews.swift", "calendar.selectedDetail"),
            ("Domain/SeasonArchive.swift", "statistics.root"),
            ("Domain/RecordDetail.swift", "recordDetail.root"),
            ("SharedComponents/VFHomeComponents.swift", "home.teamFairy")
        ]
        for (path, identifier) in expectations {
            XCTAssertTrue(try source(path).contains(identifier), "\(path)의 \(identifier)가 사라졌다")
        }
        // 온보딩 라우팅 수정이 그대로다.
        let root = try executableSource("AppRootView.swift")
        XCTAssertTrue(root.contains("preferences.onboardingEntry == .completed"), "온보딩 라우팅 수정이 사라졌다")
        let config = try executableSource("Services/VFUITestConfiguration.swift")
        XCTAssertTrue(config.contains("maskResidualValues"), "초기화 보정이 사라졌다")
    }

    func testNoPersistenceOrAPIContractChanged() throws {
        let dtos = try source("Domain/APIDTOs.swift")
        for field in ["gameDate", "favoriteTeamID", "opponentTeamID", "stadiumName", "ourScore", "opponentScore",
                      "seatText", "companionType", "shortMemo", "diaryText", "moodTags", "highlightTags",
                      "photoLocalRefs", "gameSource", "linkedKBOGameID", "officialRecordURL"] {
            XCTAssertTrue(dtos.contains(field), "요청 DTO의 \(field)가 사라졌다")
        }
        for entry in try productionSources() where entry.body.contains("@Model") {
            XCTAssertFalse(entry.body.contains("RecordCreateStep"), "\(entry.name)의 저장 모델에 단계가 들어갔다")
            XCTAssertFalse(entry.body.contains("RecordEditorDraft"), "\(entry.name)의 저장 모델에 초안이 들어갔다")
        }
    }

    func testNoBackendOrLLMProviderWasAdded() throws {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: Self.repositoryRoot.appendingPathComponent("server").path),
            "백엔드 소스가 들어왔다"
        )
        for entry in try productionSources() {
            for marker in ["OPENAI", "ANTHROPIC_API_KEY", "sk-ant-", "sk-proj-", "gpt-4", "claude-3"] {
                XCTAssertFalse(entry.body.contains(marker), "\(entry.name)에 LLM 흔적 \(marker)이 있다")
            }
        }
    }
}
