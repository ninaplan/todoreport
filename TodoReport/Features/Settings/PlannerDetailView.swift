import SwiftUI
import PhotosUI

struct PlannerDetailView: View {
    private let plannerId: String
    private let initialPlanner: Planner
    // PlannerService.shared는 @Observable — store 변경 시 자동 re-render
    private var currentPlanner: Planner {
        PlannerService.shared.store.first(where: { $0.id == plannerId }) ?? initialPlanner
    }
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIconType: String?
    @State private var selectedIconImageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showIconSheet = false
    @State private var showResetNotionAlert = false
    @State private var showMigrationModeAlert = false
    @State private var showMigrationSheet = false
    @State private var selectedMigrationMode: PlannerMigrationViewModel.SyncMode?
    @State private var showPlannerDeleteAlert = false
    @State private var activeCategoryCount: Int?

    private var canDeletePlanner: Bool {
        PlannerService.shared.store.count > 1
    }

    private static let sfSymbols: [String] = [
        // 플래너/학습/업무
        "book.fill", "doc.text.fill", "pencil", "note.text", "briefcase.fill", "graduationcap.fill",
        // 일상/생활
        "house.fill", "heart.fill", "star.fill", "fork.knife", "figure.run",
        // 기타
        "brain.head.profile", "dumbbell.fill", "bicycle", "leaf.fill",
        "chart.line.uptrend.xyaxis", "clock.fill", "flag.fill",
        "cart.fill", "car.fill", "creditcard.fill",
        "music.note", "paintbrush.fill", "camera.fill", "gamecontroller.fill"
    ]

    init(planner: Planner) {
        self.plannerId = planner.id
        self.initialPlanner = planner
        _name = State(initialValue: planner.name)
        _selectedIconType = State(initialValue: planner.iconType)
        _selectedIconImageData = State(initialValue: planner.iconImageData)
    }

    var body: some View {
        List {
            if currentPlanner.isReadOnly {
                Section {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("읽기 전용 플래너입니다. Pro 구독 시 다시 활성화됩니다.")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            profileHeaderSection
            itemsSection
            if currentPlanner.isNotionConnected {
                notionSection
            } else {
                connectNotionSection
            }
            if canDeletePlanner {
                deletePlannerSection
            }
            bottomSpacerSection
        }
        .disabled(currentPlanner.isReadOnly)
        .navigationTitle("플래너 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { Task { await savePlanner(); dismiss() } }
                    .toolbarPrimaryActionStyle(isEnabled: !currentPlanner.isReadOnly)
                    .disabled(currentPlanner.isReadOnly)
            }
        }
        .onAppear {
            Task { await reloadItemSummaries() }
        }
        .sheet(isPresented: $showIconSheet) {
            iconPickerSheet
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showMigrationSheet) {
            PlannerMigrationView(planner: currentPlanner, mode: selectedMigrationMode ?? .uploadToNotion)
        }
        .alert("로컬 데이터를 어떻게 할까요?", isPresented: $showMigrationModeAlert) {
            Button("노션에 함께 저장하기") { confirmUploadToNotion() }
            Button("버리고 시작하기", role: .destructive) { confirmDiscardLocal() }
            Button("취소", role: .cancel) { cancelMigrationMode() }
        } message: {
            Text("노션에 연결하면 노션 데이터가 앱에 연결됩니다.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    selectedIconType = "photo"
                    selectedIconImageData = data
                }
            }
        }
        .alert("노션 연결 해제", isPresented: $showResetNotionAlert) {
            Button("취소", role: .cancel) { }
            Button("해제", role: .destructive) {
                Task { await PlannerService.shared.resetNotionConnection(for: currentPlanner); dismiss() }
            }
        } message: {
            Text("노션 연결이 끊어지며, 이 플래너는 로컬 플래너로 전환됩니다. 투두·리포트 데이터는 그대로 유지돼요.")
        }
        .alert("플래너 삭제", isPresented: $showPlannerDeleteAlert) {
            Button("취소", role: .cancel) { showPlannerDeleteAlert = false }
            Button("삭제", role: .destructive) {
                Task { await deletePlanner() }
            }
        } message: {
            Text(currentPlanner.deleteConfirmationMessage)
        }
    }

