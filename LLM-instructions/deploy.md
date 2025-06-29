# Guide: macOS App Distribution Outside the App Store (with Sparkle)

Sonoma and macOS 15 Sequoia, this comprehensive resource covers the complete workflow from code signing to troubleshooting common failures. The guide emphasizes practical solutions to the most challenging aspects of non-App Store distribution, including hardened runtime requirements, Sparkle framework integration, and automated deployment strategies.

## Understanding the modern macOS security landscape

Apple's security requirements have evolved significantly, particularly with macOS 15 Sequoia's elimination of the Control-click Gatekeeper bypass. Users can no longer easily override warnings for unsigned or unnotarized software - they must navigate to System Settings > Privacy & Security to manually approve such applications. This change fundamentally shifts the distribution landscape, making notarization effectively mandatory for any app expecting smooth user adoption.

The transition from altool to notarytool represents another critical change. As of November 1, 2023, Apple no longer accepts notarization uploads via the deprecated altool. All developers must now use xcrun notarytool or Xcode 14+ for notarization workflows. This newer tool offers improved performance, better error reporting, and supports modern authentication methods including App Store Connect API keys.

For certificate management, Apple now requires Developer ID certificates for non-App Store distribution. These certificates come in two flavors: **Developer ID Application** for signing apps and **Developer ID Installer** for signing pkg installers. Both are essential components of a complete distribution strategy, and understanding their proper usage prevents many common signing failures.

## Critical failure mode: App Translocation

**App Translocation is the #1 cause of Sparkle update failures and must be addressed from day one.** When a user downloads your app and runs it directly from the Downloads folder, macOS may transparently execute it from a randomized, read-only location. This security feature, also known as Gatekeeper Path Randomization, completely breaks auto-update mechanisms.

### Why App Translocation happens

macOS applies translocation when ALL of these conditions are met:
- The app has a quarantine extended attribute (automatically added by browsers)
- The app is launched from a "transient" location (Downloads, Desktop, etc.)
- The user hasn't explicitly moved the app using Finder

### The read-only death trap

When translocated, your app runs from a path like:
```
/private/var/folders/.../AppTranslocation/.../d/YourApp.app
```

This location is:
- **Read-only**: Sparkle cannot write updates here
- **Randomized**: Changes on every launch
- **Transparent**: Your app thinks it's running from the original location

### Prevention strategy: DMG-only distribution

**Never distribute your app as a ZIP file.** This is non-negotiable for apps with auto-update. Instead:

1. **Create a well-designed DMG** with:
   - Custom background showing drag-to-Applications instruction
   - Symbolic link to /Applications folder
   - Your app icon prominently displayed

2. **The user action that saves you**: When users drag your app to /Applications using Finder, macOS removes the quarantine attribute. This deliberate installation gesture prevents translocation permanently.

3. **Testing for translocation**:
   ```bash
   # Check if app will be translocated
   xattr -l /path/to/YourApp.app | grep com.apple.quarantine
   
   # If output shows quarantine attribute, translocation will occur
   ```

## Implementing the complete signing and notarization workflow

The signing process begins with proper certificate setup. First, verify your signing identities are correctly installed by running `security find-identity -v -p codesigning`. This command should display your Developer ID certificates with their associated team identifiers. If certificates appear invalid or are missing private keys, you'll need to regenerate them through the Apple Developer portal or transfer them from another Mac using P12 export.

### The golden rule: Sign from inside out

**Never use the `--deep` flag on your main app bundle.** This is the most common and destructive code signing mistake. The `--deep` flag recursively signs nested code but applies the parent's entitlements to all children, breaking frameworks and helper tools.

Instead, follow this strict signing order:

```bash
# 1. Sign all frameworks individually
find MyApp.app -name "*.framework" -print0 | while IFS= read -r -d '' framework; do
    codesign --force --timestamp --options runtime \
             --sign "Developer ID Application: Your Name (TEAM_ID)" \
             "$framework"
done

# 2. Sign all dylibs and other executables
find MyApp.app -name "*.dylib" -o -name "*.so" -print0 | while IFS= read -r -d '' lib; do
    codesign --force --timestamp --options runtime \
             --sign "Developer ID Application: Your Name (TEAM_ID)" \
             "$lib"
done

# 3. Sign helper apps and XPC services (with their own entitlements if needed)
find MyApp.app -name "*.app" -not -path "*/MyApp.app" -print0 | while IFS= read -r -d '' helper; do
    codesign --force --timestamp --options runtime \
             --sign "Developer ID Application: Your Name (TEAM_ID)" \
             "$helper"
done

# 4. Finally, sign the main app bundle with its entitlements
codesign --force --timestamp --options runtime \
         --entitlements "MyApp.entitlements" \
         --sign "Developer ID Application: Your Name (TEAM_ID)" \
         MyApp.app

# 5. Verify with --deep (verification only!)
codesign --verify --deep --strict --verbose=2 MyApp.app
```

