# Swift Package Manager Development Guide

This project is now configured for SPM-first development, allowing you to work primarily from your IDE without needing Xcode's UI.

## Quick Start

### Running Tests (No Xcode Required!)
```bash
# Run all tests
./swift-test.sh

# Run specific test suites
./swift-test.sh unit        # Unit tests only
./swift-test.sh ui          # UI tests only
./swift-test.sh service     # ServiceConfiguration tests
./swift-test.sh manager     # ServiceManager tests

# Run tests matching a pattern
./swift-test.sh --filter testChatGPT

# List all available tests
./swift-test.sh --list
```

### Building the App
```bash
# Debug build
swift build

# Release build
swift build -c release

# Run the app
swift run
```

## Project Structure

```
hyperchat-macos/
├── Package.swift           # SPM manifest (primary build system)
├── Sources/
│   └── Hyperchat/         # All source files and resources
│       ├── *.swift        # Swift source files
│       ├── Assets.xcassets
│       ├── MainMenu.xib
│       └── Orbitron-Bold.ttf
├── Tests/
│   ├── HyperchatTests/    # Unit tests
│   └── HyperchatUITests/  # UI tests
└── swift-test.sh          # Test runner script
```

## IDE Development Workflow

### VS Code
1. Install Swift extension
2. Open the project folder
3. Use integrated terminal for commands:
   ```bash
   swift test              # Run tests
   swift build             # Build
   swift run               # Run app
   ```

### Other IDEs (Neovim, Sublime, etc.)
- Use `sourcekit-lsp` for code completion
- Run commands from terminal
- No Xcode required!

## When You Still Need Xcode

You'll only need to open Xcode for:
1. **Editing XIB files** (MainMenu.xib)
2. **Managing code signing** for distribution
3. **Submitting to App Store**
4. **Debugging with UI tools**

To open in Xcode when needed:
```bash
open Package.swift  # Opens in Xcode with SPM project
```

## Benefits of This Setup

✅ **Command-line testing** - No UI interaction needed
✅ **IDE-friendly** - Work in your preferred editor
✅ **Fast iteration** - Quick build/test cycles
✅ **CI/CD ready** - Simple `swift test` for automation
✅ **Xcode available** - Still there when you need it

## Troubleshooting

### Tests not finding module
```bash
swift package clean
swift build
swift test
```

### Resources not loading
- Resources are copied to the bundle
- Access them using `Bundle.module`

### Want to go back to Xcode project?
- The `.xcodeproj` is still there
- Just open it when needed
- Both systems can coexist

## Common Commands Reference

```bash
# Development
swift build                    # Build debug
swift run                      # Run the app
swift test                     # Run all tests
swift test --parallel          # Run tests in parallel
swift package clean            # Clean build artifacts

# Release
swift build -c release         # Build optimized
swift run -c release           # Run optimized build

# Testing
./swift-test.sh               # Run all tests
./swift-test.sh unit          # Unit tests only
./swift-test.sh --verbose     # Detailed output
```

Happy coding without the Xcode UI! 🎉