import WidgetKit

struct WidgetTodo {
    let id: String
    let title: String
    let isCompleted: Bool
}

struct WidgetCategoryStat {
    let name: String
    let colorHex: String
    let rate: Double
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let completionRate: Double
    let completedCount: Int
    let totalCount: Int
    let todos: [WidgetTodo]
    let categoryStats: [WidgetCategoryStat]
}

extension WidgetEntry {
    static let placeholder = WidgetEntry(
        date: .now,
        completionRate: 0.75,
        completedCount: 3,
        totalCount: 5,
        todos: [
            WidgetTodo(id: "1", title: "수학 문제 풀기",  isCompleted: true),
            WidgetTodo(id: "2", title: "영어 단어 30개", isCompleted: true),
            WidgetTodo(id: "3", title: "독서 30분",      isCompleted: false),
            WidgetTodo(id: "4", title: "운동하기",        isCompleted: false),
            WidgetTodo(id: "5", title: "장보기",          isCompleted: false),
            WidgetTodo(id: "6", title: "일기 쓰기",       isCompleted: false),
        ],
        categoryStats: [
            WidgetCategoryStat(name: "공부", colorHex: "4A90D9", rate: 0.83),
            WidgetCategoryStat(name: "운동", colorHex: "E8794A", rate: 0.60),
            WidgetCategoryStat(name: "독서", colorHex: "5BAD72", rate: 0.75),
        ]
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // TODO: App Group 통해 실제 데이터 로드
        let entry = WidgetEntry.placeholder
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
