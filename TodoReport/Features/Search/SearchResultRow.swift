import SwiftUI

struct SearchResultRow: View {
    let todo: Todo
    let plannerName: String

    var body: some View {
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

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var subtitle: String {
        if let date = todo.date {
            return "\(plannerName) · \(AppDateFormat.reviewTimeline(date))"
        }
        return "\(plannerName) · \(String(localized: "인박스"))"
    }

    private var accessibilityText: String {
        var parts = [todo.title]
        if todo.isCompleted {
            parts.append(String(localized: "완료됨"))
        }
        parts.append(subtitle)
        return parts.joined(separator: ", ")
    }
}
