import Foundation

enum RecurringEditChangeType: Equatable {
    case removeRecurrence
    case changeRule
    case changeEndCondition
    case changeDetails

    var alertTitle: String {
        switch self {
        case .removeRecurrence: return String(localized: "반복 해제")
        case .changeRule: return String(localized: "반복 주기 변경")
        case .changeEndCondition, .changeDetails: return String(localized: "반복 투두 편집")
        }
    }

    var alertMessage: String {
        switch self {
        case .changeDetails:
            return String(localized: "이 변경사항을 어디까지 적용할까요?")
        default:
            return String(localized: "어떻게 변경할까요?")
        }
    }

    var singleLabel: String {
        self == .removeRecurrence
            ? String(localized: "이 항목만 해제")
            : String(localized: "이 항목만 변경")
    }

    var futureLabel: String {
        self == .removeRecurrence
            ? String(localized: "이후 항목 모두 해제")
            : String(localized: "이후 항목 모두 변경")
    }
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

        if original.categoryId != updated.categoryId ||
           original.scheduledTime != updated.scheduledTime ||
           original.alarmOffset != updated.alarmOffset ||
           original.title != updated.title ||
           original.memo != updated.memo {
            return .changeDetails
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
            try RecurringTodoManager.shared.adoptExistingTodoAsSeriesOrigin(newSeries)
            try await TodoService.shared.updateTodo(newSeries)
            await RecurringTodoManager.shared.materializeDue()

        case .changeEndCondition:
            try await TodoService.shared.updateTodo(updated)

        case .changeDetails:
            try await TodoService.shared.updateTodo(updated)
        }
    }

    // MARK: - 이후 항목 모두 변경

    static func applyFromNowOn(original: Todo, updated: Todo, changeType: RecurringEditChangeType) async throws {
        guard let seriesId = original.recurrenceId else { return }

        switch changeType {
        case .removeRecurrence:
            guard let fromDate = updated.date else { return }
            await RecurringTodoManager.shared.capSeriesEndDate(
                seriesId: seriesId, beforeDate: fromDate, excludingId: updated.id
            )
            var detached = updated
            detached.recurrenceId = nil
            detached.recurrenceRule = nil
            detached.recurrenceEndDate = nil
            detached.recurrenceCount = nil
            try await TodoService.shared.updateTodo(detached)

        case .changeRule:
            guard let fromDate = updated.date else { return }
            await RecurringTodoManager.shared.capSeriesEndDate(
                seriesId: seriesId, beforeDate: fromDate, excludingId: updated.id
            )
            var newOrigin = updated
            newOrigin.recurrenceId = UUID().uuidString
            try RecurringTodoManager.shared.adoptExistingTodoAsSeriesOrigin(newOrigin)
            try await TodoService.shared.updateTodo(newOrigin)
            await RecurringTodoManager.shared.materializeDue()

        case .changeEndCondition:
            await RecurringTodoManager.shared.updateSeriesEndCondition(
                seriesId: seriesId,
                endDate: updated.recurrenceEndDate,
                count: updated.recurrenceCount
            )
            RecurringTodoManager.shared.updateSeriesTemplate(from: updated)
            try await TodoService.shared.updateTodo(updated)
            await RecurringTodoManager.shared.materializeDue()

        case .changeDetails:
            RecurringTodoManager.shared.updateSeriesTemplate(from: updated)
            try await TodoService.shared.updateTodo(updated)
            await RecurringTodoManager.shared.updateFutureTodosDetails(from: updated)
            await RecurringTodoManager.shared.materializeDue()
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
