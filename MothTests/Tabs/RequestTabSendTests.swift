//  RequestTabSendTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestTabSendTests {

    private let first = Request(name: "First", urlTemplate: "https://example.com/first")
    private let second = Request(name: "Second", urlTemplate: "https://example.com/second")
    private let blank = Request(name: "Blank")

    private func tabs(
        holdingSends: Bool = false,
        sent: @escaping (Request.ID) -> Void = { _ in }
    ) throws -> (DataModel, RequestTabsModel) {
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [RequestCollection(
            name: "API",
            children: [
                CollectionItem(sortOrder: 0, node: .request(first)),
                CollectionItem(sortOrder: 1, node: .request(second)),
                CollectionItem(sortOrder: 2, node: .request(blank))
            ]
        )]))
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let drafts = RequestDrafts.preview
        drafts.savedRequestDidChange(first)
        drafts.savedRequestDidChange(second)
        drafts.savedRequestDidChange(blank)
        let tabs = RequestTabsModel(
            store: RequestTabStore(defaults: defaults, key: "Tabs"),
            drafts: drafts,
            responses: RequestResponses { id, _, _ in
                sent(id)
                if holdingSends {
                    try? await Task.sleep(for: .seconds(600))
                }
                return .cancelled
            },
            code: .preview
        )
        let context = dataModel.mainContext
        let requests: [RequestModel] = try context.fetch(.init())
        try tabs.collectionDidChange(CollectionSnapshot(
            tree: CollectionTree(
                collections: context.fetch(.init()),
                folders: context.fetch(.init()),
                requests: requests
            ),
            requestIDs: Set(requests.map(\.id))
        ))
        return (dataModel, tabs)
    }

    @Test("Each tab keeps its own response")
    func responsePerTab() async throws {
        let (dataModel, tabs) = try tabs()
        tabs.open(first.id)
        tabs.open(second.id)

        await tabs.send(first.id)?.value

        withExtendedLifetime(dataModel) {
            #expect(tabs.responses.state(for: first.id) != nil)
            #expect(tabs.responses.state(for: second.id) == nil)
        }
    }

    @Test("Send uses the tab's draft, including unsaved edits")
    func sendsTheDraft() async throws {
        var sentDraft: RequestDraft?
        let drafts = RequestDrafts.preview
        drafts.savedRequestDidChange(first)
        drafts.update(first.id) { $0.url = "https://example.com/edited" }
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let tabs = RequestTabsModel(
            store: RequestTabStore(defaults: defaults, key: "Tabs"),
            drafts: drafts,
            responses: RequestResponses { _, draft, _ in
                sentDraft = draft
                return .cancelled
            },
            code: .preview
        )

        await tabs.send(first.id)?.value

        #expect(sentDraft?.url == "https://example.com/edited")
    }

    @Test("A request with no draft sends nothing")
    func noDraft() throws {
        let (dataModel, tabs) = try tabs()

        let send = tabs.send(UUID())

        withExtendedLifetime(dataModel) {
            #expect(send == nil)
        }
    }

    @Test("Closing a tab drops its response")
    func closeDropsResponse() async throws {
        let (dataModel, tabs) = try tabs()
        tabs.open(first.id)
        await tabs.send(first.id)?.value

        tabs.close(first.id)

        withExtendedLifetime(dataModel) {
            #expect(tabs.responses.state(for: first.id) == nil)
        }
    }

    @Test("Closing one tab leaves another tab's response")
    func closeKeepsOtherResponses() async throws {
        let (dataModel, tabs) = try tabs()
        tabs.open(first.id)
        tabs.open(second.id)
        await tabs.send(first.id)?.value

        tabs.close(second.id)

        withExtendedLifetime(dataModel) {
            #expect(tabs.responses.state(for: first.id) != nil)
        }
    }

    @Test("With no tab open there is nothing to send")
    func noTabCannotSend() throws {
        let (dataModel, tabs) = try tabs()

        withExtendedLifetime(dataModel) {
            #expect(tabs.sendCommand == .unavailable)
        }
    }

    @Test("A tab with a URL can send, and one with an empty URL cannot")
    func sendNeedsAURL() throws {
        let (dataModel, tabs) = try tabs()

        tabs.open(first.id)
        let withURL = tabs.sendCommand
        tabs.open(blank.id)
        let withoutURL = tabs.sendCommand

        withExtendedLifetime(dataModel) {
            #expect(withURL == .send(first.id))
            #expect(withoutURL == .unavailable)
        }
    }

    @Test("A tab whose row can't be read cannot send")
    func unreadableCannotSend() throws {
        let (dataModel, tabs) = try tabs()
        tabs.open(first.id)

        tabs.drafts.savedRequestIsUnreadable(first.id)

        withExtendedLifetime(dataModel) {
            #expect(tabs.sendCommand == .unavailable)
        }
    }

    @Test("While the tab's request is sending, the command cancels it")
    func sendingCancels() throws {
        let (dataModel, tabs) = try tabs(holdingSends: true)
        tabs.open(first.id)

        tabs.send(first.id)
        let whileSending = tabs.sendCommand
        tabs.cancelSend(first.id)

        withExtendedLifetime(dataModel) {
            #expect(whileSending == .cancel(first.id))
            #expect(tabs.sendCommand == .send(first.id))
        }
    }

}
