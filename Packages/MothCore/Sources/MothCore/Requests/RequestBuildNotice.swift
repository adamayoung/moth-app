//  RequestBuildNotice.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum RequestBuildNotice: Sendable, Hashable {

    case unsupportedAuth(UnsupportedAuthKind)
    case unsupportedBody(UnsupportedBodyKind)
    case unsupportedFormDataFile(key: String)
    case unsendableHeader(name: String)
    case emptyHeaderName(name: String)
    case emptyQueryParameterName(name: String)
    case emptyFieldName(name: String)
    case bodyNotSent(method: HTTPMethod)
    case formDataBoundaryNotDeclared
    case pathVariableWithoutValue(name: String)
    case unnamedPathVariableWithoutValue
    case inheritNotReplaced
    case apiKeyWithoutName

}

public nonisolated enum UnsupportedAuthKind: Sendable, Hashable {

    case digest
    case oauth2

}

public nonisolated enum UnsupportedBodyKind: Sendable, Hashable {

    case binary
    case graphQL

}
