import SwiftUI
import WidgetKit

// MARK: - Large Widget (systemLarge)
// 헤더: 플래너 이름 + 완료율 + 날짜, 본문: 투두 전체 목록 (최대 8개)

struct LargeWidgetView: View {
    let data: WidgetSnapshotData?

    private var rate: Double    { data?.completionRate  ?? 0 }
    private var completed: Int  { data?.completedCount  ?? 0 }
    private var total: Int      { data?.totalCount      ?? 0 }
    private var planner: String { data?.plannerName     ?? "투두리포트" }
    private var todos: [WidgetTodoItem] { data?.todos.prefix(8).map { $0 } ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── 헤더 ──
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(planner)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(todayString)
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(rate * 100))%")
                        .font(.title2.bold())
                        .foregroundStyle(nockOrange)
                    Text("\(completed)/\(total)개")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 진행 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 5)
                    Capsule()
                        .fill(nockOrange)
                        .frame(width: geo.size.width * CGFloat(rate), height: 5)
                }
            }
            .frame(height: 5)

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)

            // ── 투두 목록 ──
            if todos.isEmpty {
                Spacer()
                Text("오늘의 투두를 추가해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // 상단 고정 항목 먼저
                    let pinned  = todos.filter {  $0.isPinned && !$0.isCompleted }
                    let normal  = todos.filter { !$0.isPinned && !$0.isCompleted }
                    let done    = todos.filter {  $0.isCompleted }

                    ForEach(pinned  + normal + done) { todo in
                        todoRow(todo)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }

    private func todoRow(_ todo: WidgetTodoItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : (todo.isPinned ? "pin.circle.fill" : "circle"))
                .font(.system(size: 16))
                .foregroundStyle(todo.isCompleted ? nockOrange : (todo.isPinned ? .orange : Color(.systemGray4)))

            Text(todo.title)
                .font(.subheadline)
                .foregroundStyle(todo.isCompleted ? Color(.secondaryLabel) : .primary)
                .strikethrough(todo.isCompleted, color: Color(.secondaryLabel))
                .lineLimit(1)
        }
    }

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일 (E)"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: .now)
    }
}

private let nockOrange = Color(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255)
