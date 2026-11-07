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
    public func send(
        _ outgoing: OutgoingRequest,
        scopes: VariableScopes,
        cookies: any CookieJar? = nil
    ) async -> SendResult {
        await sendRecording(outgoing, scopes: scopes, cookies: cookies).result
    }

    @concurrent
    public func sendRecording(
        _ outgoing: OutgoingRequest,
        scopes: VariableScopes,
        cookies: any CookieJar? = nil
    ) async -> RecordedSend {
        let sentAt = now()
        let dynamicValues = DynamicValueLog()
        let sent = await send(
            outgoing,
            scopes: scopes,
            cookies: cookies,
            dynamicVariables: dynamicValues.recording,
            at: sentAt
        )
        if sent.result == .cancelled {
            return RecordedSend(result: .cancelled, entry: nil)
        }

        guard let snapshot = try? await HistorySnapshot.make(
            of: outgoing.request,
            scopes: scopes,
            replaying: dynamicValues
        ) else {
            return RecordedSend(result: sent.result, entry: nil)
        }
        let entry = HistoryEntry(request: snapshot, sent: sent, at: sentAt)
        return RecordedSend(result: sent.result, entry: entry)
    }

    /// Sends nothing while a secret the snapshot names, or a row it masked, has no value to send.
    @concurrent
    public func sendAgain(_ entry: HistoryEntry, cookies: any CookieJar? = nil) async -> SendAgainOutcome {
        do {
            let resolved = try await VariableResolver(secretStore: secretStore)
                .resolve(entry.request, collection: [], environment: [], globals: [])
            let hasMissingSecret = resolved.unresolved.contains { $0.reason == .missingSecret }
            guard !hasMissingSecret, resolved.unresolvedCredentials.isEmpty,
                  !HistorySnapshot.hasLostRow(in: resolved)
            else {
                return .secretUnavailable
            }
        } catch {
            return .secretUnavailable
        }
        return await .sent(sendRecording(
            OutgoingRequest(request: entry.request),
            scopes: VariableScopes(),
            cookies: cookies
        ))
    }

    private func send(
        _ outgoing: OutgoingRequest,
        scopes: VariableScopes,
        cookies: any CookieJar?,
        dynamicVariables: DynamicVariables,
        at sentAt: Date
    ) async -> Transmission {
        let urlRequest: URLRequest
        let notes: [ResponseNote]
        let digest: DigestAuthProvider?
        let delivery: Delivery
        do {
            let resolved = try await resolve(outgoing, scopes: scopes, dynamicVariables: dynamicVariables)
            let built = try await RequestBuilder(now: { sentAt }).build(resolved)
            urlRequest = built.urlRequest
            digest = resolved.digestProvider
            delivery = Delivery(cookies: cookies, settings: resolved.settings)
            notes = ResponseNote.notes(
                unresolved: built.unresolved,
                notices: built.notices.map { $0.namingRow(of: outgoing.request, resolvedAs: resolved) },
                unresolvedCredentials: resolved.unresolvedCredentials
            )
        } catch is CancellationError {
            return Transmission(result: .cancelled)
        } catch {
            return Transmission(result: .failed(SendFailure(notSent: error), notes: []))
        }
        return await transmit(urlRequest, delivery: delivery, notes: notes, digest: digest)
    }

    private func resolve(
        _ outgoing: OutgoingRequest,
        scopes: VariableScopes,
        dynamicVariables: DynamicVariables
    ) async throws -> ResolvedRequest {
        let credentials = TypedCredentialStore(typed: outgoing.typedCredentials, stored: secretStore)
        return try await VariableResolver(secretStore: credentials, dynamicVariables: dynamicVariables).resolve(
            outgoing.request,
            collection: scopes.collection,
            environment: scopes.environment,
            globals: scopes.globals
        )
    }

    private func transmit(
        _ request: URLRequest,
        delivery: Delivery,
        notes: [ResponseNote],
        digest: DigestAuthProvider?
    ) async -> Transmission {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let sent = try await timedSend(request, delivery: delivery)
            let notes = delivery.notes(notes)
            guard sent.response.status == 401, let digest else {
                return Transmission(sent.response, measured: sent.measured, notes: notes)
            }
            return try await answerDigestChallenge(
                in: sent,
                notes: notes,
                to: request,
                with: digest,
                delivery: delivery
            )
        } catch is CancellationError {
            return Transmission(result: .cancelled)
        } catch {
            let failure = SendFailure(transportError: error)
            return Transmission(result: .failed(failure, notes: notes), duration: start.duration(to: clock.now))
        }
    }

}

