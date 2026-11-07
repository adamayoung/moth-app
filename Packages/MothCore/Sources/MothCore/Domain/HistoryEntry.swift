//  HistoryEntry.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// `request` is the snapshot sent, with secret variables left as `{{name}}` and auth holding references, so no secret
/// is stored. Its `variables` hold the secret variables it names, which Send Again reads from the Keychain.
public nonisolated struct HistoryEntry: Identifiable, Sendable, Hashable {

    public static let maskedValue = "••••••••"

    public let id: UUID
    public var request: Request
    public var sentAt: Date
    public var duration: Duration
    public var response: HistoryResponse?
    public var failure: SendFailure?

    public init(
        id: UUID = UUID(),
        request: Request,
        sentAt: Date,
        duration: Duration,
        response: HistoryResponse? = nil,
        failure: SendFailure? = nil
    ) {
        self.id = id
        self.request = request
        self.sentAt = sentAt
        self.duration = duration
        self.response = response
        self.failure = failure
    }

}

public nonisolated struct HistoryResponse: Sendable, Hashable {

    /// In bytes, as the status line counts them.
    public static let bodyLimit = 5_000_000

    public var status: Int
    public var reasonPhrase: String?
    public var headers: [KeyValue]
    public var timing: [PhaseTiming]
    public var size: Int
    /// `nil` when the body was larger than ``bodyLimit``.
    public var body: Data?

    public init(
        status: Int,
        reasonPhrase: String? = nil,
        headers: [KeyValue] = [],
        timing: [PhaseTiming] = [],
        size: Int = 0,
        body: Data? = Data()
    ) {
        self.status = status
        self.reasonPhrase = reasonPhrase
        self.headers = headers
        self.timing = timing
        self.size = size
        self.body = body
    }

}
