import XCTest
import CryptoKit
import CoreGraphics
@testable import VictoryFairy

/// 개정 Pencil `01_Launch_and_Splash`에서 내보낸 네 페어리 쿼텟 런치 마크가
/// 네이티브 런치 화면 자산으로 정확히 실려 있는지 확인한다.
///
/// 런치 화면은 앱이 그리는 것이 아니라 **시스템이 자산 카탈로그에서 읽어 그린다.**
/// 그래서 여기서는 자산 파일 자체(PDF 구조·벡터 보존·외형 매핑)와, 앱이 가짜 스플래시로
/// 그것을 흉내 내지 않는다는 것을 확인한다.
final class LaunchMarkContractTests: XCTestCase {

    static let revisedPencilSHA256 = "8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2"

    // MARK: - Pencil 원본 매핑

    /// 확정된 production 소스. `01_Launch_and_Splash` 보드의 노드다.
    static let sourceNodes = [
        "LaunchMark.pdf": "i00UgJ",       // LaunchScreen_Light > 런치 마크 쿼텟
        "LaunchMark-Dark.pdf": "ATfKL"    // LaunchScreen_Dark  > 런치 마크 쿼텟
    ]

    /// 물러난 V-Wing 스플래시 마크 소스. 아직 Pencil에 남아 있지만 쓰지 않는다.
    static let supersededSplashNode = "nPZGr"   // SplashMark_OnDark

    static let expectedSHA = [
        "LaunchMark.pdf": "7b73585aa1538d03f68461a34bdcefa89fdc6319997175cf41efb94e76f366df",
        "LaunchMark-Dark.pdf": "3961018e70d79755433e84f5c361de8b25ee2947c63f421e4b88ec2742a0935e"
    ]

    /// 교체 전 실려 있던 V-Wing 런치 마크.
    static let retiredVWingLaunchSHA = "2b60eeb3fc21148e5273a014ecf89b2666781183e3897a209ba4049ae5ce3528"

    /// Pencil 핸드오프가 못박은 크기 — "LaunchScreen_Light/Dark — 배경 토큰 + 76pt 마크만".
    static let authoredMarkSide: CGFloat = 76

    /// AppIcon은 이번 패스에서 손대지 않는다. 해시가 그대로여야 한다.
    static let appIconSHA = [
        "AppIcon-1024.png": "43323e1a2948fc7e14c8aa4f0f4ad85da3606a410a5a609c582f79d134c0c9b8",
        "AppIcon-1024-Dark.png": "6fde4d723d04def12e96d59da04824f603e2b53c00947364dd79c65c8c4a370d",
        "AppIcon-1024-Tinted.png": "ed4672b6bfc7070d668cda0c2c73ae375def52174bf5fb5b247c904e82d32692"
    ]

