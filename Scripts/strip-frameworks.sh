#!/bin/bash
set -euo pipefail

# Skip framework stripping during Archive builds - Xcode handles signing properly  
if [[ "${ACTION:-}" = "install" ]]; then
    echo "Skipping framework stripping during Archive/Install action (Xcode handles signing)"
    exit 0
fi

echo "Stripping frameworks in ${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

find "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}" -name "*.framework" -print0 | while IFS= read -r -d $'\0' framework
do
    binary="${framework}/Versions/A/$(basename "${framework}" .framework)"
    if [[ -f "${binary}" ]]; then
        echo "Stripping signature from ${binary}"
        codesign --remove-signature "${binary}" || echo "Failed to strip signature from ${binary}, it might not be signed."
    fi
done

echo "Framework stripping complete." 