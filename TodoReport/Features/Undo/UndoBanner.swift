import Foundation

/// 화면에 떠 있는 「실행 취소」 배너 1개
struct UndoBanner: Identifiable, Equatable {
    let id: UUID
    let message: String
    let scope: UndoBannerScope
}
