import SwiftUI

extension View {
    func nockCaption() -> some View {
        self
            .font(.footnote)
            .foregroundStyle(Color.primary.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
