import XCTest
import SwiftUI
@testable import VictoryFairy

/// 피드가 최신 Pencil 프레임 구성과 결정적 그룹·정렬을 실제로 구현했는지 확인한다.
final class FeedTests: XCTestCase {

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repositoryRoot.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - 프레임 구성

    /// Pencil 05_Feed_RecordList가 쓰는 구성 요소가 실제로 있어야 한다.
    func testFeedUsesThePencilFrameComponents() throws {
        let feed = try source("VictoryFairy/Features/Feed/FeedViews.swift")
        for component in ["VFRecordCard", "VFMonthDivider", "VFChip", "VFProminentIconButton"] {
            XCTAssertTrue(feed.contains(component), "피드가 \(component)를 쓰지 않는다")
        }
        // 상태 패널도 공용 컴포넌트를 써야 한다.
        XCTAssertTrue(feed.contains("VFLoadingPanel"), "피드에 로딩 패널이 없다")
        XCTAssertTrue(feed.contains("VFErrorPanel"), "피드에 오류 패널이 없다")
        XCTAssertTrue(feed.contains("VFEmptyStatePanel"), "피드에 빈 상태 패널이 없다")
    }

    /// Pencil 표본 기록이 제품 코드로 새면 안 된다.
    func testFeedDoesNotHardcodePencilSampleRecords() throws {
        let samples = ["9회말 역전", "엄마랑", "치킨은 맛있었다", "개막 2연전 스윕", "3루 원정석"]
        for path in [
            "VictoryFairy/Features/Feed/FeedViews.swift",
            "VictoryFairy/SharedComponents/VFRecordComponents.swift"
        ] {
            let text = try source(path)
            let production = text.components(separatedBy: "#Preview").first ?? text
            for sample in samples {
                XCTAssertFalse(production.contains(sample), "\(path)에 Pencil 표본 '\(sample)'이 있다")
            }
        }
    }

    /// 피드는 전적을 직접 세지 않고 이미 집계된 통계를 읽어야 한다.
    func testFeedDoesNotCountRecordsInline() throws {
        let feed = try source("VictoryFairy/Features/Feed/FeedViews.swift")
        XCTAssertFalse(feed.contains("StatisticsService("), "피드가 통계 서비스를 직접 만든다")
        XCTAssertFalse(feed.contains("logs.filter { $0.result =="), "피드가 전적을 직접 센다")
    }

    // MARK: - 그룹과 정렬

    func testSectionsAreGroupedByMonthAndSortedNewestFirst() {
        let sections = FeedViewModel.monthSections(from: [
            log(seed: 1, year: 2026, month: 3, day: 28),
            log(seed: 2, year: 2026, month: 4, day: 1),
            log(seed: 3, year: 2026, month: 4, day: 12)
        ])
        XCTAssertEqual(sections.map(\.id), ["2026-04", "2026-03"])
        XCTAssertEqual(sections.first?.title, "4월")
        XCTAssertEqual(sections.first?.romanTitle, "APRIL")
        XCTAssertEqual(sections.first?.logs.count, 2)
        XCTAssertEqual(day(sections.first?.logs.first), 12, "월 안에서 최신이 먼저 와야 한다")
    }

    /// 연도 경계를 넘어도 최신 연도가 먼저 와야 한다.
    func testYearBoundaryOrdersNewestFirst() {
        let sections = FeedViewModel.monthSections(from: [
            log(seed: 1, year: 2025, month: 10, day: 30),
            log(seed: 2, year: 2026, month: 3, day: 28)
        ])
        XCTAssertEqual(sections.map(\.id), ["2026-03", "2025-10"])
    }

    /// 같은 날 기록이 여럿이면 순서가 매번 같아야 한다.
    func testSameDayRecordsHaveStableOrdering() {
        let inputs = [log(seed: 9, year: 2026, month: 4, day: 12),
                      log(seed: 2, year: 2026, month: 4, day: 12)]
        let first = FeedViewModel.monthSections(from: inputs).first?.logs.map(\.id)
        let second = FeedViewModel.monthSections(from: inputs.reversed()).first?.logs.map(\.id)
        XCTAssertEqual(first, second, "입력 순서가 달라지면 결과 순서도 달라진다")
        XCTAssertEqual(first?.count, 2)
    }

    func testEmptyInputProducesNoSections() {
        XCTAssertTrue(FeedViewModel.monthSections(from: []).isEmpty)
    }

    /// 월 라벨은 미리 만든 문자열이 아니라 날짜에서 유도돼야 한다.
    /// 표시용 `dateText`가 엉뚱해도 그룹은 실제 날짜를 따른다.
    func testGroupingUsesSemanticDateNotDisplayString() {
        var misleading = log(seed: 1, year: 2026, month: 4, day: 12)
        misleading = AttendanceLogViewState(
            id: misleading.id, date: misleading.date, dateText: "1999.01.01",
            matchup: misleading.matchup, stadium: misleading.stadium, result: misleading.result,
            ourScore: nil, opponentScore: nil, seat: "", companion: "", memo: "", caption: "",
            diary: "", tags: [], photoLocalRefs: []
        )
        XCTAssertEqual(FeedViewModel.monthSections(from: [misleading]).first?.id, "2026-04")
    }

