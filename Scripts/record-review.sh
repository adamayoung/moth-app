#!/bin/bash
#
# Record that HEAD has been reviewed, so .claude/hooks/require-review-before-push.py
# lets its branch be pushed and its pull request opened.
#
# Run it after the review's fixes are committed. A later commit has no marker,
# so it needs another review. The marker lives in the repository's shared git
# directory, which every worktree sees and nothing commits.
#
# Usage: Scripts/record-review.sh

set -euo pipefail

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "record-review: commit or discard the uncommitted changes first; the marker names HEAD." >&2
    exit 1
fi

commit=$(git rev-parse --verify HEAD)
markers="$(git rev-parse --path-format=absolute --git-common-dir)/moth-reviewed"
mkdir -p "$markers"
date -u +%Y-%m-%dT%H:%M:%SZ > "$markers/$commit"
echo "Recorded the review of $(git rev-parse --abbrev-ref HEAD) at ${commit:0:12}."
