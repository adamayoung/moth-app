//  OutgoingRequestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct OutgoingRequestTests {

    private let settings = RequestSettings(timeout: .seconds(5))
    private let variable = Variable.plain("id", "42")

    private let stored: Request

    init() {
        self.stored = Request(
            name: "List",
            urlTemplate: "https://example.com/saved",
            auth: .none,
            settings: settings,
            variables: [variable]
        )
    }

    @Test("The draft's edits go out over what is stored")
    func draftWins() throws {
        var draft = RequestDraft(stored)
        draft.method = .post
        draft.url = "https://example.com/edited?a=1"
        draft.headers = [KeyValue(key: "X-Edit", value: "1")]

        let request = try draft.outgoing(from: stored, in: .empty).request

        #expect(request.method == .post)
        #expect(request.urlTemplate == "https://example.com/edited")
        #expect(request.queryParameters.map(\.key) == ["a"])
        #expect(request.headers.map(\.key) == ["X-Edit"])
    }

    @Test("What the editor doesn't hold comes from what is stored")
    func keepsStoredFields() throws {
        let request = try RequestDraft(stored).outgoing(from: stored, in: .empty).request

        #expect(request.id == stored.id)
        #expect(request.name == "List")
        #expect(request.settings == settings)
        #expect(request.variables == [variable])
    }

    @Test("A typed credential goes with the request, under the reference the auth names")
    func typedCredential() throws {
        var draft = RequestDraft(stored)
        draft.auth.kind = .bearer
        draft.auth.setCredential("typed", for: draft.auth.tokenReference)

        let outgoing = try draft.outgoing(from: stored, in: .empty)

        guard case .bearer(let bearer) = outgoing.request.auth else {
            Issue.record("Expected Bearer, got \(outgoing.request.auth)")
            return
        }
        #expect(outgoing.typedCredentials == [CredentialWrite(reference: bearer.token, value: "typed")])
    }

    @Test("A draft with no typed credential has none")
    func noTypedCredential() throws {
        #expect(try RequestDraft(stored).outgoing(from: stored, in: .empty).typedCredentials.isEmpty)
    }

    @Test("Inherit is replaced by what the tree says, and a request outside the tree inherits nothing")
    func outsideTheTree() throws {
        var draft = RequestDraft(stored)
        draft.auth.kind = .inherit

        #expect(try draft.outgoing(from: stored, in: .empty).request.auth == Auth.none)
    }

}
