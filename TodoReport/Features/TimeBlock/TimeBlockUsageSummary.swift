import Foundation

/// 리포트 「시간 사용」·「집중 시간」용 집계. 완료한 블록 시간 = 집중 시간 (타이머 도입 전 1차 기준).
struct TimeBlockUsageSummary: Equatable {
    struct Segment: Identifiable, Equatable {
        /// 카테고리 id (미분류는 `uncategorizedKey`)
        let id: String
        let colorHex: String
        let minutes: Int
    }

    struct Bucket: Identifiable, Equatable {
        let id: Int
        let label: String
        /// 완료한 블록 시간을 카테고리별로 쌓은 막대
        let segments: [Segment]

        var totalMinutes: Int { segments.reduce(0) { $0 + $1.minutes } }
    }

    struct CategoryUsage: Identifiable, Equatable {
        let id: String
        let name: String
        let colorHex: String
        let completedMinutes: Int
        let plannedMinutes: Int
    }

    static let uncategorizedKey = "__uncategorized__"
    static let uncategorizedColorHex = "#8E8E93"

    /// 집중 시간 (완료한 블록 시간 합)
    let completedMinutes: Int
    /// 계획한 블록 시간 합
    let plannedMinutes: Int
    let buckets: [Bucket]
    let categories: [CategoryUsage]

    var hasBlocks: Bool { plannedMinutes > 0 }

    static let empty = TimeBlockUsageSummary(completedMinutes: 0, plannedMinutes: 0, buckets: [], categories: [])
}
