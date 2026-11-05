//  KeychainSecretStoreError.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import Security

/// Holds only the operation and the status, so an error can never carry a secret into a log.
public nonisolated struct KeychainSecretStoreError: Error, Equatable, CustomStringConvertible {

    public enum Operation: String, Sendable {
        case save
        case read
        case remove
    }

    public let operation: Operation
    public let status: OSStatus

    public init(operation: Operation, status: OSStatus) {
        self.operation = operation
        self.status = status
    }

    public var description: String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
        return "Keychain \(operation.rawValue) failed: \(message) (\(status))"
    }

}
