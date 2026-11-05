//  PostmanCollection.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanCollection: Decodable, Sendable, Equatable {

    public let info: PostmanInfo
    public let items: [PostmanItem]
    public let variables: [PostmanVariable]
    public let auth: PostmanAuth?
    public let events: [PostmanEvent]

    private enum CodingKeys: String, CodingKey {
        case info
        case items = "item"
        case variables = "variable"
        case auth
        case events = "event"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decodeIfPresent(DeclaredSchema.self, forKey: .info)?.schema
        guard let schema, PostmanSchema(rawValue: schema) != nil else {
            throw PostmanDecodingError.unsupportedSchema(found: schema)
        }
        self.info = try container.decode(PostmanInfo.self, forKey: .info)
        self.items = try container.decode([PostmanItem].self, forKey: .items)
        self.variables = try container.decodeList(forKey: .variables)
        self.auth = try container.decodeIfPresent(PostmanAuth.self, forKey: .auth)
        self.events = try container.decodeList(forKey: .events)
    }

}

private struct DeclaredSchema: Decodable {

    let schema: String?

}
