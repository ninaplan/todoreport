import Foundation

/// 별점 이름(「별점」 대신 보일 이름)·아이콘·색 편집. 플래너마다 따로 저장
@Observable
final class RatingLabelEditViewModel {
    private let plannerId: String
    private let savedLabel: String?
    private let savedIcon: String?
    private let savedColorHex: String?

    /// 입력 칸. 최대 글자 수를 넘으면 잘라 둔다
    var text: String {
        didSet {
            guard text.count > RatingLabel.maxLength else { return }
            text = String(text.prefix(RatingLabel.maxLength))
        }
    }

    /// nil = 기본 ⭐
    private(set) var icon: String?
    /// nil = 아이콘별 기본색. 직접 고르면 아이콘을 바꿔도 그 색을 유지
    private(set) var colorHex: String?

    init(plannerId: String) {
        self.plannerId = plannerId
        let planner = PlannerService.shared.store.first(where: { $0.id == plannerId })
        let normalized = RatingLabel.normalized(planner?.ratingLabel)
        self.savedLabel = normalized
        self.text = normalized ?? ""
        self.savedIcon = planner?.ratingIcon
        self.savedColorHex = planner?.ratingColorHex
        self.icon = planner?.ratingIcon
        self.colorHex = planner?.ratingColorHex
    }

    var countText: String {
        "\(text.count)/\(RatingLabel.maxLength)"
    }

    /// 미리보기·색 고르기에 쓰는 지금 모양
    var previewStyle: RatingStyle {
        RatingStyle(icon: icon, colorHex: colorHex)
    }

    var isDefaultIcon: Bool { icon == nil }

    /// 아이콘 고르기에 넘길 이름 (기본 ⭐일 때는 어떤 칸도 선택되지 않게 빈 이름)
    var pickerIcon: String { icon ?? "" }

    /// 저장된 값과 다를 때만 저장 버튼을 켠다
    var hasChanges: Bool {
        RatingLabel.normalized(text) != savedLabel
            || icon != savedIcon
            || (icon == nil ? nil : colorHex) != savedColorHex
    }

    /// 이름·아이콘·색 중 하나라도 기본이 아니면 「원래대로 되돌리기」를 보여 준다
    var canResetToDefault: Bool {
        RatingLabel.normalized(text) != nil || icon != nil
    }

    /// 이름·아이콘·색을 모두 기본(「별점」·⭐)으로. 저장은 「저장」에서
    func resetToDefault() {
        text = ""
        icon = nil
        colorHex = nil
    }

    // MARK: - 아이콘·색

    /// 색 버튼에 칠할 색. 기본 ⭐일 때는 별 기본색(노랑)
    var colorButtonHex: String {
        icon == nil ? RatingStyle.defaultColorHex(for: Self.defaultSymbol) : previewStyle.resolvedColorHex
    }

    func selectIcon(_ symbol: String) {
        icon = symbol
    }

    /// 색을 고르면 바로 미리보기에 반영. 기본 ⭐ 이모지는 색을 칠할 수 없어 같은 모양의 별 아이콘으로 바꾼다
    func selectColor(_ hex: String) {
        if icon == nil { icon = Self.defaultSymbol }
        colorHex = hex
    }

    func save() {
        PlannerService.shared.setRatingLabel(text, plannerId: plannerId)
        PlannerService.shared.setRatingStyle(icon: icon, colorHex: colorHex, plannerId: plannerId)
    }

    /// 기본 ⭐에서 색을 고를 때 쓰는 별 아이콘
    private static let defaultSymbol = "star.fill"
}
