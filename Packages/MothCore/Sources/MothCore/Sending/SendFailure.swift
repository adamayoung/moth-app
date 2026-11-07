//  SendFailure.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

public nonisolated struct SendFailure: Sendable, Hashable {

    public enum Kind: String, Sendable, Hashable {

        case timedOut
        case couldNotConnect
        case notSent
        case accessTokenFailed

    }

    public let kind: Kind
    public let description: String?

    public init(kind: Kind, description: String?) {
        self.kind = kind
        self.description = description
    }

    public init(transportError error: any Error) {
        switch error {
        case let error as HTTPTransportError:
            if case .timedOut = error {
                self.init(kind: .timedOut, description: error.errorDescription)
            } else {
                self.init(kind: .couldNotConnect, description: error.errorDescription)
            }
        default:
            self.init(kind: .couldNotConnect, description: error.localizedDescription)
        }
    }

    public init(notSent error: any Error) {
        self.init(kind: .notSent, description: error.localizedDescription)
    }

}
