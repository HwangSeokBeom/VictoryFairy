import XCTest
import SwiftUI
@testable import VictoryFairy

/// 홈이 최신 Pencil 프레임 구성을 실제로 구현했는지 확인한다.
/// 토큰만 바뀐 상태와 프레임 단위 구현을 구분하는 것이 목적이다.
final class HomeTests: XCTestCase {

    // MARK: - Pencil 프레임 구성 요소 존재

    /// Pencil 04_Home_Default_TeamSelected가 쓰는 컴포넌트가 실제로 있어야 한다.
    /// 하나라도 없으면 홈은 여전히 토큰만 적용된 상태다.
    func testHomeUsesThePencilFrameComponents() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let home = try String(
            contentsOf: root.appendingPathComponent("VictoryFairy/Features/Home/HomeView.swift"),
            encoding: .utf8
        )
        for component in ["VFTeamIdentityHeader", "VFMatchupHeroCard", "VFSeasonStrip", "VFStadiumGameStrip"] {
            XCTAssertTrue(home.contains(component), "홈이 \(component)를 쓰지 않는다")
        }
    }

    /// Pencil 히어로의 표본 값이 제품 코드에 박히면 안 된다.
    func testHomeDoesNotHardcodePencilSampleValues() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let sources = [
            "VictoryFairy/Features/Home/HomeView.swift",
            "VictoryFairy/SharedComponents/VFHomeComponents.swift"
        ]
        // Pencil 프레임의 표본 문자열들.
        let sampleValues = ["원태인", "네일", "4.16 THU", "18:30", "삼성 6 : 3 LG", "8번"]
        for path in sources {
            let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            let production = text.components(separatedBy: "#Preview").first ?? text
            for sample in sampleValues {
                XCTAssertFalse(
                    production.contains(sample),
                    "\(path) 제품 코드에 Pencil 표본 값 '\(sample)'이 들어 있다"
                )
            }
        }
    }

    /// 홈은 통계를 직접 계산하지 않고 이미 집계된 값을 읽기만 해야 한다.
    func testHomeDoesNotComputeStatisticsInline() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let home = try String(
            contentsOf: root.appendingPathComponent("VictoryFairy/Features/Home/HomeView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(home.contains("StatisticsService("), "홈이 통계 서비스를 직접 만든다")
        XCTAssertFalse(home.contains(".filter { $0.result =="), "홈이 전적을 직접 센다")
    }

    // MARK: - 매치업 해석

    func testMatchupResolvesBothTeamsFromRealRecordText() {
        let matchup = AttendanceMatchup.resolve(from: "삼성 vs KIA")
        XCTAssertEqual(matchup.firstTeam?.id, "samsung-lions")
        XCTAssertEqual(matchup.secondTeam?.id, "kia-tigers")
    }

    /// 응원 팀이 뒤에 적혀 있어도 "내 팀"으로 잡혀야 한다.
    func testMatchupSidesPutFavoriteTeamFirst() {
        let matchup = AttendanceMatchup.resolve(from: "삼성 vs KIA")
        let sides = matchup.sides(favoriteTeamID: "kia-tigers")
        XCTAssertEqual(sides.mine?.id, "kia-tigers")
        XCTAssertEqual(sides.opponent?.id, "samsung-lions")
    }

    func testMatchupKeepsRawLabelWhenTeamIsUnknown() {
        let matchup = AttendanceMatchup.resolve(from: "미지의팀 vs LG")
        XCTAssertNil(matchup.firstTeam)
        XCTAssertEqual(matchup.firstLabel, "미지의팀")
        XCTAssertEqual(matchup.secondTeam?.id, "lg-twins")
    }

    func testMatchupHandlesTextWithoutSeparator() {
        let matchup = AttendanceMatchup.resolve(from: "LG 트윈스")
        XCTAssertEqual(matchup.firstTeam?.id, "lg-twins")
        XCTAssertNil(matchup.secondTeam)
    }

    // MARK: - 팀과 구장을 섞지 않는다

    /// 기록의 구장은 사용자의 주 관람 구장과 별개로 해석돼야 한다.
    @MainActor
    func testRecordStadiumIsNotConflatedWithPrimaryStadium() {
        let preferences = UserPreferencesStore.preview(
            suiteName: "HomeTests.stadiumSeparation",
            favoriteTeamID: "samsung-lions",
            primaryStadiumID: "daegu-lions"
        )
        // 원정 경기: 기록의 구장은 잠실, 사용자의 주 관람 구장은 대구.
        let log = Self.makeLog(matchup: "삼성 vs LG", stadium: "잠실야구장")

        XCTAssertEqual(preferences.primaryStadium?.id, "daegu-lions")
        XCTAssertEqual(log.recordStadium?.id, "jamsil")
        XCTAssertNotEqual(preferences.primaryStadium?.id, log.recordStadium?.id)
    }

    // MARK: - 열 팀 · 아홉 구장 표현

    /// 열 팀 모두 홈 아이덴티티 헤더에 필요한 값을 갖춰야 한다.
    func testEveryTeamHasValidHomeIdentityPresentation() {
        for team in KBOSeed.teams {
            XCTAssertFalse(team.name.isEmpty, "\(team.id) 이름 없음")
            XCTAssertFalse(team.badgeInitial.isEmpty, "\(team.id) 이니셜 없음")
            XCTAssertNotEqual(team.accentColor, VFColor.bodySecondary, "\(team.id) 강조색이 중립으로 떨어졌다")
            // 남색 카드 위에서 쓰는 밝은 변형이 원본과 달라야 대비가 생긴다.
            XCTAssertNotEqual(
                team.accentColor.vfOnDarkVariant, team.accentColor,
                "\(team.id) 어두운 표면용 변형이 만들어지지 않았다"
            )
        }
    }

    /// 아홉 구장 모두 홈 구장 스트립에 쓸 수 있어야 한다.
    func testEveryStadiumHasValidHomePresentation() {
        XCTAssertEqual(KBOStadiumSeed.all.count, 9)
        for stadium in KBOStadiumSeed.all {
            XCTAssertFalse(stadium.name.isEmpty, "\(stadium.id) 이름 없음")
            XCTAssertFalse(stadium.shortName.isEmpty, "\(stadium.id) 짧은 이름 없음")
            XCTAssertFalse(stadium.city.isEmpty, "\(stadium.id) 도시 없음")
        }
    }

    /// 기록에 적힌 구장 이름이 canonical 구장으로 이어져야 한다.
    func testRecordStadiumNameMapsToCanonicalStadium() {
        for stadium in KBOStadiumSeed.all {
            let log = Self.makeLog(matchup: "삼성 vs LG", stadium: stadium.name)
            XCTAssertEqual(log.recordStadium?.id, stadium.id, "\(stadium.name) 매핑 실패")
        }
    }

    // MARK: - 도우미

    private static func makeLog(matchup: String, stadium: String) -> AttendanceLogViewState {
        AttendanceLogViewState(
            id: UUID(),
            date: .now,
            dateText: "2026.04.12",
            matchup: matchup,
            stadium: stadium,
            result: .win,
            ourScore: 6,
            opponentScore: 3,
            seat: "3루 원정석",
            companion: "",
            memo: "",
            caption: "",
            diary: "",
            tags: [],
            photoLocalRefs: []
        )
    }
}
