//  RequestSenderHistoryTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import SwiftData
import Testing

struct RequestSenderHistoryTests {
    private let secretStore: any SecretStore = InMemorySecretStore()
    private let sentAt = Date(timeIntervalSinceReferenceDate: 5000)

    private func sender(_ transport: RecordingTransport) -> RequestSender {
        RequestSender(transport: transport, secretStore: secretStore, now: { [sentAt] in sentAt })
    }

    private func record(
        _ request: Request,
        scopes: VariableScopes = VariableScopes(),
        through transport: RecordingTransport = RecordingTransport()
    ) async -> RecordedSend {
        await sender(transport).sendRecording(OutgoingRequest(request: request), scopes: scopes)
    }

    @Test("A response is recorded with its status, headers, body, timing and send time")
    func responseIsRecorded() async throws {
        let transport = RecordingTransport {
            HTTPResponse(
                status: 201,
                headers: ["Content-Type": "text/plain"],
                body: Data("made".utf8),
                metrics: HTTPMetrics(totalTime: .milliseconds(40), dns: .milliseconds(3))
            )
        }
        let request = Request(name: "Make", method: .post, urlTemplate: "https://example.com/items")

        let recorded = await record(request, through: transport)

        let entry = try #require(recorded.entry)
        let response = try #require(entry.response)
        #expect(entry.request.id == request.id)
        #expect(entry.request.urlTemplate == "https://example.com/items")
        #expect(entry.sentAt == sentAt)
        #expect(entry.duration == .milliseconds(40))
        #expect(entry.failure == nil)
        #expect(response.status == 201)
        #expect(response.reasonPhrase == "Created")
        #expect(response.headers.map(\.key) == ["Content-Type"])
        #expect(response.timing == [PhaseTiming(phase: .dns, duration: .milliseconds(3))])
        #expect(response.size == 4)
        #expect(response.body == Data("made".utf8))
    }

    @Test("A failed send is recorded with its failure")
    func failureIsRecorded() async throws {
        let transport = RecordingTransport { throw HTTPTransportError.connectionFailed(description: "Refused.") }

        let recorded = await record(Request(name: "Ping", urlTemplate: "https://example.com"), through: transport)

        let entry = try #require(recorded.entry)
        #expect(entry.response == nil)
        #expect(entry.failure?.kind == .couldNotConnect)
    }

    @Test("A send that couldn't be built is recorded as not sent")
    func notSentIsRecorded() async throws {
        let recorded = await record(Request(name: "Broken", urlTemplate: "{{host}}/users"))

        let entry = try #require(recorded.entry)
        #expect(entry.failure?.kind == .notSent)
        #expect(entry.request.urlTemplate == "{{host}}/users")
    }

    @Test("A cancelled send isn't recorded")
    func cancelIsNotRecorded() async {
        let transport = RecordingTransport { throw CancellationError() }

        let recorded = await record(Request(name: "Ping", urlTemplate: "https://example.com"), through: transport)

        #expect(recorded.result == .cancelled)
        #expect(recorded.entry == nil)
    }

    @Test("A body over 5 MB keeps its size and no body, and one at 5 MB is kept")
    func bodyLimit() async throws {
        for (size, isKept) in [(HistoryResponse.bodyLimit, true), (HistoryResponse.bodyLimit + 1, false)] {
            let transport = RecordingTransport {
                HTTPResponse(status: 200, headers: [:], body: Data(repeating: 65, count: size))
            }

            let recorded = await record(Request(name: "Big", urlTemplate: "https://example.com"), through: transport)

            let response = try #require(recorded.entry?.response)
            #expect(response.size == size)
            #expect((response.body != nil) == isKept)
        }
    }

