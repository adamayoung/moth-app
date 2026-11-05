//  RequestCollection.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Not `Collection`, which would shadow `Swift.Collection` in every file importing this module.
public nonisolated struct RequestCollection: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var name: String
    public var auth: Auth
    public var variables: [Variable]
    public var children: [CollectionItem] {
        didSet {
            children = CollectionItem.inOrder(children)
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        auth: Auth = .none,
        variables: [Variable] = [],
        children: [CollectionItem] = []
    ) {
        self.id = id
        self.name = name
        self.auth = auth
        self.variables = variables
        self.children = CollectionItem.inOrder(children)
    }

}
