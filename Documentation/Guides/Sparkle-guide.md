# Independent macOS Distribution with Sparkle

### Field Guide (Compact 2025 Edition)

> **Purpose**  A concise, step‑by‑step reference for shipping and auto‑updating a notarized Mac app outside the App Store.

---

## 1 · Why Sparkle?

* Immediate release cycles—no App Store review lag.
* Works with apps the Store rejects (privileged helpers, plug‑ins, non‑sandbox tools).
* Mature, MIT‑licensed, battle‑tested since 2006.

---

## 2 · Prerequisites

| Requirement             | Minimum              | Notes                                          |
| ----------------------- | -------------------- | ---------------------------------------------- |
| Xcode                   | 15 or later          | Enables modern notarization **notarytool**     |
| macOS SDK               | 14 (Sonoma) or later | Required for Hardened Runtime                  |
| Apple Developer Program | \$99 / yr            | Gives **Developer ID** certs                   |
| Sparkle                 | 2.7.1 (Dec 2024)     | EdDSA‑only, Apple Archive support              |
| HTTPS web host          | TLS 1.2+             | GitHub Releases + Pages, S3 + CloudFront, etc. |

---

## 3 · Quick‑Start (10 Commands)

1. **Add Sparkle** → Xcode ▸ *File › Add Packages…* → `https://github.com/sparkle-project/Sparkle`.
2. **Generate keys** \`\`\`bash
   ./bin/generate\_keys      # prints public key, stores private key in Keychain

````
3. **Embed keys + feed** in *Info.plist*:
```xml
<key>SUFeedURL</key>          <string>https://example.com/appcast.xml</string>
<key>SUPublicEDKey</key>      <string>BASE64…</string>
<key>SUEnableAutomaticChecks</key><true/>
````

4. **Instantiate updater** (AppDelegate or SwiftUI singleton):

```swift
let updater = SPUStandardUpdaterController(startingUpdater: true,
                                           updaterDelegate: nil,
                                           userDriverDelegate: nil)
```

5. **Sign & harden** build:

```bash
codesign --deep --force --options runtime --timestamp \
  --sign "Developer ID Application: ACME (TEAMID)" MyApp.app
```

6. **Archive & notarize**:

```bash
xcodebuild -scheme MyApp -configuration Release archive -archivePath build/MyApp.xcarchive
xcrun notarytool submit build/MyApp.zip --keychain-profile notary --wait
xcrun stapler staple MyApp.app
```

7. **Package** the notarized *.app* → `zip` or `create-dmg`.
8. **Generate appcast + signatures**:

```bash
./bin/generate_appcast ~/updates/
```

9. **Upload** `appcast.xml` + archives + deltas to HTTPS host.
10. **Ship** ✈️  Users auto‑update!

---

## 4 · Security Triad at a Glance

| Layer         | Tooling                                  | Fatal‑if‑missing symptom                       |
| ------------- | ---------------------------------------- | ---------------------------------------------- |
| Code signing  | `codesign --options runtime --timestamp` | “App is damaged and can’t be opened.”          |
| Notarization  | `notarytool submit …` → `stapler`        | Gatekeeper blocks even signed app              |
| Sparkle EdDSA | `generate_appcast` signature             | Sparkle dialog: “Update is improperly signed.” |

> **Tip:** Keep private EdDSA key in an encrypted password manager or HSM—never in git.

---

## 5 · Release Pipeline Checklist (Copy‑Paste)

1. Bump **Marketing Version** & **Build Number** in Xcode.
2. Clean build → Archive.
3. Re‑sign embedded **Sparkle.framework** in a post‑build Run Script:

   ```bash
   codesign --deep --force -o runtime --sign "$EXPANDED_CODE_SIGN_IDENTITY_NAME" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/Sparkle.framework"
   ```
4. Notarize archive; wait for success.
5. Export notarized app, compress to *.zip*.
6. Run `generate_appcast` (creates signature + deltas).
7. Upload *.zip*, deltas, and **appcast.xml** via HTTPS.
8. PURGE CDN cache for the new file URLs.
9. Test live update with a release build.
10. Tag release in git / GitHub.

---