The key insight: Each component's signature includes hashes of its contents. If you sign a parent before its children, modifying the children later invalidates the parent's signature.

### Critical entitlements for macOS 14+

Create an entitlements file with only what your app genuinely needs:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network access for Sparkle updates -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Required for WKWebView on Apple Silicon -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    
    <!-- Only if loading unsigned third-party plugins -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- NEVER include this in release builds -->
    <!-- <key>com.apple.security.get-task-allow</key> -->
    <!-- <true/> -->
</dict>
</plist>
```

### Notarization workflow for macOS 14+

The notarization process has three distinct phases: submission, verification, and stapling. For submission, create a ZIP archive of your app using `ditto -c -k --keepParent MyApp.app MyApp.zip`, then submit with `xcrun notarytool submit MyApp.zip --keychain-profile "MyProfile" --wait`. The `--wait` flag blocks until notarization completes, typically taking 3-5 minutes. Upon successful notarization, staple the ticket to your app with `xcrun stapler staple MyApp.app` to enable offline verification.

## Mastering Sparkle 2.x integration

Sparkle 2.x represents a significant evolution from earlier versions, introducing EdDSA signatures, sandboxed app support, and enhanced security features. Integration begins with adding Sparkle via Swift Package Manager using the repository URL `https://github.com/sparkle-project/Sparkle`. This method ensures you receive automatic framework updates and simplifies the build process.

### Critical configuration for sandboxed apps

If your app uses App Sandbox (recommended for security), Sparkle requires specific entitlements to function:

1. **In your app's Info.plist**, add:
   ```xml
   <key>SUEnableInstallerLauncherService</key>
   <true/>
   ```

2. **In your entitlements file**, add the XPC service exceptions:
   ```xml
   <!-- Network access for update checks -->
   <key>com.apple.security.network.client</key>
   <true/>
   
   <!-- Required for Sparkle's XPC installer service -->
   <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
   <array>
       <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
       <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
   </array>
   ```

Without these entitlements, sandboxed apps will show "Sandbox denied authorizing right" errors in Console.app when attempting updates.

### EdDSA signatures: Your update security backbone

The framework requires specific configuration in your app's Info.plist. At minimum, you need `SUFeedURL` pointing to your appcast location and `SUPublicEDKey` containing your public EdDSA key. Generate these keys using Sparkle's included tool: `./bin/generate_keys`. This creates a private key in your macOS Keychain and outputs a public key for embedding in your app. **Never share or commit your private key** - it's the foundation of your update security.

For programmatic integration in Swift, initialize SPUStandardUpdaterController in your app delegate or main app structure. The controller handles all update UI and logic, requiring minimal code: `updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)`. Connect this to a menu item or button action to enable manual update checks.

## Navigating common failure modes and gotchas

### The errSecInternalComponent nightmare

This is the most frustrating code signing error, typically occurring in CI/CD environments or SSH sessions. It means codesign cannot access your certificate's private key.

**Solution arsenal (try in order)**:
```bash
# 1. Fix keychain access permissions
security unlock-keychain -p "password" ~/Library/Keychains/login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "password" ~/Library/Keychains/login.keychain-db

# 2. For CI/CD, create a temporary keychain
KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
security create-keychain -p "temp123" $KEYCHAIN_PATH
security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
security unlock-keychain -p "temp123" $KEYCHAIN_PATH
# Import your p12 certificate
security import certificate.p12 -k $KEYCHAIN_PATH -P "p12password" -T /usr/bin/codesign
security list-keychains -s $KEYCHAIN_PATH
security default-keychain -s $KEYCHAIN_PATH

# 3. Nuclear option: In Keychain Access, manually set private key to "Allow all applications to access"
```

### Notarization rejection decoder ring

