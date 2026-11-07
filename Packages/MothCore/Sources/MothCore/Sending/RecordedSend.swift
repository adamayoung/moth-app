//  RecordedSend.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct RecordedSend: Sendable, Hashable {

    public static let cancelled = RecordedSend(result: .cancelled, entry: nil)

    public let result: SendResult
    /// `nil` for a cancelled send, which History doesn't record.
    public let entry: HistoryEntry?

    public init(result: SendResult, entry: HistoryEntry?) {
        self.result = result
        self.entry = entry
    }

}

public nonisolated enum SendAgainOutcome: Sendable, Hashable {

    case sent(RecordedSend)
    case secretUnavailable

}
