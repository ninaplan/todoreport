import Foundation

enum TimeBlockError: Error, Equatable {
    /// 다른 블록과 시간이 겹침
    case overlap
    /// 끝이 시작보다 빠르거나 하루를 벗어남
    case invalidRange
    /// 읽기 전용(구독 만료) 플래너
    case readOnlyPlanner
    case saveFailed
}
