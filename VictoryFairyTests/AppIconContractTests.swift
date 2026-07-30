import XCTest
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif
@testable import VictoryFairy

/// 개정 Pencil `01_AppIcon_VictoryFairies`에서 내보낸 네 페어리 쿼텟 아이콘이
/// 실제 자산 카탈로그에 정확히 실려 있는지 확인한다.
///
/// 스크립트(`verify_app_icon.sh`)는 sips가 답할 수 있는 것만 본다. 코너 픽셀·전체
/// 출혈·중앙 네거티브 스페이스처럼 **픽셀을 직접 읽어야 하는 검사**는 여기서 한다.
final class AppIconContractTests: XCTestCase {

    static let revisedPencilSHA256 = "8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2"

    // MARK: - Pencil 원본 매핑

    /// 확정된 production 소스. `01_AppIcon_VictoryFairies` 보드의 노드다.
    static let sourceNodes = [
        "AppIcon-1024.png": "ZCOI9",        // AppIcon_VictoryFairies_Default_1024
        "AppIcon-1024-Dark.png": "NHBAs",   // AppIcon_VictoryFairies_Dark_1024
        "AppIcon-1024-Tinted.png": "nN1Mw"  // AppIcon_VictoryFairies_Tinted_1024
    ]

    /// Pencil `AppIcon_VictoryFairies_Monochrome` (`VR6X3`)는 카탈로그 렌디션이
    /// **아니다.** 얼굴 레이어가 없는 단일 톤 마크이며 Icon Composer 레이어 참고용이다.
    static let monochromeNode = "VR6X3"

    /// 지금 실려야 할 쿼텟 해시.
    static let expectedSHA = [
        "AppIcon-1024.png": "43323e1a2948fc7e14c8aa4f0f4ad85da3606a410a5a609c582f79d134c0c9b8",
        "AppIcon-1024-Dark.png": "6fde4d723d04def12e96d59da04824f603e2b53c00947364dd79c65c8c4a370d",
        "AppIcon-1024-Tinted.png": "ed4672b6bfc7070d668cda0c2c73ae375def52174bf5fb5b247c904e82d32692"
    ]

    /// 물러난 세대. 어느 렌디션에도 다시 나타나면 안 된다.
    static let retiredSHA: Set<String> = [
        "64be923a2f82c4b3a46d2ccfd040a145ed95bd1bb8f76872ac3fba0a08c0b17e",  // 산호색
        "323baf6d55a97e75ff0b68d125ce2d53ed7174e4da8aa26850c47eb8b75f6507",  // V-Wing Default
        "9bac8cda2f812b082a07d43adddce2b5c3455321557a3da0c02a0fc4fedc9a50",  // V-Wing Dark
        "80e31400b494f67d72e25ae35e61c141882afaa45891a0d26ea8dbb798a26fca"   // V-Wing Tinted
    ]

    /// 각 렌디션의 배경색. Pencil 프레임 fill에서 읽었다.
    static let background: [String: (UInt8, UInt8, UInt8)] = [
        "AppIcon-1024.png": (0x0E, 0x15, 0x26),        // $fairyIconBg
        "AppIcon-1024-Dark.png": (0x07, 0x0C, 0x16),   // $fairyIconBgDark
        "AppIcon-1024-Tinted.png": (0x00, 0x00, 0x00)
    ]

    /// Default/Dark 쿼텟 네 몸 색.
    static let quartet: [String: (UInt8, UInt8, UInt8)] = [
        "team": (0x5E, 0x7F, 0xA6), "memory": (0x9D, 0x93, 0xC8),
        "stadium": (0x2F, 0x7A, 0x56), "victory": (0xF2, 0xB6, 0x3C)
    ]

