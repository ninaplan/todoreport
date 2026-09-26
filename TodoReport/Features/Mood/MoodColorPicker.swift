import SwiftUI

struct MoodColorPicker: View {
    let selectedHex: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(MoodOption.palette, id: \.self) { hex in
                    let isSelected = selectedHex.uppercased() == hex.uppercased()
                    Button {
                        onSelect(hex)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color(hex: hex).readableForeground)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(colorName(for: hex))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.top, 16)
                .padding(.bottom, 12)

            ColorPicker(
                "직접 선택",
                selection: Binding(
                    get: { Color(hex: selectedHex) },
                    set: { onSelect($0.hexString) }
                ),
                supportsOpacity: false
            )
        }
    }

    private func colorName(for hex: String) -> String {
        switch hex.uppercased() {
        case "#FF3B30": return String(localized: "빨간색")
        case "#FFCC00": return String(localized: "노란색")
        case "#34C759": return String(localized: "초록색")
        case "#00C7BE": return String(localized: "민트색")
        case "#007AFF": return String(localized: "파란색")
        case "#5856D6": return String(localized: "남색")
        case "#AF52DE": return String(localized: "보라색")
        case "#FF2D55": return String(localized: "분홍색")
        case "#A2845E": return String(localized: "갈색")
        case "#8E8E93": return String(localized: "회색")
        case "#FD6845": return String(localized: "주황색")
        case "#000000": return String(localized: "검은색")
        default: return String(localized: "색상")
        }
    }
}
