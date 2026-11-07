//  RequestSenderOAuth2Tests+Reuse.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

/// When a stored token is reused, replaced or never asked for.
extension RequestSenderOAuth2Tests {

    @Test("An auth with no token reference stores its token under one derived from the auth, and reuses it")
    func noReferenceUsesTheDerivedOne() async throws {
        let transport = ScriptedTransport(Self.issued, Self.accepted)
        let auth = Self.oauth2(accessToken: nil)
        guard case .oauth2(let oauth2) = auth else {
            throw CancellationError()
        }

        _ = await sender(transport).send(OutgoingRequest(request: Self.request(auth: auth)), scopes: VariableScopes())
        _ = await sender(transport).send(OutgoingRequest(request: Self.request(auth: auth)), scopes: VariableScopes())

        #expect(transport.requests.map { $0.url?.path() } == ["/token", "/users", "/users"])
        #expect(await secretStore.value(for: oauth2.tokenReference.identifier) != nil)
    }

    @Test("A token got for one Token URL, Client ID and Scope isn't sent for another, such as another environment's")
    func tokenIsntReusedAcrossEnvironments() async {
        let transport = ScriptedTransport(Self.issued, Self.accepted, Self.issued, Self.accepted)
        let request = Self.request(auth: Self.oauth2(tokenURL: "{{authHost}}/token"))
        func environment(_ host: String) -> VariableScopes {
            VariableScopes(environment: [Variable(name: "authHost", value: .plain(initial: "", current: host))])
        }

        _ = await sender(transport).send(OutgoingRequest(request: request), scopes: environment("https://staging.test"))
        _ = await sender(transport).send(OutgoingRequest(request: request), scopes: environment("https://login.test"))

        #expect(transport.requests.map { $0.url?.absoluteString } == [
            "https://staging.test/token",
            "https://api.example.com/users",
            "https://login.test/token",
            "https://api.example.com/users"
        ])
    }

    @Test("An imported token, which has no record of where it came from, is replaced on the first send")
    func importedTokenIsReplaced() async {
        await secretStore.save("imported", for: Self.accessToken.identifier)
        let transport = ScriptedTransport(Self.issued, Self.accepted)

        _ = await sender(transport).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer issued-tok")
    }

    @Test("A request that can't be built sends no token request, so the client secret stays home")
    func unbuildableRequestSendsNoTokenRequest() async {
        let transport = ScriptedTransport(Self.issued, Self.accepted)
        var request = Self.request()
        request.urlTemplate = "not a url"

        let result = await sender(transport).send(OutgoingRequest(request: request), scopes: VariableScopes())

        #expect(transport.requests.isEmpty)
        guard case .failed(let failure, _) = result else {
            Issue.record("Expected a failure, got \(result)")
            return
        }
        #expect(failure.kind == .notSent)
    }

    @Test("A failed token request keeps the note naming a variable that didn't resolve")
    func tokenFailureKeepsNotes() async {
        let transport = ScriptedTransport(Self.issued, Self.accepted)
        let request = Self.request(auth: Self.oauth2(tokenURL: "{{tokenURL}}"))

        let result = await sender(transport).send(OutgoingRequest(request: request), scopes: VariableScopes())

        guard case .failed(let failure, let notes) = result else {
            Issue.record("Expected a failure, got \(result)")
            return
        }
        #expect(failure.kind == .accessTokenFailed)
        #expect(notes == [.undefinedVariable("tokenURL")])
    }

}
