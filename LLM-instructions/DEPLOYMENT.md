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


### **Part 1: Prerequisites & Certificate Setup**

### **1.1. Apple Developer Program**

Distribution outside the Mac App Store requires a paid membership in the Apple Developer Program. Free accounts cannot generate the necessary `Developer ID` certificates.**1**

| Account Type | Annual Cost | App Store Seller Name | Team Members |
| --- | --- | --- | --- |
| **Individual** | $99 USD | Your Personal Name | Single user only |
| **Organization** | $99 USD | Company's Legal Name | Multiple members |

Data Sources: **3**

### **1.2. Essential Certificates**

You will need two types of `Developer ID` certificates. They are used for different purposes and are not interchangeable.**6**

- **Developer ID Application:** Used to sign the application bundle (`.app`) and all its nested code (frameworks, helpers, etc.). This is your primary certificate.**8**
- **Developer ID Installer:** Used exclusively to sign installer packages (`.pkg`). Gatekeeper checks the validity of this certificate every time the installer is run.**7**

### **1.3. Generating Your Developer ID Certificate**

You can generate certificates via the Developer Portal or directly within Xcode.

**Method 1: Developer Portal (Manual Process)**

1. **Create a Certificate Signing Request (CSR):**
    - Open **Keychain Access** on your Mac.
    - Go to `Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority...`.**9**
    - Enter your developer email and name. Select "Saved to disk" and save the `.certSigningRequest` file.**9**
2. **Generate the Certificate:**
    - Log in to the Apple Developer Portal and navigate to "Certificates, Identifiers & Profiles".**6**
    - Click `+` to add a new certificate.
    - Under "Software," select `Developer ID Application` and click Continue.**6**
    - Upload the `.certSigningRequest` file you just created.**6**
3. **Install the Certificate:**
    - Download the generated `.cer` file from the portal.**6**
    - Double-click the file to install it into your Keychain.**6** Verify it appears in Keychain Access under "My Certificates".**10**

**Method 2: Xcode (Automated Process)**

1. In Xcode, go to `Settings > Accounts`.
2. Select your Apple ID and click "Manage Certificates...".**11**
3. Click the `+` button and select `Developer ID Application`.**11** Xcode handles the rest automatically.

### **Part 2: Xcode Project Configuration**

### **2.1. Signing & Capabilities**

In your Xcode project, select your app target and go to the **Signing & Capabilities** tab. This is your command center for signing.**13**

- **Team:** Select your personal or company developer team from the dropdown. This is a critical step when switching accounts.**15**
- **Bundle Identifier:** Ensure this is a unique, reverse-DNS format string (e.g., `com.yourcompany.yourapp`).
- **Automatically manage signing:** Keep this enabled for the simplest workflow.**18**

### **2.2. Enable the Hardened Runtime**

The Hardened Runtime is mandatory for notarization.**19**

1. In the **Signing & Capabilities** tab, click `+ Capability`.
2. Select **Hardened Runtime** from the list.**20**

If your app requires functionality restricted by the Hardened Runtime, you must enable specific exceptions, known as entitlements. Request only the entitlements your app absolutely needs.**20**

| Common Entitlement | Purpose |
| --- | --- |
| **Allow Execution of JIT-compiled Code** | For apps using Just-In-Time compilers, like those embedding scripting engines (JavaScript, Lua).**22** |
| **Disable Library Validation** | Allows your app to load plugins or frameworks signed by other developers. Use with caution.**23** |
| **Audio Input** | Grants permission to record audio from the microphone.**20** |
| **Camera** | Grants permission to capture video and images from cameras.**20** |
| **Apple Events** | Allows your app to send Apple Events to control other applications.**20** |

### **Part 3: The Complete Command-Line Workflow**

This is the standard, scriptable process for signing and distributing your app.

### **Step 1: Code Signing (`codesign`)**

Always sign nested code (frameworks, helpers) *before* signing the main application bundle. This is the "inside-out" rule.**8**

**Bash**

`# General signing command
codesign --force --timestamp --options runtime \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  /path/to/YourApp.app

# Signing with specific entitlements
codesign --force --timestamp --options runtime \
  --entitlements /path/to/entitlements.plist \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  /path/to/YourApp.app`

- `-force`: Replaces any existing signature. Essential for re-signing.**26**
- `-timestamp`: Embeds a secure timestamp. **Required** for notarization.**27**
- `-options runtime`: Enables the Hardened Runtime. **Required** for notarization.**27**
- `-entitlements`: A path to a `.plist` file specifying any Hardened Runtime exceptions your app needs.**21**

### **Step 2: Package for Notarization**

The notary service requires a single file upload. A `.zip` archive is the most common container.

**Bash**

`zip -ry "YourApp.zip" "YourApp.app"`

### **Step 3: Notarization (`notarytool`)**

`notarytool` is the modern utility for interacting with Apple's notary service, replacing the deprecated `altool`.**19**

1. Store Credentials (One-Time Setup):
    
    Generate an app-specific password at appleid.apple.com.2 Then, store it securely in your Keychain:
    
    **Bash**
    
    `xcrun notarytool store-credentials "YOUR_PROFILE_NAME" \
      --apple-id "your.email@example.com" \
      --team-id "YOURTEAMID" \
      --password "xxxx-xxxx-xxxx-xxxx"`
    
    Replace the placeholders. `YOUR_PROFILE_NAME` is a local alias you'll use in subsequent commands.**30**
    
2. **Submit for Notarization:**
    
    **Bash**
    
    `xcrun notarytool submit "YourApp.zip" \
      --keychain-profile "YOUR_PROFILE_NAME" --wait`
    
    The `--wait` flag is highly recommended for scripts, as it pauses execution until notarization is complete and returns the final status.**19**
    

### **Step 4: Stapling the Ticket (`stapler`)**

Stapling attaches the notarization ticket directly to your app, allowing Gatekeeper to verify it offline.**8**

**Bash**

`# Staple the ticket to the.app bundle (not the.zip)
xcrun stapler staple "YourApp.app"

# Verify the staple was successful
xcrun stapler validate -v "YourApp.app"`

A successful validation confirms the app is ready for distribution.**33**

### **Part 4: Professional Packaging (DMG)**

A customized Disk Image (`.dmg`) is the standard for professional distribution.

1. Create the DMG:
    
    While you can use the complex built-in hdiutil 34, the open-source
    
    `create-dmg` tool is simpler and recommended. Install it via Homebrew: `brew install create-dmg`.**30**
    
    **Bash**
    
    `create-dmg \
      --volname "My Awesome App 1.0" \
      --background "/path/to/background.png" \
      --window-size 800 400 \
      --icon "YourApp.app" 200 190 \
      --app-drop-link 600 185 \
      "YourApp-1.0.dmg" \
      "YourApp.app"`
    
2. Sign, Notarize, and Staple the DMG:
    
    For the most robust security, you should notarize the final distribution container itself.8
    
    **Bash**
    
    `# 1. Sign the DMG with your Application certificate
    codesign --sign "Developer ID Application: Your Name (TEAMID)" "YourApp-1.0.dmg"
    
    # 2. Notarize the signed DMG
    xcrun notarytool submit "YourApp-1.0.dmg" --keychain-profile "YOUR_PROFILE_NAME" --wait
    
    # 3. Staple the ticket to the DMG
    xcrun stapler staple "YourApp-1.0.dmg"`
    

