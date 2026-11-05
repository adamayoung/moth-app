//  PostmanCollection.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanCollection: Decodable, Sendable, Equatable {

    public let info: PostmanInfo
    public let items: [PostmanItem]

    private enum CodingKeys: String, CodingKey {
        case info
        case items = "item"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decodeIfPresent(DeclaredSchema.self, forKey: .info)?.schema
        guard let schema, PostmanSchema(rawValue: schema) != nil else {
            throw PostmanDecodingError.unsupportedSchema(found: schema)
        }
        self.info = try container.decode(PostmanInfo.self, forKey: .info)
        self.items = try container.decode([PostmanItem].self, forKey: .items)
    }

}

private struct DeclaredSchema: Decodable {

    let schema: String?

}
