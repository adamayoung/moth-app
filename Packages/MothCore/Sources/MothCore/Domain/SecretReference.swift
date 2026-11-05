//  SecretReference.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Our own identifier, never a Keychain persistent reference, which Apple says not to use for synchronizable items.
public nonisolated struct SecretReference: Sendable, Hashable {

    public let identifier: String

    public init(identifier: String = UUID().uuidString) {
        self.identifier = identifier
    }

}
