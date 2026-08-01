import SwiftUI

/// 투두 행에서 스와이프·컨텍스트 메뉴가 공유하는 액션 종류.
/// 새 액션은 여기와 `TodoRowActionCatalog` 배열에만 추가하면 된다.
enum TodoRowActionKind: String, CaseIterable, Identifiable {
    case edit
    case pin
    case moveToTomorrow
    case changeDate
    case delete

    var id: String { rawValue }
}

/// 액션 한 항목의 표시·역할 정의 (실행은 View가 kind로 디스패치).
struct TodoRowAction: Identifiable {
    let kind: TodoRowActionKind
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool

    var id: String { kind.id }
}

/// 스와이프·메뉴 기본 구성. 추후 사용자 커스텀 시 이 배열만 교체하면 된다.
enum TodoRowActionCatalog {
    /// trailing 스와이프 렌더 순서: 먼저 선언된 항목이 바깥쪽(full swipe = 삭제).
    static let trailingSwipe: [TodoRowActionKind] = [.delete, .changeDate, .moveToTomorrow]
    static let leadingSwipe: [TodoRowActionKind] = [.pin]
    static let contextMenu: [TodoRowActionKind] = [.edit, .pin, .moveToTomorrow, .changeDate, .delete]

    static func resolve(_ kind: TodoRowActionKind, todo: Todo) -> TodoRowAction {
        switch kind {
        case .edit:
            return TodoRowAction(
                kind: .edit,
                title: String(localized: "편집"),
                systemImage: "pencil",
                tint: .primary,
                isDestructive: false
            )
        case .pin:
            if todo.isPinned {
                return TodoRowAction(
                    kind: .pin,
                    title: String(localized: "고정 해제"),
                    systemImage: "pin.slash",
                    tint: .gray,
                    isDestructive: false
                )
            }
            return TodoRowAction(
                kind: .pin,
                title: String(localized: "고정"),
                systemImage: "pin",
                tint: Color(red: 1, green: 0.584, blue: 0),
                isDestructive: false
            )
        case .moveToTomorrow:
            return TodoRowAction(
                kind: .moveToTomorrow,
                title: String(localized: "내일로"),
                systemImage: "sunrise",
                tint: .blue,
                isDestructive: false
            )
        case .changeDate:
            return TodoRowAction(
                kind: .changeDate,
                title: String(localized: "날짜 변경"),
                systemImage: "calendar",
                tint: Color(red: 1, green: 0.584, blue: 0),
                isDestructive: false
            )
        case .delete:
            return TodoRowAction(
                kind: .delete,
                title: String(localized: "삭제"),
                systemImage: "trash",
                tint: .red,
                isDestructive: true
            )
        }
    }

    static func trailingSwipeActions(for todo: Todo) -> [TodoRowAction] {
        trailingSwipe.map { resolve($0, todo: todo) }
    }

    static func leadingSwipeActions(for todo: Todo) -> [TodoRowAction] {
        leadingSwipe.map { resolve($0, todo: todo) }
    }

    static func contextMenuActions(for todo: Todo) -> [TodoRowAction] {
        contextMenu.map { resolve($0, todo: todo) }
    }
}
