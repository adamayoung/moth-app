//  CollectionTreeObserver.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

/// Owns the queries, apart from the views that show the tree, because those also read selection, and building the
/// tree on each of their updates would walk every row on every click. It sits above the sidebar column, so the tabs
/// never depend on that column being in the hierarchy.
struct CollectionTreeObserver: View {

    let onChange: (CollectionTree) -> Void

    @Query private var collections: [CollectionModel]
    @Query private var folders: [FolderModel]
    @Query private var requests: [RequestModel]

    var body: some View {
        Color.clear
            .onChange(of: tree, initial: true) { _, newTree in
                onChange(newTree)
            }
    }

    private var tree: CollectionTree {
        CollectionTree(collections: collections, folders: folders, requests: requests)
    }

}
