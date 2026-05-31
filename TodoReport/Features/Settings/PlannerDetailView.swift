import SwiftUI
import PhotosUI

struct PlannerDetailView: View {
    private let planner: Planner
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIconType: String?
    @State private var selectedIconImageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showIconSheet = false
    @State private var showDeleteAlert = false
    @State private var showResetNotionAlert = false
    @State private var showMigrationSheet = false

    private static let sfSymbols: [String] = [
        "book.fill", "pencil", "graduationcap.fill", "brain.head.profile", "note.text",
        "figure.run", "dumbbell.fill", "heart.fill", "bicycle", "leaf.fill",
        "briefcase.fill", "doc.text.fill", "chart.line.uptrend.xyaxis", "clock.fill", "flag.fill",
        "house.fill", "cart.fill", "fork.knife", "car.fill", "creditcard.fill",
        "music.note", "paintbrush.fill", "camera.fill", "star.fill", "gamecontroller.fill"
    ]

    private var totalPlannerCount: Int { PlannerService.shared.store.count }

    init(planner: Planner) {
        self.planner = planner
        _name = State(initialValue: planner.name)
        _selectedIconType = State(initialValue: planner.iconType)
        _selectedIconImageData = State(initialValue: planner.iconImageData)
    }

    var body: some View {
        List {
            profileHeaderSection
            basicSection
            categorySection
            if planner.isNotionConnected {
                notionSection
            } else {
                connectNotionSection
            }
            if totalPlannerCount > 1 {
                deleteSection
            }
        }
        .navigationTitle("플래너 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { Task { await savePlanner(); dismiss() } }
                    .tint(AppTheme.shared.accent)
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showIconSheet) {
            iconPickerSheet
        }
        .sheet(isPresented: $showMigrationSheet) {
            PlannerMigrationView(planner: planner)
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
        .alert("플래너 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                Task { try? await PlannerService.shared.deletePlanner(planner); dismiss() }
            }
        } message: {
            Text("플래너를 삭제하면 해당 플래너의 모든 데이터가 삭제됩니다. 계속할까요?")
        }
        .alert("연동 초기화", isPresented: $showResetNotionAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                Task { await PlannerService.shared.resetNotionConnection(for: planner); dismiss() }
            }
        } message: {
            Text("앱에 저장된 데이터가 모두 삭제됩니다. 노션 데이터는 유지됩니다.")
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
                            colorHex: planner.colorHex,
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
                    Text(name.isEmpty ? planner.name : name)
                        .font(.headline)
                    Text(planner.isNotionConnected ? "Notion 연결됨" : "로컬 저장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 기본

    private var basicSection: some View {
        Section("기본") {
            LabeledContent("이름") {
                TextField("플래너 이름", text: $name)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - 아이콘 선택 시트

    private var iconPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    iconSymbolGrid
                } header: {
                    Text("SF Symbol")
                }

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
            }
            .navigationTitle("아이콘 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { showIconSheet = false }
                        .tint(AppTheme.shared.accent)
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
                            .fill(isSelected ? Color.nockOrange : Color(.systemGray5))
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

    // MARK: - 카테고리

    private var categorySection: some View {
        Section("카테고리") {
            NavigationLink { CategoryView() } label: { Text("카테고리 관리") }
        }
    }

    // MARK: - 노션 설정 (연결된 플래너)

    private var notionSection: some View {
        Section("노션 설정") {
            NavigationLink {
                PlannerNotionSettingsView(planner: planner, scope: .todo)
            } label: { Text("투두 DB") }
            NavigationLink {
                PlannerNotionSettingsView(planner: planner, scope: .report)
            } label: { Text("리포트 DB") }
            Button(role: .destructive) {
                showResetNotionAlert = true
            } label: {
                Text("연동 초기화")
            }
        }
    }

    // MARK: - 노션 연결 (로컬 플래너)

    private var connectNotionSection: some View {
        Section {
            Button {
                showMigrationSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(AppTheme.shared.accent)
                    Text("노션 플래너와 연결하기")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Notion 연동")
        } footer: {
            Text("로컬 데이터를 Notion과 연결해요")
        }
    }

    // MARK: - 삭제

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("플래너 삭제")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Helpers

    private func savePlanner() async {
        var updated = planner
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        updated.name = trimmed.isEmpty ? planner.name : trimmed
        updated.iconType = selectedIconType
        updated.iconImageData = selectedIconImageData
        try? await PlannerService.shared.savePlanner(updated)
    }
}
