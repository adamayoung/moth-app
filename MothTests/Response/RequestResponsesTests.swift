//  RequestResponsesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestResponsesTests {

    private let bearer = Auth.bearer(BearerAuth(token: SecretReference(identifier: "token")))

    private func responses(
        holding request: Request,
        collectionAuth: Auth = .none,
        through transport: any HTTPTransport,
        secretStore: any SecretStore = InMemorySecretStore()
    ) throws -> (DataModel, RequestResponses, CollectionTree) {
        let production = WorkspaceEnvironment(name: "Production", variables: [
            Variable(
                name: "host",
                value: .plain(initial: "https://production.test", current: "https://production.test")
            )
        ])
        let staging = WorkspaceEnvironment(name: "Staging", variables: [
            Variable(name: "host", value: .plain(initial: "https://staging.test", current: "https://staging.test"))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            collections: [RequestCollection(
                name: "API",
                auth: collectionAuth,
                children: [CollectionItem(sortOrder: 0, node: .request(request))]
            )],
            environments: [production, staging]
        ))
        let responses = RequestResponses(
            dataModel: dataModel,
            transport: transport,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: staging.id)
        )
        return try (dataModel, responses, tree(of: dataModel))
    }

    private func tree(of dataModel: DataModel) throws -> CollectionTree {
        try CollectionTree(
            collections: dataModel.mainContext.fetch(.init()),
            folders: dataModel.mainContext.fetch(.init()),
            requests: dataModel.mainContext.fetch(.init())
        )
    }

    private func status(_ state: RequestResponses.State?) -> Int? {
        guard case .finished(.response(let response)) = state else {
            return nil
        }
        return response.status
    }

    @Test("A draft and the active environment are what gets sent")
    func sendsTheDraftAgainstTheActiveEnvironment() async throws {
        let transport = RecordingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "{{host}}/saved")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)
        var draft = RequestDraft(request)
        draft.url = "{{host}}/edited?page=2"
        draft.headers = [KeyValue(key: "X-Edited", value: "yes")]

        await responses.send(request.id, draft: draft, tree: tree).value

        withExtendedLifetime(dataModel) {
            #expect(transport.requests.first?.url?.absoluteString == "https://staging.test/edited?page=2")
            #expect(transport.requests.first?.value(forHTTPHeaderField: "X-Edited") == "yes")
            #expect(status(responses.state(for: request.id)) == 200)
        }
    }

    @Test("A request that inherits sends its container's auth")
    func sendsInheritedAuth() async throws {
        let transport = RecordingHTTPTransport()
        let secretStore = InMemorySecretStore()
        await secretStore.save("abc", for: "token")
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(
            holding: request,
            collectionAuth: bearer,
            through: transport,
            secretStore: secretStore
        )

        await responses.send(request.id, draft: RequestDraft(request), tree: tree).value

        withExtendedLifetime(dataModel) {
            #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        }
    }

    @Test("A request that can't be built shows why, and sends nothing")
    func invalidURL() async throws {
        let transport = RecordingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "{{missing}}/users")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        await responses.send(request.id, draft: RequestDraft(request), tree: tree).value

        withExtendedLifetime(dataModel) {
            #expect(transport.requests.isEmpty)
            #expect(responses.state(for: request.id) == .finished(.failed(
                SendFailure(kind: .notSent, description: "This URL isn’t valid."),
                notes: []
            )))
        }
    }

    @Test("A request whose row has gone shows why, and isn't reported as cancelled")
    func missingRow() async throws {
        let transport = RecordingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)
        let gone = Request(name: "Gone", urlTemplate: "https://example.com")

        await responses.send(gone.id, draft: RequestDraft(gone), tree: tree).value

        withExtendedLifetime(dataModel) {
            #expect(transport.requests.isEmpty)
            #expect(responses.state(for: gone.id) == .finished(.failed(
                SendFailure(kind: .notSent, description: "This request no longer exists."),
                notes: []
            )))
        }
    }

    @Test("A request with no response yet has no state")
    func noState() {
        #expect(RequestResponses.preview.state(for: UUID()) == nil)
    }

    @Test("A send shows as sending until it finishes")
    func sendingState() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        let wasSending = responses.isSending(request.id)
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(wasSending)
            #expect(!responses.isSending(request.id))
        }
    }

    @Test("A second send while one is in flight is ignored")
    func secondSendIgnored() async {
        var sends = 0
        let responses = RequestResponses { _, _, _ in
            sends += 1
            return .cancelled
        }
        let request = Request(name: "List")
        let draft = RequestDraft(request)

        let first = responses.send(request.id, draft: draft, tree: .empty)
        let second = responses.send(request.id, draft: draft, tree: .empty)
        await first.value
        await second.value

        #expect(sends == 1)
    }

    @Test("Cancel shows at once, even if the transport never answers")
    func cancelShowsAtOnce() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        let state = responses.state(for: request.id)
        let wasCancelled = transport.wasCancelled
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(state == .finished(.cancelled))
            #expect(wasCancelled)
        }
    }

    @Test("A result that arrives after Cancel doesn't replace it")
    func lateResultIgnored() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(responses.state(for: request.id) == .finished(.cancelled))
        }
    }

    @Test("A cancelled send's late result doesn't land on the send that followed it")
    func lateResultMissesTheNextSend() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)
        let draft = RequestDraft(request)

        let first = responses.send(request.id, draft: draft, tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        transport.release()
        let second = responses.send(request.id, draft: draft, tree: tree)
        await first.value
        let isStillSending = responses.isSending(request.id)
        await transport.waitForSend()
        transport.release()
        await second.value

        withExtendedLifetime(dataModel) {
            #expect(isStillSending)
        }
    }

    @Test("Responses belong to their own request")
    func perRequest() async {
        let responses = RequestResponses { id, _, _ in
            .failed(SendFailure(kind: .notSent, description: id.uuidString), notes: [])
        }
        let first = Request(name: "First")
        let second = Request(name: "Second")

        await responses.send(first.id, draft: RequestDraft(first), tree: .empty).value

        #expect(responses.state(for: first.id) != nil)
        #expect(responses.state(for: second.id) == nil)
    }

    @Test("Keeping other requests drops a response")
    func keepDropsResponses() async {
        let responses = RequestResponses { _, _, _ in .cancelled }
        let request = Request(name: "List")
        await responses.send(request.id, draft: RequestDraft(request), tree: .empty).value

        responses.keep([])

        #expect(responses.state(for: request.id) == nil)
    }

    @Test("Keeping other requests cancels a send in flight, and its late result lands nowhere")
    func keepCancelsSends() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.keep([])
        let wasCancelled = transport.wasCancelled
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(wasCancelled)
            #expect(responses.state(for: request.id) == nil)
        }
    }

    @Test("Closing the window cancels a send in flight")
    func releaseCancels() async throws {
        let transport = HoldingHTTPTransport()
        let (dataModel, send) = try await startSendThenReleaseItsModel(through: transport)

        let wasCancelled = await eventually { transport.wasCancelled }
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(wasCancelled)
        }
    }

    private func startSendThenReleaseItsModel(
        through transport: HoldingHTTPTransport
    ) async throws -> (DataModel, Task<Void, Never>) {
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)
        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        return (dataModel, send)
    }

    /// An isolated deinit runs on a later turn of the main actor.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        return condition()
    }

}