    // MARK: - 경로

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }
    private static var launchSet: URL {
        appSourceRoot.appendingPathComponent("Assets.xcassets/LaunchMark.imageset")
    }
    private static var iconSet: URL {
        appSourceRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
    }

    private func source(_ path: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("소스를 찾을 수 없다: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func sha256(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    private func documentation() throws -> String {
        try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
    }

    // MARK: - 1~7. 원본과 소스 확정

    func testRevisedPencilHashIsStillTheRecordedSource() throws {
        XCTAssertTrue(try documentation().contains(Self.revisedPencilSHA256), "개정 Pencil 해시가 문서에 없다")
    }

    func testLaunchSourceNodesAreDocumented() throws {
        let doc = try documentation()
        for (file, node) in Self.sourceNodes {
            XCTAssertTrue(doc.contains(node), "\(file)의 소스 노드 \(node)가 문서에 없다")
        }
        XCTAssertTrue(doc.contains("01_Launch_and_Splash"), "런치 소스 보드가 문서에 없다")
        XCTAssertTrue(doc.contains("LaunchScreen_Light"), "라이트 런치 소스가 문서에 없다")
        XCTAssertTrue(doc.contains("LaunchScreen_Dark"), "다크 런치 소스가 문서에 없다")
    }

    /// 라이트 소스는 현재 production, 다크 스플래시 마크는 물러난 V-Wing이다.
    /// 두 사실이 문서에서 구분돼 있어야 한다.
    func testSourceOfTruthConflictIsResolvedInDocumentation() throws {
        let doc = try documentation()
        XCTAssertTrue(doc.contains("SplashMark_OnDark"), "물러난 다크 스플래시 마크가 분류돼 있어야 한다")
        XCTAssertTrue(doc.contains(Self.supersededSplashNode), "물러난 노드 ID가 문서에 없다")
        XCTAssertTrue(doc.contains(Self.retiredVWingLaunchSHA), "물러난 런치 마크 해시가 문서에 없다")
    }

    /// 라이트/다크 동작이 문서에 적혀 있어야 한다.
    func testLightAndDarkContractIsDocumented() throws {
        let doc = try documentation()
        XCTAssertTrue(doc.contains("APPEARANCE_SPECIFIC_MARKS"), "라이트/다크 계약이 문서에 없다")
        XCTAssertTrue(doc.contains("76pt"), "Pencil이 못박은 마크 크기가 문서에 없다")
    }

    // MARK: - 8~10. 자산 매핑

    func testLaunchMarkAssetExists() {
        for name in Self.sourceNodes.keys {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: Self.launchSet.appendingPathComponent(name).path),
                "\(name)이 없다"
            )
        }
    }

    /// 런치 마크 이미지 세트는 하나뿐이어야 한다. `LaunchMarkV2` 같은 중복 금지.
    func testLaunchMarkIsTheOnlyLaunchMarkImageSet() throws {
        let catalog = Self.appSourceRoot.appendingPathComponent("Assets.xcassets")
        let entries = try FileManager.default.contentsOfDirectory(atPath: catalog.path)
        let launchSets = entries.filter { $0.hasSuffix(".imageset") && $0.lowercased().contains("launch") }
        XCTAssertEqual(launchSets, ["LaunchMark.imageset"], "런치 마크 이미지 세트가 하나가 아니다: \(launchSets)")
    }

    func testLaunchMarkCatalogMappingIsValid() throws {
        let data = try Data(contentsOf: Self.launchSet.appendingPathComponent("Contents.json"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = json?["images"] as? [[String: Any]] ?? []
        XCTAssertEqual(images.count, 2, "라이트와 다크 두 항목이어야 한다")

        var byAppearance: [String: String] = [:]
        for image in images {
            guard let file = image["filename"] as? String else { continue }
            let appearances = image["appearances"] as? [[String: Any]] ?? []
            byAppearance[appearances.compactMap { $0["value"] as? String }.first ?? "default"] = file
        }
        XCTAssertEqual(byAppearance["default"], "LaunchMark.pdf")
        XCTAssertEqual(byAppearance["dark"], "LaunchMark-Dark.pdf")

        // 벡터 보존이 켜져 있어야 PDF가 래스터로 굳지 않는다.
        let properties = json?["properties"] as? [String: Any] ?? [:]
        XCTAssertEqual(properties["preserves-vector-representation"] as? Bool, true, "벡터 보존이 꺼졌다")
        XCTAssertEqual(properties["template-rendering-intent"] as? String, "original", "렌더링 의도가 바뀌었다")

        // 참조되지 않는 파일이 남아 있으면 안 된다.
        let onDisk = Set(try FileManager.default.contentsOfDirectory(atPath: Self.launchSet.path)
            .filter { $0.hasSuffix(".pdf") })
        XCTAssertEqual(onDisk, Set(byAppearance.values), "참조되지 않는 PDF가 남아 있다")
    }

    // MARK: - 11~15. PDF 구조

    private func pdf(_ name: String) throws -> CGPDFDocument {
        let url = Self.launchSet.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(name)이 없다")
        }
        guard let doc = CGPDFDocument(url as CFURL) else {
            XCTFail("\(name)을 PDF로 열 수 없다")
            throw XCTSkip("PDF 열기 실패")
        }
        return doc
    }

    func testEveryLaunchPDFHasExactlyOnePage() throws {
        for name in Self.sourceNodes.keys {
            XCTAssertEqual(try pdf(name).numberOfPages, 1, "\(name) 페이지 수가 1이 아니다")
        }
    }

    /// Pencil 핸드오프가 못박은 76pt 정사각이어야 한다.
    func testMediaAndCropBoxesMatchTheAuthoredSize() throws {
        for name in Self.sourceNodes.keys {
            guard let page = try pdf(name).page(at: 1) else {
                return XCTFail("\(name) 1페이지를 읽을 수 없다")
            }
            let media = page.getBoxRect(.mediaBox)
            XCTAssertEqual(media.width, Self.authoredMarkSide, accuracy: 0.01, "\(name) MediaBox 폭")
            XCTAssertEqual(media.height, Self.authoredMarkSide, accuracy: 0.01, "\(name) MediaBox 높이")
            XCTAssertEqual(media.origin.x, 0, accuracy: 0.01, "\(name) MediaBox x")
            XCTAssertEqual(media.origin.y, 0, accuracy: 0.01, "\(name) MediaBox y")

            // CropBox를 따로 두지 않았으면 MediaBox와 같아야 한다.
            let crop = page.getBoxRect(.cropBox)
            XCTAssertEqual(crop, media, "\(name) CropBox가 MediaBox와 다르다")
        }
    }

    /// 벡터로 남아 있어야 한다. 전면 래스터 이미지나 글꼴이 있으면 안 된다.
    func testLaunchPDFsRemainVectorWithoutRasterOrText() throws {
        for name in Self.sourceNodes.keys {
            let data = try Data(contentsOf: Self.launchSet.appendingPathComponent(name))
            let bytes = String(decoding: data, as: UTF8.self)

            XCTAssertFalse(bytes.contains("/Subtype /Image"), "\(name)에 래스터 이미지가 있다")
            XCTAssertFalse(bytes.contains("/Subtype/Image"), "\(name)에 래스터 이미지가 있다")
            XCTAssertFalse(bytes.contains("/Type /Font"), "\(name)에 글꼴이 있다")
            XCTAssertFalse(bytes.contains("/BaseFont"), "\(name)에 글꼴이 있다")

            // 실제 벡터 내용이 있어야 한다. 빈 PDF가 통과하면 안 된다.
            XCTAssertGreaterThan(data.count, 2_000, "\(name)이 너무 작다 — 벡터 내용이 없을 수 있다")
        }
    }

    // MARK: - 16~21. 쿼텟 정체성

    func testLaunchMarksMatchTheExpectedQuartetHashes() throws {
        for (name, expected) in Self.expectedSHA {
            XCTAssertEqual(
                try sha256(Self.launchSet.appendingPathComponent(name)), expected,
                "\(name)이 기대한 쿼텟 마크가 아니다"
            )
        }
    }

    func testRetiredVWingLaunchMarkIsAbsent() throws {
        for name in Self.sourceNodes.keys {
            XCTAssertNotEqual(
                try sha256(Self.launchSet.appendingPathComponent(name)),
                Self.retiredVWingLaunchSHA,
                "\(name)에 물러난 V-Wing 런치 마크가 살아 있다"
            )
        }
    }

    /// 라이트와 다크는 서로 다른 파일이어야 한다.
    /// 같으면 한쪽 배경에서 네거티브 스페이스가 어긋난다.
    func testLightAndDarkMarksAreDistinctFiles() throws {
        let light = try sha256(Self.launchSet.appendingPathComponent("LaunchMark.pdf"))
        let dark = try sha256(Self.launchSet.appendingPathComponent("LaunchMark-Dark.pdf"))
        XCTAssertNotEqual(light, dark, "라이트와 다크 마크가 같은 파일이다")
    }

    /// 두 마크는 같은 기하를 쓰므로 크기와 페이지 수가 같아야 한다.
    /// 다른 것은 네거티브 스페이스와 얼굴의 칠뿐이다.
    func testLightAndDarkShareTheSameGeometry() throws {
        let boxes = try Self.sourceNodes.keys.map { name -> CGRect in
            guard let page = try pdf(name).page(at: 1) else { return .zero }
            return page.getBoxRect(.mediaBox)
        }
        XCTAssertEqual(boxes.count, 2)
        XCTAssertEqual(boxes[0], boxes[1], "두 마크의 크기가 다르다")

        // 벡터 내용 길이가 사실상 같아야 한다(칠 색만 다르다).
        let sizes = try Self.sourceNodes.keys.map {
            try Data(contentsOf: Self.launchSet.appendingPathComponent($0)).count
        }
        XCTAssertLessThan(abs(sizes[0] - sizes[1]), 200, "두 마크의 내용 차이가 색 이상으로 크다")
    }

    // MARK: - 22~25. 배경과 런치 구성 소유권

    /// LaunchBackground는 이번 패스에서 바꾸지 않았다.
    /// Pencil 런치 프레임의 `$paper` / `$night`와 값이 같아야 한다.
    func testLaunchBackgroundIsUnchangedAndMatchesPencil() throws {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/LaunchBackground.colorset/Contents.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let colors = json?["colors"] as? [[String: Any]] ?? []
        XCTAssertEqual(colors.count, 2, "라이트와 다크 두 값이어야 한다")

        func components(_ entry: [String: Any]) -> [String: String] {
            let color = entry["color"] as? [String: Any] ?? [:]
            return (color["components"] as? [String: String]) ?? [:]
        }
        var byAppearance: [String: [String: String]] = [:]
        for entry in colors {
            let appearances = entry["appearances"] as? [[String: Any]] ?? []
            byAppearance[appearances.compactMap { $0["value"] as? String }.first ?? "default"] = components(entry)
        }
        // $paper #F4F4F2
        XCTAssertEqual(byAppearance["default"]?["red"], "0xF4")
        XCTAssertEqual(byAppearance["default"]?["green"], "0xF4")
        XCTAssertEqual(byAppearance["default"]?["blue"], "0xF2")
        // $night #0E1526
        XCTAssertEqual(byAppearance["dark"]?["red"], "0x0E")
        XCTAssertEqual(byAppearance["dark"]?["green"], "0x15")
        XCTAssertEqual(byAppearance["dark"]?["blue"], "0x26")
    }

    func testUILaunchScreenStillOwnsTheLaunchExperience() throws {
        let plist = try String(
            contentsOf: Self.appSourceRoot.appendingPathComponent("Info.plist"), encoding: .utf8
        )
        XCTAssertTrue(plist.contains("UILaunchScreen"), "UILaunchScreen 설정이 사라졌다")
        XCTAssertTrue(plist.contains("LaunchMark"), "UILaunchScreen이 LaunchMark를 참조하지 않는다")
        XCTAssertTrue(plist.contains("LaunchBackground"), "UILaunchScreen이 LaunchBackground를 참조하지 않는다")
    }

    // MARK: - 26~29. 네이티브 런치 소유권

    /// 런치 자산을 런타임에서 쓰는 곳이 **문서화된 공유 브랜드 마크 한 곳뿐**이어야 한다.
    ///
    /// `VFBrandMark`가 같은 자산을 쓰는 것은 의도된 공유다 — 스스로 "런치 화면과 앱 안이
    /// 어긋나지 않게 한다"고 적어 두었고, 온보딩 안에서 실제 콘텐츠로 쓰인다. 금지하는
    /// 것은 그것이 아니라 **런치 화면을 흉내 내는 가짜 스플래시**다. 그래서 참조를
    /// 통째로 막는 대신 그 한 곳으로 묶어 둔다.
    func testLaunchAssetIsUsedOnlyByTheDocumentedSharedBrandMark() throws {
        var referencing: [String] = []
        guard let enumerator = FileManager.default
            .enumerator(at: Self.appSourceRoot, includingPropertiesForKeys: nil) else {
            throw XCTSkip("소스 트리를 훑을 수 없다")
        }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let body = stripComments(try String(contentsOf: url, encoding: .utf8))
            if body.contains("\"LaunchMark\"") || body.contains("\"LaunchBackground\"") {
                referencing.append(url.lastPathComponent)
            }
        }
        XCTAssertEqual(
            referencing.sorted(), ["VFStadiumComponents.swift"],
            "런치 자산을 쓰는 곳이 공유 브랜드 마크 밖으로 번졌다: \(referencing)"
        )
    }

    /// 앱 진입점이 런치 화면을 다시 그리면 그것이 곧 가짜 스플래시다.
    func testAppEntryPointDoesNotRedrawTheLaunchScreen() throws {
        for file in ["VictoryFairyApp.swift", "AppRootView.swift"] {
            let body = stripComments(try source(file))
            XCTAssertFalse(body.contains("LaunchMark"), "\(file)이 런치 마크를 그리고 있다")
            XCTAssertFalse(body.contains("LaunchBackground"), "\(file)이 런치 배경을 그리고 있다")
        }
    }

    /// 전체 화면 스플래시 뷰 타입 자체가 없어야 한다.
    func testNoSplashViewTypeExists() throws {
        var offenders: [String] = []
        guard let enumerator = FileManager.default
            .enumerator(at: Self.appSourceRoot, includingPropertiesForKeys: nil) else {
            throw XCTSkip("소스 트리를 훑을 수 없다")
        }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let body = stripComments(try String(contentsOf: url, encoding: .utf8))
            for needle in ["struct SplashView", "struct LaunchView", "struct LaunchScreenView"]
            where body.contains(needle) {
                offenders.append("\(url.lastPathComponent):\(needle)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "가짜 스플래시 뷰가 있다: \(offenders)")
    }

    /// 공유 브랜드 마크는 런치 자산을 그대로 재사용해야 한다.
    /// 별도 사본을 두면 런치 화면과 앱 안이 갈라진다.
    func testSharedBrandMarkReusesTheLaunchAssetRatherThanACopy() throws {
        let body = stripComments(try source("SharedComponents/VFStadiumComponents.swift"))
        // 자산 이름을 그대로 라벨로 삼지 않도록 `Image(decorative:)`로 만든다.
        // 어느 쪽이든 **같은 런치 자산**을 쓰는지가 이 검사의 핵심이다.
        XCTAssertTrue(
            body.contains("Image(decorative: \"LaunchMark\")") || body.contains("Image(\"LaunchMark\")"),
            "공유 브랜드 마크가 런치 자산을 쓰지 않는다"
        )
        XCTAssertEqual(body.components(separatedBy: "\"LaunchMark\"").count - 1, 1,
                       "런치 자산 참조는 한 곳이어야 한다")
        XCTAssertFalse(body.contains("BrandMarkQuartet"), "브랜드 마크 사본을 따로 두면 안 된다")
    }

    /// 로딩을 가리려고 넣은 인위적 지연이 없어야 한다.
    func testNoArtificialLaunchDelayExists() throws {
        var offenders: [String] = []
        for file in ["VictoryFairyApp.swift", "AppRootView.swift"] {
            let body = stripComments(try source(file))
            for needle in ["Thread.sleep", "sleep(", "asyncAfter", "Task.sleep", "SplashView", "LaunchView"] {
                if body.contains(needle) { offenders.append("\(file):\(needle)") }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "런치를 인위적으로 늦추거나 가짜 스플래시를 두고 있다: \(offenders)")
    }

    private func stripComments(_ text: String) -> String {
        var output = ""
        let characters = Array(text)
        var index = 0
        var inLine = false, inBlock = false, inString = false
        while index < characters.count {
            let c = characters[index]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            if inLine {
                if c == "\n" { inLine = false; output.append(c) }
                index += 1; continue
            }
            if inBlock {
                if c == "*", next == "/" { inBlock = false; index += 2; continue }
                index += 1; continue
            }
            if inString {
                if c == "\\" { index += 2; continue }
                if c == "\"" { inString = false }
                output.append(c); index += 1; continue
            }
            if c == "/", next == "/" { inLine = true; index += 2; continue }
            if c == "/", next == "*" { inBlock = true; index += 2; continue }
            if c == "\"" { inString = true }
            output.append(c); index += 1
        }
        return output
    }

    // MARK: - 30~33. 런타임 증거

    /// 실기 콜드런치 증거가 문서에 남아 있어야 한다.
    /// 정적 캡처만으로 런치 화면을 증명했다고 말하지 않는다.
    func testColdLaunchEvidenceIsDocumented() throws {
        let doc = try documentation()
        for marker in ["콜드런치", "wait-for-debugger", "iPhone 17 Pro", "SE3"] {
            XCTAssertTrue(doc.contains(marker), "콜드런치 증거 \"\(marker)\"가 문서에 없다")
        }
    }

    // MARK: - 34~36. AppIcon 회귀

    func testAppIconFilesRemainUnchanged() throws {
        for (name, expected) in Self.appIconSHA {
            XCTAssertEqual(
                try sha256(Self.iconSet.appendingPathComponent(name)), expected,
                "\(name)이 이번 패스에서 바뀌었다 — AppIcon은 손대지 않는다"
            )
        }
    }

    func testAppIconCatalogStillDeclaresThreeRenditions() throws {
        let data = try Data(contentsOf: Self.iconSet.appendingPathComponent("Contents.json"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = json?["images"] as? [[String: Any]] ?? []
        XCTAssertEqual(images.count, 3, "AppIcon 렌디션 수가 바뀌었다")
        XCTAssertEqual(
            Set(images.compactMap { $0["filename"] as? String }),
            ["AppIcon-1024.png", "AppIcon-1024-Dark.png", "AppIcon-1024-Tinted.png"]
        )
    }

    // MARK: - 37~48. 다른 시스템 보존

    func testFairySystemsRemainUnchanged() {
        XCTAssertEqual(VFFairyKind.allCases.count, 12)
        XCTAssertEqual(VFFairyKind.pencilCompactKinds.count, 8)
        XCTAssertEqual(VFTeamFairyTrait.coveredTeamIDs.count, 10)
        XCTAssertEqual(VFStadiumFairyTrait.coveredStadiumIDs.count, 9)
        XCTAssertEqual(VFFairyIconPolicy.maximumFairiesPerScreen, 3)
    }

    /// 기록 상세와 피드는 개정 원본에 페어리 배치가 **없다.**
    ///
    /// 앞 패스에서는 "어느 화면에도 페어리가 없다"를 확인했지만, 배치 패스가 원본이
    /// 지정한 자리에 놓았다. 그래도 이 두 화면은 여전히 비어 있어야 한다 — 공유
    /// 컴포넌트를 함께 쓴다는 이유로 번지면 프레임이 원본과 어긋난다.
    func testRecordDetailAndFeedReceiveNoFairyPlacement() throws {
        for file in ["Features/RecordDetail/RecordDetailViews.swift",
                     "Features/Feed/FeedViews.swift"] {
            let body = stripComments(try source(file))
            for symbol in ["VFFairyGlyph(", "VFTeamFairy(", "VFStadiumFairy("] {
                XCTAssertFalse(
                    body.contains(symbol),
                    "\(file)에 \(symbol)이 들어갔다 — 원본에는 이 화면의 페어리 배치가 없다"
                )
            }
        }
    }

    func testCompletedScreensRemainInPlace() throws {
        let expectations: [(String, String)] = [
            ("Features/Home/HomeView.swift", "home.root"),
            ("Features/Feed/FeedViews.swift", "feed.addRecord"),
            ("Features/Calendar/CalendarViews.swift", "calendar.selectedDetail"),
            ("Domain/SeasonArchive.swift", "statistics.root"),
            ("Domain/RecordDetail.swift", "recordDetail.root")
        ]
        for (path, identifier) in expectations {
            XCTAssertTrue(try source(path).contains(identifier), "\(path)의 \(identifier)가 사라졌다")
        }
    }

    func testBundleReleaseVersionAndSigningAreCanonical() throws {
        let pbx = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("VictoryFairy.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        XCTAssertTrue(pbx.contains("com.hwangseokbeom.victoryfairy"), "번들 식별자가 바뀌었다")
        XCTAssertEqual(
            pbx.components(separatedBy: "MARKETING_VERSION = 1.2.0").count - 1,
            2,
            "앱 Debug/Release 마케팅 버전이 1.2.0으로 정렬되지 않았다"
        )
        XCTAssertEqual(
            pbx.components(separatedBy: "CURRENT_PROJECT_VERSION = 2").count - 1,
            2,
            "앱 Debug/Release 빌드 번호가 2로 정렬되지 않았다"
        )
        XCTAssertTrue(pbx.contains("CODE_SIGN_STYLE = Automatic"), "서명 방식이 바뀌었다")
        XCTAssertTrue(pbx.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon"), "아이콘 설정이 바뀌었다")
    }
}
