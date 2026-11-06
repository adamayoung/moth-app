//  RequestDraftsTesting.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
protocol RequestDraftsTesting {}

extension RequestDraftsTesting {

    func bearer(_ token: SecretReference) -> Auth {
        .bearer(BearerAuth(token: token))
    }

    func stored(
        _ request: Request,
        secretStore: any SecretStore
    ) throws -> (DataModel, RequestDrafts) {
        let dataModel = try DataModel.inMemory(
            seed: Workspace(collections: [RequestCollection(name: "API", children: [
                CollectionItem(sortOrder: 0, node: .request(request))
            ])])
        )
        let drafts = RequestDrafts(writer: dataModel.writer, secretStore: secretStore)
        drafts.savedRequestDidChange(request)
        return (dataModel, drafts)
    }

    func savedRequest(_ id: Request.ID, in dataModel: DataModel) throws -> RequestModel {
        try #require(ModelContext(dataModel.container).fetch(RequestModel.withID(id)).first)
    }

}
