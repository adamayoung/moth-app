//  PostmanEnvironment.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public struct PostmanEnvironment: Decodable, Sendable, Equatable {

    public let id: String?
    public let name: String?
    public let values: [PostmanEnvironmentValue]
    public let scope: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case values
        case scope = "_postman_variable_scope"
    }

}
