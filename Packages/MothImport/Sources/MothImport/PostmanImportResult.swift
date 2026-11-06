//  PostmanImportResult.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

public nonisolated struct PostmanImportResult: Sendable, Hashable {

    public let content: PostmanImportContent
    public let imported: PostmanImportedCounts
    public let skipped: PostmanSkippedCounts
    /// What the import saved, so a caller whose store write fails can remove these.
    public let secrets: [SecretReference]

    public var name: String {
        switch content {
        case .collection(let collection): collection.name
        case .environment(let environment): environment.name
        }
    }

}

public nonisolated enum PostmanImportContent: Sendable, Hashable {

    case collection(RequestCollection)
    case environment(WorkspaceEnvironment)

}

public nonisolated struct PostmanImportedCounts: Sendable, Hashable {

    public internal(set) var folders = 0
    public internal(set) var requests = 0
    public internal(set) var variables = 0
    public internal(set) var unsupportedAuth: [PostmanAuthKind: Int] = [:]

}

public nonisolated struct PostmanSkippedCounts: Sendable, Hashable {

    public internal(set) var scripts = 0
    public internal(set) var folderVariables = 0
    public internal(set) var descriptions = 0
    public internal(set) var bodies = 0
    public internal(set) var exampleResponses = 0
    public internal(set) var auth: [PostmanAuthKind: Int] = [:]

}
