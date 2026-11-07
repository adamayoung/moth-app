//  Clipboard.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit

struct Clipboard {

    static var general: Clipboard {
        Clipboard(pasteboard: .general)
    }

    /// A UI test run must not replace what the person copied, and the runner reading the General pasteboard would
    /// raise a system alert. Other pasteboards are read freely. `GenerateCodeScreen` mirrors the name by hand.
    static var uiTest: Clipboard {
        Clipboard(pasteboard: NSPasteboard(name: NSPasteboard.Name("MothUITestClipboard")))
    }

    let pasteboard: NSPasteboard

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

}
