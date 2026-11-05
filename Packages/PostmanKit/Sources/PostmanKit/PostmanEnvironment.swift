//  PostmanEnvironment.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanEnvironment: Decodable, Sendable, Equatable {

    public let id: String?
    public let name: String?
    public let values: [PostmanEnvironmentValue]

}
