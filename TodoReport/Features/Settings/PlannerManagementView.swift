import SwiftUI

// MARK: - 플래너 관리

struct PlannerManagementView: View {
    private var planners: [Planner] { PlannerService.shared.store }
    private var selectedPlannerId: String { PlannerService.shared.selectedPlannerId }

    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showAddPlannerSheet = false
    @State private var showPaywall = false
    @State private var plannerPendingDelete: Planner?
    @State private var showPlannerDeleteAlert = false
    @State private var showLastPlannerAlert = false
    @Environment(\.editMode) private var editMode

    private var isPro: Bool { subscriptionManager.isPro }
    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    var body: some View {
        List {
            ForEach(planners) { planner in
                PlannerManagementRow(
                    planner: planner,
                    isSelected: planner.id == selectedPlannerId,
                    isEditing: isEditing,
                    onDelete: { requestDeletePlanner(planner) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        requestDeletePlanner(planner)
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                }
            }
            .onMove(perform: movePlanners)

            Button {
                guard isPro else { showPaywall = true; return }
                showAddPlannerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                    Text("플래너 추가")
                        .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                    if !isPro { ProBadge() }
                }
            }
        }
        .navigationTitle("플래너 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddPlannerSheet) {
            PlannerAddView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("플래너 삭제", isPresented: $showPlannerDeleteAlert) {
            Button("취소", role: .cancel) { cancelDeletePlanner() }
            Button("삭제", role: .destructive) {
                Task { await confirmDeletePlanner() }
            }
        } message: {
            if let planner = plannerPendingDelete {
                Text(planner.deleteConfirmationMessage)
            }
        }
        .alert("플래너 삭제", isPresented: $showLastPlannerAlert) {
            Button("확인", role: .cancel) { showLastPlannerAlert = false }
        } message: {
            Text("최소 1개의 플래너가 필요해요.")
        }
    }

    private func movePlanners(from source: IndexSet, to destination: Int) {
        var ordered = planners
        ordered.move(fromOffsets: source, toOffset: destination)
        PlannerService.shared.reorderPlanners(ordered)
    }

    private func requestDeletePlanner(_ planner: Planner) {
        if planners.count <= 1 {
            showLastPlannerAlert = true
            return
        }
        plannerPendingDelete = planner
        showPlannerDeleteAlert = true
    }

    private func cancelDeletePlanner() {
        plannerPendingDelete = nil
        showPlannerDeleteAlert = false
    }

    private func confirmDeletePlanner() async {
        guard let planner = plannerPendingDelete else { return }
        plannerPendingDelete = nil
        showPlannerDeleteAlert = false
        try? await PlannerService.shared.deletePlanner(planner)
    }
}

// MARK: - 플래너 관리 행

private struct PlannerManagementRow: View {
    let planner: Planner
    let isSelected: Bool
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Group {
                if isEditing {
                    rowLabel
                } else {
                    NavigationLink {
                        PlannerDetailView(planner: planner)
                    } label: {
                        rowLabel
                    }
                    .disabled(planner.isReadOnly)
                    .opacity(planner.isReadOnly ? 0.4 : 1.0)
                }
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 10) {
            PlannerIconView(
                iconType: planner.iconType,
                iconImageData: planner.iconImageData,
                colorHex: planner.colorHex,
                size: 28
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(planner.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                    if isSelected {
                        Text("사용중")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.shared.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.shared.accent.opacity(0.15), in: Capsule())
                    }
                }
                if planner.isReadOnly {
                    Text("Pro 구독 시 다시 활성화됩니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if planner.isNotionConnected {
                NotionBadge()
            }
        }
    }
}

// MARK: - 플래너 행 (설정·관리 공용)

struct PlannerRow: View {
    let planner: Planner

    var body: some View {
        HStack(spacing: 10) {
            PlannerIconView(
                iconType: planner.iconType,
                iconImageData: planner.iconImageData,
                colorHex: planner.colorHex,
                size: 28
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(planner.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if planner.isReadOnly {
                    Text("Pro 구독 시 다시 활성화됩니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if planner.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if planner.isNotionConnected {
                NotionBadge()
            }
        }
    }
}
