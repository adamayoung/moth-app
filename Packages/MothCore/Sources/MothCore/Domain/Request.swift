//  Request.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct Request: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var name: String
    public var method: HTTPMethod
    public var urlTemplate: String
    public var queryParameters: [KeyValue]
    public var pathParameters: [KeyValue]
    public var headers: [KeyValue]
    public var body: RequestBody
    public var auth: Auth
    public var settings: RequestSettings
    public var variables: [Variable]

    public init(
        id: UUID = UUID(),
        name: String,
        method: HTTPMethod = .get,
        urlTemplate: String = "",
        queryParameters: [KeyValue] = [],
        pathParameters: [KeyValue] = [],
        headers: [KeyValue] = [],
        body: RequestBody = .none,
        auth: Auth = .inherit,
        settings: RequestSettings = RequestSettings(),
        variables: [Variable] = []
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.urlTemplate = urlTemplate
        self.queryParameters = queryParameters
        self.pathParameters = pathParameters
        self.headers = headers
        self.body = body
        self.auth = auth
        self.settings = settings
        self.variables = variables
    }

}
