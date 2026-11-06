//  WriteQueue.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

/// Keychain calls finish in no set order, so a later write could be overtaken by an earlier one, a save could recreate
/// an item that has just been removed, or a read could put back a value that has just been replaced.
final class WriteQueue {

    private var last: Task<Void, Never>?

    func run<Value: Sendable>(_ work: @escaping () async -> Value) async -> Value {
        let previous = last
        let next = Task {
            await previous?.value
            return await work()
        }
        last = Task { _ = await next.value }
        return await next.value
    }

}
