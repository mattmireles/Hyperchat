# HyperChat Deployment Guide

## Prerequisites

Before running the deployment script, you need to set up Apple Developer credentials for code signing and notarization.

### 1. Apple Developer Account
- You need an active Apple Developer account ($99/year)
- Team ID: `$(APPLE_TEAM_ID)`
- Apple ID: `your-apple-id@example.com`

### 2. Code Signing Certificate
The deployment script expects a Developer ID Application certificate with hash:
- Certificate Hash: `***REMOVED-CERTIFICATE***`

To verify your certificate is installed:
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### 3. Notarization Credentials

You MUST store your notarization credentials before the first deployment:

#### Step 1: Create an App-Specific Password
1. Go to https://appleid.apple.com/account/manage
2. Sign in with your Apple ID (your-apple-id@example.com)
3. Navigate to "Sign-In and Security" → "App-Specific Passwords"
4. Click the "+" button to create a new password
5. Name it "Hyperchat Notarization"
6. Copy the generated password (you'll need it for the next step)

#### Step 2: Store Credentials in Keychain
Run this command with your app-specific password:
```bash
xcrun notarytool store-credentials "hyperchat-notarize" \
  --apple-id "your-apple-id@example.com" \
  --team-id "$(APPLE_TEAM_ID)" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Replace `xxxx-xxxx-xxxx-xxxx` with the app-specific password you created.

## Running the Deployment

Once credentials are stored, simply run:
```bash
cd /Users/***REMOVED-USERNAME***/Documents/GitHub/hyperchat/hyperchat-macos
./deploy-hyperchat.sh
```

The script will:
1. ✅ Check prerequisites (credentials and certificate)
2. 📝 Increment the build number
3. 🧹 Clean previous builds
4. 🔨 Archive the app
5. 🔏 Sign all components
6. 💿 Create a DMG
7. 🍎 Submit for notarization
8. 📎 Staple the notarization ticket
9. 🚀 Deploy to the website
10. 📋 Update the appcast.xml for Sparkle updates

## Troubleshooting

### "Notarization credentials not found"
- Make sure you've run the `xcrun notarytool store-credentials` command
- The profile name must be exactly "hyperchat-notarize"
- Try running: `xcrun notarytool history --keychain-profile "hyperchat-notarize"`

### "Code signing certificate not found"
- Ensure your Developer ID certificate is installed in Keychain Access
- The certificate hash must match: `***REMOVED-CERTIFICATE***`
- Run `security find-identity -v -p codesigning` to see available certificates

### Notarization fails with specific errors
- Check `notarization-log.txt` for details (created when notarization fails)
- Common issues:
  - Missing entitlements
  - Unsigned binaries
  - Invalid bundle structure

### Emergency Recovery
If the script fails midway:
```bash
# Clean up all build artifacts
sudo rm -rf build Export DerivedData Hyperchat.xcarchive *.dmg

# Reset build number if needed
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 50" Info.plist

# Run the script again
./deploy-hyperchat.sh
```

## Manual Notarization (if needed)

If automated notarization fails, you can notarize manually:

```bash
# Submit for notarization
xcrun notarytool submit "Hyperchat-v1.0.dmg" \
  --keychain-profile "hyperchat-notarize" \
  --wait

# If successful, staple the ticket
xcrun stapler staple "Hyperchat-v1.0.dmg"

# Verify
spctl -a -vvv -t open --context context:primary-signature "Hyperchat-v1.0.dmg"
```