import Foundation

/// KBO 정규 시즌 홈 구장.
///
/// 이름은 `KBOSeed.teams`의 `homeStadiumName`에서 그대로 가져온다. 구장 목록을
/// 따로 적어두지 않고 팀 데이터에서 유도하므로, 이름이 바뀌면 한곳만 고치면 된다.
/// 여기서 관리하는 것은 화면과 저장소가 함께 쓰는 **안정적인 식별자**뿐이다.
struct KBOStadium: Identifiable, Hashable {
    /// 안정적인 의미 기반 ID. 사용자에게 보이는 한국어 이름을 저장하지 않는다.
    let id: String
    /// 표시 이름. `KBOTeam.homeStadiumName`과 같은 문자열이다.
    let name: String
    /// 좁은 자리에서 쓰는 짧은 이름.
    let shortName: String
    /// 이 구장을 홈으로 쓰는 팀 ID. 잠실은 두 팀이 함께 쓴다.
    let homeTeamIDs: [String]

    /// 홈으로 쓰는 팀들의 도시. 모두 같은 도시다.
    var city: String {
        KBOSeed.team(id: homeTeamIDs.first)?.city ?? ""
    }
}

enum KBOStadiumSeed {
    /// 표시 이름 -> 안정적인 ID. 이 표가 구장 식별자의 유일한 출처다.
    private static let idByName: [String: String] = [
        "잠실야구장": "jamsil",
        "고척스카이돔": "gocheok",
        "인천 SSG 랜더스필드": "incheon-ssg",
        "수원 kt wiz 파크": "suwon-kt",
        "대전 한화생명 볼파크": "daejeon-hanwha",
        "대구 삼성 라이온즈 파크": "daegu-lions",
        "광주-기아 챔피언스 필드": "gwangju-kia",
        "사직야구장": "sajik",
        "창원NC파크": "changwon-nc"
    ]

    /// 좁은 자리에서 쓰는 짧은 이름.
    private static let shortNameByID: [String: String] = [
        "jamsil": "잠실",
        "gocheok": "고척돔",
        "incheon-ssg": "인천",
        "suwon-kt": "수원",
        "daejeon-hanwha": "대전",
        "daegu-lions": "대구",
        "gwangju-kia": "광주",
        "sajik": "사직",
        "changwon-nc": "창원"
    ]

    /// 활동 중인 팀들의 홈 구장을 모아 만든 목록.
    /// 팀 데이터가 유일한 출처이므로 구장 이름이 두 곳에 존재하지 않는다.
    static let all: [KBOStadium] = {
        var order: [String] = []
        var teamsByStadiumID: [String: [String]] = [:]
        var nameByID: [String: String] = [:]

        for team in KBOSeed.teams where team.active {
            guard let id = idByName[team.homeStadiumName] else { continue }
            if teamsByStadiumID[id] == nil {
                order.append(id)
                nameByID[id] = team.homeStadiumName
            }
            teamsByStadiumID[id, default: []].append(team.id)
        }

        return order.map { id in
            KBOStadium(
                id: id,
                name: nameByID[id] ?? id,
                shortName: shortNameByID[id] ?? nameByID[id] ?? id,
                homeTeamIDs: teamsByStadiumID[id] ?? []
            )
        }
    }()

    static func stadium(id: String?) -> KBOStadium? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// 팀의 홈 구장. 온보딩에서 추천 구장을 맨 앞에 놓을 때 쓴다.
    /// 추천일 뿐이며 자동으로 선택되지는 않는다.
    static func recommendedStadium(forTeamID teamID: String?) -> KBOStadium? {
        guard let normalized = KBOSeed.normalizedTeamID(teamID),
              let team = KBOSeed.team(id: normalized),
              let id = idByName[team.homeStadiumName] else {
            return nil
        }
        return stadium(id: id)
    }

    /// 추천 구장을 맨 앞에 두고 나머지를 뒤에 붙인 목록.
    /// 추천이 없으면 기본 순서를 그대로 돌려준다.
    static func ordered(recommendedFor teamID: String?) -> [KBOStadium] {
        guard let recommended = recommendedStadium(forTeamID: teamID) else { return all }
        return [recommended] + all.filter { $0.id != recommended.id }
    }

    /// 저장된 값이 여전히 유효한 구장인지 확인한다.
    static func isValid(id: String?) -> Bool {
        stadium(id: id) != nil
    }
}
