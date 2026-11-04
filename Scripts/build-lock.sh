#!/bin/sh
# Run a command while holding the machine-wide xcodebuild lock, so builds queue
# across every checkout and worktree. See docs/testing.md, "The Build Lock".
#
# Usage: [MOTH_BUILD_LOCK_LABEL="test UnitTests"] Scripts/build-lock.sh <command...>
set -eu

# Not TMPDIR: it differs between sessions, which would give each its own lock.
lock="${MOTH_BUILD_LOCK:-/tmp/moth-xcodebuild.lock}"
holder="$lock.holder"
label="${MOTH_BUILD_LOCK_LABEL:-$1 ${2:-}}"

# shlock also exits 1 for this, which would otherwise read as "held" for ever.
if [ ! -w "$(dirname "$lock")" ]; then
    echo "error: cannot create the xcodebuild lock at $lock" >&2
    exit 1
fi

# The lock goes last: the next run takes it at once and writes its own holder file.
release() {
    rm -f "$holder" "$lock"
}

polls=0
until shlock -f "$lock" -p $$ 2>/dev/null; do
    if [ $((polls % 5)) -eq 0 ]; then
        echo "waiting for the xcodebuild lock (held by pid $(cat "$lock" 2>/dev/null): $(cat "$holder" 2>/dev/null))..."
    fi
    polls=$((polls + 1))
    # shlock refuses a stale lock modified in the last second, so it needs asking again.
    sleep 1
done

trap release EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo "$label in $PWD" > "$holder"

"$@"
