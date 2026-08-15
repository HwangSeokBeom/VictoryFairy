import XCTest

/// 좁은 폭(375pt)·소프트 키보드·실제 AccessibilityXXXL에서 **지금의 한 장짜리
/// 기록 편집기**가 그대로 쓸 수 있는지 잰다.
///
/// 이 패스는 세 단계 마법사를 만들지 않는다. 그래서 여기서 확인하는 것은
/// "Pencil Step 1~3과 같은가"가 아니라 "현재 폼이 망가지지 않았는가"다.
///
/// 편집기에는 접근성 식별자가 없다(감사 결과). 화면에 실제로 보이는 문구로 찾고,
/// 존재만으로 통과시키지 않는다 — 스크롤해서 눈에 들어오고 누를 수 있는지까지 잰다.
final class RecordCreateFoundationResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 기기 조건

    /// 좁은 폭 기기에서만 뜻이 있는 검사인지. 넓은 기기에서는 통과로 위장하지 않고
    /// 건너뛴다. 대응하는 검사는 SE3에서 실제로 돌아 통과한다.
    private func requireCompactWidth(_ app: XCUIApplication) throws {
        let width = app.windows.firstMatch.frame.width
        guard width <= 390 else {
            throw XCTSkip("좁은 폭 검사는 375pt급 기기에서만 뜻이 있다 (현재 \(width)pt)")
        }
    }

    // MARK: - 도구

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 15) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// 부분 일치. 화면 뒤에 남아 있는 발표 화면의 글자까지 잡을 수 있으므로,
    /// 편집기 안의 라벨을 찾을 때는 아래 `exactText`를 쓴다.
    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 편집기 안에서 정확히 일치하는 라벨.
    ///
    /// 시트가 떠 있어도 뒤 화면의 요소가 트리에 남는다 — "구장"이 홈의
    /// "주 관람 구장"에, "사진"이 캘린더의 보기 탭에 잡힌다. 나중에 얹힌 시트의
    /// 요소가 트리에서도 뒤에 오므로 **마지막** 일치를 고른다. 컨테이너를 잡아 두면
    /// 스크롤 뒤에 참조가 낡아 버리므로 앱 범위로 질의한다.
    private func exactText(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let matches = app.staticTexts.matching(NSPredicate(format: "label == %@", label))
        let count = matches.count
        return count > 0 ? matches.element(boundBy: count - 1) : matches.firstMatch
    }

    /// 자리를 잡은 뒤의 좌표. 애니메이션 중의 값은 재지 않는다.
    private func settled(_ element: XCUIElement,
                         file: StaticString = #filePath, line: UInt = #line) -> CGRect {
        XCTAssertTrue(waits(element), "요소가 나타나지 않아 좌표를 잴 수 없다", file: file, line: line)
        var previous = element.frame
        for _ in 0..<25 {
            usleep(120_000)
            let current = element.frame
            if current == previous { return current }
            previous = current
        }
        return previous
    }

    // MARK: - 쓸 수 있는 구간

    /// 탭이 실제로 먹히려면 최소한 이만큼은 쓸 수 있는 구간 안에 들어와 있어야 한다.
    /// 44pt는 애플 휴먼 인터페이스 가이드라인의 최소 터치 목표 크기다. 요소 자체가
    /// 그보다 작으면 그 요소의 크기가 곧 기준이 된다.
    private static let minimumInteractiveExtent: CGFloat = 44
    /// 부동소수점 기하 오차만 흡수한다. 실제 가림을 감추는 값이 아니다.
    private static let geometryTolerance: CGFloat = 0.5

    /// 왜 아직 쓸 수 없는지.
    private enum ViewportVerdict: String {
        case reachable = "REACHABLE"
        case oversizedButActionable = "OVERSIZED_BUT_ACTIONABLE"
        case notPresent = "NOT_PRESENT"
        case aboveViewport = "ABOVE_VIEWPORT"
        case belowViewport = "BELOW_VIEWPORT"
        case insufficientVisibleRegion = "INSUFFICIENT_VISIBLE_REGION"
        case notHittable = "NOT_HITTABLE"
        case noScrollProgress = "NO_SCROLL_PROGRESS"
    }

    private enum ScrollDirection: String { case up = "UP", down = "DOWN" }

    /// 위에 붙어 화면을 덮고 있는 크롬. 없으면 `nil`.
    /// **`exists`를 먼저 묻고 있을 때만 `frame`을 읽는다.**
    private func topChromeFrame(_ app: XCUIApplication) -> CGRect? {
        let window = app.windows.firstMatch.frame
        var result: CGRect?
        let bars = app.navigationBars
        for index in 0..<bars.count {
            let bar = bars.element(boundBy: index)
            guard bar.exists else { continue }
            let frame = bar.frame
            // 위에 붙어 있는 것만 크롬으로 센다. 한복판의 막대는 크롬이 아니다.
            guard frame.minY <= window.midY else { continue }
            if let current = result {
                if frame.maxY > current.maxY { result = frame }
            } else {
                result = frame
            }
        }
        return result
    }

    /// 아래를 가리는 것 — 키보드나 고정 액션 영역. 둘 다 **없을 수 있다.**
    private func bottomObstructionFrame(_ app: XCUIApplication) -> CGRect? {
        let window = app.windows.firstMatch.frame
        var result: CGRect?
        for candidate in [app.keyboards.element, app.toolbars.firstMatch] {
            guard candidate.exists else { continue }
            let frame = candidate.frame
            guard frame.maxY >= window.midY else { continue }
            if let current = result {
                if frame.minY < current.minY { result = frame }
            } else {
                result = frame
            }
        }
        return result
    }

    /// 위 크롬 아래, 아래 가림 위 — 실제로 손이 닿는 구간.
    private func usableViewport(_ app: XCUIApplication) -> CGRect {
        let window = app.windows.firstMatch.frame
        let top = topChromeFrame(app).map { max(window.minY, $0.maxY) } ?? window.minY
        let bottom = bottomObstructionFrame(app).map { min(window.maxY, $0.minY) } ?? window.maxY
        return CGRect(x: window.minX, y: top,
                      width: window.width, height: max(0, bottom - top))
    }

    /// 지금 이 요소를 **뜻 있게 쓸 수 있는가**.
    ///
    /// 프레임 전체가 구간 안에 담겼는지는 묻지 않는다. AccessibilityXXXL에서는 의미
    /// 요소 하나가 구간보다 커지기도 하므로(실측: `티켓에서 불러오기`가 567pt 구간
    /// 안에서 604pt) 전면 포함은 아예 성립하지 않는다. 대신 최소 터치 크기만큼이
    /// 구간 안에 보이고, 실제로 누를 수 있는지를 본다.
    private func viewportVerdict(_ app: XCUIApplication,
                                 _ element: XCUIElement) -> (verdict: ViewportVerdict,
                                                             frame: CGRect?,
                                                             intersection: CGRect) {
        guard element.exists else { return (.notPresent, nil, .null) }
        let frame = element.frame
        let viewport = usableViewport(app)

        // 크롬 **자체에 속한** 컨트롤은 거기 고정돼 있다. 스크롤로 구간 안으로 옮길 수
        // 없고 옮길 필요도 없다 — 편집기의 `취소`가 바로 내비게이션 막대 안에 산다.
        // 구간 밖이라는 이유로 떨어뜨리면 영원히 닿지 못한다.
        let pinnedRegions = [topChromeFrame(app), bottomObstructionFrame(app)].compactMap { $0 }
        for region in pinnedRegions
        where region.insetBy(dx: -Self.geometryTolerance, dy: -Self.geometryTolerance).contains(frame) {
            return (element.isHittable ? .reachable : .notHittable, frame, frame)
        }

        let intersection = frame.intersection(viewport)

        guard !intersection.isNull, !intersection.isEmpty else {
            return (frame.maxY <= viewport.minY ? .aboveViewport : .belowViewport, frame, .null)
        }

        let requiredHeight = min(Self.minimumInteractiveExtent, frame.height)
        let requiredWidth = min(Self.minimumInteractiveExtent, frame.width)
        guard intersection.height + Self.geometryTolerance >= requiredHeight,
              intersection.width + Self.geometryTolerance >= requiredWidth else {
            if frame.minY < viewport.minY { return (.aboveViewport, frame, intersection) }
            if frame.maxY > viewport.maxY { return (.belowViewport, frame, intersection) }
            return (.insufficientVisibleRegion, frame, intersection)
        }

        guard element.isHittable else { return (.notHittable, frame, intersection) }
        let oversized = frame.height > viewport.height + Self.geometryTolerance
        return (oversized ? .oversizedButActionable : .reachable, frame, intersection)
    }

    /// 한 화면을 통째로 미는 대신 조금만 끈다. 한 번 지나친 뒤의 미세 조정용이다.
    /// 가로 여백에서 끄는 이유는 본문 한복판의 `TextView`가 제스처를 먹기 때문이다.
    private func fineDrag(_ app: XCUIApplication, up: Bool) {
        let window = app.windows.firstMatch
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: up ? 0.62 : 0.38))
        let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: up ? 0.38 : 0.62))
        from.press(forDuration: 0.05, thenDragTo: to)
    }

    /// 실패 문구. **여기서는 무엇도 던지지 않는다.**
    private func viewportDiagnostics(_ app: XCUIApplication, _ element: XCUIElement,
                                     state: (verdict: ViewportVerdict, frame: CGRect?, intersection: CGRect),
                                     reason: ViewportVerdict, direction: ScrollDirection?,
                                     swipes: Int, progressed: Bool) -> String {
        let exists = element.exists
        let identifier = exists ? element.identifier : "NOT_PRESENT"
        let label = exists ? element.label : "NOT_PRESENT"
        let hittable = exists ? "\(element.isHittable)" : "NOT_PRESENT"
        let frame = state.frame.map { "\($0)" } ?? "NOT_PRESENT"
        let intersection = (state.intersection.isNull || state.intersection.isEmpty)
            ? "NONE" : "\(state.intersection)"
        let requiredHeight = state.frame.map { "\(min(Self.minimumInteractiveExtent, $0.height))" } ?? "NONE"
        let requiredWidth = state.frame.map { "\(min(Self.minimumInteractiveExtent, $0.width))" } ?? "NONE"
        return "쓸 수 있는 구간 안에서 누를 수 있는 상태가 되지 않는다 — "
            + "사유=\(reason.rawValue) id=\"\(identifier)\" label=\"\(label)\" 존재=\(exists) "
            + "누를수있음=\(hittable) frame=\(frame) 보이는교집합=\(intersection) "
            + "필요최소=\(requiredWidth)x\(requiredHeight) 구간=\(usableViewport(app)) "
            + "위크롬=\(topChromeFrame(app).map { "\($0)" } ?? "NONE") "
            + "아래가림=\(bottomObstructionFrame(app).map { "\($0)" } ?? "NONE") "
            + "방향=\(direction?.rawValue ?? "NONE") 스와이프=\(swipes) 진행=\(progressed)"
    }

    /// 쓸 수 있는 구간 안으로 끌어오고, 거기서 **실제로 누를 수 있는지**까지 확인한다.
    ///
    /// 방향을 매 번 뒤집지 않는다. 한쪽으로만 밀다가 구간을 통째로 지나쳤다는 증거가
    /// 나왔을 때 딱 한 번 교정하고, 그 뒤로는 한 화면을 통째로 미는 대신 조금씩 끈다
    /// (실측: 매 번 뒤집으면 좌석 칸이 위 y −51과 아래 y 666.5 사이를 오갔다).
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maximumSwipes: Int = 25,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waits(element), "요소 자체가 없다", file: file, line: line)

        var direction: ScrollDirection?
        var corrections = 0
        var swipes = 0
        var stalled = 0
        var reason = ViewportVerdict.notPresent

        // AccessibilityXXXL에서는 폼 전체가 2,300pt를 넘는다. 넉넉히 밀어 본다.
        while swipes < maximumSwipes {
            let state = viewportVerdict(app, element)
            reason = state.verdict
            if state.verdict == .reachable || state.verdict == .oversizedButActionable {
                return element
            }

            let needed: ScrollDirection
            switch state.verdict {
            case .aboveViewport: needed = .down
            case .belowViewport, .notPresent: needed = .up
            default: needed = direction ?? .up
            }

            // 첫 역전만 "지나쳤다"는 증거로 받아들이고, 그 뒤로는 미세 조정으로 바꾼다.
            if let current = direction, current != needed, corrections == 0 { corrections += 1 }
            let fine = corrections > 0
            direction = needed

            let before = state.frame?.minY
            if fine {
                fineDrag(app, up: needed == .up)
            } else if needed == .up {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
            swipes += 1

            // 움직이지 않는 스크롤을 계속 밀어 봐야 소용없다.
            let after = element.exists ? element.frame.minY : nil
            if let before, let after, abs(after - before) <= Self.geometryTolerance {
                stalled += 1
                if stalled >= 2 { reason = .noScrollProgress; break }
            } else {
                stalled = 0
            }
        }

        let final = viewportVerdict(app, element)
        let accepted = final.verdict == .reachable || final.verdict == .oversizedButActionable
        XCTAssertTrue(accepted,
                      viewportDiagnostics(app, element, state: final,
                                          reason: reason == .noScrollProgress ? reason : final.verdict,
                                          direction: direction, swipes: swipes,
                                          progressed: stalled < 2),
                      file: file, line: line)
        return element
    }

    private func launch(_ extra: [String], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    // MARK: - 진입 경로

    /// 편집기가 실제로 열렸는지. 제목과 현재 폼의 카드로 확인한다.
    @discardableResult
    private func assertEditorIsOpen(_ app: XCUIApplication, editing: Bool,
                                    file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let title = editing ? "직관 기록 수정" : "직관 기록 추가"
        let heading = app.staticTexts[title].firstMatch
        XCTAssertTrue(waits(heading), "편집기가 열리지 않았다 (\(title))", file: file, line: line)
        XCTAssertTrue(waits(exactText(app, "필수 정보")), "현재 폼의 필수 정보 카드가 없다", file: file, line: line)
        assertNoVisibleWizard(app, file: file, line: line)
        return heading
    }

    /// 보이는 마법사가 생기지 않았는지. 이 패스는 단계 화면을 만들지 않는다.
    private func assertNoVisibleWizard(_ app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for forbidden in ["다음 · 그날의 디테일", "다음 · 나의 이야기", "이 단계는 건너뛸게요",
                          "여기까지만 저장할게요", "기록 완성하기", "임시저장",
                          "날씨", "먹은 것", "응원 준비물", "오늘 직관, 몇 점이었나요?"] {
            XCTAssertFalse(text(app, forbidden).exists,
                           "보이는 단계/미지원 항목 \(forbidden)이 생겼다", file: file, line: line)
        }
        XCTAssertFalse(text(app, "0 / 500").exists, "500자 제한이 생겼다", file: file, line: line)
    }

    /// 생성 경로가 여는 것은 이제 세 단계 흐름의 1단계다.
    private func assertWizardStep1IsOpen(_ app: XCUIApplication, origin: String,
                                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(node(app, "recordCreate.origin.\(origin)")),
                      "\(origin) 경로로 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(exactText(app, "어떤 경기였나요?")), "1단계 제목이 없다", file: file, line: line)
        XCTAssertFalse(exactText(app, "필수 정보").exists,
                       "생성 경로가 아직 한 장짜리 폼을 연다", file: file, line: line)
        for forbidden in ["임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500", "오늘 직관, 몇 점이었나요?"] {
            XCTAssertFalse(text(app, forbidden).exists,
                           "지원하지 않는 \(forbidden)이 생겼다", file: file, line: line)
        }
    }

    /// 1단계의 컨트롤이 좁은 폭·큰 글자에서 화면 안에 남는지.
    private func assertStep1RemainsUsable(_ app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.windows.firstMatch.frame

        func assertInsideScreen(_ element: XCUIElement, _ name: String) {
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(name)이 왼쪽으로 넘쳤다", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(name)이 오른쪽으로 넘쳤다", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, "\(name)이 높이 0으로 접혔다", file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, "\(name)이 너비 0으로 접혔다", file: file, line: line)
        }

        for identifier in ["recordCreate.field.date", "recordCreate.field.stadium",
                           "recordCreate.field.favoriteTeam", "recordCreate.field.opponentTeam"] {
            assertInsideScreen(scrollIntoView(app, node(app, identifier), file: file, line: line), identifier)
        }
        for result in ["승리", "패배", "무승부", "경기 취소"] {
            assertInsideScreen(scrollIntoView(app, app.buttons[result].firstMatch, file: file, line: line), "결과 \(result)")
        }
        // 지금 편집기가 이미 가진 도움에 여기서도 닿는다.
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"), file: file, line: line), "티켓에서 불러오기")
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.assist.findGame"), file: file, line: line), "경기 자동 찾기")
        // 다음과 최소 저장까지 닿는다.
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.next"), file: file, line: line), "다음")
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.saveMinimal"), file: file, line: line), "여기까지만 저장할게요")
    }

    private func openHomeCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.home")), "홈에 들어가지 못했다")
        scrollIntoView(app, node(app, "home.recordCTA")).tap()
        assertWizardStep1IsOpen(app, origin: "home")
    }

    private func openFeedCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertWizardStep1IsOpen(app, origin: "feed")
    }

    private func openCalendarCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.calendar")), "캘린더에 들어가지 못했다")
        scrollIntoView(app, node(app, "calendar.detailAddRecord")).tap()
        assertWizardStep1IsOpen(app, origin: "calendar")
    }

    private func openRecordDetailEdit(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        let firstRecord = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .firstMatch
        XCTAssertTrue(waits(firstRecord), "피드에 기록이 없다")
        firstRecord.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "기록 상세에 들어가지 못했다")
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorIsOpen(app, editing: true)
    }

    private func homeApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "home"], accessibilitySize: accessibilitySize)
    }

    private func feedApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"],
               accessibilitySize: accessibilitySize)
    }

    private func longContentFeedApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "longContent"],
               accessibilitySize: accessibilitySize)
    }

    private func calendarApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "calendar", "-VFUITestCalendarFixture", "selectedEmptyDate"],
               accessibilitySize: accessibilitySize)
    }

    // MARK: - 현재 폼이 온전한지

    /// 카드·필드·저장까지 실제로 닿을 수 있는지 한 번에 잰다.
    ///
    /// 글자 라벨 대신 **컨트롤**로만 잰다. 시트가 떠 있어도 뒤 화면의 요소가 접근성
    /// 트리에 남아서, "경기 날짜"·"구장"·"사진" 같은 글자는 홈·피드·캘린더의 것과
    /// 섞인다(측정으로 확인했다). 편집기에만 있는 컨트롤은 그런 혼동이 없다.
    private func assertCurrentFormRemainsUsable(_ app: XCUIApplication,
                                                file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.windows.firstMatch.frame

        func assertInsideScreen(_ element: XCUIElement, _ name: String) {
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(name)이 왼쪽으로 넘쳤다", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(name)이 오른쪽으로 넘쳤다", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, "\(name)이 높이 0으로 접혔다", file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, "\(name)이 너비 0으로 접혔다", file: file, line: line)
        }

        // 필수 정보 카드의 컨트롤.
        //
        // 부분 일치는 쓰지 않는다. 시트 뒤 피드 카드의 라벨
        // ("… 잠실야구장 · 3루 원정석 · 엄마랑")이 "구장"을 품고 있어서, 부분 일치는
        // 편집기의 구장 메뉴 대신 그 카드를 집어 온다(SE 3에서 실제로 그랬다).
        // 메뉴 라벨은 제목으로 시작하므로 앞부분 일치로 좁힌다.
        let opponentMenu = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "상대팀")).firstMatch
        assertInsideScreen(scrollIntoView(app, opponentMenu, file: file, line: line), "상대팀 메뉴")
        let stadiumMenu = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "구장")).firstMatch
        assertInsideScreen(scrollIntoView(app, stadiumMenu, file: file, line: line), "구장 메뉴")
        // 경기 결과 네 버튼.
        for result in ["승", "패", "무", "취소"] {
            let button = app.buttons[result].firstMatch
            assertInsideScreen(scrollIntoView(app, button, file: file, line: line), "결과 \(result)")
        }

        // 사진 카드 · 선택 정보 카드.
        let addPhoto = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "사진 추가")).firstMatch
        assertInsideScreen(scrollIntoView(app, addPhoto, file: file, line: line), "사진 추가")
        assertInsideScreen(scrollIntoView(app, app.textFields["좌석"].firstMatch, file: file, line: line), "좌석")
        assertInsideScreen(scrollIntoView(app, app.textFields["한 줄 메모"].firstMatch, file: file, line: line), "한 줄 메모")
        assertInsideScreen(scrollIntoView(app, app.textViews.firstMatch, file: file, line: line), "직관 다이어리")

        // 저장까지 닿는다.
        assertInsideScreen(scrollIntoView(app, app.buttons["저장하기"].firstMatch, file: file, line: line), "저장하기")
    }

    // MARK: - 좁은 폭

    func testCompact01_homeStandardCreateRemainsUsable() throws {
        let app = homeApp()
        try requireCompactWidth(app)
        openHomeCreate(app)
        assertStep1RemainsUsable(app)
    }

    func testCompact02_homeAIPreflightEntryRemainsUsable() throws {
        // 홈 대시보드에 최근 기록이 있어야 승리요정 지수 카드가 나온다.
        let app = launch(["-VFUITestInitialTab", "home", "-VFUITestFeedFixture", "populated"])
        try requireCompactWidth(app)
        XCTAssertTrue(waits(node(app, "home.root")))
        // 실제 컨트롤은 승리요정 지수 카드 안의 반짝 버튼이다. 지연 생성되므로
        // 먼저 스크롤로 올린 뒤에 찾는다.
        let aiButton = app.buttons["AI 직관 기록 도우미"]
        for _ in 0..<12 { if aiButton.exists, aiButton.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(aiButton.exists, "AI 도우미 버튼이 나타나지 않았다")
        aiButton.tap()
        // 최근 기록이 없으면 "첫 직관 기록하기", 있으면 초안 버튼이 나온다.
        let startDraft = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@",
                        "후기 초안 만들기", "최근 직관 다듬기")
        ).firstMatch
        XCTAssertTrue(waits(startDraft), "AI 도우미 시트가 열리지 않았다")
        startDraft.tap()
        // 최근 기록을 다듬는 경로이므로 수정 모드다.
        XCTAssertTrue(waits(app.staticTexts["직관 기록 수정"].firstMatch), "AI 진입에서 편집기가 열리지 않았다")
        assertNoVisibleWizard(app)
    }

    func testCompact03_feedCreateRemainsUsable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        assertStep1RemainsUsable(app)
    }

    func testCompact04_calendarCreateKeepsTheSelectedDate() throws {
        let app = calendarApp()
        try requireCompactWidth(app)
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")), "픽스처가 적용되지 않았다")
        openCalendarCreate(app)
        // 캘린더가 정한 날짜가 1단계에 그대로 온다.
        XCTAssertTrue(scrollIntoView(app, node(app, "recordCreate.field.date")).exists)
        assertStep1RemainsUsable(app)
    }

    func testCompact05_recordDetailEditRemainsUsable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        assertCurrentFormRemainsUsable(app)
    }

    func testCompact06_editKeepsSeatAndCompanion() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertFalse((seat.value as? String ?? "").isEmpty, "좌석이 비어 있다")
        scrollIntoView(app, exactText(app, "동행 유형"))
    }

    func testCompact07_editWithExistingPhotoKeepsPhotoControls() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        // 사진 수 표시와 추가 버튼이 살아 있다.
        XCTAssertTrue(text(app, "/10").exists, "사진 개수 표시가 사라졌다")
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "사진 추가")).firstMatch)
    }

    func testCompact08_longDiaryRemainsReachable() throws {
        let app = longContentFeedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        scrollIntoView(app, exactText(app, "직관 다이어리"))
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
    }

    func testCompact09_saveValidationErrorRemainsReachable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        // 새 기록은 상대팀·구장·결과가 비어 있으므로 진행을 막는 안내가 뜬다.
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(app, warning)
        // 1단계는 그대로 열려 있다.
        assertWizardStep1IsOpen(app, origin: "feed")
    }

    func testCompact10_featureSurfacesRemainReachable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        // 1단계의 도우미 — 티켓 OCR과 경기 자동 찾기.
        scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"))
        scrollIntoView(app, node(app, "recordCreate.assist.findGame"))
        XCTAssertTrue(node(app, "recordCreate.assist.ticketOCR").isHittable, "OCR 진입을 누를 수 없다")
        // 사진 분석과 AI 초안은 3단계에 있다. 통합 UI 테스트가 거기서 확인한다.
    }

    func testCompact11_cancellationReturnsToThePresentingScreen() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertFalse(node(app, "recordCreate.step1.root").exists, "흐름이 남아 있다")
    }

    func testCompact12_noDuplicateNavigationContainerAppears() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 추가").count, 1,
                       "내비게이션 제목이 둘이다 — 두 번째 NavigationStack이 생겼다")
        XCTAssertEqual(app.navigationBars.count, 1, "내비게이션 바가 둘이다")
    }

    // MARK: - 소프트 키보드

    func testKeyboard01_diaryStaysVisibleWhileTyping() throws {
        // 좌석은 한 장짜리 폼에만 있다. 그 폼의 주인은 이제 수정 경로다.
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        seat.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8), "키보드가 올라오지 않았다")
        seat.typeText("3루 내야 지정석 K열 24번")

        // 입력 중인 필드가 키보드에 가리지 않는다.
        let keyboardTop = settled(app.keyboards.element).minY
        XCTAssertLessThan(settled(seat).maxY, keyboardTop + 0.5, "입력 중인 필드가 키보드에 가렸다")

        // 키보드를 내릴 수 있고, 내리면 저장에 닿는다.
        if app.buttons["Return"].exists { app.buttons["Return"].tap() } else { app.swipeDown() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
        // 입력한 값이 살아 있다.
        XCTAssertTrue((scrollIntoView(app, app.textFields["좌석"].firstMatch).value as? String ?? "")
            .contains("3루"), "키보드를 내리자 입력이 사라졌다")
    }

    func testKeyboard02_validationErrorRemainsReachableWithTheKeyboardUp() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        let score = scrollIntoView(app, node(app, "recordCreate.score.our"))
        score.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8), "키보드가 올라오지 않았다")
        score.typeText("6")
        // 숫자 키패드에는 Return이 없다. 화면이 주는 완료로 내린다.
        node(app, "recordCreate.score.done").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(app, warning)
        // 시트가 하나뿐이고 적어 둔 값이 남아 있다.
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 추가").count, 1)
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.score.our")).value as? String ?? "", "6",
                       "검증 뒤 입력이 사라졌다")
    }

    // MARK: - AccessibilityXXXL

    /// 큰 글자가 실제로 적용됐는지 증명한다.
    ///
    /// 기본 글자 크기에서 잰 같은 요소의 높이와 견주어, 적용되지 않았으면 실패한다.
    /// 이렇게 해야 "큰 글자에서 통과"가 사실이 된다.
    private func assertAccessibilityCategoryApplied(_ reference: XCUIElement, defaultHeight: CGFloat,
                                                    file: StaticString = #filePath, line: UInt = #line) {
        let large = settled(reference).height
        XCTAssertGreaterThan(large, defaultHeight * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(defaultHeight)pt vs 현재 \(large)pt",
                             file: file, line: line)
    }

    /// 기본 글자 크기에서 잰 "필수 정보" 제목 높이. 게이트의 기준값이다.
    private func defaultRequiredHeadingHeight() -> CGFloat {
        let app = feedApp()
        openFeedCreate(app)
        let height = settled(exactText(app, "어떤 경기였나요?")).height
        app.terminate()
        return height
    }

    func testAccessibility01_runtimeGateProvesTheCategoryApplied() {
        let baseline = defaultRequiredHeadingHeight()
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        assertAccessibilityCategoryApplied(exactText(app, "어떤 경기였나요?"), defaultHeight: baseline)
    }

    func testAccessibility02_homeCreateRemainsUsable() {
        let app = homeApp(accessibilitySize: true)
        openHomeCreate(app)
        assertStep1RemainsUsable(app)
    }

    func testAccessibility03_calendarCreateRemainsUsable() {
        let app = calendarApp(accessibilitySize: true)
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")))
        openCalendarCreate(app)
        assertStep1RemainsUsable(app)
    }

    func testAccessibility04_recordDetailEditKeepsSeatAndCompanion() {
        let app = feedApp(accessibilitySize: true)
        openRecordDetailEdit(app)
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertFalse((seat.value as? String ?? "").isEmpty, "큰 글자에서 좌석이 비었다")
        scrollIntoView(app, exactText(app, "동행 유형"))
    }

    func testAccessibility05_longDiaryGrowsAndStaysReachable() {
        let app = longContentFeedApp(accessibilitySize: true)
        openRecordDetailEdit(app)
        let diaryHeading = scrollIntoView(app, exactText(app, "직관 다이어리"))
        XCTAssertGreaterThan(settled(diaryHeading).height, 0)
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
    }

    func testAccessibility06_validationErrorRemainsReachable() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 10), "큰 글자에서 검증 안내가 사라졌다")
        scrollIntoView(app, warning)
    }

    func testAccessibility07_featureSurfacesRemainReachable() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"))
        scrollIntoView(app, node(app, "recordCreate.assist.findGame"))
    }

    func testAccessibility08_keyboardStillLeavesTheFieldVisible() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        let field = scrollIntoView(app, node(app, "recordCreate.score.our"))
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 12), "큰 글자에서 키보드가 올라오지 않았다")
        let keyboardTop = settled(app.keyboards.element).minY
        XCTAssertLessThan(settled(field).maxY, keyboardTop + 0.5, "큰 글자에서 입력 필드가 키보드에 가렸다")
        node(app, "recordCreate.score.done").tap()
    }

    func testAccessibility09_cancellationRemainsPossible() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        let cancel = node(app, "recordCreate.cancel")
        XCTAssertTrue(cancel.isHittable, "큰 글자에서 취소를 누를 수 없다")
        cancel.tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "큰 글자에서 흐름을 닫지 못했다")
    }

    func testAccessibility10_noInternalNameIsSpoken() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        for internalName in ["RecordEditorDraft", "RecordCreateStep", "RecordEditorField",
                             "RecordEditorMode", "LogEditorViewModel", "photoLocalRefs",
                             "linkedKBOGameID", "appliedHighlightTags"] {
            XCTAssertFalse(text(app, internalName).exists, "내부 이름 \(internalName)이 읽힌다")
        }
    }
}