### **Part 5: Troubleshooting Manual**

### **Problem 1: Switching Developer Credentials**

When moving from a company to a personal account, you must purge all traces of the old identity.

- **Step 1: Remove Account from Xcode:** Go to `Xcode > Settings > Accounts`, select the old company Apple ID, and click the  button.**39** This is often not enough.
- **Step 2: Purge Certificates from Keychain:** This is the most critical step. `codesign` uses the Keychain, not Xcode's account list.
    1. Open **Keychain Access**.
    2. Select the `login` keychain and the `My Certificates` category.**10**
    3. Find and delete all certificates and private keys associated with the old company (e.g., `Developer ID Application: Old Company Inc.`).**43**
- **Step 3: Clean the Xcode Project:**
    1. In your project's `Build Settings`, search for the old Team ID (e.g., `OLDTEAMID`).
    2. Clear this value from the `DEVELOPMENT_TEAM` setting for **all** targets (app, tests, etc.).**15**
- **Step 4: Finalize:**
    1. In `Signing & Capabilities`, ensure your new personal team is selected.**15**
    2. Clean the build folder (`Product > Clean Build Folder`) and restart Xcode.**46**

### **Problem 2: Gatekeeper Rejection: "cannot be checked for malicious software"**

This error indicates a problem with your app's signature or notarization, not actual malware.**47**

**Diagnostic Workflow:**

1. **Check Local Assessment (`spctl`):** See how Gatekeeper on your machine assesses the app.
    
    **Bash**
    
    `spctl --assess -vv --type execute /path/to/YourApp.app`
    
    Look for a result like `accepted` or `source=Notarized Developer ID`.**49**
    
2. **Verify Signature (`codesign`):** Perform a strict check that mimics Gatekeeper.
    
    **Bash**
    
    `codesign --verify --deep --strict --verbose=2 /path/to/YourApp.app`
    
    Any failure here points to a signing problem that must be fixed.**49**
    
3. **Get the Notary Log (`notarytool`):** If local checks pass but notarization fails, the log file is your definitive guide.
    
    **Bash**
    
    `# Get the submission UUID from your history
    xcrun notarytool history --keychain-profile "YOUR_PROFILE_NAME"
    
    # Download the log for the failed submission
    xcrun notarytool log <UUID> --keychain-profile "YOUR_PROFILE_NAME" developer_log.json`
    
    The `issues` array in the `developer_log.json` file will detail the exact problems.**31**
    

**Common Notarization Log Errors:**

| `message` in `developer_log.json` | Likely Cause & Solution |
| --- | --- |
| **"The signature of the binary is invalid."** | A file was modified after signing, or a nested component was not signed. **Solution:** Re-sign everything in the correct "inside-out" order.**49** |
| **"The executable does not have the hardened runtime enabled."** | The `--options runtime` flag was missing from your `codesign` command. **Solution:** Add the flag and re-sign.**49** |
| **"The signature does not include a secure timestamp."** | The `--timestamp` flag was missing from your `codesign` command. **Solution:** Add the flag and re-sign. This is mandatory.**49** |
| **"The binary uses an SDK older than the 10.9 SDK."** | Your project's "macOS Deployment Target" is too old. **Solution:** Set the deployment target to 10.9 or later in Build Settings.**49** |

### **Problem 3: Common Xcode Signing Errors**

- **"Signing for... requires a development team."**
    - **Cause:** The `Team` is not set in `Signing & Capabilities`, often for a dependency like a Swift Package or CocoaPod.**53**
    - **Solution:** Select your team. For dependencies, you may need to add a post-install script to your `Podfile` or adjust build settings.
- **"No account for team..."**
    - **Cause:** The project file has a hardcoded reference to a Team ID for an account no longer in Xcode.**15**
    - **Solution:** Search for the old Team ID in `Build Settings` across all targets and replace it with your current one.
- **"Conflicting provisioning settings."**
    - **Cause:** A mismatch between automatic signing and manually specified profiles in `Build Settings`.**18**
    - **Solution:** Commit to one method. Either use full automatic signing or disable it and manage all profiles manually.
- **"The entitlements specified... do not match those specified in your provisioning profile."**
    - **Cause:** A capability is enabled in your app (e.g., Push Notifications) that is not authorized in the provisioning profile.**56**
    - **Solution:** Let Xcode fix it automatically if possible. If not, log in to the Developer Portal, edit your App ID to include the service, and regenerate the provisioning profile.


    # **The Developer's Field Guide to Signing and distributing macOS Apps Outside the App Store**

You've spent weeks, maybe months, crafting the perfect macOS app. The code is elegant, the UI is polished, and it's ready for the world. But then you hit the wall: a labyrinth of certificates, signing, notarization, and cryptic error messages from Apple. Hours of fighting with Xcode lead to warnings that your perfectly legitimate app "cannot be checked for malicious software," a frustrating and demoralizing experience for any developer. This guide is the map through that territory. It details not only the "how" of distributing your app outside the Mac App Store but, more importantly, the "why" behind each step. It provides clear workflows for both the Xcode graphical interface and command-line automation, and concludes with a comprehensive manual for troubleshooting the most common and maddening issues, including the specific challenges of switching developer credentials and resolving Gatekeeper rejections.

## **Part 1: The Foundation – Understanding the "Why"**

Successfully distributing a macOS application independently requires an understanding of the security philosophy that underpins the entire process. Without this conceptual framework, the steps for signing and notarization become a series of rote, meaningless commands, making troubleshooting nearly impossible. This section establishes that essential groundwork.

### **1.1 The Chain of Trust: A Developer's Introduction to Gatekeeper, Code Signing, and Notarization**

At the heart of macOS security is a "chain of trust," a series of checks designed to protect users from malicious software. As a developer distributing outside the Mac App Store, your primary task is to ensure your application satisfies every link in this chain.

### **Gatekeeper: The User's Guardian**

Gatekeeper is the user-facing security technology in macOS responsible for verifying downloaded software before it runs.**1** When a user opens an app for the first time, Gatekeeper intervenes to check its credentials. Since macOS Catalina (10.15), it looks for two key pieces of evidence: a valid digital signature from an identified developer and a notarization ticket from Apple.**3** If either is missing or invalid, Gatekeeper presents a warning dialogue, such as "macOS cannot verify that this app is free from malware," effectively stopping the user from proceeding easily.**5** The entire signing and notarization process exists to satisfy Gatekeeper's requirements.

### **Code Signing: Your Digital Signature**

Code signing is the first link in the chain and serves as your digital, cryptographic promise of authenticity. It uses a `Developer ID` certificate, issued by Apple to a registered developer, to prove two critical facts:

1. **Identity:** The app was created by you, a developer whose identity has been verified by Apple.**7**
2. **Integrity:** The app has not been modified or tampered with since you signed it. Any change to the app's code or resources will invalidate the signature.**4**

This signature is the foundation of trust. Without it, your app is an anonymous piece of software that Gatekeeper will block by default.

### **Notarization: Apple's Automated Malware Scan**

