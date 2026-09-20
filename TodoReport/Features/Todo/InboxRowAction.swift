import SwiftUI

/// 인박스 행 스와이프·컨텍스트 메뉴 액션.
enum InboxRowActionKind: String, CaseIterable, Identifiable {
    case edit
    case moveToToday
    case assignDate
    case snooze
    case bumpToRecent
    case clearSnooze
    case uncomplete
    case delete

    var id: String { rawValue }
}

struct InboxRowAction: Identifiable {
    let kind: InboxRowActionKind
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool

    var id: String { kind.id }
}

enum InboxRowActionCatalog {
    /// trailing: 바깥쪽(full swipe) = 삭제. 안쪽(살짝 스와이프) = 미루기.
    static let nowTrailingSwipe: [InboxRowActionKind] = [.delete, .assignDate, .snooze]
    static let nowContextMenu: [InboxRowActionKind] = [.edit, .moveToToday, .assignDate, .snooze, .bumpToRecent, .delete]

    static let snoozedTrailingSwipe: [InboxRowActionKind] = [.delete, .assignDate]
    static let snoozedContextMenu: [InboxRowActionKind] = [.clearSnooze, .assignDate, .delete]

    /// leading: 자주 쓰는 「오늘하기」(full swipe 가능).
    static let nowLeadingSwipe: [InboxRowActionKind] = [.moveToToday]
    static let snoozedLeadingSwipe: [InboxRowActionKind] = [.clearSnooze]

    static let completedTrailingSwipe: [InboxRowActionKind] = [.delete]
    static let completedContextMenu: [InboxRowActionKind] = [.delete]

    static func resolve(_ kind: InboxRowActionKind) -> InboxRowAction {
        switch kind {
        case .edit:
            return InboxRowAction(
                kind: .edit,
                title: String(localized: "편집"),
                systemImage: "pencil",
                tint: .primary,
                isDestructive: false
            )
        case .moveToToday:
            return InboxRowAction(
                kind: .moveToToday,
                title: String(localized: "오늘하기"),
                systemImage: "sun.max",
                tint: .blue,
                isDestructive: false
            )
        case .assignDate:
            return InboxRowAction(
                kind: .assignDate,
                title: String(localized: "날짜 넣기"),
                systemImage: "calendar",
                tint: Color(red: 1, green: 0.584, blue: 0),
                isDestructive: false
            )
        case .snooze:
            return InboxRowAction(
                kind: .snooze,
                title: String(localized: "미루기"),
                systemImage: "clock",
                tint: .gray,
                isDestructive: false
            )
        case .bumpToRecent:
            return InboxRowAction(
                kind: .bumpToRecent,
                title: String(localized: "위로 올리기"),
                systemImage: "arrow.up",
                tint: .blue,
                isDestructive: false
            )
        case .clearSnooze:
            return InboxRowAction(
                kind: .clearSnooze,
                title: String(localized: "지금 보기로"),
                systemImage: "tray",
                tint: .blue,
                isDestructive: false
            )
        case .uncomplete:
            return InboxRowAction(
                kind: .uncomplete,
                title: String(localized: "되돌리기"),
                systemImage: "arrow.uturn.backward",
                tint: .blue,
                isDestructive: false
            )
        case .delete:
            return InboxRowAction(
                kind: .delete,
                title: String(localized: "삭제"),
                systemImage: "trash",
                tint: .red,
                isDestructive: true
            )
        }
    }

    static func nowTrailingActions() -> [InboxRowAction] {
        nowTrailingSwipe.map { resolve($0) }
    }

    static func nowContextActions() -> [InboxRowAction] {
        nowContextMenu.map { resolve($0) }
    }

    static func snoozedTrailingActions() -> [InboxRowAction] {
        snoozedTrailingSwipe.map { resolveSnoozed($0) }
    }

    static func snoozedContextActions() -> [InboxRowAction] {
        snoozedContextMenu.map { resolveSnoozed($0) }
    }

    static func nowLeadingActions() -> [InboxRowAction] {
        nowLeadingSwipe.map { resolve($0) }
    }

    static func snoozedLeadingActions() -> [InboxRowAction] {
        snoozedLeadingSwipe.map { resolve($0) }
    }

    static func completedTrailingActions() -> [InboxRowAction] {
        completedTrailingSwipe.map { resolve($0) }
    }

    static func completedContextActions() -> [InboxRowAction] {
        completedContextMenu.map { resolve($0) }
    }

    private static func resolveSnoozed(_ kind: InboxRowActionKind) -> InboxRowAction {
        if kind == .assignDate {
            return InboxRowAction(
                kind: .assignDate,
                title: String(localized: "날짜 다시 정하기"),
                systemImage: "calendar",
                tint: Color(red: 1, green: 0.584, blue: 0),
                isDestructive: false
            )
        }
        return resolve(kind)
    }
}
