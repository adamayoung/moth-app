//  DynamicVariables.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct DynamicVariables: Sendable {

    public static let live = DynamicVariables(
        guid: { UUID().uuidString.lowercased() },
        timestamp: { String(Int(Date.now.timeIntervalSince1970.rounded())) },
        randomInt: { String(Int.random(in: 0 ... 1000)) }
    )

    public var guid: @Sendable () -> String
    public var timestamp: @Sendable () -> String
    public var randomInt: @Sendable () -> String

    public init(
        guid: @escaping @Sendable () -> String,
        timestamp: @escaping @Sendable () -> String,
        randomInt: @escaping @Sendable () -> String
    ) {
        self.guid = guid
        self.timestamp = timestamp
        self.randomInt = randomInt
    }

    func value(named name: String) -> String? {
        switch name {
        case "$guid": guid()
        case "$timestamp": timestamp()
        case "$randomInt": randomInt()
        default: nil
        }
    }

}