    /// 영문 월 라벨은 기기 언어와 무관하게 고정돼야 한다.
    func testRomanMonthLabelIsLocaleIndependent() {
        XCTAssertEqual(DateFormatter.vfFeedMonthRoman.locale.identifier, "en_US_POSIX")
        XCTAssertEqual(DateFormatter.vfFeedMonthRoman.timeZone.identifier, "Asia/Seoul")
    }

    // MARK: - 요약 문구

    func testSummaryUsesRealCountsAndNeverInventsThem() {
        let model = FeedViewModel(logs: [log(seed: 1, year: 2026, month: 4, day: 1)])
        XCTAssertEqual(
            model.summaryText(seasonLabel: "2026 시즌", recordText: "5승 2패 1무"),
            "2026 시즌 · 1개의 기록 · 5승 2패 1무"
        )
        // 전적이 없으면 그 부분을 지어내지 않고 뺀다.
        XCTAssertEqual(model.summaryText(seasonLabel: "2026 시즌", recordText: nil), "2026 시즌 · 1개의 기록")
        XCTAssertEqual(FeedViewModel(logs: []).summaryText(seasonLabel: "2026 시즌", recordText: nil), "아직 기록이 없어요")
    }

    // MARK: - 필터

    /// 필터 정체성은 한국어 표시 문구가 아니라 안정적인 rawValue여야 한다.
    func testFilterIdentityIsSemanticNotDisplayCopy() {
        XCTAssertEqual(
            FeedResultFilter.allCases.map(\.rawValue),
            ["all", "win", "loss", "draw", "canceled"]
        )
        for filter in FeedResultFilter.allCases {
            XCTAssertFalse(filter.title.isEmpty, "\(filter.rawValue) 표시 문구가 없다")
            XCTAssertNotEqual(filter.rawValue, filter.title, "표시 문구가 정체성으로 쓰이고 있다")
        }
    }

    func testFilterMapsToTheCorrectGameResult() {
        XCTAssertNil(FeedResultFilter.all.result)
        XCTAssertEqual(FeedResultFilter.win.result, .win)
        XCTAssertEqual(FeedResultFilter.loss.result, .loss)
        XCTAssertEqual(FeedResultFilter.draw.result, .draw)
        XCTAssertEqual(FeedResultFilter.canceled.result, .canceled)
    }

    // MARK: - 팀과 구장

    /// 열 팀 모두 피드 카드의 매치업으로 풀려야 한다.
    func testEveryTeamResolvesInFeedMatchup() {
        for team in KBOSeed.teams {
            let matchup = AttendanceMatchup.resolve(from: "\(team.shortName) vs LG")
            XCTAssertNotNil(matchup.firstTeam, "\(team.id) 매치업 해석 실패")
            XCTAssertNotEqual(team.accentColor, VFColor.bodySecondary, "\(team.id) 강조색 없음")
        }
    }

    /// 아홉 구장 모두 카드에서 canonical 구장으로 이어져야 한다.
    func testEveryStadiumResolvesInFeedCard() {
        for stadium in KBOStadiumSeed.all {
            let entry = log(seed: 1, year: 2026, month: 4, day: 1, stadium: stadium.name)
            XCTAssertEqual(entry.recordStadium?.id, stadium.id, "\(stadium.name) 매핑 실패")
        }
    }

    /// 카드가 보여주는 구장은 기록의 구장이지 사용자의 주 관람 구장이 아니다.
    @MainActor
    func testFeedCardShowsRecordStadiumNotPrimaryStadium() {
        let preferences = UserPreferencesStore.preview(
            suiteName: "FeedTests.stadium",
            favoriteTeamID: "samsung-lions",
            primaryStadiumID: "daegu-lions"
        )
        let away = log(seed: 1, year: 2026, month: 4, day: 12, stadium: "잠실야구장")
        XCTAssertEqual(preferences.primaryStadium?.id, "daegu-lions")
        XCTAssertEqual(away.recordStadium?.id, "jamsil")
        XCTAssertNotEqual(preferences.primaryStadium?.id, away.recordStadium?.id)
    }

    // MARK: - 픽스처 경계

