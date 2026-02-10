# Andernet Posture UI Tests

This directory contains comprehensive UI tests for the Andernet Posture iOS app using XCTest and XCUITest.

## Test Structure

### Base Infrastructure

- **BaseUITest.swift** - Base class with common setup and helper methods for all UI tests
- **PageObjects.swift** - Page Object pattern implementation for UI elements and screens

### Test Suites

#### 1. Smoke Tests (`Andernet_PostureUITests.swift`)

Basic functionality tests to ensure the app launches and core features work:

- App launch verification
- Tab existence checks
- Basic navigation
- Crash prevention tests
- Launch performance baseline

#### 2. Navigation Tests (`NavigationTests.swift`)

Comprehensive tab navigation and state management:

- Tab bar existence and accessibility
- Navigation between all tabs
- State preservation during navigation
- Rapid tab switching stability
- Tab selection state verification

#### 3. Session Flow Tests (`SessionFlowTests.swift`)

User flows for session capture and management:

- Sessions list display
- Empty state handling
- Session detail navigation
- Capture view functionality
- Camera permissions flow
- Dashboard interactions
- Complete user journey testing

#### 4. Accessibility Tests (`AccessibilityTests.swift`)

Accessibility and VoiceOver support:

- Tab bar accessibility labels
- Element accessibility across all views
- Touch target size verification
- Dynamic Type support
- VoiceOver navigation order
- Color contrast and visibility

#### 5. Performance Tests (`PerformanceTests.swift`)

App performance and responsiveness:

- App launch performance (cold & warm start)
- Tab switching performance
- View load times
- Scrolling performance
- Memory usage monitoring
- Rapid interaction stability
- Animation smoothness

#### 6. Launch Tests (`Andernet_PostureUITestsLaunchTests.swift`)

Configuration-specific launch tests:

- Launch in different orientations
- Launch screenshot capture
- Offline mode launch

## Running Tests

### From Xcode

1. Open `Andernet Posture.xcodeproj`
2. Select the Product > Test menu (⌘U)
3. Or use the Test Navigator (⌘6) to run specific tests

### From Command Line

```bash
# Run all UI tests
xcodebuild test -scheme "Andernet Posture" -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test class
xcodebuild test -scheme "Andernet Posture" -only-testing:Andernet_PostureUITests/NavigationTests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test method
xcodebuild test -scheme "Andernet Posture" -only-testing:Andernet_PostureUITests/NavigationTests/testNavigateToDashboard -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Using Test Plans

You can create test plans in Xcode to:

- Run different test suites separately
- Test with different configurations (languages, regions, etc.)
- Parallelize test execution
- Control test execution order

## Test Environments

### Launch Arguments

The tests set the following launch arguments:

- `UI_TESTING` - Indicates the app is running under UI test automation

### Launch Environment Variables

- `IS_UI_TESTING=1` - Flag for UI testing mode
- `DISABLE_ANIMATIONS=1` - Speeds up test execution
- `NETWORK_OFFLINE=1` - (Optional) Simulates offline mode

### Using in Your App

You can check these in your app code:

```swift
if ProcessInfo.processInfo.arguments.contains("UI_TESTING") {
    // Disable analytics, use mock data, etc.
}

if ProcessInfo.processInfo.environment["DISABLE_ANIMATIONS"] == "1" {
    UIView.setAnimationsEnabled(false)
}
```

## Page Object Pattern

Tests use the Page Object pattern to:

- Encapsulate UI element location logic
- Make tests more maintainable
- Provide reusable navigation helpers
- Improve test readability

### Available Page Objects

- `TabBar` - Main tab bar navigation
- `DashboardPage` - Dashboard view elements
- `SessionsListPage` - Sessions list and cells
- `CapturePage` - Capture view and controls
- `ClinicalTestsPage` - Clinical tests view
- `SettingsPage` - Settings view
- `SessionDetailPage` - Session detail view
- `AlertHelper` - System alerts and dialogs

## Best Practices

### Writing Tests

1. **Inherit from BaseUITest** - Use the base class for common setup
2. **Use Page Objects** - Don't query elements directly in tests
3. **Wait for Elements** - Use `waitForElement()` for better reliability
4. **Take Screenshots** - Capture important states for debugging
5. **Handle Permissions** - Always handle system permission alerts
6. **Use Descriptive Names** - Test names should clearly describe what they test
7. **Keep Tests Independent** - Each test should be able to run standalone

### Debugging Failed Tests

1. Check attached screenshots in test results
2. Review console logs for assertion failures
3. Run individual tests to isolate issues
4. Use breakpoints in test code
5. Enable slow animations in simulator for visual debugging

### Performance Tests

- Performance tests use `measure(metrics:)` blocks
- Run on actual devices for reliable metrics
- Keep iteration counts reasonable (3-5)
- Baseline metrics may vary by device

## Continuous Integration

### Setting Up CI

For CI/CD pipelines (GitHub Actions, Jenkins, etc.):

```yaml
# Example GitHub Actions workflow
- name: Run UI Tests
  run: |
    xcodebuild test \
      -scheme "Andernet Posture" \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0' \
      -resultBundlePath TestResults.xcresult \
      -enableCodeCoverage YES
```

## Code Coverage

Enable code coverage in your scheme settings:

1. Edit Scheme > Test > Options
2. Check "Code Coverage"
3. Select targets to gather coverage for

View coverage reports:

- Xcode: Report Navigator (⌘9) > Coverage tab
- Command line: `xcrun xccov view --report TestResults.xcresult`

## Maintaining Tests

### When UI Changes

1. Update relevant Page Objects
2. Update element identifiers if needed
3. Run full test suite to catch regressions
4. Update screenshots if they're reference images

### When Adding Features

1. Add new Page Object if needed
2. Add corresponding tests
3. Update existing flows if they're affected
4. Consider accessibility from the start

## Accessibility Identifiers

For reliable UI testing, add accessibility identifiers to your SwiftUI views:

```swift
Button("Start Capture") {
    // action
}
.accessibilityIdentifier("startCaptureButton")
```

This makes elements easier to locate in tests and improves VoiceOver support.

## Troubleshooting

### Common Issues

**Tests timing out**

- Increase timeout values in `waitForElement()`
- Check if animations are disabled
- Verify simulator performance

**Elements not found**

- Print element hierarchy: `print(app.debugDescription)`
- Check accessibility identifiers
- Verify element exists in current view state

**Flaky tests**

- Add proper waits for animations
- Ensure tests are independent
- Check for timing dependencies
- Use `XCTNSPredicateExpectation` for complex waits

**Permission dialogs**

- Reset simulator permissions between runs
- Handle alerts in test setup
- Use `addUIInterruptionMonitor()` for system dialogs

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [WWDC XCTest Videos](https://developer.apple.com/videos/frameworks/testing)
- [UI Testing Cheat Sheet](https://www.hackingwithswift.com/articles/148/xcode-ui-testing-cheat-sheet)
- [Accessibility Testing Guide](https://developer.apple.com/documentation/accessibility)

## Contact

For questions or issues with the test suite, contact the development team or file an issue in the project repository.
