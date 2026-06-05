import SwiftUI
import StoreKit

struct PaywallView: View {
    var message: String? = nil
    @State private var viewModel = PaywallViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featureListSection
                    planCardsSection
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        ProgressView().tint(.white)
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
        }
        .task { await viewModel.loadIfNeeded() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.shared.accent)

            Text("Pro로 업그레이드")
                .font(.title2.bold())

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "calendar",             text: "더 많은 날짜의 할일 확인")
            FeatureRow(icon: "chart.bar.fill",       text: "주간·월간 리포트 전체 기간 조회")
            FeatureRow(icon: "square.stack.fill",    text: "멀티 플래너로 프로젝트 분리")
            FeatureRow(icon: "square.and.arrow.up",  text: "주간·월간 리포트 노션에 저장")
            FeatureRow(icon: "arrow.clockwise",      text: "반복 할일 설정", isComingSoon: true)
            FeatureRow(icon: "link",                 text: "프로젝트·목표 DB와 카테고리 연동", isComingSoon: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Plan Cards

    private var planCardsSection: some View {
        VStack(spacing: 10) {
            PlanCard(
                title: "월간",
                subtitle: "매월 자동 갱신",
                priceText: SubscriptionManager.shared.monthlyProduct?.displayPrice ?? (SubscriptionManager.shared.isLoadingProducts ? "로딩 중..." : "---"),
                isSelected: viewModel.selectedProductId == SubscriptionManager.monthlyProductId,
                savingsText: nil
            ) {
                viewModel.selectedProductId = SubscriptionManager.monthlyProductId
            }

            PlanCard(
                title: "연간",
                subtitle: "매년 자동 갱신",
                priceText: SubscriptionManager.shared.yearlyProduct?.displayPrice ?? (SubscriptionManager.shared.isLoadingProducts ? "로딩 중..." : "---"),
                isSelected: viewModel.selectedProductId == SubscriptionManager.yearlyProductId,
                savingsText: yearlySavingsText
            ) {
                viewModel.selectedProductId = SubscriptionManager.yearlyProductId
            }
        }
    }

    private var yearlySavingsText: String? {
        guard let monthly = SubscriptionManager.shared.monthlyProduct,
              let yearly  = SubscriptionManager.shared.yearlyProduct else { return nil }
        let monthlyAnnual = monthly.price * Decimal(12)
        let savings = monthlyAnnual - yearly.price
        guard savings > 0 else { return nil }
        let pct = Int((NSDecimalNumber(decimal: savings / monthlyAnnual).doubleValue * 100).rounded())
        return "\(pct)% 절약"
    }

    // MARK: - Action

    private var actionSection: some View {
        VStack(spacing: 14) {
            Button {
                Task { await viewModel.purchase() }
            } label: {
                Text("구독 시작하기")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.shared.accent)
            .disabled(viewModel.isLoading)

            Button {
                Task { await viewModel.restore() }
            } label: {
                Text("구독 복원")
                    .font(.footnote)
                    .foregroundStyle(.blue)
            }
            .disabled(viewModel.isLoading)

            Text("구독은 Apple ID에 연결되며 iTunes 계정에 청구됩니다.\n구독 관리는 기기 설정 > Apple ID > 구독에서 가능합니다.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String
    var isComingSoon: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isComingSoon ? Color(.secondaryLabel) : AppTheme.shared.accent)
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isComingSoon ? Color(.secondaryLabel) : Color(.label))
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let title: String
    let subtitle: String
    let priceText: String
    let isSelected: Bool
    let savingsText: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.subheadline.bold())
                        if let savings = savingsText {
                            Text(savings)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .foregroundStyle(.white)
                                .background(AppTheme.shared.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(priceText)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? AppTheme.shared.accent : .primary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.shared.accent : Color(.separator),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
