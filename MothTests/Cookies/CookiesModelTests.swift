//  CookiesModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import Moth
import MothCore
import Testing

@MainActor
struct CookiesModelTests {

    private static func cookie(_ name: String, domain: String, path: String = "/") -> Cookie {
        Cookie(
            name: name,
            value: "\(name)-value",
            domain: domain,
            isHostOnly: true,
            path: path,
            expiresAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private let cookies = [
        cookie("theme", domain: "example.org"),
        cookie("sid", domain: "api.example.com", path: "/v1"),
        cookie("csrf", domain: "api.example.com")
    ]

    private func model(seeding cookies: [Cookie]? = nil) throws -> CookiesModel {
        let dataModel = try DataModel.inMemory(seed: Workspace())
        let workspaceID = try #require(dataModel.workspaceID)
        let jars = CookieJars(
            writer: dataModel.writer,
            secretStore: InMemorySecretStore(),
            seed: [workspaceID: cookies ?? self.cookies],
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
        return CookiesModel(dataModel: dataModel, cookieJars: jars)
    }

    @Test("Opening shows the sheet, with a group for each domain in order and its cookies by name")
    func groupsByDomain() async throws {
        let model = try model()

        await model.open()

        #expect(model.isPresented)
        #expect(model.domains.map(\.name) == ["api.example.com", "example.org"])
        #expect(model.domains.first?.cookies.map(\.name) == ["csrf", "sid"])
    }

    @Test("Nothing is selected at first, and a selection names its cookie and value")
    func selection() async throws {
        let model = try model()
        await model.open()

        #expect(model.selectedCookie == nil)

        model.selection = Self.cookie("sid", domain: "api.example.com", path: "/v1").identity

        #expect(model.selectedCookie?.value == "sid-value")
    }

    @Test("Deleting the selected cookie removes it alone and clears the selection")
    func deletesTheSelection() async throws {
        let model = try model()
        await model.open()
        model.selection = Self.cookie("csrf", domain: "api.example.com").identity

        await model.deleteSelected()

        #expect(model.selection == nil)
        #expect(model.domains.flatMap(\.cookies).map(\.name) == ["sid", "theme"])
    }

    @Test("A cookie selected while a delete runs stays selected")
    func selectionDuringADeleteStays() async throws {
        let model = try model()
        await model.open()
        let other = Self.cookie("theme", domain: "example.org").identity
        model.selection = Self.cookie("csrf", domain: "api.example.com").identity

        let deleting = Task { await model.deleteSelected() }
        await Task.yield()
        #expect(model.selection == nil)
        model.selection = other
        await deleting.value

        #expect(model.selection == other)
    }

    @Test("Deleting a domain removes its cookies and keeps the others")
    func deletesADomain() async throws {
        let model = try model()
        await model.open()

        await model.deleteCookies(in: "api.example.com")

        #expect(model.domains.map(\.name) == ["example.org"])
    }

    @Test("Delete All asks first, and confirming removes every cookie")
    func deletesAll() async throws {
        let model = try model()
        await model.open()

        model.confirmDeleteAll()
        #expect(model.isConfirmingDeleteAll)
        #expect(model.domains.count == 2)

        await model.deleteAll()

        #expect(model.domains.isEmpty)
    }

    @Test("With no workspace there are no cookies")
    func noWorkspace() async throws {
        let dataModel = try DataModel.inMemory()
        let model = CookiesModel(
            dataModel: dataModel,
            cookieJars: CookieJars(writer: dataModel.writer, secretStore: InMemorySecretStore())
        )

        await model.open()

        #expect(model.isPresented)
        #expect(model.domains.isEmpty)
    }

}
