#!/bin/sh
# Run `xcodebuild test` and report how many tests ran, failing a run that ran
# none: xcodebuild prints ** TEST SUCCEEDED ** and exits 0 when a filter matches
# nothing. Run this under the build lock, or a queued run can delete the bundle.
#
# Usage: Scripts/run-xcode-tests.sh <result-bundle> <xcodebuild arguments...>
set -eu

bundle="$1"
shift

rm -rf "$bundle"

status=0
xcodebuild test "$@" -resultBundlePath "$bundle" || status=$?

fail_uncounted() {
    echo "error: $1" >&2
    exit $((status == 0 ? 1 : status))
}

if [ ! -d "$bundle" ]; then
    fail_uncounted "xcodebuild left no result bundle at $bundle, so no tests can be counted"
fi

count=$(xcrun xcresulttool get test-results summary --path "$bundle" --compact |
    jq -r '.totalTestCount - .skippedTests' 2>/dev/null) || count=""

case "$count" in
"" | *[!0-9]*)
    fail_uncounted "could not read a test count from $bundle"
    ;;
esac

echo "Ran $count test(s)."

if [ "$status" -eq 0 ] && [ "$count" -eq 0 ]; then
    echo "error: no tests ran; check the filter (Swift Testing functions need a trailing ())" >&2
    status=1
fi

exit "$status"