    // MARK: - 경로

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }
    private static var iconSet: URL {
        appSourceRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
    }

    private func iconURL(_ name: String) -> URL { Self.iconSet.appendingPathComponent(name) }

    private func source(_ path: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("소스를 찾을 수 없다: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func sha256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 픽셀 읽기

    private struct Bitmap {
        let width: Int
        let height: Int
        let pixels: [UInt8]   // RGBA

        func at(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
            let i = (y * width + x) * 4
            return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
        }
    }

    private func bitmap(_ name: String) throws -> Bitmap {
        #if canImport(UIKit)
        let url = iconURL(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("아이콘 파일이 없다: \(name)")
        }
        guard let image = UIImage(contentsOfFile: url.path), let cg = image.cgImage else {
            XCTFail("\(name) 을 이미지로 읽을 수 없다")
            throw XCTSkip("decode 실패")
        }
        let w = cg.width, h = cg.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buffer, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("\(name) 비트맵 컨텍스트를 만들 수 없다")
            throw XCTSkip("context 실패")
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Bitmap(width: w, height: h, pixels: buffer)
        #else
        throw XCTSkip("UIKit 없이 픽셀을 읽을 수 없다")
        #endif
    }

    /// 상대 휘도. 인라인으로 쓰면 Swift 타입 검사기가 시간 안에 못 푼다.
    private func luminance(_ p: (UInt8, UInt8, UInt8, UInt8)) -> Double {
        let r = Double(p.0) * 0.2126
        let g = Double(p.1) * 0.7152
        let b = Double(p.2) * 0.0722
        return r + g + b
    }

    private func near(
        _ a: (UInt8, UInt8, UInt8, UInt8), _ b: (UInt8, UInt8, UInt8), tol: Int = 3
    ) -> Bool {
        abs(Int(a.0) - Int(b.0)) <= tol && abs(Int(a.1) - Int(b.1)) <= tol
            && abs(Int(a.2) - Int(b.2)) <= tol
    }

    // MARK: - 1~4. 원본과 소스 확정

    func testRevisedPencilHashIsStillTheRecordedSource() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains(Self.revisedPencilSHA256), "개정 Pencil 해시가 문서에 없다")
    }

    /// 어느 Pencil 노드가 어느 렌디션이 됐는지 문서에 남아 있어야 한다.
    func testAppIconSourceNodesAreDocumented() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        for (file, node) in Self.sourceNodes {
            XCTAssertTrue(doc.contains(node), "\(file)의 소스 노드 \(node)가 문서에 없다")
        }
        XCTAssertTrue(doc.contains("01_AppIcon_VictoryFairies"), "확정된 소스 보드가 문서에 없다")
    }

    /// 두 보드가 경쟁하던 상태가 문서에서 해소돼 있어야 한다.
    func testSourceOfTruthConflictIsResolvedInDocumentation() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains("01_Brand_and_AppIcon"), "물러난 보드가 문서에 분류돼 있어야 한다")
        XCTAssertTrue(doc.contains(Self.monochromeNode), "Monochrome 노드의 역할이 문서에 없다")
    }

    // MARK: - 5~12. 카탈로그 계약

    func testCatalogDeclaresExactlyThreeSupportedRenditions() throws {
        let data = try Data(contentsOf: Self.iconSet.appendingPathComponent("Contents.json"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = json?["images"] as? [[String: Any]] ?? []
        XCTAssertEqual(images.count, 3, "카탈로그 렌디션은 셋이다 — 네 번째는 지원되지 않는다")

        let names = Set(images.compactMap { $0["filename"] as? String })
        XCTAssertEqual(names, Set(Self.sourceNodes.keys), "렌디션 파일 이름이 다르다")

        // 외형 매핑이 정확해야 한다.
        var appearanceByFile: [String: String] = [:]
        for image in images {
            guard let file = image["filename"] as? String else { continue }
            let appearances = image["appearances"] as? [[String: Any]] ?? []
            appearanceByFile[file] = appearances.compactMap { $0["value"] as? String }.first ?? "default"
        }
        XCTAssertEqual(appearanceByFile["AppIcon-1024.png"], "default")
        XCTAssertEqual(appearanceByFile["AppIcon-1024-Dark.png"], "dark")
        XCTAssertEqual(appearanceByFile["AppIcon-1024-Tinted.png"], "tinted")
    }

    func testEveryReferencedFileExistsAndNoOrphanRemains() throws {
        let data = try Data(contentsOf: Self.iconSet.appendingPathComponent("Contents.json"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let referenced = Set(((json?["images"] as? [[String: Any]]) ?? [])
            .compactMap { $0["filename"] as? String })
        for name in referenced {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: iconURL(name).path),
                "참조된 \(name)이 없다"
            )
        }
        let onDisk = Set(try FileManager.default
            .contentsOfDirectory(atPath: Self.iconSet.path)
            .filter { $0.hasSuffix(".png") })
        XCTAssertEqual(onDisk, referenced, "참조되지 않는 아이콘 파일이 남아 있다: \(onDisk.subtracting(referenced))")
    }

    func testEveryProductionRenditionIs1024Square() throws {
        for name in Self.sourceNodes.keys {
            let bmp = try bitmap(name)
            XCTAssertEqual(bmp.width, 1024, "\(name) 폭")
            XCTAssertEqual(bmp.height, 1024, "\(name) 높이")
        }
    }

    func testEveryProductionRenditionIsFullyOpaque() throws {
        for name in Self.sourceNodes.keys {
            let bmp = try bitmap(name)
            var nonOpaque = 0
            for i in stride(from: 3, to: bmp.pixels.count, by: 4) where bmp.pixels[i] != 255 {
                nonOpaque += 1
            }
            XCTAssertEqual(nonOpaque, 0, "\(name)에 불투명하지 않은 픽셀이 \(nonOpaque)개 있다")
        }
    }

    // MARK: - 13~15. 출혈과 코너

    /// 네 코너가 모두 배경색이면 라운드 코너를 구워 넣지 않았다는 뜻이다.
    func testNoBakedRoundedCornersInAnyRendition() throws {
        for (name, bg) in Self.background {
            let bmp = try bitmap(name)
            let corners = [
                bmp.at(0, 0), bmp.at(bmp.width - 1, 0),
                bmp.at(0, bmp.height - 1), bmp.at(bmp.width - 1, bmp.height - 1)
            ]
            for (index, corner) in corners.enumerated() {
                XCTAssertEqual(corner.3, 255, "\(name) 코너 \(index)가 투명하다")
                XCTAssertTrue(
                    near(corner, bg),
                    "\(name) 코너 \(index)가 배경색이 아니다: \(corner) — 라운드 코너가 구워졌을 수 있다"
                )
            }
        }
    }

    /// 바깥 테두리 전체가 배경색이어야 전체 출혈이다.
    func testBackgroundIsFullBleedToEveryEdge() throws {
        for (name, bg) in Self.background {
            let bmp = try bitmap(name)
            var offBackground = 0
            for x in stride(from: 0, to: bmp.width, by: 4) {
                if !near(bmp.at(x, 0), bg, tol: 4) { offBackground += 1 }
                if !near(bmp.at(x, bmp.height - 1), bg, tol: 4) { offBackground += 1 }
            }
            for y in stride(from: 0, to: bmp.height, by: 4) {
                if !near(bmp.at(0, y), bg, tol: 4) { offBackground += 1 }
                if !near(bmp.at(bmp.width - 1, y), bg, tol: 4) { offBackground += 1 }
            }
            XCTAssertEqual(offBackground, 0, "\(name) 가장자리에 배경이 아닌 픽셀이 \(offBackground)개 있다")
        }
    }

    // MARK: - 16~20. 쿼텟 정체성

    func testProductionRenditionsMatchTheExpectedQuartetHashes() throws {
        for (name, expected) in Self.expectedSHA {
            XCTAssertEqual(try sha256(iconURL(name)), expected, "\(name)이 기대한 쿼텟 아이콘이 아니다")
        }
    }

    func testNoRetiredVWingHashSurvivesInAnyProductionFile() throws {
        for name in Self.sourceNodes.keys {
            let sha = try sha256(iconURL(name))
            XCTAssertFalse(Self.retiredSHA.contains(sha), "\(name)에 물러난 세대가 살아 있다")
        }
    }

    func testTheThreeRenditionsAreGenuinelyDifferentFiles() throws {
        let hashes = try Self.sourceNodes.keys.map { try sha256(iconURL($0)) }
        XCTAssertEqual(Set(hashes).count, 3, "두 렌디션이 같은 파일이다 — Dark가 Default를 베끼면 안 된다")
    }

    /// Default와 Dark에 네 페어리 몸 색이 모두 실제로 들어 있어야 한다.
    func testAllFourFairyBodiesArePresentInDefaultAndDark() throws {
        for name in ["AppIcon-1024.png", "AppIcon-1024-Dark.png"] {
            let bmp = try bitmap(name)
            for (fairy, colour) in Self.quartet {
                var count = 0
                for i in stride(from: 0, to: bmp.pixels.count, by: 4) {
                    let p = (bmp.pixels[i], bmp.pixels[i + 1], bmp.pixels[i + 2], bmp.pixels[i + 3])
                    if near(p, colour, tol: 6) { count += 1 }
                }
                XCTAssertGreaterThan(count, 50_000, "\(name)에 \(fairy) 페어리가 없다 (\(count)px)")
            }
        }
    }

    /// 중앙 네거티브 스페이스 — 가운데가 배경색으로 뚫려 있어야 한다.
    func testCentralNegativeSpaceExistsInEveryRendition() throws {
        for (name, bg) in Self.background {
            let bmp = try bitmap(name)
            let centre = bmp.at(bmp.width / 2, bmp.height / 2)
            XCTAssertTrue(
                near(centre, bg),
                "\(name) 가운데가 배경색이 아니다: \(centre) — 네거티브 스페이스가 사라졌다"
            )
        }
    }

    /// 쿼텟이 광학적으로 가운데 있어야 한다. 배경이 아닌 픽셀의 경계 상자로 잰다.
    func testQuartetIsOpticallyCentred() throws {
        for (name, bg) in Self.background {
            let bmp = try bitmap(name)
            var minX = bmp.width, maxX = 0, minY = bmp.height, maxY = 0
            for y in stride(from: 0, to: bmp.height, by: 2) {
                for x in stride(from: 0, to: bmp.width, by: 2) where !near(bmp.at(x, y), bg, tol: 6) {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            XCTAssertLessThan(minX, bmp.width, "\(name)에 전경이 없다")
            let cx = Double(minX + maxX) / 2.0
            let cy = Double(minY + maxY) / 2.0
            XCTAssertEqual(cx, Double(bmp.width) / 2.0, accuracy: 12, "\(name) 쿼텟이 가로로 치우쳤다")
            XCTAssertEqual(cy, Double(bmp.height) / 2.0, accuracy: 12, "\(name) 쿼텟이 세로로 치우쳤다")

            // 쿼텟이 캔버스의 대부분을 채워야 한다. 작게 오그라들면 아이콘이 비어 보인다.
            let span = Double(maxX - minX) / Double(bmp.width)
            XCTAssertGreaterThan(span, 0.75, "\(name) 쿼텟이 너무 작다 (\(span))")
        }
    }

    // MARK: - 21~27. 소형 크기 · 마스크 · 그레이스케일

    /// 축소해도 네 페어리와 중앙 다이아몬드가 남아야 한다.
    /// 29px은 Pencil 검증 보드가 기준으로 삼은 크기다.
    func testQuartetSurvivesDownToSixteenPixels() throws {
        for (name, bg) in Self.background {
            let bmp = try bitmap(name)
            for target in [120, 60, 40, 29, 20, 16] {
                let small = downscale(bmp, to: target)
                let centre = small.at(target / 2, target / 2)
                XCTAssertTrue(
                    near(centre, bg, tol: 40),
                    "\(name) @\(target)px 중앙 네거티브 스페이스가 사라졌다: \(centre)"
                )
                let corner = small.at(0, 0)
                XCTAssertTrue(near(corner, bg, tol: 8), "\(name) @\(target)px 코너가 배경이 아니다")

                // 서로 다른 밝기 덩어리가 최소 넷은 남아야 네 형상이 읽힌다.
                var tones = Set<Int>()
                for y in 0..<target {
                    for x in 0..<target {
                        let p = small.at(x, y)
                        if near(p, bg, tol: 20) { continue }
                        tones.insert(Int(luminance(p)) / 12)
                    }
                }
                XCTAssertGreaterThanOrEqual(
                    tones.count, 3,
                    "\(name) @\(target)px 형상이 한 덩어리로 뭉갰다 (밝기 그룹 \(tones.count))"
                )
            }
        }
    }

    /// 표준 시스템 마스크(스퀘어클)가 쿼텟을 잘라내지 않아야 한다.
    func testStandardSystemMaskClipsNoFairyPixels() throws {
        let bmp = try bitmap("AppIcon-1024.png")
        let small = downscale(bmp, to: 256)
        guard let bg = Self.background["AppIcon-1024.png"] else { return XCTFail("배경색 없음") }
        var clipped = 0, foreground = 0
        let a = 128.0
        for y in 0..<256 {
            for x in 0..<256 {
                let p = small.at(x, y)
                guard !near(p, bg, tol: 6) else { continue }
                foreground += 1
                let dx = (Double(x) + 0.5 - a) / a, dy = (Double(y) + 0.5 - a) / a
                if pow(abs(dx), 5) + pow(abs(dy), 5) > 1.0 { clipped += 1 }
            }
        }
        XCTAssertGreaterThan(foreground, 0)
        let ratio = Double(clipped) / Double(foreground)
        XCTAssertLessThan(ratio, 0.005, "표준 마스크가 전경의 \(ratio * 100)%를 잘라낸다")
    }

    /// 색을 지워도 네 형상이 밝기로 갈려야 한다.
    func testQuartetStaysSeparableInGrayscale() throws {
        for name in Self.sourceNodes.keys {
            guard let bg = Self.background[name] else { continue }
            let bmp = try bitmap(name)
            let small = downscale(bmp, to: 128)
            var tones = Set<Int>()
            for y in 0..<128 {
                for x in 0..<128 {
                    let p = small.at(x, y)
                    if near(p, bg, tol: 12) { continue }
                    tones.insert(Int(luminance(p)) / 16)
                }
            }
            XCTAssertGreaterThanOrEqual(tones.count, 3, "\(name) 그레이스케일에서 형상이 뭉갰다")
        }
    }

    /// Tinted는 밝기 계단이 가장 넓어야 시스템 틴트가 네 형상을 살린다.
    func testTintedRenditionHasTheWidestLuminanceRange() throws {
        let tinted = try bitmap("AppIcon-1024-Tinted.png")
        var minL = 255.0, maxL = 0.0
        for i in stride(from: 0, to: tinted.pixels.count, by: 4) {
            let p = (tinted.pixels[i], tinted.pixels[i + 1], tinted.pixels[i + 2], UInt8(255))
            let l = luminance(p)
            minL = min(minL, l); maxL = max(maxL, l)
        }
        XCTAssertLessThan(minL, 8, "Tinted에 순검정이 없다")
        XCTAssertGreaterThan(maxL, 247, "Tinted에 순백이 없다")
    }

    private func downscale(_ bmp: Bitmap, to target: Int) -> Bitmap {
        var out = [UInt8](repeating: 0, count: target * target * 4)
        let sx = Double(bmp.width) / Double(target)
        let sy = Double(bmp.height) / Double(target)
        for ty in 0..<target {
            let y0 = Int(Double(ty) * sy), y1 = max(y0 + 1, Int(Double(ty + 1) * sy))
            for tx in 0..<target {
                let x0 = Int(Double(tx) * sx), x1 = max(x0 + 1, Int(Double(tx + 1) * sx))
                var r = 0, g = 0, b = 0, a = 0, n = 0
                for y in y0..<min(y1, bmp.height) {
                    for x in x0..<min(x1, bmp.width) {
                        let p = bmp.at(x, y)
                        r += Int(p.0); g += Int(p.1); b += Int(p.2); a += Int(p.3); n += 1
                    }
                }
                let d = (ty * target + tx) * 4
                out[d] = UInt8(r / n); out[d + 1] = UInt8(g / n)
                out[d + 2] = UInt8(b / n); out[d + 3] = UInt8(a / n)
            }
        }
        return Bitmap(width: target, height: target, pixels: out)
    }

    // MARK: - 28~29. 아트워크 출처

    /// 래스터 AI 소스를 들이지 않았다. 아이콘은 Pencil 벡터에서 내보낸 것뿐이다.
    func testNoExtraRasterSourceWasAddedToTheProject() throws {
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: Self.iconSet.path)
        XCTAssertEqual(
            Set(onDisk), Set(Self.sourceNodes.keys).union(["Contents.json"]),
            "아이콘 세트에 예상 밖의 파일이 있다: \(onDisk)"
        )
        // 저장소 루트에 남아 있던 예전 1024 원본이 다시 늘어나지 않았는지 본다.
        let strays = try FileManager.default
            .contentsOfDirectory(atPath: Self.repositoryRoot.path)
            .filter { $0.hasSuffix(".png") && $0.lowercased().contains("appicon") }
        XCTAssertLessThanOrEqual(strays.count, 1, "저장소 루트에 아이콘 원본이 늘었다: \(strays)")
    }

    /// 구단 로고나 KBO 마크가 들어갈 자리가 없다. 아이콘에는 글자도 없다.
    /// 쿼텟은 네 페어리 몸 색과 배경, 잉크 외곽선, 금색 다이아몬드로만 이루어진다.
    func testDefaultRenditionUsesOnlyTheApprovedBrandPalette() throws {
        let bmp = try bitmap("AppIcon-1024.png")
        var histogram: [UInt32: Int] = [:]
        for i in stride(from: 0, to: bmp.pixels.count, by: 4) {
            let key = (UInt32(bmp.pixels[i]) << 16) | (UInt32(bmp.pixels[i + 1]) << 8)
                | UInt32(bmp.pixels[i + 2])
            histogram[key, default: 0] += 1
        }
        let bulk = histogram.filter { $0.value > 20_000 }
        // 배경 + 네 페어리 + 잉크 외곽선 + 금색 다이아몬드 = 일곱을 넘지 않는다.
        XCTAssertLessThanOrEqual(bulk.count, 7, "승인되지 않은 색 덩어리가 있다: \(bulk.count)")
    }

    // MARK: - 30~34. 손대지 않은 것

    func testLaunchMarkRemainsUnchanged() throws {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/LaunchMark.imageset/LaunchMark.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "LaunchMark.pdf가 사라졌다")
        // 앞 패스에서는 여기에 V-Wing 해시가 박혀 있었고, 쿼텟 교체 때 함께 갱신하라고
        // 적어 두었다. `pass/launch-mark-quartet`이 실제로 교체했으므로 그대로 갱신한다.
        // 검사 강도는 그대로다 — AppIcon 작업이 런치 자산을 건드리지 않는지 여전히 본다.
        // 런치 자체의 계약은 `LaunchMarkContractTests`가 자세히 맡는다.
        XCTAssertEqual(
            try sha256(url), "7b73585aa1538d03f68461a34bdcefa89fdc6319997175cf41efb94e76f366df",
            "LaunchMark가 기대한 쿼텟 마크가 아니다"
        )
        let dark = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/LaunchMark.imageset/LaunchMark-Dark.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dark.path), "다크 런치 마크가 없다")
    }

    func testLaunchBackgroundRemainsUnchanged() {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/LaunchBackground.colorset/Contents.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "LaunchBackground가 사라졌다")
    }

    func testBundleIdentifierMarketingVersionAndSigningAreUnchanged() throws {
        let pbx = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("VictoryFairy.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        XCTAssertTrue(pbx.contains("com.hwangseokbeom.victoryfairy"), "번들 식별자가 바뀌었다")
        XCTAssertTrue(pbx.contains("MARKETING_VERSION = 1.1.0"), "마케팅 버전이 바뀌었다")
        XCTAssertTrue(pbx.contains("CODE_SIGN_STYLE = Automatic"), "서명 방식이 바뀌었다")
        XCTAssertTrue(pbx.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon"), "아이콘 설정이 바뀌었다")
        XCTAssertFalse(pbx.contains("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES"), "대체 아이콘 설정이 생겼다")
    }

    // MARK: - 35~42. 다른 시스템 보존

    func testFairyFoundationRemainsUnchanged() {
        XCTAssertEqual(VFFairyKind.allCases.count, 12)
        XCTAssertEqual(VFFairyKind.pencilCompactKinds.count, 8)
        XCTAssertEqual(VFFairyIconPolicy.maximumFairiesPerScreen, 3)
    }

    func testTeamFairySystemRemainsUnchanged() {
        XCTAssertEqual(VFTeamFairyTrait.allCases.count, 11)
        XCTAssertEqual(VFTeamFairyTrait.coveredTeamIDs.count, 10)
        XCTAssertEqual(VFTeamFairy.pairing, .requiresTeamName)
    }

    func testStadiumFairySystemRemainsUnchanged() {
        XCTAssertEqual(VFStadiumFairyTrait.coveredStadiumIDs.count, 9)
        XCTAssertEqual(VFStadiumFairy.pairing, .requiresStadiumName)
        XCTAssertNil(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: nil))
    }

    func testNoProductionScreenWasEdited() throws {
        var offenders: [String] = []
        for folder in ["Features", "SharedComponents"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in e where url.pathExtension == "swift" {
                let body = try String(contentsOf: url, encoding: .utf8)
                for symbol in ["VFStadiumFairy", "VFTeamFairy", "VFFairyGlyph"] where body.contains(symbol) {
                    offenders.append("\(url.lastPathComponent):\(symbol)")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "아이콘 패스에서 화면이 바뀌었다: \(offenders)")
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
}
