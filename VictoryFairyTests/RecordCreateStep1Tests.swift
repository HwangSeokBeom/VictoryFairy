import XCTest
@testable import VictoryFairy

/// 개정 Pencil `08_RecordCreate_Step1`(`m34WD`)의 보이는 레이아웃 계약.
///
/// 이 패스는 1단계를 **제품 타깃에 만들되 사용자 경로에 붙이지 않는다**. 그래서
/// 이 파일은 두 가지를 지킨다: 1단계가 다루는 값과 저장 의미가 맞는가, 그리고
/// 기존 일곱 개 진입점이 그대로인가.
final class RecordCreateStep1Tests: XCTestCase {

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

    /// 주석과 문서 주석을 걷어낸 본문. 주석에 적힌 낱말이 구현으로 오해되지 않게 한다.
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

    private var step1Source: String { (try? executableSource("Features/LogEditor/RecordCreateStep1View.swift")) ?? "" }

    /// `#Preview` 아래는 디자인 타임 전용이다. 화면이 실제로 무엇을 하는지 볼 때는
    /// 미리보기를 뺀 부분만 본다.
    private var step1ScreenSource: String {
        guard let range = step1Source.range(of: "#Preview") else { return step1Source }
        return String(step1Source[..<range.lowerBound])
    }
    private var flowSource: String { (try? executableSource("Features/LogEditor/RecordCreateFlowView.swift")) ?? "" }

    // MARK: - 표본

    private static let calendarDate = Date.vfDate(year: 2026, month: 4, day: 16)

    private func freshDraft(preferredTeam: String? = nil, initialDate: Date? = nil) -> RecordEditorDraft {
        RecordEditorDraft.make(
            mode: .create(initialDate: initialDate),
            preferredFavoriteTeamName: preferredTeam,
            defaultMoodTag: RecordCreateFlowView.defaultMoodTag,
            defaultHighlightTag: RecordCreateFlowView.defaultHighlightTag,
            fallbackDate: Self.calendarDate
        )
    }

    private func validStep1Draft() -> RecordEditorDraft {
        var draft = freshDraft(preferredTeam: KBOSeed.teams[0].name)
        draft.opponentTeamName = KBOSeed.teams[1].name
        draft.stadiumName = KBOSeed.stadiums[0]
        draft.result = .win
        draft.ourScore = 5
        draft.opponentScore = 3
        return draft
    }

    // MARK: - 1~4. 정본 초안에 붙는다

    func testStep1BindsToTheCanonicalDraft() {
        XCTAssertTrue(step1Source.contains("@Binding var draft: RecordEditorDraft"),
                      "1단계가 정본 초안에 바인딩하지 않는다")
    }

    func testStep1DoesNotDeclareASecondDraftType() {
        for forbidden in ["struct Step1Draft", "struct RecordCreateStep1Draft", "class Step1Model",
                         "struct Step1State", "@State private var draft"] {
            XCTAssertFalse(step1ScreenSource.contains(forbidden), "1단계가 두 번째 초안 \(forbidden)을 만든다")
        }
    }

    func testStep1OwnsNoDTOAndNoAPIRequest() {
        for forbidden in ["DTO", "Request(", "URLSession", "APIClient", "await appData.save", "await appData.update"] {
            XCTAssertFalse(step1Source.contains(forbidden), "1단계가 \(forbidden)을 직접 다룬다")
        }
    }

    func testStep1OwnsNoIndependentPhotoStateAndNoPersistedStep() {
        for forbidden in ["PhotosPicker", "photo", "UserDefaults", "SwiftData", "modelContext", "currentStep"] {
            XCTAssertFalse(step1Source.contains(forbidden), "1단계가 \(forbidden)을 소유한다")
        }
    }

    // MARK: - 5~7. 1단계는 경기 값만 만진다