| Error Message | Root Cause | Fix |
|--------------|------------|-----|
| "The signature of the binary is invalid" | Modified after signing OR unsigned nested component | Re-sign everything from inside out |
| "The executable does not have the hardened runtime enabled" | Missing `--options runtime` | Add flag to all codesign commands |
| "The signature does not include a secure timestamp" | Missing `--timestamp` flag | Always include `--timestamp` |
| "The binary uses an SDK older than the 10.9 SDK" | Deployment target too low | Set minimum to 10.9 in Xcode |
| "Team is not yet configured for notarization" | New developer account | Contact Apple Developer Support |
| "The executable has entitlement com.apple.security.get-task-allow" | Debug entitlement in release build | Remove from release entitlements |

### JAR files and unsigned binaries

Notarization now rejects unsigned native code inside JAR files:
```bash
# Extract, sign, and repackage JARs
jar -xf problematic.jar
find . -name "*.dylib" -o -name "*.jnilib" | while read lib; do
    codesign --force --timestamp --options runtime --sign "Developer ID" "$lib"
done
jar -cfm problematic.jar META-INF/MANIFEST.MF .
```

### Sparkle-specific issues

The framework's update mechanism requires certain entitlements that may conflict with strict security settings. If updates take excessive time or show "Death sentinel fired" errors, verify your entitlements include necessary exceptions like `com.apple.security.cs.allow-unsigned-executable-memory` for apps using JIT compilation. However, use such exceptions sparingly - each weakens your app's security posture.

## Leveraging hardened runtime and entitlements effectively

Hardened runtime enforcement became mandatory for notarization with macOS 10.14.5. This security feature prevents certain classes of exploits but can break legitimate functionality. Understanding which entitlements to enable - and which to avoid - proves crucial for balancing security with functionality.

### Critical entitlements reference

| Entitlement | When Required | Security Impact | Common Gotcha |
|------------|---------------|-----------------|---------------|
| `com.apple.security.cs.allow-jit` | WKWebView on Apple Silicon, JavaScript engines | Medium | Required for any web content on M1/M2 |
| `com.apple.security.cs.disable-library-validation` | Loading unsigned frameworks/plugins | High | Avoid if you sign all components |
| `com.apple.security.cs.allow-dyld-environment-variables` | Debugging tools, profilers | Very High | NEVER ship in release |
| `com.apple.security.cs.allow-unsigned-executable-memory` | Legacy JIT code | Very High | Use allow-jit instead |
| `com.apple.security.get-task-allow` | Debugger attachment | Blocker | Auto-removed by Archive, but check! |
| `com.apple.security.device.audio-input` | Microphone access | Low | User still prompted |
| `com.apple.security.device.camera` | Camera access | Low | User still prompted |
| `com.apple.security.automation.apple-events` | AppleScript/automation | Medium | Each target app prompts user |

### The entitlements file template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network access - required for Sparkle -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Only add what you actually need below -->
    
    <!-- For web views on Apple Silicon -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    
    <!-- For loading third-party signed frameworks -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

For Sparkle integration, network access is non-negotiable - the framework must download updates. Sandboxed apps require additional considerations, including XPC service entitlements. Add `com.apple.security.temporary-exception.mach-lookup.global-name` with your app's bundle identifier suffixed with `-spks` and `-spki` to enable Sparkle's XPC services. Non-sandboxed apps can omit these complications but sacrifice the additional security sandbox provides.

## Building robust deployment and update infrastructure

Successful deployment requires more than just signed binaries - you need reliable infrastructure for hosting and delivering updates. Start with HTTPS hosting, mandatory due to App Transport Security. Your server doesn't need complex logic; Sparkle works with static file hosting. However, consider using a CDN like CloudFront for global distribution and improved reliability.

### Creating the perfect DMG

The DMG is your first line of defense against App Translocation. Use `create-dmg` or similar tools to build a professional installer experience:

```bash
# Install create-dmg
brew install create-dmg

# Create a well-designed DMG
create-dmg \
  --volname "YourApp" \
  --volicon "YourApp.icns" \
  --background "installer-background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "YourApp.app" 175 190 \
  --hide-extension "YourApp.app" \
  --app-drop-link 425 190 \
  "YourApp-1.0.dmg" \
  "build/Release/YourApp.app"

# Sign the DMG separately
codesign --force --timestamp --sign "Developer ID Application: Your Name (TEAMID)" "YourApp-1.0.dmg"

# Then notarize it
xcrun notarytool submit "YourApp-1.0.dmg" --keychain-profile "MyNotaryProfile" --wait

# Finally staple
xcrun stapler staple "YourApp-1.0.dmg"
```

