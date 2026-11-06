//  SidebarDragItem.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import CoreTransferable
import MothCore
import UniformTypeIdentifiers

/// `Configs/Info.plist` declares this type, as `exportedAs:` requires.
nonisolated extension UTType {

    static let mothTreeNode = UTType(exportedAs: "uk.co.adam-young.moth.tree-node")

}

nonisolated struct SidebarDragItem: Identifiable, Codable, Transferable {

    let id: TreeNodeID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .mothTreeNode)
    }

}
