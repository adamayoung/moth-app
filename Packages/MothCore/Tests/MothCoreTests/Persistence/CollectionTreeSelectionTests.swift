//  CollectionTreeSelectionTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Testing

nonisolated struct CollectionTreeSelectionTests {

    private static let collectionID = TreeNodeID.collection(id(1))
    private static let folderID = TreeNodeID.folder(id(2))
    private static let innerFolderID = TreeNodeID.folder(id(3))
    private static let requestID = TreeNodeID.request(id(4))
    private static let nestedRequestID = TreeNodeID.request(id(5))
    private static let otherCollectionID = TreeNodeID.collection(id(6))

    /// Collection > Folder > (Inner Folder > Nested Request, Request), and an empty Other Collection.
    private static let tree = CollectionTree(roots: [
        node(collectionID, children: [
            node(folderID, children: [
                node(innerFolderID, children: [node(nestedRequestID)]),
                node(requestID)
            ])
        ]),
        node(otherCollectionID)
    ])

    private static func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    private static func node(_ id: TreeNodeID, children: [TreeNode] = []) -> TreeNode {
        TreeNode(id: id, name: "", method: nil, children: children)
    }

    /// The whole tree with `removed` and everything beneath it gone.
    private static func tree(without removed: TreeNodeID) -> CollectionTree {
        func pruned(_ nodes: [TreeNode]) -> [TreeNode] {
            nodes.filter { $0.id != removed }.map { node($0.id, children: pruned($0.children)) }
        }
        return CollectionTree(roots: pruned(tree.roots))
    }

    @Test(
        "A selection that leaves the tree moves to its nearest surviving ancestor",
        arguments: [
            (selected: requestID, removed: requestID, expected: folderID),
            (selected: innerFolderID, removed: innerFolderID, expected: folderID),
            (selected: nestedRequestID, removed: folderID, expected: collectionID),
            (selected: folderID, removed: folderID, expected: collectionID)
        ] as [(selected: TreeNodeID, removed: TreeNodeID, expected: TreeNodeID)]
    )
    func selectionMovesToAncestor(selected: TreeNodeID, removed: TreeNodeID, expected: TreeNodeID) {
        let selection = Self.tree.selection(selected, carriedTo: Self.tree(without: removed))

        #expect(selection == expected)
    }

    @Test("A selection in a deleted collection goes to nothing")
    func selectionInADeletedCollectionClears() {
        let selection = Self.tree.selection(Self.nestedRequestID, carriedTo: Self.tree(without: Self.collectionID))

        #expect(selection == nil)
    }

    @Test("A selection the change did not touch stays where it is")
    func survivingSelectionStays() {
        let selection = Self.tree.selection(Self.requestID, carriedTo: Self.tree(without: Self.otherCollectionID))

        #expect(selection == Self.requestID)
    }

    @Test("A row the tree has not delivered yet keeps its selection, because it never left")
    func undeliveredSelectionStays() {
        let undelivered = TreeNodeID.request(Self.id(9))

        let selection = Self.tree.selection(undelivered, carriedTo: Self.tree(without: Self.requestID))

        #expect(selection == undelivered)
    }

    @Test("No selection stays no selection")
    func noSelectionStaysNone() {
        #expect(Self.tree.selection(nil, carriedTo: Self.tree) == nil)
    }

    @Test("A node's ancestors run from its collection down to its parent")
    func ancestorsRunTopDown() {
        #expect(Self.tree.ancestors(of: Self.nestedRequestID) == [
            Self.collectionID,
            Self.folderID,
            Self.innerFolderID
        ])
        #expect(Self.tree.ancestors(of: Self.collectionID).isEmpty)
        #expect(Self.tree.ancestors(of: .request(Self.id(9))).isEmpty)
    }

    @Test("A node is found by its identifier, at any depth")
    func nodeIsFoundById() {
        #expect(Self.tree.node(Self.nestedRequestID)?.id == Self.nestedRequestID)
        #expect(Self.tree.node(.request(Self.id(9))) == nil)
    }

}
