//  PostmanFormDataRow.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanFormDataRow: Decodable, Sendable, Equatable {

    public let key: String?
    public let value: String?
    public let type: String?
    public let sources: [String]
    public let contentType: String?
    public let description: PostmanDescription?
    public let isEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case key
        case value
        case type
        case sources = "src"
        case contentType
        case description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.sources = try container.decodeStringOrList(forKey: .sources)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.description = try container.decodeIfPresent(PostmanDescription.self, forKey: .description)
        self.isEnabled = try EnabledFlags(from: decoder).isEnabled
    }

}
