//  SchemaV1Tests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

@testable import MothCore
import SwiftData
import Testing

struct SchemaV1Tests {

    private static let frozenFingerprint = """
    version 1.0.0
    CollectionModel.authData: Optional<Data>
    CollectionModel.folders -> FolderModel to-many cascade inverse collection
    CollectionModel.id: UUID
    CollectionModel.name: String
    CollectionModel.requests -> RequestModel to-many cascade inverse collection
    CollectionModel.sortOrder: Int
    CollectionModel.variables -> VariableModel to-many cascade inverse collection
    CollectionModel.workspace -> WorkspaceModel to-one nullify inverse collections
    EnvironmentModel.id: UUID
    EnvironmentModel.name: String
    EnvironmentModel.sortOrder: Int
    EnvironmentModel.variables -> VariableModel to-many cascade inverse environment
    EnvironmentModel.workspace -> WorkspaceModel to-one nullify inverse environments
    FolderModel.authData: Optional<Data>
    FolderModel.collection -> CollectionModel to-one nullify inverse folders
    FolderModel.id: UUID
    FolderModel.name: String
    FolderModel.parent -> FolderModel to-one nullify inverse subfolders
    FolderModel.requests -> RequestModel to-many cascade inverse folder
    FolderModel.sortOrder: Int
    FolderModel.subfolders -> FolderModel to-many cascade inverse parent
    HistoryEntryModel.durationAttoseconds: Int64
    HistoryEntryModel.durationSeconds: Int64
    HistoryEntryModel.failure: Optional<String>
    HistoryEntryModel.id: UUID
    HistoryEntryModel.requestData: Optional<Data>
    HistoryEntryModel.requestID: UUID
    HistoryEntryModel.responseBody: Optional<Data> [externalStorage]
    HistoryEntryModel.responseHeadersData: Optional<Data>
    HistoryEntryModel.sentAt: Date
    HistoryEntryModel.statusCode: Optional<Int>
    RequestModel.authData: Optional<Data>
    RequestModel.bodyData: Optional<Data> [externalStorage]
    RequestModel.collection -> CollectionModel to-one nullify inverse requests
    RequestModel.folder -> FolderModel to-one nullify inverse requests
    RequestModel.headersData: Optional<Data>
    RequestModel.id: UUID
    RequestModel.methodRawValue: String
    RequestModel.name: String
    RequestModel.pathParametersData: Optional<Data>
    RequestModel.queryParametersData: Optional<Data>
    RequestModel.settingsData: Optional<Data>
    RequestModel.sortOrder: Int
    RequestModel.urlTemplate: String
    RequestModel.variables -> VariableModel to-many cascade inverse request
    VariableModel.collection -> CollectionModel to-one nullify inverse variables
    VariableModel.currentValue: String
    VariableModel.environment -> EnvironmentModel to-one nullify inverse variables
    VariableModel.id: UUID
    VariableModel.initialValue: String
    VariableModel.isEnabled: Bool
    VariableModel.isGlobal: Bool
    VariableModel.name: String
    VariableModel.request -> RequestModel to-one nullify inverse variables
    VariableModel.secretIdentifier: Optional<String>
    VariableModel.sortOrder: Int
    VariableModel.workspace -> WorkspaceModel to-one nullify inverse globals
    WorkspaceModel.activeEnvironmentID: Optional<UUID>
    WorkspaceModel.collections -> CollectionModel to-many nullify inverse workspace
    WorkspaceModel.environments -> EnvironmentModel to-many nullify inverse workspace
    WorkspaceModel.globals -> VariableModel to-many nullify inverse workspace
    WorkspaceModel.id: UUID
    """

    @Test("The frozen SchemaV1 matches its pinned fingerprint, so a change to it needs a SchemaV2")
    func schemaMatchesItsFingerprint() {
        let schema = Schema(versionedSchema: SchemaV1.self)

        #expect(SchemaInspection.fingerprint(of: schema) == Self.frozenFingerprint)
    }

    @Test("The fingerprint changes when an attribute is added")
    func fingerprintSeesAnAddedAttribute() {
        let baseline = Schema([BaselineFixture.Owner.self, BaselineFixture.Item.self])
        let changed = Schema([AddedAttributeFixture.Owner.self, AddedAttributeFixture.Item.self])

        #expect(SchemaInspection.fingerprint(of: baseline) != SchemaInspection.fingerprint(of: changed))
    }

    @Test("The fingerprint changes when a delete rule changes")
    func fingerprintSeesAChangedDeleteRule() {
        let baseline = Schema([BaselineFixture.Owner.self, BaselineFixture.Item.self])
        let changed = Schema([ChangedDeleteRuleFixture.Owner.self, ChangedDeleteRuleFixture.Item.self])

        #expect(SchemaInspection.fingerprint(of: baseline) != SchemaInspection.fingerprint(of: changed))
    }

    @Test("No model in SchemaV1 breaks the CloudKit rules")
    func schemaFollowsTheCloudKitRules() {
        let schema = Schema(versionedSchema: SchemaV1.self)

        #expect(SchemaInspection.cloudKitViolations(in: schema).isEmpty)
    }

    @Test("Every CloudKit rule is checked")
    func violationCheckSeesEveryRule() {
        let schema = Schema([CloudKitViolationsFixture.Owner.self, CloudKitViolationsFixture.Item.self])

        #expect(SchemaInspection.cloudKitViolations(in: schema) == [
            "Owner.code is unique",
            "Owner.items denies deletes",
            "Owner.items has no inverse",
            "Owner.required has no inverse",
            "Owner.required is required",
            "Owner.requiredWithNoDefault has no default"
        ])
    }

    @Test("Every synced model but the workspace orders itself with sortOrder")
    func syncedChildrenHaveASortOrder() {
        let schema = Schema(SchemaV1.syncedModels, version: SchemaV1.versionIdentifier)

        let unordered = schema.entities
            .filter { $0.attributesByName["sortOrder"] == nil }
            .map(\.name)

        #expect(unordered == ["WorkspaceModel"])
    }

    @Test("History refers to its request by identifier, with no relationship")
    func historyHasNoRelationship() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let history = try #require(schema.entitiesByName["HistoryEntryModel"])

        #expect(history.relationships.isEmpty)
        #expect(history.attributesByName["requestID"] != nil)
    }

}
