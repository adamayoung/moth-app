//  ReadOnlyTextView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import SwiftUI

/// An `NSTextView`, because `Text` lays out megabytes on the main thread and `TextEditor` can't be selectable and
/// read-only at once.
struct ReadOnlyTextView: NSViewRepresentable {

    let text: String
    let accessibilityIdentifier: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        if let textView = scrollView.documentView as? NSTextView {
            textView.isEditable = false
            textView.isSelectable = true
            textView.isRichText = false
            textView.drawsBackground = false
            textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            textView.textColor = .labelColor
            textView.setAccessibilityIdentifier(accessibilityIdentifier)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else {
            return
        }
        textView.string = text
        textView.scroll(.zero)
    }

}
