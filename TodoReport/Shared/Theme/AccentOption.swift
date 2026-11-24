import Foundation

/// 포인트 컬러 팔레트 한 칸
struct AccentOption: Identifiable, Equatable {
    let hex: String
    let name: String

    var id: String { hex }
}
