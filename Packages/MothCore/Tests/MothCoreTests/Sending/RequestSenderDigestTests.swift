//  RequestSenderDigestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

struct RequestSenderDigestTests {

    private static let password = SecretReference(identifier: "digest-password")
    private nonisolated static let challengeHeader = #"Digest realm="api", nonce="n", qop="auth", algorithm=SHA-256"#
    private nonisolated static let challenge = HTTPResponse(
        status: 401,
        headers: ["WWW-Authenticate": challengeHeader],
        body: Data("challenge".utf8)
    )
    private nonisolated static let accepted = HTTPResponse(status: 200, headers: [:], body: Data("ok".utf8))

    private let secretStore: any SecretStore = InMemorySecretStore()

    private static func digest(username: String = "ada") -> Auth {
        .digest(DigestAuth(username: username, password: password))
    }

    private func send(
        _ request: Request,
        scopes: VariableScopes = VariableScopes(),
        through transport: ScriptedTransport,
        password: String? = "Circle of Life"
    ) async throws -> SendResult {
        if let password {
            try await secretStore.save(password, for: Self.password.identifier)
        }
        let sender = RequestSender(transport: transport, secretStore: secretStore, cnonce: { "c" })
        return await sender.send(OutgoingRequest(request: request), scopes: scopes)
    }

    private func expectedAnswer(to request: URLRequest, username: String = "ada", password: String = "Circle of Life")
    throws -> String {
        let challenge = try #require(DigestChallenge.first(in: Self.challengeHeader))
        return DigestAuthProvider(username: username, password: password)
            .authorization(answering: challenge, to: request, cnonce: "c")
    }