Notarization is the second, mandatory link in the chain for modern macOS versions.**3** It is not a human-led App Review like the one for the App Store; rather, it's a fast, automated service that scans your already-signed software for malicious components and common code-signing problems.**3**

When you submit your app for notarization, Apple's service performs its checks. If the app passes, the service generates a "ticket." This ticket is then stored on Apple's servers and can also be directly attached to your app in a process called "stapling".**3** When Gatekeeper inspects your app, it checks for this ticket (either online or stapled to the app) to confirm that Apple has scanned it. A successful notarization check gives users the confident message: "Apple checked it for malicious software and none was detected".**6**

The evolution from simple code signing to mandatory notarization represents a fundamental policy shift by Apple. The burden of establishing software trust has moved from the end-user, who previously had to make a judgment call on whether to trust an unknown developer, to the developer themselves. By requiring enrollment in a paid program and submission to an automated security scan, Apple has created a system of developer accountability.**2** The annual fee is not just for access to tools; it is an entry fee into a trusted ecosystem where a developer's identity is verified and their software is vetted.**11** This entire technical framework—Gatekeeper, signing, and notarization—is the implementation of this policy. An error message about malware is therefore not an accusation, but a notification that a link in this chain of trust is broken.

### **1.2 Your Developer Identity: Accounts, Certificates, and Keys**

To participate in this chain of trust, you need a verified identity, which is managed through the Apple Developer Program and represented cryptographically by a set of certificates.

### **The Apple Developer Program (ADP): The Price of Admission**

While a free Apple ID allows you to download Xcode and develop apps for your personal devices, distributing software with a `Developer ID` requires a paid membership in the Apple Developer Program.**12** The key benefits for this purpose are direct access to the

`Developer ID` certificates and the notarization service, which are unavailable to free accounts.**13**

There are two primary paid account types relevant for independent distribution:

| Feature | Individual Account | Organization Account |
| --- | --- | --- |
| **Annual Cost** | $99 | $99 |
| **App Store Seller Name** | Your Personal Name | Your Company's Legal Name |
| **Team Members** | Single user only | Multiple members with different roles |
| **D-U-N-S Number** | Not Required | Required for verification |
| **Primary Use Case** | Freelancers, solo developers | Companies, startups, teams |

Data Sources: **11**

For a developer switching from a company account to a personal one, enrolling as an Individual is the correct path.

### **The Certificate Arsenal: Application vs. Installer**

The Apple Developer Program provides two distinct types of `Developer ID` certificates for distribution outside the Mac App Store. Understanding their different roles is crucial, as using the wrong one is a common source of errors.

- **Developer ID Application Certificate:** This is the workhorse certificate. It is used to sign the application bundle (`.app`) itself, along with any embedded code like frameworks, plug-ins, or command-line tools.**7** Gatekeeper checks this certificate's validity when the app is first installed. An app signed with a certificate that was valid at the time of signing can typically still run even after the certificate expires, though any future updates will require re-signing with a new, valid certificate.**16**
- **Developer ID Installer Certificate:** This certificate has a much narrower purpose: it is used *exclusively* for signing installer packages (`.pkg`).**15** Gatekeeper's check on this certificate is more stringent; it verifies its validity
    
    *every time the installer is run*. If an installer package is signed with an expired `Developer ID Installer` certificate, it will fail to launch, period.**16**
    

This distinction reveals a layered, "inside-out" security model. A developer must first sign the *contents* (the `.app`) with an Application certificate. Then, if they are using a `.pkg` installer, they sign the *container* with an Installer certificate. This ensures that both the payload and the delivery mechanism are independently verified. Many notarization failures stem from failing to sign these nested components in the correct order.**9**

### **Generating Your Developer ID Certificates**

You can generate the necessary `Developer ID Application` certificate using two methods. While the Xcode method is simpler, understanding the manual portal method provides deeper insight into the process, which is invaluable for troubleshooting and automation.

Method 1: The Developer Portal (Recommended for Clarity)

This method explicitly shows the relationship between your private key and the public certificate issued by Apple.

1. **Create a Certificate Signing Request (CSR):** On your Mac, open the **Keychain Access** application. From the menu bar, navigate to `Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority...`.**17**
    - Enter the email address associated with your Apple Developer account.
    - Enter your name in the "Common Name" field.
    - Select "Saved to disk" and click Continue. Save the `.certSigningRequest` file to your computer. This process creates a public/private key pair on your Mac; the private key never leaves your machine, and the CSR contains the public key.**18**
2. **Log in to the Apple Developer Portal:** Navigate to the "Certificates, Identifiers & Profiles" section of your account.**17**
3. **Create a New Certificate:** Click the blue `+` button to add a new certificate. Under the "Software" section, select `Developer ID Application` and click Continue.**15**
4. **Upload the CSR:** On the next screen, click "Choose File" and upload the `.certSigningRequest` file you created in Step 1.
5. **Download and Install:** Apple will generate your certificate. Download the resulting `.cer` file. Double-click this file to install it directly into your Keychain Access.**17**
6. **Verify in Keychain:** Open Keychain Access and go to the "My Certificates" category. You should see your new `Developer ID Application` certificate listed, with a small triangle next to it. This triangle indicates that you have the corresponding private key, which is essential for signing.**20**

Method 2: The Xcode Shortcut

Xcode can automate this process entirely.

1. In Xcode, go to `Settings` (or `Preferences`) `> Accounts`.
2. Select your Apple ID and click "Manage Certificates..."
3. In the dialog that appears, click the `+` button in the bottom-left corner and select `Developer ID Application`.**20**

Xcode will handle the CSR generation, submission, and installation behind the scenes. While convenient, this "magic" hides the critical role of the private key. Losing the private key associated with a certificate renders that certificate useless for signing new code.**22** Understanding the manual process empowers developers to manage their keys properly, back them up, and diagnose issues when Xcode's automation fails.

## **Part 2: The Standard Path – Distribution via the Xcode Interface**

For many developers, the most straightforward way to sign and distribute an app is by using Xcode's built-in graphical tools. This "happy path" automates most of the complex steps, from signing to notarization.

### **2.1 Pre-Flight Check: Configuring Your Xcode Project**

Before you can build a distributable app, your project must be configured with the correct identity and security settings. This is all handled in the `Signing & Capabilities` tab.

### **Signing & Capabilities Command Center**

This tab is the central hub for managing your app's identity. To access it, select your project in the Project navigator, then select your app's main target, and click the `Signing & Capabilities` tab.**23**

- **Team:** From the `Team` dropdown menu, select your developer account. For a developer switching from a corporate account, this is the most critical step. Ensure the new, personal account is selected here.**24**
- **Bundle Identifier:** This must be a unique string in reverse-DNS format (e.g., `com.yourdomain.yourappname`). This identifier is how Apple tracks your app across its services, so it should be chosen carefully.**25**
- **Automatically manage signing:** For this GUI-based workflow, it is highly recommended to keep this option checked. When enabled, Xcode uses the selected Team and Bundle Identifier to automatically generate and manage the necessary provisioning profiles, which authorize your app to use certain services and run on devices.**25**

### **The Hardened Runtime: Mandatory for Notarization**

The Hardened Runtime is a security feature introduced in macOS Mojave (10.14) and is a strict requirement for notarization.**9** It protects your app from common exploit vectors like code injection and memory tampering by applying a set of restrictions at the system level.**31**

