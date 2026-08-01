import Foundation

struct WhatsNewRelease: Identifiable {
    let id: String
    let symbolName: String
    let items: [String]
    let showsPopup: Bool
    /// 팝업 상단에 할일 행 미리보기 표시. false면 기존처럼 SF Symbol.
    let showsTodoRowPreview: Bool

    init(
        id: String,
        symbolName: String,
        items: [String],
        showsPopup: Bool,
        showsTodoRowPreview: Bool = false
    ) {
        self.id = id
        self.symbolName = symbolName
        self.items = items
        self.showsPopup = showsPopup
        self.showsTodoRowPreview = showsTodoRowPreview
    }
}
