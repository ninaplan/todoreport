import Foundation

/// 투두 DB 속성 자동 매핑 정책
enum TodoPropsMappingPolicy {
    /// 온보딩·DB 최초 선택 — 필수 필드 휴리스틱 적용
    case initialSetup
    /// 설정 재진입·속성 목록 refresh — 사용자 저장값 우선
    case preserveUser
}

enum TodoPropsMappingAutoFill {

    /// 리포트 relation 자동 매핑에만 사용하는 정확한 속성명 (first fallback 금지)
    private static let reportRelationExactNames = ["데일리 리포트"]

    /// isPinned checkbox 자동 매핑 alias (순서대로 exact match, 영문은 대소문자 무시)
    private static let isPinnedAliasNames = ["중요", "상단고정", "고정", "pin", "pinned"]

    static func apply(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty],
        policy: TodoPropsMappingPolicy
    ) {
        switch policy {
        case .initialSetup:
            applyInitialSetup(mapping: &mapping, properties: properties)
        case .preserveUser:
            mergePreservingUser(mapping: &mapping, properties: properties)
        }
    }

    /// 저장 직전·수동 선택 후 이름→ID 보강
    static func backfillIds(mapping: inout TodoPropsMapping, properties: [NotionProperty]) {
        backfillField(name: &mapping.completed, id: &mapping.completedPropId, type: "checkbox", properties: properties)
        backfillField(name: &mapping.date, id: &mapping.datePropId, type: "date", properties: properties)
        backfillField(name: &mapping.memo, id: &mapping.memoPropId, type: "rich_text", properties: properties)
        backfillField(name: &mapping.isPinned, id: &mapping.isPinnedPropId, type: "checkbox", properties: properties)
        backfillField(
            name: &mapping.reportRelation,
            id: &mapping.reportRelationPropId,
            type: "relation",
            properties: properties
        )
        for type in CategoryNotionProperty.supportedTypes {
            if backfillField(
                name: &mapping.category,
                id: &mapping.categoryPropId,
                type: type,
                properties: properties
            ) {
                mapping.categoryPropType = type
                return
            }
        }
    }

    static func syncOptionalModes(
        mapping: TodoPropsMapping,
        memoMode: inout PropMappingMode,
        isPinnedMode: inout PropMappingMode,
        reportRelationMode: inout PropMappingMode,
        categoryMode: inout PropMappingMode
    ) {
        memoMode = mapping.memo != nil || mapping.memoPropId != nil ? .existing : .appOnly
        isPinnedMode = mapping.isPinned != nil || mapping.isPinnedPropId != nil ? .existing : .appOnly
        reportRelationMode = mapping.reportRelation != nil || mapping.reportRelationPropId != nil ? .existing : .appOnly
        categoryMode = mapping.category != nil || mapping.categoryPropId != nil ? .existing : .appOnly
    }

    static func applyCompletedSelection(
        mapping: inout TodoPropsMapping,
        propertyId: String?,
        name: String?,
        properties: [NotionProperty]
    ) {
        applyCheckboxSelection(
            name: &mapping.completed,
            id: &mapping.completedPropId,
            propertyId: propertyId,
            propertyName: name,
            properties: properties
        )
    }

    static func applyIsPinnedSelection(
        mapping: inout TodoPropsMapping,
        propertyId: String?,
        name: String?,
        properties: [NotionProperty],
        isPinnedMode: inout PropMappingMode
    ) {
        applyCheckboxSelection(
            name: &mapping.isPinned,
            id: &mapping.isPinnedPropId,
            propertyId: propertyId,
            propertyName: name,
            properties: properties
        )
        isPinnedMode = mapping.isPinnedPropId != nil || mapping.isPinned != nil ? .existing : .appOnly
    }

    static func applyCategorySelection(
        mapping: inout TodoPropsMapping,
        name: String?,
        properties: [NotionProperty],
        categoryMode: inout PropMappingMode
    ) {
        mapping.category = name
        if let name,
           let prop = properties.first(where: {
               $0.name == name && CategoryNotionProperty.supportedTypes.contains($0.type)
           }) {
            mapping.categoryPropId = prop.id
            mapping.categoryPropType = prop.type
            categoryMode = .existing
        } else {
            mapping.categoryPropId = nil
            mapping.categoryPropType = nil
            categoryMode = .appOnly
        }
    }

    // MARK: - Private

    private static func applyInitialSetup(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty]
    ) {
        resolveCheckbox(
            name: &mapping.completed,
            id: &mapping.completedPropId,
            defaultNames: ["완료"],
            properties: properties,
            preserveIfMissing: false
        )
        resolveStandard(
            name: &mapping.date,
            id: &mapping.datePropId,
            type: "date",
            defaultName: "날짜",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: false
        )
        resolveStandard(
            name: &mapping.memo,
            id: &mapping.memoPropId,
            type: "rich_text",
            defaultName: "메모",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: false
        )
        resolveCheckbox(
            name: &mapping.isPinned,
            id: &mapping.isPinnedPropId,
            defaultNames: isPinnedAliasNames,
            properties: properties,
            preserveIfMissing: false,
            excludePropertyIds: excludedCompletedPropertyIds(from: mapping)
        )
        resolveReportRelation(
            name: &mapping.reportRelation,
            id: &mapping.reportRelationPropId,
            properties: properties,
            preserveIfMissing: false
        )
        applyCategoryMapping(mapping: &mapping, properties: properties, preserveIfMissing: false)
    }

    private static func mergePreservingUser(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty]
    ) {
        resolveCheckbox(
            name: &mapping.completed,
            id: &mapping.completedPropId,
            defaultNames: ["완료"],
            properties: properties,
            preserveIfMissing: true
        )
        resolveStandard(
            name: &mapping.date,
            id: &mapping.datePropId,
            type: "date",
            defaultName: "날짜",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: true
        )
        resolveStandard(
            name: &mapping.memo,
            id: &mapping.memoPropId,
            type: "rich_text",
            defaultName: "메모",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: true
        )
        resolveCheckbox(
            name: &mapping.isPinned,
            id: &mapping.isPinnedPropId,
            defaultNames: isPinnedAliasNames,
            properties: properties,
            preserveIfMissing: true,
            excludePropertyIds: excludedCompletedPropertyIds(from: mapping)
        )
        resolveReportRelation(
            name: &mapping.reportRelation,
            id: &mapping.reportRelationPropId,
            properties: properties,
            preserveIfMissing: true
        )
        applyCategoryMapping(mapping: &mapping, properties: properties, preserveIfMissing: true)
    }

    private static func applyCategoryMapping(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty],
        preserveIfMissing: Bool
    ) {
        let orderedTypes: [String]
        if let preferred = mapping.categoryPropType {
            orderedTypes = [preferred] + CategoryNotionProperty.supportedTypes.filter { $0 != preferred }
        } else {
            orderedTypes = CategoryNotionProperty.supportedTypes
        }

        for type in orderedTypes {
            var name = mapping.category
            var id = mapping.categoryPropId
            let hadValue = name != nil || id != nil
            let matched = resolveStandard(
                name: &name,
                id: &id,
                type: type,
                defaultName: "카테고리",
                properties: properties,
                allowFirstFallback: false,
                preserveIfMissing: preserveIfMissing
            )
            if matched {
                mapping.category = name
                mapping.categoryPropId = id
                mapping.categoryPropType = type
                return
            }
            if preserveIfMissing, hadValue, mapping.categoryPropType == type {
                return
            }
        }
        if !preserveIfMissing || (mapping.category == nil && mapping.categoryPropId == nil) {
            mapping.category = nil
            mapping.categoryPropId = nil
            mapping.categoryPropType = nil
        }
    }

    /// checkbox 전용: ID 우선 → 이름 → alias exact match. 동일 유형이 여러 개여도 첫 번째로 폴백하지 않음.
    @discardableResult
    private static func resolveCheckbox(
        name: inout String?,
        id: inout String?,
        defaultNames: [String],
        properties: [NotionProperty],
        preserveIfMissing: Bool,
        excludePropertyIds: Set<String> = []
    ) -> Bool {
        let allCheckbox = properties.filter { $0.type == "checkbox" }
        let candidateCheckbox = excludePropertyIds.isEmpty
            ? allCheckbox
            : allCheckbox.filter { !excludePropertyIds.contains($0.id) }
        let hadValue = name != nil || id != nil

        if preserveIfMissing, let savedId = id {
            if let prop = allCheckbox.first(where: { $0.id == savedId }) {
                name = prop.name
            }
            return true
        }

        if let currentId = id, let prop = allCheckbox.first(where: { $0.id == currentId }) {
            name = prop.name
            id = prop.id
            return true
        }
        if let currentName = name, let prop = allCheckbox.first(where: { $0.name == currentName }) {
            name = prop.name
            id = prop.id
            return true
        }

        if preserveIfMissing, hadValue {
            return false
        }

        for alias in defaultNames {
            if let match = candidateCheckbox.first(where: { propertyNameMatchesAlias($0.name, alias: alias) }) {
                name = match.name
                id = match.id
                return true
            }
        }

        name = nil
        id = nil
        return false
    }

    private static func excludedCompletedPropertyIds(from mapping: TodoPropsMapping) -> Set<String> {
        guard let completedPropId = mapping.completedPropId else { return [] }
        return [completedPropId]
    }

    private static func propertyNameMatchesAlias(_ propertyName: String, alias: String) -> Bool {
        if alias.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
            return propertyName.caseInsensitiveCompare(alias) == .orderedSame
        }
        return propertyName == alias
    }

    private static func applyCheckboxSelection(
        name: inout String?,
        id: inout String?,
        propertyId: String?,
        propertyName: String?,
        properties: [NotionProperty]
    ) {
        if propertyId == nil, propertyName == nil {
            name = nil
            id = nil
            return
        }
        if let propertyId,
           let prop = properties.first(where: { $0.id == propertyId && $0.type == "checkbox" }) {
            name = prop.name
            id = prop.id
            return
        }
        if let propertyName,
           let prop = properties.first(where: { $0.name == propertyName && $0.type == "checkbox" }) {
            name = prop.name
            id = prop.id
            return
        }
        name = propertyName
        id = propertyId
    }

    /// ID 우선 → 이름 → (initialSetup만) 휴리스틱. preserve 시 매칭 실패하면 기존값 유지.
    @discardableResult
    private static func resolveStandard(
        name: inout String?,
        id: inout String?,
        type: String,
        defaultName: String,
        properties: [NotionProperty],
        allowFirstFallback: Bool,
        preserveIfMissing: Bool
    ) -> Bool {
        let typed = properties.filter { $0.type == type }
        let hadValue = name != nil || id != nil

        if preserveIfMissing, let savedId = id {
            if let prop = typed.first(where: { $0.id == savedId }) {
                name = prop.name
            }
            return true
        }

        if let currentId = id, let prop = typed.first(where: { $0.id == currentId }) {
            name = prop.name
            id = prop.id
            return true
        }
        if let currentName = name, let prop = typed.first(where: { $0.name == currentName }) {
            name = prop.name
            id = prop.id
            return true
        }

        if preserveIfMissing, hadValue {
            return false
        }

        if let exact = typed.first(where: { $0.name == defaultName }) {
            name = exact.name
            id = exact.id
            return true
        }
        if allowFirstFallback, typed.count == 1, let only = typed.first {
            name = only.name
            id = only.id
            return true
        }
        if allowFirstFallback, let first = typed.first {
            name = first.name
            id = first.id
            return true
        }

        name = nil
        id = nil
        return false
    }

    private static func resolveReportRelation(
        name: inout String?,
        id: inout String?,
        properties: [NotionProperty],
        preserveIfMissing: Bool
    ) {
        let relations = properties.filter { $0.type == "relation" }
        let hadValue = name != nil || id != nil

        if let currentId = id, let prop = relations.first(where: { $0.id == currentId }) {
            name = prop.name
            id = prop.id
            return
        }
        if let currentName = name, relations.contains(where: { $0.name == currentName }) {
            if let prop = relations.first(where: { $0.name == currentName }) {
                name = prop.name
                id = prop.id
            }
            return
        }

        if preserveIfMissing, hadValue {
            return
        }

        for exactName in reportRelationExactNames {
            if let match = relations.first(where: { $0.name == exactName }) {
                name = match.name
                id = match.id
                return
            }
        }

        name = nil
        id = nil
    }

    @discardableResult
    private static func backfillField(
        name: inout String?,
        id: inout String?,
        type: String,
        properties: [NotionProperty]
    ) -> Bool {
        let typed = properties.filter { $0.type == type }

        guard name != nil || id != nil else {
            id = nil
            return false
        }

        if name == nil {
            id = nil
            return false
        }

        if let currentName = name,
           let propByName = typed.first(where: { $0.name == currentName }) {
            id = propByName.id
            name = propByName.name
            return true
        }

        if let currentId = id,
           let propById = typed.first(where: { $0.id == currentId }) {
            name = propById.name
            return true
        }

        return false
    }
}

