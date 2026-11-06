//  RequestSender.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

public nonisolated struct VariableScopes: Sendable, Hashable {

    public var collection: [Variable]
    public var environment: [Variable]
    public var globals: [Variable]

    public init(collection: [Variable] = [], environment: [Variable] = [], globals: [Variable] = []) {
        self.collection = collection
        self.environment = environment
        self.globals = globals
    }

}

/// Never logs: a request's URL, headers and body can each hold a secret.
public nonisolated struct RequestSender: Sendable {

    private let transport: any HTTPTransport
    private let secretStore: any SecretStore

    public init(transport: any HTTPTransport, secretStore: any SecretStore) {
        self.transport = transport
        self.secretStore = secretStore
    }

    @concurrent
    public func send(_ outgoing: OutgoingRequest, scopes: VariableScopes) async -> SendResult {
        let urlRequest: URLRequest
        let notes: [ResponseNote]
        do {
            let resolved = try await resolve(outgoing, scopes: scopes)
            let built = try await RequestBuilder().build(resolved)
            urlRequest = built.urlRequest
            notes = ResponseNote.notes(unresolved: resolved.unresolved, notices: built.notices)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(SendFailure(notSent: error), notes: [])
        }
        return await transmit(urlRequest, notes: notes)
    }

    private func resolve(_ outgoing: OutgoingRequest, scopes: VariableScopes) async throws -> ResolvedRequest {
        let credentials = TypedCredentialStore(typed: outgoing.typedCredentials, stored: secretStore)
        return try await VariableResolver(secretStore: credentials).resolve(
            outgoing.request,
            collection: scopes.collection,
            environment: scopes.environment,
            globals: scopes.globals
        )
    }

    private func transmit(_ request: URLRequest, notes: [ResponseNote]) async -> SendResult {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let response = try await transport.send(request)
            return .response(SentResponse(response, measured: start.duration(to: clock.now), notes: notes))
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(SendFailure(transportError: error), notes: notes)
        }
    }

}

/// Answers what the editor holds first, so an unsaved credential sends without reaching the Keychain.
private nonisolated struct TypedCredentialStore: SecretStore {

    private let typed: [String: String]
    private let stored: any SecretStore

    init(typed: [CredentialWrite], stored: any SecretStore) {
        self.typed = Dictionary(typed.map { ($0.reference.identifier, $0.value) }) { _, last in last }
        self.stored = stored
    }

    func save(_ value: String, for identifier: String) async throws {
        try await stored.save(value, for: identifier)
    }

    func value(for identifier: String) async throws -> String? {
        if let value = typed[identifier] {
            return value
        }
        return try await stored.value(for: identifier)
    }

    func removeValue(for identifier: String) async throws {
        try await stored.removeValue(for: identifier)
    }

}
