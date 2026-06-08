import SwiftUI

struct PlannerNotionSettingsView: View {

    enum Scope { case todo, report }

    @State private var viewModel: PlannerNotionSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    let scope: Scope

    init(planner: Planner, scope: Scope) {
        self.scope = scope
        _viewModel = State(initialValue: PlannerNotionSettingsViewModel(planner: planner))
    }

    var body: some View {
        List {
            switch scope {
            case .todo:
                todoDBSection
                if !viewModel.todoProperties.isEmpty { todoPropsSection }
            case .report:
                reportDBSection
                if !viewModel.reportProperties.isEmpty { reportPropsSection }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(scope == .todo ? "투두 DB" : "리포트 DB")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    Task {
                        await viewModel.save()
                        dismiss()
                    }
                }
                .toolbarPrimaryActionStyle(isEnabled: !viewModel.isLoading)
                .disabled(viewModel.isLoading)
            }
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .task {
            await viewModel.fetchDatabases()
            switch scope {
            case .todo:
                if viewModel.selectedTodoDBId != nil { await viewModel.fetchTodoProperties() }
            case .report:
                if viewModel.selectedReportDBId != nil { await viewModel.fetchReportProperties(autoMap: false) }
            }
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.clearAlert() } }
        )) {
            Button("확인") { viewModel.clearAlert() }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    // MARK: - 투두 DB

    private var todoDBSection: some View {
        Section {
            SettingsDBPickerRow(
                label: "투두 DB",
                databases: viewModel.databases,
                selectedId: viewModel.selectedTodoDBId,
                isLoading: viewModel.isLoading && viewModel.databases.isEmpty,
                onSelect: { viewModel.selectTodoDB($0) }
            )
        } header: {
            Text("투두 데이터베이스")
        }
    }

    // MARK: - 투두 속성 매핑

    private var todoPropsSection: some View {
        Section {
            SettingsPropMappingRow(
                label: "완료", isRequired: true,
                candidates: viewModel.todoProperties.filter { $0.type == "checkbox" },
                fallback: viewModel.todoProperties,
                selection: $viewModel.todoPropsMapping.completed
            )
            SettingsPropMappingRow(
                label: "날짜", isRequired: true,
                candidates: viewModel.todoProperties.filter { $0.type == "date" },
                fallback: viewModel.todoProperties,
                selection: $viewModel.todoPropsMapping.date
            )
            SettingsOptionalPropRow(
                label: "메모",
                candidates: viewModel.todoProperties.filter { $0.type == "rich_text" },
                mode: $viewModel.memoMode,
                selection: $viewModel.todoPropsMapping.memo,
                onCreate: { Task { await viewModel.createMemoProperty() } }
            )
            SettingsOptionalPropRow(
                label: "상단고정",
                candidates: viewModel.todoProperties.filter { $0.type == "checkbox" },
                mode: $viewModel.isPinnedMode,
                selection: $viewModel.todoPropsMapping.isPinned,
                onCreate: { Task { await viewModel.createPinnedProperty() } }
            )
            SettingsOptionalPropRow(
                label: "카테고리",
                candidates: CategoryNotionProperty.candidates(from: viewModel.todoProperties),
                mode: $viewModel.categoryMode,
                selection: Binding(
                    get: { viewModel.todoPropsMapping.category },
                    set: { viewModel.selectCategory($0) }
                ),
                onCreate: { Task { await viewModel.createCategoryProperty() } }
            )
            if viewModel.selectedReportDBId != nil {
                SettingsOptionalPropRow(
                    label: "리포트 연결",
                    candidates: viewModel.todoProperties.filter { $0.type == "relation" },
                    mode: $viewModel.reportRelationMode,
                    selection: $viewModel.todoPropsMapping.reportRelation
                )
            }
        } header: {
            Text("투두 속성 매핑")
        }
    }

    // MARK: - 리포트 DB

    private var reportDBSection: some View {
        Section {
            SettingsDBPickerRow(
                label: "리포트 DB",
                databases: viewModel.databases,
                selectedId: viewModel.selectedReportDBId,
                isLoading: viewModel.isLoading && viewModel.databases.isEmpty,
                onSelect: { viewModel.selectReportDB($0) }
            )
        } header: {
            Text("데일리리포트 데이터베이스")
        } footer: {
            Text("연결하지 않으면 리포트는 앱 내에서만 저장됩니다.")
        }
    }

    // MARK: - 리포트 속성 매핑

    private var reportPropsSection: some View {
        Section("리포트 속성 매핑") {
            SettingsPropMappingRow(
                label: "날짜", isRequired: true,
                candidates: viewModel.reportProperties.filter { $0.type == "date" },
                fallback: viewModel.reportProperties,
                selection: $viewModel.reportPropsMapping.date
            )
            SettingsOptionalPropRow(
                label: "하루 리뷰",
                candidates: viewModel.reportProperties.filter { $0.type == "rich_text" },
                mode: $viewModel.reviewMode,
                selection: $viewModel.reportPropsMapping.review
            )
            SettingsOptionalPropRow(
                label: "별점",
                candidates: viewModel.reportProperties.filter { $0.type == "select" || $0.type == "status" },
                mode: $viewModel.ratingMode,
                selection: Binding(
                    get: { viewModel.reportPropsMapping.rating },
                    set: { viewModel.selectRating($0) }
                ),
                onCreate: { Task { await viewModel.createRatingProperty() } }
            )
        }
    }
}

