//  PostmanValue+Text.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import PostmanKit

nonisolated extension PostmanValue {

    /// `nil` for a value the file doesn't hold.
    var text: String? {
        switch self {
        case .null:
            nil
        case .string(let value):
            value
        case .bool(let value):
            String(value)
        case .number, .array, .object:
            jsonText
        }
    }

    private var jsonText: String? {
        let options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]

        guard let data = try? JSONSerialization.data(withJSONObject: foundationValue, options: options) else {
            return nil
        }

        return String(bytes: data, encoding: .utf8)
    }

    private var foundationValue: Any {
        switch self {
        case .null: NSNull()
        case .string(let value): value
        case .bool(let value): value
        case .number(let value): value
        case .array(let values): values.map(\.foundationValue)
        case .object(let values): values.mapValues(\.foundationValue)
        }
    }

}
