//  KeyValueTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct KeyValueTests {

    @Test("A new row is enabled")
    func newRowIsEnabled() {
        let row = KeyValue(key: "page", value: "1")

        #expect(row.isEnabled)
    }

    @Test("A disabled row stays disabled and keeps its key and value")
    func disabledRowKeepsItsContent() {
        let row = KeyValue(key: "Accept", value: "text/plain", isEnabled: false)

        #expect(!row.isEnabled)
        #expect(row.key == "Accept")
        #expect(row.value == "text/plain")
    }

    @Test("Two rows with the same key and value are still separate rows")
    func rowsAreDistinctByIdentity() {
        let first = KeyValue(key: "Set-Cookie", value: "a=1")
        let second = KeyValue(key: "Set-Cookie", value: "a=1")

        #expect(first.id != second.id)
    }

}
