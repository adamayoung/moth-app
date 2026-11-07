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