Key DMG requirements:
- **Visual instructions**: Background image showing drag-to-Applications
- **Applications symlink**: Makes installation target obvious
- **Signed and notarized**: The entire DMG container must be secure
- **Professional appearance**: This is users' first impression

### Appcast hosting strategy

Structure your update repository logically. Place your appcast.xml at a stable URL, then organize updates in versioned subdirectories. This approach enables rollback capabilities and simplifies debugging. Configure appropriate cache headers - short for appcast.xml to ensure users receive latest versions quickly, longer for binary files to reduce bandwidth costs.

Version numbering deserves special attention. Sparkle compares CFBundleVersion values numerically, so use simple incrementing integers (1, 2, 3) rather than dotted notation. Reserve semantic versioning for CFBundleShortVersionString, which users see. This dual approach provides clear version communication while ensuring reliable update detection.

## Automating the entire pipeline

Manual signing and deployment invites errors. Implement automation early using CI/CD platforms like GitHub Actions. Store signing credentials securely as secrets: base64-encoded certificates, certificate passwords, and notarization credentials including Apple ID and app-specific passwords.

Your automated pipeline should handle the complete workflow: building, signing embedded frameworks, signing the main bundle, creating archives, notarizing, stapling, and finally uploading to your distribution server. Implement retry logic for notarization - Apple's service occasionally experiences delays. Cache signing certificates between builds to improve performance, but always validate their expiration dates.

Here's a critical automation insight: generate your appcast.xml automatically using Sparkle's `generate_appcast` tool. This utility creates properly formatted XML, generates EdDSA signatures, and even produces delta updates when previous versions are available. Point it at a directory containing your releases and it handles the rest: `./bin/generate_appcast /path/to/updates_folder/`.

## Testing strategies that prevent deployment disasters

Comprehensive testing prevents user-facing failures. Begin with local verification using `codesign --verify --deep --strict --verbose=2 MyApp.app` and `spctl --assess --type execute --verbose MyApp.app`. These commands validate signing and Gatekeeper acceptance respectively. However, true testing requires clean systems without development certificates installed.

### The clean room testing imperative

**Your development machine is a terrible test environment.** It's contaminated with:
- Developer certificates that bypass security checks
- Cached Gatekeeper decisions
- Disabled security settings
- Previously approved apps

The only valid test simulates a real user's experience on a pristine system:

#### Virtual machine testing protocol

1. **Setup a clean VM**: Use UTM (free), Parallels, or VMware with fresh macOS install. Never install Xcode or developer tools.

2. **Take a snapshot**: Capture the pristine state immediately after OS installation.

3. **Test like a real user**:
   ```bash
   # Before each test
   1. Restore VM to clean snapshot
   2. Download your DMG using Safari (applies quarantine)
   3. Disconnect network (tests stapled ticket)
   4. Mount DMG and drag to /Applications
   5. Launch app - should open without warnings
   6. Reconnect network
   7. Test "Check for Updates" - should complete successfully
   ```

4. **What failure looks like**:
   - Gatekeeper warnings = signing/notarization failed
   - App won't launch = missing entitlements or wrong certificate
   - Updates fail silently = App Translocation or permissions issue

### Update testing scenarios

For update testing, manipulate CFBundleVersion values in development builds to simulate older versions. Clear Sparkle's last check time with `defaults delete my-bundle-id SULastCheckTime` to trigger immediate update checks. Test both automatic and manual update flows, paying attention to UI behavior and download progress.

Delta updates require special attention. Generate test scenarios with genuine version progressions - artificial version changes may not exercise the same code paths. Monitor Console.app during updates; Sparkle logs detailed information about failures and success states. This visibility proves invaluable when debugging user-reported issues.

## Troubleshooting when things go wrong

When signing fails, start with certificate validation. The error "The identity 'Developer ID Application' doesn't match any valid, non-expired certificate/private key pair" indicates missing or expired certificates. Verify both certificate and private key presence in Keychain Access. Green checkmarks indicate valid certificates; blue plus signs suggest problems requiring attention.

### The master troubleshooting checklist

