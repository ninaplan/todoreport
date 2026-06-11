import SwiftUI
import WidgetKit

// MARK: - Medium Widget (systemMedium)
// 왼쪽: 완료율 + 날짜, 오른쪽: 투두 목록 (최대 4개)

struct MediumWidgetView: View {
    let data: WidgetSnapshotData?
    let isPro: Bool

    private var rate: Double    { data?.completionRate  ?? 0 }
    private var completed: Int  { data?.completedCount  ?? 0 }
    private var total: Int      { data?.totalCount      ?? 0 }
    private var planner: String { data?.plannerName     ?? "투두리포트" }
    private var todos: [WidgetTodoItem] { data?.todos.prefix(4).map { $0 } ?? [] }

    var body: some View {
        if isPro {
            contentView
        } else {
            ProLockedWidgetView(message: "투두 목록 위젯은 Pro 기능이에요")
        }
    }

    private var contentView: some View {
        HStack(alignment: .top, spacing: 14) {

            // ── 왼쪽: 통계 ──
            VStack(alignment: .leading, spacing: 6) {
                Text(planner)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(Int(rate * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(nockOrange)

                Text("\(completed)/\(total)개")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(todayString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 2)
            }
            .frame(width: 88)

            // 구분선
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 0.5)
                .padding(.vertical, 2)

            // ── 오른쪽: 투두 목록 ──
            VStack(alignment: .leading, spacing: 8) {
                if todos.isEmpty {
                    Spacer()
                    Text("투두를 추가해보세요")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                } else {
                    ForEach(todos) { todo in
                        todoRow(todo)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "todoreport://todo"))
        .containerBackground(.background, for: .widget)
    }

    private func todoRow(_ todo: WidgetTodoItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(todo.isCompleted ? nockOrange : Color(.systemGray4))

            Text(todo.title)
                .font(.subheadline)
                .foregroundStyle(todo.isCompleted ? Color(.secondaryLabel) : .primary)
                .strikethrough(todo.isCompleted, color: Color(.secondaryLabel))
                .lineLimit(1)
        }
    }

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: .now)
    }
}

private let nockOrange = Color(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255)

