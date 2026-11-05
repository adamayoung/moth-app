# Testing

## Test Layers

Unit and integration tests use Swift Testing. `MothUITests` uses XCTest because
it drives `XCUIApplication`. Tests live beside their ownership boundary:

| Location | Covers |
| --- | --- |
| `MothTests/` | App composition, commands, view presentation helpers, and platform adapters |
| `Packages/*/Tests/` | Package behaviour, mapping, persistence, services, and transport contracts |
| `MothUITests/` | End-to-end observable UI behaviour against deterministic seeded data |

For features and bug fixes, follow the `canon-tdd` skill: write a short
behavioural test list, add one failing test, make it pass with the smallest
production change, refactor while green, and repeat. Assert observable outcomes
rather than private implementation details.

## Building

`CLAUDE.md` determines which tool or delegated agent runs a build. These are the
canonical Make equivalents for direct terminal use and fallback execution:

```bash
make build
```

## Running Tests

`CLAUDE.md` determines which tool or delegated agent runs a target. The commands
below are the canonical Make equivalents for direct terminal use and fallback
execution:

```bash
make test                         # UnitTests: app plus all package targets
make test-unit                    # MothTests only
make test-packages                # swift test in every local package
make test TESTS=AppLaunchModeTests
make test TESTS='AppLaunchModeTests/noArgumentsIsLive()'
make test TEST_TARGET=MothCoreTests TESTS='VariableResolverTests/requestScopeWins()'
make test-all                     # unit, packages, and the full UI suite
```

See [UI Testing](ui-testing.md) for UI plans, filters, and commands. The scripts
behind these targets have tests of their own:

```bash
python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
```

`TESTS=` defaults to the `MothTests` target. Supply `TEST_TARGET=` when the suite
belongs to a package. Swift Testing function filters require trailing `()`;
XCTest and UI test method filters do not. An incorrect filter can match nothing,
so trust the final `Ran N test(s).` line rather than only `** TEST SUCCEEDED **`.

## Test Plans

`TestPlans/UnitTests.xctestplan` contains the app and package unit targets.
`UITests.xctestplan` contains the full UI target. A new target must be added to
the relevant plan, or `make test` will not run it. The `Moth` scheme lists the
plans, not their targets, so it needs no entry. A package's plan entry uses
`container:Packages/<Name>` as its `containerPath`, and the target's name as
both `identifier` and `name`.

The project's `Packages` folder entry belongs to no target and already covers a
new package. Do not use `xcrun xcodeproj pkg add-local`: it writes the project's
`packages` array, and with the packages there `make test` passed having run none
of their tests, its count kept above zero by `MothTests`. The script tests fail
on a `packages` array. To link a product, add it to the target's
`package-product-members` by hand, with no `package` key.

## Writing Swift Tests

- Name suites `<Subject>Tests`; use a `struct` unless XCTest requires a class.
- Give `@Test` a sentence that states the behaviour, not a method-shaped label.
- Add `@MainActor` when the subject is main-actor isolated.
- Use `#expect` for assertions and `try #require` to unwrap prerequisites.
- Use parameterized `arguments:` when several inputs prove the same claim.
- Prefer focused fakes that record calls or return deterministic values. Avoid
  real network, Keychain or iCloud access.
- For SwiftData tests, create an isolated in-memory container, hold it for the
  life of any context you read from, and validate persisted results through a
  fresh context when cache behaviour matters.
- Cover cancellation, errors, empty results, repeated calls, and late async
  callbacks when they are meaningful parts of the contract.
- Use real exported Postman files as fixtures. A fixture you invented tests your
  belief, not the format.

## Verification Expectations

Run the narrow test while iterating, then the owning target or plan. Run
`make test` when shared models, composition, persistence, or cross-package
behaviour changes; run `make test-packages` when a package's standalone build
matters. UI changes require the affected UI classes described in
[UI Testing](ui-testing.md). Finish with `make lint` as described in
[Code Style](code-style.md).

