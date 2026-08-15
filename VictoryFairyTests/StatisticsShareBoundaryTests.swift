import XCTest
@testable import VictoryFairy

/// 09_States 감사에서 발견한 시즌 값 + 샘플 기록 혼합 회귀를 막는다.
final class StatisticsShareBoundaryTests: XCTestCase {
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private var statisticsSource: String {
        get throws {
            try String(
                contentsOf: Self.repositoryRoot
                    .appendingPathComponent("VictoryFairy/Features/Statistics/StatisticsViews.swift"),
                encoding: .utf8
            )
        }
    }

    func testSF01_seasonActionNeverReferencesTheRecordMemoryCard() throws {
        let source = try statisticsSource
        XCTAssertFalse(source.contains("ShareCardPreviewView"))
        XCTAssertFalse(source.contains("MemoryShareCardContent"))
    }

    func testSF02_noSampleRecordCanAppearInAStatisticsSharePreview() throws {
        let source = try statisticsSource
        XCTAssertFalse(source.contains("seasonWinRateText:"))
        XCTAssertFalse(source.contains("isShowingSeasonReport = true"))
    }

    func testSF03_noStatisticsExportPathCanRenderSampleRecordData() throws {
        let source = try statisticsSource
        XCTAssertFalse(source.contains("MemoryShareCardRenderer"))
        XCTAssertFalse(source.contains("ImageRenderer"))
    }

    func testSF04_realSeasonWinRateIsNeverCombinedWithAFakeRecord() throws {
        let source = try statisticsSource
        XCTAssertTrue(source.contains("SEASON_SHARE_REQUIRES_SEPARATE_PRODUCT_DESIGN"))
        XCTAssertTrue(source.contains("isShowingSeasonReportUnavailable = true"))
        XCTAssertFalse(source.contains("archive.record.winRateText)"))
    }
}