    /// Bounded, so a sender that never answers fails the test rather than holding the build lock.
    private static func secondSend(of transport: ScriptedTransport, within limit: Duration) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await count in transport.arrivals where count == 2 {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: limit)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    private func response(of result: SendResult) throws -> SentResponse {
        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            throw CancellationError()
        }
        return response
    }

    @Test("The first send carries no Authorization header, even with a manual Authorization row")
    func firstSendHasNoAuthorization() async throws {
        let transport = ScriptedTransport(Self.accepted)
        let request = Request(
            name: "Digest",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "Authorization", value: "Basic abc")],
            auth: Self.digest()
        )

        let result = try await send(request, through: transport)

        #expect(transport.requests.count == 1)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try response(of: result).notes.isEmpty)
    }

    @Test("A Digest challenge is answered with one more send, and the final response carries the note")
    func answersTheChallenge() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.accepted)
        let request = Request(name: "Digest", urlTemplate: "https://example.com/dir?q=1", auth: Self.digest())

        let result = try await send(request, through: transport)

        let first = try #require(transport.requests.first)
        #expect(transport.requests.count == 2)
        #expect(try transport.requests.last?.value(forHTTPHeaderField: "Authorization") == expectedAnswer(to: first))
        let response = try response(of: result)
        #expect(response.status == 200)
        #expect(response.content == .text("ok"))
        #expect(response.notes == [.sentAgainForDigestChallenge])
    }

    @Test("The second send repeats the method, URL, headers and a POST body byte for byte")
    func repeatsTheRequest() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.accepted)
        let request = Request(
            name: "Create",
            method: .post,
            urlTemplate: "https://example.com/users?a=%2F",
            headers: [KeyValue(key: "X-Trace", value: "1"), KeyValue(key: "Accept", value: "application/json")],
            body: .raw(content: #"{"name":"Ada ✓"}"#, contentType: "application/json"),
            auth: Self.digest()
        )

        _ = try await send(request, through: transport)

        let first = try #require(transport.requests.first)
        let second = try #require(transport.requests.last)
        var answered = second.allHTTPHeaderFields ?? [:]
        answered["Authorization"] = nil
        #expect(transport.requests.count == 2)
        #expect(second.httpMethod == "POST")
        #expect(second.httpMethod == first.httpMethod)
        #expect(second.url == first.url)
        #expect(answered == first.allHTTPHeaderFields)
        #expect(second.httpBody == first.httpBody)
        #expect(second.httpBody == Data(#"{"name":"Ada ✓"}"#.utf8))
    }

    @Test(
        "A challenge Moth can't answer shows the 401 after one send, with a note",
        arguments: [
            #"Digest realm="api", nonce="n", qop="auth-int""#,
            #"Digest realm="api", nonce="n", qop="auth", algorithm=SHA-512-256"#
        ]
    )
    func unsupportedChallenge(header: String) async throws {
        let refused = HTTPResponse(status: 401, headers: ["WWW-Authenticate": header], body: Data())
        let transport = ScriptedTransport(refused, Self.accepted)

        let result = try await send(
            Request(name: "Digest", urlTemplate: "https://example.com", auth: Self.digest()),
            through: transport
        )

        let response = try response(of: result)
        #expect(transport.requests.count == 1)
        #expect(response.status == 401)
        #expect(response.notes == [.digestChallengeUnsupported])
    }

    @Test(
        "A 401 with no Digest challenge is shown after one send",
        arguments: [[:], ["WWW-Authenticate": #"Basic realm="api""#]]
    )
    func plainRefusal(headers: [String: String]) async throws {
        let transport = ScriptedTransport(HTTPResponse(status: 401, headers: headers, body: Data()), Self.accepted)

        let result = try await send(
            Request(name: "Digest", urlTemplate: "https://example.com", auth: Self.digest()),
            through: transport
        )

        let response = try response(of: result)
        #expect(transport.requests.count == 1)
        #expect(response.status == 401)
        #expect(response.notes.isEmpty)
    }

    @Test("A second 401 is shown, and nothing more is sent")
    func secondRefusal() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.challenge, Self.accepted)

        let result = try await send(
            Request(name: "Digest", urlTemplate: "https://example.com", auth: Self.digest()),
            through: transport
        )

        let response = try response(of: result)
        #expect(transport.requests.count == 2)
        #expect(response.status == 401)
        #expect(response.notes == [.sentAgainForDigestChallenge])
    }

    @Test("Cancelling during the second send cancels the send")
    func cancelDuringTheAnswer() async throws {
        let transport = ScriptedTransport([
            { Self.challenge },
            {
                try await Task.sleep(for: .seconds(600))
                return Self.accepted
            }
        ])
        try await secretStore.save("Circle of Life", for: Self.password.identifier)
        let sender = RequestSender(transport: transport, secretStore: secretStore, cnonce: { "c" })
        let request = Request(name: "Digest", urlTemplate: "https://example.com", auth: Self.digest())

        let task = Task { await sender.send(OutgoingRequest(request: request), scopes: VariableScopes()) }
        let answerArrived = await Self.secondSend(of: transport, within: .seconds(10))
        task.cancel()

        #expect(answerArrived)
        #expect(await task.value == .cancelled)
        #expect(transport.requests.count == 2)
    }

    @Test("The username and password resolve their variables before the answer is worked out")
    func variablesResolve() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.accepted)
        let request = Request(
            name: "Digest",
            urlTemplate: "https://example.com",
            auth: Self.digest(username: "{{user}}")
        )

        _ = try await send(
            request,
            scopes: VariableScopes(environment: [.plain("user", "ada"), .plain("secret", "Circle of Life")]),
            through: transport,
            password: "{{secret}}"
        )

        let first = try #require(transport.requests.first)
        #expect(try transport.requests.last?.value(forHTTPHeaderField: "Authorization") == expectedAnswer(to: first))
    }

    @Test("A password with no stored value sends once, and the 401 says the credential is missing")
    func missingPassword() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.accepted)

        let result = try await send(
            Request(name: "Digest", urlTemplate: "https://example.com", auth: Self.digest()),
            through: transport,
            password: nil
        )

        let response = try response(of: result)
        #expect(transport.requests.count == 1)
        #expect(response.status == 401)
        #expect(response.notes == [.missingCredential])
    }

    @Test("A Digest challenge to a request with another auth is shown as it is")
    func otherAuth() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.accepted)
        let request = Request(
            name: "Basic",
            urlTemplate: "https://example.com",
            auth: .basic(BasicAuth(username: "ada", password: Self.password))
        )

        let result = try await send(request, through: transport)

        #expect(transport.requests.count == 1)
        #expect(try response(of: result).notes.isEmpty)
    }

    @Test("A folder's Digest Auth reaches a request that inherits, and answers its challenge")
    func inherited() async throws {
        let transport = ScriptedTransport(Self.challenge, Self.accepted)
        var request = Request(name: "Inherits", urlTemplate: "https://example.com")
        let folder = Folder(
            name: "Digest",
            auth: Self.digest(),
            children: [CollectionItem(sortOrder: 0, node: .request(request))]
        )
        let collection = RequestCollection(name: "API", children: [CollectionItem(sortOrder: 0, node: .folder(folder))])
        request.auth = collection.effectiveAuth(of: request)

        _ = try await send(request, through: transport)

        let first = try #require(transport.requests.first)
        #expect(transport.requests.count == 2)
        #expect(try transport.requests.last?.value(forHTTPHeaderField: "Authorization") == expectedAnswer(to: first))
    }

}

