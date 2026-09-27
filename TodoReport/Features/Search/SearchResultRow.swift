import SwiftUI

struct SearchResultRow: View {
    let item: SearchResultItem
    let plannerName: String

    var body: some View {
        Group {
            switch item {
            case .todo(let todo):
                todoContent(todo)
            case .review(_, let date, let text, _):
                reviewContent(text: text, date: date)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private func todoContent(_ todo: Todo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todo.title)
                .font(.body)
                .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(todo.isCompleted)
                .lineLimit(2)

            if let memo = todo.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(todoSubtitle(todo))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func reviewContent(text: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("하루 리뷰")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(reviewSubtitle(date: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func todoSubtitle(_ todo: Todo) -> String {
        if let date = todo.date {
            return "\(plannerName) · \(AppDateFormat.reviewTimeline(date))"
        }
        return "\(plannerName) · \(String(localized: "수집함"))"
    }

    private func reviewSubtitle(date: Date) -> String {
        "\(plannerName) · \(AppDateFormat.reviewTimeline(date))"
    }

    private var accessibilityText: String {
        switch item {
        case .todo(let todo):
            var parts = [todo.title]
            if todo.isCompleted {
                parts.append(String(localized: "완료됨"))
            }
            parts.append(todoSubtitle(todo))
            return parts.joined(separator: ", ")
        case .review(_, let date, let text, _):
            return [
                String(localized: "하루 리뷰"),
                text,
                reviewSubtitle(date: date)
            ].joined(separator: ", ")
        }
    }
}
