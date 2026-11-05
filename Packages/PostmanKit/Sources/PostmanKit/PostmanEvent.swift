//  PostmanEvent.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanEvent: Decodable, Sendable, Equatable {

    public let listen: String
    public let script: PostmanScript?
    public let isEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case listen
        case script
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.listen = try container.decode(String.self, forKey: .listen)
        self.script = try container.decodeIfPresent(PostmanScript.self, forKey: .script)
        self.isEnabled = try EnabledFlags(from: decoder).isEnabled
    }

}

public struct PostmanScript: Decodable, Sendable, Equatable {

    public let type: String?
    public let exec: [String]

    private enum CodingKeys: String, CodingKey {
        case type
        case exec
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.exec = try container.decodeStringOrList(forKey: .exec)
    }

}
