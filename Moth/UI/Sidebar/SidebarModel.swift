//  SidebarModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Observation
import OSLog

/// One window's sidebar state, naming rows by identifier so a sync that removes a row leaves nothing dangling.
@Observable
final class SidebarModel {

    var selection: TreeNodeID?
    var expanded: Set<TreeNodeID> = []
    var pendingDeletion: PendingDeletion?
    var renameDraft = ""
    private(set) var renaming: TreeNodeID?
    private(set) var tree = CollectionTree.empty

    private var hasReceivedTree = false
    private let writer: StoreWriter

    init(writer: StoreWriter) {
        self.writer = writer
    }

    /// Where File > New Folder and New Request put their item. A selected request's parent is the target, because a
    /// new item takes the selection and a second New Request would otherwise be disabled.
    var newItemContainer: TreeContainerID? {
        guard let selection else {
            return nil
        }
        if let container = TreeContainerID(selection) {
            return container
        }
        return tree.ancestors(of: selection).last.flatMap(TreeContainerID.init)
    }

    /// False until the first tree arrives, so a launch with collections never flashes the empty state.
    var showsEmptyState: Bool {
        hasReceivedTree && tree.roots.isEmpty
    }

    func treeDidChange(_ newTree: CollectionTree) {
        hasReceivedTree = true
        selection = tree.selection(selection, carriedTo: newTree)
        if let renaming, tree.contains(renaming), !newTree.contains(renaming) {
            self.renaming = nil
        }
        tree = newTree
    }

    func newCollection() async {
        await commitActiveRename()
        let collection = RequestCollection(name: String(localized: "DEFAULT_COLLECTION_NAME"))
        if await perform({ [writer] in try await writer.createCollection(collection) }) {
            reveal(.collection(collection.id), named: collection.name, in: nil)
        }
    }

    func newFolder(in container: TreeContainerID) async {
        await commitActiveRename()
        let folder = Folder(name: String(localized: "DEFAULT_FOLDER_NAME"))
        if await perform({ [writer] in try await writer.createFolder(folder, in: container) }) {
            reveal(.folder(folder.id), named: folder.name, in: container)
        }
    }

    func newRequest(in container: TreeContainerID) async {
        await commitActiveRename()
        let request = Request(name: String(localized: "DEFAULT_REQUEST_NAME"))
        if await perform({ [writer] in try await writer.createRequest(request, in: container) }) {
            reveal(.request(request.id), named: request.name, in: container)
        }
    }

    func beginRename(of id: TreeNodeID) async {
        await commitActiveRename()
        renaming = id
        renameDraft = tree.node(id)?.name ?? ""
    }

    /// Both Return and the field losing focus arrive here, so only the first of them ends the edit.
    func commitRename(of id: TreeNodeID) async {
        guard renaming == id else {
            return
        }
        renaming = nil

        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }
        await perform { [writer] in try await writer.rename(id, to: name) }
    }

    func cancelRename() {
        renaming = nil
    }

    func requestDeletion(of node: TreeNode) {
        pendingDeletion = PendingDeletion(
            id: node.id,
            name: node.name,
            requestsToMention: node.method == nil && node.requestCount > 0 ? node.requestCount : nil
        )
    }

    /// The selection moves when the query delivers the tree without this row.
    func confirmDeletion(_ deletion: PendingDeletion) async {
        await perform { [writer] in try await writer.delete(deletion.id) }
    }

    func move(_ id: TreeNodeID, to parent: SidebarParent, before: TreeNodeID?) async {
        switch SidebarMove(moving: id, to: parent, before: before, in: tree) {
        case .collection(let id, let before):
            await perform { [writer] in try await writer.moveCollection(id, before: before) }
        case .item(let id, let container, let before):
            await perform { [writer] in try await writer.moveItem(id, to: container, before: before) }
        case nil:
            break
        }
    }

    func drop(_ ids: [TreeNodeID], on parent: SidebarParent, atOffset offset: Int) async {
        await commitActiveRename()
        let siblings: [TreeNode] = switch parent {
        case .root: tree.roots
        case .container(let container): tree.node(TreeNodeID(container))?.children ?? []
        }
        let before = siblings.indices.contains(offset) ? siblings[offset].id : nil
        for id in ids {
            await move(id, to: parent, before: before)
        }
    }

    /// A menu click leaves the field focused, so nothing else commits an edit that a new one is about to replace.
    private func commitActiveRename() async {
        if let renaming {
            await commitRename(of: renaming)
        }
    }

    private func reveal(_ id: TreeNodeID, named name: String, in container: TreeContainerID?) {
        if let container {
            let parent = TreeNodeID(container)
            expanded.formUnion(tree.ancestors(of: parent) + [parent])
        }
        selection = id
        renaming = id
        renameDraft = name
    }

    /// A row that failed to change stays as it was on screen, so the sidebar shows the truth.
    @discardableResult
    private func perform(_ write: () async throws -> Void) async -> Bool {
        do {
            try await write()
            return true
        } catch {
            Logger.sidebar.error("A sidebar write failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

}
