import Foundation

/// 빈 칸을 눌렀을 때 만들 블록의 시간 범위 (고르기 시트용).
struct TimeBlockSlotRequest: Identifiable, Equatable {
    let id = UUID()
    let day: Date
    let startMinute: Int
    let endMinute: Int
}
