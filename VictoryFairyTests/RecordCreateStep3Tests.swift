import XCTest
@testable import VictoryFairy

/// 개정 Pencil `08_RecordCreate_Step3`(`z0G0P`)의 보이는 레이아웃 계약.
///
/// 이 단계는 전부 선택 사항이고, 저장을 막는 것은 1단계 요구 조건뿐이다.
/// Pencil이 함께 그린 별점과 `0 / 500`은 저장할 자리가 없어 만들지 않는다.
final class RecordCreateStep3Tests: XCTestCase {

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

    private var step3Source: String { (try? executableSource("Features/LogEditor/RecordCreateStep3View.swift")) ?? "" }
    private var flowSource: String { (try? executableSource("Features/LogEditor/RecordCreateFlowView.swift")) ?? "" }

    private var step3ScreenSource: String {
        guard let range = step3Source.range(of: "#Preview") else { return step3Source }
        return String(step3Source[..<range.lowerBound])
    }

    /// `private func name()`의 본문만 잘라 온다.
    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "private func \(name)(") else {
            throw XCTSkip("\(name)()을 찾지 못했다")
        }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    }") else { throw XCTSkip("\(name)()의 끝을 찾지 못했다") }
        return String(rest[..<end.lowerBound])
    }

    // MARK: - 표본

    private func validDraft(memo: String = "", mood: String = "", diary: String = "",
                            photos: [String] = []) -> RecordEditorDraft {
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
        value.shortMemo = memo
        value.moodTag = mood
        value.diary = diary
        value.photo = RecordEditorPhotoDraft(originalRefs: [], refs: photos)
        return value
    }

    // MARK: - 1~3. 정본 초안, 기억 값만

    func test01_step3BindsToTheCanonicalDraft() {
        XCTAssertTrue(step3Source.contains("@Binding var draft: RecordEditorDraft"),
                      "3단계가 정본 초안에 바인딩하지 않는다")
    }

    func test02_noStep3DraftExists() {
        for forbidden in ["struct Step3Draft", "struct RecordCreateStep3Draft", "class Step3Model",
                          "struct Step3State", "@State private var draft"] {
            XCTAssertFalse(step3ScreenSource.contains(forbidden), "두 번째 초안 \(forbidden)이 생겼다")
        }
        XCTAssertEqual(flowSource.components(separatedBy: "RecordEditorDraft.make(").count - 1, 1,
                       "흐름이 초안을 두 번 만든다")
    }

    func test03_step3TouchesOnlyMemoryFields() {
        for owned in ["draft.photo", "draft.shortMemo", "draft.moodTag", "draft.diary"] {
            XCTAssertTrue(step3ScreenSource.contains(owned), "3단계가 \(owned)을 다루지 않는다")
        }
        let others = ["draft.date", "draft.stadiumName", "draft.favoriteTeamName",
                      "draft.opponentTeamName", "draft.result", "draft.ourScore",
                      "draft.opponentScore", "draft.linkedKBOGameID", "draft.seat", "draft.companion"]
        for keyPath in others {
            XCTAssertFalse(step3ScreenSource.contains(keyPath), "3단계가 남의 값 \(keyPath)을 만진다")
        }
        // 하이라이트는 보존하되 새 컨트롤을 만들지 않는다.
        XCTAssertFalse(step3ScreenSource.contains("draft.highlightTag = "), "하이라이트를 3단계가 쓴다")
        XCTAssertFalse(step3ScreenSource.contains("draft.appliedHighlightTags = "), "적용된 하이라이트를 3단계가 쓴다")
    }

    // MARK: - 4~5. 막는 값이 없다

    func test04_memoryStepHasNoBlockingField() {
        let empty = validDraft()
        XCTAssertTrue(RecordEditorValidation.validate(empty, step: .memory).blockingFields.isEmpty,
                      "3단계가 저장을 막는다")
        for field in RecordCreateStep.memory.supportedFields {
            XCTAssertFalse(field.isRequired, "\(field.rawValue)이 필수로 바뀌었다")
        }
    }

    func test05_everySupportedCombinationIsValid() {
        let combinations: [(String, String, String, [String])] = [
            ("", "", "", []),
            ("", "", "", ["photo-a"]),
            ("9회초 역전", "", "", []),
            ("", "행복", "", []),
            ("", "", "오래 기억할 하루", []),
            ("9회초 역전", "벅차오름", "좋았다", ["photo-a", "photo-b"])
        ]
        for (memo, mood, diary, photos) in combinations {
            let value = validDraft(memo: memo, mood: mood, diary: diary, photos: photos)
            XCTAssertTrue(RecordEditorValidation.validate(value, step: .memory).isValid,
                          "3단계가 막혔다: \(memo)/\(mood)/\(diary)")
            XCTAssertTrue(RecordEditorValidation.validate(value).isValid, "전체 저장이 막혔다")
        }
    }

    // MARK: - 6~7. 글이 그대로 오간다

    func test06_shortMemoRoundTripsUnchanged() {
        for written in ["9회초 박병호 역전 스리런", "walk-off HR ⚾️", "8회 대타 2타점 (좌중간)"] {
            let value = validDraft(memo: written)
            XCTAssertEqual(value.shortMemo, written, "\"\(written)\"이 바뀌었다")
            XCTAssertNotNil(value.makeSaveInput())
        }
    }

    func test07_diaryKeepsLineBreaksAndEmoji() {
        let written = "1회부터 조마조마했다.\n9회 역전 🎉\n\n오래 기억할 하루 ⚾️😭"
        let value = validDraft(diary: written)
        XCTAssertEqual(value.diary, written, "줄바꿈이나 이모지가 사라졌다")
        XCTAssertEqual(value.diary.components(separatedBy: "\n").count, 4, "줄이 합쳐졌다")
        XCTAssertTrue(RecordEditorValidation.validate(value).isValid, "긴 글이 저장을 막았다")
    }

    // MARK: - 8~11. 기분

    func test08_authoredMoodStringsAreWrittenExactly() {
        XCTAssertEqual(RecordCreateStep3View.moods, ["벅차오름", "행복", "뿌듯", "아쉬움", "약오름"],
                       "Pencil이 적은 기분과 다르다")
        for mood in RecordCreateStep3View.moods {
            let value = validDraft(mood: mood)
            XCTAssertEqual(value.moodTag, mood)
            XCTAssertEqual(RecordCreateStep3View.moodSelection(for: mood), mood,
                           "\(mood)이 선택으로 읽히지 않는다")
            // 저장 태그의 첫 자리가 기분이다.
            XCTAssertEqual(value.saveTags.first, mood)
        }
    }

    func test09_onlyOneMoodIsSelected() {
        for mood in RecordCreateStep3View.moods {
            let selected = RecordCreateStep3View.moodSelection(for: mood)
            for other in RecordCreateStep3View.moods where other != mood {
                XCTAssertNotEqual(selected, other, "\(mood)일 때 \(other)도 선택으로 보인다")
            }
        }
    }

    func test10_unknownExistingMoodIsPreserved() {
        // 지금 편집기와 스테이징 흐름은 기본 기분을 미리 넣는다. 그 값은 다섯 칩에
        // 없지만 지워지지 않는다.
        for unknown in ["짜릿함", "설렘", "사진 분석이 넣은 값"] {
            let value = validDraft(mood: unknown)
            XCTAssertEqual(value.moodTag, unknown, "모르는 기분이 지워졌다")
            XCTAssertNil(RecordCreateStep3View.moodSelection(for: unknown),
                         "모르는 값이 칩으로 선택돼 보인다")
            XCTAssertEqual(value.saveTags.first, unknown, "저장 태그에서 사라졌다")
        }
    }

    func test11_choosingAChipReplacesAnUnknownMood() {
        var value = validDraft(mood: "짜릿함")
        value.moodTag = "행복"
        XCTAssertEqual(value.moodTag, "행복")
        XCTAssertEqual(RecordCreateStep3View.moodSelection(for: value.moodTag), "행복")
        // 화면은 기분에 두 번째 진실 원본을 두지 않는다.
        XCTAssertFalse(step3ScreenSource.contains("@State private var mood"), "기분에 화면 상태가 생겼다")
        XCTAssertFalse(step3ScreenSource.contains("enum Mood"), "숨은 기분 타입이 생겼다")
    }

    // MARK: - 12~15. 사진

    func test12_photosUseTheExistingPhotoDraft() {
        XCTAssertTrue(step3ScreenSource.contains("RecordEditorPhotoAttachment.importItems"),
                      "공용 사진 규칙을 쓰지 않는다")
        XCTAssertTrue(step3ScreenSource.contains("AttachmentPhotoView"), "기존 썸네일 뷰를 쓰지 않는다")
        XCTAssertFalse(step3ScreenSource.contains("PhotoAttachmentService()"),
                       "3단계가 사진 서비스를 직접 만든다")
        // 지금 편집기도 같은 규칙을 쓴다 — 두 벌이 되지 않았다.
        let editor = (try? executableSource("Features/LogEditor/LogEditorView.swift")) ?? ""
        XCTAssertTrue(editor.contains("RecordEditorPhotoAttachment.importItems"),
                      "지금 편집기가 다른 규칙을 쓴다")
        XCTAssertEqual(RecordEditorPhotoAttachment.maximumPhotoCount, 10, "최대 장수가 바뀌었다")
    }

    func test13_pickerCancellationPreservesPhotos() async {
        let photo = RecordEditorPhotoDraft(originalRefs: ["a"], refs: ["a", "b"])
        let result = await RecordEditorPhotoAttachment.importItems([], into: photo)
        XCTAssertEqual(result.outcome, .nothingSelected, "취소가 다른 결과를 낸다")
        XCTAssertEqual(result.photo.refs, ["a", "b"], "취소했는데 사진이 바뀌었다")
        XCTAssertNil(result.outcome.message, "취소했는데 안내가 뜬다")
    }

    func test14_failureAndLimitPreservePhotos() async {
        // 자리가 없을 때도 이미 있던 사진은 그대로다.
        let full = RecordEditorPhotoDraft(originalRefs: [], refs: (1...10).map { "p\($0)" })
        XCTAssertEqual(RecordEditorPhotoAttachment.remainingSlots(for: full), 0)
        let result = await RecordEditorPhotoAttachment.importItems([], into: full)
        XCTAssertEqual(result.photo.refs.count, 10, "자리가 없다고 사진이 줄었다")
        XCTAssertEqual(RecordEditorPhotoAttachment.ImportOutcome.limitReached(limit: 10).message,
                       "사진은 최대 10장까지 추가할 수 있어요.")
        // 디코딩 실패 경로에는 삭제가 없다 — 더하기만 한다.
        let attachment = try! String(
            contentsOf: Self.appSourceRoot.appendingPathComponent("Features/LogEditor/RecordEditorPhotoAttachment.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(attachment.contains(".remove("), "실패 경로가 사진을 지운다")
        XCTAssertFalse(attachment.contains("refs = []"), "실패 경로가 사진을 비운다")
    }

    func test15_removalIsExplicitOnly() {
        var photo = RecordEditorPhotoDraft(originalRefs: ["a", "b"], refs: ["a", "b"])
        photo.remove("a")
        XCTAssertEqual(photo.refs, ["b"])
        XCTAssertEqual(photo.removedRefs, ["a"], "지운 사진이 기록되지 않는다")
        XCTAssertEqual(photo.state, .replacedExisting)
        // 화면에서 지우는 곳은 명시적인 삭제 버튼 하나뿐이다.
        XCTAssertEqual(step3ScreenSource.components(separatedBy: "draft.photo.remove(").count - 1, 1,
                       "사진을 지우는 곳이 둘 이상이다")
    }

    // MARK: - 16~17. 뒤로

    func test16_backPreservesEveryStep() {
        XCTAssertTrue(flowSource.contains("@State private var draft: RecordEditorDraft"))
        XCTAssertTrue(flowSource.contains("step = previous"), "이전 단계 이동이 없다")
        XCTAssertEqual(RecordCreateStep.memory.previous, .details)
        XCTAssertEqual(RecordCreateStep.details.previous, .game)
    }

    func test17_backPerformsNoSave() throws {
        let body = try functionBody(named: "goBack", in: flowSource)
        for forbidden in ["await", "save", "appData", "UserDefaults", "modelContext"] {
            XCTAssertFalse(body.contains(forbidden), "이전으로 가며 \(forbidden)을 한다: \(body)")
        }
    }

    // MARK: - 18~27. 기록 완성하기

    func test18_finalCTAValidatesStep1Only() throws {
        let body = try functionBody(named: "completeRecord", in: flowSource)
        XCTAssertTrue(body.contains("RecordEditorValidation.validate(draft).isValid"),
                      "완성이 전체 검증을 부르지 않는다")
        // 2·3단계 값을 따로 요구하지 않는다.
        for forbidden in ["seat.isEmpty", "companion.isEmpty", "diary.isEmpty",
                          "shortMemo.isEmpty", "photo.refs.isEmpty", "moodTag.isEmpty"] {
            XCTAssertFalse(body.contains(forbidden), "완성이 \(forbidden)을 요구한다")
        }
        // 전체 검증의 막는 값은 1단계 것뿐이다.
        var bare = RecordEditorDraft.make(mode: .create, defaultMoodTag: "", defaultHighlightTag: "",
                                          fallbackDate: Date())
        XCTAssertEqual(RecordEditorValidation.validate(bare).blockingFields,
                       [.favoriteTeam, .opponentTeam, .stadium, .result])
        bare.diary = "일기만 적어도"
        XCTAssertEqual(RecordEditorValidation.validate(bare).blockingFields.count, 4,
                       "3단계 값이 검증에 끼어들었다")
    }

    func test19and20_invalidFinalSaveRoutesToGameAndKeepsValues() throws {
        let body = try functionBody(named: "completeRecord", in: flowSource)
        XCTAssertTrue(body.contains("step = .game"), "막혔는데 1단계로 되돌리지 않는다")
        XCTAssertTrue(body.contains("didFailFinalValidation = true"), "안내를 띄우라고 알리지 않는다")
        // 되돌릴 때 값을 지우지 않는다.
        for destructive in ["draft = RecordEditorDraft", "draft.seat = \"\"", "draft.diary = \"\"",
                            "draft.photo = RecordEditorPhotoDraft("] {
            XCTAssertFalse(body.contains(destructive), "되돌리며 값을 지운다: \(destructive)")
        }
        // 1단계는 되돌아왔을 때 안내를 이미 띄운 채로 열린다.
        let step1 = (try? executableSource("Features/LogEditor/RecordCreateStep1View.swift")) ?? ""
        XCTAssertTrue(step1.contains("showsValidationOnAppear"), "1단계가 안내를 띄울 방법이 없다")
    }

    func test21and22_successfulSaveCreatesOneOrdinaryRecordWithEveryStep() throws {
        let draft = validDraft(memo: "9회초 역전", mood: "벅차오름", diary: "좋았다", photos: ["p1"])
        var full = draft
        full.seat = "3루 K열"
        full.companion = "엄마랑"
        let input = try XCTUnwrap(full.makeSaveInput())
        XCTAssertEqual(input.favoriteTeam, KBOSeed.teams[0].name)
        XCTAssertEqual(input.result, .win)
        XCTAssertEqual(full.seat, "3루 K열")
        XCTAssertEqual(full.companion, "엄마랑")
        XCTAssertEqual(full.shortMemo, "9회초 역전")
        XCTAssertEqual(full.diary, "좋았다")
        XCTAssertEqual(full.photo.refs, ["p1"])
        XCTAssertEqual(full.saveTags.first, "벅차오름")
        // 저장 호출부는 하나뿐이다 — 기록이 하나만 생긴다.
        XCTAssertEqual(flowSource.components(separatedBy: "appData.saveAttendanceLog(").count - 1, 1,
                       "저장 호출부가 둘 이상이다")
    }

    func test23_finalSaveOmitsRating() throws {
        for path in ["Features/LogEditor/RecordCreateStep3View.swift",
                     "Features/LogEditor/RecordCreateFlowView.swift",
                     "Features/LogEditor/RecordEditorDraft.swift",
                     "Domain/VFDomain.swift", "Domain/APIDTOs.swift"] {
            let body = try executableSource(path)
            for needle in ["별점", "starCount", "score5", "몇 점이었나요"] {
                XCTAssertFalse(body.contains(needle), "\(path)에 별점 \(needle)이 들어갔다")
            }
            // 낱말로서의 `rating`만 찾는다. `isGeneratingAIDraft` 속의 철자는 별점이 아니다.
            XCTAssertNil(
                body.range(of: "(?<![A-Za-z])rating", options: [.regularExpression, .caseInsensitive]),
                "\(path)에 별점 rating이 들어갔다"
            )
        }
        let mirror = Mirror(reflecting: validDraft())
        for label in mirror.children.compactMap(\.label) {
            XCTAssertFalse(label.lowercased().contains("rating"), "초안에 \(label)이 생겼다")
        }
    }

    func test24_finalSaveHasNoDiaryLimit() throws {
        let long = String(repeating: "가", count: 1200)
        var value = validDraft(diary: long)
        XCTAssertEqual(value.diary.count, 1200, "일기가 잘렸다")
        XCTAssertTrue(RecordEditorValidation.validate(value).isValid, "긴 일기가 저장을 막았다")
        value.diary = long + "더"
        XCTAssertEqual(value.diary.count, 1201)
        for path in ["Features/LogEditor/RecordCreateStep3View.swift",
                     "Features/LogEditor/RecordEditorValidation.swift",
                     "Features/LogEditor/RecordEditorDraft.swift"] {
            let body = try executableSource(path)
            for needle in ["0 / 500", "500", "prefix(500", "characterLimit", "maxLength"] {
                XCTAssertFalse(body.contains(needle), "\(path)에 글자 수 제한 \(needle)이 생겼다")
            }
        }
    }

    func test25_finalSaveUsesTheExistingBoundary() throws {
        let body = try functionBody(named: "save", in: flowSource)
        XCTAssertTrue(body.contains("appData.saveAttendanceLog("), "기존 저장 경계를 쓰지 않는다")
        XCTAssertFalse(body.contains("appData.updateAttendanceLog("), "새로 만들기인데 수정 경로를 부른다")
        XCTAssertTrue(body.contains("photoLocalRefs: draft.photo.refs"), "사진이 저장에 실리지 않는다")
        // 오프라인 대체 정책은 그대로다 — 서버 확인을 요구하지 않는다.
        XCTAssertFalse(body.contains("guard didSave else"), "서버 실패를 저장 실패로 오해한다")
        XCTAssertTrue(body.contains("appData.lastSaveMessage != nil"), "저장 여부 판단이 바뀌었다")
    }

    func test26_duplicateFinalTapsSaveOnce() throws {
        let complete = try functionBody(named: "completeRecord", in: flowSource)
        XCTAssertTrue(complete.contains("guard !isSaving else { return }"), "중복 제출을 막지 않는다")
        // 화면도 저장 중에는 버튼을 잠근다.
        XCTAssertTrue(step3ScreenSource.contains("isEnabled: !isSaving"), "저장 중에도 버튼이 살아 있다")
    }

    func test27_saveFailurePreservesDraftAndPhotos() throws {
        let body = try functionBody(named: "save", in: flowSource)
        XCTAssertTrue(body.contains("guard appData.lastSaveMessage != nil else { return }"),
                      "저장이 아예 실패해도 화면을 닫는다")
        for destructive in ["draft = RecordEditorDraft", "draft.photo = RecordEditorPhotoDraft(",
                            "draft.diary = \"\"", "refs = []"] {
            XCTAssertFalse(body.contains(destructive), "실패 뒤 값을 지운다: \(destructive)")
        }
        XCTAssertTrue(body.contains("saveMessage = appData.lastSaveMessage"), "오류를 알리지 않는다")
    }

    // MARK: - 28~32. 만들지 않은 것

    func test28_currentStepIsNeverPersisted() {
        for forbidden in ["UserDefaults", "@AppStorage", "SwiftData", "modelContext", "currentStep"] {
            XCTAssertFalse(flowSource.contains(forbidden), "현재 단계를 \(forbidden)에 남긴다")
            XCTAssertFalse(step3ScreenSource.contains(forbidden), "3단계가 \(forbidden)을 쓴다")
        }
    }

    func test29_noTemporarySavePersistenceExists() throws {
        for path in ["Features/LogEditor/RecordCreateFlowView.swift",
                     "Features/LogEditor/RecordCreateStep3View.swift"] {
            let body = try executableSource(path)
            XCTAssertFalse(body.contains("임시저장"), "\(path)에 임시저장이 생겼다")
            for forbidden in ["autosave", "draftStorage", "resumable"] {
                XCTAssertFalse(body.lowercased().contains(forbidden), "\(path)에 \(forbidden)이 생겼다")
            }
        }
    }

    func test30and31_noRatingOrDiaryLimitInTheContract() throws {
        let dto = try executableSource("Domain/APIDTOs.swift")
        for forbidden in ["rating", "starCount", "diaryLimit", "maxDiary", "currentStep", "isDraft"] {
            XCTAssertFalse(dto.contains(forbidden), "저장 계약에 \(forbidden)이 생겼다")
        }
        // 지원하는 세 값은 그대로 실려 나간다.
        for kept in ["shortMemo", "diaryText", "moodTags", "photoLocalRefs"] {
            XCTAssertTrue(dto.contains(kept), "\(kept) 계약이 사라졌다")
        }
    }

    func test32_noSchemaAPIOrBackendChange() throws {
        let domain = try executableSource("Domain/VFDomain.swift")
        for forbidden in ["rating", "weather", "food", "cheeringGear", "isPartial"] {
            XCTAssertFalse(domain.contains(forbidden), "도메인에 \(forbidden)이 생겼다")
        }
    }

    // MARK: - 33~35. 경계

    func test33_productionRouteSplitRemainsFiveCreateAndTwoEdit() throws {
        var callSites: [String] = []
        for case let url as URL in FileManager.default.enumerator(
            at: Self.appSourceRoot, includingPropertiesForKeys: nil
        )!.allObjects as! [URL] where url.pathExtension == "swift" {
            guard url.lastPathComponent != "LogEditorView.swift" else { continue }
            let body = try String(contentsOf: url, encoding: .utf8)
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

    func test34_stagedFixtureIsUnavailableInRelease() throws {
        let configuration = try source("Services/VFUITestConfiguration.swift")
        guard let range = configuration.range(of: "static var recordCreateStagedFixture") else {
            return XCTFail("스테이징 픽스처 접근자가 없다")
        }
        let body = String(configuration[range.lowerBound...].prefix(600))
        guard let end = body.range(of: "#endif") else { return XCTFail("#endif가 없다") }
        let gated = String(body[..<end.upperBound])
        XCTAssertTrue(gated.contains("#if DEBUG") && gated.contains("#else") && gated.contains("return nil"))
    }

    func test35_step1AndStep2BehaviourRemainIntact() throws {
        let step1 = try executableSource("Features/LogEditor/RecordCreateStep1View.swift")
        let step2 = try executableSource("Features/LogEditor/RecordCreateStep2View.swift")
        XCTAssertTrue(step1.contains("RecordEditorValidation.validate(draft, step: .game)"))
        XCTAssertTrue(step1.contains("여기까지만 저장할게요"), "1단계 최소 저장이 사라졌다")
        XCTAssertFalse(step1.contains(".accessibilityLabel(\"경기 날짜\")"), "날짜 라벨 중복이 되살아났다")
        XCTAssertEqual(RecordCreateStep2View.quickCompanions, ["혼자", "엄마랑", "친구랑"])
        XCTAssertTrue(step2.contains("이 단계는 건너뛸게요"), "2단계 건너뛰기가 사라졌다")
        // 2단계는 여전히 아무것도 막지 않는다.
        XCTAssertTrue(RecordEditorValidation.validate(validDraft(), step: .details).isValid)
        // 지금 편집기의 능력이 그대로 살아 있다.
        let editor = try executableSource("Features/LogEditor/LogEditorView.swift")
        for capability in ["applyTicketSuggestion", "applyKBOGameCandidate", "analyzePhotos", "generateAIDraft"] {
            XCTAssertTrue(editor.contains(capability), "지금 편집기의 \(capability)이 사라졌다")
        }
    }

    // MARK: - 36~38. 화면 구조

    func test36_authoredCopyIsReproduced() {
        for copy in ["오늘의 이야기를 남겨주세요", "사진 한 장과 짧은 한마디면 충분해요", "사진",
                     "가장 기억에 남는 순간", "오늘의 기분", "짧은 일기", "기록 완성하기",
                     "선택한 사진에만 접근해요 · 설정에서 변경"] {
            XCTAssertTrue(step3ScreenSource.contains(copy), "Pencil 문구 \(copy)가 없다")
        }
    }

    func test37_progressUsesTheSharedComponentAtStepThree() {
        XCTAssertTrue(step3ScreenSource.contains("VFStepProgress("), "공용 진행 표시를 쓰지 않는다")
        XCTAssertTrue(step3ScreenSource.contains("RecordCreateStep.memory.position - 1"))
        XCTAssertEqual(RecordCreateStep.memory.position, 3)
        XCTAssertEqual(RecordCreateStep.memory.accessibilityTitle, "나의 이야기")
    }

    func test38_assistanceParityIsPresentAndNothingElseIsInvented() {
        // 지금 편집기가 이미 가진 두 가지는 3단계에서도 닿을 수 있어야 한다.
        for parity in ["사진 분석", "AI 초안"] {
            XCTAssertTrue(step3ScreenSource.contains(parity), "3단계에서 \(parity)에 닿을 수 없다")
        }
        // 1단계가 맡은 것과 없는 기능은 여전히 여기 없다.
        for invented in ["경기 선택", "KBO 경기", "티켓", "날씨", "응원 준비물"] {
            XCTAssertFalse(step3ScreenSource.contains(invented), "3단계가 \(invented) 표면을 지어냈다")
        }
        for hardCoded in ["Color(hex:", "#F2B63C", "#14171F", "#8B909E", "#E2E3E1"] {
            XCTAssertFalse(step3ScreenSource.contains(hardCoded), "토큰 대신 값을 직접 적었다: \(hardCoded)")
        }
        XCTAssertFalse(step3ScreenSource.contains("minimumScaleFactor"), "축소로 레이아웃 실패를 가린다")
        XCTAssertFalse(step3ScreenSource.contains("dynamicTypeSize(..."), "Dynamic Type을 잘랐다")
        for fairy in ["VFFairyGlyph", "TeamFairy", "StadiumFairy"] {
            XCTAssertFalse(step3ScreenSource.contains(fairy), "Pencil에 없는 \(fairy)를 넣었다")
        }
    }
}
