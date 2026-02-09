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
    @State private var cloudSyncService = CloudSyncService()
    @State private var mlModelService = MLModelService.shared

    init() {
        let schema = Schema([GaitSession.self, UserGoals.self])

        // iCloud sync: set the CloudKit container identifier so SwiftData
        // mirrors all models to the private CloudKit database automatically.
        // Users who aren't signed in to iCloud still get a local-only store.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.dev.andernet.posture")
        )

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
                // One-time migration from legacy @AppStorage goals
                migrateLegacyGoalsIfNeeded()

                // Kick off iCloud KVS sync for demographics
                KeyValueStoreSync.shared.pushAll()

                // Pre-warm CoreML models in background
                mlModelService.warmUp()

                // Dismiss splash after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .environment(cloudSyncService)
        .environment(mlModelService)
    }

    // MARK: - Legacy Goals Migration

    /// One-time migration from @AppStorage("goalsJSON") → SwiftData UserGoals.
    private func migrateLegacyGoalsIfNeeded() {
        let defaults = UserDefaults.standard
        let legacyKey = "goalsJSON"
        guard let json = defaults.string(forKey: legacyKey), !json.isEmpty else { return }

        let context = sharedModelContainer.mainContext
        // Only migrate if no UserGoals exist yet
        let descriptor = FetchDescriptor<UserGoals>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else {
            // Already migrated — clean up the legacy key
            defaults.removeObject(forKey: legacyKey)
            logger.info("Legacy goalsJSON removed (migration already complete)")
            return
        }

        if let migrated = UserGoals.fromLegacyJSON(json) {
            context.insert(migrated)
            try? context.save()
            defaults.removeObject(forKey: legacyKey)
            logger.info("Migrated legacy GoalConfig → SwiftData UserGoals")
        }
    }
}
