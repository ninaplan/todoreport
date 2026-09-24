import Foundation
import SwiftData

final class MoodService {
    static let shared = MoodService()

    enum Failure: Error {
        case emptyName
        case optionNotFound
    }

    private var context: ModelContext { PersistenceController.shared.context }

    private init() {}

    func options(for plannerId: String) throws -> [MoodOption] {
        if allowsDefaultOptions(plannerId: plannerId) {
            let existing = try fetchItems(plannerId: plannerId)
            if existing.isEmpty {
                try insertDefaultOptions(plannerId: plannerId)
            }
        }
        return try fetchItems(plannerId: plannerId).map(option(from:))
    }

    func addOption(name: String, colorHex: String, plannerId: String) throws -> MoodOption {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.emptyName }
        let existing = try fetchItems(plannerId: plannerId)
        let sortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let item = MoodOptionItem(
            plannerId: plannerId,
            name: trimmed,
            colorHex: colorHex,
            sortOrder: sortOrder
        )
        context.insert(item)
        try context.save()
        return option(from: item)
    }

    func deleteOption(id: String) throws {
        guard let item = try fetchItem(id: id) else { throw Failure.optionNotFound }
        context.delete(item)
        try context.save()
    }

    func updateColor(id: String, colorHex: String) throws {
        guard let item = try fetchItem(id: id) else { throw Failure.optionNotFound }
        item.colorHex = colorHex
        try context.save()
    }

    func reorder(ids: [String], plannerId: String) throws {
        let items = try fetchItems(plannerId: plannerId)
        for (index, id) in ids.enumerated() {
            items.first { $0.id == id }?.sortOrder = index
        }
        try context.save()
    }

    /// 하루 리뷰에 기분을 저장한다. optionId가 nil이면 해제. 리뷰 필드는 바꾸지 않는다.
    func setMood(optionId: String?, on date: Date, plannerId: String) throws {
        let item = try dailyReportItem(on: date, plannerId: plannerId)
        if let optionId {
            guard let option = try fetchItem(id: optionId), option.plannerId == plannerId else {
                throw Failure.optionNotFound
            }
            item.moodOptionId = option.id
            item.moodName = option.name
        } else {
            item.moodOptionId = nil
            item.moodName = nil
        }
        try context.save()
    }

    private func allowsDefaultOptions(plannerId: String) -> Bool {
        guard let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }) else {
            return false
        }
        return planner.decodedReportPropsMapping.moodMode != .disabled
    }

    private func insertDefaultOptions(plannerId: String) throws {
        for (index, choice) in MoodOption.defaultChoices.enumerated() {
            context.insert(
                MoodOptionItem(
                    plannerId: plannerId,
                    name: choice.name,
                    colorHex: choice.colorHex,
                    sortOrder: index
                )
            )
        }
        try context.save()
    }

    private func fetchItems(plannerId: String) throws -> [MoodOptionItem] {
        let descriptor = FetchDescriptor<MoodOptionItem>(
            predicate: #Predicate { $0.plannerId == plannerId },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchItem(id: String) throws -> MoodOptionItem? {
        let descriptor = FetchDescriptor<MoodOptionItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    /// fetchReport와 같이 하루 리포트(endDate == nil)만 고르고, 노션 페이지가 있는 항목을 우선한다.
    private func dailyReportItem(on date: Date, plannerId: String) throws -> DailyReportItem {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            let created = DailyReportItem(date: startOfDay, plannerId: plannerId)
            context.insert(created)
            return created
        }
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let daily = try context.fetch(descriptor).filter { $0.endDate == nil && $0.plannerId == plannerId }
        if let existing = daily.first(where: { !$0.notionPageId.isEmpty }) ?? daily.first {
            return existing
        }
        let created = DailyReportItem(date: startOfDay, plannerId: plannerId)
        context.insert(created)
        return created
    }

    private func option(from item: MoodOptionItem) -> MoodOption {
        MoodOption(
            id: item.id,
            plannerId: item.plannerId,
            name: item.name,
            colorHex: item.colorHex,
            sortOrder: item.sortOrder,
            notionOptionId: item.notionOptionId,
            notionOptionName: item.notionOptionName
        )
    }
}
