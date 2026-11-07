//  AccessTokensTests.swift
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
struct AccessTokensTests {

    private nonisolated static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let secretStore = RecordingSecretStore()

    private func accessTokens(transport: any HTTPTransport = StubHTTPTransport()) -> AccessTokens {
        AccessTokens(tokens: OAuth2Tokens(
            transport: transport,
            secretStore: secretStore,
            now: { Self.now }
        )) { source in
            guard case .container(_, let draft, _) = source else {
                throw CancellationError()
            }
            return (
                OutgoingRequest(request: Request(name: "Users", auth: draft.requestAuth)),
                VariableScopes()
            )
        }
    }

    private func draft(tokenURL: String) -> AuthDraft {
        var draft = AuthDraft(.none)
        draft.kind = .oauth2
        draft.oauth2.tokenURL = tokenURL
        draft.oauth2.clientID = "moth"
        return draft
    }

    private func source(_ draft: AuthDraft) -> AccessTokens.Source {
        .container(.folder(UUID()), draft, .empty)
    }

    @Test("Get New Access Token stores the token and shows when it expires")
    func getsAToken() async {
        let tokens = accessTokens()
        let draft = draft(tokenURL: "https://stub.invalid/token")
        let reference = draft.oauth2.accessTokenReference

        await tokens.getNewToken(for: reference, from: source(draft))

        let token = OAuth2Token(value: "stub-access-token", expiresAt: Self.now.addingTimeInterval(3600))
        #expect(tokens.status(of: reference) == .token(token))
        #expect(tokens.failure(of: reference) == nil)
        #expect(!tokens.isFetching(reference))
        #expect(secretStore.values[reference.identifier] != nil)
    }

    @Test("A refused token request shows the server's error and stores nothing")
    func refusalShowsTheError() async {
        let tokens = accessTokens()
        let draft = draft(tokenURL: "https://stub.invalid/token/refused")
        let reference = draft.oauth2.accessTokenReference

        await tokens.getNewToken(for: reference, from: source(draft))

        #expect(tokens.failure(of: reference) == "invalid_client: Client authentication failed.")
        #expect(tokens.status(of: reference) == .none)
        #expect(secretStore.values.isEmpty)
    }

    @Test("A later Get New Access Token that works clears the earlier failure")
    func successClearsFailure() async {
        let tokens = accessTokens()
        var draft = draft(tokenURL: "https://stub.invalid/token/refused")
        let reference = draft.oauth2.accessTokenReference
        await tokens.getNewToken(for: reference, from: source(draft))

        draft.oauth2.tokenURL = "https://stub.invalid/token"
        await tokens.getNewToken(for: reference, from: source(draft))

        #expect(tokens.failure(of: reference) == nil)
    }

    @Test("Clear Token removes the token from the secret store")
    func clearRemovesTheSecret() async {
        let tokens = accessTokens()
        let draft = draft(tokenURL: "https://stub.invalid/token")
        let reference = draft.oauth2.accessTokenReference
        await tokens.getNewToken(for: reference, from: source(draft))

        await tokens.clear(reference)

        #expect(secretStore.values[reference.identifier] == nil)
        #expect(tokens.status(of: reference) == .none)
    }

    @Test("A token's state loads from the secret store, and one never read is loading")
    func loads() async {
        let draft = draft(tokenURL: "https://stub.invalid/token/forever")
        let stored = draft.oauth2.accessTokenReference
        let missing = SecretReference(identifier: "missing")
        await accessTokens().getNewToken(for: stored, from: source(draft))
        let tokens = accessTokens()

        #expect(tokens.status(of: stored) == .loading)
        await tokens.load(stored)
        await tokens.load(missing)

        #expect(tokens.status(of: stored) == .token(OAuth2Token(value: "stub-access-token", expiresAt: nil)))
        #expect(tokens.status(of: missing) == .none)
    }

    @Test("Reloading after a send picks up a token stored elsewhere")
    func reloadsAfterASend() async {
        let draft = draft(tokenURL: "https://stub.invalid/token/forever")
        let reference = draft.oauth2.accessTokenReference
        let tokens = accessTokens()
        await tokens.load(reference)
        await accessTokens().getNewToken(for: reference, from: source(draft))

        await tokens.reloadLoaded()

        #expect(tokens.status(of: reference) == .token(OAuth2Token(value: "stub-access-token", expiresAt: nil)))
    }

    @Test("A folder's token resolves its collection's variables and the active environment's")
    func folderScopes() async throws {
        let transport = RecordingHTTPTransport()
        let folder = Folder(name: "Users")
        let collection = RequestCollection(
            name: "API",
            variables: [Variable(name: "path", value: .plain(initial: "/oauth/token", current: "/oauth/token"))],
            children: [CollectionItem(sortOrder: 0, node: .folder(folder))]
        )
        let environment = WorkspaceEnvironment(name: "Staging", variables: [
            Variable(name: "authHost", value: .plain(initial: "", current: "https://login.staging.test"))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection], environments: [environment]))
        let tree = try CollectionTree(
            collections: dataModel.mainContext.fetch(.init()),
            folders: dataModel.mainContext.fetch(.init()),
            requests: dataModel.mainContext.fetch(.init())
        )
        let tokens = AccessTokens(
            dataModel: dataModel,
            transport: transport,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: environment.id)
        )
        let draft = draft(tokenURL: "{{authHost}}{{path}}")

        await tokens.getNewToken(
            for: draft.oauth2.accessTokenReference,
            from: .container(.folder(folder.id), draft, tree)
        )

        withExtendedLifetime(dataModel) {
            #expect(transport.requests.first?.url?.absoluteString == "https://login.staging.test/oauth/token")
        }
    }

}
