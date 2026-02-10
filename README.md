# Andernet Posture

Real-time posture and gait analytics using ARKit body tracking, LiDAR, and CoreMotion on iPhone.

## Requirements

| Requirement | Minimum |
|---|---|
| Xcode | 26.0+ |
| iOS Deployment Target | 26.0 |
| Device | iPhone/iPad with A12+ chip and ARKit support |
| LiDAR | Recommended (iPhone 12 Pro+, iPad Pro 2020+) |

> **Note:** ARKit body tracking requires a physical device — it does not work in the iOS Simulator.

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/and3rn3t/Andernet-Posture.git
   cd Andernet-Posture
   ```

2. **Open in Xcode**

   ```bash
   open "Andernet Posture/Andernet Posture.xcodeproj"
   ```

3. **Select your team** — In *Signing & Capabilities*, pick your development team under *Automatically manage signing*.

4. **Build & Run** — Select a physical iOS device and press `Cmd+R`.

## Project Structure

```
Andernet Posture/
├── Andernet_PostureApp.swift    # App entry point, SwiftData container
├── BodyARView.swift             # ARView wrapper + skeleton overlay
├── PostureGaitCaptureView.swift # Capture session UI
├── GaitSession.swift            # SwiftData @Model for session persistence
├── Info.plist                   # Privacy descriptions, device capabilities
├── PrivacyInfo.xcprivacy        # App privacy manifest
├── Models/
│   ├── BodyFrame.swift          # Skeleton joint snapshot
│   ├── JointName.swift          # Tracked joint enum + ARKit mapping
│   ├── MotionFrame.swift        # CoreMotion device motion snapshot
│   └── StepEvent.swift          # Foot-strike event during gait
├── Services/
│   ├── BodyTrackingService.swift   # ARKit body tracking protocol + impl
│   ├── GaitAnalyzer.swift          # Step detection & gait metrics
│   ├── HealthKitService.swift      # HealthKit read/write
│   ├── MotionService.swift         # CoreMotion 60Hz sampling
│   ├── PostureAnalyzer.swift       # Spine angle & posture scoring
│   └── SessionRecorder.swift       # Record/stop/save session state machine
├── ViewModels/
│   ├── CaptureViewModel.swift      # Orchestrates capture services
│   ├── DashboardViewModel.swift    # Dashboard data & trends
│   └── SessionDetailViewModel.swift # Single session detail
├── Views/
│   ├── DashboardView.swift         # Overview with charts
│   ├── MainTabView.swift           # Tab bar (Dashboard, Capture, History, Settings)
│   ├── SessionDetailView.swift     # Session drill-down with charts
│   ├── SessionListView.swift       # Session history list
│   └── SettingsView.swift          # Preferences & data management
├── Utilities/
│   ├── Formatters.swift            # Time & number formatting helpers
│   └── SIMDExtensions.swift        # SIMD3<Float> convenience extensions
└── Assets.xcassets/                # App icon, accent color
```

## Architecture

- **MVVM** with protocol-based service injection for testability
- **SwiftData** for on-device session persistence
- **Swift Concurrency** — `@MainActor` default isolation, `nonisolated` for delegate callbacks
- **ARKit + RealityKit** — `ARBodyTrackingConfiguration` with real-time skeleton overlay
- **CoreMotion** — 60 Hz accelerometer/gyroscope sampling for gait step detection
- **HealthKit** — Read walking metrics, write session summaries
- **Swift Charts** — Posture score trends and gait analysis visualizations

For a detailed architecture overview with Mermaid diagrams, see **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

## Build Settings

| Setting | Value | Purpose |
|---|---|---|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | All types default to main actor |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Simplified concurrency model |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | Full concurrency checking |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` | Explicit imports required |

## Privacy & Capabilities

The app requests access to:

| Permission | Usage |
|---|---|
| **Camera** | ARKit body tracking and LiDAR depth |
| **Motion & Fitness** | CoreMotion accelerometer/gyroscope for gait analysis |
| **HealthKit (Read)** | Walking metrics, step counts, historical trends |
| **HealthKit (Write)** | Save posture/gait session summaries |

Entitlements: HealthKit capability is enabled in `Andernet_Posture.entitlements`.

## Testing

```bash
# Run unit tests
xcodebuild test -project "Andernet Posture/Andernet Posture.xcodeproj" \
  -scheme "Andernet Posture" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro"
```

> Unit tests for analyzers and services work on Simulator. AR-dependent tests require a physical device.

## License

Copyright © 2026 Andernet. All rights reserved.
