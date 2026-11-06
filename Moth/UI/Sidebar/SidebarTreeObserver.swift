//  SidebarTreeObserver.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

/// Owns the queries, apart from the view that shows the tree, because that view also reads selection, and building the
/// tree on each of its updates would walk every row on every click.
struct SidebarTreeObserver: View {

    let model: SidebarModel

    @Query private var collections: [CollectionModel]
    @Query private var folders: [FolderModel]
    @Query private var requests: [RequestModel]

    var body: some View {
        Color.clear
            .onChange(of: tree, initial: true) { _, newTree in
                model.treeDidChange(newTree)
            }
    }

    private var tree: CollectionTree {
        CollectionTree(collections: collections, folders: folders, requests: requests)
    }

}
