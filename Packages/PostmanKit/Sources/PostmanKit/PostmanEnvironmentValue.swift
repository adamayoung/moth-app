//  PostmanEnvironmentValue.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanEnvironmentValue: Decodable, Sendable, Equatable {

    public let key: String
    public let value: PostmanValue?
    public let type: String?
    public let isEnabled: Bool

    public var isSecret: Bool {
        type == "secret"
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case value
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.value = try container.decodeIfPresent(PostmanValue.self, forKey: .value)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.isEnabled = try EnabledFlags(from: decoder).isEnabled
    }

}
