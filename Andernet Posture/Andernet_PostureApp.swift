//
//  Andernet_PostureApp.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "dev.andernet.posture", category: "App")

@main
struct Andernet_PostureApp: App {

    let sharedModelContainer: ModelContainer
    @State private var showSplash = true

    init() {
        let schema = Schema([GaitSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [config])
            logger.info("ModelContainer created successfully (persistent store)")
        } catch {
            logger.error("Persistent ModelContainer failed: \(error.localizedDescription). Falling back to in-memory store.")
            // Fallback: in-memory store so the app doesn't crash
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                sharedModelContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                logger.warning("Using in-memory fallback — data will not persist between launches.")
            } catch {
                // Last resort: this should never happen, but if it does, crash with context
                fatalError("ModelContainer could not be created even in-memory: \(error)")
            }
        }
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss splash after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
