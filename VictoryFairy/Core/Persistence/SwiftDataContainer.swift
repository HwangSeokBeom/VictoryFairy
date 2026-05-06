import Foundation
import SwiftData

enum SwiftDataContainer {
    static func makeAttendanceLogRepository() -> LocalAttendanceLogRepository? {
        let schema = Schema([SwiftDataAttendanceLogEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return LocalAttendanceLogRepository(container: container)
        } catch {
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let container = try? ModelContainer(for: schema, configurations: [fallbackConfiguration]) else {
                return nil
            }
            return LocalAttendanceLogRepository(container: container)
        }
    }
}

