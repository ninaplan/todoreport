import SwiftUI
import SwiftData
import UserNotifications

@main
struct TodoReportApp: App {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPlannerDowngrade: Bool = false
    @State private var showPaywall: Bool = false
    var body: some Scene {
        WindowGroup {
            Group {
                if let error = PersistenceController.shared.initializationError {
                    PersistenceErrorView(error: error)
                } else if onboardingCompleted {
                    MainTabView(onAccountDeleted: { onboardingCompleted = false })
                } else {
                    OnboardingView {
                        onboardingCompleted = true
                    }
                }
            }
            .onAppear {
                TabBarAppearance.applyNockAccent()
                // 앱 실행 시 로그 파일 없으면 새로 생성, 있으면 세션 구분선만 추가
                AppLogger.shared.logNewSession()
                UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
                TodoNotificationManager.shared.requestPermission()
                SubscriptionManager.shared.onSubscriptionExpired = {
                    ReportNotificationManager.shared.cancelAll()
                    if PlannerService.shared.store.count > 1 {
                        showPlannerDowngrade = true
                    }
                }
                Task {
                    async let entitlements: Void = SubscriptionManager.shared.updatePurchasedProducts()
                    async let products: Void = SubscriptionManager.shared.loadProducts()
                    _ = await (entitlements, products)
                    ReportNotificationManager.shared.rescheduleAll()
                }
                Task { @MainActor in
                    await RecurringTodoManager.shared.generateUpcoming()
                    NotionRelationLinker.shared.linkMissing()
                }
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    print("[Notification] 📋 등록된 알림 수: \(requests.count)")
                    requests.forEach { print("[Notification] - \($0.identifier) \($0.trigger.debugDescription)") }
                }
            }
            .onOpenURL { url in
                if url.scheme == "todoreport" && url.host == "paywall" {
                    showPaywall = true
                } else {
                    Task { @MainActor in
                        NotionAuthManager.shared.handleCallback(url: url)
                    }
                }
            }
            .sheet(isPresented: $showPlannerDowngrade) {
                PlannerDowngradeView {
                    showPlannerDowngrade = false
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .preferredColorScheme(appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil)
        }
        .modelContainer(PersistenceController.shared.container)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                AppForegroundCoordinator.shared.recordBackgroundEntry()
            case .active:
                AppForegroundCoordinator.shared.handleBecomeActive()
                Task { await SubscriptionManager.shared.updatePurchasedProducts() }
                ReportNotificationManager.shared.rescheduleAll()
                Task { @MainActor in SyncQueueManager.shared.processIfConnected() }
                Task { @MainActor in NotionRelationLinker.shared.linkMissing() }
                Task {
                    if let plannerId = PlannerService.shared.selectedPlanner?.id {
                        await CategoryNotionSync.shared.syncCategoriesByName(plannerId: plannerId)
                    }
                }
            default:
                break
            }
        }
    }
}
