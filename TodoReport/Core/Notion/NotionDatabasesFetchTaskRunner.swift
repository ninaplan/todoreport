import Foundation

/// DB 목록 fetch Task 중복 실행·강제 새로고침(취소 후 재시작) 공통 처리.
enum NotionDatabasesFetchTaskRunner {
    private static let forceRefreshDelayNanoseconds: UInt64 = 300_000_000

    enum PrepareResult {
        case proceed
        case skip
    }

    static func prepareForFetch(
        existingTask: Task<Void, Never>?,
        forceRefresh: Bool
    ) async -> PrepareResult {
        guard let existing = existingTask else { return .proceed }
        if forceRefresh {
            existing.cancel()
            await existing.value
            try? await Task.sleep(nanoseconds: forceRefreshDelayNanoseconds)
            return .proceed
        }
        await existing.value
        return .skip
    }
}
