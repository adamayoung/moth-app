#!/bin/sh
# Clear a running Moth before a UI run, then run the command given. Only call
# this while holding the build lock: without it, this kills the app another
# run's UI test is driving. See docs/testing.md, "The Build Lock".
#
# Usage: Scripts/clear-stale-moth.sh --check-only
#        Scripts/clear-stale-moth.sh <command...>
#
# --check-only refuses a Moth under the debugger and signals nothing, so it is
# safe before the lock is held.
set -eu

app="${MOTH_APP_PROCESS:-Moth}"
term_grace_seconds=5

running=$(pgrep -x "$app" || true)

# ps reports state X for a traced process. A signal cannot stop one, and a UI
# run around it hangs every test at "Terminate".
for pid in $running; do
    case "$(ps -o state= -p "$pid" || true)" in
    *X*)
        echo "error: $app (pid $pid) is running under the Xcode debugger; stop it in Xcode, then run this again" >&2
        exit 1
        ;;
    esac
done

if [ "${1:-}" = "--check-only" ]; then
    exit 0
fi

for pid in $running; do
    kill "$pid" 2>/dev/null || continue
    waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$term_grace_seconds" ]; do
        sleep 1
        waited=$((waited + 1))
    done
    kill -9 "$pid" 2>/dev/null || true
    echo "killed stale $app (pid $pid) before the UI run"
done

exec "$@"
