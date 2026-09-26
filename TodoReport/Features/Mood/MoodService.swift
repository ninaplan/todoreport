import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MoodService {
    static let shared = MoodService()

    /// 선택지·모드가 바뀌면 증가한다. 칩이 이 값을 읽어 다시 불러온다.
    private(set) var revision: Int = 0

    enum Failure: Error {
        case emptyName
        case optionNotFound
        case plannerNotFound
        case saveFailed
    }

    private var context: ModelContext { PersistenceController.shared.context }
    /// 플래너마다 기본 키 채우기는 한 번만 저장한다.
    @ObservationIgnored private var backfilledPlannerIds: Set<String> = []

    private init() {}

    func storageMode(for plannerId: String) -> MoodStorageMode? {
        PlannerService.shared.store
            .first { $0.id == plannerId }?
            .decodedReportPropsMapping.moodMode
    }

    func options(for plannerId: String) throws -> [MoodOption] {
        if allowsDefaultOptions(plannerId: plannerId) {
            let existing = try fetchItems(plannerId: plannerId)
            if existing.isEmpty {
                try insertDefaultOptions(plannerId: plannerId)
            }
        }
        let items = try fetchItems(plannerId: plannerId)
        if !backfilledPlannerIds.contains(plannerId) {
            if backfillDefaultKeys(in: items) {
                try context.save()
            }
            backfilledPlannerIds.insert(plannerId)
        }
        return items.map(option(from:))
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
        bump()
        return option(from: item)
    }

    func deleteOption(id: String) throws {
        guard let item = try fetchItem(id: id) else { throw Failure.optionNotFound }
        context.delete(item)
        try context.save()
        bump()
    }

    func updateColor(id: String, colorHex: String) throws {
        guard let item = try fetchItem(id: id) else { throw Failure.optionNotFound }
        item.colorHex = colorHex
        try context.save()
        bump()
    }

    func updateOption(id: String, name: String, colorHex: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.emptyName }
        guard let item = try fetchItem(id: id) else { throw Failure.optionNotFound }
        let nameChanged = trimmed != displayedName(of: item)
        if nameChanged {
            item.defaultKey = nil
            item.name = trimmed
            try rewriteMoodSnapshots(optionId: id, name: trimmed)
        }
        item.colorHex = colorHex
        try context.save()
        bump()
    }

    func reorder(ids: [String], plannerId: String) throws {
        let items = try fetchItems(plannerId: plannerId)
        for (index, id) in ids.enumerated() {
            items.first { $0.id == id }?.sortOrder = index
        }
        try context.save()
        bump()
    }

    func selection(on date: Date, plannerId: String) throws -> (optionId: String?, name: String?) {
        guard let item = try existingDailyReport(on: date, plannerId: plannerId) else {
            return (nil, nil)
        }
        return (item.moodOptionId, item.moodName)
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

    /// 끄면 disabled. 다시 켜면 끄기 직전이 notion이었으면 notion으로 되돌리고, 아니면 appOnly.
    /// nil(미설정)은 appOnly로 기억해서, 켜도 자동 연결 대상(nil)으로 돌아가지 않는다.
    func setUsageEnabled(_ enabled: Bool, plannerId: String) async throws {
        guard var planner = PlannerService.shared.store.first(where: { $0.id == plannerId }) else {
            throw Failure.plannerNotFound
        }
        var mapping = planner.decodedReportPropsMapping
        let key = restoreModeKey(plannerId: plannerId)
        let modeToRemember: String?
        if enabled {
            modeToRemember = nil
            let stored = UserDefaults.standard.string(forKey: key)
            mapping.moodMode = stored == MoodStorageMode.notion.rawValue ? .notion : .appOnly
        } else {
            switch mapping.moodMode {
            case .notion, .appOnly:
                modeToRemember = mapping.moodMode?.rawValue
            case nil:
                modeToRemember = MoodStorageMode.appOnly.rawValue
            case .disabled:
                modeToRemember = nil
            }
            mapping.moodMode = .disabled
        }
        let data = try JSONEncoder().encode(mapping)
        guard let json = String(data: data, encoding: .utf8) else { throw Failure.saveFailed }
        planner.reportPropsMapping = json
        try await PlannerService.shared.savePlanner(planner)
        if let modeToRemember {
            UserDefaults.standard.set(modeToRemember, forKey: key)
        }
        bump()
    }

    private func restoreModeKey(plannerId: String) -> String {
        "moodUsageRestoreMode.\(plannerId)"
    }

    private func bump() {
        revision += 1
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
                    name: choice.storedName,
                    colorHex: choice.colorHex,
                    sortOrder: index,
                    defaultKey: choice.key
                )
            )
        }
        try context.save()
        bump()
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

    private func displayedName(of item: MoodOptionItem) -> String {
        let mode = PlannerService.shared.store
            .first { $0.id == item.plannerId }?
            .decodedReportPropsMapping.moodMode
        return MoodOption.displayName(storedName: item.name, defaultKey: item.defaultKey, mode: mode)
    }

    /// defaultKey가 비어 있고 이름이 기본 5개의 한국어·영어 이름과 같으면 키를 채운다.
    private func backfillDefaultKeys(in items: [MoodOptionItem]) -> Bool {
        var changed = false
        for item in items where item.defaultKey == nil {
            guard let key = MoodOption.defaultKey(matching: item.name) else { continue }
            item.defaultKey = key
            changed = true
        }
        return changed
    }

    private func rewriteMoodSnapshots(optionId: String, name: String) throws {
        let reports = try context.fetch(FetchDescriptor<DailyReportItem>())
        for report in reports where report.moodOptionId == optionId {
            report.moodName = name
        }
    }

    /// fetchReport와 같이 하루 리포트(endDate == nil)만 고르고, 노션 페이지가 있는 항목을 우선한다.
    private func existingDailyReport(on date: Date, plannerId: String) throws -> DailyReportItem? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let daily = try context.fetch(descriptor).filter { $0.endDate == nil && $0.plannerId == plannerId }
        return daily.first(where: { !$0.notionPageId.isEmpty }) ?? daily.first
    }

    private func dailyReportItem(on date: Date, plannerId: String) throws -> DailyReportItem {
        if let existing = try existingDailyReport(on: date, plannerId: plannerId) {
            return existing
        }
        let created = DailyReportItem(date: Calendar.current.startOfDay(for: date), plannerId: plannerId)
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
            notionOptionName: item.notionOptionName,
            defaultKey: item.defaultKey
        )
    }
}
