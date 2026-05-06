import Foundation
import SwiftData

struct LocalAttendanceLogRepository: AttendanceLogRepository, FeedRepository, CalendarRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAttendanceLogs(season: Int) async throws -> [AttendanceLogViewState] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SwiftDataAttendanceLogEntity>(
            predicate: #Predicate { $0.season == season },
            sortBy: [
                SortDescriptor(\.gameDate, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        return try context.fetch(descriptor).map(AttendanceLogMapper.map)
    }

    func createAttendanceLog(_ request: CreateAttendanceLogRequest) async throws -> AttendanceLogViewState {
        let context = ModelContext(container)
        let entity = AttendanceLogMapper.entity(from: request)
        context.insert(entity)
        try context.save()
        return AttendanceLogMapper.map(entity)
    }

    func updateAttendanceLog(id: String, request: UpdateAttendanceLogRequest) async throws -> AttendanceLogViewState {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SwiftDataAttendanceLogEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw APIError.server(code: "LOCAL_LOG_NOT_FOUND", message: "로컬 직관 기록을 찾을 수 없어요.")
        }
        AttendanceLogMapper.update(entity, request: request)
        try context.save()
        return AttendanceLogMapper.map(entity)
    }

    func deleteAttendanceLog(id: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SwiftDataAttendanceLogEntity>(
            predicate: #Predicate { $0.id == id }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }

    func markSyncState(id: String, state: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SwiftDataAttendanceLogEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else { return }
        entity.syncStateRawValue = state
        entity.updatedAt = .now
        try context.save()
    }

    func fetchFeed(season: Int, result: GameResult? = nil) async throws -> [AttendanceLogViewState] {
        let logs = try await fetchAttendanceLogs(season: season)
        guard let result else { return logs }
        return logs.filter { $0.result == result }
    }

    func fetchCalendar(year: Int, month: Int) async throws -> [AttendanceLogViewState] {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date.vfDate(year: year, month: month, day: 1)
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return []
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SwiftDataAttendanceLogEntity>(
            predicate: #Predicate { entity in
                entity.gameDate >= start && entity.gameDate < end
            },
            sortBy: [
                SortDescriptor(\.gameDate, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        return try context.fetch(descriptor).map(AttendanceLogMapper.map)
    }
}
