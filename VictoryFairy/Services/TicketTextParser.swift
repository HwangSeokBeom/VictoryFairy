import Foundation

struct TicketFieldSuggestion: Hashable {
    var gameDate: Date?
    var favoriteTeamName: String?
    var opponentTeamName: String?
    var stadiumName: String?
    var seatText: String?
    var rawText: String

    var hasAnyField: Bool {
        gameDate != nil || favoriteTeamName != nil || opponentTeamName != nil || stadiumName != nil || seatText != nil
    }

    func merged(with remote: TicketParseOCRTextDTO) -> TicketFieldSuggestion {
        TicketFieldSuggestion(
            gameDate: remote.gameDate.map(Date.vfParseServerDate) ?? gameDate,
            favoriteTeamName: normalizedTeamName(remote.favoriteTeamName) ?? favoriteTeamName,
            opponentTeamName: normalizedTeamName(remote.opponentTeamName) ?? opponentTeamName,
            stadiumName: remote.stadiumName ?? stadiumName,
            seatText: remote.seatText ?? seatText,
            rawText: rawText
        )
    }

    private func normalizedTeamName(_ value: String?) -> String? {
        guard let value else { return nil }
        return KBOSeed.team(named: value)?.name ?? value
    }
}

struct TicketTextParser {
    var currentFavoriteTeamName: String?
    var calendar = Calendar(identifier: .gregorian)

    func parse(_ rawText: String) -> TicketFieldSuggestion {
        let normalized = rawText
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "  ", with: " ")
        let teams = detectedTeams(in: normalized)
        let favorite = preferredFavoriteTeam(from: teams)
        let opponent = teams.first { $0 != favorite }

        return TicketFieldSuggestion(
            gameDate: detectedDate(in: normalized),
            favoriteTeamName: favorite,
            opponentTeamName: opponent,
            stadiumName: detectedStadium(in: normalized),
            seatText: detectedSeat(in: normalized),
            rawText: normalized
        )
    }

    private func detectedTeams(in text: String) -> [String] {
        var matches: [String] = []
        for team in KBOSeed.teams {
            let candidates = [team.name, team.shortName]
            if candidates.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
                matches.append(team.name)
            }
        }
        return Array(NSOrderedSet(array: matches)) as? [String] ?? matches
    }

    private func preferredFavoriteTeam(from teams: [String]) -> String? {
        if let currentFavoriteTeamName,
           let matched = teams.first(where: { $0 == currentFavoriteTeamName || KBOSeed.team(named: $0)?.shortName == currentFavoriteTeamName }) {
            return matched
        }
        return teams.first
    }

    private func detectedStadium(in text: String) -> String? {
        let aliases: [(String, [String])] = [
            ("잠실야구장", ["잠실야구장", "잠실"]),
            ("고척스카이돔", ["고척스카이돔", "고척"]),
            ("인천 SSG 랜더스필드", ["인천 SSG 랜더스필드", "문학", "랜더스필드"]),
            ("수원 KT 위즈파크", ["수원 KT 위즈파크", "수원 kt wiz 파크", "수원"]),
            ("대전 한화생명 볼파크", ["대전 한화생명 볼파크", "한화생명 볼파크", "대전"]),
            ("대구 삼성 라이온즈 파크", ["대구 삼성 라이온즈 파크", "라이온즈 파크", "대구"]),
            ("광주 KIA 챔피언스 필드", ["광주 KIA 챔피언스 필드", "광주-기아 챔피언스 필드", "챔피언스 필드", "광주"]),
            ("사직야구장", ["사직야구장", "사직"]),
            ("창원 NC 파크", ["창원NC파크", "창원 NC 파크", "창원"])
        ]
        return aliases.first { _, values in
            values.contains { text.localizedCaseInsensitiveContains($0) }
        }?.0
    }

    private func detectedSeat(in text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let keywords = ["블록", "구역", "열", "번", "좌석", "석", "층"]
        let seatLines = lines.filter { line in
            keywords.contains { line.contains($0) } && line.count <= 40
        }
        return seatLines.prefix(2).joined(separator: " ").nilIfBlank
    }

    private func detectedDate(in text: String) -> Date? {
        let patterns = [
            #"(\d{4})[.\-/년\s]+(\d{1,2})[.\-/월\s]+(\d{1,2})"#,
            #"(\d{1,2})[.\-/월\s]+(\d{1,2})[일]?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            if match.numberOfRanges >= 4,
               let year = int(text, match, 1),
               let month = int(text, match, 2),
               let day = int(text, match, 3) {
                return makeDate(year: year, month: month, day: day)
            }

            if match.numberOfRanges >= 3,
               let month = int(text, match, 1),
               let day = int(text, match, 2) {
                let year = calendar.component(.year, from: .now)
                return makeDate(year: year, month: month, day: day)
            }
        }
        return nil
    }

    private func int(_ text: String, _ match: NSTextCheckingResult, _ index: Int) -> Int? {
        guard let range = Range(match.range(at: index), in: text) else { return nil }
        return Int(text[range])
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.year = year
        components.month = month
        components.day = day
        return components.date
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
