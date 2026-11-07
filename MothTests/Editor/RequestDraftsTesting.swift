//  RequestDraftsTesting.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
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

    /// Every stored field of the row as text, so a credential can't hide in one a test forgot to name.
    func storedText(of row: RequestModel) -> String {
        let fields = [row.queryParametersData, row.pathParametersData, row.headersData, row.bodyData, row.authData]
        return fields.compactMap(\.self).compactMap { String(bytes: $0, encoding: .utf8) }.joined()
            + row.name + row.urlTemplate
    }

    func savedRequest(_ id: Request.ID, in dataModel: DataModel) throws -> RequestModel {
        try #require(ModelContext(dataModel.container).fetch(RequestModel.withID(id)).first)
    }

}
