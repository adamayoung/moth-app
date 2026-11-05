//  HistoryEntry.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// `request` is the unresolved request, so a secret in it stays a reference. A response is stored as received.
public nonisolated struct HistoryEntry: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var request: Request
    public var sentAt: Date
    public var duration: Duration
    public var response: HistoryResponse?
    public var failure: String?

    public init(
        id: UUID = UUID(),
        request: Request,
        sentAt: Date,
        duration: Duration,
        response: HistoryResponse? = nil,
        failure: String? = nil
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

    public var status: Int
    public var headers: [KeyValue]
    public var body: Data

    public init(status: Int, headers: [KeyValue] = [], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

}
