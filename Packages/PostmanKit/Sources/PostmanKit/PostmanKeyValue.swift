//  PostmanKeyValue.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanKeyValue: Decodable, Sendable, Equatable {

    public let key: String?
    public let value: String?
    public let description: PostmanDescription?
    public let isEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case key
        case value
        case description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
        self.description = try container.decodeIfPresent(PostmanDescription.self, forKey: .description)
        self.isEnabled = try EnabledFlags(from: decoder).isEnabled
    }

}
