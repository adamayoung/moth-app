//  MenuShortcutTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// List Users mirrors `SeedData` by hand, and `/wait` mirrors `StubHTTPTransport`, which holds that send open.
final class MenuShortcutTests: MothTestCase {

    @MainActor
    func testEachMenuItemShowsItsShortcut() throws {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        let reader = try MenuShortcutReader()
        let expected: [(menu: String, item: String, shortcut: MenuShortcut)] = [
            ("File", "New Request", MenuShortcut(character: "T", modifiers: MenuShortcut.command)),
            ("Request", "Send", MenuShortcut(character: "\r", modifiers: MenuShortcut.command)),
            ("Request", "Edit URL", MenuShortcut(character: "L", modifiers: MenuShortcut.command)),
            (
                "Request",
                "Select Next Tab",
                MenuShortcut(character: "\t", modifiers: MenuShortcut.control | MenuShortcut.noCommand)
            ),
            (
                "Request",
                "Select Previous Tab",
                MenuShortcut(
                    character: "\t",
                    modifiers: MenuShortcut.shift | MenuShortcut.control | MenuShortcut.noCommand
                )
            )
        ]

        for (menu, item, shortcut) in expected {
            app.menuBars.menuBarItems[menu].click()
            XCTAssertTrue(app.menuBars.menuBarItems[menu].menuItems[item].waitForExistence(timeout: 10), item)
            let actual = try reader.shortcut(of: item, inMenu: menu)
            screen.closeMenu()
            XCTAssertEqual(actual, shortcut, "\(menu) > \(item)")
        }
    }

    @MainActor
    func testCancelShowsCommandPeriodWhileSending() throws {
        let screen = MainWindowScreen(app: app)
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        screen.select("List Users")
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
        editor.replaceURL(with: "{{host}}/wait")
        XCTAssertTrue(editor.waitForValue("{{host}}/wait", of: editor.urlField))
        editor.sendButton.click()
        XCTAssertTrue(editor.cancelButton.waitForExistence(timeout: 10))
        let reader = try MenuShortcutReader()

        screen.openRequestMenu()
        XCTAssertTrue(screen.requestMenuItem("Cancel").waitForExistence(timeout: 10))
        let shortcut = try reader.shortcut(of: "Cancel", inMenu: "Request")
        screen.closeMenu()

        XCTAssertEqual(shortcut, MenuShortcut(character: ".", modifiers: MenuShortcut.command))
    }

}
