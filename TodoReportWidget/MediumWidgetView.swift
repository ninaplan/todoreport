import SwiftUI
import WidgetKit

// MARK: - Medium Widget (systemMedium)
// 왼쪽: 완료율 + 날짜, 오른쪽: 투두 목록 (최대 4개)

struct MediumWidgetView: View {
    let data: WidgetSnapshotData?

    private var rate: Double    { data?.completionRate  ?? 0 }
    private var completed: Int  { data?.completedCount  ?? 0 }
    private var total: Int      { data?.totalCount      ?? 0 }
    private var planner: String { data?.plannerName     ?? "투두리포트" }
    private var todos: [WidgetTodoItem] { data?.todos.prefix(4).map { $0 } ?? [] }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // ── 왼쪽: 통계 ──
            VStack(alignment: .leading, spacing: 4) {
                Text(planner)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(rate * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(nockOrangeW)

                Text("\(completed)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(todayString)
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.top, 2)
            }
            .frame(width: 70)

            // 구분선
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 0.5)
                .padding(.vertical, 2)

            // ── 오른쪽: 투두 목록 ──
            VStack(alignment: .leading, spacing: 6) {
                if todos.isEmpty {
                    Spacer()
                    Text("투두를 추가해보세요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                } else {
                    ForEach(todos) { todo in
                        todoRow(todo)
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }

    private func todoRow(_ todo: WidgetTodoItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(todo.isCompleted ? nockOrangeW : Color(.systemGray4))

            Text(todo.title)
                .font(.caption)
                .foregroundStyle(todo.isCompleted ? Color(.secondaryLabel) : .primary)
                .strikethrough(todo.isCompleted, color: Color(.secondaryLabel))
                .lineLimit(1)
        }
    }

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: .now)
    }
}

private let nockOrangeW = Color(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255)
