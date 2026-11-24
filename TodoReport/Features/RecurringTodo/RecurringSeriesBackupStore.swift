import Foundation
import SwiftData

/// 반복 규칙(`RecurringSeries`)을 iCloud 키-값 저장소에 백업하고, 재설치·기기 변경 후 되살린다.
/// - 대상: 노션에 연결된 플래너 (재설치 후 노션 투두 DB id로 같은 플래너를 찾는다)
/// - iCloud가 꺼져 있으면 기기 안에만 남는다 → 재설치 시 복원 안 됨 (지금과 같음)
/// - 백업은 id 기준 병합(추가·갱신)만 한다. 지우는 건 플래너 삭제·계정 삭제 때만.
///   (재설치 직후 기기에 시리즈가 없을 때 백업을 덮어써 날리지 않기 위함)
@MainActor
final class RecurringSeriesBackupStore {
    static let shared = RecurringSeriesBackupStore()

    private static let storageKey = "recurringSeriesBackup.v1"
    private let cloud = NSUbiquitousKeyValueStore.default

    private var context: ModelContext { PersistenceController.shared.context }

    private init() {
        cloud.synchronize()
    }

    // MARK: - 백업

    /// 기기의 시리즈를 백업에 반영 (추가·갱신만). 바뀐 게 없으면 쓰지 않는다.
    func backupAll() {
        let plannerKeys = notionPlannerKeyById()
        guard !plannerKeys.isEmpty else { return }
        let categories = categoriesById()
        let seriesList = (try? context.fetch(FetchDescriptor<RecurringSeries>())) ?? []

        var map = loadAll()
        var changed = false
        for series in seriesList {
            guard let plannerId = series.plannerId, let key = plannerKeys[plannerId] else { continue }
            let category = series.categoryId.flatMap { categories[$0] }
            let entry = RecurringSeriesBackup(
                id: series.id,
                plannerKey: key,
                title: series.title,
                memo: series.memo,
                categoryNotionOptionId: category?.notionOptionId,
                categoryName: category?.name,
                scheduledTime: series.scheduledTime,
                alarmOffset: series.alarmOffset,
                ruleData: series.ruleData,
                originDate: series.originDate,
                endDate: series.endDate,
                occurrenceLimit: series.occurrenceLimit,
                isActive: series.isActive,
                lastMaterializedThrough: series.lastMaterializedThrough
            )
            if map[series.id] != entry {
                map[series.id] = entry
                changed = true
            }
        }
        if changed {
            saveAll(map)
        }
    }

    /// 플래너 삭제 등으로 시리즈를 지울 때 백업에서도 뺀다
    func remove(seriesIds: [String]) {
        guard !seriesIds.isEmpty else { return }
        var map = loadAll()
        let before = map.count
        seriesIds.forEach { map.removeValue(forKey: $0) }
        if map.count != before {
            saveAll(map)
        }
    }

    /// 계정 삭제 시 전부 지운다
    func removeAll() {
        cloud.removeObject(forKey: Self.storageKey)
        cloud.synchronize()
    }

    // MARK: - 복원

