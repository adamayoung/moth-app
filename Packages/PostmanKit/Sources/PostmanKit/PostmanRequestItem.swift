//  PostmanRequestItem.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanRequestItem: Decodable, Sendable, Equatable {

    public let name: String?
    public let request: PostmanRequest

}
