import SwiftUI

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))
        }
        .toolbarSecondaryActionStyle()
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
        }
        .toolbarSecondaryActionStyle()
    }
}

struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .medium))
            }
        }
        .toolbarSecondaryActionStyle()
    }
}

// iOS 26: navigation bar Button에 .tint()를 쓰면 회색 캡슐 + accent 글씨로 렌더링됨 → plain text style 사용
extension View {
    func toolbarPrimaryActionStyle(isEnabled: Bool = true) -> some View {
        fontWeight(.semibold)
            .foregroundStyle(isEnabled ? AppTheme.shared.accent : Color(.tertiaryLabel))
    }

    func toolbarSecondaryActionStyle() -> some View {
        foregroundStyle(.secondary)
    }
}