    /// 기기에 없는 시리즈를 백업에서 되살리고, 같은 제목·규칙 날짜의 할 일을 다시 반복으로 연결한다.
    /// 플래너가 아직 노션에 다시 연결되지 않았으면 건너뛰고, 다음 호출 때 다시 시도한다.
    @discardableResult
    func restoreMissing() -> Int {
        let backups = loadAll()
        guard !backups.isEmpty else { return 0 }
        let plannerIdByKey = Dictionary(
            notionPlannerKeyById().map { ($0.value, $0.key) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !plannerIdByKey.isEmpty else { return 0 }
        let localIds = Set(((try? context.fetch(FetchDescriptor<RecurringSeries>())) ?? []).map(\.id))

        // 되살린 시리즈는 「어제까지 만들었음」으로 둔다.
        // → 지난 날짜는 다시 만들지 않고, 오늘부터는 노션 할 일을 먼저 받아 와서 같은 할 일에 연결하며 따라잡는다.
        //   (백업 시점의 미래 날짜를 그대로 두면, 노션에 이미 있는 미래 할 일이 반복에 연결되지 않는다)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))
            ?? calendar.startOfDay(for: .now)

        var restored: [RecurringSeries] = []
        for backup in backups.values where !localIds.contains(backup.id) {
            guard let plannerId = plannerIdByKey[backup.plannerKey] else { continue }
            let series = RecurringSeries(
                id: backup.id,
                plannerId: plannerId,
                title: backup.title,
                memo: backup.memo,
                categoryId: resolveCategoryId(backup, plannerId: plannerId),
                scheduledTime: backup.scheduledTime,
                alarmOffset: backup.alarmOffset,
                ruleData: backup.ruleData,
                originDate: backup.originDate,
                endDate: backup.endDate,
                occurrenceLimit: backup.occurrenceLimit,
                isActive: backup.isActive,
                lastMaterializedThrough: min(backup.lastMaterializedThrough ?? yesterday, yesterday)
            )
            context.insert(series)
            restored.append(series)
        }
        guard !restored.isEmpty else { return 0 }

        relinkUnlinkedTodos(to: restored)
        do {
            try context.save()
            AppLogger.shared.info("RecurringTodo", "iCloud 백업에서 반복 \(restored.count)개 복원")
        } catch {
            context.rollback()
            AppLogger.shared.error("RecurringTodo", "반복 복원 저장 실패 \(error.localizedDescription)")
            return 0
        }
        return restored.count
    }

    /// 재설치 후 노션에서 다시 들어온 할 일은 반복 연결(recurrenceId)이 없다.
    /// 같은 플래너·같은 제목이고 날짜가 반복 규칙에 맞으면 다시 연결한다. (recurrenceId는 노션에 올리지 않는 로컬 값)
    private func relinkUnlinkedTodos(to seriesList: [RecurringSeries]) {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.recurrenceId == nil })
        let unlinked = (try? context.fetch(descriptor)) ?? []
        let calendar = Calendar.current
        for series in seriesList {
            guard let rule = series.decodedRule else { continue }
            let origin = calendar.startOfDay(for: series.originDate)
            let endDay = series.endDate.map { calendar.startOfDay(for: $0) }
            for item in unlinked where item.recurrenceId == nil
                && item.plannerId == series.plannerId
                && item.title == series.title {
                guard let date = item.date else { continue }
                let day = calendar.startOfDay(for: date)
                guard day >= origin else { continue }
                if let endDay, day > endDay { continue }
                guard rule.matches(date: day, origin: origin) else { continue }
                item.recurrenceId = series.id
            }
        }
    }

    // MARK: - Private

    private func loadAll() -> [String: RecurringSeriesBackup] {
        guard let data = cloud.data(forKey: Self.storageKey),
              let list = try? JSONDecoder().decode([RecurringSeriesBackup].self, from: data) else {
            return [:]
        }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    private func saveAll(_ map: [String: RecurringSeriesBackup]) {
        guard let data = try? JSONEncoder().encode(Array(map.values)) else {
            AppLogger.shared.error("RecurringTodo", "반복 백업 인코딩 실패")
            return
        }
        cloud.set(data, forKey: Self.storageKey)
        cloud.synchronize()
    }

    /// 노션 연결 플래너: 플래너 id → 노션 투두 DB id
    private func notionPlannerKeyById() -> [String: String] {
        var map: [String: String] = [:]
        for planner in PlannerService.shared.store where planner.isNotionConnected {
            guard let key = planner.notionTodoDBId, !key.isEmpty else { continue }
            map[planner.id] = key
        }
        return map
    }

    private func categoriesById() -> [String: CategoryItem] {
        let items = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        return Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 노션 옵션 id가 같은 카테고리 → 없으면 이름이 같은 카테고리 (같은 플래너 안에서)
    private func resolveCategoryId(_ backup: RecurringSeriesBackup, plannerId: String) -> String? {
        let items = ((try? context.fetch(FetchDescriptor<CategoryItem>())) ?? [])
            .filter { $0.plannerId == plannerId }
        if let optionId = backup.categoryNotionOptionId,
           let match = items.first(where: { $0.notionOptionId == optionId }) {
            return match.id
        }
        if let name = backup.categoryName,
           let match = items.first(where: { $0.name == name }) {
            return match.id
        }
        return nil
    }
}
