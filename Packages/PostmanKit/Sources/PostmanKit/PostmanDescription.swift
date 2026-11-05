//  PostmanDescription.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanDescription: Decodable, Sendable, Equatable {

    public let content: String?
    public let type: String?

    private enum CodingKeys: String, CodingKey {
        case content
        case type
    }

    public init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            self.content = text
            self.type = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
    }

}
