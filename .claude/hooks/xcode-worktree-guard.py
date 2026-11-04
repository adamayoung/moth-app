#!/usr/bin/env python3
"""PreToolUse hook on the Xcode MCP: from inside a linked git worktree, allow
only calls aimed at a workspace opened on that worktree's own project.

The user's Xcode window (`windowtab-…`) is open on the main checkout, so a call
aimed at it reads the user's files and overwrites them while they work. A
project opened with XcodeOpenWorkspace runs headless as `workspace-…`, and
record-xcode-workspaces.py records the path behind each identifier; the path,
not the identifier, decides. Sessions outside a worktree are not checked.
"""

import json
import os
from pathlib import Path
import subprocess
import sys

REGISTRY_DIRECTORY = "moth-xcode-workspaces"
WORKSPACE_FREE_TOOLS = {"XcodeListWorkspaces", "DocumentationSearch"}


class Refusal(Exception):
    pass


def git(cwd, *arguments):
    try:
        result = subprocess.run(["git", "-C", cwd, *arguments], capture_output=True, text=True)
    except OSError:
        raise Refusal(f"could not run git to tell whether {cwd} is a worktree")
    return result.stdout.splitlines() if result.returncode == 0 else None


def worktree_root(cwd):
    """The linked worktree containing `cwd`, or None for a main checkout or no repository."""
    found = git(cwd, "rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir", "--show-toplevel")
    if found is None:
        return None
    git_dir, common_dir, top_level = found[:3]
    return Path(top_level).resolve() if git_dir != common_dir else None


def registry(cwd):
    common_dir = git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return Path(common_dir[0]) / REGISTRY_DIRECTORY


def is_inside(path, root):
    return Path(os.path.realpath(path)).is_relative_to(root)


def check(tool, tool_input, cwd):
    root = worktree_root(cwd)
    if root is None:
        return
    action = tool.rpartition("__")[2]
    if action in WORKSPACE_FREE_TOOLS:
        return
    if action == "XcodeOpenWorkspace":
        path = tool_input.get("path")
        if not (isinstance(path, str) and is_inside(path, root)):
            raise Refusal(f"open only this worktree's project, {root}/Moth.xcodeproj")
        return
    identifier = tool_input.get("workspaceIdentifier")
    if not isinstance(identifier, str) or not identifier:
        raise Refusal("pass the workspaceIdentifier XcodeOpenWorkspace returned for this worktree")
    if identifier.startswith("windowtab-"):
        raise Refusal(f"{identifier} is the user's Xcode window on the main checkout")
    entry = registry(cwd) / identifier
    if not entry.is_file():
        raise Refusal(f"{identifier} was never opened or listed in a recorded call; open {root}/Moth.xcodeproj first")
    if not is_inside(entry.read_text().strip(), root):
        raise Refusal(f"{identifier} is another checkout's workspace")


def read_payload():
    try:
        payload = json.load(sys.stdin)
        tool, tool_input, cwd = payload["tool_name"], payload["tool_input"], payload["cwd"]
    except (ValueError, KeyError, TypeError):
        return None
    if not (isinstance(tool, str) and isinstance(tool_input, dict) and isinstance(cwd, str)):
        return None
    return tool, tool_input, cwd


def main():
    payload = read_payload()
    try:
        if payload is None:
            # Claude Code lets a call through on any exit but 2, so a hook
            # that cannot read its input must refuse rather than crash.
            raise Refusal("the hook input could not be read")
        check(*payload)
    except Refusal as refusal:
        print(
            f"Xcode worktree guard: {refusal}. From a worktree, open "
            "<worktree>/Moth.xcodeproj with XcodeOpenWorkspace and pass the "
            "workspace-… identifier it returns on every call; never a windowtab-… "
            "identifier, which is the user's window on the main checkout.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
