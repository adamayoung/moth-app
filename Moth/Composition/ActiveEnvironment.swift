//  ActiveEnvironment.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import Observation

/// Per Mac, so two Macs can point at different environments: nothing here reaches the synced store.
@Observable
final class ActiveEnvironment {

    private static let defaultsKey = "activeEnvironmentID"

    private(set) var id: UUID?

    @ObservationIgnored private var knownIDs: Set<UUID> = []
    @ObservationIgnored private let persist: (UUID?) -> Void

    init(defaults: UserDefaults) {
        self.id = defaults.string(forKey: Self.defaultsKey).flatMap(UUID.init(uuidString:))
        self.persist = { defaults.set($0?.uuidString, forKey: Self.defaultsKey) }
    }

    /// A seeded launch, which must neither read nor change the choice a real launch saved in the same defaults.
    init(inMemory id: UUID?) {
        self.id = id
        self.persist = { _ in }
    }

    func select(_ id: UUID?) {
        self.id = id
        persist(id)
    }

    /// Clears only on the transition out of the list, so a launch keeps a choice whose row has not synced yet.
    func environmentsDidChange(_ ids: Set<UUID>) {
        if let id, knownIDs.contains(id), !ids.contains(id) {
            select(nil)
        }
        knownIDs = ids
    }

}