    @Test("The snapshot keeps a secret variable as {{name}} and resolves a plain one")
    func snapshotKeepsSecretVariables() async throws {
        let token = Variable(name: "token", value: .secret(SecretReference(identifier: "token-ref")))
        try await secretStore.save("s3cret-variable", for: "token-ref")
        let request = Request(
            name: "List",
            urlTemplate: "{{host}}/users",
            headers: [KeyValue(key: "X-Token", value: "{{token}}")]
        )

        let recorded = await record(
            request,
            scopes: VariableScopes(environment: [.plain("host", "https://example.com"), token])
        )

        let snapshot = try #require(recorded.entry?.request)
        #expect(snapshot.urlTemplate == "https://example.com/users")
        #expect(snapshot.headers.map(\.value) == ["{{token}}"])
        let kept = snapshot.variables.first { $0.name == "token" }
        #expect(kept?.secretReference == SecretReference(identifier: "token-ref"))
    }

    @Test("Send Again resolves a variable that a secret's own value names")
    func sendAgainResolvesWhatASecretNames() async throws {
        let token = Variable(name: "token", value: .secret(SecretReference(identifier: "token-ref")))
        try await secretStore.save("{{user}}-key", for: "token-ref")
        let first = await record(
            Request(name: "List", urlTemplate: "https://example.com/{{token}}"),
            scopes: VariableScopes(environment: [.plain("user", "ada"), token])
        )
        let entry = try #require(first.entry)
        let transport = RecordingTransport()

        _ = await sender(transport).sendAgain(entry)

        #expect(transport.requests.first?.url?.absoluteString == "https://example.com/ada-key")
    }

    @Test("The snapshot holds the dynamic values that were sent")
    func snapshotHoldsTheSentDynamicValues() async throws {
        let transport = RecordingTransport()

        let recorded = await record(
            Request(name: "Make", urlTemplate: "https://example.com/{{$guid}}/{{$guid}}"),
            through: transport
        )

        let sent = try #require(transport.requests.first?.url?.absoluteString)
        #expect(recorded.entry?.request.urlTemplate == sent)
    }

    @Test("No secret reaches the stored row, and an Authorization row is masked")
    func storedRowHoldsNoSecret() async throws {
        let token = Variable(name: "token", value: .secret(SecretReference(identifier: "token-ref")))
        try await secretStore.save("s3cret-variable", for: "token-ref")
        try await secretStore.save("s3cret-credential", for: "bearer-ref")
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com/{{token}}",
            headers: [
                KeyValue(key: "Authorization", value: "Bearer typed-in-token"),
                KeyValue(key: "X-Token", value: "{{token}}")
            ],
            auth: .bearer(BearerAuth(token: SecretReference(identifier: "bearer-ref")))
        )
        let recorded = await record(request, scopes: VariableScopes(environment: [token]))
        let entry = try #require(recorded.entry)
        let dataModel = try DataModel.inMemory()

        try await dataModel.writer.addHistoryEntry(entry)

