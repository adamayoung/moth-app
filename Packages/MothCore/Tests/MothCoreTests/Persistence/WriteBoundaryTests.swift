//  WriteBoundaryTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import SwiftData
import Testing

// The plain `import` is the point: this file sees what the app sees. Do not make it `@testable`.

private func isWritable(_: ReferenceWritableKeyPath<some Any, some Any>) -> Bool {
    true
}

/// The compiler picks this overload only when the setter is out of reach here. A key path's runtime type says
/// nothing: `\Model.property` is a `ReferenceWritableKeyPath` at run time even with an `internal(set)` property.
@_disfavoredOverload
private func isWritable(_: KeyPath<some Any, some Any>) -> Bool {
    false
}

private final class AccessControl {
    var open = 0
    private(set) var closed = 0
}

struct WriteBoundaryTests {

    private static let modelProperties: [String: Bool] = [
        "WorkspaceModel.id": isWritable(\WorkspaceModel.id),
        "WorkspaceModel.activeEnvironmentID": isWritable(\WorkspaceModel.activeEnvironmentID),
        "WorkspaceModel.collections": isWritable(\WorkspaceModel.collections),
        "WorkspaceModel.environments": isWritable(\WorkspaceModel.environments),
        "WorkspaceModel.globals": isWritable(\WorkspaceModel.globals),
        "CollectionModel.id": isWritable(\CollectionModel.id),
        "CollectionModel.name": isWritable(\CollectionModel.name),
        "CollectionModel.sortOrder": isWritable(\CollectionModel.sortOrder),
        "CollectionModel.authData": isWritable(\CollectionModel.authData),
        "CollectionModel.workspace": isWritable(\CollectionModel.workspace),
        "CollectionModel.folders": isWritable(\CollectionModel.folders),
        "CollectionModel.requests": isWritable(\CollectionModel.requests),
        "CollectionModel.variables": isWritable(\CollectionModel.variables),
        "FolderModel.id": isWritable(\FolderModel.id),
        "FolderModel.name": isWritable(\FolderModel.name),
        "FolderModel.sortOrder": isWritable(\FolderModel.sortOrder),
        "FolderModel.authData": isWritable(\FolderModel.authData),
        "FolderModel.collection": isWritable(\FolderModel.collection),
        "FolderModel.parent": isWritable(\FolderModel.parent),
        "FolderModel.subfolders": isWritable(\FolderModel.subfolders),
        "FolderModel.requests": isWritable(\FolderModel.requests),
        "RequestModel.id": isWritable(\RequestModel.id),
        "RequestModel.name": isWritable(\RequestModel.name),
        "RequestModel.methodRawValue": isWritable(\RequestModel.methodRawValue),
        "RequestModel.urlTemplate": isWritable(\RequestModel.urlTemplate),
        "RequestModel.sortOrder": isWritable(\RequestModel.sortOrder),
        "RequestModel.queryParametersData": isWritable(\RequestModel.queryParametersData),
        "RequestModel.pathParametersData": isWritable(\RequestModel.pathParametersData),
        "RequestModel.headersData": isWritable(\RequestModel.headersData),
        "RequestModel.authData": isWritable(\RequestModel.authData),
        "RequestModel.settingsData": isWritable(\RequestModel.settingsData),
        "RequestModel.collection": isWritable(\RequestModel.collection),
        "RequestModel.folder": isWritable(\RequestModel.folder),
        "RequestModel.bodyData": isWritable(\RequestModel.bodyData),
        "RequestModel.variables": isWritable(\RequestModel.variables),
        "EnvironmentModel.id": isWritable(\EnvironmentModel.id),
        "EnvironmentModel.name": isWritable(\EnvironmentModel.name),
        "EnvironmentModel.sortOrder": isWritable(\EnvironmentModel.sortOrder),
        "EnvironmentModel.workspace": isWritable(\EnvironmentModel.workspace),
        "EnvironmentModel.variables": isWritable(\EnvironmentModel.variables),
        "VariableModel.id": isWritable(\VariableModel.id),
        "VariableModel.name": isWritable(\VariableModel.name),
        "VariableModel.initialValue": isWritable(\VariableModel.initialValue),
        "VariableModel.currentValue": isWritable(\VariableModel.currentValue),
        "VariableModel.secretIdentifier": isWritable(\VariableModel.secretIdentifier),
        "VariableModel.isEnabled": isWritable(\VariableModel.isEnabled),
        "VariableModel.sortOrder": isWritable(\VariableModel.sortOrder),
        "VariableModel.isGlobal": isWritable(\VariableModel.isGlobal),
        "VariableModel.workspace": isWritable(\VariableModel.workspace),
        "VariableModel.collection": isWritable(\VariableModel.collection),
        "VariableModel.environment": isWritable(\VariableModel.environment),
        "VariableModel.request": isWritable(\VariableModel.request),
        "HistoryEntryModel.id": isWritable(\HistoryEntryModel.id),
        "HistoryEntryModel.requestID": isWritable(\HistoryEntryModel.requestID),
        "HistoryEntryModel.requestData": isWritable(\HistoryEntryModel.requestData),
        "HistoryEntryModel.sentAt": isWritable(\HistoryEntryModel.sentAt),
        "HistoryEntryModel.durationSeconds": isWritable(\HistoryEntryModel.durationSeconds),
        "HistoryEntryModel.durationAttoseconds": isWritable(\HistoryEntryModel.durationAttoseconds),
        "HistoryEntryModel.statusCode": isWritable(\HistoryEntryModel.statusCode),
        "HistoryEntryModel.responseHeadersData": isWritable(\HistoryEntryModel.responseHeadersData),
        "HistoryEntryModel.failure": isWritable(\HistoryEntryModel.failure),
        "HistoryEntryModel.responseBody": isWritable(\HistoryEntryModel.responseBody),
        "CookieModel.id": isWritable(\CookieModel.id),
        "CookieModel.workspaceID": isWritable(\CookieModel.workspaceID),
        "CookieModel.name": isWritable(\CookieModel.name),
        "CookieModel.domain": isWritable(\CookieModel.domain),
        "CookieModel.isHostOnly": isWritable(\CookieModel.isHostOnly),
        "CookieModel.path": isWritable(\CookieModel.path),
        "CookieModel.expiresAt": isWritable(\CookieModel.expiresAt),
        "CookieModel.isSecure": isWritable(\CookieModel.isSecure),
        "CookieModel.isHTTPOnly": isWritable(\CookieModel.isHTTPOnly),
        "CookieModel.createdAt": isWritable(\CookieModel.createdAt),
        "CookieModel.valueIdentifier": isWritable(\CookieModel.valueIdentifier)
    ]

