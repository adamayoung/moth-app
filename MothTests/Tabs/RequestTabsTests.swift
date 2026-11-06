//  RequestTabsTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import Testing

@MainActor
struct RequestTabsTests {

    let first = UUID()
    let second = UUID()
    let third = UUID()

    private func tabs(open ids: UUID..., selecting selected: UUID) -> RequestTabs {
        var tabs = RequestTabs()
        ids.forEach { tabs.open($0) }
        tabs.select(selected)
        return tabs
    }

    @Test("Opening a request appends it and selects it")
    func openAppendsAndSelects() {
        var tabs = RequestTabs()

        tabs.open(first)
        tabs.open(second)

        #expect(tabs.ids == [first, second])
        #expect(tabs.selected == second)
    }

    @Test("Opening an open request selects it and adds no tab")
    func openExistingSelects() {
        var tabs = tabs(open: first, second, selecting: second)

        tabs.open(first)

        #expect(tabs.ids == [first, second])
        #expect(tabs.selected == first)
    }

    @Test("Selecting names only an open tab")
    func selectIgnoresAClosedRequest() {
        var tabs = tabs(open: first, selecting: first)

        tabs.select(second)

        #expect(tabs.selected == first)
    }

    @Test("Closing the selected tab selects the tab to its right")
    func closeSelectsRightNeighbour() {
        var tabs = tabs(open: first, second, third, selecting: second)

        tabs.close(second)

        #expect(tabs.ids == [first, third])
        #expect(tabs.selected == third)
    }

    @Test("Closing the selected tab at the end selects the tab to its left")
    func closeLastPositionSelectsLeftNeighbour() {
        var tabs = tabs(open: first, second, third, selecting: third)

        tabs.close(third)

        #expect(tabs.selected == second)
    }

    @Test("Closing another tab keeps the selection")
    func closeOtherKeepsSelection() {
        var tabs = tabs(open: first, second, third, selecting: first)

        tabs.close(third)

        #expect(tabs.ids == [first, second])
        #expect(tabs.selected == first)
    }

    @Test("Closing the last tab leaves no selection")
    func closeOnlyTabClearsSelection() {
        var tabs = tabs(open: first, selecting: first)

        tabs.close(first)

        #expect(tabs.ids.isEmpty)
        #expect(tabs.selected == nil)
    }

    @Test("Closing a request with no tab changes nothing")
    func closeUnknownIsIgnored() {
        var tabs = tabs(open: first, selecting: first)

        tabs.close(second)

        #expect(tabs.ids == [first])
        #expect(tabs.selected == first)
    }

}
