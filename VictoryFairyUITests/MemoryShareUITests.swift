import XCTest

/// Record Detail과 Feed가 소유한 실제 기록 한 건으로만 jYs0S Memory Card를 연다.
final class MemoryShareUITests: XCTestCase {
    private enum Origin {
        case recordDetail
        case feed
    }

    private let fixtureSeeds: [String: Int] = [
        "withPhoto": 1,
        "noPhoto": 2,
        "unreadablePhoto": 3,
        "scored": 4,
        "canceled": 5,
        "missingScore": 6,
        "longContent": 7
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func fixtureID(_ fixture: String) -> String {
        guard let seed = fixtureSeeds[fixture] else {
            XCTFail("알 수 없는 Memory Card 픽스처: \(fixture)")
            return ""
        }
        return String(format: "09F10000-0000-4000-8000-%012d", seed)
    }

    @discardableResult
    private func scrollTo(
        _ app: XCUIApplication,
        _ element: XCUIElement,
        limit: Int = 16,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        for _ in 0..<limit {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(240_000)
        }
        XCTAssertTrue(element.exists && element.isHittable,
                      "요소에 스크롤해도 닿을 수 없다: \(element)",
                      file: file, line: line)
        return element
    }

    private func launch(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestMemoryShareFixture", fixture
        ]
        if accessibilitySize {
            arguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(node(app, "screen.feed").waitForExistence(timeout: 15),
                      "Memory Card fixture의 피드가 열리지 않았다")
        return app
    }

    @discardableResult
    private func openPreview(
        _ fixture: String,
        origin: Origin,
        accessibilitySize: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = launch(fixture, accessibilitySize: accessibilitySize)
        let id = fixtureID(fixture)

        switch origin {
        case .feed:
            let share = scrollTo(app, node(app, "feed.share.\(id)"), file: file, line: line)
            XCTAssertTrue(share.isHittable, "Feed의 정확한 기록 공유 경로가 없다", file: file, line: line)
            share.tap()
        case .recordDetail:
            let record = scrollTo(app, node(app, "feed.record.\(id)"), file: file, line: line)
            XCTAssertTrue(record.isHittable, "정확한 fixture 기록 카드가 없다", file: file, line: line)
            record.tap()
            XCTAssertTrue(node(app, "recordDetail.root").waitForExistence(timeout: 12),
                          "기록 상세가 열리지 않았다", file: file, line: line)
            let share = scrollTo(app, node(app, "recordDetail.share"), file: file, line: line)
            share.tap()
        }

        XCTAssertTrue(node(app, "memoryShare.root").waitForExistence(timeout: 12),
                      "Memory Card 미리보기가 열리지 않았다", file: file, line: line)
        XCTAssertTrue(node(app, "memoryShare.scenario.\(fixture)").waitForExistence(timeout: 8),
                      "요청한 fixture가 카드까지 전달되지 않았다", file: file, line: line)
        return app
    }

    private func cardLabel(_ app: XCUIApplication) -> String {
        let card = node(app, "memoryShare.card")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Memory Card가 없다")
        return card.label
    }

    private func assertCoreControls(_ app: XCUIApplication) {
        XCTAssertTrue(node(app, "memoryShare.card").exists)
        for identifier in ["memoryShare.share", "memoryShare.save", "memoryShare.close"] {
            let control = scrollTo(app, node(app, identifier))
            XCTAssertTrue(control.isHittable, "\(identifier)를 누를 수 없다")
        }
    }

    func testMS01_recordDetailOpensTheExactFixtureRecordMemoryCard() {
        let app = openPreview("withPhoto", origin: .recordDetail)
        let label = cardLabel(app)
        XCTAssertTrue(label.contains("승리"))
        XCTAssertTrue(label.contains("삼성 대 LG"))
        XCTAssertTrue(label.contains("6 : 3"))
        XCTAssertTrue(label.contains("2026.04.12"))
        XCTAssertTrue(label.contains("잠실"))
    }

    func testMS02_feedDirectShareKeepsTheExactVisibleRecord() {
        let app = openPreview("scored", origin: .feed)
        XCTAssertTrue(node(app, "memoryShare.scenario.scored").exists)
        XCTAssertTrue(cardLabel(app).contains("삼성 대 LG"))
    }

    func testMS03_previewHasOneCardModeAndAllApprovedActions() {
        let app = openPreview("scored", origin: .feed)
        assertCoreControls(app)
        for forbidden in ["카드 스타일", "스코어 카드", "다이어리 카드", "승률 카드"] {
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", forbidden)).count, 0,
                           "폐기한 기록 카드 스타일이 노출됐다: \(forbidden)")
        }
    }

