import CoreGraphics
import Foundation

/// Pencil `09_States / jYs0S`를 실제 직관 기록 한 건으로 채운 순수 모델.
///
/// `EXPLICIT_PRODUCT_DECISION: JYS0S_ONE_RECORD_MEMORY_CARD`
///
/// 생성자는 실제 `AttendanceLogViewState`를 필수로 받는다. 선택형 기록, 시즌 값,
/// 샘플 fallback을 표현할 진입점이 없으므로 카드가 서로 다른 엔티티를 섞을 수 없다.
struct MemoryShareCardContent: Equatable {
    let recordID: UUID
    let result: GameResult
    let firstTeamText: String
    let secondTeamText: String
    let matchupText: String
    let scoreText: String
    let matchupAndScoreText: String
    let dateText: String
    let stadiumText: String
    let photoLocalRefs: [String]

    init(log: AttendanceLogViewState) {
        let matchup = log.resolvedMatchup
        let first = Self.teamText(team: matchup.firstTeam, stored: matchup.firstLabel)
        let second = Self.teamText(team: matchup.secondTeam, stored: matchup.secondLabel)
        let readableMatchup = second == Self.missingTeamText ? first : "\(first) 대 \(second)"
        let score: String

        if log.result == .canceled {
            score = "경기 취소"
        } else if let firstScore = log.ourScore, let secondScore = log.opponentScore {
            score = "\(firstScore) : \(secondScore)"
        } else {
            score = "점수 미기록"
        }

        recordID = log.id
        result = log.result
        firstTeamText = first
        secondTeamText = second
        matchupText = readableMatchup
        scoreText = score
        if log.result != .canceled,
           let firstScore = log.ourScore,
           let secondScore = log.opponentScore,
           second != Self.missingTeamText {
            matchupAndScoreText = "\(first) \(firstScore) : \(secondScore) \(second)"
        } else {
            matchupAndScoreText = "\(readableMatchup) · \(score)"
        }
        // 표시용 문자열이 아니라 기록이 소유한 Date에서 다시 만든다.
        dateText = DateFormatter.vfDisplayDate.string(from: log.date)
        let storedStadium = log.stadium.trimmingCharacters(in: .whitespacesAndNewlines)
        stadiumText = KBOStadiumSeed.stadium(named: storedStadium)?.shortName
            ?? (storedStadium.isEmpty ? "구장 미기록" : storedStadium)
        photoLocalRefs = log.photoLocalRefs
    }

    var resultText: String { result.diaryTitle }

    var metadataText: String { "\(dateText) · \(stadiumText)" }

    /// 이미지 전체는 자식별로 읽지 않고 이 한 문장으로 설명한다.
    var accessibilitySummary: String {
        "\(resultText), \(matchupText), \(scoreText), \(dateText), \(stadiumText)"
    }

    /// 같은 canonical 입력이 같은 표시 내용을 만드는지 검증하는 안정 문자열.
    var stableContentFingerprint: String {
        [recordID.uuidString, result.rawValue, firstTeamText, secondTeamText, scoreText,
         dateText, stadiumText, photoLocalRefs.joined(separator: "|")]
            .joined(separator: "\n")
    }

    private static let missingTeamText = "팀 미기록"

    private static func teamText(team: KBOTeam?, stored: String) -> String {
        if let team { return team.shortName }
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? missingTeamText : trimmed
    }
}

enum MemoryShareCardGeometry {
    /// `EXPLICIT_PRODUCT_DECISION: MEMORY_CARD_EXPORT_1200x1440_5x6`
    static let logicalSize = CGSize(width: 300, height: 360)
    static let exportScale: CGFloat = 4
    static let pixelSize = CGSize(width: 1200, height: 1440)
    static let aspectRatio: CGFloat = 5 / 6
}