// MARK: - 리포트 DB 속성

enum ReportPropsMappingAutoFill {

    static func applyInitialSetup(
        mapping: inout ReportPropsMapping,
        properties: [NotionProperty],
        reviewMode: inout PropMappingMode,
        ratingMode: inout PropMappingMode
    ) {
        resolveStandard(
            name: &mapping.date,
            id: &mapping.datePropId,
            type: "date",
            defaultName: "날짜",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: false
        )
        if resolveStandard(
            name: &mapping.review,
            id: &mapping.reviewPropId,
            type: "rich_text",
            defaultName: "하루 리뷰",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: false
        ) {
            reviewMode = .existing
        }
        let ratingTypes = ["select", "status"]
        for type in ratingTypes {
            if resolveStandard(
                name: &mapping.rating,
                id: &mapping.ratingPropId,
                type: type,
                defaultName: "별점",
                properties: properties,
                allowFirstFallback: true,
                preserveIfMissing: false
            ) {
                applyRatingMetadata(mapping: &mapping, properties: properties)
                ratingMode = .existing
                return
            }
        }
    }

    static func syncFromProperties(mapping: inout ReportPropsMapping, properties: [NotionProperty]) {
        resolveStandard(
            name: &mapping.date,
            id: &mapping.datePropId,
            type: "date",
            defaultName: "날짜",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: true
        )
        resolveStandard(
            name: &mapping.review,
            id: &mapping.reviewPropId,
            type: "rich_text",
            defaultName: "하루 리뷰",
            properties: properties,
            allowFirstFallback: true,
            preserveIfMissing: true
        )
        if let ratingType = mapping.ratingPropType {
            resolveStandard(
                name: &mapping.rating,
                id: &mapping.ratingPropId,
                type: ratingType,
                defaultName: "별점",
                properties: properties,
                allowFirstFallback: false,
                preserveIfMissing: true
            )
        } else {
            for type in ["select", "status"] {
                if resolveStandard(
                    name: &mapping.rating,
                    id: &mapping.ratingPropId,
                    type: type,
                    defaultName: "별점",
                    properties: properties,
                    allowFirstFallback: false,
                    preserveIfMissing: true
                ) {
                    break
                }
            }
        }
        applyRatingMetadata(mapping: &mapping, properties: properties)
        resolveStandard(
            name: &mapping.periodCompletionRate,
            id: &mapping.periodCompletionRatePropId,
            type: "number",
            defaultName: "완료율",
            properties: properties,
            allowFirstFallback: false,
            preserveIfMissing: true
        )
    }

