#!/bin/bash
#
# Comment ratio of every changed Swift file, against its own baseline.
#
# A rising ratio is the signal `file_length` gives too late and misattributes.
# There is no absolute threshold on purpose: some files are legitimately 40%
# comment. What matters is whether your change made a file more comment than
# it was.
#
# Usage: Scripts/comment-ratio.sh [base-ref]   (default: main)

set -uo pipefail

base="${1:-main}"
flagged=0

ratio() {
    # Skips the licence header, which is the same 6 lines in every file and
    # would otherwise dominate the ratio of a short one.
    awk 'NR > 6 { total++; if ($0 ~ /^[[:space:]]*\/\//) comment++ }
         END { if (total > 0) printf "%d", comment * 100 / total; else printf "0" }'
}

while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue

    after=$(ratio < "$file")
    before=$(git show "${base}:${file}" 2>/dev/null | ratio)
    before=${before:-0}
    delta=$((after - before))

    if [ "$delta" -ge 5 ]; then
        printf '  %3d%% -> %3d%%  (+%d)  %s\n' "$before" "$after" "$delta" "$file"
        flagged=$((flagged + 1))
    fi
done < <(git diff --name-only "$base"...HEAD -- '*.swift')

if [ "$flagged" -eq 0 ]; then
    echo "No changed Swift file raised its comment ratio by 5 points or more."
    exit 0
fi

echo
echo "$flagged file(s) above the +5 point mark. Not a failure — a prompt to run"
echo "the deletion tests in .claude/rules/code-comments.md over what you added."
exit 0
