import Foundation

@Observable
final class PaywallViewModel {
    private(set) var isLoading: Bool = false
    var errorMessage: String? = nil
    var selectedProductId: String = SubscriptionManager.yearlyProductId
    private(set) var purchaseSuccess: Bool = false

    // MARK: - Actions

    func loadIfNeeded() async {
        await SubscriptionManager.shared.loadProducts()
    }

    func purchase() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await SubscriptionManager.shared.purchase(productId: selectedProductId)
            if SubscriptionManager.shared.isPro { purchaseSuccess = true }
        } catch {
            errorMessage = "구매 중 오류가 발생했어요. 다시 시도해 주세요."
        }
    }

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await SubscriptionManager.shared.restorePurchases()
            if SubscriptionManager.shared.isPro { purchaseSuccess = true }
        } catch {
            errorMessage = "복원 중 오류가 발생했어요. 다시 시도해 주세요."
        }
    }
}
