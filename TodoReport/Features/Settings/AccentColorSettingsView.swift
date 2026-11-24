import SwiftUI

/// 설정 > 포인트 컬러: 팔레트에서 고르기
struct AccentColorSettingsView: View {
    private var theme: AppTheme { AppTheme.shared }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(AppTheme.accentPalette) { option in
                        colorButton(option)
                    }
                }
                .padding(.vertical, 12)
            } footer: {
                Text("버튼, 체크 표시, 강조 색이 선택한 색으로 바뀝니다.")
            }

            Section {
                ColorPicker(selection: customColorBinding, supportsOpacity: false) {
                    HStack(spacing: 8) {
                        Text("직접 고르기")
                        if theme.isCustomAccent {
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
            } footer: {
                Text("아주 밝은 색은 버튼 위 흰 글자가 잘 보이지 않을 수 있습니다.")
            }

            Section("미리보기") {
                preview
            }
        }
        .navigationTitle("포인트 컬러")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { theme.accent },
            set: { color in
                theme.setAccentHex(color.hexString)
                TabBarAppearance.applyNockAccent()
            }
        )
    }

    private func colorButton(_ option: AccentOption) -> some View {
        let isSelected = theme.accentHex == option.hex
        return Button {
            theme.setAccentHex(option.hex)
            TabBarAppearance.applyNockAccent()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: option.hex))
                        .frame(width: 44, height: 44)
                    if isSelected {
                        Circle()
                            .strokeBorder(Color(hex: option.hex), lineWidth: 2)
                            .frame(width: 54, height: 54)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                Text(option.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color(.label) : Color(.secondaryLabel))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 투두 행과 버튼 모양으로 바로 확인
    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.accent.opacity(0.55))
                Text("완료한 할 일")
                    .strikethrough(true, color: Color(.secondaryLabel))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .foregroundStyle(Color(.tertiaryLabel))
                Text("오늘 할 일")
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
            }
            Text("Pro 시작하기")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 4)
    }
}
