//  PostmanValue.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public enum PostmanValue: Decodable, Sendable, Equatable {

    case string(String)
    case number(Double)
    case bool(Bool)
    case array([PostmanValue])
    case object([String: PostmanValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([PostmanValue].self) {
            self = .array(value)
        } else {
            self = try .object(container.decode([String: PostmanValue].self))
        }
    }

}
