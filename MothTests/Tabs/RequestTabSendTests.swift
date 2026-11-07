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

    private func tabs(sent: @escaping (Request.ID) -> Void = { _ in }) throws -> (DataModel, RequestTabsModel) {
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [RequestCollection(
            name: "API",
            children: [
                CollectionItem(sortOrder: 0, node: .request(first)),
                CollectionItem(sortOrder: 1, node: .request(second))
            ]
        )]))
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let drafts = RequestDrafts.preview
        drafts.savedRequestDidChange(first)
        drafts.savedRequestDidChange(second)
        let tabs = RequestTabsModel(
            store: RequestTabStore(defaults: defaults, key: "Tabs"),
            drafts: drafts,
            responses: RequestResponses { id, _, _ in
                sent(id)
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

}
