import Foundation

struct WhatsNewRelease: Identifiable {
    let id: String
    let symbolName: String
    let items: [String]
    let showsPopup: Bool
}
