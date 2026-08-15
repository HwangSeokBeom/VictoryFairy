import XCTest
@testable import VictoryFairy

/// 개정 Pencil `08_RecordCreate_Step2`(`Dotbx`)의 보이는 레이아웃 계약.
///
/// 이 단계는 **전부 선택 사항**이고, 지금 저장되는 값은 좌석과 함께한 사람 둘뿐이다.
/// Pencil이 함께 그린 날씨·먹은 것·응원 준비물은 어디에도 자리가 없어 만들지 않는다.
final class RecordCreateStep2Tests: XCTestCase {

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

    private var step2Source: String { (try? executableSource("Features/LogEditor/RecordCreateStep2View.swift")) ?? "" }
    private var flowSource: String { (try? executableSource("Features/LogEditor/RecordCreateFlowView.swift")) ?? "" }

    /// `#Preview` 아래는 디자인 타임 전용이다.
    private var step2ScreenSource: String {
        guard let range = step2Source.range(of: "#Preview") else { return step2Source }
        return String(step2Source[..<range.lowerBound])
    }

    // MARK: - 표본

    private func draft(seat: String = "", companion: String = "") -> RecordEditorDraft {
        var value = RecordEditorDraft.make(
            mode: .create,
            preferredFavoriteTeamName: KBOSeed.teams[0].name,
            defaultMoodTag: RecordCreateFlowView.newRecordMoodTag,
            defaultHighlightTag: RecordCreateFlowView.defaultHighlightTag,
            fallbackDate: Date.vfDate(year: 2026, month: 4, day: 16)
        )
        value.opponentTeamName = KBOSeed.teams[1].name
        value.stadiumName = KBOSeed.stadiums[0]
        value.result = .win
        value.seat = seat
        value.companion = companion
        return value
    }

    private typealias Selection = RecordCreateStep2View.CompanionSelection