To enable it, click the `+ Capability` button in the `Signing & Capabilities` tab and select `Hardened Runtime` from the library.**29**

### **Configuring Entitlements (Exceptions)**

By default, the Hardened Runtime locks your app down. If your app needs to perform a specific action that the Hardened Runtime restricts, you must request an exception by enabling an "entitlement." Entitlements are fine-grained permissions that opt your app out of a specific protection. The guiding principle is to request the absolute minimum set of entitlements necessary for your app to function.**31**

The following are some of the most common Hardened Runtime entitlements you might need for a macOS app:

| Entitlement (Xcode UI Name) | Entitlement Key (`com.apple.security.*`) | Purpose | Common Use Case |
| --- | --- | --- | --- |
| **Allow Execution of JIT-compiled Code** | `com.apple.security.cs.allow-jit` | Allows the app to create writable and executable memory, necessary for Just-In-Time compilation. | Apps that embed scripting languages (like JavaScript, Lua) or certain cross-platform game engines.**30** |
| **Allow Unsigned Executable Memory** | `com.apple.security.cs.allow-unsigned-executable-memory` | A more permissive and less secure version of the JIT entitlement. Use with extreme caution. | Legacy codebases or specific frameworks that require this behavior.**33** |
| **Disable Library Validation** | `com.apple.security.cs.disable-library-validation` | Allows your app to load frameworks, libraries, and plug-ins that are signed by other developers. | Apps with a plug-in architecture where third parties can create add-ons.**33** |
| **Audio Input** | `com.apple.security.device.audio-input` | Grants permission to record audio from the microphone using Core Audio APIs. | Any app that needs to record sound, like a voice memo app or audio editor.**29** |
| **Camera** | `com.apple.security.device.camera` | Grants permission to capture video and still images from built-in or external cameras. | Video conferencing apps, photo booth apps, or QR code scanners.**29** |
| **Apple Events** | `com.apple.security.automation.apple-events` | Allows your app to send Apple Events to control other applications. | Automation tools or apps that integrate deeply with other apps like Finder or Mail.**29** |

Data Sources: **29**

### **2.2 The Main Event: Archiving, Notarizing, and Exporting**

With the project correctly configured, the process of creating a distributable, notarized app is streamlined through Xcode's Organizer.

- **Step 1: Create the Archive:** In the main Xcode window, ensure the run destination in the scheme toolbar is set to `Any Mac (Apple Silicon, Intel)` or a specific connected Mac. Do not use a simulator. Then, from the menu bar, select `Product > Archive`.**8** Xcode will compile your app and package it into an archive, which then appears in the Organizer window.
- **Step 2: Start the Distribution Process:** The Organizer window should open automatically, displaying your newly created archive. Select it and click the blue `Distribute App` button on the right.**8**
- **Step 3: Choose Distribution Method:** A panel will appear with several options. To distribute your app directly to users outside the App Store, select `Developer ID` and click Next. On the following screen, choose `Direct Distribution`.**39**
- **Step 4: Upload for Notarization:** The next panel asks for a destination. Choose `Upload`. This option packages your archive and sends it directly to Apple's notary service for the automated security scan.**3** Xcode handles the complex command-line submission in the background.
- **Step 5: Wait and Monitor:** The notarization process is not instantaneous. It can take anywhere from a few minutes to over an hour, depending on server load.**8** You can monitor the progress in the Organizer window. Apple will also send an email to your developer account address once the process is complete.
- **Step 6: Export the Notarized App:** Once you receive the "Notarization Successful" notification, a new option will become available for that archive in the Organizer: `Export Notarized App`.**8** Select the archive again, click this button, choose a location to save the file, and click Export. Xcode will package your application, staple the notarization ticket to it, and give you a final
    
    `.app` bundle ready for distribution.
    

## **Part 3: The Power-User Path – Command-Line Automation**

For developers who use continuous integration (CI/CD) systems, build scripts, or simply prefer the control and transparency of the terminal, a command-line workflow is essential. This process uses the same underlying tools as Xcode but exposes them for manual control and automation.

### **3.1 The Automation Toolkit: `codesign`, `notarytool`, and `stapler`**

Three core command-line utilities form the basis of any automated signing and notarization workflow:

- **`codesign`**: This is the tool that applies your digital signature to application bundles, frameworks, and other executables. It embeds your developer identity into the code.**7**
- **`notarytool`**: This is the modern command-line interface to Apple's notary service. It is used to submit software for notarization, check the status of submissions, and retrieve logs. It replaces the older, now-deprecated `altool` for notarization tasks.**3**
- **`stapler`**: After successful notarization, this tool retrieves the notarization ticket from Apple's servers and attaches ("staples") it directly to your app bundle or disk image. This allows Gatekeeper to verify the app's notarization status even when the user is offline.**7**

### **3.2 A Scriptable Workflow: From Code to Notarized App**

The following steps outline a complete, scriptable process for preparing an app for distribution.

### **Step 1: Code Signing with `codesign`**

Correctly signing your app and all its components is the most critical step. A common mistake is to sign only the outer `.app` bundle while neglecting embedded helpers or frameworks. The correct approach is to sign from the "inside-out": sign the most deeply nested code first, and work your way up to the main application bundle.**9**

The basic command for signing an application bundle is:

**Bash**

`codesign --force --timestamp --options runtime --sign "Developer ID Application: Your Name (TEAMID)" /path/to/YourApp.app`

Each flag is important:

- `-force`: Overwrites any existing signature. Necessary when re-signing.**36**
- `-timestamp`: Embeds a secure, trusted timestamp in the signature. This is **required** for notarization.**7**
- `-options runtime`: Enables the Hardened Runtime for the executable. This is also **required** for notarization.**31**
- `-sign "IDENTITY"`: Specifies which certificate to use. You must provide the full "Common Name" of the certificate as it appears in Keychain Access, including your Team ID.**7**
- `-entitlements /path/to/entitlements.plist`: If your app requires Hardened Runtime exceptions, you must provide them in a `.plist` file and include this flag.**31**

### **Step 2: Preparing for Notarization**

The notary service requires a single file to be uploaded. Therefore, you must package your signed `.app` bundle into a container, most commonly a `.zip` file.

**Bash**

`zip -ry "YourApp.zip" "YourApp.app"`

### **Step 3: Notarizing with `notarytool`**

This multi-part step involves setting up credentials and then submitting the app.

- **Credential Setup (One-time task):** To avoid putting your Apple ID password in plain text within scripts, you should generate an app-specific password and store it securely in the macOS Keychain.
    1. Go to `appleid.apple.com`, sign in, and under "Sign-In and Security," generate an app-specific password. Copy this password.**27**
    2. In Terminal, run the following command to store the password in your Keychain under a profile name. This profile name is a local alias you will use in subsequent commands.
        
        **Bash**
        
        `xcrun notarytool store-credentials "AC_PASSWORD_PROFILE_NAME" --apple-id "your.email@example.com" --team-id "YOURTEAMID" --password "xxxx-xxxx-xxxx-xxxx"`
        
        Replace the placeholders with your Apple ID, Team ID, and the app-specific password you just generated.**37**
        
