//  RequestBuildNotice.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum RequestBuildNotice: Sendable, Hashable {

    case unsupportedAuth(UnsupportedAuthKind)
    case unsupportedBody(UnsupportedBodyKind)
    case unsupportedFormDataFile(key: String)
    case unsendableHeader(name: String)
    case bodyNotSent(method: HTTPMethod)
    case formDataBoundaryNotDeclared
    case inheritNotReplaced

}

public nonisolated enum UnsupportedAuthKind: Sendable, Hashable {

    case apiKey
    case digest
    case oauth2
    case awsSigV4

}

public nonisolated enum UnsupportedBodyKind: Sendable, Hashable {

    case binary
    case graphQL

}
