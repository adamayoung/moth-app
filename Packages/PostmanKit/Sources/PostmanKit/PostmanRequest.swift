//  PostmanRequest.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanRequest: Decodable, Sendable, Equatable {

    public let url: PostmanURL?
    public let method: String?
    public let headers: [PostmanKeyValue]
    public let auth: PostmanAuth?
    public let body: PostmanBody?
    public let description: PostmanDescription?

    private enum CodingKeys: String, CodingKey {
        case url
        case method
        case headers = "header"
        case auth
        case body
        case description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(PostmanURL.self, forKey: .url)
        self.method = try container.decodeIfPresent(String.self, forKey: .method)
        self.headers = try container.decodeList(forKey: .headers)
        self.auth = try container.decodeIfPresent(PostmanAuth.self, forKey: .auth)
        self.body = try container.decodeIfPresent(PostmanBody.self, forKey: .body)
        self.description = try container.decodeIfPresent(PostmanDescription.self, forKey: .description)
    }

}
