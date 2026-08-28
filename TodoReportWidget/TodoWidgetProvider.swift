import WidgetKit
import SwiftUI

// MARK: - 위젯 내부 공유 모델 (Widget Extension 타겟 전용)

struct WidgetTimelineEntry: TimelineEntry {
    let date: Date
    let data: WidgetSnapshotData?
}

struct WidgetSnapshotData: Codable {
    let date: Date
    let plannerName: String
    let completionRate: Double
    let completedCount: Int
    let totalCount: Int
    let todos: [WidgetTodoItem]
}

struct WidgetTodoItem: Codable, Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let isPinned: Bool
}

// MARK: - Placeholder 데이터

private func placeholderData() -> WidgetSnapshotData {
    WidgetSnapshotData(
        date: .now,
        plannerName: "내 플래너",
        completionRate: 0.5,
        completedCount: 3,
        totalCount: 6,
        todos: [
            WidgetTodoItem(id: "1", title: "운동하기", isCompleted: true,  isPinned: false),
            WidgetTodoItem(id: "2", title: "책 읽기 30분", isCompleted: true,  isPinned: false),
            WidgetTodoItem(id: "3", title: "일기 쓰기", isCompleted: true,  isPinned: false),
            WidgetTodoItem(id: "4", title: "물 2L 마시기", isCompleted: false, isPinned: true),
            WidgetTodoItem(id: "5", title: "저녁 요리", isCompleted: false, isPinned: false),
            WidgetTodoItem(id: "6", title: "영어 공부", isCompleted: false, isPinned: false),
        ]
    )
}

// MARK: - Timeline Provider

struct TodoTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetTimelineEntry {
        WidgetTimelineEntry(date: .now, data: placeholderData())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetTimelineEntry) -> Void) {
        let data = context.isPreview ? placeholderData() : WidgetStoreReader.loadTodaySnapshot()
        completion(WidgetTimelineEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimelineEntry>) -> Void) {
        let now = Date.now
        let data = WidgetStoreReader.loadTodaySnapshot()
        let entry = WidgetTimelineEntry(date: now, data: data)

        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(24 * 60 * 60)
        let periodicRefresh = now.addingTimeInterval(4 * 60 * 60)
        let nextRefresh = min(startOfTomorrow, periodicRefresh)

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget Declaration

struct TodoWidget: Widget {
    let kind = "kr.nock.TodoReport.SmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoTimelineProvider()) { entry in
            TodoWidgetEntryView(data: entry.data)
        }
        .configurationDisplayName("투두리포트")
        .description("오늘의 투두 완료율과 목록을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let data: WidgetSnapshotData?

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: data)
        case .systemMedium:
            MediumWidgetView(data: data)
        case .systemLarge:
            LargeWidgetView(data: data)
        default:
            SmallWidgetView(data: data)
        }
    }
}
