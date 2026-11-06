//  VariableDraft.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

enum SecretValue: Hashable {

    case loading
    case available(String)
    case notYetAvailable

}

struct SecretDraft: Hashable {

    let reference: SecretReference
    var value: SecretValue

}

/// One row of the sheet as the person is editing it, which can run ahead of the store until a field commits.
struct VariableDraft: Identifiable, Hashable {

    let id: UUID
    var name: String
    var initial: String
    var current: String
    var isEnabled: Bool
    var secret: SecretDraft?

    init(_ variable: Variable) {
        self.id = variable.id
        self.name = variable.name
        self.initial = variable.initialValue ?? ""
        self.current = variable.currentValue ?? ""
        self.isEnabled = variable.isEnabled
        self.secret = variable.secretReference.map { SecretDraft(reference: $0, value: .loading) }
    }

    var variable: Variable {
        let value: VariableValue = if let secret {
            .secret(secret.reference)
        } else {
            .plain(initial: initial, current: current)
        }
        return Variable(id: id, name: name, value: value, isEnabled: isEnabled)
    }

    /// Turning off a secret needs its value, which a Mac the secret has not reached does not have.
    var canChangeSecret: Bool {
        switch secret?.value {
        case nil, .available: true
        case .loading, .notYetAvailable: false
        }
    }

}
