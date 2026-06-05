import SwiftUI

struct ProBadge: View {
    var body: some View {
        if !SubscriptionManager.shared.isPro {
            Text("Pro")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hue: 0.13, saturation: 0.8, brightness: 0.45))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hue: 0.13, saturation: 0.6, brightness: 0.9), in: Capsule())
        }
    }
}