private nonisolated extension RequestSender {

    func timedSend(
        _ request: URLRequest,
        delivery: Delivery
    ) async throws -> (response: HTTPResponse, measured: Duration) {
        let clock = ContinuousClock()
        let start = clock.now
        let response = try await transport.send(request, cookies: delivery.cookies, policy: delivery.policy)
        return (response, start.duration(to: clock.now))
    }

    /// One answer, whatever the method: the server refused the first send for lack of credentials. No nonce is kept, so
    /// every send starts again with none. After a redirect, only a request with no body to another URL on its origin is
    /// answered: one with a body may have become a GET, and another origin is a host the request didn't name.
    func answerDigestChallenge(
        in sent: (response: HTTPResponse, measured: Duration),
        notes: [ResponseNote],
        to request: URLRequest,
        with digest: DigestAuthProvider,
        delivery: Delivery
    ) async throws -> Transmission {
        let (refusal, measured) = sent
        let challenges = AuthChallenge.all(in: refusal.value(forHeader: "WWW-Authenticate") ?? "")
        guard let challenge = DigestChallenge.first(in: challenges) else {
            let isOffered = challenges.contains { $0.isScheme("Digest") }
            return Transmission(
                refusal,
                measured: measured,
                notes: notes + (isOffered ? [.digestChallengeUnsupported] : [])
            )
        }

        guard let challenger = Self.answerableURL(after: refusal, to: request) else {
            return Transmission(refusal, measured: measured, notes: notes + [.digestChallengeAfterRedirect])
        }

        try Task.checkCancellation()
        var answer = request
        answer.url = challenger
        answer.setValue(
            digest.authorization(answering: challenge, to: answer, cnonce: cnonce()),
            forHTTPHeaderField: "Authorization"
        )
        return try await transmitAnswer(answer, delivery: delivery, notes: notes + [.sentAgainForDigestChallenge])
    }

    /// The same jar as the first send, so a cookie the refusal set goes with the answer.
    private func transmitAnswer(
        _ answer: URLRequest,
        delivery: Delivery,
        notes: [ResponseNote]
    ) async throws -> Transmission {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (response, measured) = try await timedSend(answer, delivery: delivery)
            return Transmission(response, measured: measured, notes: notes)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let failure = SendFailure(transportError: error)
            return Transmission(result: .failed(failure, notes: notes), duration: start.duration(to: clock.now))
        }
    }

    private static func answerableURL(after refusal: HTTPResponse, to request: URLRequest) -> URL? {
        guard let sent = request.url else {
            return nil
        }
        guard let challenger = refusal.url, challenger != sent else {
            return sent
        }
        let hasBody = !(request.httpBody ?? Data()).isEmpty
        return challenger.hasSameOrigin(as: sent) && !hasBody ? challenger : nil
    }

}

/// How each send of one request travels: the workspace's jar, and the request's settings as the transport's policy.
private nonisolated struct Delivery {

    var cookies: any CookieJar?
    var policy: SendPolicy

    init(cookies: any CookieJar?, settings: RequestSettings) {
        self.cookies = cookies
        self.policy = SendPolicy(followsRedirects: settings.followsRedirects, verifiesTLS: settings.verifiesTLS)
    }

    /// On plain HTTP too, because a redirect can pass through HTTPS on its way.
    func notes(_ notes: [ResponseNote]) -> [ResponseNote] {
        policy.verifiesTLS ? notes : notes + [.sentWithoutTLSVerification]
    }

}

/// What history needs from a send: the raw body, which ``SentResponse`` doesn't keep.
private nonisolated struct Transmission {

    var result: SendResult
    var duration: Duration = .zero
    var response: HTTPResponse?

    init(result: SendResult, duration: Duration = .zero, response: HTTPResponse? = nil) {
        self.result = result
        self.duration = duration
        self.response = response
    }

    init(_ response: HTTPResponse, measured: Duration, notes: [ResponseNote]) {
        let shown = SentResponse(response, measured: measured, notes: notes)
        self.init(result: .response(shown), duration: shown.duration, response: response)
    }

}

private nonisolated extension HistoryEntry {

    init(request: Request, sent: Transmission, at sentAt: Date) {
        var failure: SendFailure?
        var response: HistoryResponse?
        switch sent.result {
        case .response(let shown):
            let body = sent.response?.body ?? Data()
            response = HistoryResponse(
                status: shown.status,
                reasonPhrase: shown.reasonPhrase,
                headers: shown.headers.map { KeyValue(key: $0.name, value: $0.value) },
                timing: shown.timing,
                size: body.count,
                body: body.count > HistoryResponse.bodyLimit ? nil : body
            )
        case .failed(let sendFailure, _):
            failure = sendFailure
        case .cancelled:
            break
        }
        self.init(request: request, sentAt: sentAt, duration: sent.duration, response: response, failure: failure)
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
