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
