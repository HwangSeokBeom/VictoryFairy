import Foundation

/// 기록의 `matchup` 문자열("삼성 vs LG")에서 양 팀을 풀어낸다.
///
/// 순수 계산이라 SwiftUI와 SwiftData에 의존하지 않고 그대로 테스트할 수 있다.
/// 새 데이터를 만들지 않고, 이미 저장된 문자열을 canonical 팀으로 옮기기만 한다.
struct AttendanceMatchup: Equatable {
    /// 먼저 적힌 팀. 기록 작성 규칙상 사용자의 응원 팀이 앞에 온다.
    let firstTeam: KBOTeam?
    /// 뒤에 적힌 팀.
    let secondTeam: KBOTeam?
    /// 팀을 찾지 못했을 때 쓸 원본 표기.
    let firstLabel: String
    let secondLabel: String

    private static let separators = [" vs ", " VS ", " 대 ", " : "]

    static func resolve(from matchup: String) -> AttendanceMatchup {
        let trimmed = matchup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = separators.first(where: { trimmed.contains($0) }) else {
            return AttendanceMatchup(
                firstTeam: KBOSeed.team(named: trimmed),
                secondTeam: nil,
                firstLabel: trimmed,
                secondLabel: ""
            )
        }
        let parts = trimmed.components(separatedBy: separator)
        let first = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let second = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        return AttendanceMatchup(
            firstTeam: KBOSeed.team(named: first),
            secondTeam: KBOSeed.team(named: second),
            firstLabel: first,
            secondLabel: second
        )
    }

    /// 사용자의 응원 팀을 기준으로 (내 팀, 상대 팀)을 정한다.
    /// 응원 팀이 문자열에 없으면 적힌 순서를 그대로 쓴다.
    func sides(favoriteTeamID: String?) -> (mine: KBOTeam?, opponent: KBOTeam?) {
        guard let favoriteID = KBOSeed.normalizedTeamID(favoriteTeamID) else {
            return (firstTeam, secondTeam)
        }
        if secondTeam?.id == favoriteID { return (secondTeam, firstTeam) }
        return (firstTeam, secondTeam)
    }
}

extension AttendanceLogViewState {
    var resolvedMatchup: AttendanceMatchup {
        AttendanceMatchup.resolve(from: matchup)
    }

    /// 이 기록이 열린 구장. 사용자의 주 관람 구장과 혼동하면 안 된다.
    var recordStadium: KBOStadium? {
        KBOStadiumSeed.all.first { $0.name == stadium }
    }
}
