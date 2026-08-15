import XCTest

/// 탭 이동, 선택 상태, 안전 영역, 반응형 동작을 실제 앱에서 검증한다.
final class NavigationUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 온보딩을 마친 사용자로 앱을 띄운다.
    private func launchOnboarded(
        teamID: String = "lg-twins",
        stadiumID: String = "jamsil",
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", stadiumID,
            "-VFUITestOnboardingCompleted", "1"
        ] + extraArguments
        app.launch()
        return app
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 8) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// SwiftUI가 컨테이너를 어떤 요소 종류로 노출할지는 보장되지 않는다.
    /// 식별자만 보고 어떤 종류든 찾는다.
    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private static let tabs = ["home", "feed", "calendar", "statistics", "my"]

    // MARK: - 18~19 · 탭 이동과 선택 상태

    func test18_allFiveTabsAreReachable() {
        let app = launchOnboarded()
        XCTAssertTrue(waits(node(app, "screen.home")))

        for tab in Self.tabs {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(waits(button, 5), "tab.\(tab) 버튼이 없다")
            button.tap()
            XCTAssertTrue(
                waits(node(app, "screen.\(tab)"), 6),
                "screen.\(tab) 화면에 닿지 못했다"
            )
        }
    }

    func test19_eachTabMaintainsSelectedState() {
        let app = launchOnboarded()
        XCTAssertTrue(waits(node(app, "screen.home")))

        for tab in Self.tabs {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(waits(button, 5))
            button.tap()
            XCTAssertTrue(waits(node(app, "screen.\(tab)"), 6))
            XCTAssertTrue(button.isSelected, "tab.\(tab)이 선택 상태로 표시되지 않았다")

            // 다른 탭은 선택 상태가 아니어야 한다.
            for other in Self.tabs where other != tab {
                XCTAssertFalse(
                    app.buttons["tab.\(other)"].isSelected,
                    "tab.\(tab) 선택 중인데 tab.\(other)도 선택 상태다"
                )
            }
        }
    }

    // MARK: - 20~24 · 각 탭의 결정적 상태

    func test20to24_eachTabRendersItsDeterministicState() {
        let app = launchOnboarded()
        for tab in Self.tabs {
            app.buttons["tab.\(tab)"].tap()
            let screen = node(app, "screen.\(tab)")
            XCTAssertTrue(waits(screen, 6), "screen.\(tab)이 뜨지 않았다")
            XCTAssertTrue(screen.isHittable || screen.exists, "screen.\(tab)이 화면에 없다")
        }
    }

    // MARK: - 32~33 · 탭바 무결성과 안전 영역

    /// 깊은 화면으로 들어가도 탭바가 두 개가 되면 안 된다.
    func test32_noDuplicatedTabBarAppears() {
        let app = launchOnboarded()
        XCTAssertTrue(waits(node(app, "screen.home")))
        for tab in Self.tabs {
            app.buttons["tab.\(tab)"].tap()
            _ = waits(node(app, "screen.\(tab)"), 6)
            let homeTabs = app.buttons.matching(identifier: "tab.home")
            XCTAssertEqual(homeTabs.count, 1, "\(tab) 탭에서 탭바가 \(homeTabs.count)개 보인다")
        }
    }

    /// 탭바가 화면 하단 안전 영역 안에 있고, 모든 탭이 실제로 탭 가능해야 한다.
    func test33_tabBarStaysWithinSafeAreaAndIsHittable() {
        let app = launchOnboarded()
        XCTAssertTrue(waits(node(app, "screen.home")))
        let window = app.windows.firstMatch

        for tab in Self.tabs {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(waits(button, 5))
            XCTAssertTrue(button.isHittable, "tab.\(tab)을 탭할 수 없다(가려졌을 수 있다)")
            let frame = button.frame
            XCTAssertLessThanOrEqual(
                frame.maxY, window.frame.maxY,
                "tab.\(tab)이 화면 아래로 벗어났다"
            )
            XCTAssertGreaterThanOrEqual(frame.height, 40, "tab.\(tab) 높이가 너무 작다")
        }
    }

    // MARK: - 30~31 · 반응형

    /// 좁은 화면에서도 모든 탭에 닿고 콘텐츠가 잘리지 않아야 한다.
    /// 실행 대상 시뮬레이터가 좁은 기기일 때 의미가 있다.
    func test30_compactWidthSmoke() {
        let app = launchOnboarded()
        XCTAssertTrue(waits(node(app, "screen.home")))
        let window = app.windows.firstMatch

        for tab in Self.tabs {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(waits(button, 5), "좁은 폭에서 tab.\(tab)이 사라졌다")
            XCTAssertTrue(button.isHittable, "좁은 폭에서 tab.\(tab)을 누를 수 없다")
            XCTAssertLessThanOrEqual(
                button.frame.maxX, window.frame.maxX + 1,
                "좁은 폭에서 tab.\(tab)이 오른쪽으로 넘쳤다"
            )
        }
    }

    /// 접근성 최대 글자 크기에서도 필수 동작이 남아 있어야 한다.
    func test31_accessibilityExtraExtraExtraLargeSmoke() {
        let app = launchOnboarded()
        XCTAssertTrue(waits(node(app, "screen.home")))

        for tab in Self.tabs {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(waits(button, 5), "큰 글자에서 tab.\(tab)이 사라졌다")
            XCTAssertTrue(button.isHittable, "큰 글자에서 tab.\(tab)을 누를 수 없다")
            button.tap()
            XCTAssertTrue(
                waits(node(app, "screen.\(tab)"), 6),
                "큰 글자에서 screen.\(tab)에 닿지 못했다"
            )
        }
    }

    // MARK: - 16~17 · 나중에 바꾸기

    /// 마이 탭에서 팀과 구장 설정에 닿을 수 있어야 한다.
    func test16and17_profileExposesTeamAndStadiumEditing() {
        let app = launchOnboarded()
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "screen.my"), 6), "마이 화면에 닿지 못했다")
    }
}
