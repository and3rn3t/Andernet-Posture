# Xcode Setup Checklist

Use this checklist to verify your Xcode project is properly configured.

## 📁 Files to Add to Xcode

Open your project in Xcode and add these files:

- [ ] **Andernet Posture.entitlements** - Drag into project navigator
- [ ] **Info.plist** - Replace existing or merge content
- [ ] **MetricsManager.swift** - Add to your main target
- [ ] **SmokeTests.xctestplan** - Add to project (appears in Test Navigator)
- [ ] **FullSuite.xctestplan** - Add to project
- [ ] **AccessibilityTests.xctestplan** - Add to project
- [ ] **.swiftlint.yml** - Keep in root directory (don't add to target)
- [ ] **Scripts/** folder - Add to project for build scripts

## ⚙️ Project Settings

### Target → General

- [ ] Display Name: **Andernet Posture**
- [ ] Bundle Identifier: **dev.andernet.posture**
- [ ] Version: **1.0** (or your version)
- [ ] Build: **1** (will auto-increment)
- [ ] Minimum Deployments: **iOS 17.0**
- [ ] Supported Destinations: **iPhone, iPad** (or just iPhone)

### Target → Build Settings

- [ ] Search "Code Signing Entitlements"
  - Set to: `Andernet Posture.entitlements`

- [ ] Search "Swift Optimization Level"
  - Debug: `-Onone`
  - Release: `-O`

- [ ] Search "Debug Information Format"
  - Debug: `DWARF`
  - Release: `DWARF with dSYM File`

- [ ] Search "Strip Debug Symbols"
  - Debug: `NO`
  - Release: `YES`

## 🔐 Signing & Capabilities

### Target → Signing & Capabilities

- [ ] **Signing**
  - [ ] ☑️ Automatically manage signing (or configure manually)
  - [ ] Select your Team

- [ ] **iCloud** (Click "+ Capability" if not present)
  - [ ] ☑️ CloudKit
  - [ ] ☑️ Key-value storage
  - [ ] Container: `iCloud.dev.andernet.posture` (create if needed)

- [ ] **HealthKit** (Click "+ Capability")
  - [ ] Capability added (no additional settings needed)

- [ ] **Background Modes** (Optional - only if needed)
  - [ ] ☑️ Background fetch
  - [ ] ☑️ HealthKit

## 🧪 Scheme Configuration

### Edit Scheme (Product → Scheme → Edit Scheme)

#### Run Tab

- [ ] Build Configuration: **Debug**
- [ ] Options:
  - [ ] ☑️ Metal API Validation
  - [ ] ☑️ GPU Frame Capture

#### Test Tab

- [ ] Build Configuration: **Debug**
- [ ] Test Plan: Select **SmokeTests** (for quick feedback)
- [ ] Options:
  - [ ] ☑️ Code Coverage
  - [ ] ☑️ Gather coverage for: **Andernet Posture** target

- [ ] Diagnostics (run separately!):
  - [ ] ☑️ Address Sanitizer (for memory errors)
  - [ ] OR ☑️ Thread Sanitizer (for threading bugs)
  - [ ] ⚠️ Don't enable both at once

#### Profile Tab

- [ ] Build Configuration: **Release**

#### Archive Tab

- [ ] Build Configuration: **Release**

## 🏗️ Build Phases (Optional Enhancements)

### Target → Build Phases

#### Add SwiftLint Script

1. [ ] Click "+" → New Run Script Phase
2. [ ] Name: "SwiftLint"
3. [ ] Place AFTER "Compile Sources"
4. [ ] Shell: `/bin/bash`
5. [ ] Script:
   ```bash
   if which swiftlint >/dev/null; then
     swiftlint
   else
     echo "warning: SwiftLint not installed"
   fi
   ```
6. [ ] ☑️ Based on dependency analysis

#### Add Build Number Auto-Increment (Optional)

1. [ ] Click "+" → New Run Script Phase
2. [ ] Name: "Auto-increment Build Number"
3. [ ] Place BEFORE "Compile Sources"
4. [ ] Shell: `/bin/bash`
5. [ ] Script:
   ```bash
   if [ "$CONFIGURATION" == "Release" ]; then
       buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${INFOPLIST_FILE}")
       buildNumber=$((buildNumber + 1))
       /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "${INFOPLIST_FILE}"
       echo "Build number incremented to: $buildNumber"
   fi
   ```

## ☁️ CloudKit Setup

### CloudKit Dashboard

1. [ ] Go to [icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard)
2. [ ] Sign in with Apple Developer account
3. [ ] Find container: `iCloud.dev.andernet.posture`
   - [ ] If doesn't exist: Create it
4. [ ] Select **Development** environment
5. [ ] Go to **Schema** section
   - Schema will auto-create when you run the app
6. [ ] Before App Store release:
   - [ ] Deploy schema from Development to Production

### Test iCloud Sync

1. [ ] Sign into iCloud in Simulator/Device
   - Settings → [Your Name] → iCloud
2. [ ] Run app
3. [ ] Create a gait session
4. [ ] Check CloudKit Dashboard → Data → Development
   - [ ] Verify records appear

## 🔬 Testing

### Install SwiftLint (Optional)

```bash
brew install swiftlint
```

### Run Tests

- [ ] **Quick Smoke Test**: ⌘U (with SmokeTests plan selected)
- [ ] **Full Regression**: Switch to FullSuite plan, then ⌘U
- [ ] **Accessibility**: Switch to AccessibilityTests plan, then ⌘U

### Command Line Testing

```bash
# Smoke tests (fast)
xcodebuild test -scheme "Andernet Posture" -testPlan SmokeTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Full suite (comprehensive)
xcodebuild test -scheme "Andernet Posture" -testPlan FullSuite \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 🚀 First Build Verification

### Build the App

1. [ ] Select a simulator: **iPhone 15 Pro** (or your device)
2. [ ] Build: **⌘B**
3. [ ] Verify no build errors
4. [ ] Run: **⌘R**
5. [ ] App launches successfully

### Check Console for Logs

Look for these in Xcode's console:

- [ ] `ModelContainer created successfully`
- [ ] `MetricKit monitoring enabled` (Release builds only)
- [ ] No red error messages

### Test Key Features

- [ ] Camera permission requested
- [ ] HealthKit permission requested
- [ ] Can navigate between tabs
- [ ] Can start AR capture session
- [ ] Data persists between launches

## 📊 Performance Testing

### Use Instruments

1. [ ] **Product → Profile** (⌘I)
2. [ ] Select instrument:
   - [ ] **Time Profiler** - Find CPU bottlenecks
   - [ ] **Allocations** - Track memory usage
   - [ ] **Leaks** - Find memory leaks
   - [ ] **Core Animation** - Find UI hitches

### Memory Graph

1. [ ] Run app in Debug
2. [ ] Use app extensively
3. [ ] Click Debug Memory Graph button (in debug bar)
4. [ ] Look for purple "!" leak indicators

## 📦 Archive & Distribution

### Create Archive

1. [ ] Select destination: **Any iOS Device (arm64)**
2. [ ] **Product → Archive** (⌘⇧B)
3. [ ] Wait for archive to complete
4. [ ] Organizer opens automatically

### Distribute

- [ ] **TestFlight**: Select archive → Distribute → TestFlight & App Store
- [ ] **App Store**: Same as TestFlight, then submit in App Store Connect
- [ ] **Ad Hoc**: Select archive → Distribute → Ad Hoc

## 🔄 CI/CD Setup (Optional)

### GitHub Actions

If using GitHub:

- [ ] Workflows already created in `.github/workflows/ci.yml`
- [ ] Push code to trigger builds
- [ ] Check Actions tab for results

### Enable GitHub Actions

1. [ ] Go to repo Settings → Actions → General
2. [ ] Allow all actions
3. [ ] Push code to trigger workflow

## 📝 Documentation

Read these files for details:

- [ ] **XCODE_SETUP_GUIDE.md** - Complete setup instructions
- [ ] **SETUP_COMPLETE.md** - UI testing documentation
- [ ] **README.md** - Test suite overview

## ✅ Final Verification

### All Green Checkmarks

- [ ] App builds successfully
- [ ] Smoke tests pass (⌘U)
- [ ] No signing errors
- [ ] CloudKit sync works
- [ ] HealthKit permissions work
- [ ] Camera permissions work
- [ ] Archive succeeds

### Ready for Development

Your project is now fully configured! 🎉

---

## 🆘 Common Issues

**"No provisioning profile found"**
→ Enable automatic signing or create App ID in Developer Portal

**"CloudKit operation failed"**
→ Sign into iCloud in Settings, verify container name

**"HealthKit not available"**
→ Test on real device, not all features work in Simulator

**Build Phase scripts not running**
→ Check script permissions: `chmod +x Scripts/*.sh`

**Tests failing to find elements**
→ Add accessibility identifiers to your SwiftUI views

---

## 📚 Next Steps

1. **Customize UI Tests**: Add accessibility identifiers to views
2. **Enable CI/CD**: Push code to trigger automated builds
3. **TestFlight**: Distribute beta builds to testers
4. **Monitor Metrics**: Check MetricKit logs after 24 hours
5. **App Store**: Create listing in App Store Connect

---

**All done?** Start building! 🚀

**Need help?** Check `XCODE_SETUP_GUIDE.md` for detailed instructions.
