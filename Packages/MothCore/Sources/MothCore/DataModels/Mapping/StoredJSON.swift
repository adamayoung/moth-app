//  StoredJSON.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Sorted keys, so equal values encode to equal bytes: an equal-value assignment still rewrites a row.
nonisolated enum StoredJSON {

    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    /// A row from a newer build can hold a case this build lacks. That throws, because a default would hide the value
    /// and the next save would overwrite it.
    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data?,
        default defaultValue: Value
    ) throws -> Value {
        guard let data else {
            return defaultValue
        }

        return try JSONDecoder().decode(type, from: data)
    }

}
