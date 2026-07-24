import SwiftUI

struct DateNavigationRow: View {
    let title: String
    let onPrev: () -> Void
    let onNext: () -> Void
    var canGoNext: Bool = true
    var onTapTitle: (() -> Void)? = nil
    var showTodayButton: Bool = false
    var onGoToday: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            navButton(systemName: "chevron.left", enabled: true, action: onPrev)

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 0)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapTitle?() }

                if showTodayButton, let action = onGoToday {
                    Button(action: action) {
                        Text("오늘")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 44)
            .animation(.easeInOut(duration: 0.2), value: showTodayButton)

            navButton(systemName: "chevron.right", enabled: canGoNext, action: onNext)
        }
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(enabled ? .primary : Color(.quaternaryLabel))
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 0)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!enabled)
    }
}
