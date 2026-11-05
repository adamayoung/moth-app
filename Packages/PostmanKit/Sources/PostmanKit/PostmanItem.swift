//  PostmanItem.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public enum PostmanItem: Decodable, Sendable, Equatable {

    case folder(PostmanFolder)
    case request(PostmanRequestItem)

    private enum CodingKeys: String, CodingKey {
        case item
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = try container.contains(.item)
            ? .folder(PostmanFolder(from: decoder))
            : .request(PostmanRequestItem(from: decoder))
    }

}
