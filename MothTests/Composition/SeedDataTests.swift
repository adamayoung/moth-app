//  SeedDataTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct SeedDataTests {

    private let signature = AppSignature(teamIdentifier: nil, keychainAccessGroup: nil)

    @Test("UI-test and demo launches hold the fixed collection and environment", arguments: [
        AppLaunchMode.uiTesting,
        .demo
    ])
    func seededLaunchesHoldTheSeed(mode: AppLaunchMode) throws {
        let dataModel = try dataModel(for: mode)

        let workspaces = try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>())

        #expect(try workspaces.map { try $0.asDomain() } == [SeedData.workspace])
    }

    @Test("The seed holds one collection and one environment, with fixed identifiers")
    func seedIsFixed() throws {
        let collection = try #require(SeedData.workspace.collections.first)
        let environment = try #require(SeedData.workspace.environments.first)

        #expect(SeedData.workspace.collections.count == 1)
        #expect(SeedData.workspace.environments.count == 1)
        #expect(collection.id.uuidString == "00000000-0000-0000-0000-000000000002")
        #expect(environment.id.uuidString == "00000000-0000-0000-0000-000000000004")
    }

    @Test("The seed gives the delete alert a plural folder and a singular one, as MothUITests expects")
    func seedHoldsBothDeleteCounts() throws {
        let collection = try #require(SeedData.workspace.collections.first)
        guard case .folder(let users) = try #require(collection.children.first).node,
              case .folder(let admins) = try #require(users.children.last).node else {
            Issue.record("The seed's first child should be Users, with Admins last inside it")
            return
        }

        #expect(users.name == "Users")
        #expect(users.children.count == 4)
        #expect(admins.name == "Admins")
        #expect(admins.children.count == 1)
    }

    @Test("The test host's store is empty")
    func hostStoreIsEmpty() throws {
        let dataModel = try dataModel(for: .testHost)

        #expect(try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>()).isEmpty)
    }

    private func dataModel(for mode: AppLaunchMode) throws -> DataModel {
        try DependencyProvider(
            launchMode: mode,
            infoDictionary: [:],
            signature: signature,
            openLiveDataModel: { _ in try .inMemory() }
        ).dependencies.dataModel
    }

}
