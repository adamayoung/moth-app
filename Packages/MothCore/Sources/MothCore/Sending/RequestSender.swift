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
    private let now: @Sendable () -> Date
    private let cnonce: @Sendable () -> String

    public init(
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        now: @escaping @Sendable () -> Date = { Date() },
        cnonce: @escaping @Sendable () -> String = { UUID().uuidString.replacing("-", with: "").lowercased() }
    ) {
        self.transport = transport
        self.secretStore = secretStore
        self.now = now
        self.cnonce = cnonce
    }

    @concurrent
    public func send(_ outgoing: OutgoingRequest, scopes: VariableScopes) async -> SendResult {
        let urlRequest: URLRequest
        let notes: [ResponseNote]
        let digest: DigestAuthProvider?
        do {
            let resolved = try await resolve(outgoing, scopes: scopes)
            let built = try await RequestBuilder(now: now).build(resolved)
            urlRequest = built.urlRequest
            digest = resolved.digestProvider
            notes = ResponseNote.notes(
                unresolved: built.unresolved,
                notices: built.notices.map { $0.namingRow(of: outgoing.request, resolvedAs: resolved) },
                unresolvedCredentials: resolved.unresolvedCredentials
            )
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(SendFailure(notSent: error), notes: [])
        }
        return await transmit(urlRequest, notes: notes, digest: digest)
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

    private func transmit(
        _ request: URLRequest,
        notes: [ResponseNote],
        digest: DigestAuthProvider?
    ) async -> SendResult {
        do {
            let (response, measured) = try await timedSend(request)
            guard response.status == 401, let digest else {
                return .response(SentResponse(response, measured: measured, notes: notes))
            }
            return try await answerDigestChallenge(
                in: response,
                measured: measured,
                notes: notes,
                to: request,
                with: digest
            )
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(SendFailure(transportError: error), notes: notes)
        }
    }

}

private nonisolated extension RequestSender {

    func timedSend(_ request: URLRequest) async throws -> (HTTPResponse, Duration) {
        let clock = ContinuousClock()
        let start = clock.now
        let response = try await transport.send(request)
        return (response, start.duration(to: clock.now))
    }

    /// One answer, whatever the method: the server refused the first send for lack of credentials. No nonce is kept, so
    /// every send starts again with none.
    func answerDigestChallenge(
        in refusal: HTTPResponse,
        measured: Duration,
        notes: [ResponseNote],
        to request: URLRequest,
        with digest: DigestAuthProvider
    ) async throws -> SendResult {
        let header = refusal.value(forHeader: "WWW-Authenticate") ?? ""
        guard let challenge = DigestChallenge.first(in: header) else {
            let note: [ResponseNote] = DigestChallenge.isOffered(in: header) ? [.digestChallengeUnsupported] : []
            return .response(SentResponse(refusal, measured: measured, notes: notes + note))
        }

        try Task.checkCancellation()
        var answer = request
        answer.setValue(
            digest.authorization(answering: challenge, to: request, cnonce: cnonce()),
            forHTTPHeaderField: "Authorization"
        )
        let (response, measured) = try await timedSend(answer)
        return .response(SentResponse(response, measured: measured, notes: notes + [.sentAgainForDigestChallenge]))
    }

}

private nonisolated extension RequestBuildNotice {

    /// A resolved name can hold a secret, so a note names a row as the tab shows it.
    func namingRow(of request: Request, resolvedAs resolved: ResolvedRequest) -> RequestBuildNotice {
        switch self {
        case .unsendableHeader(let name):
            let row = zip(request.headers, resolved.headers).first { $0.1.key == name }
            return .unsendableHeader(name: row?.0.key ?? name)
        case .unsupportedFormDataFile(let key):
            guard case .formData(let written) = request.body, case .formData(let fields) = resolved.body else {
                return self
            }
            let row = zip(written, fields).first { $0.1.key == key }
            return .unsupportedFormDataFile(key: row?.0.key ?? key)
        case .pathVariableWithoutValue(let name):
            return namingPathVariable(name, of: request, resolvedAs: resolved)
        default:
            return self
        }
    }

    private func namingPathVariable(
        _ name: String,
        of request: Request,
        resolvedAs resolved: ResolvedRequest
    ) -> RequestBuildNotice {
        let rows = zip(request.pathParameters, resolved.pathParameters)

        if let row = rows.first(where: { $0.0.isEnabled && $0.1.key == name }) {
            return .pathVariableWithoutValue(name: row.0.key)
        }

        let isShownInTheURL = URLTemplateText(request.urlTemplate).pathVariableNames.contains(name)
        return isShownInTheURL ? self : .unnamedPathVariableWithoutValue
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
