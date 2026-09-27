import Foundation

enum MoodPropsAutoFill {
    static let notionPropertyName = "기분"

    /// 모드가 미설정일 때만, 이름이 정확히 「기분」인 select를 연결하고 모드를 notion으로 둔다.
    static func autoConnectIfUnset(mapping: inout ReportPropsMapping, properties: [NotionProperty]) {
        guard mapping.moodMode == nil else { return }
        guard let prop = selectableMoodProperty(in: properties, mapping: mapping) else { return }
        mapping.mood = prop.name
        mapping.moodPropId = prop.id
        mapping.moodMode = .notion
    }

    /// 미설정이면 자동 연결하고, 이미 notion인데 id만 비어 있으면 id만 채운다.
    static func backfillIfNeeded(mapping: inout ReportPropsMapping, properties: [NotionProperty]) {
        autoConnectIfUnset(mapping: &mapping, properties: properties)
        guard mapping.moodMode == .notion, mapping.moodPropId == nil, let name = mapping.mood else { return }
        guard let prop = properties.first(where: { $0.type == "select" && $0.name == name }) else { return }
        if isUsedByRating(prop, mapping: mapping) { return }
        mapping.moodPropId = prop.id
    }

    enum MoodUserSelection {
        case notionProperty(NotionProperty)
        case appOnly
        case disabled
    }

    enum MoodUserSelectionOutcome {
        /// 사용 안 함으로 처음 바꿀 때만 다시 켤 모드가 있다. 이미 사용 안 함이면 nil.
        case applied(restoreModeOnDisable: String?)
        case rejected
    }

    static func usageRestoreDefaultsKey(plannerId: String) -> String {
        "moodUsageRestoreMode.\(plannerId)"
    }

    /// 끄기 직전 모드. 미설정은 appOnly로 기억해 자동 연결 대상(nil)으로 돌아가지 않는다.
    static func restoreModeRawValue(beforeDisable: MoodStorageMode?) -> String? {
        switch beforeDisable {
        case .notion:
            return MoodStorageMode.notion.rawValue
        case .appOnly, nil:
            return MoodStorageMode.appOnly.rawValue
        case .disabled:
            return nil
        }
    }

    /// 사용자가 고른 기분 저장 방식. 별점에 연결된 속성은 거절한다.
    static func applyUserSelection(
        mapping: inout ReportPropsMapping,
        selection: MoodUserSelection
    ) -> MoodUserSelectionOutcome {
        switch selection {
        case .notionProperty(let property):
            guard property.type == "select" else { return .rejected }
            if ReportPropsMappingAutoFill.isLinkedProperty(
                property,
                linkedId: mapping.ratingPropId,
                linkedName: mapping.rating
            ) {
                return .rejected
            }
            mapping.mood = property.name
            mapping.moodPropId = property.id
            mapping.moodMode = .notion
            return .applied(restoreModeOnDisable: nil)
        case .appOnly:
            mapping.mood = nil
            mapping.moodPropId = nil
            mapping.moodMode = .appOnly
            return .applied(restoreModeOnDisable: nil)
        case .disabled:
            let restore = restoreModeRawValue(beforeDisable: mapping.moodMode)
            mapping.moodMode = .disabled
            return .applied(restoreModeOnDisable: restore)
        }
    }

    /// 별점의 첫 속성 폴백이 건너뛸 속성. 이름 「기분」과 기분에 연결된 속성.
    static func ratingFallbackExclusion(mapping: ReportPropsMapping) -> (ids: Set<String>, names: Set<String>) {
        var names: Set<String> = [notionPropertyName]
        var ids = Set<String>()
        if let name = mapping.mood {
            names.insert(name)
        }
        if let id = mapping.moodPropId {
            ids.insert(id)
        }
        return (ids, names)
    }

    private static func selectableMoodProperty(
        in properties: [NotionProperty],
        mapping: ReportPropsMapping
    ) -> NotionProperty? {
        properties.first { property in
            property.type == "select"
                && property.name == notionPropertyName
                && !isUsedByRating(property, mapping: mapping)
        }
    }

    private static func isUsedByRating(_ property: NotionProperty, mapping: ReportPropsMapping) -> Bool {
        if let ratingPropId = mapping.ratingPropId, ratingPropId == property.id {
            return true
        }
        if let ratingName = mapping.rating, ratingName == property.name {
            return true
        }
        return false
    }
}
