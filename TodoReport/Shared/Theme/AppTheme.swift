import SwiftUI

@Observable
final class AppTheme {
    static let shared = AppTheme()
    private init() {}

    // 포인트 컬러 고정 — 노크 오렌지 (#FD6845)
    let accent: Color = .nockOrange
}
