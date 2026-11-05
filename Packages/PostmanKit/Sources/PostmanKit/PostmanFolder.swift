//  PostmanFolder.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanFolder: Decodable, Sendable, Equatable {

    public let name: String?
    public let description: PostmanDescription?
    public let items: [PostmanItem]
    public let variables: [PostmanVariable]
    public let auth: PostmanAuth?
    public let events: [PostmanEvent]

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case items = "item"
        case variables = "variable"
        case auth
        case events = "event"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(PostmanDescription.self, forKey: .description)
        self.items = try container.decode([PostmanItem].self, forKey: .items)
        self.variables = try container.decodeList(forKey: .variables)
        self.auth = try container.decodeIfPresent(PostmanAuth.self, forKey: .auth)
        self.events = try container.decodeList(forKey: .events)
    }

}
