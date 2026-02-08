//
//  Andernet_PostureApp.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import SwiftUI
import SwiftData

@main
struct Andernet_PostureApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GaitSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

