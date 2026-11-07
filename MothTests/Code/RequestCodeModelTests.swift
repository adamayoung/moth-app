//  RequestCodeModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import AppKit
@testable import Moth
import MothCore
import MothImport
import SwiftData
import Testing

@MainActor
final class RequestCodeModelTests {

    private static let secret = "s3cret-value"

    private let reference = SecretReference()
    private let request: Request
    private let otherRequest = Request(name: "Other", urlTemplate: "https://example.com/other")
    private let dataModel: DataModel
    private let secretStore = InMemorySecretStore()
    private let drafts = RequestDrafts.preview
    private let clipboard = Clipboard(pasteboard: .withUniqueName())
    private let tabs: RequestTabsModel

    /// API, which holds a Bearer token, > (Users, Other). The active environment holds `host` and a secret.
    init() async throws {
        let request = Request(
            name: "Users",
            urlTemplate: "{{host}}/users",
            headers: [KeyValue(key: "X-Secret", value: "{{hidden}}")]
        )
        let environment = WorkspaceEnvironment(name: "Staging", variables: [
            Variable(name: "host", value: .plain(initial: "", current: "https://staging.test")),
            Variable(name: "hidden", value: .secret(reference))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            collections: [RequestCollection(
                name: "API",
                auth: .bearer(BearerAuth(token: reference)),
                children: [
                    CollectionItem(sortOrder: 0, node: .request(request)),
                    CollectionItem(sortOrder: 1, node: .request(otherRequest))
                ]
            )],
            environments: [environment]
        ))
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        self.request = request
        self.dataModel = dataModel
        self.tabs = RequestTabsModel(
            store: RequestTabStore(defaults: defaults, key: "Tabs"),
            drafts: drafts,
            responses: .preview,
            code: RequestCodeModel(
                dataModel: dataModel,
                activeEnvironment: ActiveEnvironment(inMemory: environment.id),
                clipboard: clipboard
            )
        )
        await secretStore.save(Self.secret, for: reference.identifier)
        try deliverCollection()
    }

    private func deliverCollection() throws {
        let context = dataModel.mainContext
        let requests: [RequestModel] = try context.fetch(.init())
        try tabs.collectionDidChange(CollectionSnapshot(
            tree: CollectionTree(
                collections: context.fetch(.init()),
                folders: context.fetch(.init()),
                requests: requests
            ),
            requestIDs: Set(requests.map(\.id))
        ))
    }

    private var copied: String? {
        clipboard.pasteboard.string(forType: .string)
    }

    private func editDraft() {
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.url = "https://edited.test/draft" }
    }

    @Test("Copy as cURL copies the saved request when no tab holds it")
    func copiesTheSavedRequest() async {
        await tabs.copyCURL(request.id)

        #expect(copied?.contains("'https://staging.test/users'") == true)
    }

    @Test("An open tab's unsaved edits are what gets copied")
    func usesAnOpenTabsDraft() async {
        tabs.open(request.id)
        editDraft()

        await tabs.copyCURL(request.id)

        #expect(copied?.contains("'https://edited.test/draft'") == true)
    }

    @Test("A draft that outlived its tab is not used")
    func ignoresADraftWithNoTab() async {
        editDraft()

        await tabs.copyCURL(request.id)

        #expect(copied?.contains("'https://staging.test/users'") == true)
    }

    @Test("A tab with no edits uses what is stored, because a tab that isn't selected misses deliveries")
    func cleanTabUsesTheStore() async {
        let staleSaved = Request(id: request.id, name: "Users", urlTemplate: "https://stale.test")
        drafts.savedRequestDidChange(staleSaved)
        tabs.open(request.id)

        await tabs.copyCURL(request.id)

        #expect(copied?.contains("'https://staging.test/users'") == true)
    }

    @Test("Inherited auth is followed")
    func followsInheritedAuth() async {
        await tabs.copyCURL(request.id)

        #expect(copied?.contains("--header 'Authorization: Bearer <token>'") == true)
    }

    @Test("A stored secret and a typed credential stay out of what is copied")
    func keepsSecretsOut() async {
        tabs.open(request.id)
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { draft in
            draft.auth.kind = .bearer
            draft.auth.setCredential("typed-token", for: draft.auth.tokenReference)
        }

        await tabs.copyCURL(request.id)

        let output = copied ?? ""
        #expect(output.contains("Bearer <token>"))
        #expect(output.contains("X-Secret: {{hidden}}"))
        #expect(!output.contains(Self.secret))
        #expect(!output.contains("typed-token"))
    }

    @Test("Generate Code presents both languages from the same source as Copy as cURL")
    func presentsBothLanguages() async throws {
        tabs.open(request.id)
        editDraft()

        await tabs.generateCode(request.id)

        let presented = try #require(tabs.code.presented)
        #expect(presented.id == request.id)
        #expect(presented.code.curl.contains("'https://edited.test/draft'"))
        #expect(presented.code.swift.contains(#"URL(string: "https://edited.test/draft")!"#))
        #expect(copied == nil)
    }

    @Test("Copying from the sheet copies the text it is given")
    func copiesFromTheSheet() {
        tabs.code.copy("the code")

        #expect(copied == "the code")
    }

    @Test("A request that can't be read reports a failure and copies nothing")
    func failureCopiesNothing() async {
        await tabs.copyCURL(UUID())

        #expect(tabs.code.hasFailed)
        #expect(copied == nil)
    }

    @Test("A request that can't be read presents nothing")
    func failurePresentsNothing() async {
        await tabs.generateCode(UUID())

        #expect(tabs.code.hasFailed)
        #expect(tabs.code.presented == nil)
    }

}
