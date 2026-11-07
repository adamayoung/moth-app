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
    var isEnteringCurl = false
    var curlText = ""
    var curlProblem: CurlImportProblem?
    private(set) var isImporting = false

    private let source: ImportFileSource
    private let importer: PostmanImporter
    private let curlImporter: CurlImporter
    private let sidebar: SidebarModel
    private let environments: EnvironmentsModel
    private let write: @Sendable (PostmanImportContent) async throws -> Void
    private let createRequest: @Sendable (Request, TreeContainerID) async throws -> Void
    private let openRequest: (Request.ID) -> Void

    init(
        source: ImportFileSource,
        secretStore: any SecretStore,
        sidebar: SidebarModel,
        environments: EnvironmentsModel,
        write: @escaping @Sendable (PostmanImportContent) async throws -> Void,
        createRequest: @escaping @Sendable (Request, TreeContainerID) async throws -> Void,
        openRequest: @escaping (Request.ID) -> Void
    ) {
        self.source = source
        self.importer = PostmanImporter(secretStore: secretStore)
        self.curlImporter = CurlImporter(secretStore: secretStore)
        self.sidebar = sidebar
        self.environments = environments
        self.write = write
        self.createRequest = createRequest
        self.openRequest = openRequest
    }

    var canImport: Bool {
        !isImporting && !isChoosingFile && report == nil && !isAnotherPresentationUp
    }

    private var isAnotherPresentationUp: Bool {
        isEnteringCurl || sidebar.presentedVariables != nil || sidebar.pendingDeletion != nil
            || environments.pendingDeletion != nil
    }

    var canImportCurl: Bool {
        canImport && sidebar.importContainer != nil
    }

    var canSubmitCurl: Bool {
        !isImporting && !curlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func beginCurlImport() {
        guard canImportCurl else {
            return
        }
        curlText = ""
        curlProblem = nil
        isEnteringCurl = true
    }

    func cancelCurlImport() {
        isEnteringCurl = false
    }

    /// A failure keeps the sheet, because closing it would lose the pasted text.
    func importCurl() async {
        guard canSubmitCurl, let container = sidebar.importContainer else {
            return
        }
        isImporting = true
        defer { isImporting = false }
        curlProblem = nil

        do {
            let result = try await curlImporter.importCommand(curlText) { [createRequest] request in
                try await createRequest(request, container)
            }
            isEnteringCurl = false
            sidebar.revealRequest(result.request.id, in: container)
            openRequest(result.request.id)
            report = ImportReport(result)
        } catch CurlImportError.notACurlCommand {
            curlProblem = .invalidCommand
        } catch {
            Logger.imports.error("A cURL import failed: \(String(describing: error), privacy: .private)")
            curlProblem = .failed
        }
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
