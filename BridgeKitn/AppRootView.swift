
//  AppRootView.swift
//  BridgeTeacherHandCompose
//
//  Created by Gerald Dawson on 9/1/2026.
//

import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                HandComposeView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            // Temporary: force onboarding to show on every app run
            hasCompletedOnboarding = false
        }
    }
}

#Preview {
    AppRootView()
}


