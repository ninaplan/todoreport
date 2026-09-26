import SwiftUI

struct MoodButton: View {
    let date: Date
    var forMeasurement: Bool = false
    @Bindable var viewModel: MoodButtonViewModel

    @Environment(\.colorScheme) private var colorScheme

    static let minimumWidth: CGFloat = 72
    static let minimumHeight: CGFloat = 30
    static let minimumHitLength: CGFloat = 44

    private static let chipHorizontalPadding: CGFloat = 8
    private static let chipVerticalPadding: CGFloat = 4

    private var plannerId: String {
        PlannerService.shared.selectedPlannerId
    }

    private var isUsageDisabled: Bool {
        guard !plannerId.isEmpty,
              let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }) else {
            return true
        }
        return planner.decodedReportPropsMapping.moodMode == .disabled
    }

    private var taskID: String {
        "\(date.timeIntervalSince1970)|\(plannerId)|\(MoodService.shared.revision)"
    }

    var body: some View {
        if isUsageDisabled {
            EmptyView()
        } else if forMeasurement {
            chip
                .accessibilityHidden(true)
        } else {
            chip
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .anchorPreference(key: MoodChipAnchorKey.self, value: .bounds) { $0 }
                .task(id: taskID) {
                    await viewModel.reload(date: date, plannerId: plannerId)
                }
                .alert("저장 실패", isPresented: $viewModel.showSaveErrorAlert) {
                    Button("확인") { viewModel.confirmSaveError() }
                } message: {
                    Text("기분을 저장하지 못했습니다. 다시 시도해 주세요.")
                }
                .alert("읽기 전용 플래너", isPresented: $viewModel.showReadOnlyAlert) {
                    Button("확인") { viewModel.confirmReadOnly() }
                } message: {
                    Text("이 플래너는 읽기 전용입니다. Pro 구독 시 다시 활성화됩니다.")
                }
        }
    }

    private var chip: some View {
        chipLabel
            .font(.subheadline)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .foregroundStyle(chipForeground)
            .padding(.horizontal, Self.chipHorizontalPadding)
            .padding(.vertical, Self.chipVerticalPadding)
            .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight, alignment: .center)
            .background(Capsule().fill(chipFill))
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private var chipLabel: Text {
        Text(viewModel.chipTitle)
    }

    private var chipFill: Color {
        guard let hex = viewModel.chipColorHex else {
            return Color(.tertiarySystemFill)
        }
        return Color(hex: hex).opacity(0.18)
    }

    private var chipForeground: Color {
        guard let hex = viewModel.chipColorHex else {
            return .secondary
        }
        return Color(hex: hex).readableText(on: colorScheme)
    }
}

struct MoodChipAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() {
            value = next
        }
    }
}

struct MoodChipFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0.5 {
            value = next
        }
    }
}

/// 칩 위에 얹는 44pt 메뉴. 줄 높이 계산에는 들어가지 않는다.
struct MoodChipHitMenu: View {
    @Bindable var viewModel: MoodButtonViewModel
    var width: CGFloat

    var body: some View {
        Menu {
            ForEach(viewModel.options) { option in
                Button {
                    viewModel.select(optionId: option.id)
                } label: {
                    if viewModel.selectedOptionId == option.id {
                        Label(viewModel.displayName(for: option), systemImage: "checkmark")
                    } else {
                        Text(viewModel.displayName(for: option))
                    }
                }
            }
            if viewModel.showsClear {
                Button("선택 해제") {
                    viewModel.clear()
                }
            }
            if !viewModel.options.isEmpty || viewModel.showsClear {
                Divider()
            }
            Button("기분 편집…") {
                viewModel.openEditor()
            }
        } label: {
            Color.clear
                .frame(width: width, height: MoodButton.minimumHitLength)
                .contentShape(Rectangle())
        }
        .frame(width: width, height: MoodButton.minimumHitLength)
        .accessibilityLabel(String(localized: "기분"))
        .accessibilityValue(viewModel.accessibilityValueText)
    }
}
