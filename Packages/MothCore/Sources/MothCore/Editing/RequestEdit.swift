//  RequestEdit.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// The fields the editor owns. It has no name, so a Save cannot undo a rename made in the sidebar.
public nonisolated struct RequestEdit: Sendable, Hashable {

    public var method: HTTPMethod
    public var urlTemplate: String
    public var queryParameters: [KeyValue]
    public var pathParameters: [KeyValue]
    public var headers: [KeyValue]

    public init(
        method: HTTPMethod = .get,
        urlTemplate: String = "",
        queryParameters: [KeyValue] = [],
        pathParameters: [KeyValue] = [],
        headers: [KeyValue] = []
    ) {
        self.method = method
        self.urlTemplate = urlTemplate
        self.queryParameters = queryParameters
        self.pathParameters = pathParameters
        self.headers = headers
    }

    public init(_ request: Request) {
        self.init(
            method: request.method,
            urlTemplate: request.urlTemplate,
            queryParameters: request.queryParameters,
            pathParameters: request.pathParameters,
            headers: request.headers
        )
    }

}