- **Submit for Notarization:** With credentials stored, you can now submit your zipped app.
    
    **Bash**
    
    `xcrun notarytool submit "YourApp.zip" --keychain-profile "AC_PASSWORD_PROFILE_NAME" --wait`
    
    The `--wait` flag is invaluable for automation; it pauses the script and waits for the notarization process to complete, then returns the final status.**41** If you omit
    
    - `-wait`, the command returns immediately with a submission UUID. You would then need to periodically check the status with `xcrun notarytool info <UUID>...` and, if it fails, retrieve the log with `xcrun notarytool log <UUID> developer_log.json`.
        
        **41**
        

### **Step 4: Stapling the Ticket with `stapler`**

Once notarization succeeds, the final step is to staple the ticket to your original `.app` bundle (not the `.zip` file).

**Bash**

`xcrun stapler staple "YourApp.app"`

This ensures a smooth user experience even without an internet connection.**27** You can verify that the staple was successful with:

**Bash**

`xcrun stapler validate -v "YourApp.app"`

A successful validation will confirm that the app has a valid, stapled ticket.**43**

### **3.3 Professional Packaging: Creating and Signing a DMG**

While a zipped `.app` file is functional, a customized Disk Image (`.dmg`) is the standard for professional macOS app distribution.

- **Method 1: Using `hdiutil` (The Built-in Way):** The native `hdiutil` command offers powerful control but is notoriously complex, requiring a multi-stage process of creating a temporary read-write image, mounting it, styling it with AppleScript, unmounting it, and finally converting it to a compressed, read-only final image.**49** This approach is generally reserved for advanced build systems.
- **Method 2: Using `create-dmg` (The Recommended Way):** A much simpler and highly recommended approach is to use the open-source `create-dmg` tool, which automates the entire process. It can be easily installed via Homebrew: `brew install create-dmg`.**37**
    
    A typical script using `create-dmg` looks like this:
    
    **Bash**
    
    `#!/bin/bash
    # Usage:./create-dmg.sh YourApp.app
    
    APP_BUNDLE="$1"
    APP_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleName" "$APP_BUNDLE/Contents/Info.plist")
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist")
    DMG_NAME="$APP_NAME-$VERSION.dmg"
    
    create-dmg \
      --volname "$APP_NAME $VERSION" \
      --background "./path/to/dmg-background.png" \
      --window-pos 200 120 \
      --window-size 800 400 \
      --icon-size 100 \
      --icon "$APP_NAME.app" 250 190 \
      --hide-extension "$APP_NAME.app" \
      --app-drop-link 540 185 \
      "$DMG_NAME" \
      "$APP_BUNDLE"`
    
    This script creates a professional-looking DMG with a custom background, places the app icon and a shortcut to the `/Applications` folder, and names the file based on the app's version.**37**
    
- Final Step: Signing and Notarizing the DMG:
    
    The most robust and modern distribution workflow involves signing and notarizing the final container (.dmg) itself. This provides an end-to-end chain of trust. The recommended sequence is:
    
    1. Sign all code inside your `.app` bundle from the inside out.
    2. Enable the Hardened Runtime and include a secure timestamp.
    3. Place the fully signed `.app` inside a folder.
    4. Use a tool like `create-dmg` to build your `.dmg` from that folder.
    5. Sign the final `.dmg` file using your `Developer ID Application` certificate:
        
        **Bash**
        
        `codesign --sign "Developer ID Application: Your Name (TEAMID)" "YourApp.dmg"`
        
    6. Submit the signed `.dmg` to the notary service with `notarytool`. Apple's service will recursively scan the contents, including your app.**52**
    7. Once notarization is successful, staple the ticket to the `.dmg`:
        
        **Bash**
        
        `xcrun stapler staple "YourApp.dmg"`
        
    
    Your `.dmg` is now fully signed, notarized, and ready for distribution.
    

## **Part 4: The Troubleshooting Manual – A Guide to Common Frustrations**

This section directly addresses the most common and painful issues developers face, providing systematic solutions to get unstuck.

### **4.1 The Credential Switch: Migrating from a Company to a Personal Developer Account**

Switching from a corporate to a personal developer account is a frequent source of signing headaches. Xcode and the macOS Keychain can retain old credentials, leading to errors where the build system attempts to sign with the wrong identity. A complete "digital exorcism" of the old credentials is required.

- **Step 1: The Purge - Removing the Old Identity**
    - **From Xcode:** The first, most obvious step is to remove the old account from Xcode's preferences. Go to `Xcode > Settings > Accounts`, select the old company Apple ID from the list, and click the minus () button at the bottom.**54** However, this is often insufficient on its own.
    - **From Keychain Access:** This is the most critical part of the process. The `codesign` tool pulls its identities directly from the Keychain, not from Xcode's account list. A polluted Keychain is the primary cause of signing with the wrong identity.
        1. Open the **Keychain Access** application.
        2. In the top-left "Keychains" panel, select `login`.
        3. In the bottom-left "Category" panel, select `My Certificates`.**56**
        4. Look for any certificates associated with the old company (e.g., `Developer ID Application: Old Company Inc. (OLDTEAMID)`).
        5. Right-click on each old certificate and select `Delete`. Ensure you also delete the associated private key (the expandable item under the certificate).**21**
        6. Switch to the `All Items` category and search for any saved passwords or authentication tokens related to the old Apple ID or developer account and delete them as well.
- Step 2: The Project Cleanup - Scrubbing the Old Team ID
    
    Even after cleaning your system, the Xcode project file (.pbxproj) can contain hardcoded references to the old Team ID.
    
    1. In your Xcode project, navigate to the `Build Settings` tab for your main app target.
    2. In the search bar, type `DEVELOPMENT_TEAM`.
    3. Carefully inspect every field that appears. If any still show the old Team ID, clear them or re-select your new team.**24**
    4. Repeat this process for **all** targets in your project, including unit test and UI test targets.
- **Step 3: The New Identity - Establishing the New Account**
    1. If you haven't already, add your new personal Apple ID in `Xcode > Settings > Accounts`.**55**
    2. Return to your project's `Signing & Capabilities` tab and, from the `Team` dropdown, select your new personal team.**24**
    3. Finally, perform a full clean of the build folder by selecting `Product > Clean Build Folder` from the menu, and then restart Xcode to ensure all old caches and in-memory settings are cleared.**59**

### **4.2 "Apple thinks my app is malware!" – Decoding Notarization and Gatekeeper Rejections**

The dreaded "cannot be checked for malicious software" warning is Gatekeeper's generic response to any broken link in the chain of trust. It almost never means your app contains actual malware; it means the proof of its safety is flawed or incomplete.**5** The key is to systematically diagnose where the chain broke.

### **The Diagnostic Workflow**

Follow these steps in order to pinpoint the problem.

1. **Local Gatekeeper Assessment (`spctl`):** First, ask Gatekeeper directly how it assesses your app on your local machine.
    
    **Bash**
    
    `spctl --assess -vv --type execute /path/to/YourApp.app`
    
    This command will output the assessment result, such as `accepted`, `rejected`, or `source=Notarized Developer ID`. This provides a crucial baseline for whether the issue is with the signature, the notarization, or something else.**10**
    
