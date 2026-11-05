//  PostmanURL.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanURL: Decodable, Sendable, Equatable {

    public let raw: String?
    public let protocolName: String?
    public let host: [String]
    public let path: [String]
    public let port: String?
    public let query: [PostmanKeyValue]
    public let hash: String?
    public let variables: [PostmanVariable]

    private enum CodingKeys: String, CodingKey {
        case raw
        case protocolName = "protocol"
        case host
        case path
        case port
        case query
        case hash
        case variables = "variable"
    }

    public init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            self.raw = text
            self.protocolName = nil
            self.host = []
            self.path = []
            self.port = nil
            self.query = []
            self.hash = nil
            self.variables = []
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.raw = try container.decodeIfPresent(String.self, forKey: .raw)
        self.protocolName = try container.decodeIfPresent(String.self, forKey: .protocolName)
        self.host = try container.decodeList(forKey: .host)
        self.path = try container.decodeList(forKey: .path)
        self.port = try container.decodeIfPresent(String.self, forKey: .port)
        self.query = try container.decodeList(forKey: .query)
        self.hash = try container.decodeIfPresent(String.self, forKey: .hash)
        self.variables = try container.decodeList(forKey: .variables)
    }

}
