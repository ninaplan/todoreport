import SwiftUI

struct ProBadge: View {
    var body: some View {
        if !SubscriptionManager.shared.isPro {
            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text("Pro")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(AppTheme.shared.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppTheme.shared.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}