2. **Deep Signature Verification (`codesign`):** Next, scrutinize the signature itself.
    
    **Bash**
    
    `# Basic details, including Hardened Runtime flag
    codesign -dv --verbose=4 /path/to/YourApp.app
    
    # Strict verification that mimics Gatekeeper's checks
    codesign --verify --deep --strict --verbose=2 /path/to/YourApp.app`
    
    The first command shows the signature details, including the `flags=0x10000` which indicates the Hardened Runtime is enabled.**31** The second command performs a rigorous check for signature validity across all nested code. Any failure here must be fixed before proceeding.**10**
    
3. **Retrieving the Notary Log (`notarytool`):** If local checks pass but notarization fails or the app is still blocked on other machines, the notarization log is the definitive source of truth.
    - Get your submission history: `xcrun notarytool history --keychain-profile "AC_PROFILE"`
    - Find the UUID of the failed submission.
    - Download the JSON log: `xcrun notarytool log <UUID> --keychain-profile "AC_PROFILE" developer_log.json`.**42**

### **Interpreting the Notary Log (`developer_log.json`)**

This JSON file contains an `issues` array, where each object details a specific error or warning found by Apple's service.**41** This is your guide to fixing the problem.

| `message` (from JSON log) | Likely Cause | Solution |
| --- | --- | --- |
| **"The signature of the binary is invalid."** | A file within the app bundle was modified after it was signed, or a nested executable/library was not signed at all. | Ensure all binaries are signed in the correct "inside-out" order. Re-sign the entire application. Use `codesign --verify` to find the specific component with the invalid signature.**10** |
| **"The executable does not have the hardened runtime enabled."** | The `codesign` command was run without the `--options runtime` flag, or the Hardened Runtime capability was not enabled in Xcode. | Add the Hardened Runtime capability in Xcode or use the `--options runtime` flag in your `codesign` command and re-sign.**9** |
| **"The signature does not include a secure timestamp."** | The `codesign` command was run without the `--timestamp` flag. | Add the `--timestamp` flag to your `codesign` command and re-sign. This is non-negotiable for notarization.**10** |
| **"The binary uses an SDK older than the 10.9 SDK."** | The project's "macOS Deployment Target" build setting is set to a version below 10.9. | In Xcode Build Settings, set the macOS Deployment Target to 10.9 or later. This does not prevent your app from running on older supported systems.**8** |
| **"The executable... has an rpath... that is not a path prefix of any of the binaries in the container."** | A "dangling rpath." A binary inside your app references a library using an absolute path on your build machine (e.g., `/usr/local/lib`) instead of a path relative to the app bundle. | This is an advanced issue. Use `otool -l /path/to/binary` to inspect the load commands and find the problematic rpath. Use `install_name_tool` to change the path to be relative (e.g., `@rpath/...`) or modify your project's build settings to link libraries correctly.**35** |

Data Sources: **9**

### **Advanced Gotchas**

- **Third-Party Frameworks:** Using frameworks signed by another developer often requires enabling the `Disable Library Validation` entitlement. However, this entitlement can open the door to other Gatekeeper issues, especially if the framework itself has problems like dangling rpaths.**34**
- **Notarization Hangs:** On rare occasions, the notary service can get stuck processing a submission. Community consensus is to cancel the submission and try again after a short wait. It is also wise to check Apple's official System Status page to see if the "Developer ID Notary Service" is experiencing an outage.**9**

### **4.3 A Quick Reference for Common Xcode Signing Errors**

These are common errors that appear directly in the Xcode build log or as dialogs, often preventing a build from even completing.

- **Error: "Signing for... requires a development team. Select a development team in the Signing & Capabilities editor."**
    - **Cause:** The `Team` is set to "None" in the project editor, or the project uses dependencies (like Swift Packages or CocoaPods) that also need a team assigned, which became a stricter requirement in Xcode 14.**61**
    - **Solution:** Ensure the correct team is selected in `Signing & Capabilities`. For CocoaPods, you may need to add a script to your `Podfile` to explicitly disable code signing for resource bundles.**64**
- **Error: "No account for team ''."**
    - **Cause:** The project file has a hardcoded reference to a Team ID from a developer account that is no longer configured in your Xcode `Settings > Accounts`. This is a classic symptom of switching developer accounts.**24**
    - **Solution:** In the project's `Build Settings`, search for the old Team ID. It may be present in multiple targets or configurations. Manually clear these fields or select your new team.**24**
- **Error: "Conflicting provisioning settings."**
    - **Cause:** There is a mismatch between Xcode's "Automatically manage signing" feature and a manually specified code signing identity or provisioning profile in the `Build Settings`.**63**
    - **Solution:** Either commit fully to automatic signing by setting the `Code Signing Identity` build setting to "Apple Development" or "Apple Distribution," or disable automatic signing and manually specify the exact provisioning profile for each configuration.
- **Error: "The entitlements specified... do not match those specified in your provisioning profile."**
    - **Cause:** You have enabled a capability in the `Signing & Capabilities` tab (e.g., Push Notifications, Keychain Sharing) that requires an explicit entitlement, but the provisioning profile being used does not contain that permission.**65**
    - **Solution:** If using automatic signing, Xcode should resolve this by regenerating the profile. Click "Fix Issue" if prompted. If signing manually, you must log in to the Apple Developer Portal, edit your App ID to enable the corresponding service, and then regenerate and re-download the provisioning profile that uses that App ID.

## **Conclusion**

Distributing a macOS app outside the Mac App Store is a journey through Apple's robust and exacting security ecosystem. While the layers of code signing, Hardened Runtime, and notarization can initially seem like a daunting series of obstacles, they are a systematic and manageable process. The entire framework is built on a chain of trust, designed to protect users by holding developers accountable for the software they create.

By understanding the "why" behind Gatekeeper's checks, developers can better navigate the "how." The core requirements are an active, paid Apple Developer Program membership and the correct use of `Developer ID` certificates. The workflow itself—whether executed through the convenience of the Xcode interface or the power of command-line scripts—boils down to three fundamental stages: signing the code to prove its identity and integrity, notarizing it with Apple to scan for malware, and packaging it professionally for users.

The most challenging part of this journey is often troubleshooting, where cryptic errors can halt progress for hours. However, with a methodical diagnostic approach—using `spctl` for local assessment, `codesign` for signature validation, and `notarytool` to retrieve the definitive notary log—any issue can be pinpointed and resolved. The frustrations of switching accounts or deciphering Gatekeeper rejections are surmountable with a clear understanding of how identities are managed in the Keychain and how to interpret the feedback from Apple's services. You now have the map. Go forth and distribute your app with confidence.

# The Complete macOS App Signing & Distribution Field Guide

## Getting started: The complete journey from zero to distributed app

The process of distributing a macOS app outside the Mac App Store involves **eight critical steps**: setting up your Apple Developer account, creating certificates, signing your application, submitting for notarization, stapling the ticket, and finally distributing your signed app. Each step must be executed correctly, as a single error can result in users seeing the dreaded "app is damaged" message.

Here's your complete roadmap:

1. **Setup Apple Developer Account** ($99/year)
2. **Create Certificate Signing Request** in Keychain Access
3. **Generate Developer ID Application Certificate** via Apple Developer Portal
4. **Sign the Application** using codesign command
5. **Create Distribution Package** (DMG, ZIP, or PKG)
6. **Submit for Notarization** using notarytool
7. **Staple the Ticket** to your app
8. **Distribute** the signed and notarized app

