//  SendResult.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum SendResult: Sendable, Hashable {

    case response(SentResponse)
    case failed(SendFailure, notes: [ResponseNote])
    case cancelled

}
