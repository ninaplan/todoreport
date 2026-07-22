import SwiftUI
import SwiftData
import UserNotifications

@main
struct TodoReportApp: App {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPlannerDowngrade: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showWhatsNewPopup: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = PersistenceController.shared.initializationError {
                    PersistenceErrorView(error: error)
                } else if onboardingCompleted {
                    MainTabView(onAccountDeleted: { onboardingCompleted = false })
                        .onAppear { presentWhatsNewPopupIfNeeded() }
                        .sheet(isPresented: $showWhatsNewPopup, onDismiss: markLatestWhatsNewAsSeen) {
                            if let release = whatsNewReleases.first {
                                WhatsNewPopupView(release: release) {
                                    showWhatsNewPopup = false
                                }
                            }
                        }
                } else {
                    OnboardingView {
                        markLatestWhatsNewAsSeen()
                        onboardingCompleted = true
                    }
                }
            }
            .onAppear {
                NetworkMonitor.shared.start()
                TabBarAppearance.applyNockAccent()
                // 앱 실행 시 로그 파일 없으면 새로 생성, 있으면 세션 구분선만 추가
                AppLogger.shared.logNewSession()
                UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
                TodoNotificationManager.shared.requestPermission()
                Task {
                    async let entitlements: Void = SubscriptionManager.shared.updatePurchasedProducts()
                    async let products: Void = SubscriptionManager.shared.loadProducts()
                    _ = await (entitlements, products)
                    evaluateSubscriptionState()
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
                    .presentationDragIndicator(.visible)
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
                Task {
                    await SubscriptionManager.shared.updatePurchasedProducts()
                    evaluateSubscriptionState()
                }
                ReportNotificationManager.shared.rescheduleAll()
                Task { @MainActor in SyncQueueManager.shared.processIfConnected() }
                Task { @MainActor in NotionRelationLinker.shared.linkMissing() }
                Task {
                    if let plannerId = PlannerService.shared.selectedPlanner?.id {
                        await CategoryNotionSync.shared.syncCategoriesByName(plannerId: plannerId)
                    }
                }
                Task { @MainActor in
                    await WidgetDataProvider.shared.refreshTodayFromStore()
                }
            default:
                break
            }
        }
    }

    /// entitlement 갱신 후 구독·플래너 상태를 멱등적으로 점검한다.
    @MainActor
    private func evaluateSubscriptionState() {
        if SubscriptionManager.shared.isPro {
            PlannerService.shared.restoreAllPlanners()
            return
        }
        guard PlannerService.shared.activePlannerCount > 1 else { return }
        ReportNotificationManager.shared.cancelAll()
        showPlannerDowngrade = true
    }

    private func presentWhatsNewPopupIfNeeded() {
        guard let latest = whatsNewReleases.first, latest.showsPopup else { return }
        guard lastSeenWhatsNewVersion != latest.id else { return }
        showWhatsNewPopup = true
    }

    private func markLatestWhatsNewAsSeen() {
        guard let latest = whatsNewReleases.first else { return }
        lastSeenWhatsNewVersion = latest.id
    }
}
