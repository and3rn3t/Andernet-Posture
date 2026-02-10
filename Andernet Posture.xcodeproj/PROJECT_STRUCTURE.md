# Andernet Posture - Project Structure

```
Andernet-Posture/
│
├── 📱 Source Code
│   ├── Andernet_PostureApp.swift          # App entry point
│   ├── MetricsManager.swift                # NEW: Performance monitoring
│   │
│   ├── 🎨 Views/
│   │   ├── MainTabView.swift
│   │   ├── DashboardView.swift
│   │   ├── SessionsListView.swift
│   │   ├── CaptureView.swift
│   │   ├── OnboardingView.swift
│   │   └── ...
│   │
│   ├── 🧠 ViewModels/
│   │   ├── CaptureViewModel.swift
│   │   ├── ClinicalTestViewModel.swift
│   │   └── ...
│   │
│   ├── 💾 Models/
│   │   ├── GaitSession.swift
│   │   ├── UserGoals.swift
│   │   └── ...
│   │
│   ├── 🔬 Services/
│   │   ├── HealthKitService.swift
│   │   ├── CloudSyncService.swift
│   │   ├── MLModelService.swift
│   │   └── ...
│   │
│   └── 🧮 Analyzers/
│       ├── GaitAnalyzer.swift
│       ├── PostureAnalyzer.swift
│       ├── BalanceAnalyzer.swift
│       └── ...
│
├── ⚙️ Configuration (NEW!)
│   ├── Andernet Posture.entitlements      # App capabilities
│   ├── Info.plist                          # Privacy & settings
│   ├── ExportOptions.plist                 # App Store export config
│   └── .swiftlint.yml                      # Code style rules
│
├── 🧪 Testing
│   ├── Test Plans/ (NEW!)
│   │   ├── SmokeTests.xctestplan          # Fast tests
│   │   ├── FullSuite.xctestplan           # Complete tests
│   │   └── AccessibilityTests.xctestplan  # A11y tests
│   │
│   ├── Andernet PostureTests/
│   │   ├── ModelUtilityTests.swift
│   │   └── ...
│   │
│   └── Andernet PostureUITests/
│       ├── BaseUITest.swift
│       ├── PageObjects.swift
│       ├── NavigationTests.swift
│       ├── SessionFlowTests.swift
│       ├── AccessibilityTests.swift
│       ├── PerformanceTests.swift
│       └── ...
│
├── 🔨 Scripts/ (NEW!)
│   ├── swiftlint.sh                       # Build phase: Code linting
│   └── increment_build_number.sh          # Build phase: Version bump
│
├── 🤖 CI/CD (NEW!)
│   └── .github/
│       └── workflows/
│           └── ci.yml                     # Automated testing & builds
│
└── 📚 Documentation
    ├── README.md                          # UI test documentation
    ├── SETUP_COMPLETE.md                  # UI test setup guide
    ├── XCODE_SETUP_GUIDE.md               # NEW: Complete Xcode guide
    ├── XCODE_CHECKLIST.md                 # NEW: Setup checklist
    ├── XCODE_FILES_SUMMARY.md             # NEW: Files overview
    └── PROJECT_STRUCTURE.md               # This file!
```

---

## 🎯 File Purposes

### Essential Configuration

| File | What It Does | Who Needs It |
|------|--------------|--------------|
| **Andernet Posture.entitlements** | Declares iCloud, HealthKit permissions | Required for App Store |
| **Info.plist** | Privacy descriptions, app metadata | Required for iOS 17+ |
| **MetricsManager.swift** | Monitors performance in production | Production monitoring |

### Development Tools

| File | What It Does | When to Use |
|------|--------------|-------------|
| **.swiftlint.yml** | Enforces code style | During development |
| **Scripts/swiftlint.sh** | Runs linter on build | Every build |
| **Scripts/increment_build_number.sh** | Auto-bumps version | Release builds |

### Testing Infrastructure

| File | What It Does | When to Run |
|------|--------------|-------------|
| **SmokeTests.xctestplan** | Quick validation (2-3 min) | Every commit |
| **FullSuite.xctestplan** | Complete testing (15-20 min) | Before release |
| **AccessibilityTests.xctestplan** | A11y validation (5 min) | Weekly |

### CI/CD Pipeline

