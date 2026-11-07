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
    /// Moves on with each Get New Access Token and Clear Token, so a read that started before one can't undo it.
    private var generations: [SecretReference: Int] = [:]
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
        let generation = generations[reference, default: 0]
        let status: Status
        do {
            status = try await tokens.token(for: reference).map(Status.token) ?? Status.none
        } catch {
            Logger.editor.error("Reading a token failed: \(String(describing: error), privacy: .private)")
            status = Status.none
        }
        if generations[reference, default: 0] == generation {
            statuses[reference] = status
        }
    }

    func getNewToken(for reference: SecretReference, from source: Source) async {
        guard fetching.insert(reference).inserted else {
            return
        }
        defer { fetching.remove(reference) }
        generations[reference, default: 0] += 1
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
        generations[reference, default: 0] += 1
        do {
            try await tokens.clearToken(for: reference)
        } catch {
            Logger.editor.error("Clearing a token failed: \(String(describing: error), privacy: .private)")
        }
        await load(reference)
    }

}
