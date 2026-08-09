import XCTest

/// Record Create 1단계의 실제 구장 필드가 여는 09_States 시트 계약.
final class StadiumSelectionUITests: XCTestCase {
    private let stadiumIDs = [
        "jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
        "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func launch(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestRecordCreateStaged", "fresh",
            "-VFUITestStadiumSheetFixture", fixture
        ]
        app.launch()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForExistence(timeout: 15))
        XCTAssertTrue(node(app, "stadiumSheet.scenario.\(fixture)").waitForExistence(timeout: 8))
        return app
    }

    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        for _ in 0..<12 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
        }
        return element
    }

    @discardableResult
    private func openSheet(_ app: XCUIApplication) -> XCUIElement {
        let field = scrollTo(app, node(app, "recordCreate.field.stadium"))
        XCTAssertTrue(field.isHittable)
        field.tap()
        let root = node(app, "stadiumSheet.root")
        XCTAssertTrue(root.waitForExistence(timeout: 8), "구장 시트가 열리지 않았다")
        XCTAssertTrue(node(app, "stadiumSheet.title").exists)
        return root
    }

    private func dismissInteractively(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(node(app, "stadiumSheet.root").waitForNonExistence(timeout: 8),
                      "시트를 드래그로 닫지 못했다")
    }

    func testSS01_realStep1StadiumFieldOpensThePencilTitledSheet() {
        let app = launch("canonicalSelected")
        _ = openSheet(app)
        XCTAssertEqual(node(app, "stadiumSheet.title").label, "구장을 선택해 주세요")
        XCTAssertTrue(node(app, "recordCreate.origin.home").exists)
    }

    func testSS02_allNineCanonicalStableRowsAreReachableInOrder() {
        let app = launch("allNine")
        let root = openSheet(app)
        for id in stadiumIDs {
            let row = node(app, "stadiumSheet.stadium.\(id)")
            for _ in 0..<10 where !row.exists || !row.isHittable { root.swipeUp() }
            XCTAssertTrue(row.exists, "canonical 행이 없다: \(id)")
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        }
    }

    func testSS03_currentDraftSelectionUsesSelectedTraitAndReadableCanonicalLabel() {
        let app = launch("canonicalSelected")
        _ = openSheet(app)
        let row = node(app, "stadiumSheet.stadium.jamsil")
        XCTAssertTrue(row.exists && row.isSelected, "현재 초안 구장이 선택 상태가 아니다")
        XCTAssertEqual(row.label, "잠실야구장")
        XCTAssertTrue((row.value as? String ?? "").contains("선택됨"))
    }

    func testSS04_rowTapImmediatelyWritesCanonicalNameAndDismisses() {
        let app = launch("canonicalSelected")
        let root = openSheet(app)
        let target = node(app, "stadiumSheet.stadium.suwon-kt")
        for _ in 0..<8 where !target.exists || !target.isHittable { root.swipeUp() }
        target.tap()
        XCTAssertTrue(root.waitForNonExistence(timeout: 8))
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String,
                       "수원 kt wiz 파크")
    }

    func testSS05_interactiveDismissalPreservesThePreviousDraftValue() {
        let app = launch("canonicalSelected")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "잠실야구장")
        _ = openSheet(app)
        dismissInteractively(app)
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "잠실야구장")
    }

    func testSS06_invalidInitialValueHasNoSelectionAndStaysUnchangedOnOpen() {
        let app = launch("invalidCurrent")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "과거의 미등록 구장")
        _ = openSheet(app)
        for id in stadiumIDs.prefix(4) {
            let row = node(app, "stadiumSheet.stadium.\(id)")
            XCTAssertTrue(row.exists)
            XCTAssertFalse(row.isSelected, "미등록 값인데 \(id)가 선택됐다")
        }
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "과거의 미등록 구장")
    }

    func testSS07_explicitSelectionRepairsOnlyTheInvalidDraftField() {
        let app = launch("invalidCurrent")
        _ = openSheet(app)
        node(app, "stadiumSheet.stadium.gocheok").tap()
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "고척스카이돔")
        XCTAssertEqual(node(app, "recordCreate.field.favoriteTeam").value as? String, "삼성 라이온즈")
        XCTAssertFalse(node(app, "onboarding.root").exists)
        XCTAssertFalse(node(app, "profile.root").exists)
    }

    func testSS08_emptyCatalogIsHonestPresentedAndDismissible() {
        let app = launch("empty")
        _ = openSheet(app)
        XCTAssertTrue(node(app, "stadiumSheet.empty").exists)
        XCTAssertEqual(node(app, "stadiumSheet.empty").label,
                       "선택할 수 있는 구장이 없어요, 시트를 내려 기록 작성으로 돌아갈 수 있어요.")
        XCTAssertEqual(app.descendants(matching: .button)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "stadiumSheet.stadium.")).count, 0)
        dismissInteractively(app)
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "선택하지 않음")
    }

    func testSS09_longRowKeepsCanonicalSpokenNameAndSecondaryContext() {
        let app = launch("longContent")
        _ = openSheet(app)
        let row = node(app, "stadiumSheet.stadium.jamsil")
        XCTAssertEqual(row.label, "잠실야구장")
        let value = row.value as? String ?? ""
        XCTAssertTrue(value.contains("서울"))
        XCTAssertTrue(value.contains("LG"))
        XCTAssertTrue(value.contains("삼성"))
        // XCUI의 버튼 접근성 프레임은 SwiftUI의 56pt 시각 프레임보다 조금 작게
        // 보고될 수 있다. 제품 계약인 최소 44pt 터치 영역을 실측한다.
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
    }

    func testSS10_sheetHasNoDoneOrCancelControl() {
        let app = launch("canonicalSelected")
        let root = openSheet(app)
        XCTAssertEqual(root.descendants(matching: .button)
            .matching(NSPredicate(format: "label == %@", "완료")).count, 0)
        XCTAssertEqual(root.descendants(matching: .button)
            .matching(NSPredicate(format: "label == %@", "취소")).count, 0)
    }

    func testSS11_selectionNeverRoutesThroughProfileOrOnboarding() {
        let app = launch("canonicalSelected")
        _ = openSheet(app)
        XCTAssertFalse(node(app, "profile.root").exists)
        XCTAssertFalse(node(app, "onboarding.root").exists)
        XCTAssertTrue(node(app, "recordCreate.step1.root").exists)
    }
}
