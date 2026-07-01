import Foundation

enum TodoDateAccess {
    /// 모든 날짜 조회 허용.
    static func canView(date: Date, isPro: Bool) -> Bool {
        true
    }
}
