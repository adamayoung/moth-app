//  SecretStore+Released.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import OSLog

extension SecretStore {

    /// Follows the save that released them, so a failure is logged rather than undone: a stray item is harmless.
    func remove(_ released: Set<SecretReference>) async {
        for reference in released {
            do {
                try await removeValue(for: reference.identifier)
            } catch {
                Logger.variables.error(
                    "Secret \(reference.identifier, privacy: .public) stayed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

}
