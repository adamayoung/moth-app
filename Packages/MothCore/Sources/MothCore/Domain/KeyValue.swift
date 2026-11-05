//  KeyValue.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct KeyValue: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), key: String, value: String, isEnabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }

}
