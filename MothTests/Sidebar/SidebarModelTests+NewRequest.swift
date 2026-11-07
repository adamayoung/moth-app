//  SidebarModelTests+NewRequest.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

extension SidebarModelTests {

    @Test("With nothing selected, New Request goes in the first collection")
    func nothingSelectedRequestGoesInTheFirstCollection() {
        #expect(model.newRequestContainer == .collection(collection.id))
    }

    @Test("New Request goes where New Folder does when a row is selected")
    func selectedRowPlacesANewRequest() {
        model.selection = .folder(inner.id)
        #expect(model.newRequestContainer == .folder(inner.id))

        model.selection = .request(shallow.id)
        #expect(model.newRequestContainer == .folder(folder.id))
    }

    @Test("With no collection, New Request has nowhere to go")
    func noCollectionHasNoRequestContainer() {
        model.treeDidChange(.empty)

        #expect(model.newRequestContainer == nil)
    }

    @Test("New Request opens the new request in a tab")
    func newRequestOpensATab() async throws {
        var opened: [Request.ID] = []
        let model = SidebarModel(writer: dataModel.writer, secretStore: InMemorySecretStore()) { opened.append($0) }

        await model.newRequest(in: .collection(other.id))

        let selection = try #require(model.selection)
        #expect(opened.map { TreeNodeID.request($0) } == [selection])
    }

    @Test("A New Request that fails to save opens no tab")
    func failedNewRequestOpensNoTab() async {
        var opened: [Request.ID] = []
        let model = SidebarModel(writer: dataModel.writer, secretStore: InMemorySecretStore()) { opened.append($0) }

        await model.newRequest(in: .folder(UUID()))

        #expect(opened.isEmpty)
    }

}
