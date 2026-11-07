//  RequestSenderCookieTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderCookieTests {

    @Test("The workspace's cookie jar goes to the transport with the request")
    func passesTheCookieJar() async throws {
        let transport = RecordingTransport()
        let jar = InMemoryCookieJar()
        let sender = RequestSender(transport: transport, secretStore: InMemorySecretStore())

        _ = await sender.send(
            OutgoingRequest(request: Request(name: "List", urlTemplate: "https://example.com/users")),
            scopes: VariableScopes(),
            cookies: jar
        )

        let sent = try #require(transport.cookieJars.first as? InMemoryCookieJar)
        #expect(sent === jar)
    }

    @Test("A Digest answer goes with the same jar, so a cookie the refusal set goes with it")
    func digestAnswerUsesTheJar() async {
        let password = SecretReference(identifier: "digest-password")
        let secrets = InMemorySecretStore()
        await secrets.save("Circle of Life", for: password.identifier)
        let challenge = HTTPResponse(
            status: 401,
            headers: ["WWW-Authenticate": #"Digest realm="api", nonce="n", qop="auth", algorithm=SHA-256"#],
            body: Data()
        )
        let transport = ScriptedTransport(challenge, HTTPResponse(status: 200, headers: [:], body: Data()))
        let jar = InMemoryCookieJar()
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com/users",
            auth: .digest(DigestAuth(username: "ada", password: password))
        )

        _ = await RequestSender(transport: transport, secretStore: secrets)
            .send(OutgoingRequest(request: request), scopes: VariableScopes(), cookies: jar)

        #expect(transport.cookieJars.count == 2)
        #expect(transport.cookieJars.allSatisfy { ($0 as? InMemoryCookieJar) === jar })
    }

    @Test("Without a jar the transport gets none")
    func noJar() async {
        let transport = RecordingTransport()
        let sender = RequestSender(transport: transport, secretStore: InMemorySecretStore())

        _ = await sender.send(
            OutgoingRequest(request: Request(name: "List", urlTemplate: "https://example.com/users")),
            scopes: VariableScopes()
        )

        #expect(transport.cookieJars.count == 1)
        #expect(transport.cookieJars.first.flatMap(\.self) == nil)
    }

}
