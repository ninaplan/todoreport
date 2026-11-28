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
        /// 이 구간에 계획한 블록 시간 (카테고리 id → 분). 월간 막대 탭 시 「계획」 표시용
        var plannedMinutesByCategory: [String: Int] = [:]

        var totalMinutes: Int { segments.reduce(0) { $0 + $1.minutes } }
    }

    struct CategoryUsage: Identifiable, Equatable {
        let id: String
        let name: String
        let colorHex: String
        let completedMinutes: Int
        let plannedMinutes: Int
    }

    /// 주간 시간표용: 블록 한 칸 (어느 날·몇 시부터 몇 시까지·무슨 색·완료 여부)
    struct PlacedBlock: Identifiable, Equatable {
        let id: String
        /// `buckets` 인덱스 (주간 = 요일 칸)
        let bucketIndex: Int
        let startMinute: Int
        let endMinute: Int
        let colorHex: String
        let isCompleted: Bool
    }

    static let uncategorizedKey = "__uncategorized__"
    static let uncategorizedColorHex = "#AEAEB2"

    /// 집중 시간 (완료한 블록 시간 합)
    let completedMinutes: Int
    /// 계획한 블록 시간 합
    let plannedMinutes: Int
    let buckets: [Bucket]
    let categories: [CategoryUsage]
    var blocks: [PlacedBlock] = []

    var hasBlocks: Bool { plannedMinutes > 0 }

    static let empty = TimeBlockUsageSummary(completedMinutes: 0, plannedMinutes: 0, buckets: [], categories: [])
}
