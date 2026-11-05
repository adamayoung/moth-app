//  PostmanRequestItem.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanRequestItem: Decodable, Sendable, Equatable {

    public let name: String?
    public let description: PostmanDescription?
    public let request: PostmanRequest
    public let variables: [PostmanVariable]
    public let events: [PostmanEvent]

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case request
        case variables = "variable"
        case events = "event"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(PostmanDescription.self, forKey: .description)
        self.request = try container.decode(PostmanRequest.self, forKey: .request)
        self.variables = try container.decodeList(forKey: .variables)
        self.events = try container.decodeList(forKey: .events)
    }

}
