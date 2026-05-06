import Foundation

enum AttendanceLogMapper {
    static func map(_ dto: AttendanceLogDTO) -> AttendanceLogViewState {
        let date = Date.vfParseServerDate(dto.gameDate)
        let favorite = KBOSeed.team(id: dto.favoriteTeamID)?.shortName ?? "우리팀"
        let opponent = KBOSeed.team(id: dto.opponentTeamID)?.shortName ?? "상대팀"
        let memo = dto.shortMemo ?? "직관 기록"
        return AttendanceLogViewState(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            matchup: "\(favorite) vs \(opponent)",
            stadium: dto.stadiumName,
            result: GameResult(serverValue: dto.result),
            ourScore: dto.ourScore,
            opponentScore: dto.opponentScore,
            seat: dto.seatText ?? "좌석 미정",
            companion: dto.companionType ?? "미입력",
            memo: memo,
            caption: dto.diaryText ?? memo,
            diary: dto.diaryText ?? "",
            tags: dto.moodTags + dto.highlightTags,
            photoLocalRefs: dto.photoLocalRefs,
            gameSource: dto.gameSource,
            linkedKBOGameID: dto.linkedKBOGameID,
            officialRecordURL: dto.officialRecordURL
        )
    }

    static func map(_ dto: FeedItemDTO) -> AttendanceLogViewState {
        let date = Date.vfParseServerDate(dto.gameDate)
        let parsedScore = scorePair(from: dto.scoreText)
        return AttendanceLogViewState(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            matchup: dto.matchupText,
            stadium: dto.stadiumName,
            result: GameResult(serverValue: dto.result),
            ourScore: parsedScore?.0,
            opponentScore: parsedScore?.1,
            seat: "좌석 미정",
            companion: "미입력",
            memo: dto.captionText.isEmpty ? "직관 기록" : dto.captionText,
            caption: dto.captionText,
            diary: dto.hasDiary ? dto.captionText : "",
            tags: dto.moodTags + dto.highlightTags,
            photoLocalRefs: [],
            gameSource: dto.gameSource,
            linkedKBOGameID: dto.linkedKBOGameID,
            officialRecordURL: dto.officialRecordURL
        )
    }

    static func map(_ dto: CalendarDayLogDTO, dateText: String) -> AttendanceLogViewState {
        let date = Date.vfParseServerDate(dateText)
        let parsedScore = scorePair(from: dto.scoreText)
        return AttendanceLogViewState(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            matchup: dto.matchupText,
            stadium: dto.stadiumName,
            result: GameResult(serverValue: dto.result),
            ourScore: parsedScore?.0,
            opponentScore: parsedScore?.1,
            seat: "좌석 미정",
            companion: "미입력",
            memo: dto.shortMemo ?? "직관 기록",
            caption: dto.shortMemo ?? dto.scoreText,
            diary: "",
            tags: [],
            photoLocalRefs: [],
            gameSource: dto.gameSource,
            linkedKBOGameID: dto.linkedKBOGameID,
            officialRecordURL: dto.officialRecordURL
        )
    }

    static func map(_ entity: SwiftDataAttendanceLogEntity) -> AttendanceLogViewState {
        AttendanceLogViewState(
            id: UUID(uuidString: entity.id) ?? UUID(),
            date: entity.gameDate,
            dateText: entity.dateText,
            matchup: entity.matchup,
            stadium: entity.stadiumName,
            result: GameResult(serverValue: entity.resultRawValue),
            ourScore: entity.ourScore,
            opponentScore: entity.opponentScore,
            seat: entity.seatText ?? "좌석 미정",
            companion: entity.companionType ?? "미입력",
            memo: entity.shortMemo ?? "직관 기록",
            caption: entity.diaryText ?? entity.shortMemo ?? "직관 기록",
            diary: entity.diaryText ?? "",
            tags: entity.moodTags + entity.highlightTags,
            photoLocalRefs: entity.photoLocalRefs,
            gameSource: entity.gameSource,
            linkedKBOGameID: entity.linkedKBOGameID,
            officialRecordURL: entity.officialRecordURL
        )
    }

    static func entity(from request: CreateAttendanceLogRequest) -> SwiftDataAttendanceLogEntity {
        let date = Date.vfParseServerDate(request.gameDate)
        return SwiftDataAttendanceLogEntity(
            gameDate: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            season: request.season,
            favoriteTeamID: request.favoriteTeamID,
            opponentTeamID: request.opponentTeamID,
            matchup: matchup(favoriteTeamID: request.favoriteTeamID, opponentTeamID: request.opponentTeamID),
            stadiumName: request.stadiumName,
            resultRawValue: request.result,
            ourScore: request.ourScore,
            opponentScore: request.opponentScore,
            seatText: request.seatText,
            companionType: request.companionType,
            shortMemo: request.shortMemo,
            diaryText: request.diaryText,
            moodTags: request.moodTags,
            highlightTags: request.highlightTags,
            photoLocalRefs: request.photoLocalRefs,
            gameSource: request.gameSource,
            linkedKBOGameID: request.linkedKBOGameID,
            officialRecordURL: request.officialRecordURL
        )
    }

    static func update(_ entity: SwiftDataAttendanceLogEntity, request: UpdateAttendanceLogRequest) {
        let date = Date.vfParseServerDate(request.gameDate)
        entity.gameDate = date
        entity.dateText = DateFormatter.vfDisplayDate.string(from: date)
        entity.season = request.season
        entity.favoriteTeamID = request.favoriteTeamID
        entity.opponentTeamID = request.opponentTeamID
        entity.matchup = matchup(favoriteTeamID: request.favoriteTeamID, opponentTeamID: request.opponentTeamID)
        entity.stadiumName = request.stadiumName
        entity.resultRawValue = request.result
        entity.ourScore = request.ourScore
        entity.opponentScore = request.opponentScore
        entity.seatText = request.seatText
        entity.companionType = request.companionType
        entity.shortMemo = request.shortMemo
        entity.diaryText = request.diaryText
        entity.moodTagsStorage = SwiftDataAttendanceLogEntity.encode(request.moodTags)
        entity.highlightTagsStorage = SwiftDataAttendanceLogEntity.encode(request.highlightTags)
        entity.photoLocalRefsStorage = SwiftDataAttendanceLogEntity.encode(request.photoLocalRefs)
        entity.gameSource = request.gameSource
        entity.linkedKBOGameID = request.linkedKBOGameID
        entity.officialRecordURL = request.officialRecordURL
        entity.syncStateRawValue = "pending"
        entity.updatedAt = .now
    }

    private static func matchup(favoriteTeamID: String, opponentTeamID: String) -> String {
        let favorite = KBOSeed.team(id: favoriteTeamID)?.shortName ?? "우리팀"
        let opponent = KBOSeed.team(id: opponentTeamID)?.shortName ?? "상대팀"
        return "\(favorite) vs \(opponent)"
    }

    private static func scorePair(from text: String) -> (Int, Int)? {
        let pattern = #"(\d{1,2})\s*[:：]\s*(\d{1,2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let firstRange = Range(match.range(at: 1), in: text),
              let secondRange = Range(match.range(at: 2), in: text),
              let first = Int(text[firstRange]),
              let second = Int(text[secondRange]) else {
            return nil
        }
        return (first, second)
    }
}
