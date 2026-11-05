//  Variable.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct Variable: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var name: String
    public var value: VariableValue
    public var isEnabled: Bool

    public var isSecret: Bool {
        secretReference != nil
    }

    public var secretReference: SecretReference? {
        guard case .secret(let reference) = value else {
            return nil
        }

        return reference
    }

    public var initialValue: String? {
        guard case .plain(let initial, _) = value else {
            return nil
        }

        return initial
    }

    public var currentValue: String? {
        guard case .plain(_, let current) = value else {
            return nil
        }

        return current
    }

    public init(id: UUID = UUID(), name: String, value: VariableValue, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.value = value
        self.isEnabled = isEnabled
    }

}

/// A secret has one value, held in the Keychain, so it has no initial and current pair.
public nonisolated enum VariableValue: Sendable, Hashable {

    case plain(initial: String, current: String)
    case secret(SecretReference)

}