// MARK: - DB 선택 행

private struct SettingsDBPickerRow: View {
    let label: String
    let databases: [NotionDatabase]
    let selectedId: String?
    let isLoading: Bool
    let onSelect: (String) -> Void

    private var selectedTitle: String? {
        databases.first(where: { $0.id == selectedId })?.title
    }

    var body: some View {
        if isLoading {
            HStack {
                Text(label)
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
            }
        } else {
            Menu {
                ForEach(databases) { db in
                    Button {
                        onSelect(db.id)
                    } label: {
                        if db.id == selectedId {
                            Label(db.title, systemImage: "checkmark")
                        } else {
                            Text(db.title)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(label)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let title = selectedTitle {
                        HStack(spacing: 4) {
                            Image(systemName: "tablecells")
                                .font(.caption)
                            Text(title)
                        }
                        .foregroundStyle(AppTheme.shared.accent)
                        .lineLimit(1)
                    } else {
                        Text("선택하세요")
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 필수 속성 행

private struct SettingsPropMappingRow: View {
    let label: String
    var isRequired: Bool = false
    let candidates: [NotionProperty]
    let fallback: [NotionProperty]
    @Binding var selection: String?

    private var options: [NotionProperty] {
        candidates.isEmpty ? fallback : candidates
    }

    private var iconName: String {
        propTypeIcon(for: candidates.first?.type ?? fallback.first?.type, label: label)
    }

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            HStack(spacing: 6) {
                Text(label)
                if isRequired {
                    SettingsSmallTag(text: "필수")
                }
            }
            Spacer()
            Picker("", selection: $selection) {
                Text("선택 안 함").tag(nil as String?)
                ForEach(options, id: \.name) { prop in
                    Text(prop.name).tag(prop.name as String?)
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
        }
    }
}

// MARK: - 선택 속성 행

private struct SettingsOptionalPropRow: View {
    let label: String
    let candidates: [NotionProperty]
    @Binding var mode: PropMappingMode
    @Binding var selection: String?
    var isRecommended: Bool = false
    var onCreate: (() -> Void)? = nil
    var hint: String? = nil

    private var iconName: String {
        propTypeIcon(for: candidates.first?.type, label: label)
    }

    private var displayLabel: String {
        switch mode {
        case .appOnly:  return "앱에만 저장"
        case .existing: return selection ?? "선택 안 함"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            HStack(spacing: 6) {
                Text(label)
                if isRecommended {
                    SettingsSmallTag(text: "권장")
                }
            }
            Spacer()
            Menu {
                Button("앱에만 저장") {
                    mode = .appOnly
                    selection = nil
                }
                if let onCreate {
                    Button("생성하기") { onCreate() }
                }
                if !candidates.isEmpty {
                    Divider()
                    ForEach(candidates, id: \.name) { prop in
                        Button(prop.name) {
                            mode = .existing
                            selection = prop.name
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(displayLabel)
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        if let hint, candidates.isEmpty {
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
        }
    }
}

// MARK: - 태그

private struct SettingsSmallTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .foregroundStyle(Color(.secondaryLabel))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
