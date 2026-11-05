//  PostmanAuth.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanAuth: Decodable, Sendable, Equatable {

    public let type: PostmanAuthType
    public let parameters: [PostmanAuthParameter]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AuthKey.self)
        let name = try container.decode(String.self, forKey: AuthKey("type"))
        self.type = PostmanAuthType(name: name)
        self.parameters = try container.decodeList(forKey: AuthKey(name))
    }

}

public struct PostmanAuthParameter: Decodable, Sendable, Equatable {

    public let key: String
    public let value: PostmanValue?
    public let type: String?

}

/// Postman stores an auth's parameters under a key named after its type, so the key set is open.
private struct AuthKey: CodingKey {

    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue _: Int) {
        nil
    }

}
