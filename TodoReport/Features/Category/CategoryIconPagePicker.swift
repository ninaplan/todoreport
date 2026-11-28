import SwiftUI

/// 카테고리 편집의 아이콘 고르기.
/// 위에서부터: 채움 | 라인 (이 카테고리만) → 검색창 → 분야별 페이지(옆으로 넘김, 3줄 × 6칸) + 페이지 점.
/// 검색어를 넣으면 페이지 자리에 결과가 나온다 (분야 아이콘 + SF Symbols 전체 + 한국어 낱말 사전).
/// 높이는 검색 중에도 같게 고정해서 화면이 들썩이지 않는다.
struct CategoryIconPagePicker: View {
    let selectedIcon: String
    let colorHex: String
    let onSelect: (String) -> Void

    @State private var page: String
    @State private var query = ""
    /// 채움 | 라인 선택. 아이콘 이름과 따로 둔다 → 지금 아이콘에 채움 모양이 없어도 「채움」으로 넘어가 채움 아이콘을 고를 수 있다
    @State private var showsFilled: Bool

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private static let rows = 3
    private static let cell: CGFloat = 40
    private static let rowSpacing: CGFloat = 10
    /// 분야 이름 줄 (글자 + 간격)
    private static let titleHeight: CGFloat = 26

    /// `initiallyFilled`: 고른 아이콘이 없을 때(별점 기본 ⭐) 처음 보여 줄 모양. nil이면 지금 아이콘 이름으로 판단
    init(
        selectedIcon: String,
        colorHex: String,
        initiallyFilled: Bool? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.selectedIcon = selectedIcon
        self.colorHex = colorHex
        self.onSelect = onSelect
        // 지금 아이콘이 있는 분야에서 연다 (검색으로 고른 아이콘이면 첫 분야)
        let base = CategoryIconName.baseName(selectedIcon)
        let initial = Category.iconGroups.first { $0.icons.contains(base) }?.id
            ?? Category.iconGroups.first?.id
            ?? ""
        _page = State(initialValue: initial)
        _showsFilled = State(initialValue: initiallyFilled ?? CategoryIconName.isFilled(selectedIcon))
    }

    private var color: Color { Color(hex: colorHex) }
    private var selectedBase: String { CategoryIconName.baseName(selectedIcon) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    private var gridHeight: CGFloat {
        CGFloat(Self.rows) * Self.cell + CGFloat(Self.rows - 1) * Self.rowSpacing
    }
    /// 페이지(분야 이름 + 격자) 높이. 검색 결과도 같은 높이를 쓴다
    private var pageHeight: CGFloat { Self.titleHeight + gridHeight }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            styleControl
            searchField
            if isSearching {
                searchResults
            } else {
                pages
                pageDots
            }
        }
    }

    // MARK: - 채움 | 라인 (이 카테고리만)

    private var styleControl: some View {
        Picker("카테고리 아이콘 모양", selection: styleBinding) {
            Text("채움").tag(true)
            Text("라인").tag(false)
        }
        .pickerStyle(.segmented)
    }

    /// 모양을 바꾸면 격자가 그 모양으로 바뀌고, 지금 아이콘도 그 모양이 있으면 같이 바꾼다
    /// (채움 모양이 없는 아이콘이면 지금 아이콘은 그대로 두고, 격자에서 채움 아이콘을 새로 고르면 된다)
    private var styleBinding: Binding<Bool> {
        Binding(
            get: { showsFilled },
            set: { filled in
                showsFilled = filled
                let converted = CategoryIconName.make(base: selectedIcon, filled: filled)
                if converted != selectedIcon { onSelect(converted) }
            }
        )
    }

    // MARK: - 검색

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(.tertiaryLabel))
            TextField("영어로 검색 (예: book, cat)", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if isSearching {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("지우기"))
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var searchResults: some View {
        let results = SFSymbolCatalog.search(query)
        return Group {
            if results.isEmpty {
                Text("검색 결과가 없습니다.")
                    .font(.footnote)
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Self.columns, spacing: Self.rowSpacing) {
                        ForEach(results, id: \.self) { symbol in
                            iconButton(symbol)
                        }
                    }
                }
            }
        }
        // 페이지 + 점 자리만큼 (검색할 때 높이가 바뀌지 않게)
        .frame(height: pageHeight + 12 + Self.dotSize)
    }

    // MARK: - 분야 페이지

    private var pages: some View {
        TabView(selection: $page) {
            ForEach(Category.iconGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                    LazyVGrid(columns: Self.columns, spacing: Self.rowSpacing) {
                        ForEach(group.icons, id: \.self) { symbol in
                            iconButton(symbol)
                        }
                    }
                    .frame(height: gridHeight, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 2)
                .tag(group.id)
            }
        }
        // 기본 점은 흰색이라 밝은 배경에서 안 보여서 직접 그린다 (아래 pageDots)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: pageHeight)
    }

    private static let dotSize: CGFloat = 7

    /// 페이지 점: 지금 페이지는 진하게, 나머지는 연하게. 눌러서 이동할 수도 있다
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(Category.iconGroups) { group in
                let isCurrent = group.id == page
                Circle()
                    .fill(isCurrent ? Color(.label) : Color(.tertiaryLabel).opacity(0.5))
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .contentShape(Rectangle().inset(by: -4))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { page = group.id }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(currentGroupTitle))
    }

    private var currentGroupTitle: LocalizedStringResource {
        Category.iconGroups.first { $0.id == page }?.title ?? "공부"
    }

    // MARK: - 아이콘 칸

    private func iconButton(_ symbol: String) -> some View {
        let isSelected = selectedBase == CategoryIconName.baseName(symbol)
        return Button {
            onSelect(CategoryIconName.make(base: symbol, filled: showsFilled))
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? color : color.opacity(0.12))
                    .frame(width: Self.cell, height: Self.cell)
                Image(systemName: CategoryIconName.make(base: symbol, filled: showsFilled))
                    .font(.system(size: 17))
                    .foregroundStyle(isSelected ? .white : color)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: colorHex)
        .accessibilityLabel(Text(verbatim: symbol))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
