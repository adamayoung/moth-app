//  DynamicValueLog.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Synchronization

/// Lets a history snapshot, resolved after the send, hold the dynamic values that were sent.
final nonisolated class DynamicValueLog: Sendable {

    private struct Drawn {

        var guid: [String] = []
        var timestamp: [String] = []
        var randomInt: [String] = []

    }

    private let drawn = Mutex(Drawn())
    private let live: DynamicVariables

    init(live: DynamicVariables = .live) {
        self.live = live
    }

    var recording: DynamicVariables {
        DynamicVariables(
            guid: { [self] in record(live.guid(), in: \.guid) },
            timestamp: { [self] in record(live.timestamp(), in: \.timestamp) },
            randomInt: { [self] in record(live.randomInt(), in: \.randomInt) }
        )
    }

    /// Falls back to a new value once the log runs out, as when a secret's own value held a dynamic variable.
    var replaying: DynamicVariables {
        DynamicVariables(
            guid: { [self] in replay(\.guid) ?? live.guid() },
            timestamp: { [self] in replay(\.timestamp) ?? live.timestamp() },
            randomInt: { [self] in replay(\.randomInt) ?? live.randomInt() }
        )
    }

    private func record(_ value: String, in values: WritableKeyPath<Drawn, [String]>) -> String {
        drawn.withLock { $0[keyPath: values].append(value) }
        return value
    }

    private func replay(_ values: WritableKeyPath<Drawn, [String]>) -> String? {
        drawn.withLock { drawn in
            drawn[keyPath: values].isEmpty ? nil : drawn[keyPath: values].removeFirst()
        }
    }

}
