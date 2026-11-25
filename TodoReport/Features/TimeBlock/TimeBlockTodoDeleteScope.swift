import Foundation

/// 타임블록 팝업에서 「할 일까지 삭제」할 때 범위
enum TimeBlockTodoDeleteScope {
    /// 이 할 일 하나 (반복이면 이번 것만)
    case single
    /// 반복 할 일의 이번 것부터 이후 모두
    case allFuture
}
