//  Folder.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct Folder: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var name: String
    public var auth: Auth
    public private(set) var children: [CollectionItem]

    public init(id: UUID = UUID(), name: String, auth: Auth = .inherit, children: [CollectionItem] = []) {
        self.id = id
        self.name = name
        self.auth = auth
        self.children = CollectionItem.inOrder(children)
    }

    public mutating func setChildren(_ children: [CollectionItem]) {
        self.children = CollectionItem.inOrder(children)
    }

}
