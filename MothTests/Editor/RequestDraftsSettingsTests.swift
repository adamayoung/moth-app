//  RequestDraftsSettingsTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct RequestDraftsSettingsTests: RequestDraftsTesting {

    private let request = Request(name: "Request", urlTemplate: "https://example.com")
    private let unverified = RequestSettings(timeout: .seconds(9), followsRedirects: false, verifiesTLS: false)

    @Test("A settings change marks the request edited, and Save writes it")
    func saveWritesSettings() async throws {
        let (dataModel, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.settings = unverified }
        #expect(drafts.isEdited(request.id))

        #expect(await drafts.save(request.id))

        #expect(try savedRequest(request.id, in: dataModel).asDomain().settings == unverified)
        #expect(!drafts.isEdited(request.id))
    }

    @Test("Revert to Saved puts the stored settings back")
    func revertRestoresSettings() throws {
        let (_, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.settings = unverified }

        drafts.revert(request.id)

        #expect(drafts.draft(for: request.id)?.settings == RequestSettings())
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A sync change to the settings follows a draft that didn't touch them, and an edited URL stays")
    func syncedSettingsFollow() throws {
        let (_, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.url = "https://example.com/edited" }
        var synced = request
        synced.settings = unverified

        drafts.savedRequestDidChange(synced)

        #expect(drafts.draft(for: request.id)?.settings == unverified)
        #expect(drafts.draft(for: request.id)?.url == "https://example.com/edited")
    }

    @Test("A sync change to one setting follows, and a setting the draft changed stays")
    func editedSettingsStay() throws {
        let (_, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.settings.followsRedirects = false }
        var synced = request
        synced.settings.timeout = .seconds(5)

        drafts.savedRequestDidChange(synced)

        #expect(drafts.draft(for: request.id)?.settings == RequestSettings(
            timeout: .seconds(5),
            followsRedirects: false
        ))
    }

}
