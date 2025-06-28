#!/bin/bash
set -eo pipefail

#================================================================================
# HYPERCHAT RELEASE SCRIPT
#
# This script automates the entire release process for HyperChat.
# It performs the following steps:
#   1. Bumps the build number.
#   2. Archives the app using release configuration.
#   3. Exports the app from the archive.
#   4. Zips the app for notarization.
#   5. Submits the app to Apple's notary service.
#   6. Staples the notarization ticket to the app.
#   7. Zips the final, stapled app for distribution.
#   8. Signs the distribution zip for Sparkle updates.
#   9. Generates the final appcast.xml item.
#
# USAGE:
#   ./configure-release-build.sh "1.0.1"
#
# PREREQUISITES:
#   1. Set the configuration variables below.
#   2. Your Apple ID & app-specific password must be stored in the keychain:
#      `xcrun notarytool store-credentials "hyperchat-notary-profile" --apple-id "your-apple-id@example.com" --password "your-app-specific-password"`
#================================================================================

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# CONFIGURE THESE VARIABLES
# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

# The "marketing" version number you're releasing. Pass this as the first argument to the script.
# Example: "1.0.1"
VERSION_STRING="$1"

# Your Developer ID Application certificate. Find this in Keychain Access.
# Example: "Developer ID Application: Your Company (XXXXXXXXXX)"
DEVELOPER_ID_CERT="Developer ID Application: Matt Mireles ($(APPLE_TEAM_ID))"

# The name of the keychain profile you created for notarytool.
# SEE "PREREQUISITES" section above for instructions.
NOTARY_KEYCHAIN_PROFILE="hyperchat-notary-profile"

# Path to your Sparkle private key.
# IMPORTANT: Keep this file secure and out of source control.
SPARKLE_PRIVATE_KEY_PATH="${HOME}/.keys/sparkle_ed_private_key.pem"

# Project configuration
PROJECT_NAME="Hyperchat.xcodeproj"
SCHEME_NAME="Hyperchat"

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# SCRIPT LOGIC (No need to edit below this line)
# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

if [[ -z "$VERSION_STRING" ]]; then
    echo "❌ Error: No version number provided."
    echo "Usage: ./configure-release-build.sh \"1.0.1\""
    exit 1
fi

echo "🚀 Starting release process for HyperChat v${VERSION_STRING}"

# 1. VERSIONING
# ==============================================================================
echo "1/8: Bumping build number..."
BUILD_NUMBER=$(agvtool next-version -all)
echo "  ✅ New build number: ${BUILD_NUMBER}"

# 2. ARCHIVE
# ==============================================================================
echo "2/8: Archiving the application..."
ARCHIVE_PATH="./build/Hyperchat-${VERSION_STRING}.xcarchive"
xcodebuild -project "${PROJECT_NAME}" \
           -scheme "${SCHEME_NAME}" \
           -sdk macosx \
           -configuration Release \
           -archivePath "${ARCHIVE_PATH}" \
           archive \
           | xcpretty

echo "  ✅ Archive created at: ${ARCHIVE_PATH}"

# 3. EXPORT FROM ARCHIVE
# ==============================================================================
echo "3/8: Exporting app from archive..."
EXPORT_DIR="./build/export"
rm -rf "${EXPORT_DIR}" # Clean previous export
mkdir -p "${EXPORT_DIR}"

xcodebuild -exportArchive \
           -archivePath "${ARCHIVE_PATH}" \
           -exportPath "${EXPORT_DIR}" \
           -exportOptionsPlist "ExportOptions.plist" \
           | xcpretty

EXPORTED_APP_PATH="${EXPORT_DIR}/Hyperchat.app"
echo "  ✅ App exported to: ${EXPORTED_APP_PATH}"

# 4. PACKAGE FOR NOTARIZATION
# ==============================================================================
echo "4/8: Compressing app for notarization..."
NOTARIZATION_ZIP_PATH="./build/Hyperchat-notarization-temp.zip"
ditto -c -k --rsrc --sequesterRsrc --keepParent "${EXPORTED_APP_PATH}" "${NOTARIZATION_ZIP_PATH}"
echo "  ✅ Temporary zip for notarization created at: ${NOTARIZATION_ZIP_PATH}"

# 5. SUBMIT FOR NOTARIZATION
# ==============================================================================
echo "5/8: Submitting for notarization..."
xcrun notarytool submit "${NOTARIZATION_ZIP_PATH}" \
    --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}" \
    --wait
echo "  ✅ Notarization successful."

# 6. STAPLE THE TICKET
# ==============================================================================
echo "6/8: Stapling notarization ticket..."
xcrun stapler staple "${EXPORTED_APP_PATH}"
echo "  ✅ Ticket stapled to ${EXPORTED_APP_PATH}"

# 7. PACKAGE FOR DISTRIBUTION
# ==============================================================================
echo "7/8: Compressing final application..."
ZIP_PATH_DIR="../hyperchat-web/public/"
ZIP_FILE_NAME="Hyperchat-v${VERSION_STRING}-notarized.zip"
ZIP_FILE_PATH="${ZIP_PATH_DIR}${ZIP_FILE_NAME}"

ditto -c -k --rsrc --sequesterRsrc --keepParent "${EXPORTED_APP_PATH}" "${ZIP_FILE_PATH}"
FILE_SIZE=$(stat -f "%z" "${ZIP_FILE_PATH}")
echo "  ✅ App compressed to: ${ZIP_FILE_PATH} (Size: ${FILE_SIZE} bytes)"

# 8. SIGN FOR SPARKLE
# ==============================================================================
echo "8/8: Generating Sparkle update signature..."
if [ ! -f "$SPARKLE_PRIVATE_KEY_PATH" ]; then
    echo "❌ Error: Sparkle private key not found at '${SPARKLE_PRIVATE_KEY_PATH}'"
    exit 1
fi

# Find the sign_update tool from Sparkle binary
SIGN_UPDATE_TOOL_PATH="./DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

if [ ! -f "$SIGN_UPDATE_TOOL_PATH" ]; then
    echo "❌ Error: Sparkle's 'sign_update' tool not found. Please build the project once to ensure dependencies are downloaded."
    exit 1
fi

ED_SIGNATURE=$("${SIGN_UPDATE_TOOL_PATH}" -s "${SPARKLE_PRIVATE_KEY_PATH}" "${ZIP_FILE_PATH}")
echo "  ✅ EdDSA signature generated."

# GENERATE APPCAST
# ==============================================================================
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
DOWNLOAD_URL="https://hyperchat.app/${ZIP_FILE_NAME}"

cat << EOF

🎉 Release process complete!

1. Commit and push your version changes.
   - git commit -am "Release v${VERSION_STRING}"
   - git tag "v${VERSION_STRING}"
   - git push && git push --tags

2. Upload the new ZIP file to your web server.
   - The file is located at: ${ZIP_FILE_PATH}

3. Add the following item to your appcast.xml:

<!--===========================================================================-->

    <item>
      <title>Version ${VERSION_STRING}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION_STRING}</sparkle:shortVersionString>
      <pubDate>${PUB_DATE}</pubDate>
      <description>
        <![CDATA[
          <h2>Hyperchat ${VERSION_STRING}</h2>
          <p>INSERT YOUR RELEASE NOTES HERE.</p>
        ]]>
      </description>
      <link>https://hyperchat.app/release-notes-${VERSION_STRING}.html</link>
      <enclosure url="${DOWNLOAD_URL}"
                 sparkle:edSignature="${ED_SIGNATURE}"
                 length="${FILE_SIZE}"
                 type="application/octet-stream" />
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    </item>

<!--===========================================================================-->

EOF