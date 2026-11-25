import Foundation

/// 카테고리 아이콘 고르기의 한 페이지 (분야 하나).
/// 아이콘 이름은 라인 기본 이름으로 둔다 (`book`). 채움·라인은 카테고리마다 고른다 (`CategoryIconName`).
struct CategoryIconGroup: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let icons: [String]
}
