//
//  OnboardingView.swift
//  Andernet Posture
//
//  Multi-step first-launch onboarding walkthrough.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("clinicalDisclaimerAccepted") private var disclaimerAccepted = false
    @State private var currentPage = 0

    private let pageCount = 5

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: gradientColors(for: currentPage),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack {
                // Skip button on pages 0-3
                HStack {
                    Spacer()
                    if currentPage < pageCount - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = pageCount - 1
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.trailing, 24)
                        .padding(.top, 12)
                    }
                }

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    howItWorksPage.tag(1)
                    clinicalMetricsPage.tag(2)
                    privacyPage.tag(3)
                    getStartedPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPageView(
            icon: "figure.stand",
            title: "Welcome to Andernet Posture",
            subtitle: "Your personal posture and gait analysis companion"
        )
    }

    private var howItWorksPage: some View {
        OnboardingPageView(
            icon: "figure.walk.motion",
            title: "How It Works",
            subtitle: "Stand in view of your camera and we track 91 body joints in real-time using advanced AR body tracking"
        )
    }

    private var clinicalMetricsPage: some View {
        OnboardingPageView(
            icon: "chart.bar.doc.horizontal",
            title: "Clinical Metrics",
            subtitle: "Medical-grade measurements including craniovertebral angle, gait symmetry, fall risk, and 40+ clinical parameters"
        )
    }

    private var privacyPage: some View {
        OnboardingPageView(
            icon: "lock.shield.fill",
            title: "Your Privacy Matters",
            subtitle: "All data stays on your device. No data is sent to any server. HealthKit sync is optional."
        )
    }

    private var getStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .symbolEffect(.pulse)

            Text("Get Started")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Accept the clinical disclaimer to begin using Andernet Posture.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                disclaimerAccepted = true
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Accept & Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.indigo)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Helpers

    private func gradientColors(for page: Int) -> [Color] {
        switch page {
        case 0: return [.indigo, .purple]
        case 1: return [.purple, .blue]
        case 2: return [.blue, .teal]
        case 3: return [.teal, .green]
        case 4: return [.green, .indigo]
        default: return [.indigo, .purple]
        }
    }
}

// MARK: - Onboarding Page Template

private struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .symbolEffect(.pulse)

            Text(title)
                .font(.title.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
