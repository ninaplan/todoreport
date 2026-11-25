import SwiftUI

/// 카테고리 편집 「색상」: 위 탭(노션 · 클래식 · 모던 · 파스텔 · 커스텀) + 칩 12칸 (6칸 × 2줄).
/// - 세트 탭: 12색 그대로
/// - 커스텀 탭: 저장된 색(최대 11) + 맨 끝 「＋ 추가」. 추가는 iOS 색 고르기 창을 닫을 때 고른 색 하나만 들어가고, 이 카테고리 색은 안 바뀐다
///   (여러 번 눌러 팔레트를 한꺼번에 채울 수 있게). 「편집」을 누르면 칩마다 ⊖가 붙어 뺄 수 있다
/// 탭은 보기만 바꾼다 (플래너 세트는 칩을 골라 저장할 때 바뀜 — `CategoryViewModel`).
struct CategoryColorSetPicker: View {
    let selectedHex: String
    let setId: String
    let onSelectSet: (String) -> Void
    let onSelect: (String) -> Void
    let onAddCustom: (String) -> Void
    let onRemoveCustom: (String) -> Void
    /// 이번 편집에서 뺀 색 (대문자). 지금 색이어도 첫 칸에 다시 보여 주지 않는다
    var removedHexes: Set<String> = []

    @State private var isAddingCustom = false
    /// 색 고르기 창에서 고르는 중인 색. 창이 닫힐 때 커스텀에 넣는다
    @State private var pendingCustomHex: String?
    /// 커스텀 「편집」: 칩마다 ⊖가 붙고 누르면 그 색이 빠진다
    /// (목록 안에서는 길게 누르기 메뉴가 줄 전체에 하나만 붙어 엉뚱한 색이 빠졌음 → 편집 방식으로)
    @State private var isEditingCustom = false

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)
    private static let chip: CGFloat = 36

    private var isCustomTab: Bool { setId == CategoryColorSet.customId }
    private var customStore: CategoryCustomColorStore { CategoryCustomColorStore.shared }

    /// 지금 색이 어느 세트에도 없으면(예전에 직접 고른 색) 커스텀 탭 첫 칸에 잠깐 보여 준다 (저장하면 정식으로 들어감)
    private var unsavedCurrentHex: String? {
        guard CategoryColorSet.setId(containing: selectedHex) == nil,
              !removedHexes.contains(selectedHex.uppercased()) else { return nil }
        return selectedHex
    }

    private var colors: [String] {
        guard isCustomTab else {
            return Array(CategoryColorSet.colors(for: setId).prefix(CategoryColorSet.colorCount))
        }
        // 색 고르기 창이 열려 있으면 고르는 중인 색을 맨 앞에 미리 보여 준다 (창을 닫으면 정식으로 들어감)
        let pending = isAddingCustom ? pendingCustomHex : nil
        let saved = customStore.colors.filter { $0.uppercased() != pending?.uppercased() }
        let shown = [pending, unsavedCurrentHex].compactMap { $0 } + saved
        return Array(shown.prefix(CategoryCustomColorStore.maxCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("색 세트", selection: setBinding) {
                ForEach(CategoryColorSet.all) { set in
                    Text(set.title).tag(set.id)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(colors, id: \.self) { hex in
                    colorChip(hex)
                }
                if isCustomTab, !isEditingCustom {
                    addChip
                }
            }

            if isCustomTab {
                HStack(alignment: .firstTextBaseline) {
                    if let customHint {
                        Text(customHint)
                            .font(.footnote)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    Spacer(minLength: 8)
                    if !customStore.colors.isEmpty {
                        Button(isEditingCustom ? "완료" : "편집") {
                            isEditingCustom.toggle()
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .onChange(of: setId) { _, _ in isEditingCustom = false }
        .onChange(of: customStore.colors.isEmpty) { _, isEmpty in
            if isEmpty { isEditingCustom = false }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isAddingCustom, onDismiss: commitPendingCustom) {
            CategoryColorPickerSheet(
                onPick: { pendingCustomHex = $0 },
                onFinish: { isAddingCustom = false }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var customHint: LocalizedStringKey? {
        if isEditingCustom { return "빼려는 색을 누르세요." }
        if customStore.colors.isEmpty { return "＋를 눌러 색을 모아 두세요." }
        if customStore.colors.count >= CategoryCustomColorStore.maxCount { return "꽉 차면 가장 오래된 색이 빠집니다." }
        return nil
    }

    private var setBinding: Binding<String> {
        Binding(get: { setId }, set: { onSelectSet($0) })
    }

    private func isPendingChip(_ hex: String) -> Bool {
        isAddingCustom && pendingCustomHex?.uppercased() == hex.uppercased()
    }

    private func commitPendingCustom() {
        if let hex = pendingCustomHex {
            onAddCustom(hex)
        }
        pendingCustomHex = nil
    }

    private func colorChip(_ hex: String) -> some View {
        // 편집 중에는 저장된 커스텀 색만 뺄 수 있다 (잠깐 보이는 색·미리보기 칩은 제외)
        let isRemovable = isEditingCustom && hex != unsavedCurrentHex && !isPendingChip(hex)
        return Button {
            if isRemovable {
                onRemoveCustom(hex)
            } else if !isEditingCustom {
                onSelect(hex)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: Self.chip, height: Self.chip)
                if isPendingChip(hex) {
                    // 아직 저장 전인 색: 점선 테두리
                    Circle()
                        .strokeBorder(Color(.secondaryLabel), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: Self.chip + 8, height: Self.chip + 8)
                }
                if selectedHex.uppercased() == hex.uppercased(), !isEditingCustom {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: hex).readableForeground)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isRemovable {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color(.systemRed))
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .opacity(isEditingCustom && !isRemovable ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isEditingCustom)
        .accessibilityLabel(isRemovable ? Text("커스텀에서 빼기") : Text(verbatim: hex))
    }

    /// 커스텀 맨 끝 칸: 색 고르기 창 열기
    private var addChip: some View {
        Button {
            pendingCustomHex = nil
            isAddingCustom = true
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: Self.chip, height: Self.chip)
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("커스텀 색 추가"))
    }
}
