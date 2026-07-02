import SwiftUI
import StoreKit

struct PaywallView: View {
    var message: String? = nil

    @State private var viewModel = PaywallViewModel()
    @State private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    private static let privacyPolicyURL = URL(string: "https://nock.kr/privacy")
    private static let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    private var isDark: Bool { true }

    private var backgroundColor: Color {
        isDark ? .black : Color(.systemGroupedBackground)
    }

    private var cardBackground: Color {
        isDark ? Color(hex: "2C2C2E") : .white
    }

    private var primaryText: Color {
        isDark ? .white : Color(hex: "111111")
    }

    private var secondaryText: Color {
        isDark ? Color(hex: "AAAAAA") : Color(hex: "666666")
    }

    private var dividerColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var selectedIntroOfferText: String? {
        viewModel.selectedProductId == SubscriptionManager.yearlyProductId
            ? subscriptionManager.yearlyIntroOfferText
            : subscriptionManager.monthlyIntroOfferText
    }

    private var ctaTitle: String {
        selectedIntroOfferText != nil ? "7일 무료로 시작하기" : "구독 시작하기"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        proFeaturesSection
                        freeFeaturesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                bottomSection
            }
            .background(backgroundColor)
            .navigationTitle("투두x리포트 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        ProgressView().tint(Color.nockOrange)
                    }
                }
            }
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.purchaseSuccess) { _, success in
                if success { dismiss() }
            }
            .task { await viewModel.loadIfNeeded() }
        }
        .presentationBackground(backgroundColor)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.nockOrange.opacity(0.85))

            Text("앱에서 기록하고, 노션에 쌓아가세요")
                .font(.system(size: 14))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nockOrange)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Pro Features

    private var proFeaturesSection: some View {
        VStack(spacing: 0) {
            ProFeatureRow(
                title: "주간·월간 리포트 노션에 저장",
                description: "리포트를 노션 DB에 저장해 나만의 기록 아카이브를 만드세요.",
                isComingSoon: false,
                primaryText: primaryText,
                secondaryText: secondaryText
            )

            proFeatureDivider

            ProFeatureRow(
                title: "멀티 플래너",
                description: "업무·개인·프로젝트를 각각의 공간에서 분리해 관리하세요. 현재 워크스페이스당 플래너 1개를 권장합니다.",
                isComingSoon: false,
                primaryText: primaryText,
                secondaryText: secondaryText
            )

            proFeatureDivider

            ProFeatureRow(
                title: "반복 할일",
                description: "매일·매주 반복되는 할일을 한 번만 설정하면 자동으로 생성됩니다.",
                isComingSoon: true,
                primaryText: primaryText,
                secondaryText: secondaryText
            )

            proFeatureDivider

            ProFeatureRow(
                title: "집중시간 트래커",
                description: "측정한 집중시간이 리포트에 함께 기록됩니다.",
                isComingSoon: true,
                primaryText: primaryText,
                secondaryText: secondaryText
            )

            proFeatureDivider

            ProFeatureRow(
                title: "카테고리 → 노션 DB 연동",
                description: "카테고리가 노션 프로젝트·목표 DB와 연결됩니다.",
                isComingSoon: true,
                primaryText: primaryText,
                secondaryText: secondaryText
            )
        }
        .padding(.vertical, 4)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var proFeatureDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 0.5)
            .padding(.leading, 41)
    }

    // MARK: - Free Features

    private var freeFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("무료로 제공")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)

            PaywallChipFlowLayout(spacing: 8, lineSpacing: 8) {
                FreeFeatureChip(label: "노션 양방향 동기화", primaryText: primaryText, secondaryText: secondaryText)
                FreeFeatureChip(label: "투두 관리", primaryText: primaryText, secondaryText: secondaryText)
                FreeFeatureChip(label: "데일리 리포트", primaryText: primaryText, secondaryText: secondaryText)
                FreeFeatureChip(label: "주간·월간 리포트 기기 저장", primaryText: primaryText, secondaryText: secondaryText)
                FreeFeatureChip(label: "하루 리뷰", primaryText: primaryText, secondaryText: secondaryText)
                InboxComingSoonChip(secondaryText: secondaryText)
            }
        }
        .padding(.top, 20)
        .padding(.leading, 4)
    }

    // MARK: - Bottom (Fixed)

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 0.5)

            VStack(spacing: 12) {
                if subscriptionManager.isLoadFailed {
                    loadFailedView
                } else {
                    planCardsSection
                }

                ctaButton
                footerSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(backgroundColor)
    }

    private var loadFailedView: some View {
        VStack(spacing: 8) {
            Text("상품 정보를 불러오지 못했어요.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
            if let detail = subscriptionManager.productLoadFailureDetail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
            }
            Button("다시 시도") {
                Task { await viewModel.reloadProducts() }
            }
            .font(.subheadline.bold())
            .foregroundStyle(Color.nockOrange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var planCardsSection: some View {
        VStack(spacing: 8) {
            PaywallPlanCard(
                title: "연간",
                priceText: subscriptionManager.yearlyProduct?.displayPrice
                    ?? (subscriptionManager.isLoadingProducts ? "로딩 중..." : "---"),
                unit: "/년",
                subtitle: yearlyPlanSubtitle,
                discountBadge: "43% 할인",
                isSelected: viewModel.selectedProductId == SubscriptionManager.yearlyProductId,
                cardBackground: cardBackground,
                dividerColor: dividerColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                onTap: { viewModel.selectedProductId = SubscriptionManager.yearlyProductId }
            )

            PaywallPlanCard(
                title: "월간",
                priceText: subscriptionManager.monthlyProduct?.displayPrice
                    ?? (subscriptionManager.isLoadingProducts ? "로딩 중..." : "---"),
                unit: "/월",
                subtitle: "언제든 해지 가능",
                discountBadge: nil,
                isSelected: viewModel.selectedProductId == SubscriptionManager.monthlyProductId,
                cardBackground: cardBackground,
                dividerColor: dividerColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                onTap: { viewModel.selectedProductId = SubscriptionManager.monthlyProductId }
            )
        }
        .padding(.bottom, 12)
    }

    private var ctaButton: some View {
        Button {
            Task { await viewModel.purchase() }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(ctaTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.nockOrange)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(viewModel.isLoading || !viewModel.canPurchase)
    }

    private var footerSection: some View {
        HStack(spacing: 20) {
            Button {
                Task { await viewModel.restore() }
            } label: {
                Text("구독 복원")
            }
            .disabled(viewModel.isLoading)

            if let eulaURL = Self.eulaURL {
                Link("이용약관", destination: eulaURL)
            }
            if let privacyPolicyURL = Self.privacyPolicyURL {
                Link("개인정보처리방침", destination: privacyPolicyURL)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(secondaryText)
        .tint(secondaryText)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var yearlyPlanSubtitle: String? {
        guard let monthlyEquivalent = yearlyMonthlyEquivalentText,
              let savings = yearlySavingsAmountText else { return nil }
        return "월 \(monthlyEquivalent) 꼴 · \(savings)"
    }

    private var yearlyMonthlyEquivalentText: String? {
        guard let yearly = subscriptionManager.yearlyProduct else { return nil }
        let monthlyAmount = yearly.price / 12
        return formatCurrency(monthlyAmount, using: yearly)
    }

    private var yearlySavingsAmountText: String? {
        guard let monthly = subscriptionManager.monthlyProduct,
              let yearly = subscriptionManager.yearlyProduct else { return nil }
        let savings = monthly.price * 12 - yearly.price
        guard savings > 0 else { return nil }
        let formatted = formatCurrency(savings, using: yearly)
        return "연 \(formatted) 절약"
    }

    private func formatCurrency(_ amount: Decimal, using product: Product) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded.formatted(product.priceFormatStyle)
    }
}

// MARK: - ProFeatureRow

private struct ProFeatureRow: View {
    let title: String
    let description: String
    let isComingSoon: Bool
    let primaryText: Color
    let secondaryText: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "sparkles.2")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(primaryText)
                .frame(width: 28, height: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(primaryText)
                    if isComingSoon {
                        Text("예정")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(secondaryText.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isComingSoon ? 0.6 : 1)
    }
}

// MARK: - Free Feature Chips

private struct FreeFeatureChip: View {
    let label: String
    let primaryText: Color
    let secondaryText: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(primaryText)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(secondaryText)
        }
    }
}

private struct InboxComingSoonChip: View {
    let secondaryText: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)
            Text("인박스")
                .font(.system(size: 12))
                .foregroundStyle(secondaryText)
            Text("예정")
                .font(.system(size: 12))
                .foregroundStyle(secondaryText)
                .opacity(0.5)
        }
    }
}

// MARK: - PaywallPlanCard

private struct PaywallPlanCard: View {
    let title: String
    let priceText: String
    let unit: String
    let subtitle: String?
    let discountBadge: String?
    let isSelected: Bool
    let cardBackground: Color
    let dividerColor: Color
    let primaryText: Color
    let secondaryText: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.nockOrange : dividerColor,
                                lineWidth: isSelected ? 2 : 1.5
                            )
                            .frame(width: 18, height: 18)
                        if isSelected {
                            Circle()
                                .fill(Color.nockOrange)
                                .frame(width: 9, height: 9)
                        }
                    }

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(primaryText)

                    if let discountBadge {
                        Text(discountBadge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.nockOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.nockOrange.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(priceText)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(primaryText)
                        Text(unit)
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryText)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryText)
                        .padding(.leading, 28)
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.nockOrange : dividerColor,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip Flow Layout

private struct PaywallChipFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                height += rowHeight + lineSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
