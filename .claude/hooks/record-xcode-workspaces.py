#!/usr/bin/env python3
"""PostToolUse hook on XcodeOpenWorkspace and XcodeListWorkspaces: record the
project path behind every workspace identifier they report, for
xcode-worktree-guard.py.

Each identifier is a file in the repository's shared git directory holding
its path, so every worktree's session sees the same record. It never fails
the call it follows.
"""

import json
from pathlib import Path
import re
import subprocess
import sys

REGISTRY_DIRECTORY = "moth-xcode-workspaces"
LISTED_WORKSPACE = re.compile(r"workspaceIdentifier: ([\w-]+), workspacePath: (.+?)\s*$", re.MULTILINE)
IDENTIFIER = re.compile(r"^[\w-]+$")


def workspaces_in(response):
    """(identifier, path) pairs from a response that may be JSON inside JSON."""
    if isinstance(response, str):
        try:
            yield from workspaces_in(json.loads(response))
        except ValueError:
            yield from LISTED_WORKSPACE.findall(response)
    elif isinstance(response, list):
        for item in response:
            yield from workspaces_in(item)
    elif isinstance(response, dict):
        identifier, path = response.get("workspaceIdentifier"), response.get("workspacePath")
        if isinstance(identifier, str) and isinstance(path, str):
            yield identifier, path
        for value in response.values():
            yield from workspaces_in(value)


def registry(cwd):
    result = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"],
        capture_output=True,
        text=True,
    )
    return Path(result.stdout.strip()) / REGISTRY_DIRECTORY if result.returncode == 0 else None


def main():
    try:
        payload = json.load(sys.stdin)
        directory = registry(payload["cwd"])
        if directory is None:
            return 0
        for identifier, path in workspaces_in(payload["tool_response"]):
            if IDENTIFIER.match(identifier):
                directory.mkdir(exist_ok=True)
                (directory / identifier).write_text(path + "\n")
    except (ValueError, KeyError, TypeError, OSError):
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
