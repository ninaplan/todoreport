import Foundation
import StoreKit
import UIKit

// MARK: - Sandbox 테스트 방법
// 1. 기기: Settings > App Store > SANDBOX ACCOUNT 에서 developer.apple.com 테스트 계정으로 로그인
//    (앱스토어 계정과 별도. 실제 결제 없이 구매 처리됨)
// 2. 시뮬레이터: TodoReport.storekit 파일을 Scheme > Edit Scheme > Options > StoreKit Configuration 에서 선택
// 3. 구독 갱신 주기 자동 단축: 1개월 → 약 5분, 1년 → 약 30분
// 4. 구매 확인창 > "Confirm" 탭 시 실제 결제 없이 처리됨
// 5. 구매 복원 테스트: Settings > App Store > Sandbox > 동일 테스트 계정으로 재로그인 후 복원
//
// App Store Connect 실연동:
// - 상품 ID: kr.nock.todoreport.pro.monthly / kr.nock.todoreport.pro.yearly (동일 그룹)
// - Paid Applications Agreement 체결, 가격·현지화 등록 후 심사 제출

enum SubscriptionError: LocalizedError {
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "상품 정보를 불러올 수 없어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    static let monthlyProductId = "kr.nock.todoreport.pro.monthly"
    static let yearlyProductId  = "kr.nock.todoreport.pro.yearly"
    private static let expectedProductIds: Set<String> = [monthlyProductId, yearlyProductId]

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts: Bool = false
    private(set) var isLoadFailed: Bool = false
    private(set) var productLoadFailureDetail: String?

    var onSubscriptionExpired: (() -> Void)?
    private var wasProBefore: Bool = false
    private var updateListenerTask: Task<Void, Never>?

    private init() { startTransactionListener() }

    // MARK: - isPro

    var isPro: Bool {
        !purchasedProductIDs.isEmpty
    }

    var activePlanDisplayName: String {
        guard isPro else { return "무료" }
        if purchasedProductIDs.contains(Self.yearlyProductId) { return "Pro (연간)" }
        if purchasedProductIDs.contains(Self.monthlyProductId) { return "Pro (월간)" }
        return "Pro"
    }

    var monthlyProduct: Product? { product(for: Self.monthlyProductId) }
    var yearlyProduct: Product? { product(for: Self.yearlyProductId) }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    var hasAllProducts: Bool {
        Self.expectedProductIds.isSubset(of: Set(products.map(\.id)))
    }

    // MARK: - Transaction Listener

    func startTransactionListener() {
        updateListenerTask?.cancel()
        updateListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.updatePurchasedProducts()
            }
        }
    }

    // MARK: - Products

    func loadProducts(force: Bool = false) async {
        if !force, hasAllProducts, !isLoadFailed { return }
        isLoadingProducts = true
        isLoadFailed = false
        productLoadFailureDetail = nil
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Array(Self.expectedProductIds))
                .sorted { $0.price < $1.price }
            products = loaded
            let receivedIds = Set(loaded.map(\.id))
            let missingIds = Self.expectedProductIds.subtracting(receivedIds)
            isLoadFailed = loaded.isEmpty || !missingIds.isEmpty
            if isLoadFailed {
                if loaded.isEmpty {
                    productLoadFailureDetail = """
                    App Store Connect에서 구독 상품을 찾지 못했습니다.
                    • 앱 번들 ID: \(Bundle.main.bundleIdentifier ?? "unknown")
                    • 요청 ID: \(Self.monthlyProductId), \(Self.yearlyProductId)
                    • Scheme > Run > Options > StoreKit Configuration이 None이면 ASC 등록 상품을 사용합니다.
                    """
                } else {
                    productLoadFailureDetail = "누락된 상품 ID: \(missingIds.sorted().joined(separator: ", "))"
                }
                AppLogger.shared.error(
                    "SubscriptionManager",
                    "loadProducts 불완전: 요청 \(Self.expectedProductIds), 수신 \(loaded.map(\.id))"
                )
            }
        } catch {
            isLoadFailed = true
            productLoadFailureDetail = error.localizedDescription
            AppLogger.shared.error("SubscriptionManager", "loadProducts 실패: \(error)")
        }
    }

    func reloadProducts() async {
        products = []
        isLoadFailed = false
        productLoadFailureDetail = nil
        await loadProducts(force: true)
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
        guard let product = product(for: productId) else {
            throw SubscriptionError.productNotFound
        }
        try await purchase(product)
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Manage Subscriptions

    func showManageSubscriptions() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            AppLogger.shared.error("SubscriptionManager", "showManageSubscriptions 실패: \(error)")
        }
    }

    // MARK: - Entitlement Refresh

    func updatePurchasedProducts() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.revocationDate == nil {
                ids.insert(tx.productID)
            }
        }
        let wasPro = !purchasedProductIDs.isEmpty || wasProBefore
        purchasedProductIDs = ids
        let isNowPro = !ids.isEmpty
        if wasPro && !isNowPro {
            onSubscriptionExpired?()
        }
        if isNowPro {
            wasProBefore = true
            PlannerService.shared.restoreAllPlanners()
        }
    }
}
