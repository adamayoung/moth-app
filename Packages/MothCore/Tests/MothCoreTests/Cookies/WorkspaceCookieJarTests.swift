//  WorkspaceCookieJarTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Security
import SwiftData
import Testing

@MainActor
struct WorkspaceCookieJarTests {

    private let workspaceID = UUID()

    private func jars(_ dataModel: DataModel, secrets: any SecretStore) -> CookieJars {
        CookieJars(writer: dataModel.writer, secretStore: secrets, now: { CookieFixtures.now })
    }

    private func rows(in dataModel: DataModel) throws -> [CookieModel] {
        try dataModel.mainContext.fetch(FetchDescriptor<CookieModel>())
    }

    @Test("With an in-memory secret store, as in an ad hoc build, the jar keeps and sends cookies")
    func inMemorySecretStore() async throws {
        let dataModel = try DataModel.inMemory()
        let jar = jars(dataModel, secrets: InMemorySecretStore()).jar(for: workspaceID)

        await jar.receive([CookieFixtures.cookie()])

        #expect(try await jar.cookies(for: CookieFixtures.url) == [CookieFixtures.cookie()])
    }

    @Test("Cookies survive a fresh data model and a fresh secret store over the same Keychain")
    func survivesARelaunch() async throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let keychain = InMemoryKeychainItems()
        let cookie = CookieFixtures.cookie(expiresAt: CookieFixtures.now.addingTimeInterval(3600))
        do {
            let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
            let secrets = KeychainSecretStore(
                service: "cookies",
                mode: .deviceOnly(accessGroup: "g"),
                keychain: keychain
            )
            await jars(dataModel, secrets: secrets).jar(for: workspaceID).receive([cookie])
        }

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)

        #expect(try await jar.cookies(for: CookieFixtures.url) == [cookie])
    }

    @Test("A value is a device-only Keychain item, and its row holds only a reference to it")
    func valuesAreDeviceOnly() async throws {
        let dataModel = try DataModel.inMemory()
        let keychain = InMemoryKeychainItems()
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)

        await jars(dataModel, secrets: secrets).jar(for: workspaceID).receive([CookieFixtures.cookie("sid", "s3cret")])

        let row = try #require(rows(in: dataModel).first)
        let item = try #require(keychain.attributes(of: row.valueIdentifier))
        #expect(item[kSecValueData] as? Data == Data("s3cret".utf8))
        #expect(item[kSecAttrSynchronizable] as? Bool == false)
        #expect(item[kSecAttrAccessible] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(row.name == "sid")
        #expect(!row.valueIdentifier.contains("s3cret"))
    }

    @Test("Each workspace has its own jar, and a new workspace's jar is empty")
    func workspacesAreSeparate() async throws {
        let dataModel = try DataModel.inMemory()
        let jars = jars(dataModel, secrets: InMemorySecretStore())

        await jars.jar(for: workspaceID).receive([CookieFixtures.cookie()])

        #expect(try await jars.jar(for: UUID()).cookies(for: CookieFixtures.url).isEmpty)
        #expect(try await jars.jar(for: workspaceID).cookies(for: CookieFixtures.url) == [CookieFixtures.cookie()])
    }

    @Test("Jars that persist through the same store stay separate after a relaunch")
    func workspacesStaySeparateInTheStore() async throws {
        let dataModel = try DataModel.inMemory()
        let secrets = InMemorySecretStore()
        let other = UUID()
        await jars(dataModel, secrets: secrets).jar(for: workspaceID).receive([CookieFixtures.cookie("a")])
        await jars(dataModel, secrets: secrets).jar(for: other).receive([CookieFixtures.cookie("b")])

        let relaunched = jars(dataModel, secrets: secrets)

        #expect(try await relaunched.jar(for: workspaceID).cookies(for: CookieFixtures.url).map(\.name) == ["a"])
        #expect(try await relaunched.jar(for: other).cookies(for: CookieFixtures.url).map(\.name) == ["b"])
    }

    @Test("Deleting a workspace removes its cookies and their Keychain items, and leaves the others")
    func deletingAWorkspaceRemovesItsCookies() async throws {
        let dataModel = try DataModel.inMemory()
        let keychain = InMemoryKeychainItems()
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)
        let (survivor, merged) = try Self.insertTwoWorkspaces(into: dataModel)
        let jars = jars(dataModel, secrets: secrets)
        await jars.jar(for: survivor).receive([CookieFixtures.cookie("kept")])
        await jars.jar(for: merged).receive([CookieFixtures.cookie("gone")])

        try await dataModel.writer.reconcileWorkspaces()
        try await jars.removeCookiesOfDeletedWorkspaces()

        let remaining = try rows(in: dataModel)
        #expect(remaining.map(\.name) == ["kept"])
        #expect(keychain.accounts == Set(remaining.map(\.valueIdentifier)))
        #expect(try await jars.jar(for: survivor).cookies(for: CookieFixtures.url).map(\.name) == ["kept"])
    }

    @Test("A row whose value is missing, as after an ad hoc build quits, is dropped")
    func missingValueIsDropped() async throws {
        let dataModel = try DataModel.inMemory()
        await jars(dataModel, secrets: InMemorySecretStore()).jar(for: workspaceID).receive([CookieFixtures.cookie()])

        let relaunched = jars(dataModel, secrets: InMemorySecretStore()).jar(for: workspaceID)

        #expect(try await relaunched.cookies(for: CookieFixtures.url).isEmpty)
        #expect(try rows(in: dataModel).isEmpty)
    }

    @Test("A cookie set again keeps one row and one Keychain item, with the new value")
    func replacingKeepsOneRow() async throws {
        let dataModel = try DataModel.inMemory()
        let keychain = InMemoryKeychainItems()
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)

        await jar.receive([CookieFixtures.cookie("sid", "old")])
        await jar.receive([CookieFixtures.cookie("sid", "new")])

        #expect(try rows(in: dataModel).count == 1)
        #expect(keychain.accounts.count == 1)
        #expect(try await jar.cookies(for: CookieFixtures.url).map(\.value) == ["new"])
    }

    @Test("An expired cookie removes the stored one, with its row and Keychain item")
    func expiredRemoves() async throws {
        let dataModel = try DataModel.inMemory()
        let keychain = InMemoryKeychainItems()
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        await jar.receive([CookieFixtures.cookie()])

        await jar.receive([CookieFixtures.cookie(expiresAt: CookieFixtures.now)])

        #expect(try rows(in: dataModel).isEmpty)
        #expect(keychain.accounts.isEmpty)
        #expect(await jar.all.isEmpty)
    }

    @Test("Deleting a cookie, or several, removes their rows and Keychain items and keeps the rest")
    func deletesCookies() async throws {
        let dataModel = try DataModel.inMemory()
        let keychain = InMemoryKeychainItems()
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        let kept = CookieFixtures.cookie("kept", domain: "example.org")
        await jar.receive([CookieFixtures.cookie("a"), CookieFixtures.cookie("b"), kept])

        try await jar.delete([CookieFixtures.cookie("a").identity, CookieFixtures.cookie("b").identity])

        #expect(await jar.all == [kept])
        #expect(try rows(in: dataModel).map(\.name) == ["kept"])
        #expect(keychain.accounts.count == 1)
    }

    @Test("Deleting all removes every row and Keychain item")
    func deletesAll() async throws {
        let dataModel = try DataModel.inMemory()
        let keychain = InMemoryKeychainItems()
        let secrets = KeychainSecretStore(service: "cookies", mode: .deviceOnly(accessGroup: "g"), keychain: keychain)
        let jar = jars(dataModel, secrets: secrets).jar(for: workspaceID)
        await jar.receive([CookieFixtures.cookie("a"), CookieFixtures.cookie("b", domain: "example.org")])

        try await jar.deleteAll()

        #expect(await jar.all.isEmpty)
        #expect(try rows(in: dataModel).isEmpty)
        #expect(keychain.accounts.isEmpty)
    }

    @Test("A seeded jar answers with its seed")
    func seededJar() async throws {
        let dataModel = try DataModel.inMemory()
        let jars = CookieJars(
            writer: dataModel.writer,
            secretStore: InMemorySecretStore(),
            seed: [workspaceID: [CookieFixtures.cookie()]],
            now: { CookieFixtures.now }
        )

        #expect(await jars.jar(for: workspaceID).all == [CookieFixtures.cookie()])
    }

    private static func insertTwoWorkspaces(into dataModel: DataModel) throws -> (survivor: UUID, merged: UUID) {
        let context = ModelContext(dataModel.container)
        let first = WorkspaceModel()
        let second = WorkspaceModel()
        context.insert(first)
        context.insert(second)
        try context.save()
        return first.id < second.id ? (first.id, second.id) : (second.id, first.id)
    }

}
