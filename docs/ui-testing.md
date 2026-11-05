# UI Testing

## Harness and Data

`MothUITests` uses XCTest and drives `XCUIApplication` against deterministic
seeded data. `MothTestCase` is the base class. It launches the app in UI-test
mode, which selects `SeededAppDependencies`: in-memory stores and an in-memory
secret store, with no iCloud or network access.

Every launch argument is a `-key value` pair. A bare `-Flag` swallows whatever
follows it as its value, and AppKit can read the stray argument as a file to
open, so the app comes up with no window. So a bare `-UITesting`, or any value
but `1`, stops the launch: Moth prints the fix to stderr and exits with code 64.
`MothTestCase` also passes `-ApplePersistenceIgnoreState YES`, which turns off
window restoration. It doesn't clear a saved `NSWindow Frame`, so a test can't
assume the window's size. `-NSShowNonLocalizedStrings YES` capitalises any text
missing from the catalog, so a hardcoded string fails the assertion on its copy.

Demo mode uses the same seeded graph. `-DemoMode 1` or a stored `DemoMode`
default selects it.

`SeedData.workspace` holds one collection, "Seeded Collection", with one request,
and one environment, "Seeded Environment", which is the active one. Its
identifiers are fixed. UI-test and demo launches load it, and the test host's
store stays empty.

The UI test bundle cannot import the app target, so a value it shares with the
app's seed data is mirrored by hand. Change both sides together.

## Screen Objects and Accessibility

Tests talk to screen objects in `MothUITests/Screens/`, not to raw query chains.
Anchor a screen object on an element that reaches the accessibility tree, and
give each control an accessibility identifier.

Put an identifier on a region inside `NavigationSplitView`, not on the split view
itself. A `List` is queried through `app.outlines`. A view with no children of
its own, such as the empty tab strip, reaches the tree only through
`.accessibilityElement()` and needs a label for VoiceOver. A
`ContentUnavailableView` title is a static text's value rather than its label,
and `staticTexts[…]` matches both.

An element found by identifier proves it exists, not where it is. To assert
layout, read frames, and remember that an `.accessibilityElement(children:
.contain)` group reports the union of its children's frames, not the view's own
size, so a pane that fills its space can still measure only as wide as its text.

## Plans and Commands

`CLAUDE.md` determines which tool or delegated agent runs a UI target. The
commands below are the canonical Make equivalents for direct terminal use and
fallback execution. `make test-ui` clears a stale `Moth` itself, under the
machine-wide build lock; see [The Build Lock](testing.md#the-build-lock).

```bash
make test-ui                                     # complete MothUITests target
make test-ui TESTS=RequestEditorTests UI_ALLOWANCE=short   # one class, 60/90 s per test
make test-ui UI_ALLOWANCE=long                   # the full suite, 180/240 s per test
```

`UI_ALLOWANCE` turns on xcodebuild's per-test time allowances, so a hung test
fails instead of running out the ten-minute default: `short` for one class,
`long` for the full suite. Unset, no allowance applies. Agents always pass one.

UI filters are XCTest identifiers (`Class/testMethod`) with no trailing `()`.
`TESTS` takes one identifier, so several classes need several invocations.

CI does not run UI tests: see
[Continuous Integration](testing.md#continuous-integration).

## Reliability Rules

- No fixed sleeps. Wait on the element or predicate that proves the transition.
- A string subscript over 128 characters crashes the runner. Use
  `app.windows.matching(NSPredicate(format: "identifier == %@", id))` for a long
  window identifier.
- `rightClick()` and `doubleClick()` do not raise their window. An index-bound
  window element re-resolves to another window once its own closes, so assert a
  close with `app.windows.count`.

## When a UI Run Fails

A test that fails at its first interaction with something that should be there
is often failing on the machine, not the code, and a retry in the same state
fails the same way. Check before any retry. Touch
`DerivedData/last-test-ui.start` before each run so step 3 has a start time, and
check straight after the failure: the next `make test` deletes the result bundle.

1. `grep -n 'interrupting element' DerivedData/last-test-ui.log`, the log the
   tooling runner writes. A line naming a `Dialog` or
   `com.apple.UserNotificationCenter` means a system dialog covered the app.
2. Export the failure screenshots and open each one:

   ```bash
   out=$(mktemp -d) && xcrun xcresulttool export attachments --path DerivedData/Result.xcresult \
     --output-path "$out" --only-failures --filter "*.png" && echo "$out"
   ```

   A "Moth quit unexpectedly" dialog appears in the screenshot and not in the
   accessibility hierarchy, so a search of the hierarchy text reports no dialog
   when there is one.
3. `find ~/Library/Logs/DiagnosticReports -name '*.ips' -newer DerivedData/last-test-ui.start`,
   and name each report's process and time. `procPath` is redacted, so a `Moth`
   report may come from another checkout's test host.
4. Check the screen lock with
   `ioreg -n Root -d1 -a | plutil -p - | grep ScreenIsLocked`. It prints
   `"CGSSessionScreenIsLocked" => 1` when the screen is locked, and nothing
   (exit 1) when it is not. A locked screen fails a UI run as
   `LocalAuthentication` error -4, as "Timed out while enabling automation mode",
   or as "Failed to activate application … (current state: Running Background)".
   The "automation mode" message with no lock key set is usually a wedged
   `testmanagerd`.

Once the cause is a dialog, a locked screen or a wedged `testmanagerd`, stop
retrying: report the class as not run, with that evidence. The user dismisses
dialogs, unlocks the screen and restarts `testmanagerd`. Never probe for a dialog
with `osascript` or System Events: the probe can hang, and it can leave an
Automation permission prompt on the user's screen.