    static func backfillIds(mapping: inout ReportPropsMapping, properties: [NotionProperty]) {
        backfillField(name: &mapping.date, id: &mapping.datePropId, type: "date", properties: properties)
        backfillField(name: &mapping.review, id: &mapping.reviewPropId, type: "rich_text", properties: properties)
        if let ratingType = mapping.ratingPropType {
            backfillField(name: &mapping.rating, id: &mapping.ratingPropId, type: ratingType, properties: properties)
        } else {
            for type in ["select", "status"] {
                if backfillField(name: &mapping.rating, id: &mapping.ratingPropId, type: type, properties: properties) {
                    break
                }
            }
        }
        backfillField(
            name: &mapping.periodCompletionRate,
            id: &mapping.periodCompletionRatePropId,
            type: "number",
            properties: properties
        )
    }

    static func applyRatingSelection(
        mapping: inout ReportPropsMapping,
        name: String?,
        properties: [NotionProperty],
        ratingMode: inout PropMappingMode
    ) {
        mapping.rating = name
        if let name, let prop = properties.first(where: { $0.name == name }) {
            mapping.ratingPropId = prop.id
            mapping.dayRatingOptions = prop.options ?? []
            mapping.ratingPropType = prop.type
            ratingMode = .existing
        } else {
            mapping.ratingPropId = nil
            mapping.dayRatingOptions = []
            mapping.ratingPropType = nil
            ratingMode = .appOnly
        }
    }

