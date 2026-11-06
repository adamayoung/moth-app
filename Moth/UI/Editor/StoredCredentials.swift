//  StoredCredentials.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import OSLog

struct StoredCredentials {

    private var values: [SecretReference: SecretValue] = [:]

    /// A reference no row holds yet has nothing to wait for, so its field starts empty.
    func value(of reference: SecretReference, heldBy saved: Auth) -> SecretValue {
        values[reference] ?? (saved.secretReferences.contains(reference) ? .loading : .available(""))
    }

    mutating func record(_ value: String?, for reference: SecretReference) {
        values[reference] = value.map(SecretValue.available) ?? .notYetAvailable
    }

    mutating func forget(_ references: Set<SecretReference>) {
        for reference in references {
            values[reference] = nil
        }
    }

}

extension SecretValue {

    var text: String {
        if case .available(let value) = self {
            value
        } else {
            ""
        }
    }

}

extension AuthDraft {

    /// Text typed back to what is stored leaves nothing to save, and an empty field matches a missing value.
    mutating func discardCredentials(matching stored: StoredCredentials, heldBy saved: Auth) {
        discardCredentials { reference, text in
            switch stored.value(of: reference, heldBy: saved) {
            case .loading: false
            case .available(let value): value == text
            case .notYetAvailable: text.isEmpty
            }
        }
    }

}

extension SecretStore {

    /// Values go first, because a row referring to no value would lose it. A row that can't be written takes the new
    /// values with it, and what it replaced stays until it has moved on.
    func commit(
        _ writes: [CredentialWrite],
        writingRow: () async throws -> Set<SecretReference>
    ) async throws -> Set<SecretReference> {
        do {
            for write in writes {
                try await save(write.value, for: write.reference.identifier)
            }
            let released = try await writingRow()
            await remove(released)
            return released
        } catch {
            await remove(Set(writes.map(\.reference)))
            throw error
        }
    }

    /// A read that fails shows as not yet available, which is the state a person can do nothing about either way.
    func credential(_ reference: SecretReference) async -> String? {
        do {
            return try await value(for: reference.identifier)
        } catch {
            Logger.editor.error("Reading a credential failed: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

}
