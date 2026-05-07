import Foundation

struct LocalCommunityStore {
    private enum Key {
        static let posts = "localCommunityPosts"
        static let blockedAuthorIDs = "localCommunityBlockedAuthorIDs"
        static let reportedPostIDs = "localCommunityReportedPostIDs"
    }

    private struct LocalPost: Codable {
        let id: String
        let authorID: String
        let authorDisplayName: String
        let authorProfileEmoji: String
        let teamID: String?
        let teamName: String?
        let body: String
        let createdAt: String
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPosts() -> [CommunityPostDTO] {
        let blockedIDs = blockedAuthorIDs()
        return storedPosts()
            .filter { !blockedIDs.contains($0.authorID) }
            .map { post in
                CommunityPostDTO(
                    id: post.id,
                    authorID: post.authorID,
                    authorDisplayName: post.authorDisplayName,
                    authorProfileEmoji: post.authorProfileEmoji,
                    teamID: post.teamID,
                    teamName: post.teamName,
                    body: post.body,
                    createdAt: post.createdAt,
                    status: "visible",
                    reportable: true
                )
            }
    }

    func createPost(content: String, teamID: String?, displayName: String?, emoji: String?) -> CommunityPostDTO {
        let team = KBOSeed.team(id: teamID)
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "익명 팬"
        let post = LocalPost(
            id: UUID().uuidString,
            authorID: "local-\(name)",
            authorDisplayName: name,
            authorProfileEmoji: emoji?.nilIfEmpty ?? "⚾",
            teamID: team?.id ?? teamID,
            teamName: team?.shortName,
            body: content,
            createdAt: Self.createdAtFormatter.string(from: Date())
        )
        savePosts([post] + storedPosts())
        return loadPosts().first { $0.id == post.id } ?? CommunityPostDTO(
            id: post.id,
            authorID: post.authorID,
            authorDisplayName: post.authorDisplayName,
            authorProfileEmoji: post.authorProfileEmoji,
            teamID: post.teamID,
            teamName: post.teamName,
            body: post.body,
            createdAt: post.createdAt
        )
    }

    func reportPost(id: String) {
        var ids = reportedPostIDs()
        ids.insert(id)
        defaults.set(Array(ids), forKey: Key.reportedPostIDs)
    }

    func reportedPostIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.reportedPostIDs) ?? [])
    }

    func blockAuthor(id: String) {
        var ids = blockedAuthorIDs()
        ids.insert(id)
        defaults.set(Array(ids), forKey: Key.blockedAuthorIDs)
    }

    func blockedAuthorIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.blockedAuthorIDs) ?? [])
    }

    private func storedPosts() -> [LocalPost] {
        guard let data = defaults.data(forKey: Key.posts) else { return seedPosts() }
        return (try? JSONDecoder().decode([LocalPost].self, from: data)) ?? []
    }

    private func savePosts(_ posts: [LocalPost]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        defaults.set(data, forKey: Key.posts)
    }

    private func seedPosts() -> [LocalPost] {
        [
            LocalPost(
                id: "local-seed-1",
                authorID: "local-victoryfairy",
                authorDisplayName: "승리요정",
                authorProfileEmoji: "⚾",
                teamID: nil,
                teamName: "팬",
                body: "서버 응원톡이 열리기 전에도 이 기기에서 응원 메시지를 남길 수 있어요.",
                createdAt: Self.createdAtFormatter.string(from: Date())
            )
        ]
    }

    private static let createdAtFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