## Continuous Integration

CI uses GitHub-hosted runners: the `xcode-27` image, with `DEVELOPER_DIR` pinned
to `/Applications/Xcode_27.2.app/Contents/Developer`, because 27.1 is that
image's default. Check the
[image's README](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
before changing the pin.

That image runs macOS 27.0.1 and Moth's minimum is 27.2, which decides what CI
can do:

| Command | Result when the minimum is above the host |
| --- | --- |
| `swift test` | Runs |
| `xcodebuild build-for-testing` | Succeeds |
| `xcodebuild test` | Refused: "Cannot test target … on My Mac" |

So pull requests run lint, `swift test` in every package, `build-for-testing`
for the scheme, and an iOS build of the packages. `MothTests` and `MothUITests`
run only on a developer's Mac until the image reaches macOS 27.2. Until then the
workflow reports that they did not run, so a green check is not read as covering
them, and `make test` before a pull request is the only run of those tests.

This table was measured locally, with a 27.2.1 minimum on macOS 27.2. A package
that calls an API added in 27.2 could still fail at run time on 27.0.1.

## The Build Lock

Every `make` target that runs `xcodebuild` goes through `Scripts/build-lock.sh`,
which holds a machine-wide `shlock`. Only one build or test run proceeds at a
time across every checkout and worktree on the machine; the others queue. A
queued run prints what it is waiting behind every five seconds:

```text
waiting for the xcodebuild lock (held by pid 4242: test-ui UITests in /path/to/checkout)...
```

That is the lock working, not a hang. A lock left by a killed run is detected as
stale and taken over. Builds started from Xcode's own UI or the Xcode MCP do not
take the lock, so avoid building in Xcode while a test run is going.

`make test-ui` alone clears a running `Moth` before its run, and only once it
holds the lock, so a queued run can never kill the app another run's UI test is
driving. It prints `killed stale Moth (pid N) before the UI run` when it does.

A `Moth` running under Xcode's debugger cannot be stopped from outside Xcode, and
a UI run around it would hang every test at "Terminate". So `make test-ui` checks
for one before sending any signal, and fails at once with `error: Moth (pid N)
is running under the Xcode debugger`. Stop the app in Xcode, then run the command
again.

## Working in a Worktree

Claude Code sessions implement an issue in a worktree under
`.claude/worktrees/`, while the main checkout stays the user's. A worktree builds
into its own `DerivedData` and takes the same build lock as every other checkout.

- **Gitignored files.** `.worktreeinclude` lists the ignored files Claude Code
  copies into a new worktree, and why each matters.
- **Formatting and lint.** SwiftFormat also applies a parent directory's
  `.swiftformat`, and a worktree sits inside the main checkout, so the main
  checkout's config governs the worktree's files. That is why `make lint` and
  `make format` give SwiftFormat `.claude/worktrees` on its command line, not in
  `.swiftformat`, where the exclusion would skip every file in a worktree, the
  format hook's included. SwiftLint has no such flag, so its exclusion is in
  `.swiftlint.yml`. It reads no parent configuration and lints a file named
  explicitly, so the hook is unaffected.
- **Xcode.** The Xcode window is open on the main checkout, and the Xcode MCP
  lists it as `windowtab-…`; a call aimed at it from a worktree reads and writes
  the main checkout's files. Xcode's headless MCP server
  (`sudo xcrun mcp-server enable`, once per machine) opens a worktree's project
  without a window: `XcodeOpenWorkspace` with `<worktree>/Moth.xcodeproj` returns
  a `workspace-…` identifier that addresses that worktree only. Pass the
  identifier on every call; the tools do not accept the path.
  `.claude/hooks/xcode-worktree-guard.py` refuses any other workspace from a
  worktree. Builds and previews in that workspace do not take the build lock.
- **The debugger.** A `Moth` under the debugger in the user's Xcode window can be
  stopped only there, not from a worktree's workspace.
