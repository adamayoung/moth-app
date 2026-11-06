//  ImportModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import MothImport
import Observation
import OSLog

@Observable
final class ImportModel {

    var isChoosingFile = false
    var report: ImportReport?
    private(set) var isImporting = false

    private let source: ImportFileSource
    private let importer: PostmanImporter
    private let sidebar: SidebarModel
    private let environments: EnvironmentsModel
    private let write: @Sendable (PostmanImportContent) async throws -> Void

    init(
        source: ImportFileSource,
        secretStore: any SecretStore,
        sidebar: SidebarModel,
        environments: EnvironmentsModel,
        write: @escaping @Sendable (PostmanImportContent) async throws -> Void
    ) {
        self.source = source
        self.importer = PostmanImporter(secretStore: secretStore)
        self.sidebar = sidebar
        self.environments = environments
        self.write = write
    }

    var canImport: Bool {
        !isImporting && !isChoosingFile && report == nil && !isAnotherPresentationUp
    }

    private var isAnotherPresentationUp: Bool {
        sidebar.presentedVariables != nil || sidebar.pendingDeletion != nil || environments.pendingDeletion != nil
    }

    func chooseFile() async {
        guard canImport else {
            return
        }
        switch source {
        case .panel: isChoosingFile = true
        case .uiTest(let data): await importData(data)
        }
    }

    func fileChosen(_ result: Result<URL, any Error>) async {
        switch result {
        case .success(let url):
            await run(reading: { try await ImportFile.read(url) })
        case .failure(let error as CocoaError) where error.code == .userCancelled:
            break
        case .failure(let error):
            fail(error)
        }
    }

    func importData(_ data: Data) async {
        await run(reading: { data })
    }

    private func run(reading file: () async throws -> Data) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let data = try await file()
            let result = try await importer.importFile(
                data,
                existingCollectionNames: sidebar.collectionNames,
                existingEnvironmentNames: environments.names,
                into: write
            )
            report = ImportReport(result)
        } catch PostmanImportError.unrecognisedFile {
            report = .rejected
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: any Error) {
        Logger.imports.error("An import failed: \(String(describing: error), privacy: .private)")
        report = .failed
    }

}