    func testMS04_normalRecordRendersCanonicalFieldsAndDecodedExportProof() {
        let app = openPreview("withPhoto", origin: .recordDetail)
        let label = cardLabel(app)
        for value in ["승리", "삼성 대 LG", "6 : 3", "2026.04.12", "잠실"] {
            XCTAssertTrue(label.contains(value), "카드 요약에 \(value)가 없다: \(label)")
        }
        let proof = scrollTo(app, node(app, "memoryShare.exportProof"))
        XCTAssertEqual(proof.label, "디코딩 확인 · 1200 × 1440")
        XCTAssertEqual(node(app, "memoryShare.geometry").label, "이미지 1200 × 1440 · 5:6")
        XCTAssertFalse(node(app, "memoryShare.placeholder").exists,
                       "읽을 수 있는 기록 사진 대신 placeholder를 그렸다")
    }

    func testMS05_noPhotoFixtureUsesTheHonestCardWithoutExternalContent() {
        let app = openPreview("noPhoto", origin: .recordDetail)
        XCTAssertTrue(node(app, "memoryShare.card").exists)
        XCTAssertTrue(node(app, "memoryShare.scenario.noPhoto").exists)
        XCTAssertTrue(node(app, "memoryShare.placeholder").exists,
                      "사진 없는 기록의 결정적 placeholder가 없다")
        XCTAssertEqual(app.webViews.count, 0, "사진 없음 상태가 외부 웹 콘텐츠를 열었다")
    }

    func testMS06_unreadablePhotoFallsBackWithoutCrashOrNetworkUI() {
        let app = openPreview("unreadablePhoto", origin: .recordDetail)
        XCTAssertTrue(node(app, "memoryShare.card").exists)
        XCTAssertTrue(node(app, "memoryShare.scenario.unreadablePhoto").exists)
        XCTAssertTrue(node(app, "memoryShare.placeholder").exists,
                      "읽지 못한 기록 사진이 placeholder로 대체되지 않았다")
        XCTAssertEqual(app.webViews.count, 0)
        XCTAssertFalse(app.alerts.firstMatch.exists, "읽지 못한 로컬 사진이 오류 팝업을 만들었다")
    }

    func testMS07_canceledRecordNeverFabricatesZeroScore() {
        let app = openPreview("canceled", origin: .recordDetail)
        let label = cardLabel(app)
        XCTAssertTrue(label.contains("취소"))
        XCTAssertTrue(label.contains("경기 취소"))
        XCTAssertFalse(label.contains("0 : 0"), "취소 경기에 가짜 0:0이 표시됐다")
    }

    func testMS08_missingScoreUsesTheHonestMissingState() {
        let app = openPreview("missingScore", origin: .recordDetail)
        let label = cardLabel(app)
        XCTAssertTrue(label.contains("점수 미기록"))
        XCTAssertFalse(label.contains("0 : 0"))
    }

    func testMS09_cardNeverLeaksFixtureDiarySeatCompanionOrLegacySampleMatchup() {
        let app = openPreview("scored", origin: .feed)
        let label = cardLabel(app)
        for forbidden in ["3루 원정석", "친구", "카드에 들어가면 안 되는", "한화 대 KIA", "3 : 9"] {
            XCTAssertFalse(label.contains(forbidden), "승인되지 않은 값이 카드에 들어갔다: \(forbidden)")
        }
    }

    func testMS10_closeReturnsToTheOwningFeedAndWritesNoVisibleState() {
        let app = openPreview("scored", origin: .feed)
        scrollTo(app, node(app, "memoryShare.close")).tap()
        XCTAssertTrue(node(app, "screen.feed").waitForExistence(timeout: 10),
                      "닫기가 Feed 소유 경로로 돌아가지 않았다")
        XCTAssertFalse(app.alerts.firstMatch.exists, "미리보기 닫기가 저장/권한 UI를 띄웠다")
    }

    func testMS11_shareActionPresentsTheNativeActivitySheet() {
        let app = openPreview("scored", origin: .feed)
        let share = scrollTo(app, node(app, "memoryShare.share"))
        share.tap()
        // iOS 26의 UIActivityViewController는 XCUI `Sheet`가 아니라 이 원격
        // 컨테이너 식별자로 노출된다(실제 실패 결과 번들의 계층으로 확인).
        XCTAssertTrue(node(app, "ActivityListView").waitForExistence(timeout: 12),
                      "공유 버튼이 네이티브 ActivityView를 열지 않았다")
    }

    func testMS12_photosPermissionIsNotRequestedBeforeExplicitSave() {
        let app = openPreview("withPhoto", origin: .recordDetail)
        XCTAssertTrue(scrollTo(app, node(app, "memoryShare.save")).isHittable)
        XCTAssertFalse(app.alerts.firstMatch.exists,
                       "사진에 저장을 누르기 전에 Photos 권한 또는 저장 UI가 나타났다")
    }
}
