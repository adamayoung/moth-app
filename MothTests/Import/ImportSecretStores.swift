//  ImportSecretStores.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Synchronization

actor RecordingSecretStore: SecretStore {

    private(set) var values: [String: String] = [:]

    func save(_ value: String, for identifier: String) {
        values[identifier] = value
    }

    func value(for identifier: String) -> String? {
        values[identifier]
    }

    func removeValue(for identifier: String) {
        values[identifier] = nil
    }

}

/// Holds the calling thread, not just the task, so an import running on the main actor stops the test that releases it.
final nonisolated class ThreadHoldingSecretStore: SecretStore {

    private struct Hold {

        let wasOnMainThread: Bool
        let wasReleased: Bool

    }

    private static let patience = DispatchTimeInterval.seconds(5)

    private let release = DispatchSemaphore(value: 0)
    private let hold = Mutex<Hold?>(nil)
    private let entered: AsyncStream<Void>
    private let enteredContinuation: AsyncStream<Void>.Continuation

    init() {
        (self.entered, self.enteredContinuation) = AsyncStream.makeStream()
    }

    var heldOffTheMainThreadUntilReleased: Bool {
        hold.withLock { hold in
            hold.map { !$0.wasOnMainThread && $0.wasReleased } ?? false
        }
    }

    func waitUntilHolding() async {
        _ = await entered.first { _ in true }
    }

    func letGo() {
        release.signal()
    }

    func save(_ value: String, for identifier: String) async throws {
        holdThisThread()
    }

    func value(for identifier: String) async throws -> String? {
        nil
    }

    func removeValue(for identifier: String) async throws {}

    private func holdThisThread() {
        enteredContinuation.yield()
        let wasOnMainThread = Thread.isMainThread
        let wasReleased = release.wait(timeout: .now() + Self.patience) == .success
        hold.withLock { $0 = Hold(wasOnMainThread: wasOnMainThread, wasReleased: wasReleased) }
    }

}
