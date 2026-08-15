import XCTest
import UIKit
@testable import VictoryFairy

/// jYs0S 단일 기록 카드와 출력 부작용의 집중 계약.
@MainActor
final class MemoryShareCardTests: XCTestCase {
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repositoryRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private func date(_ year: Int = 2026, _ month: Int = 4, _ day: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func log(
        id: UUID = UUID(uuidString: "09A70000-0000-0000-0000-000000000101")!,
        date: Date? = nil,
        dateText: String = "의도적으로 틀린 표시 날짜",
        matchup: String = "삼성 라이온즈 vs LG 트윈스",
        stadium: String = "잠실야구장",
        result: GameResult = .win,
        ourScore: Int? = 6,
        opponentScore: Int? = 3,
        photoLocalRefs: [String] = []
    ) -> AttendanceLogViewState {
        AttendanceLogViewState(
            id: id,
            date: date ?? self.date(),
            dateText: dateText,
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ourScore,
            opponentScore: opponentScore,
            seat: "1루 101블록",
            companion: "표시하면 안 되는 동행",
            memo: "표시하면 안 되는 메모",
            caption: "표시하면 안 되는 캡션",
            diary: "표시하면 안 되는 일기",
            tags: ["표시하면 안 되는 태그"],
            photoLocalRefs: photoLocalRefs,
            officialRecordURL: URL(string: "https://example.com/deep-link")?.absoluteString
        )
    }

    private func rendered(_ log: AttendanceLogViewState? = nil) -> UIImage? {
        MemoryShareCardRenderer.render(content: MemoryShareCardContent(log: log ?? self.log()), photo: nil)
    }

    private func onePixelImage(color: UIColor = .red) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format)
            .image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            }
    }

    func testM01_recordModeRequiresARealAttendanceRecord() throws {
        let model = try source("VictoryFairy/Domain/MemoryShareCard.swift")
        let preview = try source("VictoryFairy/Features/Share/ShareCardPreviewView.swift")
        XCTAssertTrue(model.contains("init(log: AttendanceLogViewState)"))
        XCTAssertTrue(preview.contains("log: AttendanceLogViewState,"))
        XCTAssertFalse(preview.contains("AttendanceLogViewState?"))
    }

    func testM02_productionShareHasNoAttendanceLogSampleFallback() throws {
        let source = try source("VictoryFairy/Features/Share/ShareCardPreviewView.swift")
        XCTAssertFalse(source.contains("AttendanceLogSample"))
    }

    func testM03_productionShareHasNoNowFallback() throws {
        let share = try source("VictoryFairy/Features/Share/ShareCardPreviewView.swift")
        let model = try source("VictoryFairy/Domain/MemoryShareCard.swift")
        XCTAssertFalse(share.contains(".now"))
        XCTAssertFalse(model.contains(".now"))
    }

    func testM04_missingTeamIsHonestAndNeverUsesAFakeClub() {
        let content = MemoryShareCardContent(log: log(matchup: ""))
        XCTAssertEqual(content.firstTeamText, "팀 미기록")
        XCTAssertFalse(content.matchupText.contains("우리팀"))
    }

    func testM05_missingStadiumIsHonestAndNeverUsesAFakeVenue() {
        let content = MemoryShareCardContent(log: log(stadium: "   "))
        XCTAssertEqual(content.stadiumText, "구장 미기록")
        XCTAssertNotEqual(content.stadiumText, KBOStadiumSeed.all.first?.shortName)
    }

    func testM06_missingScoreNeverFabricatesNumbers() {
        let content = MemoryShareCardContent(log: log(ourScore: nil, opponentScore: nil))
        XCTAssertEqual(content.scoreText, "점수 미기록")
        XCTAssertFalse(content.matchupAndScoreText.contains("0 : 0"))
    }

    func testM07_recordDetailPassesItsExactRecord() throws {
        let detail = try source("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift")
        XCTAssertTrue(detail.contains("ShareCardPreviewView(log: viewModel.log)"))
    }

    func testM08_feedPassesItsExactVisibleRecord() throws {
        let feed = try source("VictoryFairy/Features/Feed/FeedViews.swift")
        XCTAssertTrue(feed.contains("ShareCardPreviewView(log: log)"))
        XCTAssertTrue(feed.contains("feed.share.\\(log.id.uuidString)"))
    }

    func testM09_statisticsNeverEntersOneRecordMemoryCardMode() throws {
        let statistics = try source("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        XCTAssertFalse(statistics.contains("ShareCardPreviewView"))
        XCTAssertFalse(statistics.contains("MemoryShareCardContent"))
    }

    func testM10_statisticsNeverManufacturesAnAttendanceRecordForSharing() throws {
        let statistics = try source("VictoryFairy/Features/Statistics/StatisticsViews.swift")
        XCTAssertFalse(statistics.contains("AttendanceLogViewState("))
        XCTAssertTrue(statistics.contains("SEASON_SHARE_REQUIRES_SEPARATE_PRODUCT_DESIGN"))
    }

    func testM11_photoResolverUsesTheFirstReadableRecordOwnedReference() {
        var attempts: [String] = []
        let expected = onePixelImage()
        let selected = MemorySharePhotoResolver.firstReadable(in: ["missing-a", "readable", "later"]) {
            attempts.append($0)
            return $0 == "readable" ? expected : nil
        }
        XCTAssertEqual(selected?.reference, "readable")
        XCTAssertTrue(selected?.image === expected)
        XCTAssertEqual(attempts, ["missing-a", "readable"])
    }

    func testM12_noReadablePhotoProducesPlaceholderSelection() {
        XCTAssertNil(MemorySharePhotoResolver.firstReadable(in: ["missing-a", "missing-b"]) { _ in nil })
    }

    func testM13_unreadableMediaHasNoNetworkFallback() throws {
        let source = try source("VictoryFairy/Features/Share/ShareCardPreviewView.swift")
        for forbidden in ["URLSession", "AsyncImage", "Unsplash", "http://", "https://"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testM14_resultStampUsesTheCanonicalStoredResult() {
        for result in GameResult.allCases {
            XCTAssertEqual(MemoryShareCardContent(log: log(result: result)).result, result)
        }
    }

    func testM15_scoreUsesCanonicalStoredValues() {
        let content = MemoryShareCardContent(log: log(ourScore: 11, opponentScore: 2))
        XCTAssertEqual(content.scoreText, "11 : 2")
        XCTAssertEqual(content.matchupAndScoreText, "삼성 11 : 2 LG")
    }

    func testM16_canceledRecordNeverRendersFakeZeroScore() {
        let content = MemoryShareCardContent(log: log(result: .canceled, ourScore: 0, opponentScore: 0))
        XCTAssertEqual(content.scoreText, "경기 취소")
        XCTAssertFalse(content.matchupAndScoreText.contains("0 : 0"))
    }

    func testM17_missingScoreRendersTheHonestState() {
        let content = MemoryShareCardContent(log: log(ourScore: 4, opponentScore: nil))
        XCTAssertEqual(content.scoreText, "점수 미기록")
        XCTAssertTrue(content.matchupAndScoreText.contains("점수 미기록"))
    }

    func testM18_dateComesFromTheStoredDateNotCachedDisplayCopy() {
        let content = MemoryShareCardContent(log: log(date: date(2025, 12, 31), dateText: "2099.01.01"))
        XCTAssertEqual(content.dateText, "2025.12.31")
        XCTAssertNotEqual(content.dateText, "2099.01.01")
    }

    func testM19_stadiumComesFromTheRecord() {
        let content = MemoryShareCardContent(log: log(stadium: "울산 문수야구장"))
        XCTAssertEqual(content.stadiumText, "울산 문수야구장")
    }

    func testM20_resolvableStadiumUsesTheCanonicalShortName() {
        XCTAssertEqual(MemoryShareCardContent(log: log(stadium: "잠실야구장")).stadiumText, "잠실")
        XCTAssertEqual(MemoryShareCardContent(log: log(stadium: "수원 KT 위즈파크")).stadiumText, "수원")
    }

    func testM21_unknownStadiumPreservesTheHonestStoredText() {
        let value = "등록부 밖의 아주 긴 독립 구장 이름"
        XCTAssertEqual(MemoryShareCardContent(log: log(stadium: value)).stadiumText, value)
    }

    func testM22_displayNameCannotEnterTheCardModel() throws {
        XCTAssertFalse(try source("VictoryFairy/Domain/MemoryShareCard.swift").contains("displayName"))
    }

    func testM23_diaryCannotEnterTheCardModel() throws {
        XCTAssertFalse(try source("VictoryFairy/Domain/MemoryShareCard.swift").contains("log.diary"))
    }

    func testM24_seatCannotEnterTheCardModel() throws {
        XCTAssertFalse(try source("VictoryFairy/Domain/MemoryShareCard.swift").contains("log.seat"))
    }

    func testM25_companionCannotEnterTheCardModel() throws {
        XCTAssertFalse(try source("VictoryFairy/Domain/MemoryShareCard.swift").contains("log.companion"))
    }

    func testM26_weatherCannotEnterTheCardModel() throws {
        XCTAssertFalse(try source("VictoryFairy/Domain/MemoryShareCard.swift").localizedCaseInsensitiveContains("weather"))
    }

    func testM27_fairyCannotEnterTheExportedCanvas() throws {
        let canvas = try source("VictoryFairy/Features/Share/ShareCardPreviewView.swift")
        XCTAssertFalse(canvas.contains("VFFairy"))
        XCTAssertFalse(canvas.contains("FairyGlyph"))
    }

    func testM28_qrAndDeepLinkCannotEnterTheCardModel() throws {
        let model = try source("VictoryFairy/Domain/MemoryShareCard.swift")
        for forbidden in ["officialRecordURL", "linkedKBOGameID", "QR", "deepLink"] {
            XCTAssertFalse(model.contains(forbidden), forbidden)
        }
    }

    func testM29_exportIsExactly1200By1440Pixels() {
        let image = rendered()
        XCTAssertEqual(image?.cgImage?.width, 1200)
        XCTAssertEqual(image?.cgImage?.height, 1440)
    }

    func testM30_exportDataDecodesAsAnImage() {
        guard let data = rendered()?.pngData(), let decoded = UIImage(data: data) else {
            return XCTFail("export PNG를 디코딩하지 못했다")
        }
        XCTAssertEqual(decoded.cgImage?.width, 1200)
        XCTAssertEqual(decoded.cgImage?.height, 1440)
    }

    func testM31_identicalCanonicalInputHasStableContentAndDimensions() {
        let value = log()
        let first = MemoryShareCardContent(log: value)
        let second = MemoryShareCardContent(log: value)
        XCTAssertEqual(first.stableContentFingerprint, second.stableContentFingerprint)
        XCTAssertEqual(rendered(value)?.cgImage?.width, rendered(value)?.cgImage?.width)
        XCTAssertEqual(rendered(value)?.cgImage?.height, rendered(value)?.cgImage?.height)
    }

    func testM32_previewScaleCannotChangeExportDimensions() throws {
        XCTAssertEqual(MemoryShareCardGeometry.logicalSize, CGSize(width: 300, height: 360))
        XCTAssertEqual(MemoryShareCardGeometry.exportScale, 4)
        let source = try source("VictoryFairy/Features/Share/ShareCardPreviewView.swift")
        XCTAssertTrue(source.contains("ScaledMemoryShareCardPreview"))
        XCTAssertTrue(source.contains("renderer.scale = MemoryShareCardGeometry.exportScale"))
    }

    func testM33_nativeShareReceivesTheRenderedCanonicalImage() {
        let expected = onePixelImage()
        let controller = MemoryShareOutputController(renderer: { expected }, saver: { _ in })
        controller.prepareNativeShare()
        XCTAssertTrue(controller.shareImage === expected)
        XCTAssertTrue(controller.isShowingShareSheet)
    }

    func testM34_shareCancellationPerformsNoPersistenceWrite() {
        var saves = 0
        let controller = MemoryShareOutputController(
            renderer: { self.onePixelImage() },
            saver: { _ in saves += 1 }
        )
        controller.prepareNativeShare()
        controller.shareSheetDidDismiss()
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(controller.explicitSaveInvocationCount, 0)
    }

    func testM35_photosSaveOccursOnlyOnExplicitSaveAction() async {
        var saves = 0
        let controller = MemoryShareOutputController(
            renderer: { self.onePixelImage() },
            saver: { _ in saves += 1 }
        )
        controller.prepareNativeShare()
        controller.shareSheetDidDismiss()
        XCTAssertEqual(saves, 0)
        await controller.saveToPhotos()
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(controller.explicitSaveInvocationCount, 1)
    }

    func testM36_previewDismissalWritesNothing() {
        var saves = 0
        let controller = MemoryShareOutputController(
            renderer: { self.onePixelImage() },
            saver: { _ in saves += 1 }
        )
        controller.previewDidDismiss()
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(controller.explicitSaveInvocationCount, 0)
    }
}
