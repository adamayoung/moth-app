//  HistoryModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct HistoryModelTests {

    private let entry = HistoryEntry(
        request: Request(name: "List", urlTemplate: "https://example.com"),
        sentAt: Date(timeIntervalSinceReferenceDate: 1),
        duration: .zero
    )

    @Test("Open Request opens the source request's tab and closes the entry")
    func openRequestOpensATab() {
        var opened: [Request.ID] = []
        let history = HistoryModel(
            sendAgain: { _ in .secretUnavailable },
            record: { _ in },
            clear: {},
            openTab: { opened.append($0) }
        )
        history.open(entry.id)

        history.openRequest(entry.request.id)

        #expect(opened == [entry.request.id])
        #expect(history.openEntry == nil)
    }

    @Test("Open Request is available only while the tree holds the request")
    func openRequestNeedsTheRequest() {
        let history = HistoryModel.preview
        let tree = CollectionTree(
            collections: [],
            folders: [],
            requests: []
        )

        #expect(!history.canOpenRequest(entry.request.id, in: tree))
    }

    @Test("Send Again records the new entry and opens it")
    func sendAgainOpensTheNewEntry() async {
        let newEntry = HistoryEntry(request: entry.request, sentAt: .now, duration: .zero)
        var recorded: [HistoryEntry] = []
        let history = HistoryModel(
            sendAgain: { _ in .sent(RecordedSend(result: .cancelled, entry: newEntry)) },
            record: { recorded.append($0) },
            clear: {},
            openTab: { _ in }
        )
        history.open(entry.id)

        await history.sendAgain(entry)

        #expect(recorded == [newEntry])
        #expect(history.openEntry == newEntry.id)
        #expect(history.secretUnavailable == nil)
    }

    @Test("Send Again with a secret that has gone says so, and records nothing")
    func sendAgainWithAMissingSecret() async {
        var recorded: [HistoryEntry] = []
        let history = HistoryModel(
            sendAgain: { _ in .secretUnavailable },
            record: { recorded.append($0) },
            clear: {},
            openTab: { _ in }
        )
        history.open(entry.id)

        await history.sendAgain(entry)

        #expect(recorded.isEmpty)
        #expect(history.openEntry == entry.id)
        #expect(history.secretUnavailable == entry.id)
    }

    @Test("Clear History clears the store and closes the entry")
    func clearClosesTheEntry() async {
        var cleared = 0
        let history = HistoryModel(
            sendAgain: { _ in .secretUnavailable },
            record: { _ in },
            clear: { cleared += 1 },
            openTab: { _ in }
        )
        history.open(entry.id)

        await history.clear()

        #expect(cleared == 1)
        #expect(history.openEntry == nil)
    }

}