    func testStep1TouchesOnlyGameFields() {
        let gameKeyPaths = ["draft.date", "draft.stadiumName", "draft.favoriteTeamName",
                            "draft.opponentTeamName", "draft.result", "draft.ourScore", "draft.opponentScore"]
        for keyPath in gameKeyPaths {
            XCTAssertTrue(step1Source.contains(keyPath), "1단계가 \(keyPath)를 다루지 않는다")
        }
        let laterStepKeyPaths = ["draft.seat", "draft.companion", "draft.shortMemo",
                                 "draft.diary", "draft.moodTag", "draft.highlightTag"]
        for keyPath in laterStepKeyPaths {
            XCTAssertFalse(step1Source.contains(keyPath), "1단계가 뒤 단계 값 \(keyPath)를 만진다")
        }
    }

    func testEveryGameFieldBelongsToStep1() {
        let expected: Set<RecordEditorField> = [.date, .stadium, .favoriteTeam, .opponentTeam,
                                                .result, .ourScore, .opponentScore, .linkedKBOGame]
        XCTAssertEqual(Set(RecordCreateStep.game.supportedFields), expected)
    }

    func testStep1DoesNotIntroduceUnsupportedPencilFields() {
        for forbidden in ["weather", "날씨", "food", "먹은 것", "cheeringGear", "응원 준비물",
                          "rating", "별점", "0 / 500", "임시저장"] {
            XCTAssertFalse(step1Source.contains(forbidden), "1단계에 미지원 항목 \(forbidden)이 들어갔다")
            XCTAssertFalse(flowSource.contains(forbidden), "흐름 껍데기에 미지원 항목 \(forbidden)이 들어갔다")
        }
    }

    // MARK: - 8~9. 검증은 하나뿐이다

    func testStep1UsesTheSharedValidation() {
        XCTAssertTrue(step1Source.contains("RecordEditorValidation.validate(draft, step: .game)"),
                      "1단계가 공용 검증을 쓰지 않는다")
        for forbidden in ["isEmpty else { return false }", "struct Step1Validation", "enum Step1Validation"] {
            XCTAssertFalse(step1Source.contains(forbidden), "1단계가 두 번째 검증 체계를 만든다")
        }
    }

    func testStep1BlockingRequirementsAreUnchanged() {
        var draft = freshDraft()
        XCTAssertEqual(RecordEditorValidation.validate(draft, step: .game).blockingFields,
                       [.favoriteTeam, .opponentTeam, .stadium, .result])

        draft.favoriteTeamName = KBOSeed.teams[0].name
        draft.opponentTeamName = KBOSeed.teams[1].name
        draft.stadiumName = KBOSeed.stadiums[0]
        XCTAssertEqual(RecordEditorValidation.validate(draft, step: .game).blockingFields, [.result])

        draft.result = .win
        XCTAssertTrue(RecordEditorValidation.validate(draft, step: .game).isValid)
        // 점수·사진·일기·분위기·하이라이트는 어느 것도 요구하지 않는다.
        XCTAssertNil(draft.ourScore)
        XCTAssertNil(draft.opponentScore)
        XCTAssertTrue(draft.diary.isEmpty)
    }

