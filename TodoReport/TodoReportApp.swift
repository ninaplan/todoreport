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

    var body: some Scene {
        WindowGroup {
            if onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView {
                    onboardingCompleted = true
                }
            }
        }
        .modelContainer(PersistenceController.shared.container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in SyncQueueManager.shared.processIfConnected() }
            }
        }
    }
}