| File | What It Does | Platform |
|------|--------------|----------|
| **.github/workflows/ci.yml** | Automated testing | GitHub Actions |
| **ExportOptions.plist** | App Store export settings | Archive/Distribution |

---

## 🔗 How Files Connect

```
┌─────────────────────────────────────────────────────┐
│                   Xcode Project                      │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │  Andernet_PostureApp.swift                   │   │
│  │  ↓                                            │   │
│  │  • Initializes MetricsManager (production)   │   │
│  │  • Sets up SwiftData with CloudKit           │   │
│  │  • Reads Info.plist privacy strings          │   │
│  └─────────────────────────────────────────────┘   │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │  Capabilities (from .entitlements)           │   │
│  │  ↓                                            │   │
│  │  • iCloud CloudKit → CloudSyncService        │   │
│  │  • iCloud KVS → KeyValueStoreSync            │   │
│  │  • HealthKit → HealthKitService              │   │
│  └─────────────────────────────────────────────┘   │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │  Build Process                                │   │
│  │  ↓                                            │   │
│  │  1. Run increment_build_number.sh            │   │
│  │  2. Compile Sources                          │   │
│  │  3. Run swiftlint.sh                         │   │
│  │  4. Link & Sign (using .entitlements)        │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│                   Testing                            │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │  Test Plans (select in scheme)               │   │
│  │  ↓                                            │   │
│  │  • SmokeTests.xctestplan                     │   │
│  │  • FullSuite.xctestplan                      │   │
│  │  • AccessibilityTests.xctestplan             │   │
│  └─────────────────────────────────────────────┘   │
│                        ↓                             │
│  ┌─────────────────────────────────────────────┐   │
│  │  UI Tests Run with Launch Arguments          │   │
│  │  • UI_TESTING=1                              │   │
│  │  • DISABLE_ANIMATIONS=1                      │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│                   CI/CD (GitHub)                     │
│                                                       │
│  On Push:                                            │
│  1. .github/workflows/ci.yml triggers                │
│  2. Runs SwiftLint check                             │
│  3. Runs SmokeTests (fast feedback)                  │
│  4. (On main branch) Runs FullSuite                  │
│  5. Generates code coverage report                   │
│  6. (Optional) Uploads to TestFlight                 │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│               Distribution (App Store)               │
│                                                       │
│  Archive Process:                                    │
│  1. Build with Release configuration                 │
│  2. Sign with Distribution certificate               │
│  3. Export using ExportOptions.plist                 │
│  4. Upload to App Store Connect                      │
│  5. Submit for review                                │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│              Production (User Devices)               │
│                                                       │
│  Running App:                                        │
│  • Reads permissions from Info.plist                 │
│  • Uses capabilities from .entitlements              │
│  • Syncs data via CloudKit                           │
│  • Integrates with HealthKit                         │
│  • Reports metrics via MetricsManager                │
└─────────────────────────────────────────────────────┘
```

---

## 🚦 Development Workflow

### 1. Daily Development

```
Write Code
    ↓
Build (⌘B)
    ↓
Scripts run automatically:
    • swiftlint.sh checks code style
    • Build succeeds/fails with warnings
    ↓
Run (⌘R)
    ↓
Test manually in Simulator
```

### 2. Before Committing

```
Run Tests (⌘U)
    ↓
SmokeTests.xctestplan executes (2-3 min)
    ↓
All tests pass?
    ✅ Commit and push
    ❌ Fix failures, repeat
```

### 3. Pull Request

```
Push to GitHub
    ↓
.github/workflows/ci.yml triggers
    ↓
Automated checks:
    • SwiftLint
    • SmokeTests
    • Build verification
    ↓
All checks pass?
    ✅ Ready to merge
    ❌ Fix issues, push again
```

### 4. Release Preparation

```
Merge to main branch
    ↓
CI runs FullSuite.xctestplan (15-20 min)
    ↓
Generate code coverage report
    ↓
All tests pass + good coverage?
    ✅ Ready to archive
    ❌ Fix issues, improve coverage
```

### 5. App Store Submission

```
Archive (⌘⇧B)
    ↓
Scripts run:
    • increment_build_number.sh bumps version
    • Sign with distribution certificate
    ↓
Export using ExportOptions.plist
    ↓
Upload to App Store Connect
    ↓
Submit for review
```

### 6. Production Monitoring

