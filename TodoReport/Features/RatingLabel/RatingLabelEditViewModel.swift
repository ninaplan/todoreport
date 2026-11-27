import Foundation

/// 별점 이름(「별점」 대신 보일 이름) 편집. 플래너마다 따로 저장
@Observable
final class RatingLabelEditViewModel {
    private let plannerId: String
    private let savedLabel: String?

    /// 입력 칸. 최대 글자 수를 넘으면 잘라 둔다
    var text: String {
        didSet {
            guard text.count > RatingLabel.maxLength else { return }
            text = String(text.prefix(RatingLabel.maxLength))
        }
    }

    init(plannerId: String) {
        self.plannerId = plannerId
        let current = PlannerService.shared.store.first(where: { $0.id == plannerId })?.ratingLabel
        let normalized = RatingLabel.normalized(current)
        self.savedLabel = normalized
        self.text = normalized ?? ""
    }

    var countText: String {
        "\(text.count)/\(RatingLabel.maxLength)"
    }

    /// 저장된 값과 다를 때만 저장 버튼을 켠다
    var hasChanges: Bool {
        RatingLabel.normalized(text) != savedLabel
    }

    /// 지금 이름이 기본(「별점」)이 아니면 「기본으로 되돌리기」를 보여 준다
    var canResetToDefault: Bool {
        RatingLabel.normalized(text) != nil
    }

    func resetToDefault() {
        text = ""
    }

    func save() {
        PlannerService.shared.setRatingLabel(text, plannerId: plannerId)
    }
}