    func testCancelledResultNeedsNoScores() {
        var draft = validStep1Draft()
        draft.result = .canceled
        draft.ourScore = nil
        draft.opponentScore = nil
        let validation = RecordEditorValidation.validate(draft, step: .game)
        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.warnings.isEmpty, "취소 경기에 점수 경고가 붙었다")
    }

    // MARK: - 10~13. 지어낸 기본값이 없다

    func testFreshCreateFabricatesNothing() {
        let draft = freshDraft()
        XCTAssertNil(draft.editingRecordID, "새로 만들기인데 기록 정체성이 생겼다")
        XCTAssertTrue(draft.favoriteTeamName.isEmpty)
        XCTAssertTrue(draft.opponentTeamName.isEmpty, "상대팀을 지어냈다")
        XCTAssertTrue(draft.stadiumName.isEmpty, "구장을 지어냈다")
        XCTAssertNil(draft.result, "결과를 지어냈다")
        XCTAssertNil(draft.ourScore, "점수를 지어냈다")
        XCTAssertNil(draft.opponentScore, "점수를 지어냈다")
        XCTAssertNil(draft.linkedKBOGameID)
    }

    func testPencilSampleValuesAreNotHardCoded() {
        // Pencil 표본은 삼성 5 : 3 KIA · 대구다. 그 값이 코드에 박혀 있으면 안 된다.
        for sample in ["\"5\"", "\"3\"", "ourScore = 5", "opponentScore = 3",
                       "\"대구 삼성라이온즈파크\"", "\"KIA 타이거즈\"", "\"삼성 라이온즈\""] {
            XCTAssertFalse(step1ScreenSource.contains(sample), "Pencil 표본값 \(sample)이 박혀 있다")
        }
    }

    func testPreferredFavoriteTeamIsTheOnlyPrefill() {
        let draft = freshDraft(preferredTeam: "삼성 라이온즈")
        XCTAssertEqual(draft.favoriteTeamName, "삼성 라이온즈")
        XCTAssertTrue(draft.opponentTeamName.isEmpty)
        XCTAssertTrue(draft.stadiumName.isEmpty)
        XCTAssertNil(draft.result)
    }

    func testCalendarInitialDateIsRepresented() {
        let draft = freshDraft(initialDate: Self.calendarDate)
        XCTAssertEqual(draft.date, Self.calendarDate)
        // 날짜를 정해 줘도 다른 값을 함께 지어내지 않는다.
        XCTAssertNil(draft.result)
        XCTAssertTrue(draft.stadiumName.isEmpty)
    }

    // MARK: - 14~16. 결과 안내는 결과에서 나온다

    func testResultFeedbackIsDerivedFromTheResult() {
        XCTAssertEqual(GameResult.win.step1Feedback, "오늘은 승리요정이네요!")
        XCTAssertNotEqual(GameResult.loss.step1Feedback, GameResult.win.step1Feedback)
        XCTAssertNotEqual(GameResult.draw.step1Feedback, GameResult.win.step1Feedback)
        XCTAssertNotEqual(GameResult.canceled.step1Feedback, GameResult.win.step1Feedback)
        for result in GameResult.allCases {
            XCTAssertFalse(result.step1Feedback.isEmpty, "\(result.rawValue) 안내가 비었다")
            // 내부 이름이 새어 나가면 안 된다.
            XCTAssertFalse(result.step1Feedback.contains(result.rawValue))
            XCTAssertFalse(result.selectionLabel.contains(result.rawValue))
        }
    }

    func testResultFeedbackIsNotStoredInTheDraft() {
        let mirror = Mirror(reflecting: validStep1Draft())
        for label in mirror.children.compactMap(\.label) {
            XCTAssertFalse(label.lowercased().contains("feedback"), "초안이 안내 문구를 들고 있다: \(label)")
        }
        XCTAssertFalse(step1Source.contains("draft.feedback"))
    }

    func testScoreDisagreementWarningIsPreserved() {
        var draft = validStep1Draft()
        draft.ourScore = 2
        draft.opponentScore = 7
        XCTAssertEqual(RecordEditorValidation.validate(draft, step: .game).warnings,
                       [.scoreDisagreesWithResult])
        // 경고는 저장을 막지 않는다.
        XCTAssertTrue(RecordEditorValidation.validate(draft, step: .game).isValid)
    }

    func testNilScoresSurviveTheStep1Screen() {
        var draft = validStep1Draft()
        draft.ourScore = nil
        draft.opponentScore = nil
        XCTAssertNil(draft.makeSaveInput()?.ourScore)
        XCTAssertNil(draft.makeSaveInput()?.opponentScore)
        // 빈 점수는 경고도 만들지 않는다.
        XCTAssertTrue(RecordEditorValidation.validate(draft, step: .game).warnings.isEmpty)
    }

    // MARK: - 17~20. 다음은 아무것도 저장하지 않는다

    func testNextOnlyMovesTheInMemoryPosition() {
        XCTAssertEqual(RecordCreateStep.game.next, .details)
        XCTAssertEqual(RecordCreateStep.details.previous, .game)
        XCTAssertNil(RecordCreateStep.memory.next)
        XCTAssertTrue(flowSource.contains("step = next"), "다음 단계 이동이 없다")
    }

    func testAdvancingPerformsNoPersistence() {
        guard let advanceRange = flowSource.range(of: "private func advance()") else {
            return XCTFail("advance()가 없다")
        }
        let body = String(flowSource[advanceRange.lowerBound...].prefix(220))
        for forbidden in ["await", "save", "appData", "UserDefaults", "modelContext"] {
            XCTAssertFalse(body.contains(forbidden), "다음으로 넘어가며 \(forbidden)을 한다")
        }
    }

    func testCurrentStepIsNeverPersisted() {
        for forbidden in ["UserDefaults", "@AppStorage", "SwiftData", "modelContext",
                          "currentStep\"", "\"recordCreateStep\""] {
            XCTAssertFalse(flowSource.contains(forbidden), "현재 단계를 \(forbidden)에 남긴다")
        }
        // 저장 요청에도 단계가 실리지 않는다.
        let dto = (try? executableSource("Domain/APIDTOs.swift")) ?? ""
        XCTAssertFalse(dto.contains("currentStep"), "저장 계약에 현재 단계가 생겼다")
        XCTAssertFalse(dto.contains("isDraft"), "저장 계약에 임시 상태가 생겼다")
    }

    func testGoingBackKeepsStep1Values() {
        // 초안은 흐름이 들고 있고 단계 전환으로 다시 만들어지지 않는다.
        XCTAssertEqual(flowSource.components(separatedBy: "RecordEditorDraft.make(").count - 1, 1,
                       "단계를 옮길 때마다 초안을 다시 만든다")
        XCTAssertTrue(flowSource.contains("@State private var draft: RecordEditorDraft"),
                      "초안이 흐름 밖에 있다")
    }

    // MARK: - 21~26. "여기까지만 저장할게요"

    func testMinimalSaveProducesAnOrdinarySaveInput() throws {
        let draft = validStep1Draft()
        let input = try XCTUnwrap(draft.makeSaveInput())
        XCTAssertEqual(input.favoriteTeam, KBOSeed.teams[0].name)
        XCTAssertEqual(input.opponentTeam, KBOSeed.teams[1].name)
        XCTAssertEqual(input.stadium, KBOSeed.stadiums[0])
        XCTAssertEqual(input.result, .win)
        XCTAssertEqual(input.ourScore, 5)
        XCTAssertEqual(input.opponentScore, 3)
    }

    func testMinimalSaveLeavesLaterStepValuesEmpty() {
        let draft = validStep1Draft()
        XCTAssertTrue(draft.seat.isEmpty)
        XCTAssertTrue(draft.companion.isEmpty)
        XCTAssertTrue(draft.shortMemo.isEmpty)
        XCTAssertTrue(draft.diary.isEmpty)
        XCTAssertTrue(draft.photo.refs.isEmpty)
    }

    func testMinimalSaveUsesTheExistingSaveBoundary() {
        XCTAssertTrue(flowSource.contains("appData.saveAttendanceLog("),
                      "기존 저장 경계를 쓰지 않는다")
        // 기록은 **하나만** 만들어진다. 저장 호출부가 하나뿐이고, 그 하나도
        // `isSaving` 문지기 뒤에 있다.
        XCTAssertEqual(flowSource.components(separatedBy: "appData.saveAttendanceLog(").count - 1, 1,
                       "저장 호출부가 둘 이상이다 — 기록이 여러 개 생길 수 있다")
        XCTAssertFalse(flowSource.contains("appData.updateAttendanceLog("),
                       "새로 만들기인데 수정 경로를 부른다")
        // 저장 전에 검증을 통과해야 한다.
        XCTAssertTrue(flowSource.contains("RecordEditorValidation.validate(draft, step: .game).isValid"))
    }

    func testMinimalSaveIsGuardedAgainstDuplicates() {
        XCTAssertTrue(flowSource.contains("guard !isSaving else { return }"), "중복 저장을 막지 않는다")
    }

    func testMinimalSaveFailurePreservesTheDraft() {
        // 아무것도 저장되지 않았으면 화면에 남는다. 초안을 비우거나 새로 만들지 않는다.
        XCTAssertTrue(flowSource.contains("guard appData.lastSaveMessage != nil else { return }"),
                      "저장이 아예 실패해도 화면을 닫는다")
        XCTAssertFalse(flowSource.contains("draft = RecordEditorDraft"), "실패 뒤 초안을 새로 만든다")
        XCTAssertTrue(flowSource.contains("saveMessage = appData.lastSaveMessage"),
                      "저장 결과를 사용자에게 알리지 않는다")
    }

    /// 서버 동기화 실패는 기록을 잃은 것이 아니다 — 지금 편집기와 같은 판단을 한다.
    func testServerSyncFailureIsNotTreatedAsALostRecord() throws {
        let boundary = try executableSource("Services/AppDataStore.swift")
        // 저장 경계는 로컬 저장을 먼저 끝낸 뒤에 서버로 간다.
        guard let saveRange = boundary.range(of: "func saveAttendanceLog(") else {
            return XCTFail("저장 경계가 없다")
        }
        let rest = boundary[saveRange.upperBound...]
        let end = rest.range(of: "func updateAttendanceLog(")?.lowerBound ?? rest.endIndex
        let body = String(rest[..<end])
        XCTAssertTrue(body.contains("createAttendanceLog(request)"), "로컬 저장 경로가 사라졌다")
        XCTAssertTrue(body.contains("return false"), "서버 실패 분기가 사라졌다")

        // 지금 편집기는 그 false를 이유로 화면을 붙잡아 두지 않는다.
        let editor = try executableSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(editor.contains("_ = await appData.saveAttendanceLog("),
                      "지금 편집기의 저장 판단이 달라졌다")
        // 새 흐름도 같은 판단을 한다: 서버 실패만으로는 화면에 갇히지 않는다.
        XCTAssertFalse(flowSource.contains("guard didSave else"), "서버 실패를 저장 실패로 오해한다")
    }

    func testMinimalSaveCreatesNoDraftOrPartialRecordType() {
        for forbidden in ["PartialRecord", "DraftRecord", "TemporaryRecord", "isPartial", "isTemporary"] {
            XCTAssertFalse(flowSource.contains(forbidden), "부분 기록 타입 \(forbidden)이 생겼다")
            XCTAssertFalse(step1Source.contains(forbidden), "부분 기록 타입 \(forbidden)이 생겼다")
        }
        let domain = (try? executableSource("Domain/VFDomain.swift")) ?? ""
        XCTAssertFalse(domain.contains("PartialRecord"))
        XCTAssertFalse(domain.contains("isDraft"))
    }

    // MARK: - 27~28. 임시저장은 만들지 않았다

    func testTemporarySaveIsNotImplemented() {
        for path in ["Features/LogEditor/RecordCreateFlowView.swift",
                     "Features/LogEditor/RecordCreateStep1View.swift"] {
            let body = (try? executableSource(path)) ?? ""
            XCTAssertFalse(body.contains("임시저장"), "\(path)에 임시저장이 구현됐다")
            XCTAssertFalse(body.contains("이어서"), "\(path)가 이어쓰기를 약속한다")
        }
    }

    func testDeferredTemporarySaveIsDocumented() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains("RESUMABLE_TEMPORARY_SAVE"), "미결 결정이 문서에 없다")
        XCTAssertTrue(doc.contains("임시저장"), "임시저장 유예가 문서에 없다")
    }

    // MARK: - 29~31. 보존해야 할 값들

    func testUnknownStadiumAndLinkedGameIdentityAreUntouched() {
        var draft = validStep1Draft()
        draft.stadiumName = "등록부에 없는 구장"
        draft.linkedKBOGameID = "KBO-2026-0416-SS-KIA"
        draft.officialRecordURL = "https://example.com/record"
        draft.gameSource = "kbo"
        let input = draft.makeSaveInput()
        XCTAssertEqual(input?.stadium, "등록부에 없는 구장", "모르는 구장을 지웠다")
        XCTAssertEqual(input?.linkedKBOGameID, "KBO-2026-0416-SS-KIA")
        XCTAssertEqual(input?.officialRecordURL, "https://example.com/record")
        XCTAssertEqual(input?.gameSource, "kbo")
    }

    func testStep1KeepsTheDraftAbleToReceiveKBOCandidateValues() {
        // 눈에 보이는 KBO 추천 자리는 Pencil 1단계에 없다. 값이 들어올 통로만 지킨다.
        var draft = freshDraft()
        draft.date = Self.calendarDate
        draft.favoriteTeamName = KBOSeed.teams[0].name
        draft.opponentTeamName = KBOSeed.teams[1].name
        draft.stadiumName = KBOSeed.stadiums[0]
        draft.result = .win
        draft.linkedKBOGameID = "KBO-CANDIDATE"
        draft.gameSource = "kbo"
        XCTAssertTrue(RecordEditorValidation.validate(draft, step: .game).isValid)
        XCTAssertEqual(draft.makeSaveInput()?.linkedKBOGameID, "KBO-CANDIDATE")
        XCTAssertEqual(RecordEditorField.linkedKBOGame.step, .game)
    }

    func testTicketOCRAndKBOSuggestionRemainInTheCurrentEditor() throws {
        let editor = try executableSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(editor.contains("applyTicketSuggestion"), "티켓 OCR 매핑이 사라졌다")
        XCTAssertTrue(editor.contains("applyKBOGameCandidate"), "KBO 추천 적용이 사라졌다")
        XCTAssertTrue(editor.contains("lookupKBOGameCandidates"), "KBO 추천 조회가 사라졌다")
        // 1단계 화면에는 아직 그 표면을 만들지 않는다 — Pencil 근거가 없다.
        XCTAssertFalse(step1Source.contains("TicketOCR"))
        XCTAssertFalse(step1Source.contains("KBOGameCandidate"))
    }

    // MARK: - 32~33. Pencil 구조와 문구

    func testAuthoredCopyIsReproduced() {
        for copy in ["어떤 경기였나요?", "필수만 적어도 충분해요", "경기 날짜", "구장",
                     "우리 팀", "상대 팀", "스코어", "다음 · 그날의 디테일", "여기까지만 저장할게요"] {
            XCTAssertTrue(step1Source.contains(copy), "Pencil 문구 \(copy)가 없다")
        }
    }

    func testProgressUsesTheSharedStepTitles() {
        XCTAssertEqual(RecordCreateStep.allCases.map(\.accessibilityTitle),
                       ["경기", "그날의 디테일", "나의 이야기"])
        XCTAssertEqual(RecordCreateStep.game.position, 1)
        XCTAssertEqual(RecordCreateStep.total, 3)
        XCTAssertTrue(step1Source.contains("VFStepProgress("), "공용 진행 표시를 쓰지 않는다")
    }

    // MARK: - 34. 디자인 시스템을 복제하지 않는다

    func testStep1ReusesSharedComponentsInsteadOfLocalDuplicates() {
        for component in ["VFFormField", "VFPrimaryButton", "VFResultStamp", "VFStepProgress"] {
            XCTAssertTrue(step1Source.contains(component), "공용 컴포넌트 \(component)를 쓰지 않는다")
        }
        // 색과 치수를 직접 적지 않는다.
        for hardCoded in ["Color(hex:", "#F2B63C", "#14171F", "#8B909E"] {
            XCTAssertFalse(step1Source.contains(hardCoded), "토큰 대신 값을 직접 적었다: \(hardCoded)")
        }
        // 축소로 레이아웃 실패를 가리지 않는다.
        XCTAssertFalse(step1Source.contains("minimumScaleFactor"), "축소로 레이아웃 실패를 가린다")
        XCTAssertFalse(step1Source.contains("dynamicTypeSize(..."), "Dynamic Type을 잘랐다")
    }
}

