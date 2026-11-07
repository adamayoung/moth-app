//  WorkspaceCookieJarFailureTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import SwiftData
import Testing

@MainActor
struct WorkspaceCookieJarFailureTests {

    private let workspaceID = UUID()

    private func jars(_ dataModel: DataModel, secrets: any SecretStore) -> CookieJars {
        CookieJars(writer: dataModel.writer, secretStore: secrets, now: { CookieFixtures.now })
    }

    private func rows(in dataModel: DataModel) throws -> [CookieModel] {
        try dataModel.mainContext.fetch(FetchDescriptor<CookieModel>())
    }

    @Test("Delete All while a cookie is still being stored leaves nothing behind after a relaunch")
    func deleteAllWaitsForAStore() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = ControlledSecretStore()
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        await secrets.holdNextSave()

        let storing = Task { await jar.receive([CookieFixtures.cookie()]) }
        await secrets.waitForHeldSave()
        let deleting = Task { try await jar.deleteAll() }
        while await !jar.all.isEmpty {
            await Task.yield()
        }
        await secrets.releaseSave()
        await storing.value
        try await deleting.value

        #expect(try rows(in: dataModel).isEmpty)
        #expect(await secrets.identifiers.isEmpty)
        #expect(await jars(dataModel, secrets: secrets).jar(for: workspaceID).all.isEmpty)
    }

    @Test("Two settings of one cookie keep the later value in the Keychain as well as in memory")
    func laterValueWins() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = ControlledSecretStore()
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        await secrets.holdNextSave()

        let first = Task { await jar.receive([CookieFixtures.cookie("sid", "first")]) }
        await secrets.waitForHeldSave()
        let second = Task { await jar.receive([CookieFixtures.cookie("sid", "second")]) }
        while await jar.all.first?.value != "second" {
            await Task.yield()
        }
        await secrets.releaseSave()
        await first.value
        await second.value

        let relaunched = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        #expect(await relaunched.all.map(\.value) == ["second"])
        #expect(try rows(in: dataModel).count == 1)
    }

    @Test("A row whose value can't be read is kept, and setting that cookie again reuses it")
    func unreadableValueKeepsItsRow() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = ControlledSecretStore()
        await jars(dataModel, secrets: secrets).jar(for: workspaceID).receive([CookieFixtures.cookie("sid", "old")])
        await secrets.failReads(true)

        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        #expect(await jar.all.isEmpty)
        await jar.receive([CookieFixtures.cookie("sid", "new")])

        #expect(try rows(in: dataModel).count == 1)
        #expect(await secrets.identifiers.count == 1)
    }

    @Test("Two rows for one cookie load as one, and the other row and its value go")
    func duplicateRowsLoadAsOne() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = ControlledSecretStore()
        let records = [CookieRecord(cookie: CookieFixtures.cookie()), CookieRecord(cookie: CookieFixtures.cookie())]
        for record in records {
            await secrets.save(record.cookie.value, for: record.valueIdentifier)
        }
        try await dataModel.writer.saveCookies(records, in: workspaceID)

        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)

        #expect(try await jar.cookies(for: CookieFixtures.url).count == 1)
        #expect(try rows(in: dataModel).count == 1)
        #expect(await secrets.identifiers.count == 1)
    }

    @Test("A value that won't go keeps its row, the others go, and the jar shows what is still stored")
    func failedRemovalKeepsItsRow() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = ControlledSecretStore()
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        await jar.receive([CookieFixtures.cookie("a"), CookieFixtures.cookie("b"), CookieFixtures.cookie("c")])
        await secrets.failRemovals(1)

        await #expect(throws: ControlledSecretStore.Failure.self) {
            try await jar.deleteAll()
        }

        let remaining = try rows(in: dataModel)
        #expect(remaining.count == 1)
        #expect(await secrets.identifiers == Set(remaining.map(\.valueIdentifier)))
        #expect(await jar.all.map(\.name) == remaining.map(\.name))
    }

    @Test("A deleted workspace's values that won't go keep their rows, so the next launch tries again")
    func failedPurgeKeepsItsRows() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = ControlledSecretStore()
        let jars = jars(dataModel, secrets: secrets)
        await jars.jar(for: workspaceID).receive([CookieFixtures.cookie("a"), CookieFixtures.cookie("b")])
        await secrets.failRemovals(1)

        await #expect(throws: ControlledSecretStore.Failure.self) {
            try await jars.removeCookiesOfDeletedWorkspaces()
        }
        #expect(try rows(in: dataModel).count == 1)
        #expect(await secrets.identifiers.count == 1)

        try await jars.removeCookiesOfDeletedWorkspaces()
        #expect(try rows(in: dataModel).isEmpty)
        #expect(await secrets.identifiers.isEmpty)
    }

    @Test("A received cookie is dated by the jar's clock")
    func stampedByTheJarsClock() async {
        let dataModel = try? DataModel.inMemory()
        guard let dataModel else {
            Issue.record("No data model")
            return
        }
        let jar = jars(dataModel, secrets: InMemorySecretStore()).jar(for: workspaceID)
        var cookie = CookieFixtures.cookie()
        cookie.createdAt = .distantPast

        await jar.receive([cookie])

        #expect(await jar.all.map(\.createdAt) == [CookieFixtures.now])
    }

}
