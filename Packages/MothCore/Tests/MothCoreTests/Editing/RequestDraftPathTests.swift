//  RequestDraftPathTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestDraftPathTests {

    @Test("A path segment that starts with a colon adds a row, in URL order, once for each name")
    func pathVariablesFollowTheURL() {
        var draft = draft()

        draft.url = "https://example.com/users/:id/posts/:post/:id?x=:query#:fragment"

        #expect(draft.pathParameters.map(\.key) == ["id", "post"])
        #expect(draft.pathParameters.map(\.value) == ["", ""])
    }

    @Test("A percent-encoded path variable's name is decoded, as sending decodes it")
    func pathVariableNameIsDecoded() {
        var draft = draft()

        draft.url = "{{host}}/:user%20id"

        #expect(draft.pathParameters.map(\.key) == ["user id"])
    }

    @Test(
        "An address or a colon inside a segment is not a path variable",
        arguments: [
            "localhost:8080/users",
            "{{host}}/users",
            "https://example.com:8080",
            "https://:id",
            ":id",
            "https://example.com/a:b",
            "https://example.com/:"
        ]
    )
    func notAPathVariable(url: String) {
        var draft = draft()

        draft.url = url

        #expect(draft.pathParameters.isEmpty)
    }

    @Test("A path row keeps its value and identity as the URL changes, and goes with its segment")
    func pathRowFollowsItsSegment() {
        let row = KeyValue(key: "id", value: "42")
        var draft = RequestDraft(Request(
            name: "Path",
            urlTemplate: "https://example.com/users/:id",
            pathParameters: [row]
        ))
        #expect(draft.pathParameters == [row])

        draft.url = "https://example.com/users/:id/posts"
        #expect(draft.pathParameters == [row])

        draft.url = "https://example.com/users"
        #expect(draft.pathParameters.isEmpty)
    }

    @Test("Renaming a path segment in place keeps its row and value")
    func renamingPathSegment() {
        let row = KeyValue(key: "id", value: "42")
        var draft = RequestDraft(Request(
            name: "Path",
            urlTemplate: "https://example.com/users/:id",
            pathParameters: [row]
        ))

        draft.url = "https://example.com/users/:i"
        draft.url = "https://example.com/users/:userId"

        #expect(draft.pathParameters.map(\.key) == ["userId"])
        #expect(draft.pathParameters.map(\.value) == ["42"])
        #expect(draft.pathParameters.map(\.id) == [row.id])
    }

    @Test("Swapping two path segments keeps each value with its name")
    func swappingPathSegments() {
        var draft = RequestDraft(Request(
            name: "Path",
            urlTemplate: "https://example.com/:a/:b",
            pathParameters: [KeyValue(key: "a", value: "1"), KeyValue(key: "b", value: "2")]
        ))

        draft.url = "https://example.com/:b/:a"

        #expect(draft.pathParameters.map(\.key) == ["b", "a"])
        #expect(draft.pathParameters.map(\.value) == ["2", "1"])
    }

    @Test("A stored path row whose segment has gone gives its value to no other segment")
    func strayPathRowIsNotAdopted() {
        let request = Request(
            name: "Path",
            urlTemplate: "https://example.com/:new",
            pathParameters: [KeyValue(key: "old", value: "42")]
        )

        #expect(RequestDraft(request).pathParameters.map(\.value) == [""])
    }

    @Test("Setting a value enables a path row, because the editor has no control that could")
    func settingPathValueEnablesTheRow() {
        let row = KeyValue(key: "id", value: "", isEnabled: false)
        var draft = RequestDraft(Request(
            name: "Path",
            urlTemplate: "https://example.com/:id",
            pathParameters: [row]
        ))

        draft.setPathValue("42", for: row.id)

        #expect(draft.pathParameters.map(\.isEnabled) == [true])
    }

    @Test("A stored path row whose segment has gone does not load")
    func strayPathRowDoesNotLoad() {
        let request = Request(
            name: "Path",
            urlTemplate: "https://example.com/users",
            pathParameters: [KeyValue(key: "id", value: "42")]
        )

        #expect(RequestDraft(request).pathParameters.isEmpty)
    }

    @Test("Setting a path value changes that row")
    func settingPathValue() throws {
        var draft = draft()
        draft.url = "https://example.com/:a/:b"

        try draft.setPathValue("1", for: #require(draft.pathParameters.last).id)

        #expect(draft.pathParameters.map(\.value) == ["", "1"])
        #expect(draft.edit.pathParameters.map(\.value) == ["", "1"])
    }

    @Test("A stored path row with no segment in the template survives a Save, because a variable can hold the segment")
    func unseenPathRowSurvivesASave() {
        let row = KeyValue(key: "id", value: "42")
        var draft = RequestDraft(Request(name: "Path", urlTemplate: "{{userUrl}}", pathParameters: [row]))

        draft.headers = [KeyValue(key: "Accept", value: "text/plain")]

        #expect(draft.pathParameters.isEmpty)
        #expect(draft.edit.pathParameters == [row])
        #expect(RequestDraft(draft.edit).edit.pathParameters == [row])
    }

    @Test("Typing the segment of a row that was not shown brings that row back")
    func typingAnUnseenSegmentShowsItsRow() {
        let row = KeyValue(key: "id", value: "42")
        var draft = RequestDraft(Request(name: "Path", urlTemplate: "{{userUrl}}", pathParameters: [row]))

        draft.url = "{{userUrl}}/:id"

        #expect(draft.pathParameters == [row])
        #expect(draft.edit.pathParameters == [row])
    }

    @Test("Pasting several new segments over one gives none of them its value")
    func pastingSeveralSegments() {
        var draft = RequestDraft(Request(
            name: "Path",
            urlTemplate: "https://example.com/users/:id",
            pathParameters: [KeyValue(key: "id", value: "42")]
        ))

        draft.url = "https://example.com/orgs/:org/users/:user"

        #expect(draft.pathParameters.map(\.key) == ["org", "user"])
        #expect(draft.pathParameters.map(\.value) == ["", ""])
    }

    private func draft() -> RequestDraft {
        RequestDraft(Request(name: "Draft", urlTemplate: "https://example.com"))
    }

}
