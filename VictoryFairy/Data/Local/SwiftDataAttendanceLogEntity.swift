import Foundation
import SwiftData

@Model
final class SwiftDataAttendanceLogEntity {
    @Attribute(.unique) var id: String
    var gameDate: Date
    var dateText: String
    var season: Int
    var favoriteTeamID: String
    var opponentTeamID: String
    var matchup: String
    var stadiumName: String
    var resultRawValue: String
    var ourScore: Int?
    var opponentScore: Int?
    var seatText: String?
    var companionType: String?
    var shortMemo: String?
    var diaryText: String?
    var moodTagsStorage: String
    var highlightTagsStorage: String
    var photoLocalRefsStorage: String
    var gameSource: String?
    var linkedKBOGameID: String?
    var officialRecordURL: String?
    var syncStateRawValue: String = "pending"
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        gameDate: Date,
        dateText: String,
        season: Int,
        favoriteTeamID: String,
        opponentTeamID: String,
        matchup: String,
        stadiumName: String,
        resultRawValue: String,
        ourScore: Int?,
        opponentScore: Int?,
        seatText: String?,
        companionType: String?,
        shortMemo: String?,
        diaryText: String?,
        moodTags: [String],
        highlightTags: [String],
        photoLocalRefs: [String],
        gameSource: String? = nil,
        linkedKBOGameID: String? = nil,
        officialRecordURL: String? = nil,
        syncStateRawValue: String = "pending",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.gameDate = gameDate
        self.dateText = dateText
        self.season = season
        self.favoriteTeamID = favoriteTeamID
        self.opponentTeamID = opponentTeamID
        self.matchup = matchup
        self.stadiumName = stadiumName
        self.resultRawValue = resultRawValue
        self.ourScore = ourScore
        self.opponentScore = opponentScore
        self.seatText = seatText
        self.companionType = companionType
        self.shortMemo = shortMemo
        self.diaryText = diaryText
        self.moodTagsStorage = Self.encode(moodTags)
        self.highlightTagsStorage = Self.encode(highlightTags)
        self.photoLocalRefsStorage = Self.encode(photoLocalRefs)
        self.gameSource = gameSource
        self.linkedKBOGameID = linkedKBOGameID
        self.officialRecordURL = officialRecordURL
        self.syncStateRawValue = syncStateRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var moodTags: [String] { Self.decode(moodTagsStorage) }
    var highlightTags: [String] { Self.decode(highlightTagsStorage) }
    var photoLocalRefs: [String] { Self.decode(photoLocalRefsStorage) }

    static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    static func decode(_ text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }
}
