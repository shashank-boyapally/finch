#!/bin/bash
set -o errexit
set -o pipefail

#$1: the account name
#$2: the credential
cd ./installer-builder/output/installer/signed/Payload
ditto -c -k --sequesterRsrc --keepParent Finch.pkg Finch.zip
xcrun notarytool submit Finch.zip --apple-id "${1}" --password "${2}" --team-id 94KV3E626L --wait | tee /tmp/notarization-output.log

# validate notarization result
if grep -q "status: Accepted" /tmp/notarization-output.log; then
    echo "Notarization successful"
else
    echo "Notarization failed"
    exit 1
fi

# Staple the ticket to the .pkg. Without it, pkgutil/spctl have to look the ticket up
# online, which is not reliable right after it is issued, so the installer verification
# in test-pkg.yaml fails intermittently and end users need network access to install.
# The ticket can take a few seconds to become retrievable after notarytool reports
# Accepted, so retry before giving up.
attempts=0
until xcrun stapler staple Finch.pkg; do
    attempts=$((attempts+1))
    if [ $attempts -ge 5 ]; then
        echo "Stapling failed after $attempts attempts."
        exit 1
    fi
    echo "Wait 30 seconds and retry..."
    sleep 30
done

xcrun stapler validate Finch.pkg
echo "Stapling successful"
