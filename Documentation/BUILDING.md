# Building Hyperchat from Source

This guide explains how to build Hyperchat for macOS from source code, including requirements for external contributors who don't have access to the original signing certificates.

## Prerequisites

### System Requirements
- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later
- Swift 5.7 or later
- Command Line Tools for Xcode

### Development Dependencies
- Git (for source code management)
- Swift Package Manager (included with Xcode)

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/***REMOVED-USERNAME***/hyperchat-macos.git
   cd hyperchat-macos
   ```

2. **Set up configuration**:
   ```bash
   cp Sources/Hyperchat/Config.swift.template Sources/Hyperchat/Config.swift
   ```
   Edit `Config.swift` to add your own API keys (see Configuration section below).

3. **Open in Xcode**:
   ```bash
   open Hyperchat.xcodeproj
   ```

4. **Build and run**:
   - Select the "Hyperchat" scheme
   - Choose your target device (Any Mac)
   - Press Cmd+R to build and run

## Configuration

### API Keys Setup

The application requires API keys for analytics (optional). Copy the template file and add your keys:

```bash
cp Sources/Hyperchat/Config.swift.template Sources/Hyperchat/Config.swift
```

Edit `Config.swift` and replace placeholders:
- `AMPLITUDE_API_KEY`: For usage analytics (optional - leave empty to disable)

### Claude Settings (Optional)

If you use Claude Code for development:
```bash
cp .claude/settings.template.json .claude/settings.local.json
```
Edit the local settings file for your environment.

## Code Signing & Distribution

### For Development Builds

For local development, Xcode will automatically handle code signing with your personal Apple Developer account or create unsigned builds for local testing.

### For Distribution Builds

**Note**: External contributors cannot create distribution builds identical to the official releases without access to the original Apple Developer account and certificates.

#### Debug Entitlements
Development builds use `Hyperchat.entitlements` which includes:
- Network access for AI service communication
- Hardware acceleration for WebView performance

#### Release Entitlements
Distribution builds use `Hyperchat.Release.entitlements` with hardened runtime requirements.

### Building Without Original Certificates

External contributors can:

1. **Create Debug Builds**: Use your own Apple Developer account for local testing
2. **Modify Bundle Identifier**: Change the bundle identifier in project settings to use your own
3. **Update Sparkle Configuration**: Modify `Info.plist` to use your own update feed and keys

To build with your own certificate:
1. Open Hyperchat.xcodeproj in Xcode
2. Select the project root in navigator
3. Go to "Signing & Capabilities"
4. Change "Team" to your Apple Developer account
5. Update "Bundle Identifier" to something unique (e.g., `com.yourname.hyperchat`)

## Testing

### Running Tests

```bash
# Run all tests
./Scripts/run-tests.sh

# Run specific test suite
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests

# Run UI tests only
xcodebuild test -scheme Hyperchat -only-testing:HyperchatUITests
```

### Test Requirements

- Tests run in headless mode and don't require GUI interaction
- UI tests use accessibility identifiers for reliable automation
- Some tests may require network access for service validation

## Build Scripts

The project includes several automation scripts:

- `Scripts/run-tests.sh`: Comprehensive test runner
- `Scripts/deploy-hyperchat.sh`: Full deployment pipeline (requires original certificates)
- `Scripts/cleanup-tests.sh`: Clean test artifacts

External contributors can use the test scripts but deployment scripts require the original signing setup.

## Common Build Issues

### Missing Config.swift
**Error**: "No such file or directory: Config.swift"
**Solution**: Copy and configure the template file as described above.

### Code Signing Errors
**Error**: Signing certificate not found
**Solution**: 
1. Use your own Apple Developer account in Xcode
2. Change the bundle identifier to avoid conflicts
3. For local testing, disable signing in build settings

### WebView Crashes in Debug
**Issue**: WebView components may crash in debug builds
**Solution**: This is normal for development builds. Release builds have additional stability optimizations.

### Test Failures
**Issue**: Some tests fail due to network dependencies
**Solution**: Ensure stable internet connection and retry. Some service-specific tests may fail if AI services are unavailable.

## Architecture Overview

For understanding the codebase structure, see:
- `README.md`: Complete system architecture
- `Documentation/`: Detailed guides and notes
- `Documentation/Websites/`: Browser automation patterns

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with appropriate tests
4. Run the test suite: `./Scripts/run-tests.sh`
5. Submit a pull request

### Documentation Standards

This project follows an "LLM-First" documentation approach:
- Use formal Swift documentation comments (`///`) for all public APIs
- Document cross-file connections explicitly
- Explain timing and WebKit-specific workarounds
- See `CLAUDE.md` for detailed documentation standards

## Support

For build issues:
1. Check this document first
2. Review existing GitHub issues
3. Create a new issue with detailed build logs if needed

The project maintainers can provide guidance on build setup but cannot share original signing certificates or API keys for security reasons.