import SwiftUI

/// 리포트 「카테고리별 완료율」 원형 보기.
/// 한 줄에 3개, 왼쪽 정렬(남는 칸은 비워 둠). 링을 탭하면 그 줄 바로 아래에 할 일 목록이 열린다.
/// 이 기간에 할 일이 없는 카테고리는 회색 링 + 「–」
struct CategoryRingGrid: View {
    let stats: [CategoryStat]

    // 레이아웃 숫자는 여기서만 바꾼다 (링 크기·한 줄 개수·간격)
    private enum Layout {
        static let columns = 3
        static let ringSize: CGFloat = 58
        static let lineWidth: CGFloat = 6
        static let cellWidth: CGFloat = 88
        static let cellSpacing: CGFloat = 12
        static let rowSpacing: CGFloat = 14
        /// 꽉 찬 줄의 폭. 모든 줄을 이 폭 안에서 왼쪽 정렬 → 줄마다 링 위치가 맞는다
        static var gridWidth: CGFloat {
            CGFloat(columns) * cellWidth + CGFloat(columns - 1) * cellSpacing
        }
        /// 기록 없음 회색
        static let emptyColor = Color(.systemGray3)
    }

    /// 열린 카테고리 (이름으로 구분 — 리포트를 다시 불러와도 같은 카테고리가 열려 있게)
    @State private var selectedName: String?

    private var rows: [[CategoryStat]] {
        stride(from: 0, to: stats.count, by: Layout.columns).map {
            Array(stats[$0..<min($0 + Layout.columns, stats.count)])
        }
    }

    var body: some View {
        VStack(spacing: Layout.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Layout.cellSpacing) {
                    ForEach(row) { stat in
                        ringCell(stat)
                    }
                }
                .frame(width: Layout.gridWidth, alignment: .leading)
                .frame(maxWidth: .infinity)

                if let selected = row.first(where: { $0.name == selectedName }) {
                    CategoryRingDetailPanel(stat: selected)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedName)
        .onChange(of: stats.map(\.name)) { _, names in
            // 기간이 바뀌어 그 카테고리가 없어지면 닫는다
            if let selectedName, !names.contains(selectedName) {
                self.selectedName = nil
            }
        }
    }

    private func ringCell(_ stat: CategoryStat) -> some View {
        let isSelected = selectedName == stat.name
        let isDimmed = selectedName != nil && !isSelected
        let color = stat.hasRecords ? Color(hex: stat.colorHex) : Layout.emptyColor
        return Button {
            selectedName = isSelected ? nil : stat.name
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(stat.hasRecords ? 0.15 : 0.45), lineWidth: Layout.lineWidth)
                    if stat.hasRecords {
                        Circle()
                            .trim(from: 0, to: max(0, min(stat.rate, 1)))
                            .stroke(color, style: StrokeStyle(lineWidth: Layout.lineWidth, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(stat.rate.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    } else {
                        // 0%(했는데 못 끝냄)와 구분: 아예 기록 없음
                        Text(verbatim: "–")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: Layout.ringSize, height: Layout.ringSize)
                .padding(Layout.lineWidth / 2)

                Text(stat.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : (stat.hasRecords ? .secondary : .tertiary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: Layout.cellWidth)
            .contentShape(Rectangle())
            .opacity(isDimmed ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 링 아래에 열리는 할 일 목록
private struct CategoryRingDetailPanel: View {
    let stat: CategoryStat

    private var incompleteTodos: [ReportTodoEntry] {
        stat.todos.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var completedTodos: [ReportTodoEntry] {
        stat.todos.filter { $0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var nameColor: Color {
        stat.isUncategorized ? Color(.label) : Color(hex: stat.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: CategoryIconName.resolved(stat.icon))
                    .font(.system(size: 12))
                    .foregroundStyle(nameColor)
                Text(stat.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(nameColor)
                Spacer()
                Text("\(stat.completed)/\(stat.total)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if stat.todos.isEmpty {
                Text("이 기간에 기록된 할일이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // 반복 할 일은 이름이 같아서 날짜로 구분
                ForEach(incompleteTodos) { todo in
                    ReportTodoRow(todo: todo, showsDate: true) { openTodoFromRow(todo) }
                }
                ForEach(completedTodos) { todo in
                    ReportTodoRow(todo: todo, showsDate: true) { openTodoFromRow(todo) }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