    private static func applyRatingMetadata(mapping: inout ReportPropsMapping, properties: [NotionProperty]) {
        guard let name = mapping.rating,
              let prop = properties.first(where: { $0.name == name }) else { return }
        mapping.ratingPropId = prop.id
        mapping.dayRatingOptions = prop.options ?? []
        mapping.ratingPropType = prop.type
    }

    @discardableResult
    private static func resolveStandard(
        name: inout String?,
        id: inout String?,
        type: String,
        defaultName: String,
        properties: [NotionProperty],
        allowFirstFallback: Bool,
        preserveIfMissing: Bool
    ) -> Bool {
        let typed = properties.filter { $0.type == type }
        let hadValue = name != nil || id != nil

        if let currentId = id, let prop = typed.first(where: { $0.id == currentId }) {
            name = prop.name
            id = prop.id
            return true
        }
        if let currentName = name, let prop = typed.first(where: { $0.name == currentName }) {
            name = prop.name
            id = prop.id
            return true
        }

        if preserveIfMissing, hadValue {
            return false
        }

        if let exact = typed.first(where: { $0.name == defaultName }) {
            name = exact.name
            id = exact.id
            return true
        }
        if allowFirstFallback, typed.count == 1, let only = typed.first {
            name = only.name
            id = only.id
            return true
        }
        if allowFirstFallback, let first = typed.first {
            name = first.name
            id = first.id
            return true
        }

        name = nil
        id = nil
        return false
    }

    @discardableResult
    private static func backfillField(
        name: inout String?,
        id: inout String?,
        type: String,
        properties: [NotionProperty]
    ) -> Bool {
        guard id == nil, let currentName = name else { return name != nil }
        guard let prop = properties.first(where: { $0.name == currentName && $0.type == type }) else {
            return false
        }
        id = prop.id
        return true
    }
}
