import Foundation
import SwiftData
import Observation

enum CategoryNotionMode: String, Codable {
    case appOnly
    case select
    case database
}

enum CategoryNotionProperty {
    static let supportedTypes = ["select", "status"]

    static func candidates(from properties: [NotionProperty]) -> [NotionProperty] {
        properties.filter { supportedTypes.contains($0.type) }
    }
}

struct NotionCategoryOption: Identifiable, Equatable {
    let id: String
    let name: String
}

@Observable
@MainActor
final class CategoryNotionSync {
    static let shared = CategoryNotionSync()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }
    private let backendBase = "https://todoreport-backend.vercel.app"

    // MARK: - Mode

    func resolvedMode(for planner: Planner) -> CategoryNotionMode {
        if planner.notionCategoryDBId != nil { return .database }
        guard planner.decodedTodoPropsMapping.category != nil else { return .appOnly }
        let linkedToNotion = planner.isNotionConnected
            || (planner.notionTodoDBId != nil && planner.resolvedNotionToken != nil)
        return linkedToNotion ? .select : .appOnly
    }

    func isSelectSyncEnabled(for planner: Planner) -> Bool {
        resolvedMode(for: planner) == .select
    }

    // MARK: - Fetch Notion options

    func fetchNotionOptions(planner: Planner) async -> [NotionCategoryOption] {
        guard let dbId = planner.notionTodoDBId,
              let token = planner.resolvedNotionToken,
              let propName = planner.decodedTodoPropsMapping.category,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else {
            AppLogger.shared.warn("CategoryNotionSync", "노션 옵션 조회 스킵 - DB/토큰/속성명 없음")
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                AppLogger.shared.warn("CategoryNotionSync", "노션 옵션 조회 실패 - 응답 없음")
                return []
            }
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                AppLogger.shared.warn(
                    "CategoryNotionSync",
                    "노션 옵션 조회 실패 - HTTP \(http.statusCode): \(body.prefix(200))"
                )
                return []
            }
            let decoded = try JSONDecoder().decode(CategoryPropertiesResponse.self, from: data)
            // 이름으로만 매칭 (select/status 둘 다 허용 — 매핑에 저장된 propType과 노션 실제 type이 어긋나도 안전)
            guard let prop = decoded.properties.first(where: {
                $0.name == propName && CategoryNotionProperty.supportedTypes.contains($0.type)
            }) else {
                let available = decoded.properties
                    .filter { CategoryNotionProperty.supportedTypes.contains($0.type) }
                    .map { "\($0.name)(\($0.type))" }
                    .joined(separator: ", ")
                AppLogger.shared.warn(
                    "CategoryNotionSync",
                    "카테고리 속성 '\(propName)' 없음. 후보: [\(available)]"
                )
                return []
            }
            await reconcileCategoryPropType(for: planner, resolvedType: prop.type)
            if let details = prop.selectOptions, !details.isEmpty {
                return details.map { NotionCategoryOption(id: $0.id, name: $0.name) }
            }
            return (prop.options ?? []).enumerated().map {
                NotionCategoryOption(id: "name:\($0.element)", name: $0.element)
            }
        } catch {
            AppLogger.shared.warn("CategoryNotionSync", "노션 옵션 조회 실패 - \(error.localizedDescription)")
            return []
        }
    }

    /// 매핑에 저장된 categoryPropType과 노션 실제 type이 다르면 매핑을 보정해 둠
    private func reconcileCategoryPropType(for planner: Planner, resolvedType: String) async {
        guard planner.decodedTodoPropsMapping.categoryPropType != resolvedType else { return }
        var updated = planner
        var mapping = updated.decodedTodoPropsMapping
        mapping.categoryPropType = resolvedType
        if let data = try? JSONEncoder().encode(mapping),
           let json = String(data: data, encoding: .utf8) {
            updated.todoPropsMapping = json
            try? await PlannerService.shared.savePlanner(updated)
        }
    }

    // MARK: - 이름 일치 병합

    /// 이름 일치 병합 + 노션에만 있는 새 옵션을 앱 카테고리로 가져오기
    func syncCategoriesByName(plannerId: String) async {
        guard let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }),
              isSelectSyncEnabled(for: planner) else { return }

        let notionOptions = await fetchNotionOptions(planner: planner)
        guard !notionOptions.isEmpty else { return }

        let all = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        let plannerItems = all.filter { $0.plannerId == plannerId }
        let archivedNames = Set(
            plannerItems
                .filter { $0.statusRaw == CategoryStatus.archived.rawValue }
                .map { $0.name.trimmingCharacters(in: .whitespaces) }
        )
        let unlinked = plannerItems.filter {
            $0.statusRaw == CategoryStatus.active.rawValue && !$0.isLinkedToNotion
        }

        var usedOptionIds = Set(linkedOptionIds(plannerId: plannerId))
        var linkedCount = 0

        for item in unlinked {
            let normalizedName = item.name.trimmingCharacters(in: .whitespaces)
            guard !archivedNames.contains(normalizedName) else { continue }
            guard let option = notionOptions.first(where: { opt in
                let optionName = opt.name.trimmingCharacters(in: .whitespaces)
                return optionName == normalizedName &&
                !archivedNames.contains(optionName) &&
                !usedOptionIds.contains(opt.id)
            }) else { continue }

            item.notionOptionId = option.id
            item.notionOptionName = option.name
            usedOptionIds.insert(option.id)
            linkedCount += 1
        }

        let toImport = notionOptionsToImport(
            plannerItems: plannerItems,
            notionOptions: notionOptions,
            archivedNames: archivedNames,
            usedOptionIds: usedOptionIds
        )
        for (offset, option) in toImport.enumerated() {
            importNotionOnlyOption(
                option,
                plannerId: plannerId,
                plannerItems: plannerItems,
                sortOrder: plannerItems.count + offset
            )
            usedOptionIds.insert(option.id)
        }

        guard linkedCount > 0 || !toImport.isEmpty else { return }
        try? context.save()
        await CategoryService.shared.refresh()
        AppLogger.shared.info(
            "CategoryNotionSync",
            "카테고리 동기화 - 병합 \(linkedCount)개, 노션 신규 \(toImport.count)개 planner=\(plannerId)"
        )
    }

    // MARK: - Todo sync

    func appendToPayload(_ body: inout [String: Any], todo: Todo, planner: Planner) {
        guard isSelectSyncEnabled(for: planner),
              let prop = planner.decodedTodoPropsMapping.category else { return }
        body["categoryProp"] = prop
        body["categoryPropType"] = planner.decodedTodoPropsMapping.categoryPropType ?? "select"
        body["categoryName"] = notionSyncName(for: todo.categoryId) ?? ""
    }

    func todoFetchParams(from planner: Planner) -> [String: String] {
        guard isSelectSyncEnabled(for: planner),
              let prop = planner.decodedTodoPropsMapping.category else { return [:] }
        return ["categoryProp": prop]
    }

    func notionSyncName(for categoryId: String?) -> String? {
        guard let categoryId,
              let item = try? context.fetch(
                FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == categoryId })
              ).first else { return nil }
        guard item.statusRaw == CategoryStatus.active.rawValue,
              item.isLinkedToNotion else { return nil }
        return item.notionOptionName ?? item.name
    }

    func applyCategoryFromNotion(name: String?, plannerId: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty,
              let plannerId else { return nil }

        let all = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        let match = all.first(where: { item in
            guard item.plannerId == plannerId,
                  item.statusRaw == CategoryStatus.active.rawValue else { return false }
            let itemName = item.name.trimmingCharacters(in: .whitespaces)
            let notionName = item.notionOptionName?.trimmingCharacters(in: .whitespaces)
            return itemName == trimmed || notionName == trimmed
        })
        return match?.id
    }

    // MARK: - Category save hook

    func onCategorySaved(_ category: Category) async {
        guard category.status == .active,
              category.isLinkedToNotion,
              let plannerId = category.plannerId,
              let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }),
              isSelectSyncEnabled(for: planner),
              let prop = planner.decodedTodoPropsMapping.category,
              let dbId = planner.notionTodoDBId,
              let token = planner.resolvedNotionToken else { return }

        await addSelectOption(
            dbId: dbId, propertyName: prop,
            optionName: category.notionOptionName ?? category.name,
            token: token
        )
    }

    func onCategoryMappingEnabled(
        plannerId: String,
        previousCategoryProp: String?,
        newCategoryProp: String?
    ) {
        guard newCategoryProp != nil else { return }
        Task { await syncCategoriesByName(plannerId: plannerId) }
    }

    func onCategoryDeleted(_ category: Category) async {
        guard category.isLinkedToNotion,
              let plannerId = category.plannerId,
              let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }),
              isSelectSyncEnabled(for: planner),
              let prop = planner.decodedTodoPropsMapping.category,
              let dbId = planner.notionTodoDBId,
              let token = planner.resolvedNotionToken else { return }

        let rawOptionId = category.notionOptionId
        let optionId = rawOptionId?.hasPrefix("name:") == true ? nil : rawOptionId
        let optionName = category.notionOptionName ?? category.name
        guard optionId != nil || !optionName.isEmpty else { return }

        let removed = await removeSelectOption(
            dbId: dbId,
            propertyName: prop,
            optionId: optionId,
            optionName: optionName,
            propType: planner.decodedTodoPropsMapping.categoryPropType ?? "select",
            token: token
        )
        if !removed {
            AppLogger.shared.warn(
                "CategoryNotionSync",
                "노션 카테고리 옵션 삭제 실패 - \(optionName) (id: \(rawOptionId ?? "nil"))"
            )
        }
    }

    // MARK: - Private

    private func notionOptionsToImport(
        plannerItems: [CategoryItem],
        notionOptions: [NotionCategoryOption],
        archivedNames: Set<String>,
        usedOptionIds: Set<String>
    ) -> [NotionCategoryOption] {
        let existingNames = Set(
            plannerItems.map { $0.name.trimmingCharacters(in: .whitespaces) }
        )
        let linkedNames = Set(
            plannerItems.compactMap { $0.notionOptionName?.trimmingCharacters(in: .whitespaces) }
        )

        return notionOptions.filter { opt in
            let name = opt.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return false }
            guard !usedOptionIds.contains(opt.id) else { return false }
            guard !existingNames.contains(name) else { return false }
            guard !linkedNames.contains(name) else { return false }
            guard !archivedNames.contains(name) else { return false }
            return true
        }
    }

    private func importNotionOnlyOption(
        _ option: NotionCategoryOption,
        plannerId: String,
        plannerItems: [CategoryItem],
        sortOrder: Int
    ) {
        let name = option.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if plannerItems.contains(where: {
            $0.notionOptionId == option.id || $0.name.trimmingCharacters(in: .whitespaces) == name
        }) { return }
        let category = Category(
            name: option.name,
            plannerId: plannerId,
            notionOptionId: option.id,
            notionOptionName: option.name
        )
        context.insert(CategoryItem.from(category, sortOrder: sortOrder))
    }

    private func linkedOptionIds(plannerId: String) -> [String] {
        let all = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        return all.compactMap { item in
            guard item.plannerId == plannerId, let id = item.notionOptionId else { return nil }
            return id
        }
    }

    private func removeSelectOption(
        dbId: String,
        propertyName: String,
        optionId: String?,
        optionName: String,
        propType: String,
        token: String
    ) async -> Bool {
        guard !dbId.isEmpty, !propertyName.isEmpty,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/remove-select-option") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = [
            "propertyName": propertyName,
            "optionName": optionName,
            "propType": propType
        ]
        if let optionId { body["optionId"] = optionId }
        guard let bodyData = try? JSONEncoder().encode(body) else { return false }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            guard http.statusCode == 200 else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                AppLogger.shared.warn(
                    "CategoryNotionSync",
                    "노션 select 옵션 삭제 실패 - HTTP \(http.statusCode): \(propertyName)/\(optionName) \(bodyText.prefix(120))"
                )
                return false
            }
            return true
        } catch {
            AppLogger.shared.warn(
                "CategoryNotionSync",
                "노션 select 옵션 삭제 실패 - \(propertyName)/\(optionName): \(error.localizedDescription)"
            )
            return false
        }
    }

    private func addSelectOption(dbId: String, propertyName: String, optionName: String, token: String) async {
        guard !dbId.isEmpty, !propertyName.isEmpty, !optionName.isEmpty,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/add-select-option") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["propertyName": propertyName, "optionName": optionName]
        guard let bodyData = try? JSONEncoder().encode(body) else { return }
        request.httpBody = bodyData

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            AppLogger.shared.warn(
                "CategoryNotionSync",
                "노션 select 옵션 추가 실패 - \(propertyName)/\(optionName): \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - API Response

private struct CategoryPropertiesResponse: Decodable {
    let properties: [PropItem]
    struct PropItem: Decodable {
        let id: String
        let name: String
        let type: String
        let options: [String]?
        let selectOptions: [SelectOptionItem]?
        struct SelectOptionItem: Decodable {
            let id: String
            let name: String
        }
    }
}
