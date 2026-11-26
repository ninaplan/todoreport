import Foundation

/// 타임블록 「제안 블록」: 시간이 있는 반복 할 일을 흐린 블록으로 미리 보여 준다.
/// 저장하지 않는다. 탭해야 진짜 블록(`TimeBlockItem`)이 된다.
/// - 오늘·지난 날: 그날 만들어진 할 일(`todoId` 있음) → 탭하면 블록 생성
/// - 미래 날: 아직 할 일이 없는 「예정」(`todoId` nil) → 탭하면 안내만
/// 길이는 저장하지 않고 화면에서 블록 단위만큼 정한다 (단위를 바꾸면 같이 바뀜)
struct TimeBlockSuggestion: Identifiable, Equatable {
    /// 할 일 id. 미래 예정이면 시리즈 id
    let id: String
    /// 그날 할 일 id. 미래 예정이면 nil
    let todoId: String?
    let title: String
    /// 그날 0시부터 분 (할 일에 정한 시각)
    let startMinute: Int

    var isPreview: Bool { todoId == nil }
}
