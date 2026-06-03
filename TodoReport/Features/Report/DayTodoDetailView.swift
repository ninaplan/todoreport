import SwiftUI

struct DayTodoDetailView: View {
    let date: Date

    @State private var todos: [Todo] = []
    @State private var isLoading = true

    private let service = TodoService.shared

    private static let navTitleFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if todos.isEmpty {
                ContentUnavailableView(
                    "할일 없음",
                    systemImage: "checklist",
                    description: Text("이 날은 기록된 할일이 없습니다.")
                )
            } else {
                List {
                    let pinned   = todos.filter {  $0.isPinned && !$0.isCompleted }
                    let normal   = todos.filter { !$0.isPinned && !$0.isCompleted }
                    let completed = todos.filter { $0.isCompleted }
                    ForEach(pinned + normal + completed) { todo in
                        todoRow(todo)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Self.navTitleFmt.string(from: date))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTodos() }
    }

    private func todoRow(_ todo: Todo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.isCompleted ? AppTheme.shared.accent : Color(.tertiaryLabel))
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                if let memo = todo.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if todo.isPinned && !todo.isCompleted {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.584, blue: 0).opacity(0.8))
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.vertical, 4)
    }

    private func loadTodos() async {
        isLoading = true
        todos = await service.fetchTodos(for: date)
        isLoading = false
    }
}
