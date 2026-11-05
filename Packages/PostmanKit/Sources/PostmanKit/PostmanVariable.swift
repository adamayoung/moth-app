//  PostmanVariable.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanVariable: Decodable, Sendable, Equatable {

    public let id: String?
    public let key: String?
    public let value: PostmanValue?
    public let type: String?
    public let description: PostmanDescription?
    public let isEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case key
        case value
        case type
        case description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.value = try container.decodeIfPresent(PostmanValue.self, forKey: .value)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.description = try container.decodeIfPresent(PostmanDescription.self, forKey: .description)
        self.isEnabled = try EnabledFlags(from: decoder).isEnabled
    }

}
