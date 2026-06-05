import Foundation
import StoreKit

// MARK: - Sandbox 테스트 방법
// 1. 기기: Settings > App Store > SANDBOX ACCOUNT 에서 developer.apple.com 테스트 계정으로 로그인
//    (앱스토어 계정과 별도. 실제 결제 없이 구매 처리됨)
// 2. 시뮬레이터: Xcode > File > New > StoreKit Configuration File 생성
//    Product 추가 후 Scheme > Edit Scheme > Options > StoreKit Configuration 선택
// 3. 구독 갱신 주기 자동 단축: 1개월 → 약 5분, 1년 → 약 30분
// 4. 구매 확인창 > "Confirm" 탭 시 실제 결제 없이 처리됨
// 5. 구매 복원 테스트: Settings > App Store > Sandbox > 동일 테스트 계정으로 재로그인 후 복원

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    private init() { startTransactionListener() }

    static let monthlyProductId = "kr.nock.todoreport.pro.monthly"
    static let yearlyProductId  = "kr.nock.todoreport.pro.yearly"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts: Bool = false

    var onSubscriptionExpired: (() -> Void)?
    private var wasProBefore: Bool = false
    private var updateListenerTask: Task<Void, Never>?

    // MARK: - isPro

    var isPro: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugIsPro") { return true }
        #endif
        return !purchasedProductIDs.isEmpty
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductId } }
    var yearlyProduct:  Product? { products.first { $0.id == Self.yearlyProductId  } }

    // MARK: - Transaction Listener

    func startTransactionListener() {
        updateListenerTask?.cancel()
        updateListenerTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.updatePurchasedProducts()
            }
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: [Self.monthlyProductId, Self.yearlyProductId])
                .sorted { $0.price < $1.price }
        } catch {
            print("[SubscriptionManager] loadProducts error: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let tx) = verification else { return }
            await tx.finish()
            await updatePurchasedProducts()
        case .pending, .userCancelled:
            break
        @unknown default:
            break
        }
    }

    func purchase(productId: String) async throws {
        guard let product = products.first(where: { $0.id == productId }) else { return }
        try await purchase(product)
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Debug Pro 토글 만료 시뮬레이션

    #if DEBUG
    func refreshIsProDebug(previousValue: Bool) {
        let wasPro = previousValue || wasProBefore
        let debugOn = UserDefaults.standard.bool(forKey: "debugIsPro")
        if !debugOn && wasPro && purchasedProductIDs.isEmpty {
            wasProBefore = false
            Task { @MainActor in onSubscriptionExpired?() }
        }
        if debugOn {
            wasProBefore = true
            PlannerService.shared.restoreAllPlanners()
        }
    }
    #endif

    // MARK: - Entitlement Refresh

    func updatePurchasedProducts() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.revocationDate == nil {
                ids.insert(tx.productID)
            }
        }
        // 이전에 Pro였던 경우에만 만료 콜백 호출
        let wasPro = !purchasedProductIDs.isEmpty || wasProBefore
        purchasedProductIDs = ids
        let isNowPro = !ids.isEmpty
        if wasPro && !isNowPro {
            await MainActor.run { onSubscriptionExpired?() }
        }
        if isNowPro {
            wasProBefore = true
            await MainActor.run { PlannerService.shared.restoreAllPlanners() }
        }
    }
}
