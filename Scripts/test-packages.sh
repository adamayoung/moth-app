#!/bin/bash
# Run `swift test` in every local package. swift test exits 0 for an empty test
# target, so a package that ran no tests fails here.
set -uo pipefail
shopt -s nullglob

manifests=(Packages/*/Package.swift)
if [ ${#manifests[@]} -eq 0 ]; then
    echo "no packages to test"
    exit 0
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# XCTest prints one summary per suite level, each repeating the same count.
# Swift Testing prints one line for the whole run.
count_tests() {
    local xctest swift_testing
    xctest=$(grep -aoE 'Executed [0-9]+ tests?' "$log" | awk '$2 > max { max = $2 } END { print max + 0 }')
    swift_testing=$(grep -aoE 'Test run with [0-9]+ tests?' "$log" | awk '{ sum += $4 } END { print sum + 0 }')
    echo $((xctest + swift_testing))
}

failed=0
for manifest in "${manifests[@]}"; do
    package=$(dirname "$manifest")
    name=$(basename "$package")
    echo "=== $name"

    if ! swift test --package-path "$package" 2>&1 | tee "$log"; then
        echo "error: $name failed" >&2
        failed=1
        continue
    fi

    count=$(count_tests)
    if [ "$count" -eq 0 ]; then
        echo "error: $name ran no tests" >&2
        failed=1
    else
        echo "$name: ran $count test(s)"
    fi
done

exit "$failed"
