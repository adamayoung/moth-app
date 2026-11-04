---
paths:
  - ".claude/settings.json"
---

# The Swift formatting hook

The `PostToolUse` hook in `.claude/settings.json` runs `swiftlint --fix` + `swiftformat` on every Swift file written through `Edit`, `Write`, `XcodeWrite` or `XcodeUpdate`. Two things in its `jq` are load-bearing and must survive any edit to it: `tool_response` arrives as a JSON **string** from the MCP tools but as an **object** from the built-in `Write`, which is what the `if type == "string" then fromjson` branch is for; and `XcodeUpdate` returns no `absolutePath` at all, so its path falls back to `tool_input.filePath` — a project path like `Moth/Foo.swift` that resolves only through the `$d/${p#*/}` candidate. Drop either and formatting silently stops for one tool while still working for the others. A third: that project path resolves against the checkout holding the hook input's `cwd`, not `$CLAUDE_PROJECT_DIR`, which stays at the main checkout in a worktree session; resolve it there and an `XcodeUpdate` in a worktree's workspace formats the user's copy of the file instead.
