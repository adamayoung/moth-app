//  RequestSenderTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderTests {

    private let secretStore: any SecretStore = InMemorySecretStore()

    private func send(
        _ request: Request,
        typed: [CredentialWrite] = [],
        scopes: VariableScopes = VariableScopes(),
        through transport: RecordingTransport = RecordingTransport()
    ) async -> SendResult {
        let sender = RequestSender(transport: transport, secretStore: secretStore)
        return await sender.send(OutgoingRequest(request: request, typedCredentials: typed), scopes: scopes)
    }

    @Test("An environment's value reaches the wire")
    func resolvesEnvironment() async throws {
        let transport = RecordingTransport()
        let request = Request(name: "List", urlTemplate: "{{host}}/users")

        _ = await send(
            request,
            scopes: VariableScopes(environment: [.plain("host", "https://example.com")]),
            through: transport
        )

        let url = try #require(transport.requests.first?.url)
        #expect(url.absoluteString == "https://example.com/users")
    }

    @Test("Collection variables and globals are in scope, with the collection first")
    func scopeOrder() async throws {
        let transport = RecordingTransport()
        let request = Request(name: "List", urlTemplate: "https://{{a}}.example.com/{{b}}")

        _ = await send(
            request,
            scopes: VariableScopes(
                collection: [.plain("a", "collection")],
                environment: [.plain("a", "environment")],
                globals: [.plain("a", "global"), .plain("b", "global")]
            ),
            through: transport
        )

        let url = try #require(transport.requests.first?.url)
        #expect(url.absoluteString == "https://collection.example.com/global")
    }

    @Test("A response comes back with its status")
    func response() async {
        let transport = RecordingTransport {
            HTTPResponse(status: 404, headers: [:], body: Data("gone".utf8))
        }

        let result = await send(Request(name: "List", urlTemplate: "https://example.com"), through: transport)

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(response.status == 404)
        #expect(response.content == .text("gone"))
    }

    @Test("A typed credential is used and not saved")
    func typedCredential() async throws {
        let transport = RecordingTransport()
        let reference = SecretReference(identifier: "typed")
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            auth: .bearer(BearerAuth(token: reference))
        )

        _ = await send(
            request,
            typed: [CredentialWrite(reference: reference, value: "typed-token")],
            through: transport
        )

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer typed-token")
        #expect(try await secretStore.value(for: "typed") == nil)
    }

    @Test("A typed credential expands its variables")
    func typedCredentialExpands() async {
        let transport = RecordingTransport()
        let reference = SecretReference(identifier: "typed")
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            auth: .bearer(BearerAuth(token: reference))
        )

        _ = await send(
            request,
            typed: [CredentialWrite(reference: reference, value: "{{token}}")],
            scopes: VariableScopes(environment: [.plain("token", "abc")]),
            through: transport
        )

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test("A stored credential is read from the secret store")
    func storedCredential() async throws {
        let transport = RecordingTransport()
        let reference = SecretReference(identifier: "stored")
        try await secretStore.save("stored-token", for: "stored")
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            auth: .bearer(BearerAuth(token: reference))
        )

        _ = await send(request, through: transport)

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer stored-token")
    }

    @Test("An unresolved variable goes out as written and is noted")
    func unresolvedVariable() async {
        let transport = RecordingTransport()
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Token", value: "{{token}}")]
        )

        let result = await send(request, through: transport)

        #expect(transport.requests.first?.value(forHTTPHeaderField: "X-Token") == "{{token}}")
        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(response.notes == [.undefinedVariable("token")])
    }

    @Test("A credential with no value sends no auth, and says so")
    func missingCredential() async {
        let transport = RecordingTransport()
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            auth: .bearer(BearerAuth(token: SecretReference(identifier: "unsaved")))
        )

        let result = await send(request, through: transport)

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(response.notes == [.missingCredential])
    }

    @Test("An unsupported auth and body are noted")
    func unsupportedNotes() async {
        let request = Request(
            name: "Health",
            urlTemplate: "https://example.com",
            body: .binary(filePath: "/tmp/health.bin"),
            auth: .apiKey(APIKeyAuth(
                name: "X-Key",
                value: SecretReference(identifier: "key"),
                location: .header
            ))
        )

        let result = await send(request)

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(response.notes == [.unsupportedAuth, .unsupportedBody])
    }

    @Test("A transport failure keeps its notes, because the request went out")
    func transportFailureKeepsNotes() async {
        let transport = RecordingTransport {
            throw HTTPTransportError.timedOut(description: "The request timed out.")
        }
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Token", value: "{{token}}")]
        )

        let result = await send(request, through: transport)

        #expect(result == .failed(
            SendFailure(kind: .timedOut, description: "The request timed out."),
            notes: [.undefinedVariable("token")]
        ))
    }

    @Test("A cancelled send isn't a failure")
    func cancelled() async {
        let transport = RecordingTransport { throw CancellationError() }

        let result = await send(Request(name: "List", urlTemplate: "https://example.com"), through: transport)

        #expect(result == .cancelled)
    }

    @Test("A task cancelled before the send stops without reaching the transport")
    func cancelledBeforeSending() async {
        let transport = RecordingTransport()
        let sender = RequestSender(transport: transport, secretStore: secretStore)
        let outgoing = OutgoingRequest(request: Request(name: "List", urlTemplate: "https://example.com"))

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await sender.send(outgoing, scopes: VariableScopes())
        }

        #expect(await task.value == .cancelled)
        #expect(transport.requests.isEmpty)
    }

    @Test("A URL that can't be built sends nothing and claims nothing was sent as written")
    func invalidURL() async {
        let transport = RecordingTransport()

        let result = await send(Request(name: "List", urlTemplate: "{{host}}/users"), through: transport)

        #expect(transport.requests.isEmpty)
        #expect(result == .failed(
            SendFailure(kind: .notSent, description: "This URL isn’t valid."),
            notes: []
        ))
    }

    @Test("A secret store that fails stops the send")
    func failingSecretStore() async {
        let transport = RecordingTransport()
        let sender = RequestSender(transport: transport, secretStore: FailingSecretStore())
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            auth: .bearer(BearerAuth(token: SecretReference(identifier: "stored")))
        )

        let result = await sender.send(OutgoingRequest(request: request), scopes: VariableScopes())

        guard case .failed(let failure, _) = result else {
            Issue.record("Expected a failure, got \(result)")
            return
        }
        #expect(failure.kind == .notSent)
        #expect(transport.requests.isEmpty)
    }

}
