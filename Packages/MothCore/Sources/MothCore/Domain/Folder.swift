//  Folder.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct Folder: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var name: String
    public var auth: Auth
    public var children: [CollectionItem] {
        didSet {
            children = CollectionItem.inOrder(children)
        }
    }

    public init(id: UUID = UUID(), name: String, auth: Auth = .inherit, children: [CollectionItem] = []) {
        self.id = id
        self.name = name
        self.auth = auth
        self.children = CollectionItem.inOrder(children)
    }

}
