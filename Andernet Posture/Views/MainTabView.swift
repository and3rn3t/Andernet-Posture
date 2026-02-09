//
//  MainTabView.swift
//  Andernet Posture
//
//  iOS 26 Liquid Glass floating tab bar with scroll-to-minimize.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard

    enum AppTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case sessions = "Sessions"
        case capture = "Capture"
        case clinicalTests = "Tests"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .sessions: return "list.bullet.rectangle.portrait.fill"
            case .capture: return "figure.walk"
            case .clinicalTests: return "stethoscope"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.icon, value: .dashboard) {
                DashboardView()
            }

            Tab(AppTab.sessions.rawValue, systemImage: AppTab.sessions.icon, value: .sessions) {
                SessionListView()
            }

            Tab(AppTab.capture.rawValue, systemImage: AppTab.capture.icon, value: .capture) {
                PostureGaitCaptureView()
            }

            Tab(AppTab.clinicalTests.rawValue, systemImage: AppTab.clinicalTests.icon, value: .clinicalTests) {
                ClinicalTestView()
            }

            Tab(AppTab.settings.rawValue, systemImage: AppTab.settings.icon, value: .settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
