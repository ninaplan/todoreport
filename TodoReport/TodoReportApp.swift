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
    }
}
