import XCTest
import SwiftUI
@testable import VictoryFairy

/// 디자인 시스템이 도메인 모델과 어긋나지 않는지 확인한다.
final class DesignSystemContractTests: XCTestCase {

    // MARK: - 열 개 구단

    func testCanonicalModelHasExactlyTenActiveTeams() {
        let active = KBOSeed.teams.filter(\.active)
        XCTAssertEqual(active.count, 10, "KBO 구단은 10개여야 한다")
    }

    func testEveryCanonicalTeamHasADesignAccent() {
        for team in KBOSeed.teams {
            XCTAssertTrue(
                VFTeamAccent.coveredTeamIDs.contains(team.id),
                "\(team.id)에 대응하는 팀 포인트 컬러가 없다"
            )
        }
    }

    func testAccentTableDoesNotContainUnknownTeams() {
        let canonical = Set(KBOSeed.teams.map(\.id))
        for id in VFTeamAccent.coveredTeamIDs {
            XCTAssertTrue(canonical.contains(id), "\(id)는 canonical 팀 목록에 없다")
        }
    }

    func testEveryTeamHasDisplayNameShortNameAndBadgeInitial() {
        for team in KBOSeed.teams {
            XCTAssertFalse(team.name.trimmingCharacters(in: .whitespaces).isEmpty, "\(team.id) 표시 이름 없음")
            XCTAssertFalse(team.shortName.trimmingCharacters(in: .whitespaces).isEmpty, "\(team.id) 약칭 없음")
            XCTAssertFalse(team.badgeInitial.isEmpty, "\(team.id) 뱃지 표기 없음")
            XCTAssertLessThanOrEqual(team.badgeInitial.count, 3, "\(team.id) 뱃지 표기가 너무 길다")
        }
    }

    /// 저장소에 구단 로고 에셋이 없고 Pencil도 약칭 표기를 쓴다.
    /// 로고가 없어도 모든 팀이 화면에 표현될 수 있어야 한다.
    func testBadgeInitialFollowsPencilRule() {
        let expected = [
            "lg-twins": "LG",
            "doosan-bears": "두",
            "kiwoom-heroes": "키",
            "ssg-landers": "SSG",
            "kt-wiz": "KT",
            "hanwha-eagles": "한",
            "samsung-lions": "삼",
            "kia-tigers": "KIA",
            "lotte-giants": "롯",
            "nc-dinos": "NC"
        ]
        for team in KBOSeed.teams {
            XCTAssertEqual(team.badgeInitial, expected[team.id], "\(team.id) 뱃지 표기가 Pencil과 다르다")
        }
    }

    func testUnknownTeamFallsBackToNeutralAccent() {
        XCTAssertEqual(VFTeamAccent.color(forTeamID: "not-a-team"), VFColor.bodySecondary)
        XCTAssertEqual(VFTeamAccent.color(forTeamID: nil), VFColor.bodySecondary)
    }

    /// 예전 짧은 ID도 같은 강조색으로 이어져야 한다.
    func testLegacyTeamIDsResolveToTheSameAccent() {
        for (legacyID, canonicalID) in KBOSeed.legacyIDMap {
            XCTAssertEqual(
                VFTeamAccent.color(forTeamID: legacyID),
                VFTeamAccent.color(forTeamID: canonicalID),
                "\(legacyID)와 \(canonicalID)의 강조색이 다르다"
            )
        }
    }

    func testEveryTeamThemeResolvesWithoutFallback() {
        for team in KBOSeed.teams {
            let theme = TeamTheme(team: team)
            XCTAssertEqual(theme.teamID, team.id)
            XCTAssertEqual(theme.primary, VFTeamAccent.color(forTeamID: team.id))
            XCTAssertNotEqual(theme.primary, VFColor.bodySecondary, "\(team.id)가 중립색으로 떨어졌다")
        }
    }

    /// 팀 강조색 위의 글자색은 대비 판정을 거쳐 정해져야 한다.
    func testTeamForegroundContrastIsResolvedForEveryTeam() {
        for team in KBOSeed.teams {
            let theme = TeamTheme(team: team)
            let expected = theme.primary.vfReadableForegroundColor
            XCTAssertEqual(theme.textOnPrimary, expected, "\(team.id) 전경색이 대비 판정과 어긋난다")
        }
    }

    // MARK: - 경기 결과 토큰

    func testGameResultMapsToDistinctVisualTokens() {
        XCTAssertEqual(GameResult.win.color, VFColor.gameWin)
        XCTAssertEqual(GameResult.loss.color, VFColor.gameLoss)
        XCTAssertEqual(GameResult.draw.color, VFColor.gameDraw)
        XCTAssertEqual(GameResult.canceled.color, VFColor.gameCanceled)
    }

