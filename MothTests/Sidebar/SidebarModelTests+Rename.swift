//  SidebarModelTests+Rename.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import MothCore
import Testing

extension SidebarModelTests {

    @Test("Committing a rename changes the name, trimmed, and ends the edit")
    func commitRename() async throws {
        await model.beginRename(of: .request(top.id))

        model.renameDraft = "  Renamed  "
        await model.commitRename(of: .request(top.id))
        try deliverTree()

        #expect(model.tree.node(.request(top.id))?.name == "Renamed")
        #expect(model.renaming == nil)
    }

    @Test("An empty name restores the old one and ends the edit", arguments: ["", "   ", "\n"])
    func emptyRenameRestores(draft: String) async throws {
        await model.beginRename(of: .request(top.id))

        model.renameDraft = draft
        await model.commitRename(of: .request(top.id))
        try deliverTree()

        #expect(model.tree.node(.request(top.id))?.name == "Top")
        #expect(model.renaming == nil)
    }

    @Test("Cancelling a rename keeps the old name, and a later commit from the field is ignored")
    func cancelRename() async throws {
        await model.beginRename(of: .request(top.id))

        model.cancelRename()
        model.renameDraft = "Renamed"
        await model.commitRename(of: .request(top.id))
        try deliverTree()

        #expect(model.tree.node(.request(top.id))?.name == "Top")
        #expect(model.renaming == nil)
    }

    @Test("Starting a new item saves a rename in progress")
    func newItemSavesARenameInProgress() async throws {
        await model.beginRename(of: .request(top.id))
        model.renameDraft = "Typed"

        await model.newRequest(in: .collection(other.id))
        try deliverTree()

        #expect(model.tree.node(.request(top.id))?.name == "Typed")
        #expect(model.renameDraft == "New Request")
        #expect(model.renaming == model.selection)
    }

    @Test("Renaming another row saves the rename in progress")
    func anotherRenameSavesTheFirst() async throws {
        await model.beginRename(of: .request(top.id))
        model.renameDraft = "Typed"

        await model.beginRename(of: .folder(empty.id))
        try deliverTree()

        #expect(model.tree.node(.request(top.id))?.name == "Typed")
        #expect(model.renaming == .folder(empty.id))
        #expect(model.renameDraft == "Empty")
    }

    @Test("A commit from a field that has gone does not end the edit that replaced it")
    func lateCommitLeavesTheNewEditAlone() async {
        await model.beginRename(of: .request(top.id))
        await model.beginRename(of: .folder(empty.id))
        model.renameDraft = "Typing"

        await model.commitRename(of: .request(top.id))

        #expect(model.renaming == .folder(empty.id))
        #expect(model.renameDraft == "Typing")
    }

}
