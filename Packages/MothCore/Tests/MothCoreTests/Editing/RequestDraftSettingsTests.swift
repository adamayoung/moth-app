//  RequestDraftSettingsTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct RequestDraftSettingsTests {

    private let stored = Request(
        name: "List",
        urlTemplate: "https://example.com/users",
        settings: RequestSettings(timeout: .seconds(5), followsRedirects: false, verifiesTLS: false)
    )

    @Test("A draft starts with the request's settings, and its edit carries them")
    func startsWithStoredSettings() {
        let draft = RequestDraft(stored)

        #expect(draft.settings == stored.settings)
        #expect(draft.edit.settings == stored.settings)
        #expect(RequestEdit(stored).settings == stored.settings)
    }

    @Test("Changing a setting makes the draft differ from what it started as")
    func changeIsAnEdit() {
        let saved = RequestDraft(stored)
        var draft = saved

        draft.settings.verifiesTLS = true

        #expect(!draft.hasSameContent(as: saved))
        #expect(draft.edit.settings.verifiesTLS)
    }

    @Test("An unsaved change to the settings goes out with the send")
    func unsavedSettingsGoOut() throws {
        var draft = RequestDraft(stored)
        draft.settings.timeout = .seconds(9)
        draft.settings.followsRedirects = true

        let request = try draft.outgoing(from: stored, in: .empty).request

        #expect(request.settings == RequestSettings(timeout: .seconds(9), followsRedirects: true, verifiesTLS: false))
    }

}
