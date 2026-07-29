import XCTest
@testable import VictoryFairy

/// 기록 상세의 의미 매핑이 저장된 기록과 맞는지 확인한다.
///
/// 화면 없이 값만 본다. Pencil이 예시로 적어 둔 문장이 아니라, 넘긴 기록에서 나와야 할
/// 값을 직접 계산해 비교한다.
final class RecordDetailTests: XCTestCase {

    private let service = RecordDetailService()
    private let calendar = RecordDetailService.referenceCalendar()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 18) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        return components.date!
    }

    private func log(
        _ seed: Int = 1,
        result: GameResult = .win,
        ours: Int? = 6,
        theirs: Int? = 3,
        matchup: String = "삼성 vs LG",
        stadium: String = "잠실야구장",
        seat: String = "3루 원정석 K열",
        companion: String = "엄마랑",
        memo: String = "목이 다 쉰 날",
        diary: String = "9회초 대타 한 방으로 뒤집은 날.",
        tags: [String] = ["벅차오름", "역전승"],
        photos: [String] = [],
        when: Date? = nil
    ) -> AttendanceLogViewState {
        let value = when ?? date(2026, 4, 12)
        return AttendanceLogViewState(
            id: UUID(uuidString: String(format: "BBBBBBBB-0000-4000-8000-%012d", seed))!,
            date: value,
            dateText: DateFormatter.vfDisplayDate.string(from: value),
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ours,
            opponentScore: theirs,
            seat: seat,
            companion: companion,
            memo: memo,
            caption: "",
            diary: diary,
            tags: tags,
            photoLocalRefs: photos
        )
    }

    private func present(
        _ entry: AttendanceLogViewState,
        teamID: String? = "samsung-lions",
        displayName: String? = "민지",
        media: RecordDetailMedia = .none
    ) -> RecordDetailPresentation {
        service.presentation(
            log: entry,
            favoriteTeam: KBOSeed.team(id: teamID),
            displayName: displayName,
            media: media
        )
    }

    // MARK: - 1. 기준 기록

    func testReferencePresentationMapsEveryVisibleValue() {
        let detail = present(VFRecordDetailFixtures.referenceLog)
        XCTAssertEqual(detail.navigationTitle, "2026년 4월 12일")
        XCTAssertEqual(detail.title, "목이 다 쉰 날")
        XCTAssertEqual(detail.placeMeta, "잠실야구장 · 3루 원정석 K열")
        XCTAssertEqual(detail.matchup.myTeam?.name, "삼성 라이온즈")
        XCTAssertEqual(detail.matchup.opponent?.name, "LG 트윈스")
        XCTAssertEqual(detail.matchup.result, .win)
        XCTAssertEqual(detail.matchup.scoreText, "6 : 3")
        XCTAssertEqual(detail.stadium.stadiumID, "jamsil")
        XCTAssertEqual(detail.moodTag, "벅차오름")
        XCTAssertEqual(detail.highlightTags, ["역전승"])
        XCTAssertEqual(detail.season, 2026)
        XCTAssertEqual(detail.recordID, VFRecordDetailFixtures.referenceLog.id)
    }

    func testPresentationIsDeterministic() {
        let entry = VFRecordDetailFixtures.referenceLog
        XCTAssertEqual(present(entry), present(entry))
    }

    // MARK: - 2. 매치업과 결과

    /// 매치업 문자열 해석은 도메인이 한다. 화면이 문자열을 자르지 않는다.
    func testMatchupResolutionPutsTheFavouriteTeamFirst() {
        let written = present(log(matchup: "LG vs 삼성"), teamID: "samsung-lions")
        XCTAssertEqual(written.matchup.myTeam?.name, "삼성 라이온즈", "응원 팀이 상대 자리로 갔다")
        XCTAssertEqual(written.matchup.opponent?.name, "LG 트윈스")
    }

    func testMatchupKeepsWrittenOrderWhenFavouriteTeamIsUnknown() {
        let detail = present(log(matchup: "LG vs 삼성"), teamID: nil)
        XCTAssertEqual(detail.matchup.myTeam?.name, "LG 트윈스")
        XCTAssertEqual(detail.matchup.opponent?.name, "삼성 라이온즈")
    }

    func testScoreFormattingIsDeterministic() {
        XCTAssertEqual(present(log(ours: 6, theirs: 3)).matchup.scoreText, "6 : 3")
        XCTAssertEqual(present(log(ours: 0, theirs: 12)).matchup.scoreText, "0 : 12")
    }

    func testMissingScoreDoesNotInventNumbers() {
        let detail = present(log(ours: nil, theirs: nil))
        XCTAssertNil(detail.matchup.scoreText)
        XCTAssertEqual(detail.matchup.scorePlaceholder, "점수 미기록")
        XCTAssertTrue(detail.matchup.spokenSummary.contains("점수 미기록"))
    }

    /// 취소 경기는 점수를 보여 주지 않는다. 저장된 숫자가 있어도 경기가 열리지 않았다.
    func testCancelledGameHidesTheScore() {
        let detail = present(log(result: .canceled, ours: 6, theirs: 3))
        XCTAssertNil(detail.matchup.scoreText)
        XCTAssertNil(detail.matchup.myScore)
        XCTAssertEqual(detail.matchup.scorePlaceholder, "경기 취소")
    }

    func testMissingOpponentIsHonest() {
        let detail = present(log(matchup: "삼성"))
        XCTAssertEqual(detail.matchup.myTeam?.name, "삼성 라이온즈")
        XCTAssertNil(detail.matchup.opponent, "상대가 없는데 팀을 지어냈다")
        XCTAssertTrue(detail.matchup.spokenSummary.contains("삼성 라이온즈"))
    }

    /// 결과는 색이 아니라 글자로도 남는다.
    func testResultIsAlwaysAvailableAsAWord() {
        for result in GameResult.allCases {
            let detail = present(log(result: result))
            XCTAssertFalse(detail.matchup.resultTitle.isEmpty)
            XCTAssertFalse(detail.matchup.resultDescription.isEmpty)
            XCTAssertTrue(detail.matchup.spokenSummary.contains(detail.matchup.resultDescription))
        }
    }

    // MARK: - 3. 팀

    func testEveryCanonicalTeamProducesAValidPresentation() {
        XCTAssertEqual(KBOSeed.teams.count, 10)
        for team in KBOSeed.teams {
            let rival = KBOSeed.teams.first { $0.id != team.id }!
            let detail = present(
                log(matchup: "\(team.shortName) vs \(rival.shortName)"),
                teamID: team.id
            )
            XCTAssertEqual(detail.matchup.myTeam?.teamID, team.id, "\(team.name) 매핑이 틀렸다")
            XCTAssertEqual(detail.matchup.myTeam?.name, team.name)
            XCTAssertEqual(detail.matchup.opponent?.teamID, rival.id)
            XCTAssertFalse(detail.matchup.myTeam?.badgeText.isEmpty ?? true)
            XCTAssertEqual(
                detail.matchup.myTeam?.accessibilityIdentifierSuffix, team.id,
                "식별자가 canonical 팀 ID가 아니다"
            )
        }
    }

    /// 상세 화면이 자기만의 팀 목록을 만들지 않는다.
    func testTeamsComeFromTheCanonicalRegistry() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for relative in [
            "VictoryFairy/Domain/RecordDetail.swift",
            "VictoryFairy/Domain/Services/RecordDetailService.swift",
            "VictoryFairy/Features/RecordDetail/RecordDetailViews.swift"
        ] {
            let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            for name in ["LG 트윈스", "두산 베어스", "삼성 라이온즈", "KIA 타이거즈"] {
                XCTAssertFalse(text.contains("\"\(name)\""),
                               "\(relative)가 팀 이름을 직접 들고 있다: \(name)")
            }
        }
    }

    // MARK: - 4. 구장

    func testEveryCanonicalStadiumProducesAValidPresentation() {
        XCTAssertEqual(KBOStadiumSeed.all.count, 9)
        for stadium in KBOStadiumSeed.all {
            let detail = present(log(stadium: stadium.name))
            XCTAssertEqual(detail.stadium.stadiumID, stadium.id, "\(stadium.name) 매핑이 틀렸다")
            XCTAssertEqual(detail.stadium.name, stadium.name)
            XCTAssertTrue(detail.stadium.isKnown)
            XCTAssertNotNil(detail.stadium.meta, "\(stadium.name) 메타가 비었다")
            XCTAssertEqual(detail.stadium.accessibilityIdentifierSuffix, stadium.id)
        }
    }

    /// 기록의 구장은 주 관람 구장이나 응원 팀 홈 구장으로 대체되지 않는다.
    func testRecordStadiumIsNeverReplaced() {
        // 응원 팀은 삼성(홈: 대구)이고 주 관람 구장이 무엇이든, 기록은 사직에서 남겼다.
        let detail = present(log(stadium: "사직야구장"), teamID: "samsung-lions")
        XCTAssertEqual(detail.stadium.name, "사직야구장")
        XCTAssertEqual(detail.stadium.stadiumID, "sajik")
        XCTAssertNotEqual(detail.stadium.name, KBOSeed.team(id: "samsung-lions")?.homeStadiumName)
        XCTAssertEqual(detail.stadium.isHomeGame, false)
    }

    func testHomeAndAwayComeFromTheRegistryNotFromGuessing() {
        let home = present(log(stadium: "대구 삼성 라이온즈 파크"), teamID: "samsung-lions")
        XCTAssertEqual(home.stadium.isHomeGame, true)
        XCTAssertEqual(home.stadium.eyebrow, "HOME GAME · 홈 직관")

        let away = present(log(stadium: "잠실야구장"), teamID: "samsung-lions")
        XCTAssertEqual(away.stadium.isHomeGame, false)
        XCTAssertEqual(away.stadium.eyebrow, "AWAY GAME · 원정 직관")

        // 응원 팀을 모르면 홈·원정을 단정하지 않는다.
        let unknownTeam = present(log(stadium: "잠실야구장"), teamID: nil)
        XCTAssertNil(unknownTeam.stadium.isHomeGame)
        XCTAssertNil(unknownTeam.stadium.eyebrow)
    }

    /// 등록부에 없는 이름은 그대로 남는다. 다른 구장으로 옮기지 않는다.
    func testUnknownStadiumKeepsItsNameAndStaysHonest() {
        let detail = present(log(stadium: "동대문운동장"))
        XCTAssertEqual(detail.stadium.name, "동대문운동장")
        XCTAssertNil(detail.stadium.stadiumID)
        XCTAssertFalse(detail.stadium.isKnown)
        XCTAssertNil(detail.stadium.isHomeGame)
        XCTAssertEqual(detail.stadium.accessibilityIdentifierSuffix, "unknown")
    }

    func testMissingStadiumIsReportedAsMissing() {
        let detail = present(log(stadium: ""))
        XCTAssertNil(detail.stadium.name)
        XCTAssertNil(detail.stadium.stadiumID)
        XCTAssertEqual(detail.stadium.accessibilityIdentifierSuffix, "missing")
        XCTAssertEqual(detail.stadium.spokenSummary, "구장 정보 없음")
        XCTAssertEqual(detail.placeMeta, "3루 원정석 K열", "구장이 없는데 자리를 지어냈다")
    }

    // MARK: - 5. 미디어

    func testEveryMediaStateIsDistinct() {
        let states: [RecordDetailMedia] = [
            .none, .loading, .available(refs: ["a"]), .missingFile(refs: ["a"]), .decodeFailed(refs: ["a"])
        ]
        let suffixes = states.map(\.accessibilityIdentifierSuffix)
        XCTAssertEqual(Set(suffixes).count, states.count, "상태 식별자가 겹친다")
        let spoken = states.map(\.spokenSummary)
        XCTAssertEqual(Set(spoken).count, states.count, "읽어 주는 문장이 겹친다")

        XCTAssertTrue(RecordDetailMedia.available(refs: ["a"]).hasUsableImage)
        for state in [RecordDetailMedia.none, .loading, .missingFile(refs: ["a"]), .decodeFailed(refs: ["a"])] {
            XCTAssertFalse(state.hasUsableImage, "\(state) 가 쓸 수 있는 이미지로 취급됐다")
        }
    }

    /// 사진 없음과 파일 없음은 다른 사실이라 다른 문구를 쓴다.
    func testNoPhotoAndMissingFileAreNotTheSameMessage() {
        XCTAssertNotEqual(RecordDetailMedia.none.message, RecordDetailMedia.missingFile(refs: ["a"]).message)
        XCTAssertNotEqual(
            RecordDetailMedia.missingFile(refs: ["a"]).message,
            RecordDetailMedia.decodeFailed(refs: ["a"]).message
        )
        XCTAssertNotNil(RecordDetailMedia.none.message)
        XCTAssertNil(RecordDetailMedia.available(refs: ["a"]).message)
    }

    /// 참조가 없으면 파일을 찾아보지도 않는다.
    func testMediaStateForEmptyReferencesIsNone() {
        XCTAssertEqual(PhotoAttachmentService().mediaState(for: [], maxPixel: 320), .none)
    }

    /// 존재하지 않는 참조는 "파일 없음"이지 "사진 없음"이 아니다.
    func testMediaStateForAbsentFileIsMissingFile() {
        let refs = ["vf-unit-test-absent-photo"]
        XCTAssertEqual(
            PhotoAttachmentService().mediaState(for: refs, maxPixel: 320),
            .missingFile(refs: refs)
        )
    }

    // MARK: - 6. 사용자가 쓴 기록

    func testNoteBodyIsShownExactlyAsWritten() {
        let body = "첫 줄\n\n둘째 줄 🥹 그리고 아주 긴 " + String(repeating: "가", count: 400)
        let detail = present(log(diary: body))
        XCTAssertEqual(detail.note.body, body, "일기가 잘리거나 다시 쓰였다")
        XCTAssertFalse(detail.note.isEmpty)
    }

    func testEmptyNoteIsHonestRatherThanGenerated() {
        let detail = present(log(diary: "   \n  "))
        XCTAssertNil(detail.note.body)
        XCTAssertTrue(detail.note.isEmpty)
        XCTAssertNil(detail.note.signature, "본문이 없는데 서명이 붙었다")
        XCTAssertFalse(detail.note.emptyMessage.isEmpty)
    }

    /// 서명은 구장과 사용자 이름이 모두 있을 때만 만든다. 이름을 지어내지 않는다.
    func testSignatureNeedsBothStadiumAndDisplayName() {
        XCTAssertEqual(present(log()).note.signature, "— 잠실야구장에서, 민지")
        XCTAssertNil(present(log(), displayName: nil).note.signature)
        XCTAssertNil(present(log(), displayName: "   ").note.signature)
        XCTAssertNil(present(log(stadium: "")).note.signature)
    }

    // MARK: - 7. 저장소가 채운 표시 문구

    /// 매퍼가 값이 없을 때 넣는 "좌석 미정"·"미입력"·"직관 기록"은 사용자가 쓴 값이 아니다.
    func testRepositoryPlaceholdersAreTreatedAsMissing() {
        let detail = present(log(seat: "좌석 미정", companion: "미입력", memo: "직관 기록"))
        XCTAssertNil(detail.title, "표시용 문구가 제목으로 올라왔다")
        XCTAssertEqual(detail.placeMeta, "잠실야구장", "표시용 좌석 문구가 그대로 나왔다")
        XCTAssertTrue(detail.details.isEmpty, "표시용 문구로 셀을 만들었다")
    }

    func testDetailsOnlyContainFieldsTheDomainActuallyStores() {
        let detail = present(log())
        XCTAssertEqual(detail.details.map(\.kind), [.companion, .seat])
        XCTAssertEqual(Set(RecordDetailFact.Kind.allCases), Set(detail.details.map(\.kind)))
        for fact in detail.details {
            XCTAssertTrue(fact.accessibilityIdentifier.hasPrefix("recordDetail.fact."))
            XCTAssertFalse(fact.value.isEmpty)
        }
    }

    // MARK: - 8. 시간대

    /// 날짜 판단은 언제나 한국 시간 기준이다.
    func testDateTitleUsesTheExplicitSeoulTimeZone() {
        XCTAssertEqual(calendar.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(DateFormatter.vfRecordDetailTitle.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(DateFormatter.vfRecordDetailVoiceOver.timeZone.identifier, "Asia/Seoul")

        // 한국 시간 4월 1일 00:30 = UTC 3월 31일 15:30.
        let midnight = date(2026, 4, 1, hour: 0)
        let detail = present(log(when: midnight))
        XCTAssertEqual(detail.navigationTitle, "2026년 4월 1일")
        XCTAssertEqual(detail.season, 2026)
    }

    func testSpokenDateReadsTheWeekdayToo() {
        let spoken = service.spokenDate(for: VFRecordDetailFixtures.referenceLog)
        XCTAssertTrue(spoken.contains("2026년 4월 12일"))
        XCTAssertTrue(spoken.contains("요일"), "요일을 읽지 않는다: \(spoken)")
    }

    // MARK: - 9. 접근성 요약

    func testAccessibilitySummaryNeverLeaksInternalIdentifiers() {
        let detail = present(VFRecordDetailFixtures.referenceLog, media: .available(refs: ["x"]))
        let summary = detail.accessibilitySummary
        XCTAssertFalse(summary.contains("recordDetail."), "읽어 주는 문장에 식별자가 섞였다")
        XCTAssertFalse(summary.contains(detail.recordID.uuidString), "읽어 주는 문장에 내부 ID가 섞였다")
        XCTAssertFalse(summary.contains("vf-uitest"), "읽어 주는 문장에 픽스처 이름이 섞였다")
        XCTAssertTrue(summary.contains("삼성 라이온즈"))
        XCTAssertTrue(summary.contains("잠실야구장"))
    }

    // MARK: - 10. 서비스 순수성

    func testPresentationIsCallableWithoutAnyView() {
        let detail = RecordDetailService().presentation(
            log: AttendanceLogSample.logs[0],
            favoriteTeam: nil,
            displayName: nil,
            media: .none
        )
        XCTAssertEqual(detail.recordID, AttendanceLogSample.logs[0].id)
        XCTAssertFalse(detail.navigationTitle.isEmpty)
    }
}
