---
paths:
  - "Moth/Scenes/**/*.swift"
---

# Window sizes: saved frames and `.contentSize`

**AppKit restores a saved `NSWindow Frame <name>` over the scene's size, and the name is the scene's full generic type**, every content modifier included. Adding or removing a modifier inside a `WindowGroup` changes the key, so a sizing change can look right on the first launch, with no saved frame, and wrong once a frame is saved again.

**Under `.windowResizability(.contentSize)` the main window opens at its content's minimum and ignores `.defaultSize`**, so use `.contentMinSize`, under which `.defaultSize` applies.

See [Code Style](../../docs/code-style.md#swift-and-swiftui-practices).
