#!/bin/sh
# Delete the ~/Library/Developer/Xcode/DerivedData/Moth-<hash> folders built
# for a worktree's project. `make` builds into the worktree's own DerivedData,
# but opening the worktree in Xcode (or the Xcode MCP) creates one there, and
# it outlives the worktree.
#
# Usage: Scripts/remove-worktree-derived-data.sh <worktree-path>
set -eu

worktree=$(cd "${1:?usage: $0 <worktree-path>}" && pwd)
resolved=$(cd "$worktree" && pwd -P)

derived_data="${XCODE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"

for folder in "$derived_data"/Moth-*; do
    [ -f "$folder/info.plist" ] || continue
    workspace=$(/usr/libexec/PlistBuddy -c "Print :WorkspacePath" "$folder/info.plist" 2>/dev/null || true)
    # Xcode records the path as opened, so /tmp/x stays /tmp/x, not /private/tmp/x.
    if [ "$workspace" = "$worktree/Moth.xcodeproj" ] || [ "$workspace" = "$resolved/Moth.xcodeproj" ]; then
        echo "removing $folder"
        rm -rf "$folder"
    fi
done
