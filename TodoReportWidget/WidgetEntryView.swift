import SwiftUI
import WidgetKit

// MARK: - 날짜 포맷

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "M월 d일 E"
    return f
}()

private let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "M.d E"
    return f
}()

// MARK: - Entry View (사이즈 분기)

struct WidgetEntryView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small (2×2)

struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(shortDateFormatter.string(from: entry.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.nockOrange.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: entry.completionRate)
                    .stroke(
                        Color.nockOrange,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(Int(entry.completionRate * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nockOrange)
                }
            }
            .padding(.horizontal, 4)

            Spacer()

            Text("\(entry.completedCount)/\(entry.totalCount)개 완료")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "todoreport://todo"))
    }
}

// MARK: - Medium (4×2)

struct MediumWidgetView: View {
    let entry: WidgetEntry

    private var visibleTodos: [WidgetTodo] { Array(entry.todos.prefix(3)) }
    private var remainingCount: Int { max(0, entry.todos.count - 3) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack(alignment: .firstTextBaseline) {
                Text(dateFormatter.string(from: entry.date))
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(entry.completionRate * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.nockOrange)
                Text("완료")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: entry.completionRate)
                .tint(Color.nockOrange)
                .scaleEffect(y: 0.7, anchor: .center)
                .padding(.top, 4)
                .padding(.bottom, 8)

            // 투두 목록
            VStack(alignment: .leading, spacing: 6) {
                ForEach(visibleTodos, id: \.id) { todo in
                    TodoRowView(todo: todo)
                }
                if remainingCount > 0 {
                    Text("+\(remainingCount)개 더")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 22)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "todoreport://todo"))
    }
}

// MARK: - Large (4×4)

struct LargeWidgetView: View {
    let entry: WidgetEntry

    private var visibleTodos: [WidgetTodo] { Array(entry.todos.prefix(6)) }
    private var remainingCount: Int { max(0, entry.todos.count - 6) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack(alignment: .firstTextBaseline) {
                Text(dateFormatter.string(from: entry.date))
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(entry.completionRate * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.nockOrange)
                Text("완료")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: entry.completionRate)
                .tint(Color.nockOrange)
                .scaleEffect(y: 0.7, anchor: .center)
                .padding(.top, 4)
                .padding(.bottom, 10)

            // 투두 목록
            VStack(alignment: .leading, spacing: 7) {
                ForEach(visibleTodos, id: \.id) { todo in
                    TodoRowView(todo: todo)
                }
                if remainingCount > 0 {
                    Text("+\(remainingCount)개 더")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 22)
                }
            }

            Spacer(minLength: 0)

            // 카테고리 달성률
            if !entry.categoryStats.isEmpty {
                Divider().padding(.bottom, 10)

                Text("카테고리 달성률")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.categoryStats, id: \.name) { stat in
                        CategoryStatRow(stat: stat)
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "todoreport://todo"))
    }
}

// MARK: - 공통 서브뷰

private struct TodoRowView: View {
    let todo: WidgetTodo

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(todo.isCompleted ? Color.nockOrange : Color(.tertiaryLabel))

            Text(todo.title)
                .font(.subheadline)
                .strikethrough(todo.isCompleted, color: .secondary)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)
        }
    }
}

private struct CategoryStatRow: View {
    let stat: WidgetCategoryStat

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: stat.colorHex))
                .frame(width: 6, height: 6)

            Text(stat.name)
                .font(.caption2)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: stat.colorHex).opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: stat.colorHex))
                        .frame(width: geo.size.width * stat.rate, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(Int(stat.rate * 100))%")
                .font(.caption2.bold())
                .foregroundStyle(Color(hex: stat.colorHex))
                .frame(width: 30, alignment: .trailing)
        }
    }
}
