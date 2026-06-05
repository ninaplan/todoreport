import Foundation

enum RecurringEditChangeType {
    case removeRecurrence
    case changeRule
    case changeEndCondition
}

struct RecurringEditPendingInfo {
    let original: Todo
    let updated: Todo
    let changeType: RecurringEditChangeType
}

enum RecurringTodoEditHandler {
    static func detectChange(original: Todo, updated: Todo) -> RecurringEditChangeType? {
        guard original.recurrenceId != nil else { return nil }

        if original.recurrenceRule != nil && updated.recurrenceRule == nil {
            return .removeRecurrence
        }

        if let origRule = original.recurrenceRule,
           let newRule = updated.recurrenceRule,
           !origRule.isEffectivelyEqual(to: newRule) {
            return .changeRule
        }

        if original.recurrenceEndDate != updated.recurrenceEndDate ||
           original.recurrenceCount != updated.recurrenceCount {
            return .changeEndCondition
        }

        return nil
    }

    // MARK: - 이 항목만 변경

    static func applySingleOnly(original: Todo, updated: Todo, changeType: RecurringEditChangeType) async throws {
        switch changeType {
        case .removeRecurrence:
            var detached = updated
            detached.recurrenceId = nil
            detached.recurrenceRule = nil
            detached.recurrenceEndDate = nil
            detached.recurrenceCount = nil
            try await TodoService.shared.updateTodo(detached)

        case .changeRule:
            // 이 항목을 새 시리즈의 시작으로 분리
            var newSeries = updated
            newSeries.recurrenceId = UUID().uuidString
            try await TodoService.shared.updateTodo(newSeries)
            await RecurringTodoManager.shared.generateUpcoming()

        case .changeEndCondition:
            try await TodoService.shared.updateTodo(updated)
        }
    }

    // MARK: - 이후 항목 모두 변경

    static func applyFromNowOn(original: Todo, updated: Todo, changeType: RecurringEditChangeType) async throws {
        guard let seriesId = original.recurrenceId else { return }

        switch changeType {
        case .removeRecurrence:
            await RecurringTodoManager.shared.deleteFutureTodos(
                seriesId: seriesId, from: updated.date, excludingId: updated.id
            )
            await RecurringTodoManager.shared.capSeriesEndDate(
                seriesId: seriesId, beforeDate: updated.date, excludingId: updated.id
            )
            var detached = updated
            detached.recurrenceId = nil
            detached.recurrenceRule = nil
            detached.recurrenceEndDate = nil
            detached.recurrenceCount = nil
            try await TodoService.shared.updateTodo(detached)

        case .changeRule:
            await RecurringTodoManager.shared.deleteFutureTodos(
                seriesId: seriesId, from: updated.date, excludingId: updated.id
            )
            await RecurringTodoManager.shared.capSeriesEndDate(
                seriesId: seriesId, beforeDate: updated.date, excludingId: updated.id
            )
            var newOrigin = updated
            newOrigin.recurrenceId = UUID().uuidString
            try await TodoService.shared.updateTodo(newOrigin)
            await RecurringTodoManager.shared.generateUpcoming()

        case .changeEndCondition:
            await RecurringTodoManager.shared.updateSeriesEndCondition(
                seriesId: seriesId,
                endDate: updated.recurrenceEndDate,
                count: updated.recurrenceCount
            )
            try await TodoService.shared.updateTodo(updated)
            await RecurringTodoManager.shared.generateUpcoming()
        }
    }
}

extension RecurrenceRule {
    func isEffectivelyEqual(to other: RecurrenceRule) -> Bool {
        switch (self, other) {
        case (.weekly(let a), .weekly(let b)):
            return Set(a) == Set(b)
        case (.biweekly(let a), .biweekly(let b)):
            return Set(a) == Set(b)
        default:
            return self == other
        }
    }
}
