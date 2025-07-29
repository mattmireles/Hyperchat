# The Complete macOS App Distribution Guide Outside the App Store

## Table of Contents
1. [Overview: Understanding the Distribution Process](#overview)
2. [Prerequisites & Setup](#prerequisites)
3. [Certificate Management](#certificates)
4. [Code Signing Deep Dive](#signing)
5. [Notarization Process](#notarization)
6. [Distribution Methods & App Translocation](#distribution)
7. [Sparkle Auto-Update Integration](#sparkle)
8. [Troubleshooting Guide](#troubleshooting)
   - [Diagnostic Script](#diagnostic-script)
   - [Common Issues and Solutions](#common-issues-and-solutions)
   - [The errSecInternalComponent Error](#the-errsecInternalComponent-error)
   - [JAR Files and Unsigned Binaries](#jar-files-and-unsigned-binaries)
   - [Framework-Specific Issues](#framework-specific-issues)
   - [Virtual Machine Testing Protocol](#virtual-machine-testing-protocol)
   - [Advanced Notarization Log Analysis](#advanced-notarization-log-analysis)
   - [Detailed Gatekeeper Assessment](#detailed-gatekeeper-assessment)
   - [App Translocation Deep Dive](#app-translocation-deep-dive)
   - [CI/CD Specific Issues](#cicd-specific-issues)
   - [Entitlement Conflicts and Edge Cases](#entitlement-conflicts-and-edge-cases)
   - [Debugging Notarization Hangs](#debugging-notarization-hangs)
   - [Complete Diagnostic Checklist](#complete-diagnostic-checklist)
   - [The "Death by a Thousand Cuts" Issues](#the-death-by-a-thousand-cuts-issues)
   - [Security-Scoped Bookmarks](#security-scoped-bookmarks-sandboxed-apps)
   - [Testing Strategies That Prevent Disasters](#testing-strategies-that-prevent-disasters)
9. [Recent macOS Changes](#recent-changes)
10. [Quick Reference](#quick-reference)
11. [Hyperchat-Specific Deployment](#hyperchat)
12. [Conclusion](#conclusion)

## Overview: Understanding the Distribution Process {#overview}

Distributing a macOS app outside the App Store requires navigating Apple's security framework. This guide covers the complete journey from code signing to user installation, with special attention to common pitfalls like App Translocation and Sparkle integration issues.

### The Chain of Trust

macOS security relies on three interconnected components:

1. **Code Signing** - Your cryptographic signature proving identity and integrity
2. **Notarization** - Apple's automated malware scan and approval
3. **Gatekeeper** - The system that verifies these credentials at runtime

Since macOS 15 Sequoia, the security requirements have become stricter - users can no longer bypass Gatekeeper warnings with a simple right-click. Proper signing and notarization are now mandatory for mainstream distribution.

### Critical Decision: Distribution Format

**⚠️ If your app includes auto-update functionality (like Sparkle), you MUST distribute as a DMG, never as a ZIP.** This prevents App Translocation, which breaks auto-updates by running your app from a read-only, randomized location.

## Prerequisites & Setup {#prerequisites}

### Apple Developer Account

You need a paid Apple Developer Program membership ($99/year). Free accounts cannot generate Developer ID certificates required for distribution.

| Account Type | Use Case | Team Members | App Store Name |
|-------------|----------|--------------|----------------|
| Individual | Solo developers | Single user | Your personal name |
| Organization | Companies | Multiple users | Company legal name |

### Required Tools

- **Xcode** (latest version recommended)
- **Command Line Tools**: `xcode-select --install`
- **Keychain Access** for certificate management
- **Terminal** for signing and notarization commands

### First-Time Setup

1. **Store Notarization Credentials** (one-time setup):
```bash
# Create app-specific password at appleid.apple.com first
xcrun notarytool store-credentials "notary-profile" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

2. **Verify Your Setup**:
```bash
# Check certificates
security find-identity -v -p codesigning | grep "Developer ID"

# Test notarization credentials
xcrun notarytool history --keychain-profile "notary-profile"
```

## Certificate Management {#certificates}

### Understanding Certificate Types

You need two types of Developer ID certificates:

- **Developer ID Application**: Signs apps, frameworks, and DMGs
- **Developer ID Installer**: Signs .pkg installers only

### Creating Certificates

#### Method 1: Through Apple Developer Portal

1. **Generate Certificate Signing Request (CSR)**:
   - Open Keychain Access
   - Menu: Certificate Assistant → Request a Certificate from a Certificate Authority
   - Email: Your Apple ID
   - Common Name: Your name/company
   - Select: "Saved to disk"

2. **Create Certificate**:
   - Log into developer.apple.com
   - Navigate to Certificates, Identifiers & Profiles
   - Click "+" → Select "Developer ID Application"
   - Upload CSR file
   - Download and double-click the .cer file

#### Method 2: Through Xcode (Simpler)

1. Xcode → Settings → Accounts
2. Select your Apple ID → "Manage Certificates..."
3. Click "+" → "Developer ID Application"

### Switching Developer Accounts

When moving from company to personal account:

1. **Purge Old Credentials**:
```bash
# Remove from Xcode
# Xcode → Settings → Accounts → Select old account → Click "-"

# Clean Keychain (CRITICAL!)
# Open Keychain Access → My Certificates
# Delete all old company certificates and private keys

# Clean project
# Search Build Settings for old TEAM_ID and clear all instances
```

2. **Establish New Identity**:
   - Add new account in Xcode
   - Select new team in Signing & Capabilities
   - Clean build folder: Product → Clean Build Folder

## Code Signing Deep Dive {#signing}

### The Golden Rules

1. **Never use `--deep` flag** - It's deprecated and causes problems
2. **Sign from inside out** - Frameworks first, then app bundle
3. **Always include `--timestamp`** - Required for notarization
4. **Enable hardened runtime** - Use `--options runtime`

### Complete Signing Workflow

```bash
# 1. Sign all frameworks FIRST
find YourApp.app -name "*.framework" -o -name "*.dylib" | while read -r item; do
    codesign --force --timestamp --options runtime \
             --sign "Developer ID Application: Your Name (TEAMID)" \
             "$item"
done

# 2. Sign helper apps and XPC services
find YourApp.app -name "*.app" -not -path "*/YourApp.app" | while read -r helper; do
    codesign --force --timestamp --options runtime \
             --sign "Developer ID Application: Your Name (TEAMID)" \
             "$helper"
done

# 3. Sign main app bundle with entitlements
codesign --force --timestamp --options runtime \
         --entitlements "YourApp.entitlements" \
         --sign "Developer ID Application: Your Name (TEAMID)" \
         YourApp.app

# 4. Verify signature
codesign --verify --deep --strict --verbose=2 YourApp.app
```

### Essential Entitlements

Create `YourApp.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network access (required for Sparkle) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- For web views on Apple Silicon -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    
    <!-- Only if loading third-party plugins -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- Hardware access if needed -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
</dict>
</plist>
```

### Sandboxed Apps

If using App Sandbox, add these Sparkle-specific entitlements:

```xml
<!-- XPC services for Sparkle -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

## Notarization Process {#notarization}

### The Modern Workflow

Since November 2023, `altool` is deprecated. Use `notarytool` exclusively.

### Step-by-Step Notarization

1. **Create Archive for Submission**:
```bash
# CRITICAL: Use ditto, not zip!
ditto -c -k --sequesterRsrc --keepParent YourApp.app YourApp.zip
```

2. **Submit for Notarization**:
```bash
xcrun notarytool submit YourApp.zip \
  --keychain-profile "notary-profile" \
  --wait
```

3. **Handle Results**:
```bash
# If successful, staple the ticket
xcrun stapler staple YourApp.app

# If failed, get the log
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "notary-profile" \
  developer_log.json
```

### Common Notarization Failures

| Error | Cause | Solution |
|-------|-------|----------|
| "The signature of the binary is invalid" | Modified after signing or unsigned component | Re-sign from inside out |
| "The executable does not have the hardened runtime enabled" | Missing `--options runtime` | Add flag and re-sign |
| "The signature does not include a secure timestamp" | Missing `--timestamp` | Add flag and re-sign |
| "The binary uses an SDK older than the 10.9 SDK" | Old deployment target | Set to 10.9+ in Build Settings |

## Distribution Methods & App Translocation {#distribution}

### Critical: Understanding App Translocation

**App Translocation is the #1 cause of auto-update failures.** When macOS detects a potentially unsafe app location, it runs your app from a randomized, read-only path:

```
/private/var/folders/.../AppTranslocation/.../d/YourApp.app
```

This breaks:
- Auto-updates (can't write to read-only location)
- File path assumptions
- Settings storage

### When App Translocation Occurs

ALL conditions must be met:
- App has quarantine attribute (from download)
- App launched from "unsafe" location (Downloads, Desktop)
- User hasn't moved app with Finder

### Distribution Method Comparison

| Method | Pros | Cons | Use When |
|--------|------|------|----------|
| **DMG** | Prevents translocation, professional | Larger size | **Always (if using auto-update)** |
| **ZIP** | Smaller, simple | Causes translocation | Never with auto-update |
| **PKG** | Complex installs, admin rights | Requires Installer cert | System extensions |

### Creating a Professional DMG

```bash
# Install create-dmg
brew install create-dmg

# Create DMG with custom background
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

# Sign the DMG
codesign --force --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  "YourApp-1.0.dmg"

# Notarize the DMG
xcrun notarytool submit "YourApp-1.0.dmg" \
  --keychain-profile "notary-profile" --wait

# Staple the ticket
xcrun stapler staple "YourApp-1.0.dmg"
```

## Sparkle Auto-Update Integration {#sparkle}

### Initial Setup

1. **Add Sparkle via Swift Package Manager**:
   - URL: `https://github.com/sparkle-project/Sparkle`
   - Version: Latest 2.x

2. **Configure Info.plist**:
```xml
<key>SUFeedURL</key>
<string>https://yourserver.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>your-public-key-here</string>
<key>SUEnableInstallerLauncherService</key>
<true/>
```

3. **Generate EdDSA Keys**:
```bash
./bin/generate_keys
# Private key: Stored in Keychain (NEVER share!)
# Public key: Add to Info.plist
```

### Critical Sparkle Configuration

For sandboxed apps, add to entitlements:
```xml
<!-- Required for Sparkle XPC services -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

### Appcast Generation

```bash
# Generate appcast automatically
./bin/generate_appcast /path/to/updates_folder/

# Structure:
# updates/
#   ├── YourApp-1.0.dmg
#   ├── YourApp-1.1.dmg
#   └── appcast.xml (generated)
```

### Version Numbering Strategy

- **CFBundleVersion**: Simple integers (1, 2, 3) for Sparkle comparison
- **CFBundleShortVersionString**: Semantic version (1.0.0) for users

## Troubleshooting Guide {#troubleshooting}

### Diagnostic Script

Create `diagnose-app.sh`:

```bash
#!/bin/bash
APP="$1"

echo "=== Certificate Check ==="
codesign -dvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|flags"

echo -e "\n=== Signature Verification ==="
codesign --verify --deep --strict --verbose=2 "$APP"

echo -e "\n=== Gatekeeper Assessment ==="
spctl --assess --verbose --type execute "$APP"

echo -e "\n=== Notarization Status ==="
spctl -a -vvv -t execute "$APP"

echo -e "\n=== Translocation Check ==="
xattr -l "$APP" | grep com.apple.quarantine

echo -e "\n=== Entitlements ==="
codesign -d --entitlements :- "$APP"
```

### Common Issues and Solutions

**"App is damaged and can't be opened"**
- Incorrect ZIP creation: Use `ditto -c -k --sequesterRsrc --keepParent`
- Missing notarization: Submit to notarytool and wait for approval
- Quarantine issues: Remove with `xattr -cr YourApp.app`
- App translocation: Move app properly to /Applications/

**Sparkle Update Failures**
- "Cannot update - app may be running from disk image": App Translocation active
- "Update permission error": Verify XPC service entitlements
- "EdDSA signature does not match": Wrong public key in Info.plist

### Console.app Debugging

Filter by your app name or "Sparkle" to find:
- `"Sandboxed app cannot update"` → Missing XPC entitlements
- `"Death sentinel fired"` → Update process timeout
- `"Couldn't find bundle at URL"` → App Translocation active

### The errSecInternalComponent Error

This frustrating error typically occurs in CI/CD environments:

```bash
# Fix 1: Unlock keychain
security unlock-keychain -p "password" ~/Library/Keychains/login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "password" ~/Library/Keychains/login.keychain-db

# Fix 2: For CI/CD, create temporary keychain
KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
security create-keychain -p "temp123" $KEYCHAIN_PATH
security import certificate.p12 -k $KEYCHAIN_PATH -P "p12password" -T /usr/bin/codesign
security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
security default-keychain -s $KEYCHAIN_PATH

# Fix 3: Nuclear option - In Keychain Access
# Manually set private key to "Allow all applications to access"
```

### JAR Files and Unsigned Binaries

Notarization now rejects unsigned native code inside JAR files:

```bash
# Find problematic JARs
find YourApp.app -name "*.jar" -exec sh -c 'jar -tf "$1" | grep -E "\.(dylib|so|jnilib)$" && echo "Found in: $1"' _ {} \;

# Extract, sign, and repackage JARs
jar -xf problematic.jar
find . -name "*.dylib" -o -name "*.jnilib" | while read lib; do
    codesign --force --timestamp --options runtime --sign "Developer ID" "$lib"
done
jar -cfm problematic.jar META-INF/MANIFEST.MF .
```

### Framework-Specific Issues

**Qt Framework:**
```bash
# Remove problematic files
find YourApp.app -name "*.prl" -delete
find YourApp.app -name "*.la" -delete

# Fix symlinks
cd YourApp.app/Contents/Frameworks/QtCore.framework
ln -sf Versions/Current/QtCore QtCore
```

**Electron Apps:**
```bash
# Sign Electron Framework first
codesign --force --timestamp --options runtime \
  --sign "Developer ID" \
  "YourApp.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Electron Framework"

# Then Libraries
codesign --force --timestamp --options runtime \
  --sign "Developer ID" \
  "YourApp.app/Contents/Frameworks/Electron Framework.framework/Libraries/libffmpeg.dylib"
```

### Virtual Machine Testing Protocol

**The Clean Room Testing Imperative**

Your development machine is contaminated with:
- Developer certificates that bypass security checks
- Cached Gatekeeper decisions
- Disabled security settings
- Previously approved apps

**Complete VM Testing Workflow:**

```bash
# 1. Setup clean VM (UTM/Parallels/VMware)
# 2. Take snapshot immediately after OS install
# 3. For each test:

# Restore to clean snapshot
# Download DMG via Safari (applies quarantine)
# Verify quarantine is present
xattr -l ~/Downloads/YourApp.dmg | grep quarantine

# Test offline (disconnect network)
# Mount DMG and install
# Should open without warnings if properly stapled

# Test online
# Verify auto-update works
# Check Console.app for errors
```

### Advanced Notarization Log Analysis

**Interpreting `developer_log.json`:**

```json
{
  "issues": [
    {
      "severity": "error",
      "code": null,
      "message": "The binary uses an SDK older than the 10.9 SDK.",
      "path": "YourApp.app/Contents/Frameworks/SomeFramework.framework/Versions/A/SomeFramework",
      "architecture": "x86_64"
    }
  ]
}
```

**Complete Error Reference:**

| Error Message | Root Cause | Detailed Fix |
|--------------|------------|--------------|
| "The signature of the binary is invalid" | Modified after signing OR unsigned nested component OR wrong certificate type | 1. Find specific file: `codesign -vvv --deep YourApp.app 2>&1 | grep "invalid"` <br> 2. Re-sign that specific component <br> 3. Re-sign parent bundle |
| "The binary is not signed with a valid Developer ID certificate" | Wrong cert type or expired cert | Check cert: `codesign -dvv YourApp.app | grep "Authority"` <br> Must show "Developer ID Application" |
| "The signature does not include a secure timestamp" | Missing `--timestamp` flag | Re-sign ALL components with `--timestamp` |
| "The executable requests the com.apple.security.get-task-allow entitlement" | Debug entitlement in release build | Remove from entitlements file or use separate Release.entitlements |
| "The binary uses SDK in a disallowed manner" | Using private APIs | Use `nm -u` to find undefined symbols, check against private API list |
| "The executable has entitlement com.apple.security.cs.debugger" | Another debug entitlement | Remove all debug entitlements for distribution |

### Detailed Gatekeeper Assessment

```bash
# Complete assessment with context
spctl --assess --type execute --verbose=4 YourApp.app 2>&1

# Check specific components
find YourApp.app -type f -perm +111 | while read f; do
    echo "Checking: $f"
    spctl --assess --type execute "$f" 2>&1
done

# Verify online notarization check
# This simulates what happens on user's machine
log stream --predicate 'subsystem == "com.apple.Security"' | grep -i "YourApp"
# In another terminal, launch your app
```

### App Translocation Deep Dive

**Detecting Translocation:**
```bash
# In your app, check at runtime
if [[ "$0" == *"/AppTranslocation/"* ]]; then
    echo "App is translocated!"
fi

# From outside
ps aux | grep YourApp | grep AppTranslocation
```

**All Translocation Triggers:**
1. Downloaded via browser (quarantine attribute)
2. Extracted from ZIP in place
3. Copied via command line without proper attributes
4. AirDropped and not moved
5. Downloaded via curl/wget without removing quarantine

**Preventing Translocation:**
```bash
# Option 1: Remove quarantine (NOT recommended for distribution)
xattr -dr com.apple.quarantine YourApp.app

# Option 2: Move with Finder (recommended)
# Must be actual Finder drag, not Terminal mv

# Option 3: Distribute as DMG with visual instructions
```

### CI/CD Specific Issues

**GitHub Actions:**
```yaml
- name: Import Certificate
  env:
    CERTIFICATE_BASE64: ${{ secrets.CERTIFICATE_BASE64 }}
    CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
  run: |
    # Create temporary keychain
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    KEYCHAIN_PASSWORD=mysecretpassword
    
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    
    # Import certificate
    echo "$CERTIFICATE_BASE64" | base64 --decode > certificate.p12
    security import certificate.p12 -k "$KEYCHAIN_PATH" \
      -P "$CERTIFICATE_PASSWORD" \
      -T /usr/bin/codesign \
      -T /usr/bin/security
    
    security list-keychains -d user -s "$KEYCHAIN_PATH"
    security default-keychain -s "$KEYCHAIN_PATH"
    
    # Grant access
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
      -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
```

**Jenkins/Other CI:**
```bash
# Common issue: No GUI session
# Solution: Use ssh with -Y flag or run via launchd user agent
```

### Entitlement Conflicts and Edge Cases

**Conflicting Entitlements:**
```xml
<!-- NEVER combine these -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.inherit</key>
<true/>

<!-- These require careful consideration -->
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
<!-- Breaks with: -->
<key>com.apple.security.cs.runtime-exceptions</key>
```

**Entitlement Inheritance Issues:**
```bash
# Helper app entitlements must be subset of main app
# Check with:
codesign -d --entitlements :- YourApp.app
codesign -d --entitlements :- YourApp.app/Contents/Helpers/Helper.app
```

### Debugging Notarization Hangs

```bash
# Check Apple System Status
curl -s https://www.apple.com/support/systemstatus/data/system_status_en_US.js

# Cancel stuck submission
xcrun notarytool submission list --keychain-profile "profile"
xcrun notarytool submission cancel SUBMISSION_ID --keychain-profile "profile"

# Retry with verbose logging
xcrun notarytool submit YourApp.zip \
  --keychain-profile "profile" \
  --verbose \
  --wait 2>&1 | tee notarization.log
```

### Complete Diagnostic Checklist

When nothing else works, run this comprehensive diagnostic:

```bash
#!/bin/bash
# ultimate-diagnostic.sh

APP="$1"
echo "=== macOS Signing Diagnostic Tool ==="
echo "App: $APP"
echo "Date: $(date)"
echo "macOS: $(sw_vers -productVersion)"

echo -e "\n=== 1. Certificate Validation ==="
security find-identity -v -p codesigning

echo -e "\n=== 2. Basic Signature Info ==="
codesign -dvv "$APP" 2>&1

echo -e "\n=== 3. Signature Verification ==="
codesign --verify --deep --strict --verbose=4 "$APP" 2>&1

echo -e "\n=== 4. Entitlements ==="
codesign -d --entitlements :- "$APP" 2>&1

echo -e "\n=== 5. Gatekeeper Assessment ==="
spctl --assess --verbose=4 --type execute "$APP" 2>&1

echo -e "\n=== 6. Notarization Check ==="
spctl -a -vvv -t execute "$APP" 2>&1

echo -e "\n=== 7. Quarantine Status ==="
xattr -l "$APP"

echo -e "\n=== 8. Framework Issues ==="
find "$APP" -name "*.framework" | while read fw; do
    echo "Framework: $fw"
    codesign -dvv "$fw" 2>&1 | grep -E "Authority|Timestamp|flags"
done

echo -e "\n=== 9. Unsigned Binaries ==="
find "$APP" -type f -perm +111 | while read bin; do
    codesign -vv "$bin" 2>&1 | grep -q "not signed" && echo "Unsigned: $bin"
done

echo -e "\n=== 10. Info.plist Validation ==="
plutil -lint "$APP/Contents/Info.plist"

echo -e "\n=== 11. Bundle Structure ==="
find "$APP" -name "*.app" -o -name "*.framework" -o -name "*.bundle" | head -20

echo -e "\n=== 12. Recent System Logs ==="
log show --predicate 'subsystem == "com.apple.Security" OR subsystem == "com.apple.gatekeeper"' --last 5m | grep -i "$(basename "$APP")"
```

### The "Death by a Thousand Cuts" Issues

Small issues that compound:

1. **Windows line endings in Info.plist**: Use `dos2unix`
2. **Hidden .DS_Store files**: Remove with `find YourApp.app -name .DS_Store -delete`
3. **Extended attributes**: Check with `xattr -l YourApp.app`
4. **Symlink issues**: Verify with `find YourApp.app -type l -ls`
5. **Resource fork data**: Strip with `xattr -cr YourApp.app`
6. **Wrong file permissions**: Fix with `chmod -R 755 YourApp.app`
7. **Corrupted nibs**: Recompile from xibs

### Security-Scoped Bookmarks (Sandboxed Apps)

For persistent file access in sandboxed apps:

```xml
<!-- Required entitlement -->
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

```swift
// Create bookmark
let bookmarkData = try url.bookmarkData(options: .withSecurityScope)
UserDefaults.standard.set(bookmarkData, forKey: "savedPath")

// Restore access - CRITICAL: Must bracket with start/stop
var isStale = false
let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
guard url.startAccessingSecurityScopedResource() else { return }
defer { url.stopAccessingSecurityScopedResource() }
// Use url here...
```

### Testing Strategies That Prevent Disasters

**The Three Essential Tests:**

1. **Clean Install Test**
   ```bash
   # On fresh system/VM
   # 1. Download DMG via Safari
   # 2. Check quarantine: xattr -l YourApp.dmg
   # 3. Install and launch
   # 4. Should open without warnings
   ```

2. **Update Test**
   ```bash
   # 1. Install old version
   # 2. Trigger update check
   # 3. Monitor Console.app during update
   # 4. Verify new version launches
   ```

3. **Offline Test**
   ```bash
   # 1. Disconnect network
   # 2. Install from DMG
   # 3. App should launch (stapled ticket)
   # 4. Reconnect and verify updates work
   ```

**Automated Testing Script:**

```bash
#!/bin/bash
# test-distribution.sh

APP="YourApp.app"
DMG="YourApp.dmg"

echo "1. Verifying signatures..."
codesign --verify --strict "$APP" || exit 1

echo "2. Checking notarization..."
spctl --assess --type execute "$APP" || exit 1

echo "3. Simulating download..."
xattr -w com.apple.quarantine "0081;$(printf '%016x' $(date +%s));Safari;" "$APP"
spctl --assess --type execute "$APP" || exit 1

echo "4. Testing DMG..."
hdiutil attach "$DMG" -nobrowse
cp -R "/Volumes/YourApp/$APP" "/tmp/"
hdiutil detach "/Volumes/YourApp"
spctl --assess --type execute "/tmp/$APP" || exit 1

echo "✅ All distribution tests passed!"
```

### Testing Update Scenarios

For Sparkle updates:

```bash
# Force immediate update check
defaults delete com.company.app SULastCheckTime

# Test delta updates
# Keep multiple versions for delta generation
./bin/generate_appcast updates_folder/

# Monitor update process
log stream --predicate 'subsystem == "org.sparkle-project.Sparkle"'
```

## Recent macOS Changes {#recent-changes}

### macOS 15 Sequoia (2024)

**Major Change**: Gatekeeper bypass removed completely
- Users can no longer right-click → Open to bypass warnings
- Must go to System Settings → Privacy & Security → "Open Anyway"
- Makes notarization effectively mandatory

### macOS 14 Sonoma

- Stricter entitlement parsing (validate with `plutil -lint`)
- Enhanced runtime security checks
- Faster notarization service

### Privacy Manifest Requirements (Spring 2024)

New requirement for apps using certain APIs:

```xml
<!-- PrivacyInfo.xcprivacy -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

## Quick Reference {#quick-reference}

### Complete Distribution Workflow

```bash
#!/bin/bash
# deploy.sh - Complete distribution script

APP_NAME="YourApp"
IDENTITY="Developer ID Application: Your Name (TEAMID)"
PROFILE="notary-profile"

# 1. Clean and build
echo "🧹 Cleaning..."
rm -rf build/ *.dmg *.zip

echo "🔨 Building..."
xcodebuild -scheme "$APP_NAME" -configuration Release build

# 2. Sign everything
echo "🔏 Signing..."
APP_PATH="build/Release/$APP_NAME.app"

# Sign frameworks first
find "$APP_PATH" -name "*.framework" -o -name "*.dylib" | while read -r item; do
    codesign --force --timestamp --options runtime --sign "$IDENTITY" "$item"
done

# Sign helpers
find "$APP_PATH" -name "*.app" -not -path "*/$APP_NAME.app" | while read -r helper; do
    codesign --force --timestamp --options runtime --sign "$IDENTITY" "$helper"
done

# Sign main app
codesign --force --timestamp --options runtime \
  --entitlements "$APP_NAME.entitlements" \
  --sign "$IDENTITY" "$APP_PATH"

# 3. Create and sign DMG
echo "💿 Creating DMG..."
create-dmg \
  --volname "$APP_NAME" \
  --background "assets/dmg-background.png" \
  --window-size 600 400 \
  --icon "$APP_NAME.app" 150 200 \
  --app-drop-link 450 200 \
  "$APP_NAME.dmg" \
  "$APP_PATH"

codesign --force --timestamp --sign "$IDENTITY" "$APP_NAME.dmg"

# 4. Notarize
echo "🍎 Notarizing..."
xcrun notarytool submit "$APP_NAME.dmg" \
  --keychain-profile "$PROFILE" \
  --wait

# 5. Staple
echo "📎 Stapling..."
xcrun stapler staple "$APP_NAME.dmg"

# 6. Verify
echo "✅ Verifying..."
spctl --assess --verbose --type open \
  --context context:primary-signature "$APP_NAME.dmg"

echo "🚀 Done! $APP_NAME.dmg is ready for distribution"
```

### Essential Commands Cheat Sheet

```bash
# Find signing identity
security find-identity -v -p codesigning

# Quick sign
codesign -fs "Developer ID Application: Name (TEAM)" --options runtime --timestamp App.app

# Create ZIP properly
ditto -c -k --sequesterRsrc --keepParent App.app App.zip

# Submit to notary
xcrun notarytool submit App.zip --keychain-profile "profile" --wait

# Get notary log
xcrun notarytool log UUID --keychain-profile "profile"

# Staple ticket
xcrun stapler staple App.app

# Test like Gatekeeper
spctl --assess --verbose --type execute App.app

# Remove quarantine
xattr -cr App.app

# Check for translocation
xattr -l App.app | grep quarantine
```

### Golden Rules Summary

1. **Always distribute auto-updating apps as DMG** (never ZIP)
2. **Sign from inside out** (frameworks → helpers → main app)
3. **Never use `--deep`** for signing
4. **Test on clean systems** without dev tools
5. **Include only required entitlements**
6. **Use simple integers for CFBundleVersion**
7. **Store credentials securely** in Keychain
8. **Monitor Console.app** for hidden errors

## Hyperchat-Specific Deployment {#hyperchat}

### Prerequisites for Hyperchat

Before running the deployment script, ensure:

- **Team ID**: `YOUR_TEAM_ID` (configured via APPLE_TEAM_ID environment variable)
- **Apple ID**: `your-apple-id@example.com` (configured via APPLE_ID_EMAIL environment variable)
- **Certificate Hash**: `YOUR_CERTIFICATE_HASH` (configured via APPLE_CERTIFICATE_IDENTITY environment variable)

### One-Time Credential Setup

```bash
# 1. Create app-specific password at appleid.apple.com
# 2. Store credentials
xcrun notarytool store-credentials "hyperchat-notarize" \
  --apple-id "$APPLE_ID_EMAIL" \
  --team-id "$APPLE_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### Hyperchat Deployment Script

The complete deployment workflow is automated in `deploy-hyperchat.sh`:

```bash
cd /Users/mattmireles/Documents/GitHub/hyperchat/hyperchat-macos
./deploy-hyperchat.sh
```

This script handles:
1. ✅ Prerequisites check (credentials and certificate)
2. 📝 Build number increment
3. 🧹 Clean previous builds
4. 🔨 Archive the app
5. 🔏 Sign all components
6. 💿 Create DMG
7. 🍎 Submit for notarization
8. 📎 Staple the ticket
9. 🚀 Deploy to website
10. 📋 Update appcast.xml for Sparkle

### Emergency Recovery

If deployment fails:
```bash
# Clean all artifacts
sudo rm -rf build Export DerivedData Hyperchat.xcarchive *.dmg

# Reset build number if needed
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 50" Info.plist

# Run again
./deploy-hyperchat.sh
```

### Manual Override

For manual notarization:
```bash
# Submit
xcrun notarytool submit "Hyperchat-v1.0.dmg" \
  --keychain-profile "hyperchat-notarize" \
  --wait

# Staple
xcrun stapler staple "Hyperchat-v1.0.dmg"

# Verify
spctl -a -vvv -t open --context context:primary-signature "Hyperchat-v1.0.dmg"
```

## Conclusion

Successfully distributing macOS apps outside the App Store requires attention to detail and understanding of the security model. The most critical aspects are:

- Proper signing order (inside out)
- Choosing the right distribution format (DMG for auto-updating apps)
- Complete notarization workflow
- Thorough testing on clean systems

With macOS security requirements becoming stricter each release, following these practices ensures your users have a smooth installation experience while maintaining the security macOS users expect.

Remember: Most distribution failures come from rushing through the process. Take time to set up your workflow correctly, automate where possible, and test thoroughly. Your users will thank you for it.