//  CurlImportModelTests+Availability.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import MothCore
import Testing

extension CurlImportModelTests {

    @Test("File > Import… is unavailable while the sheet is up, and Import cURL… too")
    func theSheetBlocksOtherImports() throws {
        try deliverRows()
        let model = makeModel()

        model.beginCurlImport()

        #expect(!model.canImport)
        #expect(!model.canImportCurl)
    }

    @Test("Import cURL… is unavailable while the Authorization sheet is up")
    func theAuthorizationSheetBlocksTheSheet() throws {
        try deliverRows()
        let model = makeModel()
        let node = try #require(sidebar.tree.node(.collection(collection.id)))

        sidebar.presentAuthorization(of: node)

        #expect(!model.canImportCurl)
    }

    @Test("Cancel does nothing once an import is running, because the import can't be stopped")
    func cancelWaitsForARunningImport() async throws {
        try deliverRows()
        let secretStore = ThreadHoldingSecretStore()
        let model = makeModel(secretStore: secretStore)
        model.beginCurlImport()
        model.curlText = "curl -u user:pass https://a.example/users"

        let running = Task { await model.importCurl() }
        await secretStore.waitUntilHolding()
        model.cancelCurlImport()
        let stayedOpen = model.isEnteringCurl
        secretStore.letGo()
        await running.value

        #expect(stayedOpen)
        #expect(!model.isEnteringCurl)
    }

    @Test("Import cURL… is unavailable while a result is showing")
    func aResultBlocksTheSheet() async throws {
        try deliverRows()
        let model = makeModel()

        await importing("curl -s https://a.example/users", into: model)

        #expect(!model.canImportCurl)
        model.beginCurlImport()
        #expect(!model.isEnteringCurl)
    }

}
