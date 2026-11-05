#!/bin/bash
# Build every local package for iOS, unsigned. Run this under the build lock.
set -uo pipefail
shopt -s nullglob

cd "$(dirname "$0")/.." || exit 1
repository=$PWD

manifests=(Packages/*/Package.swift)
if [ ${#manifests[@]} -eq 0 ]; then
    echo "error: no packages to build" >&2
    exit 1
fi

failed=0
for manifest in "${manifests[@]}"; do
    package=$(dirname "$manifest")
    name=$(basename "$package")
    echo "=== $name"

    if (cd "$package" && xcodebuild build -scheme "$name" -destination generic/platform=iOS \
        -skipMacroValidation -derivedDataPath "$repository/DerivedData/iOSPackages" CODE_SIGNING_ALLOWED=NO); then
        echo "$name: built for iOS"
    else
        echo "error: $name failed" >&2
        failed=1
    fi
done

exit "$failed"
