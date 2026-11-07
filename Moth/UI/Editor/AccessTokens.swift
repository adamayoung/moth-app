//  AccessTokens.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Observation
import OSLog

/// One for each window: the OAuth 2.0 token state its editors and sheets show, keyed by the auth's token reference, so
/// every request inheriting an auth sees the same token.
@Observable
final class AccessTokens {

    enum Source {

        case request(Request.ID, RequestDraft, CollectionTree)
        case container(TreeContainerID, AuthDraft, CollectionTree)

    }

    enum Status: Equatable {

        case loading
        case none
        case token(OAuth2Token)

    }

    /// What a Get New Access Token resolves: the auth as the editor holds it, and the variables in its scope.
    typealias Prepare = @MainActor (Source) throws -> (OutgoingRequest, VariableScopes)

    private var statuses: [SecretReference: Status] = [:]
    private var fetching: Set<SecretReference> = []
    private var failures: [SecretReference: String] = [:]
    private let tokens: OAuth2Tokens
    private let prepare: Prepare

    init(tokens: OAuth2Tokens, prepare: @escaping Prepare) {
        self.tokens = tokens
        self.prepare = prepare
    }

    convenience init(
        dataModel: DataModel,
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        activeEnvironment: ActiveEnvironment
    ) {
        self.init(tokens: OAuth2Tokens(transport: transport, secretStore: secretStore)) { source in
            switch source {
            case .request(let id, let draft, let tree):
                let context = try dataModel.sendContext(for: id, in: tree, environment: activeEnvironment.id)
                return try (draft.outgoing(from: context.request, in: tree), context.scopes)
            case .container(let container, let draft, let tree):
                let request = Request(name: "", auth: draft.requestAuth)
                return try (
                    OutgoingRequest(request: request, typedCredentials: draft.credentialWrites()),
                    dataModel.variableScopes(for: container, in: tree, environment: activeEnvironment.id)
                )
            }
        }
    }

    /// New on every use, because previews share one process and one would otherwise show another's tokens.
    static var preview: AccessTokens {
        AccessTokens(tokens: OAuth2Tokens(transport: StubHTTPTransport(), secretStore: InMemorySecretStore())) { _ in
            throw CancellationError()
        }
    }

    func status(of reference: SecretReference) -> Status {
        statuses[reference] ?? .loading
    }

    func isFetching(_ reference: SecretReference) -> Bool {
        fetching.contains(reference)
    }

    func failure(of reference: SecretReference) -> String? {
        failures[reference]
    }

    func load(_ reference: SecretReference) async {
        do {
            statuses[reference] = try await tokens.token(for: reference).map(Status.token) ?? Status.none
        } catch {
            Logger.editor.error("Reading a token failed: \(String(describing: error), privacy: .private)")
            statuses[reference] = Status.none
        }
    }

    /// A send may have stored a token, so every token on show is read again.
    func reloadLoaded() async {
        for reference in statuses.keys {
            await load(reference)
        }
    }

    func getNewToken(for reference: SecretReference, from source: Source) async {
        guard fetching.insert(reference).inserted else {
            return
        }
        defer { fetching.remove(reference) }
        failures[reference] = nil
        do {
            let (outgoing, scopes) = try prepare(source)
            statuses[reference] = try await .token(tokens.getNewToken(for: outgoing, scopes: scopes))
        } catch is CancellationError {
            return
        } catch {
            failures[reference] = error.localizedDescription
            await load(reference)
        }
    }

    func clear(_ reference: SecretReference) async {
        do {
            try await tokens.clearToken(for: reference)
        } catch {
            Logger.editor.error("Clearing a token failed: \(String(describing: error), privacy: .private)")
        }
        await load(reference)
    }

}
