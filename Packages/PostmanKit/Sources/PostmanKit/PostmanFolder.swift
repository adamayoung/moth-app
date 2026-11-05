//  PostmanFolder.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanFolder: Decodable, Sendable, Equatable {

    public let name: String?
    public let items: [PostmanItem]

    private enum CodingKeys: String, CodingKey {
        case name
        case items = "item"
    }

}
