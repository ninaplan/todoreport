import Foundation

@Observable
final class PaywallViewModel {
    private(set) var isLoading: Bool = false
    var errorMessage: String? = nil
    var selectedProductId: String = SubscriptionManager.yearlyProductId
    private(set) var purchaseSuccess: Bool = false

    var canPurchase: Bool {
        SubscriptionManager.shared.product(for: selectedProductId) != nil
    }

    // MARK: - Actions

    func loadIfNeeded() async {
        await SubscriptionManager.shared.loadProducts()
    }

    func reloadProducts() async {
        await SubscriptionManager.shared.reloadProducts()
    }

    func purchase() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await SubscriptionManager.shared.purchase(productId: selectedProductId)
            if SubscriptionManager.shared.isPro {
                PlannerService.shared.restoreAllPlanners()
                purchaseSuccess = true
            }
        } catch {
            AppLogger.shared.error("PaywallViewModel", "purchase 실패: \(error)")
            #if DEBUG
            errorMessage = "구매 실패: \(error.localizedDescription)"
            #else
            errorMessage = "구매 중 오류가 발생했어요. 다시 시도해 주세요."
            #endif
        }
    }

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await SubscriptionManager.shared.restorePurchases()
            if SubscriptionManager.shared.isPro {
                PlannerService.shared.restoreAllPlanners()
                purchaseSuccess = true
            } else {
                errorMessage = "복원할 구독이 없습니다."
            }
        } catch {
            AppLogger.shared.error("PaywallViewModel", "restore 실패: \(error)")
            #if DEBUG
            errorMessage = "복원 실패: \(error.localizedDescription)"
            #else
            errorMessage = "복원 중 오류가 발생했어요. 다시 시도해 주세요."
            #endif
        }
    }
}