        let row = try #require(try ModelContext(dataModel.container).fetch(FetchDescriptor<HistoryEntryModel>()).first)
        let stored = try #require(String(bytes: row.requestData ?? Data(), encoding: .utf8)) + row.url
        #expect(!stored.contains("s3cret-variable"))
        #expect(!stored.contains("s3cret-credential"))
        #expect(!stored.contains("typed-in-token"))
        #expect(entry.request.headers.first?.value == HistoryEntry.maskedValue)
    }

    @Test("An API key's own header row is masked")
    func apiKeyRowIsMasked() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Api-Key", value: "typed-key")],
            auth: .apiKey(APIKeyAuth(name: "x-api-key", value: SecretReference(identifier: "k"), location: .header))
        )

        let recorded = await record(request)

        #expect(recorded.entry?.request.headers.map(\.value) == [HistoryEntry.maskedValue])
    }

    @Test("Send Again sends the snapshot with the current secret value, and records a new entry")
    func sendAgainUsesTheCurrentSecret() async throws {
        let token = Variable(name: "token", value: .secret(SecretReference(identifier: "token-ref")))
        try await secretStore.save("old", for: "token-ref")
        let first = await record(
            Request(name: "List", urlTemplate: "https://example.com/{{token}}"),
            scopes: VariableScopes(globals: [token])
        )
        let entry = try #require(first.entry)
        try await secretStore.save("new", for: "token-ref")
        let transport = RecordingTransport()

        let outcome = await sender(transport).sendAgain(entry)

        guard case .sent(let again) = outcome else {
            Issue.record("Expected a send, got \(outcome)")
            return
        }
        #expect(transport.requests.first?.url?.absoluteString == "https://example.com/new")
        #expect(again.entry?.id != entry.id)
        #expect(again.entry?.request.urlTemplate == "https://example.com/{{token}}")
    }

    @Test("Send Again with a secret that has gone sends nothing")
    func sendAgainWithAMissingSecret() async throws {
        let token = Variable(name: "token", value: .secret(SecretReference(identifier: "token-ref")))
        try await secretStore.save("old", for: "token-ref")
        let first = await record(
            Request(name: "List", urlTemplate: "https://example.com/{{token}}"),
            scopes: VariableScopes(globals: [token])
        )
        let entry = try #require(first.entry)
        try await secretStore.removeValue(for: "token-ref")
        let transport = RecordingTransport()

        let outcome = await sender(transport).sendAgain(entry)

        #expect(outcome == .secretUnavailable)
        #expect(transport.requests.isEmpty)
    }

    @Test("Send Again with a credential that has gone sends nothing")
    func sendAgainWithAMissingCredential() async {
        let auth = Auth.bearer(BearerAuth(token: SecretReference(identifier: "bearer-ref")))
        let entry = HistoryEntry(
            request: Request(name: "List", urlTemplate: "https://example.com", auth: auth),
            sentAt: sentAt,
            duration: .zero
        )
        let transport = RecordingTransport()

        let outcome = await sender(transport).sendAgain(entry)

        #expect(outcome == .secretUnavailable)
        #expect(transport.requests.isEmpty)
    }

    @Test("Send Again with a masked row the auth won't replace sends nothing, and one it replaces is sent")
    func sendAgainWithAMaskedRow() async throws {
        try await secretStore.save("token", for: "bearer-ref")
        let masked = [KeyValue(key: "Authorization", value: HistoryEntry.maskedValue)]
        let bearer = Auth.bearer(BearerAuth(token: SecretReference(identifier: "bearer-ref")))
        let transport = RecordingTransport()

        let unreplaced = await sender(transport).sendAgain(HistoryEntry(
            request: Request(name: "List", urlTemplate: "https://example.com", headers: masked, auth: .none),
            sentAt: sentAt,
            duration: .zero
        ))
        let replaced = await sender(transport).sendAgain(HistoryEntry(
            request: Request(name: "List", urlTemplate: "https://example.com", headers: masked, auth: bearer),
            sentAt: sentAt,
            duration: .zero
        ))

        #expect(unreplaced == .secretUnavailable)
        #expect(replaced != .secretUnavailable)
        #expect(transport.requests.map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer token"])
    }

    @Test("Send Again with a masked row under an auth that has no provider sends nothing")
    func sendAgainWithAMaskedRowUnderOAuth2() async throws {
        try await secretStore.save("secret", for: "client-secret")
        let oauth2 = Auth.oauth2(OAuth2Auth(
            grantType: .implicit,
            authorizationURL: "",
            accessTokenURL: "https://example.com/token",
            callbackURL: "",
            clientID: "moth",
            clientSecret: SecretReference(identifier: "client-secret"),
            scope: ""
        ))
        let transport = RecordingTransport()

        let outcome = await sender(transport).sendAgain(HistoryEntry(
            request: Request(
                name: "List",
                urlTemplate: "https://example.com",
                headers: [KeyValue(key: "Authorization", value: HistoryEntry.maskedValue)],
                auth: oauth2
            ),
            sentAt: sentAt,
            duration: .zero
        ))

        #expect(outcome == .secretUnavailable)
        #expect(transport.requests.isEmpty)
    }
}