    private static var dataModelSources: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../../../Sources/MothCore/DataModels")
            .standardizedFileURL
    }

    @Test("The writability check tells a public setter from a hidden one")
    func writabilityCheckWorks() {
        #expect(isWritable(\AccessControl.open))
        #expect(!isWritable(\AccessControl.closed))
    }

    @Test("Code outside MothCore can set no property of any model")
    func noModelPropertyIsWritable() {
        let writable = Self.modelProperties.filter(\.value).keys.sorted()

        #expect(writable.isEmpty)
    }

    @Test("The writability check covers every stored property in the schema")
    func everyStoredPropertyIsChecked() {
        let schema = Schema(versionedSchema: SchemaV2.self)

        let stored = schema.entities.flatMap { entity in
            entity.storedProperties.map { "\(entity.name).\($0.name)" }
        }

        #expect(Set(stored) == Set(Self.modelProperties.keys))
    }

    @Test("Code outside MothCore cannot make a model or reach the writer's context")
    func noPublicRouteToAWrite() throws {
        let sources = try #require(
            FileManager.default.subpaths(atPath: Self.dataModelSources.path(percentEncoded: false))
        )

        let offending = try sources.filter { $0.hasSuffix(".swift") }.filter { path in
            let source = try String(
                contentsOf: Self.dataModelSources.appending(path: path),
                encoding: .utf8
            )
            let makesModels = path.hasPrefix("Schema/") || path.hasPrefix("Mapping/")
            return source.split(separator: "\n").contains { line in
                Self.exposesTheWriter(line) || makesModels && line.contains("public") && line.contains(" init(")
            }
        }

        #expect(!sources.isEmpty)
        #expect(offending.isEmpty)
    }

    private static func exposesTheWriter(_ line: Substring) -> Bool {
        guard line.contains("public ") else {
            return false
        }

        return line.contains("ModelContext") && !line.contains("var mainContext") || line.contains("func write")
    }

}