    // MARK: - 프로필 헤더

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                Button { showIconSheet = true } label: {
                    ZStack(alignment: .bottomTrailing) {
                        PlannerIconView(
                            iconType: selectedIconType,
                            iconImageData: selectedIconImageData,
                            colorHex: currentPlanner.colorHex,
                            size: 64
                        )
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.shared.accent)
                            .background(Color(.systemBackground), in: Circle())
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    PlannerNameField(
                        text: $name,
                        placeholder: String(localized: "플래너 이름"),
                        textStyle: .headline,
                        isEnabled: !currentPlanner.isReadOnly
                    )
                    .accessibilityHint(String(localized: "이름 수정"))
                    Text(currentPlanner.isNotionConnected ? "Notion 연결됨" : "기기에 저장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 항목

    private var itemsSection: some View {
        Section("항목") {
            NavigationLink {
                CategoryView(plannerId: plannerId)
                    .onDisappear {
                        Task { await reloadItemSummaries() }
                    }
            } label: {
                LabeledContent("카테고리") {
                    if let activeCategoryCount {
                        Text(String(localized: "\(activeCategoryCount)개"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            NavigationLink {
                MoodEditorView(plannerId: plannerId)
                    .onDisappear {
                        Task { await reloadItemSummaries() }
                    }
            } label: {
                LabeledContent("기분") {
                    Text(moodModeLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var moodModeLabel: String {
        switch MoodService.shared.storageMode(for: plannerId) {
        case .notion:
            return String(localized: "노션 연동")
        case .disabled:
            return String(localized: "사용 안 함")
        case .appOnly, nil:
            return String(localized: "앱에서만")
        }
    }

    private func reloadItemSummaries() async {
        activeCategoryCount = await CategoryService.shared.activeCategoryCount(for: plannerId)
    }

    // MARK: - 하단 여백

    private var bottomSpacerSection: some View {
        Section {
            Color.clear
                .frame(height: 120)
                .accessibilityHidden(true)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - 아이콘 선택 시트

    private var iconPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("사진에서 선택", systemImage: "photo")
                            .foregroundStyle(.primary)
                    }
                    if selectedIconType != nil {
                        Button("아이콘 제거", role: .destructive) {
                            selectedIconType = nil
                            selectedIconImageData = nil
                            showIconSheet = false
                        }
                    }
                } header: {
                    Text("사진")
                }

                Section {
                    iconSymbolGrid
                } header: {
                    Text("SF Symbol")
                }
            }
            .navigationTitle("아이콘 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { showIconSheet = false }
                        .toolbarPrimaryActionStyle()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var iconSymbolGrid: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 6)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Self.sfSymbols, id: \.self) { symbol in
                Button {
                    selectedIconType = symbol
                    selectedIconImageData = nil
                    showIconSheet = false
                } label: {
                    let isSelected = selectedIconType == symbol
                    ZStack {
                        Circle()
                            .fill(isSelected ? AppTheme.shared.accent : Color(.systemGray5))
                            .frame(width: 44, height: 44)
                        Image(systemName: symbol)
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? .white : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: selectedIconType)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 노션 설정 (연결된 플래너)

    private var notionSection: some View {
        Section("노션 설정") {
            NavigationLink {
                PlannerNotionSettingsView(planner: currentPlanner, scope: .todo)
            } label: { Text("투두 DB") }
            NavigationLink {
                PlannerNotionSettingsView(planner: currentPlanner, scope: .report)
            } label: { Text("리포트 DB") }
            Button(role: .destructive) {
                showResetNotionAlert = true
            } label: {
                Text("노션 연결 해제")
            }
        }
    }

    // MARK: - 노션 연결 (로컬 플래너)

    private var connectNotionSection: some View {
        Section {
            Button {
                showMigrationModeAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("노션 플래너와 연결하기")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(AppTheme.shared.accent)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Notion 연동")
        } footer: {
            Text("로컬 데이터를 Notion과 연결해요")
        }
    }

    // MARK: - 플래너 삭제

    private var deletePlannerSection: some View {
        Section {
            Button(role: .destructive) {
                showPlannerDeleteAlert = true
            } label: {
                Text("플래너 삭제")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Migration Mode Alert

    private func cancelMigrationMode() {
        showMigrationModeAlert = false
    }

    private func confirmUploadToNotion() {
        selectedMigrationMode = .uploadToNotion
        showMigrationSheet = true
    }

    private func confirmDiscardLocal() {
        selectedMigrationMode = .importFromNotion
        showMigrationSheet = true
    }

    // MARK: - Helpers

    private func savePlanner() async {
        var updated = currentPlanner
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        updated.name = trimmed.isEmpty ? currentPlanner.name : trimmed
        updated.iconType = selectedIconType
        updated.iconImageData = selectedIconImageData
        try? await PlannerService.shared.savePlanner(updated)
    }

    private func deletePlanner() async {
        showPlannerDeleteAlert = false
        try? await PlannerService.shared.deletePlanner(currentPlanner)
        dismiss()
    }
}
