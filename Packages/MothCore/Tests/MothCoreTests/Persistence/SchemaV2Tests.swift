//  SchemaV2Tests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct SchemaV2Tests {

    private static let frozenFingerprint = """
    version 2.0.0
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
    HistoryEntryModel.failureKind: Optional<String>
    HistoryEntryModel.id: UUID
    HistoryEntryModel.method: String
    HistoryEntryModel.reasonPhrase: Optional<String>
    HistoryEntryModel.requestData: Optional<Data>
    HistoryEntryModel.requestID: UUID
    HistoryEntryModel.responseBody: Optional<Data> [externalStorage]
    HistoryEntryModel.responseHeadersData: Optional<Data>
    HistoryEntryModel.responseSize: Int
    HistoryEntryModel.sentAt: Date
    HistoryEntryModel.statusCode: Optional<Int>
    HistoryEntryModel.timingData: Optional<Data>
    HistoryEntryModel.url: String
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

    @Test("The frozen SchemaV2 matches its pinned fingerprint, so a change to it needs a SchemaV3")
    func schemaMatchesItsFingerprint() {
        let schema = Schema(versionedSchema: SchemaV2.self)

        #expect(SchemaInspection.fingerprint(of: schema) == Self.frozenFingerprint)
    }

    @Test("SchemaV2 changes only the local store, so CloudKit sees no change")
    func syncedModelsAreSchemaV1s() {
        #expect(SchemaV2.syncedModels.map { "\($0)" } == SchemaV1.syncedModels.map { "\($0)" })
    }

    @Test("No model in SchemaV2 breaks the CloudKit rules")
    func schemaFollowsTheCloudKitRules() {
        let schema = Schema(versionedSchema: SchemaV2.self)

        #expect(SchemaInspection.cloudKitViolations(in: schema).isEmpty)
    }

    @Test("The migration plan holds SchemaV1 then SchemaV2, with no stage between them")
    func migrationPlanHoldsBothVersions() {
        #expect(MothMigrationPlan.schemas.map { "\($0)" } == ["SchemaV1", "SchemaV2"])
        #expect(MothMigrationPlan.stages.isEmpty)
        #expect(CurrentSchema.self == SchemaV2.self)
    }

    @Test("A SchemaV1 store with a history row opens as SchemaV2 and keeps the row")
    func schemaV1StoreMigrates() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entryID = UUID()
        do {
            let schema = Schema(SchemaV1.localModels, version: SchemaV1.versionIdentifier)
            let configuration = CharacterisationStore.onDiskConfiguration(named: "Local", schema: schema, in: directory)
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)
            let row = SchemaV1.HistoryEntryModel()
            row.id = entryID
            row.statusCode = 200
            context.insert(row)
            try context.save()
        }

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
        let rows = try dataModel.mainContext.fetch(FetchDescriptor<HistoryEntryModel>())

        #expect(rows.map(\.id) == [entryID])
        #expect(rows.first?.statusCode == 200)
        #expect(rows.first?.responseSize == 0)
    }

}
