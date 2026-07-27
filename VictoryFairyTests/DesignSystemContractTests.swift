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
        XCTAssertEqual(VFColor.appBackground, Color(hex: "#F8F4EB"), "paper")
        XCTAssertEqual(VFColor.elevatedSurface, Color(hex: "#FFFDF8"), "surface")
        XCTAssertEqual(VFColor.bodyPrimary, Color(hex: "#33302A"), "ink")
        XCTAssertEqual(VFColor.bodySecondary, Color(hex: "#6F6759"), "ink-soft")
        XCTAssertEqual(VFColor.bodyTertiary, Color(hex: "#A59C8C"), "ink-faint")
        XCTAssertEqual(VFColor.primaryAction, Color(hex: "#E0714F"), "coral")
        XCTAssertEqual(VFColor.hairline, Color(hex: "#E4DCCB"), "line")
        XCTAssertEqual(VFColor.inkOutline, Color(hex: "#4A453C"), "line-ink")
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

    // MARK: - 모션

    /// Reduce Motion이 켜지면 애니메이션이 사라져야 한다.
    func testMotionIsSuppressedWhenReduceMotionIsOn() {
        XCTAssertNil(VFMotion.respectingReduceMotion(.default, reduceMotion: true))
        XCTAssertNotNil(VFMotion.respectingReduceMotion(.default, reduceMotion: false))
    }
}