/// 스테이징 경계의 governance. 사용자 경로가 그대로인지, Release가 이 화면을 열 수
/// 있는지를 못박는다.
final class RecordCreateStep1GovernanceTests: XCTestCase {

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }

    private func rawSource(_ relativePath: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("소스를 찾을 수 없다: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 제품 타깃의 Swift 소스 전부. 앱 루트에 바로 놓인 파일(`AppRootView.swift` 등)도
    /// 포함해야 진입점 검사가 새는 곳 없이 돈다.
    private func productionSources() throws -> [(name: String, body: String)] {
        var result: [(String, String)] = []
        for case let url as URL in try FileManager.default.contentsOfDirectory(
            at: Self.appSourceRoot, includingPropertiesForKeys: nil
        ) as [URL] where url.pathExtension == "swift" {
            result.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
        }
        for folder in ["Features", "SharedComponents", "DesignSystem", "Domain", "Services", "Data"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                result.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return result
    }

    /// 주석을 걷어낸 본문. 주석에 적힌 낱말이 구현으로 오해되지 않게 한다.
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

    /// 일곱 개 사용자 경로는 여전히 지금 편집기를 띄운다.
    func testSevenProductionRoutesStillPresentTheCurrentEditor() throws {
        var callSites: [String] = []
        for entry in try productionSources() {
            for line in entry.body.split(separator: "\n") where line.contains("LogEditorView(") {
                callSites.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        let production = callSites.filter { !$0.hasPrefix("LogEditorView.swift") }
        XCTAssertEqual(production.count, 7, "진입점 수가 달라졌다: \(production)")
    }

    /// 그 어떤 사용자 경로도 아직 새 흐름으로 가지 않는다.
    func testNoProductionRouteEntersTheStagedFlow() throws {
        var callSites: [String] = []
        for entry in try productionSources() where entry.name != "RecordCreateFlowView.swift" {
            for line in entry.body.split(separator: "\n") where line.contains("RecordCreateFlowView(") {
                callSites.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertTrue(callSites.isEmpty, "새 흐름을 직접 부르는 곳이 생겼다: \(callSites)")

        // 유일한 진입은 스테이징 호스트이고, 그 호스트를 부르는 곳도 한 군데뿐이다.
        var hostSites: [String] = []
        for entry in try productionSources() where entry.name != "RecordCreateFlowView.swift" {
            for line in entry.body.split(separator: "\n") where line.contains("RecordCreateStagedHostView(") {
                hostSites.append("\(entry.name):\(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(hostSites.count, 1, "스테이징 호스트를 부르는 곳이 늘었다: \(hostSites)")
        XCTAssertTrue(hostSites[0].hasPrefix("AppRootView.swift"), "예상치 못한 곳에서 스테이징을 연다")
    }

    /// 스테이징 픽스처가 있어야만 열린다.
    func testStagedHostIsGatedBehindTheTestFixture() throws {
        let root = try rawSource("AppRootView.swift")
        XCTAssertTrue(root.contains("VFUITestConfiguration.activeRecordCreateStagedScenarioIdentifier"),
                      "스테이징 게이트가 없다")
        guard let range = root.range(of: "RecordCreateStagedHostView(") else { return XCTFail("호출부가 없다") }
        let before = String(root[..<range.lowerBound].suffix(400))
        XCTAssertTrue(before.contains("activeRecordCreateStagedScenarioIdentifier"),
                      "픽스처 게이트 밖에서 스테이징을 연다")
    }

    /// Release에서는 픽스처 자체가 존재할 수 없다.
    func testReleaseCannotActivateTheStagedFixture() throws {
        let configuration = try rawSource("Services/VFUITestConfiguration.swift")
        for accessor in ["recordCreateStagedFixture", "recordCreateStagedInitialDate",
                         "activeRecordCreateStagedScenarioIdentifier"] {
            guard let range = configuration.range(of: "static var \(accessor)") else {
                return XCTFail("\(accessor)가 없다")
            }
            let body = String(configuration[range.lowerBound...].prefix(600))
            guard let end = body.range(of: "#endif") else { return XCTFail("\(accessor)에 #endif가 없다") }
            let gated = String(body[..<end.upperBound])
            XCTAssertTrue(gated.contains("#if DEBUG"), "\(accessor)가 DEBUG 밖에서도 산다")
            XCTAssertTrue(gated.contains("#else"), "\(accessor)에 Release 분기가 없다")
            XCTAssertTrue(gated.contains("return nil"), "\(accessor)가 Release에서 값을 준다")
        }
    }

    /// 1단계 화면 자체는 제품 타깃에 있다. 테스트 타깃이 아니다.
    func testStep1ComponentIsCompiledIntoTheProductionTarget() {
        let step1 = Self.appSourceRoot.appendingPathComponent("Features/LogEditor/RecordCreateStep1View.swift")
        let flow = Self.appSourceRoot.appendingPathComponent("Features/LogEditor/RecordCreateFlowView.swift")
        let progress = Self.appSourceRoot.appendingPathComponent("SharedComponents/VFStepProgress.swift")
        for url in [step1, flow, progress] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent)이 제품 타깃 밖에 있다")
        }
        // 타입이 실제로 링크되는지. 컴파일되지 않으면 이 줄이 빌드되지 않는다.
        XCTAssertEqual(String(describing: RecordCreateStep1View.self), "RecordCreateStep1View")
        XCTAssertEqual(String(describing: RecordCreateFlowView.self), "RecordCreateFlowView")
        XCTAssertEqual(String(describing: VFStepProgress.self), "VFStepProgress")
    }

    /// 스테이징 픽스처는 사용자에게 열리는 경로가 아니다.
    func testStagedFixtureIsNotAUserAccessibleRoute() throws {
        let root = try rawSource("AppRootView.swift")
        // 탭 목록이 늘지 않았다.
        XCTAssertEqual(MainTab.allCases.count, 5, "탭이 늘었다")
        // 스테이징 가지는 탭 쉘 밖에 있고, 사용자가 도달할 수 있는 버튼이 없다.
        XCTAssertFalse(root.contains("Button(\"기록 작성 흐름\""), "사용자가 누를 수 있는 진입점이 생겼다")
    }

    /// 3단계의 권위 있는 레이아웃은 아직 없다.
    ///
    /// 2단계는 2026-08-01 패스에서 실제로 만들었으므로 그 문구는 이제 제품에 있다.
    /// 어디에 있어야 하는지까지 함께 못박아, 다른 화면으로 새어 나가지 않게 한다.
    func testNoVisibleStep3LayoutExistsAndStep2CopyStaysInStep2() throws {
        for entry in try productionSources() {
            let body = stripComments(entry.body)
            for authored in ["오늘의 이야기를 남겨주세요", "0 / 500"] {
                XCTAssertFalse(body.contains(authored),
                               "\(entry.name)에 3단계 문구 \(authored)가 생겼다")
            }
            if entry.name != "RecordCreateStep2View.swift" {
                XCTAssertFalse(body.contains("그날의 디테일을 더해볼까요"),
                               "\(entry.name)에 2단계 제목이 새어 나갔다")
            }
        }
        XCTAssertNil(RecordCreateStep.memory.next)
    }

    /// 접근성 취소는 두 화면 모두에 살아 있다.
    func testCancelActionsRemainInBothEditors() throws {
        let editor = try rawSource("Features/LogEditor/LogEditorView.swift")
        XCTAssertTrue(editor.contains("logEditor.cancel"), "기존 편집기의 취소가 사라졌다")
        let flow = try rawSource("Features/LogEditor/RecordCreateFlowView.swift")
        XCTAssertTrue(flow.contains("recordCreate.cancel"), "새 흐름에 취소가 없다")
    }
}
