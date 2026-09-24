import Foundation

/// 플래너별 기분 저장 방식. nil(미설정)만 자동 연결 대상이다.
enum MoodStorageMode: String, Codable, Equatable {
    case notion
    case appOnly
    case disabled
}
