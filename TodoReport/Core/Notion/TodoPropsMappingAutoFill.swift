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

    static func syncOptionalModes(
        mapping: TodoPropsMapping,
        memoMode: inout PropMappingMode,
        isPinnedMode: inout PropMappingMode,
        reportRelationMode: inout PropMappingMode,
        categoryMode: inout PropMappingMode
    ) {
        memoMode = mapping.memo != nil ? .existing : .appOnly
        isPinnedMode = mapping.isPinned != nil ? .existing : .appOnly
        reportRelationMode = mapping.reportRelation != nil ? .existing : .appOnly
        categoryMode = mapping.category != nil ? .existing : .appOnly
    }

    // MARK: - Private

    private static func applyInitialSetup(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty]
    ) {
        mapping.completed = resolveStandard(
            current: nil, type: "checkbox", defaultName: "완료",
            properties: properties, allowFirstFallback: true
        )
        mapping.date = resolveStandard(
            current: nil, type: "date", defaultName: "날짜",
            properties: properties, allowFirstFallback: true
        )
        mapping.memo = resolveStandard(
            current: nil, type: "rich_text", defaultName: "메모",
            properties: properties, allowFirstFallback: true
        )
        mapping.isPinned = resolveStandard(
            current: nil, type: "checkbox", defaultName: "중요",
            properties: properties, allowFirstFallback: true
        )
        mapping.reportRelation = resolveReportRelation(current: nil, properties: properties)
        applyCategoryMapping(mapping: &mapping, properties: properties, current: nil)
    }

    private static func mergePreservingUser(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty]
    ) {
        mapping.completed = resolveStandard(
            current: mapping.completed, type: "checkbox", defaultName: "완료",
            properties: properties, allowFirstFallback: true
        )
        mapping.date = resolveStandard(
            current: mapping.date, type: "date", defaultName: "날짜",
            properties: properties, allowFirstFallback: true
        )
        mapping.memo = resolveStandard(
            current: mapping.memo, type: "rich_text", defaultName: "메모",
            properties: properties, allowFirstFallback: true
        )
        mapping.isPinned = resolveStandard(
            current: mapping.isPinned, type: "checkbox", defaultName: "중요",
            properties: properties, allowFirstFallback: true
        )
        mapping.reportRelation = resolveReportRelation(
            current: mapping.reportRelation,
            properties: properties
        )
        applyCategoryMapping(mapping: &mapping, properties: properties, current: mapping.category)
    }

    private static func applyCategoryMapping(
        mapping: inout TodoPropsMapping,
        properties: [NotionProperty],
        current: String?
    ) {
        for type in CategoryNotionProperty.supportedTypes {
            if let resolved = resolveStandard(
                current: current, type: type, defaultName: "카테고리",
                properties: properties, allowFirstFallback: false
            ) {
                mapping.category = resolved
                mapping.categoryPropType = type
                return
            }
        }
        mapping.category = nil
        mapping.categoryPropType = nil
    }

    /// relation 이외 필드: 저장값 유효하면 유지, 아니면 defaultName 일치 → typed.first
    private static func resolveStandard(
        current: String?,
        type: String,
        defaultName: String,
        properties: [NotionProperty],
        allowFirstFallback: Bool
    ) -> String? {
        let typed = properties.filter { $0.type == type }
        if let current, typed.contains(where: { $0.name == current }) {
            return current
        }
        if let exact = typed.first(where: { $0.name == defaultName })?.name {
            return exact
        }
        if allowFirstFallback, typed.count == 1 {
            return typed.first?.name
        }
        return allowFirstFallback ? typed.first?.name : nil
    }

    /// 리포트 relation: exact name만 자동 매핑. 1개여도 first fallback 금지.
    private static func resolveReportRelation(
        current: String?,
        properties: [NotionProperty]
    ) -> String? {
        let relations = properties.filter { $0.type == "relation" }
        if let current, relations.contains(where: { $0.name == current }) {
            return current
        }
        for exactName in reportRelationExactNames {
            if let match = relations.first(where: { $0.name == exactName }) {
                return match.name
            }
        }
        return nil
    }
}
