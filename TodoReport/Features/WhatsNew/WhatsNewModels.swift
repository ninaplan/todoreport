import Foundation

struct WhatsNewRelease: Identifiable {
    struct PopupItem: Identifiable {
        let symbolName: String
        let title: String
        let description: String
        /// Assets Catalog 이미지 이름. nil이면 미리보기 없음.
        let previewImageName: String?
        /// true면 제목 옆에 Pro 배지. 이미 Pro인 사용자는 `ProBadge`가 숨긴다.
        let isPro: Bool

        var id: String { title }

        init(
            symbolName: String,
            title: String,
            description: String,
            previewImageName: String? = nil,
            isPro: Bool = false
        ) {
            self.symbolName = symbolName
            self.title = title
            self.description = description
            self.previewImageName = previewImageName
            self.isPro = isPro
        }
    }

    let id: String
    let symbolName: String
    let items: [String]
    let showsPopup: Bool
    /// 팝업 상단에 할일 행 미리보기 표시. false면 기존처럼 SF Symbol.
    let showsTodoRowPreview: Bool
    /// 항목 목록 아래 강조 안내. nil이면 표시하지 않음.
    let notice: String?
    let popupTitle: String?
    let popupSubtitle: String?
    let popupItems: [PopupItem]
    let popupButtonTitle: String?

    var usesFeaturedPopup: Bool { !popupItems.isEmpty }

    init(
        id: String,
        symbolName: String,
        items: [String],
        showsPopup: Bool,
        showsTodoRowPreview: Bool = false,
        notice: String? = nil,
        popupTitle: String? = nil,
        popupSubtitle: String? = nil,
        popupItems: [PopupItem] = [],
        popupButtonTitle: String? = nil
    ) {
        self.id = id
        self.symbolName = symbolName
        self.items = items
        self.showsPopup = showsPopup
        self.showsTodoRowPreview = showsTodoRowPreview
        self.notice = notice
        self.popupTitle = popupTitle
        self.popupSubtitle = popupSubtitle
        self.popupItems = popupItems
        self.popupButtonTitle = popupButtonTitle
    }
}