    /// UI 테스트 픽스처는 Release에서 존재조차 하지 않아야 한다.
    func testFixturesAreDebugOnly() throws {
        let fixtures = try source("VictoryFairy/Services/VFFeedFixtures.swift")
        XCTAssertTrue(fixtures.hasPrefix("#if DEBUG"), "픽스처 파일이 DEBUG로 감싸여 있지 않다")
        XCTAssertTrue(fixtures.hasSuffix("#endif\n"), "픽스처 파일이 DEBUG로 닫히지 않았다")

        let config = try source("VictoryFairy/Services/VFUITestConfiguration.swift")
        XCTAssertTrue(config.contains("#if DEBUG"), "픽스처 진입점이 DEBUG로 감싸여 있지 않다")
        // 픽스처 진입점은 반드시 인자를 그대로 돌려주는 기본 경로를 가져야 한다.
        XCTAssertTrue(config.contains("return production"), "Release 경로가 실제 데이터를 돌려주지 않는다")
    }

    /// 픽스처는 결정적이어야 한다. 실행 시각이나 무작위 값을 쓰면 안 된다.
    func testFixturesAreDeterministic() throws {
        // 주석에 적힌 설명까지 잡지 않도록 코드 줄만 검사한다.
        let code = try source("VictoryFairy/Services/VFFeedFixtures.swift")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        XCTAssertFalse(code.contains("Date()"), "픽스처가 현재 시각을 쓴다")
        XCTAssertFalse(code.contains(".now"), "픽스처가 현재 시각을 쓴다")
        XCTAssertFalse(code.contains("UUID()"), "픽스처가 무작위 ID를 만든다")

        // 같은 픽스처는 두 번 읽어도 같은 순서와 같은 ID여야 한다.
        let first = VFFeedFixtures.logs(for: .populated).map(\.id)
        let second = VFFeedFixtures.logs(for: .populated).map(\.id)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, first.count, "픽스처 ID가 중복된다")
    }

    /// 픽스처는 사진 **파일**을 만들지 않는다.
    ///
    /// 사진이 있는 기록도 그려 볼 수 있어야 하므로 참조 자체는 둘 수 있다. 다만 그 참조는
    /// 반드시 메모리에서 그리는 종류여야 한다. 실제 파일 경로를 가리키면 저장소에 없는
    /// 파일을 가리키게 되고, 그 순간 픽스처가 흔적을 남기기 시작한다.
    func testFixturePhotoReferencesAreDrawnInMemoryNotStored() {
        for fixture in [VFUITestConfiguration.FeedFixture.populated, .multiMonth, .longContent] {
            for entry in VFFeedFixtures.logs(for: fixture) {
                for ref in entry.photoLocalRefs {
                    XCTAssertTrue(
                        ref.hasPrefix(VFRecordDetailFixtures.inMemoryPhotoPrefix),
                        "픽스처가 저장소의 사진 파일을 가리킨다: \(ref)"
                    )
                    XCTAssertNotNil(
                        VFRecordDetailFixtures.inMemoryImage(for: ref, maxPixel: 320),
                        "메모리 사진을 그릴 수 없다: \(ref)"
                    )
                }
            }
        }
    }

    /// 사진이 있는 기록과 없는 기록이 모두 있어야 두 상태를 다 확인할 수 있다.
    func testPopulatedFixtureHasBothPhotoAndPhotolessRecords() {
        let logs = VFFeedFixtures.logs(for: .populated)
        XCTAssertTrue(logs.contains { !$0.photoLocalRefs.isEmpty }, "사진 있는 기록이 없다")
        XCTAssertTrue(logs.contains { $0.photoLocalRefs.isEmpty }, "사진 없는 기록이 없다")
    }

    /// 픽스처가 실제로 여러 달과 같은 날 기록을 담아야 그룹 검증이 의미를 갖는다.
    func testMultiMonthFixtureSpansMonthsAndYears() {
        let sections = FeedViewModel.monthSections(from: VFFeedFixtures.logs(for: .multiMonth))
        XCTAssertGreaterThanOrEqual(sections.count, 3, "여러 달 픽스처가 달을 충분히 담지 못했다")
        XCTAssertEqual(sections.map(\.id), sections.map(\.id).sorted(by: >), "월 정렬이 내림차순이 아니다")
        XCTAssertTrue(sections.contains { $0.logs.count > 1 }, "같은 달에 두 건 이상인 구간이 없다")
    }

    // MARK: - 도우미

    private func day(_ log: AttendanceLogViewState?) -> Int? {
        guard let log else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.component(.day, from: log.date)
    }

    private func log(
        seed: Int, year: Int, month: Int, day: Int,
        stadium: String = "잠실야구장"
    ) -> AttendanceLogViewState {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 18
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        return AttendanceLogViewState(
            id: UUID(uuidString: String(format: "ABCDEF00-0000-4000-8000-%012d", seed))!,
            date: components.date ?? Date(timeIntervalSince1970: 0),
            dateText: "\(year).\(month).\(day)",
            matchup: "삼성 vs LG",
            stadium: stadium,
            result: .win,
            ourScore: 6,
            opponentScore: 3,
            seat: "",
            companion: "",
            memo: "",
            caption: "",
            diary: "",
            tags: [],
            photoLocalRefs: []
        )
    }
}
