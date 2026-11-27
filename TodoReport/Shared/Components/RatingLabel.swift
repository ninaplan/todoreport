import Foundation

/// 「별점」 대신 사용자가 정한 이름(플래너별)을 화면 문구로 바꿔 주는 곳.
/// 화면에 보이는 이름만 바뀐다. 노션 속성명 「별점」·저장 값은 그대로 (속성명을 바꾸면 기존 데이터 연결이 끊김)
enum RatingLabel {
    /// 하루 리포트 카드 줄이 좁아서 5글자까지
    static let maxLength = 5

    /// 앞뒤 공백 제거 + 최대 글자 수로 자르기. 비면 nil(기본 「별점」)
    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    /// 지금 선택된 플래너의 이름 (없으면 nil = 기본)
    static var current: String? {
        normalized(PlannerService.shared.selectedPlanner?.ratingLabel)
    }

    /// 「별점」 / 사용자가 정한 이름 (사용자 이름은 언어와 상관없이 쓴 그대로)
    static func title(_ custom: String?) -> String {
        custom ?? String(localized: "별점")
    }

    /// 「별점 평균」 / 「기분 평균」
    static func averageTitle(_ custom: String?) -> String {
        guard let custom else { return String(localized: "별점 평균") }
        return String(localized: "\(custom) 평균")
    }

    /// 「별점 데이터가 없습니다.」 / 「기분 데이터가 없습니다.」
    static func emptyText(_ custom: String?) -> String {
        guard let custom else { return String(localized: "별점 데이터가 없습니다.") }
        return String(localized: "\(custom) 데이터가 없습니다.")
    }
}