## Part 1: Certificates and Provisioning Setup

### Creating Your Certificate Step-by-Step

First, open Keychain Access and create a Certificate Signing Request (CSR):

```bash
# Open Keychain Access
# Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
# User Email: Your Apple ID email
# Common Name: Your name or company name
# CA Email: Leave empty
# Request: Save to disk
```

Next, generate your certificate through the Apple Developer Portal:
1. Navigate to Certificates, Identifiers & Profiles → Certificates
2. Click "+" to add new certificate
3. Select "Developer ID Application" under Software
4. Upload your CSR file
5. Download the generated certificate (.cer file)

Install the certificate by double-clicking the .cer file or importing through Keychain Access.

### Understanding Certificate Types

**Developer ID Application Certificate** is your primary signing certificate for apps distributed outside the Mac App Store. It's valid for 5 years and enables Gatekeeper approval. You can have up to 5 of these certificates per developer account.

**Developer ID Installer Certificate** is required for .pkg installer packages. It must use the same Team ID as your application certificate.

**Provisioning Profiles** are only required when using advanced capabilities like CloudKit or push notifications. For basic app signing, you don't need a provisioning profile.

### Switching from Company to Personal Credentials

The process of switching between company and personal Apple Developer credentials requires careful planning because **certificates cannot be directly transferred between accounts**. If you're moving from a company account to personal:

1. Export your certificates from the company Keychain as .p12 files (including private keys)
2. Create your personal Apple Developer account
3. Generate new certificates under your personal account
4. Update your app's Team ID and bundle identifier if necessary

Remember that apps signed with different Team IDs are considered different apps by macOS, potentially breaking automatic updates.

## Part 2: Xcode Configuration for Signing

### Configuring Your Project

In Xcode, proper signing configuration starts with the Signing & Capabilities tab:

1. Select your app target (not the project)
2. Under Signing & Capabilities:
   - **Team**: Select your Apple Developer Program team
   - **Bundle Identifier**: Use reverse DNS format (com.company.app)
   - **Signing Certificate**: "Developer ID Application" for distribution

### Critical Build Settings

Configure these build settings for distribution:

```
CODE_SIGN_IDENTITY = Developer ID Application: Company Name (TEAM_ID)
DEVELOPMENT_TEAM = XXXXXXXXXX
CODE_SIGN_STYLE = Manual
ENABLE_HARDENED_RUNTIME = YES
```

### Advanced Configuration with XCConfig

For teams or CI/CD pipelines, use XCConfig files:

```
// Distribution.xcconfig
CODE_SIGN_IDENTITY = Developer ID Application: Company Name (TEAM_ID)
DEVELOPMENT_TEAM = XXXXXXXXXX
PROVISIONING_PROFILE_SPECIFIER = 
CODE_SIGN_STYLE = Manual
OTHER_CODE_SIGN_FLAGS = --options runtime --timestamp
```

## Part 3: Command-Line Signing with codesign

### Essential codesign Commands

The basic signing command structure:

```bash
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --timestamp \
  --force \
  /path/to/YourApp.app
```

**Critical flags explained:**
- `--options runtime`: Enables hardened runtime (mandatory for notarization)
- `--timestamp`: Adds secure timestamp (required for notarization)
- `--force`: Replaces existing signature
- `--deep`: **Avoid this deprecated flag** - sign components individually instead

### Signing with Entitlements

When your app requires special permissions:

```bash
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --timestamp \
  --entitlements entitlements.plist \
  --force \
  YourApp.app
```

### Verification Commands

Always verify your signature after signing:

```bash
# Basic verification
codesign --verify --verbose=2 YourApp.app

# Strict verification (recommended)
codesign --verify --deep --strict --verbose=2 YourApp.app

# Display signature information
codesign -dvv YourApp.app

# Check specific requirements
codesign --test-requirement="=notarized" -vv YourApp.app
```

## Part 4: The Notarization Process

### Setting Up notarytool

First, store your credentials securely in the keychain:

```bash
xcrun notarytool store-credentials "notary-profile" \
  --apple-id your@email.com \
  --team-id TEAM_ID_HERE \
  --password app-specific-password
```

### Submitting for Notarization

The modern approach uses notarytool (altool was deprecated in Fall 2023):

```bash
# Submit and wait for completion
xcrun notarytool submit YourApp.zip \
  --keychain-profile "notary-profile" \
  --wait

# Check status of a submission
xcrun notarytool info SUBMISSION_ID \
  --keychain-profile "notary-profile"

# Get detailed log for failures
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "notary-profile"
```

### Stapling the Ticket

After successful notarization, staple the ticket to enable offline verification:

```bash
# Staple to app
xcrun stapler staple YourApp.app

# Staple to DMG
xcrun stapler staple YourApp.dmg

# Staple to PKG
xcrun stapler staple YourApp.pkg

# Verify stapling
xcrun stapler validate YourApp.app
```

## Part 5: Distribution Methods

### Creating a DMG (Recommended Method)

DMGs provide the best user experience and avoid app translocation issues:

```bash
# Create DMG
hdiutil create -volname "YourApp" \
  -srcfolder /path/to/YourApp.app \
  -ov -format UDZO YourApp.dmg

# Sign the DMG
codesign -s "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp YourApp.dmg

# Notarize and staple the DMG
xcrun notarytool submit YourApp.dmg \
  --keychain-profile "notary-profile" --wait
xcrun stapler staple YourApp.dmg
```

### Creating a ZIP Archive

**Critical:** Use `ditto`, not the standard `zip` command:

```bash
# CORRECT - preserves macOS metadata
ditto -c -k --sequesterRsrc --keepParent MyApp.app MyApp.zip

# WRONG - corrupts signatures
zip -r MyApp.zip MyApp.app  # DON'T USE THIS!
```

### Creating an Installer Package

For complex installations requiring admin privileges:

```bash
# Build component package
pkgbuild --root /path/to/app \
  --identifier com.company.app.pkg \
  --version 1.0 \
  --install-location /Applications \
  MyApp.pkg

# Sign with Installer certificate
productbuild --sign "Developer ID Installer: Your Name" \
  --timestamp \
  MyApp.pkg MyApp-signed.pkg
```

## Part 6: Troubleshooting Common Problems

### "App is damaged and can't be opened"

This is the most common issue developers face. Solutions in order of likelihood:

1. **Incorrect ZIP creation**: Use `ditto -c -k --sequesterRsrc --keepParent`
2. **Missing notarization**: Submit to notarytool and wait for approval
3. **Quarantine issues**: Remove with `xattr -cr YourApp.app`
4. **App translocation**: Move app properly to /Applications/

### "The signature of the binary is invalid"

Root causes and fixes:

```bash
# Check for Windows line endings in Info.plist
file YourApp.app/Contents/Info.plist
# Fix with: dos2unix YourApp.app/Contents/Info.plist

# Verify certificate chain
security find-identity -v -p codesigning

# Re-sign with proper certificate
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name" \
  YourApp.app
```

### Notarization Failures

Common notarization rejection reasons:

1. **Missing hardened runtime**: Add `--options runtime` to codesign
2. **Unsigned nested code**: Sign all frameworks and helpers individually
3. **Invalid entitlements**: Remove debug entitlements from release builds

Debug notarization issues:

```bash
# Get detailed log
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "notary-profile" \
  developer_log.json

# Common fix for embedded frameworks
find YourApp.app -name "*.framework" -o -name "*.dylib" | while read f; do
  codesign --force --options runtime --timestamp \
    --sign "Developer ID Application: Your Name" "$f"
done
```

### Gatekeeper Rejections

When users see "Apple cannot check it for malicious software":

```bash
# Check Gatekeeper assessment
spctl --assess --type execute --verbose YourApp.app

# For detailed rejection info
spctl -a -vv -t execute YourApp.app

# Verify notarization
spctl --assess --type execute \
  --context context:primary-signature YourApp.app
```

## Part 7: Advanced Debugging Techniques

### Systematic Debugging Workflow

Create this debugging script for comprehensive checks:

```bash
#!/bin/bash
APP_PATH="$1"

echo "=== Certificate Validation ==="
security find-identity -v -p codesigning | grep "Developer ID"

echo -e "\n=== Code Signature Check ==="
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo -e "\n=== Signature Details ==="
codesign -dvv "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Timestamp"

echo -e "\n=== Gatekeeper Assessment ==="
spctl --assess --verbose --type execute "$APP_PATH"

echo -e "\n=== Notarization Status ==="
xcrun stapler validate "$APP_PATH"

echo -e "\n=== Entitlements ==="
codesign -d --entitlements :- "$APP_PATH"
```

### Framework-Specific Issues

**Sparkle Framework:**
```bash
# Sign Autoupdate app first
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name" \
  "YourApp.app/Contents/Frameworks/Sparkle.framework/Versions/A/Resources/Autoupdate.app"

# Then sign Sparkle framework
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name" \
  "YourApp.app/Contents/Frameworks/Sparkle.framework"
```

**Qt Framework Issues:**
- Remove .prl files from framework root
- Fix symlink structure
- Sign from inside out

## Part 8: Maintaining Signing Across Updates

### Best Practices for Updates

1. **Never change bundle identifiers** - this breaks the update chain
2. **Maintain consistent Team IDs** across all releases
3. **Use secure timestamps** on all signatures
4. **Sign components individually** in the correct order:
   - Nested frameworks and dylibs
   - Helper applications
   - XPC services
   - Main application bundle

### Version Management

Keep your version numbers synchronized:

```xml
<!-- Info.plist -->
<key>CFBundleShortVersionString</key>
<string>2.1.0</string>
<key>CFBundleVersion</key>
<string>2100</string>
```

## Part 9: Development vs Distribution Signing

### Development Signing Configuration

For development builds:
- Use "Mac Developer" certificates
- Enable `com.apple.security.get-task-allow` for debugging
- Can skip notarization
- Works only on registered devices

### Distribution Signing Configuration

For release builds:
- Use "Developer ID Application" certificates
- Enable hardened runtime with `--options runtime`
- Must complete notarization
- No debug entitlements allowed

### Switching Between Configurations

In Xcode, use different build configurations:

```
// Debug configuration
CODE_SIGN_IDENTITY[config=Debug] = Mac Developer
CODE_SIGN_IDENTITY[config=Release] = Developer ID Application: Your Name (TEAM_ID)
```

## Part 10: Handling Different App Types

### Helper Applications

Place helper apps in `Contents/Library/LaunchServices/`:

```bash
# Sign helper first
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name" \
  "YourApp.app/Contents/Library/LaunchServices/com.company.helper"
```

### Launch Daemons and Agents

For privileged helpers using SMJobBless:

```xml
<!-- Daemon plist -->
<key>Label</key>
<string>com.company.helper</string>
<key>Program</key>
<string>/Library/PrivilegedHelperTools/com.company.helper</string>
```

### XPC Services

Sign XPC services with the same identity:

```bash
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name" \
  "YourApp.app/Contents/XPCServices/com.company.service.xpc"
```

## Part 11: Required Entitlements

### Camera and Microphone Access

```xml
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>

<!-- Info.plist additions -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for audio recording</string>
```

### Network Access

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

### File System Access

```xml
<!-- User-selected files -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Downloads folder -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

### Hardened Runtime Exceptions

Use sparingly and only when necessary:

```xml
<!-- For JIT compilation -->
<key>com.apple.security.cs.allow-jit</key>
<true/>

<!-- For loading third-party plugins -->
<key>com.apple.security.cs.disable-library-validation</key>
<true/>

<!-- For apps using interpreted languages -->
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

## Part 12: Testing Before Distribution

### Complete Testing Checklist

1. **Clean system test**: Use a fresh macOS installation or new user account
2. **Download simulation**: Add quarantine attribute to test Gatekeeper
3. **Offline verification**: Disconnect internet and verify stapled ticket works
4. **Update testing**: Verify updates work with previous version

### Automated Testing Script

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
xattr -w com.apple.quarantine "0081;$(date +%s);Safari;" "$APP"
spctl --assess --type execute "$APP" || exit 1

echo "4. Testing DMG..."
hdiutil attach "$DMG" -nobrowse
cp -R "/Volumes/YourApp/$APP" "/tmp/"
hdiutil detach "/Volumes/YourApp"
spctl --assess --type execute "/tmp/$APP" || exit 1

echo "✅ All distribution tests passed!"
```

## Part 13: Recent macOS Changes

### macOS 15 Sequoia Changes

The most significant change in macOS 15 is the **removal of the Gatekeeper bypass**. Users can no longer right-click and select "Open" to bypass unsigned app warnings. Instead, they must:

1. Try to open the app (it will be blocked)
2. Go to System Settings → Privacy & Security
3. Click "Open Anyway" next to the app name
4. Confirm in the dialog

### Privacy Manifest Requirements (2024)

Starting Spring 2024, apps must include privacy manifests:

```xml
<!-- PrivacyInfo.xcprivacy -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
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

## Quick Reference: Complete Workflow

```bash
# 1. Sign the app
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  YourApp.app

# 2. Create distribution package
ditto -c -k --keepParent YourApp.app YourApp.zip

# 3. Submit for notarization
xcrun notarytool submit YourApp.zip \
  --keychain-profile "notary-profile" \
  --wait

# 4. Create DMG
hdiutil create -volname "YourApp" -srcfolder YourApp.app \
  -ov -format UDZO YourApp.dmg

# 5. Sign and notarize DMG
codesign -s "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp YourApp.dmg
xcrun notarytool submit YourApp.dmg \
  --keychain-profile "notary-profile" --wait

# 6. Staple ticket
xcrun stapler staple YourApp.dmg

# 7. Verify
spctl --assess --type open --context context:primary-signature \
  --verbose YourApp.dmg
```

## Conclusion

Successfully distributing macOS apps outside the Mac App Store requires attention to detail at every step. The most critical points to remember are: always use `ditto` for ZIP creation, enable hardened runtime for all distribution builds, sign all components individually from inside out, complete the notarization process, and thoroughly test on clean systems before release. With macOS security requirements becoming stricter with each release, following these practices ensures your users have a smooth installation experience while maintaining the security that macOS users expect.