extension RequestSenderDigestTests {

    @Test("A challenge from a same-origin redirect is answered at the URL that sent it")
    func sameOriginRedirect() async throws {
        let redirected = HTTPResponse(
            status: 401,
            headers: ["WWW-Authenticate": Self.challengeHeader],
            body: Data(),
            url: URL(string: "https://example.com/b?x=1")
        )
        let transport = ScriptedTransport(redirected, Self.accepted)

        _ = try await send(
            Request(name: "Digest", urlTemplate: "https://example.com/a", auth: Self.digest()),
            through: transport
        )

        let answer = try #require(transport.requests.last)
        #expect(transport.requests.count == 2)
        #expect(answer.url?.absoluteString == "https://example.com/b?x=1")
        #expect(try answer.value(forHTTPHeaderField: "Authorization") == expectedAnswer(to: answer))
        #expect(answer.value(forHTTPHeaderField: "Authorization")?.contains(#"uri="/b?x=1""#) == true)
    }

    @Test(
        "A challenge from a redirect to another origin is shown with a note, and nothing is sent there",
        arguments: ["https://other.example/a", "http://example.com/a", "https://example.com:8443/a"]
    )
    func crossOriginRedirect(address: String) async throws {
        let redirected = HTTPResponse(
            status: 401,
            headers: ["WWW-Authenticate": Self.challengeHeader],
            body: Data(),
            url: URL(string: address)
        )
        let transport = ScriptedTransport(redirected, Self.accepted)

        let result = try await send(
            Request(name: "Digest", urlTemplate: "https://example.com/a", auth: Self.digest()),
            through: transport
        )

        let response = try response(of: result)
        #expect(transport.requests.count == 1)
        #expect(response.status == 401)
        #expect(response.notes == [.digestChallengeAfterRedirect])
    }

    @Test(
        "A request with a body isn't answered after a redirect, which may have changed its method",
        arguments: [HTTPMethod.post, .put, .patch, .delete]
    )
    func redirectedRequestWithABody(method: HTTPMethod) async throws {
        let redirected = HTTPResponse(
            status: 401,
            headers: ["WWW-Authenticate": Self.challengeHeader],
            body: Data(),
            url: URL(string: "https://example.com/account")
        )
        let transport = ScriptedTransport(redirected, Self.accepted)
        let request = Request(
            name: "Login",
            method: method,
            urlTemplate: "https://example.com/login",
            body: .raw(content: "name=ada", contentType: "application/x-www-form-urlencoded"),
            auth: Self.digest()
        )

        let result = try await send(request, through: transport)

        let response = try response(of: result)
        #expect(transport.requests.count == 1)
        #expect(response.status == 401)
        #expect(response.notes == [.digestChallengeAfterRedirect])
    }

    @Test("An answer that fails to send keeps the note, and is timed alone")
    func answerFails() async throws {
        let transport = ScriptedTransport([
            {
                try await Task.sleep(for: .milliseconds(300))
                return Self.challenge
            },
            { throw HTTPTransportError.timedOut(description: "The request timed out.") }
        ])

        try await secretStore.save("Circle of Life", for: Self.password.identifier)
        let sender = RequestSender(transport: transport, secretStore: secretStore, cnonce: { "c" })
        let request = Request(name: "Digest", urlTemplate: "https://example.com", auth: Self.digest())

        let recorded = await sender.sendRecording(OutgoingRequest(request: request), scopes: VariableScopes())

        guard case .failed(let failure, let notes) = recorded.result else {
            Issue.record("Expected a failure, got \(recorded.result)")
            return
        }
        #expect(transport.requests.count == 2)
        #expect(failure.kind == .timedOut)
        #expect(notes == [.sentAgainForDigestChallenge])
        #expect(try #require(recorded.entry).duration < .milliseconds(300))
    }

}
