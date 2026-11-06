//  RequestResponsesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct RequestResponsesTests: RequestResponsesTesting {

    private let bearer = Auth.bearer(BearerAuth(token: SecretReference(identifier: "token")))

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

}
