# Sparkle EdDSA Key Debugging Notes - Failed Attempts & Lessons

## Original Issues
1. "Check for Updates" gave no user feedback when clicked
2. Error: "The EdDSA public key is not valid for Hyperchat"

## What We Tried (And What Failed)

### Attempt 1: Initial Key Sync Approach
**What we tried**: Run the existing sync script `Scripts/sync-sparkle-keys.sh`
**Result**: Script ran silently, appeared to work
**What actually happened**: Keys were still mismatched, error persisted
**Why it failed**: The script was syncing file→Info.plist, but we had multiple key sources

### Attempt 2: Regenerate Keys from Scratch  
**What we tried**: Delete private key file and run `generate_keys` to create fresh keys
```bash
rm ~/.keys/sparkle_ed_private_key.pem
./DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```
**Result**: Tool said "A pre-existing signing key was found" and showed same keychain key
**What actually happened**: Keychain still had old key, generate_keys didn't create new ones
**Why it failed**: generate_keys doesn't overwrite existing keychain entries

### Attempt 3: Export Keychain Key to File
**What we tried**: Use `-x` flag to export keychain private key to file
```bash
rm ~/.keys/sparkle_ed_private_key.pem
./bin/generate_keys -x ~/.keys/sparkle_ed_private_key.pem
```
**Result**: Export appeared to complete, but file contained old data
**What actually happened**: File wasn't actually overwritten with keychain key
**Why it failed**: Export command seems buggy or doesn't work as expected

### Attempt 4: Force Keychain Key into Info.plist
**What we tried**: Manually update Info.plist with keychain public key
- Keychain key: `YOUR_SPARKLE_PUBLIC_KEY_HERE=`
- Updated Info.plist manually
**Result**: Build failed because sync script detected mismatch
**What actually happened**: Sync script reverted Info.plist back to file-derived key
**Why it failed**: Sync script uses file as source of truth, overrode our manual change

### Attempt 5: Delete Keychain Entries
**What we tried**: Remove keychain entries to clean slate
```bash
security delete-generic-password -s "Private key for signing Sparkle updates"
security delete-generic-password -a ed25519 -s "Private key for signing Sparkle updates"
```
**Result**: Commands said "No existing keychain entry found"
**What actually happened**: Couldn't find the keychain entries to delete
**Why it failed**: Keychain entries might be stored differently than expected

### Attempt 6: Find Hidden Keychain Entries
**What we tried**: Search for any Sparkle-related keychain entries
```bash
security find-generic-password -D "application password" | grep -i sparkle
security dump-keychain | grep -i sparkle
```
**Result**: No entries found, but `generate_keys -p` still returned a key
**What actually happened**: Key exists somewhere we can't find/access
**Why it failed**: Keychain storage more complex than simple security commands reveal

## What Actually Worked (The Pragmatic Solution)

**Final approach**: Accept that we have multiple key sources and make file authoritative
1. Keep existing private key file: `~/.keys/sparkle_ed_private_key.pem`
2. Let sync script update Info.plist from file during build
3. This gives consistent file→Info.plist sync
4. Added user feedback dialogs for update check results

**Why this worked**: 
- Sync script already designed for file-as-source workflow
- Avoids fighting with mysterious keychain behavior
- Gets keys consistent even if we don't understand all sources

## Key Debugging Commands That Actually Helped

```bash
# Compare all three key sources
echo "Keychain public key:"
./DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -p

echo "File-derived public key:"  
./DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update -p ~/.keys/sparkle_ed_private_key.pem

echo "Info.plist public key:"
/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" Info.plist
```

This showed us we had 3 different keys, which was the core problem.

## Lessons from Failed Attempts

### Sparkle's generate_keys Tool is Confusing
- `-x` export flag doesn't seem to work reliably  
- Tool reports "pre-existing key" but you can't easily find/manage that key
- Keychain integration is opaque and hard to debug

### Keychain Management is Tricky
- Standard security commands couldn't find Sparkle's keychain entries
- Sparkle stores keys in non-obvious keychain locations
- Deleting entries didn't work as expected

### Multiple Sources = Confusion
- Having keychain + file + Info.plist created 3-way mismatch
- Sync script only handles file→Info.plist, ignores keychain
- Manual changes get overridden by sync script

### Build Process Complexity
- Sync script runs during build, can revert manual changes
- Must understand build-time vs runtime key usage
- File permissions and existence matter for build scripts

## What to Try Next Time

1. **Start with key investigation**: Compare all sources first
2. **Pick one authoritative source**: Don't fight multiple sources
3. **Understand the sync workflow**: Read the sync script before changing keys
4. **Test build process**: Manual changes might get reverted by build scripts
5. **Focus on working solution**: Don't get stuck on "clean" approaches

## The Weird Keychain Mystery

We never figured out:
- Where exactly Sparkle stores keychain keys
- Why `generate_keys -x` export didn't work
- How to properly delete/reset keychain keys
- Why security commands couldn't find the entries

But we didn't need to solve this to fix the actual problem.

---

## July 16, 2025 - FINAL RESOLUTION

### The Real Problem (Finally Understood)

After the "pragmatic solution" above worked temporarily, the error returned because **the appcast.xml on the server was signed with the keychain key**, not the file key. This created a persistent mismatch:

