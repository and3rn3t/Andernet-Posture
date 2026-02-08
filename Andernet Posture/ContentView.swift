//
//  ContentView.swift
//  Andernet Posture
//
//  Legacy entry point — redirects to MainTabView.
//  Kept for backward compatibility with previews.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
