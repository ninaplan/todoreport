import SwiftUI

struct PropMappingList<R: View, O: View>: View {
    private let subtitle: String
    private let ctaTitle: String
    private let ctaEnabled: Bool
    private let isLoading: Bool
    private let onCTA: () -> Void
    private let onBack: (() -> Void)?
    private let requiredContent: R
    private let optionalContent: O

    init(
        subtitle: String,
        ctaTitle: String,
        ctaEnabled: Bool,
        isLoading: Bool = false,
        onCTA: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        @ViewBuilder requiredRows: () -> R,
        @ViewBuilder optionalRows: () -> O
    ) {
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.ctaEnabled = ctaEnabled
        self.isLoading = isLoading
        self.onCTA = onCTA
        self.onBack = onBack
        self.requiredContent = requiredRows()
        self.optionalContent = optionalRows()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.horizontal, 24)

            List {
                Section("필수") {
                    requiredContent
                }
                Section("선택") {
                    optionalContent
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button(action: onCTA) {
                    Group {
                        if isLoading {
                            ProgressView().tint(Color(.systemBackground))
                        } else {
                            Text(ctaTitle)
                                .font(.body.bold())
                                .foregroundStyle(Color(.systemBackground))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        ctaEnabled && !isLoading ? Color(.label) : Color(.systemGray4),
                        in: Capsule()
                    )
                }
                .disabled(!ctaEnabled || isLoading)
                .padding(.horizontal, 24)

                if let onBack {
                    Button("뒤로가기", action: onBack)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