- **App expects**: `rcWwv2W5b6l9pnJdueL18VAGyHzS16fcgXfNmmV9vF1NasUk7zYYbUY+EJsBCbU3gFIlxeoBP66y2FBP23pfCg==` (from file)
- **Server appcast signed with**: `YOUR_SPARKLE_PUBLIC_KEY_HERE=` (from keychain)

### The Actual Fix (Simple & Correct)

**Don't fight the keychain. Trust your deployment process.**

```bash
# 1. Restore clean state (this reverted Info.plist to keychain key)
git restore Info.plist

# 2. Run sync script (this updated Info.plist to file key)  
./Scripts/sync-sparkle-keys.sh

# 3. Run deployment script (this generates new appcast with correct signature)
./Scripts/deploy-hyperchat.sh
```

### Why This Actually Fixes It

1. **Sync script** ensures Info.plist matches the private key file
2. **Deployment script** detects key consistency and proceeds
3. **New appcast.xml** gets generated with signature matching the app's expected key
4. **Server upload** replaces the mismatched appcast with correct one

### Key Insight: Server-Side Problem

The recurring error wasn't a local key management issue - it was a **server-side signature mismatch**. The deployment script fixes this by generating a fresh appcast.xml signed with the correct key and uploading it.

### Lesson Learned

**When Sparkle says "EdDSA public key is not valid":**
- Don't fight the keychain
- Don't regenerate keys
- **Check if your appcast signature matches your app's key**
- Use your deployment script to generate a fresh, correctly-signed appcast

The deployment approach trusts the robust, battle-tested process rather than trying to wrangle Sparkle's opaque keychain behavior.

---

## July 16, 2025 - THE CRITICAL BUG DISCOVERED & PERMANENTLY FIXED

### The REAL Root Cause (Finally!)

The "simple fix" above worked but wasn't durable. The error kept recurring because there was a **critical timing bug** in the deployment script:

**❌ BROKEN SEQUENCE:**
1. Generate EdDSA signature for DMG 
2. Notarize DMG
3. **Staple notarization ticket** ← **This modifies the DMG file!**
4. Deploy appcast with signature from step 1 ← **Wrong signature!**

**✅ CORRECT SEQUENCE:**  
1. Notarize DMG
2. Staple notarization ticket  
3. **Generate EdDSA signature** ← **Now the signature matches the final DMG**
4. Deploy appcast with correct signature

### The Evidence

**Before fix** (signatures for same DMG):
- Pre-stapling: `y3BOwzPWe4DLBm/eG0n/u6a7wAhURYpBeNZthFr5KtAuYcs2Q8uZzswfS3u6Goc5Xl5WyN4thqI3Q0Lqu5hiAw==` (6201085 bytes)
- Post-stapling: `VsdO6tujUVaZIjhetitmQ58GdwSmbcsJzjw+wHnu+ulyd+IyvgJZChI5jttlYFi/xdhKwxKZ9ZCsEwUjWmSEBg==` (6202986 bytes)

Stapling changes the DMG by ~1900 bytes, completely invalidating any signature generated before stapling!

### The Bulletproof Fix

**1. Fixed the timing in `deploy-hyperchat.sh`:**
```bash
# OLD: Step 9.5 - Generate signature (WRONG - before stapling)
# NEW: Step 12.5 - Generate signature (CORRECT - after stapling)
```

**2. Added comprehensive validation:**
- Explicit private key file validation to prevent keychain fallback
- `set -x` debugging for full command visibility  
- Post-deploy signature verification with cache-busting
- Fail-fast error detection

**3. Made it regression-proof:**
- Script automatically validates deployed signatures match expected
- CDN cache handling with clear instructions
- All signature generation logged and verified

### Code Changes Made

**File: `Scripts/deploy-hyperchat.sh`**
- Moved EdDSA signature generation from Step 9.5 to Step 12.5 (after stapling)
- Added explicit key file validation with `[[ -f "$SPARKLE_PRIVATE_KEY" ]]`
- Added `set -x` debugging around critical signing operations
- Fixed post-deploy validation to compare actual signatures vs public keys
- Added CDN purge reminders and troubleshooting

### Verification Commands

```bash
# Test the exact same DMG with different timing:
echo "Pre-stapling signature:"
./bin/sign_update Hyperchat-b71.dmg ~/.keys/sparkle_ed_private_key.pem

# ... after stapling ...
echo "Post-stapling signature:"  
./bin/sign_update Hyperchat-b71.dmg ~/.keys/sparkle_ed_private_key.pem
# ↑ These will be completely different!
```

### Final Status: PERMANENTLY RESOLVED ✅

- **v1.5.0 (Build 71)** deployed with correct post-stapling signature
- **Deployment script** now generates signatures at the correct time
- **Automatic validation** prevents future regressions
- **"Check for Updates" works** without EdDSA errors

### The Ultimate Lesson

**Never generate Sparkle EdDSA signatures before notarization stapling.** 

Stapling modifies the DMG file, so any signature generated before stapling will be invalid. The deployment script now enforces this correct sequence and validates the results.

This was the missing piece that made all previous "fixes" temporary. Now it's bulletproof.

---

*July 16, 2025 - Complete debugging session notes & permanent resolution*