    /// `private func name()`의 본문만 잘라 온다. 뒤따르는 함수의 이름이 섞이지 않는다.
    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "private func \(name)(") else {
            throw XCTSkip("\(name)()을 찾지 못했다")
        }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    }") else { throw XCTSkip("\(name)()의 끝을 찾지 못했다") }
        return String(rest[..<end.lowerBound])
    }

    // MARK: - 1~3. 정본 초안, 두 값만

    func test01_step2BindsToTheCanonicalDraft() {
        XCTAssertTrue(step2Source.contains("@Binding var draft: RecordEditorDraft"),
                      "2단계가 정본 초안에 바인딩하지 않는다")
    }

    func test02_noStep2DraftExists() {
        for forbidden in ["struct Step2Draft", "struct RecordCreateStep2Draft", "class Step2Model",
                          "struct Step2State", "@State private var draft"] {
            XCTAssertFalse(step2ScreenSource.contains(forbidden), "두 번째 초안 \(forbidden)이 생겼다")
        }
        // 흐름에도 초안은 하나뿐이다.
        XCTAssertEqual(flowSource.components(separatedBy: "RecordEditorDraft.make(").count - 1, 1,
                       "흐름이 초안을 두 번 만든다")
    }

    func test03_step2TouchesOnlySeatAndCompanion() {
        XCTAssertTrue(step2ScreenSource.contains("draft.seat"), "좌석을 다루지 않는다")
        XCTAssertTrue(step2ScreenSource.contains("draft.companion"), "함께한 사람을 다루지 않는다")
        let otherFields = ["draft.date", "draft.stadiumName", "draft.favoriteTeamName",
                           "draft.opponentTeamName", "draft.result", "draft.ourScore",
                           "draft.opponentScore", "draft.linkedKBOGameID", "draft.photo",
                           "draft.shortMemo", "draft.diary", "draft.moodTag", "draft.highlightTag"]
        for keyPath in otherFields {
            XCTAssertFalse(step2ScreenSource.contains(keyPath), "2단계가 남의 값 \(keyPath)을 만진다")
        }
    }

    // MARK: - 4~5. 막는 값이 없다

    func test04_detailsStepHasNoBlockingValidation() {
        let empty = draft()
        XCTAssertTrue(RecordEditorValidation.validate(empty, step: .details).blockingFields.isEmpty,
                      "2단계가 저장을 막는다")
        XCTAssertTrue(RecordEditorValidation.validate(empty, step: .details).isValid)
        // 2단계 필드는 어느 것도 필수가 아니다.
        for field in RecordCreateStep.details.supportedFields {
            XCTAssertFalse(field.isRequired, "\(field.rawValue)이 필수로 바뀌었다")
        }
    }

    func test05_everyCombinationOfSeatAndCompanionIsValid() {
        for (seat, companion) in [("", ""), ("3루 K열", ""), ("", "엄마랑"), ("3루 K열", "회사 동료들과")] {
            let value = draft(seat: seat, companion: companion)
            XCTAssertTrue(RecordEditorValidation.validate(value, step: .details).isValid,
                          "좌석 \"\(seat)\" 동행 \"\(companion)\"이 막혔다")
            // 1단계가 채워져 있으면 전체도 저장 가능하다.
            XCTAssertTrue(RecordEditorValidation.validate(value).isValid)
        }
    }

    // MARK: - 6~7. 값이 그대로 오간다

    func test06_seatRoundTripsUnchanged() {
        let written = "3루 내야 지정석 K열 24번 (통로 옆)"
        var value = draft(seat: written)
        XCTAssertEqual(value.seat, written, "좌석이 도중에 다듬어졌다")
        value.seat = "  앞뒤 공백  "
        XCTAssertEqual(value.seat, "  앞뒤 공백  ", "입력 중에 공백을 잘라냈다")
    }

    func test07_arbitraryCompanionStringRoundTripsUnchanged() {
        for written in ["회사 동료들과", "with my brother", "친구 2명 + 사촌", "혼자서 조용히"] {
            let value = draft(companion: written)
            XCTAssertEqual(value.companion, written, "\"\(written)\"이 바뀌었다")
            XCTAssertEqual(value.makeSaveInput() == nil, false, "저장 입력을 만들지 못했다")
        }
    }

    // MARK: - 8~10. 빠른 선택지가 그대로 저장 값이 된다

    func test08to10_quickOptionsAreTheAuthoredCanonicalStrings() {
        XCTAssertEqual(RecordCreateStep2View.quickCompanions, ["혼자", "엄마랑", "친구랑"],
                       "Pencil이 적은 빠른 선택지와 다르다")
        for option in RecordCreateStep2View.quickCompanions {
            let value = draft(companion: option)
            XCTAssertEqual(value.companion, option)
            XCTAssertEqual(RecordCreateStep2View.companionSelection(for: option, customEntryChosen: false),
                           Selection.quick(option), "\(option)이 빠른 선택으로 읽히지 않는다")
        }
        // 저장되는 것은 지금도 문자열 하나다. 초안에 숨은 타입이 생기지 않았다.
        let draftSource = (try? executableSource("Features/LogEditor/RecordEditorDraft.swift")) ?? ""
        for hidden in ["enum Companion", "CompanionType", "companionCase"] {
            XCTAssertFalse(draftSource.contains(hidden), "초안에 숨은 동행 타입 \(hidden)이 생겼다")
        }
        XCTAssertTrue(draftSource.contains("var companion: String"), "동행이 더 이상 문자열이 아니다")
        // 화면의 선택 상태는 초안에서 유도할 뿐 저장되지 않는다.
        XCTAssertFalse(step2ScreenSource.contains("@State private var companion"),
                       "동행에 두 번째 진실 원본이 생겼다")
    }

    // MARK: - 11~14. 선택 상태는 초안에서 나온다

    func test11_directlyEnteredCustomTextStaysCustom() {
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: "회사 동료들과", customEntryChosen: false),
                       Selection.custom, "직접 쓴 값이 직접 입력으로 읽히지 않는다")
    }

    func test12_existingCustomValueDerivesTheCustomPresentation() {
        // 화면 의사가 없어도 값만으로 직접 입력이 열린다 — 다시 들어와도 그대로다.
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: "사촌 동생이랑", customEntryChosen: false),
                       Selection.custom)
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: "엄마랑", customEntryChosen: true),
                       Selection.quick("엄마랑"), "값이 있는데 화면 의사가 이겼다")
    }

    func test13_changingQuickOptionReplacesThePreviousCompanion() {
        var value = draft(companion: "혼자")
        value.companion = "친구랑"
        XCTAssertEqual(value.companion, "친구랑")
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: value.companion, customEntryChosen: false),
                       Selection.quick("친구랑"))
        // 직접 입력에서 빠른 선택지로 바꿔도 마찬가지다.
        value.companion = "회사 동료들과"
        value.companion = "엄마랑"
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: value.companion, customEntryChosen: false),
                       Selection.quick("엄마랑"))
    }

    func test14_clearingCustomTextLeavesCompanionEmpty() {
        var value = draft(companion: "회사 동료들과")
        value.companion = ""
        XCTAssertTrue(value.companion.isEmpty, "지웠는데 값이 남았다")
        // 지운 뒤에도 직접 입력 칸은 열려 있다. 저장되는 값은 여전히 비어 있다.
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: "", customEntryChosen: true),
                       Selection.custom)
        XCTAssertEqual(RecordCreateStep2View.companionSelection(for: "", customEntryChosen: false),
                       Selection.none)
        XCTAssertTrue(RecordEditorValidation.validate(value, step: .details).isValid, "빈 값이 막혔다")
    }

    // MARK: - 15~21. 이동은 아무것도 저장하지 않는다

    func test15and16_nextAndSkipChangeOnlyTheInMemoryStep() {
        XCTAssertEqual(RecordCreateStep.details.next, .memory)
        XCTAssertEqual(RecordCreateStep.details.previous, .game)
        // 흐름에서 다음과 건너뛰기는 같은 이동 하나만 부른다.
        XCTAssertTrue(flowSource.contains("onNext: { advance() }"), "다음이 이동만 하지 않는다")
        XCTAssertTrue(flowSource.contains("onSkip: { advance() }"), "건너뛰기가 이동만 하지 않는다")
        XCTAssertTrue(flowSource.contains("onBack: { goBack() }"), "이전이 이동만 하지 않는다")
    }

    func test17_skipPreservesEnteredValues() {
        // 건너뛰기는 초안을 건드리지 않는다 — 지우는 코드가 없다.
        for destructive in ["draft.seat = \"\"", "draft.companion = \"\"",
                            "draft = RecordEditorDraft", "clearDetails", "skippedStep"] {
            XCTAssertFalse(flowSource.contains(destructive), "건너뛰기가 값을 지운다: \(destructive)")
        }
    }

    func test18_backKeepsStep1AndStep2Values() {
        // 초안은 흐름이 하나만 들고 있고 단계 전환으로 다시 만들어지지 않는다.
        XCTAssertTrue(flowSource.contains("@State private var draft: RecordEditorDraft"))
        XCTAssertTrue(flowSource.contains("step = previous"), "이전 단계 이동이 없다")
    }

    func test19to21_navigationPerformsNoSave() {
        for name in ["advance", "goBack"] {
            let body = try! functionBody(named: name, in: flowSource)
            for forbidden in ["await", "save", "appData", "UserDefaults", "modelContext"] {
                XCTAssertFalse(body.contains(forbidden), "\(name)()이 \(forbidden)을 한다: \(body)")
            }
        }
        // 2단계 화면 자체는 저장 경로를 전혀 모른다.
        for forbidden in ["saveAttendanceLog", "updateAttendanceLog", "makeSaveInput", "await "] {
            XCTAssertFalse(step2ScreenSource.contains(forbidden), "2단계가 \(forbidden)을 부른다")
        }
    }

    func test22_currentStepIsNeverPersisted() {
        for forbidden in ["UserDefaults", "@AppStorage", "SwiftData", "modelContext", "currentStep"] {
            XCTAssertFalse(flowSource.contains(forbidden), "현재 단계를 \(forbidden)에 남긴다")
            XCTAssertFalse(step2ScreenSource.contains(forbidden), "2단계가 \(forbidden)을 쓴다")
        }
    }

    func test23_noTemporarySavePersistenceExists() {
        for path in ["Features/LogEditor/RecordCreateFlowView.swift",
                     "Features/LogEditor/RecordCreateStep2View.swift"] {
            let body = (try? executableSource(path)) ?? ""
            XCTAssertFalse(body.contains("임시저장"), "\(path)에 임시저장이 생겼다")
            XCTAssertFalse(body.contains("이어서"), "\(path)가 이어쓰기를 약속한다")
            for forbidden in ["autosave", "draftStorage", "resumable"] {
                XCTAssertFalse(body.lowercased().contains(forbidden.lowercased()), "\(path)에 \(forbidden)이 생겼다")
            }
        }
    }

    // MARK: - 24~27. 지원하지 않는 것은 어디에도 없다

    func test24to26_weatherFoodAndGearAreAbsentEverywhere() throws {
        let unsupported = ["weather", "날씨", "food", "먹은 것", "cheeringGear", "응원 준비물",
                           "유니폼", "응원봉", "응원수건", "유광점퍼", "맑음", "흐림", "밤경기"]
        let owners = ["Features/LogEditor/RecordCreateStep2View.swift",
                      "Features/LogEditor/RecordCreateFlowView.swift",
                      "Features/LogEditor/RecordEditorDraft.swift",
                      "Features/LogEditor/RecordCreateStep.swift",
                      "Domain/VFDomain.swift",
                      "Domain/APIDTOs.swift"]
        for path in owners {
            let body = try executableSource(path)
            for needle in unsupported {
                XCTAssertFalse(body.contains(needle), "\(path)에 미지원 항목 \(needle)이 들어갔다")
            }
        }
        // 초안에도 저장 입력에도 그런 값이 없다.
        let mirror = Mirror(reflecting: draft())
        for label in mirror.children.compactMap(\.label) {
            for needle in ["weather", "food", "gear", "cheering"] {
                XCTAssertFalse(label.lowercased().contains(needle), "초안에 \(label)이 생겼다")
            }
        }
    }

    func test27_noSchemaAPIOrBackendChange() throws {
        let dto = try executableSource("Domain/APIDTOs.swift")
        for forbidden in ["weather", "food", "cheeringGear", "currentStep", "isDraft", "isPartial", "skipped"] {
            XCTAssertFalse(dto.contains(forbidden), "저장 계약에 \(forbidden)이 생겼다")
        }
        // 좌석과 동행은 이미 있던 그대로 실려 나간다.
        XCTAssertTrue(dto.contains("seatText"), "좌석 계약이 사라졌다")
        XCTAssertTrue(dto.contains("companionType"), "동행 계약이 사라졌다")
    }

    // MARK: - 28~30. 경계가 그대로다

    func test28_productionRouteSplitRemainsFiveCreateAndTwoEdit() throws {
        var callSites: [String] = []
        for case let url as URL in FileManager.default.enumerator(
            at: Self.appSourceRoot, includingPropertiesForKeys: nil
        )!.allObjects as! [URL] where url.pathExtension == "swift" {
            let body = try String(contentsOf: url, encoding: .utf8)
            guard url.lastPathComponent != "LogEditorView.swift" else { continue }
            for line in body.split(separator: "\n") where line.contains("LogEditorView(") {
                callSites.append("\(url.lastPathComponent):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(callSites.count, 2, "수정 진입점 수가 달라졌다: \(callSites)")

        var createSites: [String] = []
        for case let url as URL in FileManager.default.enumerator(
            at: Self.appSourceRoot, includingPropertiesForKeys: nil
        )!.allObjects as! [URL] where url.pathExtension == "swift" {
            guard url.lastPathComponent != "RecordCreateFlowView.swift" else { continue }
            let body = try String(contentsOf: url, encoding: .utf8)
            for line in body.split(separator: "\n") where line.contains("RecordCreateFlowView(context:") {
                createSites.append("\(url.lastPathComponent):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(createSites.count, 5, "생성 진입점 수가 달라졌다: \(createSites)")
    }

    func test29_stagedFixtureIsUnavailableInRelease() throws {
        let configuration = try source("Services/VFUITestConfiguration.swift")
        guard let range = configuration.range(of: "static var recordCreateStagedFixture") else {
            return XCTFail("스테이징 픽스처 접근자가 없다")
        }
        let body = String(configuration[range.lowerBound...].prefix(600))
        guard let end = body.range(of: "#endif") else { return XCTFail("#endif가 없다") }
        let gated = String(body[..<end.upperBound])
        XCTAssertTrue(gated.contains("#if DEBUG"))
        XCTAssertTrue(gated.contains("#else"))
        XCTAssertTrue(gated.contains("return nil"))
    }

    func test30_step1BehaviourRemainsIntact() throws {
        let step1 = try executableSource("Features/LogEditor/RecordCreateStep1View.swift")
        // 1단계의 막는 값과 최소 저장 정책은 그대로다.
        XCTAssertTrue(step1.contains("RecordEditorValidation.validate(draft, step: .game)"))
        XCTAssertTrue(step1.contains("여기까지만 저장할게요"))
        XCTAssertTrue(flowSource.contains("appData.saveAttendanceLog("), "최소 저장 경계가 사라졌다")
        XCTAssertEqual(flowSource.components(separatedBy: "appData.saveAttendanceLog(").count - 1, 1,
                       "저장 호출부가 둘 이상이다")
        XCTAssertFalse(flowSource.contains("guard didSave else"), "최소 저장 정책이 바뀌었다")
        // 날짜 라벨 중복 수정도 그대로다.
        XCTAssertFalse(step1.contains(".accessibilityLabel(\"경기 날짜\")"), "날짜 라벨 중복이 되살아났다")
        // 1단계 막는 값 네 가지가 그대로다.
        var bare = RecordEditorDraft.make(mode: .create, defaultMoodTag: "설렘",
                                          defaultHighlightTag: "직관", fallbackDate: Date())
        XCTAssertEqual(RecordEditorValidation.validate(bare, step: .game).blockingFields,
                       [.favoriteTeam, .opponentTeam, .stadium, .result])
        bare.seat = "좌석만 적어도"
        XCTAssertEqual(RecordEditorValidation.validate(bare, step: .game).blockingFields.count, 4,
                       "2단계 값이 1단계 검증에 끼어들었다")
    }

    // MARK: - 31~33. 화면 구조와 문구

    func test31_authoredCopyIsReproduced() {
        for copy in ["그날의 디테일을 더해볼까요?", "모두 건너뛰어도 괜찮아요", "좌석", "함께한 사람",
                     "혼자", "엄마랑", "친구랑", "직접 입력", "다음 · 나의 이야기", "이 단계는 건너뛸게요"] {
            XCTAssertTrue(step2ScreenSource.contains(copy), "Pencil 문구 \(copy)가 없다")
        }
    }

    func test32_progressUsesTheSharedComponentAtStepTwo() {
        XCTAssertTrue(step2ScreenSource.contains("VFStepProgress("), "공용 진행 표시를 쓰지 않는다")
        XCTAssertTrue(step2ScreenSource.contains("RecordCreateStep.details.position - 1"),
                      "2단계 자리를 쓰지 않는다")
        XCTAssertEqual(RecordCreateStep.details.position, 2)
        XCTAssertEqual(RecordCreateStep.details.accessibilityTitle, "그날의 디테일")
    }

    func test33_step2ReusesSharedComponentsAndTokens() {
        for component in ["VFFormField", "VFPrimaryButton", "VFStepProgress"] {
            XCTAssertTrue(step2ScreenSource.contains(component), "공용 컴포넌트 \(component)를 쓰지 않는다")
        }
        for hardCoded in ["Color(hex:", "#F2B63C", "#14171F", "#8B909E", "#E2E3E1"] {
            XCTAssertFalse(step2ScreenSource.contains(hardCoded), "토큰 대신 값을 직접 적었다: \(hardCoded)")
        }
        XCTAssertFalse(step2ScreenSource.contains("minimumScaleFactor"), "축소로 레이아웃 실패를 가린다")
        XCTAssertFalse(step2ScreenSource.contains("dynamicTypeSize(..."), "Dynamic Type을 잘랐다")
        // 2단계에는 페어리가 없다 — Pencil 프레임에도 없다.
        for fairy in ["VFFairyGlyph", "TeamFairy", "StadiumFairy", "VFResultStamp"] {
            XCTAssertFalse(step2ScreenSource.contains(fairy), "Pencil에 없는 \(fairy)를 넣었다")
        }
    }
}
