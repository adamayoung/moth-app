//  HoldingSecretStore.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import MothCore
import Synchronization
import Testing

final nonisolated class HoldingSecretStore: SecretStore {

    private struct State {

        var values: [String: String] = [:]
        var holdsNextSave = false
        var heldSave: CheckedContinuation<Void, Never>?

    }

    private let state = Mutex(State())

    var values: [String: String] {
        state.withLock { $0.values }
    }

    private var isHoldingASave: Bool {
        state.withLock { $0.heldSave != nil }
    }

    func holdNextSave() {
        state.withLock { $0.holdsNextSave = true }
    }

    /// Bounded by the clock, because a save that never arrives would otherwise hold the machine-wide build lock.
    func waitUntilHolding() async {
        let deadline = ContinuousClock.now + .seconds(5)
        while !isHoldingASave, ContinuousClock.now < deadline {
            await Task.yield()
        }
        if !isHoldingASave {
            Issue.record("The save never reached the secret store")
        }
    }

    /// Also cancels a hold nothing has reached yet, so a save that arrives late can't wait for ever.
    func finishHeldSave() {
        let held = state.withLock { state in
            let held = state.heldSave
            state.heldSave = nil
            state.holdsNextSave = false
            return held
        }
        held?.resume()
    }

    func save(_ value: String, for identifier: String) async {
        await withCheckedContinuation { continuation in
            let isHeld = state.withLock { state in
                guard state.holdsNextSave else {
                    return false
                }
                state.holdsNextSave = false
                state.heldSave = continuation
                return true
            }
            if !isHeld {
                continuation.resume()
            }
        }
        state.withLock { $0.values[identifier] = value }
    }

    func value(for identifier: String) -> String? {
        state.withLock { $0.values[identifier] }
    }

    func removeValue(for identifier: String) {
        state.withLock { $0.values[identifier] = nil }
    }

}