## 6 · Troubleshooting Cheat‑Sheet

| Symptom (Console / UI)             | Likely Cause                                 | Fix                                                                   |
| ---------------------------------- | -------------------------------------------- | --------------------------------------------------------------------- |
| `Update is improperly signed`      | Cached old *.zip* or key mismatch            | Purge CDN; confirm `SUPublicEDKey` vs `generate_keys`                 |
| `ATS: didFailWithError`            | HTTP or weak TLS                             | Serve over HTTPS TLS 1.2+                                             |
| `DENY mach‑lookup …spks`           | Sandbox lacks XPC entitlement                | Add temporary‑exception plist keys + enable Sparkle installer service |
| Notarization “no hardened runtime” | Missing `--options runtime` on nested binary | Deep‑sign Sparkle.framework + helpers                                 |

---

## 7 · Sandbox & XPC

* Add **Outgoing Network Connections (Client)** entitlement *or* set `SUEnableDownloaderService`.
* For install step, include:

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

* Test the **archived, notarized** build—debug builds mask sandbox violations.

---

## 8.5 · Edge‑Case Playbook

| Scenario                      | Symptom                                          | One‑liner Fix                                                                                           |
| ----------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| **DSA→EdDSA migration**       | Legacy users on Sparkle 1.x can’t verify updates | Ship an interim release signed with **both** algorithms; drop DSA next cycle                            |
| **App Translocation**         | Updates fail when app is run from Downloads      | Ship signed DMG, detect translocation (`contains "/AppTranslocation/"`) and prompt drag‑to‑Applications |
| **Time‑skew notarization**    | `notarytool` error: timestamp outside range      | Sync CI clock with NTP before `codesign`                                                                |
| **CDN serving stale zip**     | “Update is improperly signed” for some regions   | Purge edge cache or use version‑hashed filenames                                                        |
| **Proxy blocking TLS 1.3**    | Feed reachable in browser, Sparkle errors        | Allow TLS 1.2; test with `nscurl --ats-diagnostics`                                                     |
| **Apple Silicon mis‑arch**    | Intel build offered to M‑series Macs             | Add `sparkle:arch="arm64"` or ship Universal 2 binary                                                   |
| **Privileged helper unloads** | Helper fails to load post‑update                 | Bump helper bundle ID & CFBundleVersion; reinstall via SMAppService                                     |
| **Offline installs**          | Gatekeeper warns despite stapled app             | Staple both app **and** pkg/zip; keep `--staple` in pipeline                                            |
| **Firewall DPI**              | Feed blocked inside corp network                 | Serve appcast on 443, ensure ALPN fallback                                                              |
| **Large delta > 2 GB**        | Patch apply aborts                               | Skip deltas above 70 % size; ship full zip                                                              |
| **Entitlements regression**   | CI build drops network entitlement               | Add codesign entitlement check script, fail CI if missing                                               |

## 8 · Advanced

### Delta Updates

* Enabled by default via `generate_appcast` when prior archives present.
* Skip if patch > 70 % of full download.

### Paid Upgrades

1. Final v1 release: informational update (`sparkle:informationalUpdate`) pointing to v2 page.
2. Or separate feed URLs per major version.

### Release Notes UX

* Use `<sparkle:releaseNotesLink>` → HTML page.
* Structure: 🚀 New, ✨ Improvements, 🐛 Fixes; lead with TL;DR.

---

## 9 · Hosting Patterns

| Scale             | Good Choice             | Notes                |
| ----------------- | ----------------------- | -------------------- |
| Indie / OSS       | GitHub Releases + Pages | Free, trivial HTTPS  |
| Growing user‑base | S3 + CloudFront         | Cache bust + metrics |
| Enterprise        | Own domain + CDN        | Pin cert, DDOS guard |

---

## 10 · References & Next Steps

* Sparkle docs: [https://sparkle-project.org/documentation/](https://sparkle-project.org/documentation/)
* Apple notarization guide: [https://developer.apple.com/documentation/security/notarizing\_macos\_software\_before\_distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
* Example CI: *sparkle‑cli‑action* on GitHub.

> **Need help?** Drop a Console.log excerpt or the exact `notarytool` failure message.

