import Foundation
import SwiftData

extension RecurringSeries {
    static func fetch(id: String, in context: ModelContext) -> RecurringSeries? {
        let descriptor = FetchDescriptor<RecurringSeries>(predicate: #Predicate { $0.id == id })
        do {
            return try context.fetch(descriptor).first
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 조회 실패 id:\(id) \(error.localizedDescription)")
            return nil
        }
    }
}
