//  RequestResponsesTesting.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import Moth
import MothCore
import SwiftData

@MainActor
protocol RequestResponsesTesting {}

extension RequestResponsesTesting {

    func responses(
        holding request: Request,
        collectionAuth: Auth = .none,
        through transport: any HTTPTransport,
        secretStore: any SecretStore = InMemorySecretStore()
    ) throws -> (DataModel, RequestResponses, CollectionTree) {
        let production = WorkspaceEnvironment(name: "Production", variables: [
            Variable(
                name: "host",
                value: .plain(initial: "https://production.test", current: "https://production.test")
            )
        ])
        let staging = WorkspaceEnvironment(name: "Staging", variables: [
            Variable(name: "host", value: .plain(initial: "https://staging.test", current: "https://staging.test"))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            collections: [RequestCollection(
                name: "API",
                auth: collectionAuth,
                children: [CollectionItem(sortOrder: 0, node: .request(request))]
            )],
            environments: [production, staging]
        ))
        let responses = RequestResponses(
            dataModel: dataModel,
            transport: transport,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: staging.id)
        )
        return try (dataModel, responses, tree(of: dataModel))
    }

    func tree(of dataModel: DataModel) throws -> CollectionTree {
        try CollectionTree(
            collections: dataModel.mainContext.fetch(.init()),
            folders: dataModel.mainContext.fetch(.init()),
            requests: dataModel.mainContext.fetch(.init())
        )
    }

}