| Problem | Diagnostic Command | Solution |
|---------|-------------------|----------|
| **App won't open (user reports)** | Ask user to check System Settings > Privacy & Security | If app appears there, notarization worked but something else failed |
| **"Damaged app" error** | `spctl -a -vvv YourApp.app` | Re-sign and re-notarize; check for modified files |
| **Sparkle updates fail silently** | Check Console.app for "Sparkle" | Usually App Translocation - must distribute as DMG |
| **Notarization takes forever** | Check Apple System Status | Sometimes Apple's servers are slow; just wait |
| **"errSecInternalComponent"** | `security find-identity -v` | See keychain fixes in gotchas section |
| **Updates download but won't install** | `ls -la@ YourApp.app` check permissions | App owned by root or has quarantine attribute |
| **Hardened runtime crashes** | Check crash logs for missing entitlements | Add only required entitlements, test thoroughly |

### Debugging Sparkle failures

For notarization failures, the log provides crucial details. Retrieve it with `xcrun notarytool log SUBMISSION_ID --keychain-profile "MyProfile"`. Common rejection reasons include unsigned binaries, missing timestamps, or incorrect entitlements. Each error includes specific file paths, enabling targeted fixes.

Update failures often manifest as network errors or signature verification problems. Users reporting "An error occurred while downloading the update" may face firewall restrictions. Provide alternative download links and clear documentation about required network access. For signature failures, verify your EdDSA keys haven't changed and that signatures properly match your distributed binaries.

### Console.app is your best friend

Always check Console.app when debugging. Filter by your app name or "Sparkle":
- **"Sandboxed app cannot update"** = Missing XPC entitlements
- **"EdDSA signature does not match"** = Wrong public key in Info.plist
- **"Cannot find enclosure URL"** = Malformed appcast.xml
- **"Update will not be installed because it cannot be verified"** = Developer ID changed or binary modified

## Recent changes in macOS 14 and 15

macOS 14 Sonoma introduced stricter entitlement parsing, rejecting previously accepted malformed XML. Validate all entitlements files with `plutil -lint entitlements.plist` before use. Remove comments and ensure proper UTF-8 encoding without BOM markers.

macOS 15 Sequoia's removal of Gatekeeper bypass fundamentally changes distribution dynamics. Users must now navigate to System Settings to approve unnotarized apps - a significant friction point. This change makes notarization mandatory for mainstream distribution. Plan accordingly and ensure your notarization pipeline remains reliable.

The future likely brings additional security requirements. Apple continues tightening controls around code execution and app distribution. Stay informed through Apple Developer forums and documentation. Consider joining beta programs to test your distribution pipeline against upcoming OS versions before public release.

## Key takeaways for successful deployment

Success in macOS app distribution outside the App Store requires mastering multiple interconnected systems. Here are the non-negotiable rules:

### The Golden Rules

1. **Always distribute as DMG, never ZIP** - App Translocation will destroy your auto-update mechanism
2. **Sign from inside out** - Never use `--deep` on the main bundle
3. **Test on clean VMs** - Your dev machine lies to you
4. **Include only required entitlements** - Each one weakens security
5. **Use Console.app religiously** - Sparkle logs everything there

### The Critical Path

```bash
# 1. Sign (inside out)
./scripts/sign_components.sh  # Sign frameworks/dylibs first
codesign --force --timestamp --options runtime --entitlements app.entitlements --sign "Developer ID" YourApp.app

# 2. Package as DMG
create-dmg --volname "YourApp" --window-size 600 400 --icon-size 100 --icon "YourApp.app" 200 150 --hide-extension "YourApp.app" --app-drop-link 400 150 "YourApp.dmg" "YourApp.app"

# 3. Sign the DMG
codesign --force --timestamp --sign "Developer ID Application" YourApp.dmg

# 4. Notarize
xcrun notarytool submit YourApp.dmg --keychain-profile "MyProfile" --wait

# 5. Staple
xcrun stapler staple YourApp.dmg

# 6. Verify
spctl -a -vvv -t install YourApp.dmg
```

### The Three Tests That Matter

1. **Clean install test**: Fresh VM, download DMG, install, launch
2. **Update test**: Install old version, trigger update, verify completion
3. **Offline test**: Disconnect network before first launch (tests stapling)

Most importantly, respect the security model Apple has built. While restrictions may seem onerous, they protect users from malware and ensure a trustworthy software ecosystem. Work within the system rather than trying to circumvent it. Your users will appreciate the smooth installation experience that proper signing and notarization provide, leading to higher adoption rates and fewer support requests.