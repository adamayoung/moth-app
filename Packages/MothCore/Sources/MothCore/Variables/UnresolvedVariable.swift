//  UnresolvedVariable.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct UnresolvedVariable: Sendable, Hashable {

    public let name: String
    public let reason: UnresolvedReason

    public init(name: String, reason: UnresolvedReason) {
        self.name = name
        self.reason = reason
    }

}

public nonisolated enum UnresolvedReason: Sendable, Hashable {

    case undefined
    case cycle
    case tooDeep
    case missingSecret

}
