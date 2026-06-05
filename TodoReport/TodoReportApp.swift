//
//  TodoReportApp.swift
//  TodoReport
//
//  Created by Nina Kim on 5/26/26.
//

import SwiftUI
import SwiftData

@main
struct TodoReportApp: App {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPlannerDowngrade: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = PersistenceController.shared.initializationError {
                    PersistenceErrorView(error: error)
                } else if onboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView {
                        onboardingCompleted = true
                    }
                }
            }
            .onAppear {
                TodoNotificationManager.shared.requestPermission()
                SubscriptionManager.shared.onSubscriptionExpired = {
                    if PlannerService.shared.store.count > 1 {
                        showPlannerDowngrade = true
                    }
                }
                Task { await SubscriptionManager.shared.updatePurchasedProducts() }
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
                Task { @MainActor in
                    NotionAuthManager.shared.handleCallback(url: url)
                }
            }
            .sheet(isPresented: $showPlannerDowngrade) {
                PlannerDowngradeView {
                    showPlannerDowngrade = false
                }
            }
        }
        .modelContainer(PersistenceController.shared.container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in SyncQueueManager.shared.processIfConnected() }
                Task { @MainActor in NotionRelationLinker.shared.linkMissing() }
            }
        }
    }
}