```
Users download from App Store
    ↓
App runs on their devices
    ↓
MetricsManager collects data:
    • Performance metrics
    • Crash reports
    • Battery usage
    ↓
Review metrics after 24 hours
    ↓
Identify and fix issues
```

---

## 🎓 Where to Start

### Complete Beginner

1. Read **XCODE_CHECKLIST.md** (step-by-step)
2. Follow every checkbox
3. Test as you go

### Experienced Developer

1. Review **XCODE_FILES_SUMMARY.md** (overview)
2. Skim **XCODE_SETUP_GUIDE.md** (reference)
3. Configure what you need

### Specific Tasks

| Task | Documentation |
|------|---------------|
| First-time setup | **XCODE_CHECKLIST.md** |
| Understanding files | **XCODE_FILES_SUMMARY.md** |
| Detailed config | **XCODE_SETUP_GUIDE.md** |
| Project overview | **PROJECT_STRUCTURE.md** (this file) |
| CI/CD setup | **.github/workflows/ci.yml** + comments |
| Testing info | **README.md** + **SETUP_COMPLETE.md** |

---

## 🔍 Quick Reference

### Build Configurations

```
Debug:
    • Optimization: None (-Onone)
    • Symbols: DWARF
    • Sanitizers: Address OR Thread
    • Use for: Development, debugging
    
Release:
    • Optimization: Speed (-O)
    • Symbols: DWARF with dSYM
    • Sanitizers: None
    • Use for: Testing, profiling, distribution
```

### Test Configurations

```
SmokeTests:
    • Duration: 2-3 minutes
    • Coverage: Critical paths only
    • Run: Every commit
    
FullSuite:
    • Duration: 15-20 minutes
    • Coverage: Everything + unit tests
    • Run: Before release, on main branch
    
AccessibilityTests:
    • Duration: 5 minutes
    • Coverage: VoiceOver, Dynamic Type, etc.
    • Run: Weekly, before release
```

### Capabilities

```
iCloud CloudKit:
    • Container: iCloud.dev.andernet.posture
    • Syncs: GaitSession, UserGoals
    • Environment: Development → Production
    
iCloud Key-Value Store:
    • Syncs: User demographics
    • Max size: 1 MB
    • Auto-merges across devices
    
HealthKit:
    • Reads: Age, sex, height, weight
    • Writes: Gait speed, balance metrics
    • Privacy: User must grant permission
```

---

## ✅ Verification Commands

### Check Configuration

```bash
# Verify entitlements are in build
codesign -d --entitlements - "Your.app"

# Check Info.plist values
/usr/libexec/PlistBuddy -c "Print NSCameraUsageDescription" Info.plist

# Verify SwiftLint is working
swiftlint lint

# Check code coverage
xcrun xccov view --report TestResults.xcresult
```

### Test Automation

```bash
# Run smoke tests
xcodebuild test -scheme "Andernet Posture" -testPlan SmokeTests

# Run with code coverage
xcodebuild test -scheme "Andernet Posture" -enableCodeCoverage YES

# Run specific test
xcodebuild test -scheme "Andernet Posture" \
  -only-testing:Andernet_PostureUITests/NavigationTests/testTabNavigation
```

### CI/CD

```bash
# Lint code
swiftlint lint --strict

# Build for release
xcodebuild build -scheme "Andernet Posture" -configuration Release

# Archive
xcodebuild archive -scheme "Andernet Posture" \
  -archivePath build/App.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath build/App.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist
```

---

## 📊 File Dependencies

```
Andernet_PostureApp.swift
    ↓ reads
Info.plist (privacy descriptions)
    ↓ enforced at runtime
HealthKitService, CaptureViewModel
    ↓ uses permissions from
Andernet Posture.entitlements
    ↓ configured in
Xcode: Signing & Capabilities
    ↓ verified during
Archive & Distribution
    ↓ configured by
ExportOptions.plist
```

---

## 🎉 You're Ready!

This project now has:

✅ Complete Xcode configuration
✅ iCloud CloudKit sync
✅ HealthKit integration
✅ Comprehensive testing
✅ Performance monitoring
✅ CI/CD automation
✅ Distribution setup

**Next**: Follow **XCODE_CHECKLIST.md** to configure everything in Xcode!

---

**Project Structure Version**: 1.0  
**Last Updated**: February 10, 2026  
**For**: Andernet Posture iOS App
