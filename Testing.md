# Hyperchat Testing Guide

This guide explains how to run and write tests for Hyperchat.

## Quick Start

### Running All Tests
```bash
# Using the test runner script
./run-tests.sh

# Using Xcode
# Press Cmd+U in Xcode
```

### Running Specific Tests
```bash
# Run only unit tests
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests

# Run only UI tests  
xcodebuild test -scheme Hyperchat -only-testing:HyperchatUITests

# Run a specific test class
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests/ServiceConfigurationTests

# Run a specific test method
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests/ServiceConfigurationTests/testChatGPTConfiguration
```

## Test Structure

```
HyperchatTests/              # Unit tests
├── ServiceConfigurationTests.swift
├── AIServiceTests.swift
├── ServiceManagerTests.swift
├── WebViewMocks.swift       # Mock objects
└── Info.plist

HyperchatUITests/            # UI tests
├── HyperchatUITests.swift
└── Info.plist
```

## What's Being Tested

### Unit Tests

1. **ServiceConfigurationTests**
   - Service URL configuration
   - URL generation with query parameters
   - Special character encoding
   - User agent strings

2. **AIServiceTests**
   - Default service configurations
   - Service activation methods
   - Service ordering
   - Icon names

3. **ServiceManagerTests**
   - Service loading and initialization
   - Service toggling
   - WebView lifecycle management
   - Service reordering
   - Loading states

### UI Tests

1. **Basic Launch Tests**
   - App launches successfully
   - Floating button appears
   - Main window shows on startup

2. **User Interactions**
   - Floating button opens main window
   - Service tabs are clickable
   - Prompt input works
   - Keyboard shortcuts function

3. **Window Management**
   - Multiple windows can be created
   - Services can be closed
   - Window hibernation works

## Writing New Tests

### Unit Test Example
```swift
func testNewFeature() {
    // Arrange: Set up test data
    let service = createTestService()
    
    // Act: Perform the action
    let result = service.doSomething()
    
    // Assert: Verify the result
    XCTAssertEqual(result, expectedValue)
}
```

### UI Test Example
```swift
func testButtonClick() {
    // Find UI element
    let button = app.buttons["ButtonIdentifier"]
    
    // Wait for it to exist
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    
    // Interact with it
    button.click()
    
    // Verify result
    XCTAssertTrue(app.windows["ResultWindow"].exists)
}
```

## Using Mocks

We've created mock objects to test without real WebViews:

```swift
// Create a mock WebView
let mockWebView = MockWebView()
mockWebView.url = URL(string: "https://example.com")

// Set up expected JavaScript results
mockWebView.javaScriptResults["document.title"] = "Test Page"

// Use in tests
let title = try await mockWebView.evaluateJavaScript("document.title")
XCTAssertEqual(title as? String, "Test Page")
```

## Continuous Integration

Tests run automatically on GitHub Actions when you:
- Push to main or develop branches
- Create a pull request

The CI pipeline:
1. Builds the app
2. Runs unit tests
3. Runs UI tests
4. Generates coverage reports
5. Runs SwiftLint

## Test Coverage

To view test coverage in Xcode:
1. Run tests with Cmd+U
2. Open the Report Navigator (Cmd+9)
3. Select the latest test run
4. Click "Coverage" tab

## Debugging Failed Tests

1. **In Xcode**: Click on the test failure to see details
2. **In Terminal**: Check `TestResults/*.log` files
3. **In CI**: Download test artifacts from GitHub Actions

## Best Practices

1. **Test Naming**: Use descriptive names that explain what's being tested
   ```swift
   func testServiceManager_WhenServiceDisabled_RemovesWebView()
   ```

2. **One Assertion Per Test**: Keep tests focused on one behavior

3. **Use Setup/Teardown**: Initialize common test data in `setUp()`

4. **Mock External Dependencies**: Don't rely on network or real WebViews

5. **Test Edge Cases**: Empty strings, nil values, boundary conditions

## Common Issues

### Tests Not Found
Make sure test methods start with `test`:
```swift
func testSomething() { } // ✅ Will be found
func checkSomething() { } // ❌ Won't be found
```

### UI Tests Failing
- Ensure accessibility identifiers are set in the app
- Use `waitForExistence()` before interacting with elements
- Run on a consistent macOS version

### WebView Tests
- Use MockWebView instead of real WKWebView
- Test business logic separately from WebKit integration