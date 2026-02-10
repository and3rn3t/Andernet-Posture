# Xcode Project Configuration Guide

This guide walks you through setting up all Xcode-specific configurations for the Andernet Posture app.

## 📋 Table of Contents

1. [Project Settings](#project-settings)
2. [Capabilities & Entitlements](#capabilities--entitlements)
3. [Build Settings](#build-settings)
4. [Scheme Configuration](#scheme-configuration)
5. [Test Plans](#test-plans)
6. [CloudKit Setup](#cloudkit-setup)
7. [Code Signing](#code-signing)
8. [Archive & Distribution](#archive--distribution)
9. [Performance Monitoring](#performance-monitoring)
10. [CI/CD Integration](#cicd-integration)

---

## 1. Project Settings

### Files Created

✅ **Andernet Posture.entitlements** - App capabilities and permissions
✅ **Info.plist** - Privacy descriptions and app configuration
✅ **SmokeTests.xctestplan** - Fast smoke test suite
✅ **FullSuite.xctestplan** - Complete regression test suite
✅ **AccessibilityTests.xctestplan** - Accessibility-focused tests
✅ **MetricsManager.swift** - Production performance monitoring

### Minimum Deployment Target

**Set to iOS 17.0** (required for ARKit body tracking and SwiftData)

1. In Xcode, select your project in the navigator
2. Select the "Andernet Posture" target
3. Go to "General" tab
4. Set "Minimum Deployments" to **iOS 17.0**

### Bundle Identifier

Ensure your bundle identifier matches: **dev.andernet.posture**

1. Target → General → Identity
2. Bundle Identifier: `dev.andernet.posture`

---

## 2. Capabilities & Entitlements

### Add the Entitlements File to Your Target

1. Select your project in Xcode
2. Select the "Andernet Posture" target
3. Go to "Build Settings" tab
4. Search for "Code Signing Entitlements"
5. Set the value to: `Andernet Posture.entitlements`

### Enable Capabilities

Go to **Target → Signing & Capabilities** and add:

#### ✅ iCloud

1. Click "+ Capability" button
2. Add "iCloud"
3. Check **CloudKit**
4. Check **Key-value storage**
5. Under CloudKit containers, ensure `iCloud.dev.andernet.posture` is selected
   - If not listed, click "+" and add it

#### ✅ HealthKit

1. Click "+ Capability"
2. Add "HealthKit"
3. HealthKit will automatically use the entitlements from your `.entitlements` file

#### ⚠️ Background Modes (Optional)

Only if you need background HealthKit syncing:

1. Click "+ Capability"
2. Add "Background Modes"
3. Check:
   - ☑️ Background fetch
   - ☑️ HealthKit

---

## 3. Build Settings

### Key Settings to Configure

1. Select your target
2. Go to "Build Settings" tab
3. Make sure "All" and "Combined" are selected at the top

#### Swift Optimization Level

- **Debug**: `-Onone` (no optimization for debugging)
- **Release**: `-O` (optimize for speed) or `-Osize` (optimize for size)

Search for: "Swift Compiler - Code Generation" → "Optimization Level"

#### Debug Information Format

- **Debug**: `DWARF`
- **Release**: `DWARF with dSYM File`

This enables proper crash symbolication in production.

Search for: "Debug Information Format"

#### Strip Debug Symbols During Copy

- **Debug**: `NO`
- **Release**: `YES`

Search for: "Strip Debug Symbols During Copy"

#### Enable Testability

- **Debug**: `YES`
- **Release**: `NO`

Search for: "Enable Testability"

#### Other Settings

```
SWIFT_VERSION = 5.9 (or latest)
IPHONEOS_DEPLOYMENT_TARGET = 17.0
TARGETED_DEVICE_FAMILY = 1,2 (iPhone and iPad)
```

---

## 4. Scheme Configuration

### Edit Your Scheme

**Product → Scheme → Edit Scheme** (or ⌘<)

#### Run Configuration (Debug)

1. Go to "Run" tab
2. Build Configuration: **Debug**
3. Options:
   - ☑️ Metal API Validation (catches GPU errors)
   - ☑️ GPU Frame Capture (for ARKit debugging)

#### Test Configuration

1. Go to "Test" tab
2. Options:
   - ☑️ **Code Coverage** - Enable for all targets
   - Select targets: Andernet Posture
   - ☑️ **Gather coverage for some targets** → Select your main target

3. **Diagnostics** (Important!):
   - ☑️ **Address Sanitizer** (catches memory errors) - Debug only
   - ☑️ **Thread Sanitizer** (catches threading bugs) - Debug only
   - ⚠️ Don't enable both at once - run separately!
   
4. **Test Plans**:
   - Click "Convert to use Test Plans..."
   - Select one of the created plans (SmokeTests.xctestplan, FullSuite.xctestplan, etc.)

#### Profile Configuration

1. Go to "Profile" tab
2. Build Configuration: **Release**
3. Use this for Instruments profiling (Leaks, Allocations, Time Profiler)

#### Archive Configuration

1. Go to "Archive" tab
2. Build Configuration: **Release**

---

## 5. Test Plans

### Using Test Plans

Three test plans have been created:

#### 1. **SmokeTests.xctestplan** (Fast - 2-3 min)

Run before every commit:
- Basic app launch
- Tab navigation
- Critical path tests

```bash
xcodebuild test \
  -scheme "Andernet Posture" \
  -testPlan SmokeTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### 2. **FullSuite.xctestplan** (Complete - 15-20 min)

Run before release:
- All UI tests
- All unit tests
- Code coverage enabled

```bash
xcodebuild test \
  -scheme "Andernet Posture" \
  -testPlan FullSuite \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### 3. **AccessibilityTests.xctestplan** (Weekly)

Dedicated accessibility validation:
- VoiceOver support
- Dynamic Type
- Touch target sizes

```bash
xcodebuild test \
  -scheme "Andernet Posture" \
  -testPlan AccessibilityTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Switching Test Plans in Xcode

1. Select your scheme dropdown (top of Xcode)
2. Click "Edit Scheme"
3. Go to "Test" tab
4. Under "Test Plans", select the plan you want

---

## 6. CloudKit Setup

### CloudKit Dashboard Configuration

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Sign in with your Apple Developer account
3. Select your app: **dev.andernet.posture**

#### Create Container (if not exists)

1. Click "CloudKit Database" button
2. Create container: `iCloud.dev.andernet.posture`
3. You'll see "Development" and "Production" environments

#### Verify Schema

Your app will automatically create the schema when you first run it, but you can verify:

1. Select your container
2. Go to "Schema" section
3. Look for:
   - **GaitSession** record type
   - **UserGoals** record type

#### Development vs Production

- **Development**: Used when running from Xcode or TestFlight internal builds
- **Production**: Used for App Store builds

You must deploy schema from Development to Production before release:

1. Go to Schema section
2. Click "Deploy Schema Changes"
3. Select changes to deploy
4. Deploy to Production

### Testing iCloud Sync

1. Run app in Simulator or on device
2. Sign in with iCloud account (Settings → iCloud)
3. Create a gait session
4. Check CloudKit Dashboard → Data → Development
5. You should see records created

---

## 7. Code Signing

### Automatic Signing (Recommended for Development)

1. Target → Signing & Capabilities
2. Check ☑️ **Automatically manage signing**
3. Select your **Team**
4. Xcode will handle provisioning profiles automatically

### Manual Signing (For Distribution)

1. Uncheck "Automatically manage signing"
2. Select appropriate **Provisioning Profile** for:
   - Debug
   - Release
   - Archive

### Troubleshooting Signing Issues

**Error: "Failed to register bundle identifier"**
- Bundle ID is already taken
- Try: `dev.andernet.posture.yourname`

**Error: "No profiles for 'dev.andernet.posture' were found"**
- Create App ID in Developer Portal: [Apple Developer](https://developer.apple.com/account)
- Enable iCloud and HealthKit capabilities for that App ID

---

## 8. Archive & Distribution

### Creating an Archive

1. Select "Any iOS Device (arm64)" as destination
2. Product → Archive (⌘⇧B)
3. Wait for archive to complete
4. Organizer window will open automatically

### Distribution Options

#### TestFlight (Beta Testing)

1. In Organizer, select your archive
2. Click "Distribute App"
3. Select "TestFlight & App Store"
4. Follow prompts to upload

#### App Store

1. Same as TestFlight
2. After upload, go to App Store Connect
3. Create app listing, submit for review

#### Ad Hoc / Enterprise

1. Select "Ad Hoc" or "Enterprise"
2. Select devices or distribution method
3. Export IPA file

---

## 9. Performance Monitoring

### MetricKit Integration

**MetricsManager.swift** has been integrated into your app. It will:

✅ Track app performance in production
✅ Monitor CPU, memory, battery usage
✅ Collect crash reports
✅ Detect hangs and performance issues

**Only enabled in TestFlight and Production** (not Debug builds)

### Viewing Metrics

Metrics are delivered daily by iOS. To view them:

1. Run your app in TestFlight or production
2. Check logs in your app after 24 hours
3. Metrics will be logged to Console.app or device logs

### Instruments Profiling

For development performance testing:

1. **Product → Profile** (⌘I)
2. Select an instrument:
   - **Time Profiler**: Find slow code
   - **Allocations**: Track memory usage
   - **Leaks**: Find memory leaks
   - **Core Animation**: Find UI hitches
   - **Energy Log**: Find battery drain

### Memory Graph Debugging

To find memory leaks:

1. Run your app in Debug
2. Use the app (capture sessions, navigate)
3. Click the "Debug Memory Graph" button in debug bar
4. Look for purple "!" icons (leaked objects)

---

## 10. CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/test.yml`:

```yaml
name: Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-14
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.2.app
    
    - name: Build and Test (Smoke Tests)
      run: |
        xcodebuild test \
          -scheme "Andernet Posture" \
          -testPlan SmokeTests \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.2' \
          -resultBundlePath TestResults.xcresult \
          -enableCodeCoverage YES
    
    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: test-results
        path: TestResults.xcresult
    
    - name: Generate Coverage Report
      run: |
        xcrun xccov view --report --json TestResults.xcresult > coverage.json
        
    - name: Full Regression (On Main)
      if: github.ref == 'refs/heads/main'
      run: |
        xcodebuild test \
          -scheme "Andernet Posture" \
          -testPlan FullSuite \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.2'
```

### Fastlane Setup (Optional)

For automated builds and distribution:

```ruby
# Fastfile
default_platform(:ios)

platform :ios do
  desc "Run smoke tests"
  lane :smoke_tests do
    run_tests(
      scheme: "Andernet Posture",
      testplan: "SmokeTests",
      devices: ["iPhone 15 Pro"]
    )
  end
  
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      scheme: "Andernet Posture",
      export_method: "app-store"
    )
    upload_to_testflight
  end
end
```

---

## 🔍 Verification Checklist

Before your first build:

### Files
- [ ] `Andernet Posture.entitlements` added to project
- [ ] `Info.plist` contains all privacy descriptions
- [ ] `.entitlements` file path set in Build Settings
- [ ] `MetricsManager.swift` added to project

### Capabilities
- [ ] iCloud enabled (CloudKit + Key-Value Storage)
- [ ] HealthKit enabled
- [ ] Background Modes configured (if needed)

### Build Settings
- [ ] Minimum Deployment Target: iOS 17.0
- [ ] Bundle Identifier: `dev.andernet.posture`
- [ ] Debug Information Format: DWARF with dSYM (Release)
- [ ] Code Signing Entitlements path set

### Scheme
- [ ] Code Coverage enabled in Test configuration
- [ ] Thread Sanitizer configured (run separately from Address Sanitizer)
- [ ] Test Plan selected (SmokeTests recommended for quick feedback)

### CloudKit
- [ ] Container `iCloud.dev.andernet.posture` created
- [ ] Signed into iCloud in Simulator/Device
- [ ] App tested with iCloud sync

### Code Signing
- [ ] Signing configured (Automatic or Manual)
- [ ] Provisioning profiles selected
- [ ] No signing errors when building

---

## 🆘 Troubleshooting

### "Failed to create provisioning profile"

**Solution**: Go to Apple Developer Portal → Certificates, Identifiers & Profiles → Create App ID with correct bundle identifier

### "CloudKit operation failed"

**Solution**: 
1. Check iCloud is signed in
2. Verify container identifier matches entitlements
3. Check CloudKit Dashboard shows your container

### "HealthKit not available"

**Solution**: 
1. HealthKit doesn't work in Simulator for all features
2. Test on real device
3. Verify entitlements file is properly linked

### Tests are flaky

**Solution**:
1. Ensure animations are disabled (test plans do this)
2. Add proper waits for UI elements
3. Run tests individually to isolate issues

### Archive fails

**Solution**:
1. Clean build folder (⌘⇧K)
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Ensure all code signing is configured correctly

---

## 📚 Additional Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [MetricKit Documentation](https://developer.apple.com/documentation/metrickit)
- [App Store Connect](https://appstoreconnect.apple.com)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)

---

## ✅ Next Steps

1. **Immediate**: Add files to Xcode project, configure capabilities
2. **Before first TestFlight**: Set up CloudKit container, test sync
3. **Before App Store**: Create App Store Connect listing, prepare metadata
4. **Ongoing**: Monitor MetricKit data, review test results, maintain code coverage

---

**Questions?** Check the inline code comments or Apple's official documentation.

**Happy Building! 🚀**