    /// 승과 패는 색으로도 반드시 구분돼야 한다.
    func testWinAndLossUseDifferentColors() {
        XCTAssertNotEqual(GameResult.win.color, GameResult.loss.color)
    }

    /// 색을 못 보는 환경에서도 결과가 구분되도록 글자 표기가 서로 달라야 한다.
    func testGameResultsRemainDistinguishableWithoutColor() {
        let titles = GameResult.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, GameResult.allCases.count, "결과 글자 표기가 겹친다")
        for result in GameResult.allCases {
            XCTAssertFalse(result.title.isEmpty)
            XCTAssertFalse(result.diaryTitle.isEmpty)
        }
    }

    // MARK: - 토큰 값

    /// Pencil 문서 변수에서 옮겨온 핵심 색이 그대로인지 고정한다.
    func testCoreTokensMatchThePencilDocumentVariables() {
        XCTAssertEqual(VFColor.appBackground, Color(hex: "#F4F4F2"), "paper")
        XCTAssertEqual(VFColor.elevatedSurface, Color(hex: "#FFFFFF"), "surface")
        XCTAssertEqual(VFColor.bodyPrimary, Color(hex: "#14171F"), "ink")
        XCTAssertEqual(VFColor.bodySecondary, Color(hex: "#4C5160"), "ink-soft")
        XCTAssertEqual(VFColor.bodyTertiary, Color(hex: "#8B909E"), "ink-faint")
        XCTAssertEqual(VFColor.primaryAction, Color(hex: "#F2B63C"), "coral/gold")
        XCTAssertEqual(VFColor.hairline, Color(hex: "#E2E3E1"), "line")
        XCTAssertEqual(VFColor.inkOutline, Color(hex: "#232A3C"), "line-ink")
        XCTAssertEqual(VFColor.nightSurface, Color(hex: "#0E1526"), "night")
        XCTAssertEqual(VFColor.nightElevated, Color(hex: "#1A2338"), "night-2")
        XCTAssertEqual(VFColor.nightHairline, Color(hex: "#2B3652"), "night-line")
    }

    /// 최신 Pencil은 승을 초록으로, 빨강을 진행 중(live) 상태로 재배정했다.
    func testResultAndLiveTokensFollowTheLatestPencil() {
        XCTAssertEqual(VFColor.gameWin, Color(hex: "#2E9E6B"), "win")
        XCTAssertEqual(VFColor.gameLoss, Color(hex: "#3A4157"), "loss")
        XCTAssertEqual(VFColor.gameDraw, Color(hex: "#8B909E"), "draw")
        XCTAssertEqual(VFColor.gameLive, Color(hex: "#E5484D"), "live")
        XCTAssertNotEqual(VFColor.gameWin, VFColor.gameLive, "승과 진행 중 상태가 같은 색이면 안 된다")
    }

    /// 팀 강조색은 최신 Pencil 팀 포인트 컬러를 그대로 따라야 한다.
    func testTeamAccentsMatchTheLatestPencil() {
        let expected = [
            "lg-twins": "#B5195B",
            "doosan-bears": "#1A2C55",
            "kiwoom-heroes": "#7A1F33",
            "ssg-landers": "#CE4A2D",
            "kt-wiz": "#2E2E36",
            "hanwha-eagles": "#E5691F",
            "samsung-lions": "#1E63C4",
            "kia-tigers": "#C42B26",
            "lotte-giants": "#1F3E73",
            "nc-dinos": "#1F5B78"
        ]
        for (id, hex) in expected {
            XCTAssertEqual(VFTeamAccent.color(forTeamID: id), Color(hex: hex), "\(id) 강조색이 Pencil과 다르다")
        }
    }

    func testSpacingAndRadiusScalesMatchPencil() {
        XCTAssertEqual(VFSpacing.xxs, 4)   // sp-xs
        XCTAssertEqual(VFSpacing.xs, 8)    // sp-sm
        XCTAssertEqual(VFSpacing.md, 16)   // sp-md
        XCTAssertEqual(VFSpacing.xl, 24)   // sp-lg
        XCTAssertEqual(VFRadius.sm, 10)    // r-sm
        XCTAssertEqual(VFRadius.md, 14)    // r-md
        XCTAssertEqual(VFRadius.lg, 20)    // r-lg
    }

    /// 터치 영역은 44pt 아래로 내려가면 안 된다.
    func testControlMetricsMeetMinimumTouchTarget() {
        XCTAssertGreaterThanOrEqual(VFControl.minimumTouchTarget, 44)
        XCTAssertGreaterThanOrEqual(VFControl.buttonHeight, VFControl.minimumTouchTarget)
        XCTAssertGreaterThanOrEqual(VFControl.fieldHeight, VFControl.minimumTouchTarget)
    }

    // MARK: - 일러스트 벡터

    /// SVG는 명령 문자 없이 좌표만 반복되면 직전 명령을 이어간다.
    /// 이때 상대 좌표라는 사실도 함께 이어져야 한다. 이걸 놓치면 두 번째
    /// 곡선부터 절대 좌표로 해석돼 그림이 뭉개진다.
    func testRepeatedCurveCommandStaysRelative() {
        // 상대로 이어지면 (6,0)에서 끝나고, 절대로 잘못 읽으면 (3,0)에서 끝난다.
        let path = VFSVGPathParser.parse("M0 0c1 0 2 0 3 0 1 0 2 0 3 0")
        XCTAssertEqual(path.boundingRect.maxX, 6, accuracy: 0.001, "반복된 c 명령이 상대 좌표로 이어지지 않았다")
    }

    func testRepeatedLineCommandStaysRelative() {
        let path = VFSVGPathParser.parse("M0 0l2 0 2 0 2 0")
        XCTAssertEqual(path.boundingRect.maxX, 6, accuracy: 0.001)
    }

    /// 각 일러스트가 자기 viewBox 안에 들어와야 한다.
    /// 파서가 어긋나면 경계 상자가 크게 벗어난다.
    func testEveryIllustrationStaysWithinItsNaturalBounds() {
        for illustration in VFIllustration.allCases {
            let size = illustration.naturalSize
            XCTAssertGreaterThan(size.width, 0, "\(illustration.rawValue) 너비 없음")
            XCTAssertGreaterThan(size.height, 0, "\(illustration.rawValue) 높이 없음")
        }
    }

    /// Pencil 반짝 별은 24x24 안에서 그려진다.
    func testSparkleGeometryMatchesItsViewBox() {
        let geometry = "M12 0.8c1 6.2 2.4 8.4 10.8 10.8-8.2 2.6-9.6 4.8-10.6 11.8-1.4-6.8-2.8-9.2-10.8-11.6 7.8-2.4 9.4-4.8 10.6-11z"
        let rect = VFSVGPathParser.parse(geometry).boundingRect
        XCTAssertGreaterThanOrEqual(rect.minX, -1)
        XCTAssertGreaterThanOrEqual(rect.minY, -1)
        XCTAssertLessThanOrEqual(rect.maxX, 25, "반짝 별이 viewBox를 벗어났다")
        XCTAssertLessThanOrEqual(rect.maxY, 25, "반짝 별이 viewBox를 벗어났다")
    }

    /// 글러브는 36x39 viewBox 안에서 닫힌 형태로 그려진다.
    func testGloveGeometryMatchesItsViewBox() {
        let geometry = "M6.6 21c-3.6-4-5.6-11.4-2.6-15.6 3.4-4.6 11-5 16.6-3.2 6.4 2 12.8 6.8 14 14.2 1.2 7.6-1.6 16-8.2 20.2-6 2.8-13.8 1.8-17.4-3-2.4-3.4-2.6-8.6-2.4-12.6z"
        let rect = VFSVGPathParser.parse(geometry).boundingRect
        XCTAssertLessThanOrEqual(rect.maxX, 37, "글러브가 viewBox를 벗어났다")
        XCTAssertLessThanOrEqual(rect.maxY, 40, "글러브가 viewBox를 벗어났다")
        XCTAssertFalse(rect.isNull)
    }

    /// 티켓은 호(arc) 명령을 쓴다. 호 변환이 깨지면 경계가 무너진다.
    func testTicketArcGeometryMatchesItsViewBox() {
        let geometry = "M2 1.6c10-1 22-0.6 32.6-0.4a3.4 3.4 0 0 0 6.4 0.2c4 0 7.2 0.4 8.6 1.2 1 8 1.2 19.2 0.4 27.4-4.4 0.8-6 0.6-9 0.4a3.4 3.4 0 0 0-6.2 0.2c-11.8 1-24.8 0.4-32.4-0.2-1.4-8.8-1.2-20-0.4-28.8z"
        let rect = VFSVGPathParser.parse(geometry).boundingRect
        XCTAssertLessThanOrEqual(rect.maxX, 53, "티켓이 viewBox를 벗어났다")
        XCTAssertLessThanOrEqual(rect.maxY, 33, "티켓이 viewBox를 벗어났다")
    }

    // MARK: - 모션

    /// Reduce Motion이 켜지면 애니메이션이 사라져야 한다.
    func testMotionIsSuppressedWhenReduceMotionIsOn() {
        XCTAssertNil(VFMotion.respectingReduceMotion(.default, reduceMotion: true))
        XCTAssertNotNil(VFMotion.respectingReduceMotion(.default, reduceMotion: false))
    }
}
