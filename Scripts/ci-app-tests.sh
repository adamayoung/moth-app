#!/bin/bash
# Run MothTests on CI once the runner reaches the deployment target. xcodebuild
# refuses to test on an older host, and until then a green check must not read
# as covering them, so this warns and passes. See docs/testing.md, "Continuous
# Integration".
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

host=$(sw_vers -productVersion)
target=$(sed -n 's/^MACOSX_DEPLOYMENT_TARGET = //p' Configs/Shared.xcconfig)

for version in "$host" "$target"; do
    if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        echo "error: cannot compare macOS versions: host '$host', deployment target '$target'" >&2
        exit 1
    fi
done

is_older() {
    local -a left right
    local index
    IFS=. read -ra left <<< "$1"
    IFS=. read -ra right <<< "$2"
    for index in 0 1 2; do
        if ((10#${left[index]:-0} != 10#${right[index]:-0})); then
            ((10#${left[index]:-0} < 10#${right[index]:-0}))
            return
        fi
    done
    return 1
}

if is_older "$host" "$target"; then
    reason="runner macOS $host is below the deployment target $target"
    echo "Runner macOS $host, deployment target $target: MothTests will not run."
    echo "::warning title=MothTests not run::MothTests did not run: $reason."
    echo "\`MothTests\` did not run: $reason. Run \`make test\` before merging." >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    exit 0
fi

echo "Runner macOS $host, deployment target $target: running MothTests."
exec make test-unit-unsigned
