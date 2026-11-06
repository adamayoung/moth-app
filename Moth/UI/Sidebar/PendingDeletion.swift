//  PendingDeletion.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore

struct PendingDeletion: Hashable {

    let id: TreeNodeID
    let name: String

    /// Nil when there is nothing to count: a request, or a collection or folder with no requests beneath it.
    let requestsToMention: Int?

}
