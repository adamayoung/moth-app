---
paths:
  - "MothUITests/**/*.swift"
---

# What a green-looking UI test run hides

Read [UI Testing](../../docs/ui-testing.md) before changing the harness, fixtures or identifiers. These are the traps a green-looking run hides.

**Every launch argument is a `-key value` pair.** AppKit pairs a `-key` with whatever follows it, so a bare `-UITesting` swallows the next key as its value and leaves a stray `0` behind, which AppKit takes for a file to open — and an app launched to open a file gets no untitled window. The app comes up as a menu bar and nothing else, and *every* screen assertion fails for a reason that has nothing to do with the test. `MothTestCase` pairs `-UITesting 1` for exactly this; never append a bare flag.

**Values the app and the tests share are mirrored by hand**, because the UI test bundle cannot import the app target. Change one side and change the other — a stale count or identifier compiles fine and fails as a flaky-looking assertion.

**A string subscript over 128 characters crashes the runner.** A `WindowGroup(for:)` window's identifier always is, so use `app.windows.matching(NSPredicate(format: "identifier == %@", id))`; long alert text needs `label == %@ OR value == %@`. A window element bound through `title BEGINSWITH` dies when its `navigationTitle` changes, so rebind it to the identifier.

**Windows hide each other.** `rightClick()` and `doubleClick()` do not raise their window, and an index-bound window element re-resolves to another window once its own closes, so assert a close with `app.windows.count`. Every test failing "Not hittable" at its first click means a stray window: check the `tearDown()` screenshot.

No fixed sleeps — wait on the element or predicate that proves the transition; extend the nearest object in `Screens/` instead of scattering raw query chains.
