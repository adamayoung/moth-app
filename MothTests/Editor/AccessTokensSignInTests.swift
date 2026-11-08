//  AccessTokensSignInTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct AccessTokensSignInTests {

    private let secretStore = RecordingSecretStore()

    private func accessTokens() -> AccessTokens {
        AccessTokens(tokens: OAuth2Tokens(transport: StubHTTPTransport(), secretStore: secretStore)) { source in
            guard case .container(_, let draft, _) = source else {
                throw CancellationError()
            }
            return (OutgoingRequest(request: Request(name: "Me", auth: draft.requestAuth)), VariableScopes())
        }
    }

    /// Stored, because each new draft mints its own token reference.
    private static let draft: AuthDraft = {
        var draft = AuthDraft(.none)
        draft.kind = .oauth2
        draft.oauth2.grantType = .authorizationCodeWithPKCE
        draft.oauth2.authorizationURL = "https://stub.invalid/authorize"
        draft.oauth2.tokenURL = "https://stub.invalid/token"
        draft.oauth2.clientID = "moth"
        return draft
    }()

    private static let source = AccessTokens.Source.container(.folder(UUID()), draft, .empty)

    /// Answers as a provider that signs the person in at once, echoing the state it was sent.
    private static func approve(_ url: URL, _: String) throws -> URL {
        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "state" }?.value ?? ""
        return try #require(URL(string: "moth://oauth/callback?code=c0de&state=\(state)"))
    }

    @Test("Get New Access Token signs in, then stores and shows the token")
    func signsIn() async {
        let tokens = accessTokens()
        let reference = Self.draft.oauth2.accessTokenReference
        let opened = OpenedURLs()

        await tokens.getNewToken(for: reference, from: Self.source) { url, scheme in
            opened.urls.append(url)
            return try Self.approve(url, scheme)
        }

        #expect(opened.urls.first?.host() == "stub.invalid")
        guard case .token(let token) = tokens.status(of: reference) else {
            Issue.record("Expected a token, got \(tokens.status(of: reference))")
            return
        }
        #expect(token.value == "stub-access-token")
        #expect(tokens.failure(of: reference) == nil)
        #expect(secretStore.values[reference.identifier] != nil)
    }

    @Test("Cancelling the sign-in leaves the token state as it was, with no error")
    func cancelLeavesTheState() async {
        let tokens = accessTokens()
        let reference = Self.draft.oauth2.accessTokenReference
        await tokens.getNewToken(for: reference, from: Self.source, signIn: Self.approve)
        let before = tokens.status(of: reference)

        await tokens.getNewToken(for: reference, from: Self.source) { _, _ in throw CancellationError() }

        #expect(tokens.status(of: reference) == before)
        #expect(tokens.failure(of: reference) == nil)
        #expect(!tokens.isFetching(reference))
    }

    @Test("A provider's error shows under Couldn’t Get Access Token with its description")
    func providerErrorShows() async throws {
        let tokens = accessTokens()
        let reference = Self.draft.oauth2.accessTokenReference
        let denied = try #require(URL(
            string: "moth://oauth/callback?error=access_denied&error_description=The%20user%20said%20no."
        ))

        await tokens.getNewToken(for: reference, from: Self.source) { _, _ in denied }

        #expect(tokens.failure(of: reference) == "access_denied: The user said no.")
        #expect(tokens.status(of: reference) == .none)
    }

}

@MainActor
private final class OpenedURLs {

    var urls: [URL] = []

}
