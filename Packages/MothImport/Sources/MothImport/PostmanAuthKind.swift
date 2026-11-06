//  PostmanAuthKind.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

public nonisolated enum PostmanAuthKind: Sendable, Hashable {

    case apiKey
    case awsSigV4
    case digest
    case edgeGrid
    case hawk
    case ntlm
    case oauth1
    case oauth2
    case other(String)

}
