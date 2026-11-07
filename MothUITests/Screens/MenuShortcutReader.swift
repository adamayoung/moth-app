//  MenuShortcutReader.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import AppKit
import ApplicationServices
import XCTest

/// A menu item's key equivalent as the Accessibility API reports it: the character uppercased, and the modifiers as
/// `kAXMenuItemModifier…` flags, where 0 means Command alone.
struct MenuShortcut: Equatable, CustomStringConvertible {

    static let command = 0
    static let shift = 1 << 0
    static let control = 1 << 2
    static let noCommand = 1 << 3

    let character: Character
    let modifiers: Int

    var description: String {
        "\(character.unicodeScalars.map(\.value)) modifiers \(modifiers)"
    }

}

/// XCUIElement has no key equivalent, so this reads the app's menu bar through the Accessibility API.
struct MenuShortcutReader {

    private let application: AXUIElement

    init() throws {
        guard AXIsProcessTrusted() else {
            throw XCTSkip("The test runner is not trusted for Accessibility, so it cannot read key equivalents.")
        }
        let running = try XCTUnwrap(
            NSRunningApplication.runningApplications(withBundleIdentifier: "uk.co.adam-young.Moth").first
        )
        self.application = AXUIElementCreateApplication(running.processIdentifier)
    }

    func shortcut(of title: String, inMenu menuTitle: String) throws -> MenuShortcut? {
        let menuBar = try XCTUnwrap(element(application, kAXMenuBarAttribute))
        let menuBarItem = try XCTUnwrap(children(of: menuBar).first { self.title(of: $0) == menuTitle }, menuTitle)
        let items = children(of: menuBarItem).flatMap(children(of:))
        let item = try XCTUnwrap(items.first { self.title(of: $0) == title }, title)
        guard let character = attribute(item, kAXMenuItemCmdCharAttribute) as? String,
              let first = character.uppercased().first
        else {
            return nil
        }
        let modifiers = attribute(item, kAXMenuItemCmdModifiersAttribute) as? Int ?? 0
        return MenuShortcut(character: first, modifiers: modifiers)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func title(of element: AXUIElement) -> String? {
        attribute(element, kAXTitleAttribute) as? String
    }

    private func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

}
