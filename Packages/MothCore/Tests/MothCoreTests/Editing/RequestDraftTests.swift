//  RequestDraftTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestDraftTests {

    @Test("A saved request's URL shows its enabled rows and not its disabled ones")
    func urlShowsEnabledRows() {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com/users",
            queryParameters: [
                KeyValue(key: "limit", value: "10"),
                KeyValue(key: "offset", value: "0", isEnabled: false),
                KeyValue(key: "sort", value: "name")
            ]
        )

        let draft = RequestDraft(request)

        #expect(draft.url == "https://example.com/users?limit=10&sort=name")
    }

    @Test("The URL percent-encodes what a row holds decoded")
    func urlEncodesRows() {
        let draft = draft(queryParameters: [KeyValue(key: "a&b", value: "c=d e")])

        #expect(draft.url == "https://example.com?a%26b=c%3Dd%20e")
    }

    @Test(
        "A key and value round-trip through the URL",
        arguments: ["a&b", "a=b", "a#b", "100%", "a b", "café", "a+b", "a/b?c", "%20"]
    )
    func textRoundTrips(text: String) {
        var draft = draft(queryParameters: [KeyValue(key: text, value: text)])
        let encoded = draft.url

        draft.url = "https://example.com"
        draft.url = encoded

        #expect(draft.queryParameters.map(\.key) == [text])
        #expect(draft.queryParameters.map(\.value) == [text])
    }

    @Test("A variable stays literal in the URL, between encoded text")
    func variableStaysLiteral() {
        let draft = draft(queryParameters: [KeyValue(key: "token", value: "a b{{token}}c d")])

        #expect(draft.url == "https://example.com?token=a%20b{{token}}c%20d")
    }

    @Test("A separator inside a variable does not split the URL")
    func separatorInsideVariable() {
        var draft = draft()

        draft.url = "{{a?b}}/users?q={{c&d=e#f}}&page=1#top"

        #expect(draft.queryParameters.map(\.key) == ["q", "page"])
        #expect(draft.queryParameters.map(\.value) == ["{{c&d=e#f}}", "1"])
    }

    @Test("Editing the URL keeps the text as typed")
    func urlKeepsTypedText() {
        var draft = draft()

        draft.url = "https://example.com?a=b+c&"

        #expect(draft.url == "https://example.com?a=b+c&")
    }

    @Test("A plus in the URL's query is the space a server reads, so a Save sends the same value")
    func plusReadsAsSpace() {
        var draft = draft()

        draft.url = "https://example.com?q=hello+world%2Bmore"

        #expect(draft.queryParameters.map(\.value) == ["hello world+more"])
    }

    @Test("Whitespace around the URL stays out of rows and the template, as sending trims it")
    func whitespaceAroundTheURL() {
        var draft = draft()

        draft.url = "  https://example.com/users/:id?k=v \n"

        #expect(draft.queryParameters.map(\.value) == ["v"])
        #expect(draft.edit.urlTemplate == "https://example.com/users/:id")

        draft.url = "https://example.com/users/:id "

        #expect(draft.pathParameters.map(\.key) == ["id"])
    }

    @Test("A query key with no value gives an empty value, and a pair with no key gives no row")
    func partialPairs() {
        var draft = draft()

        draft.url = "https://example.com?flag&=1&"

        #expect(draft.queryParameters.map(\.key) == ["flag"])
        #expect(draft.queryParameters.map(\.value) == [""])
    }

    @Test("A malformed percent sequence stays literal")
    func malformedPercentStaysLiteral() {
        var draft = draft()

        draft.url = "https://example.com?a=100%"

        #expect(draft.queryParameters.map(\.value) == ["100%"])
    }

    @Test("Editing the URL fills enabled rows in place and keeps their identifiers")
    func urlKeepsRowIdentity() {
        let first = KeyValue(key: "a", value: "1")
        let disabled = KeyValue(key: "b", value: "2", isEnabled: false)
        let last = KeyValue(key: "c", value: "3")
        var draft = draft(queryParameters: [first, disabled, last])

        draft.url = "https://example.com?a=9&z=8&new=7"

        #expect(draft.queryParameters.map(\.key) == ["a", "b", "z", "new"])
        #expect(draft.queryParameters.map(\.value) == ["9", "2", "8", "7"])
        #expect(Array(draft.queryParameters.map(\.id).prefix(3)) == [first.id, disabled.id, last.id])
        #expect(draft.queryParameters.map(\.isEnabled) == [true, false, true, true])
    }

    @Test("Removing a pair from the URL removes its row and leaves disabled and empty rows")
    func urlRemovesRows() {
        let disabled = KeyValue(key: "b", value: "2", isEnabled: false)
        let empty = KeyValue(key: "", value: "")
        var draft = draft(queryParameters: [KeyValue(key: "a", value: "1"), disabled, empty])

        draft.url = "https://example.com"

        #expect(draft.queryParameters == [disabled, empty])
    }

    @Test("Adding a row updates the URL, and an empty one is left out of it")
    func addingRow() throws {
        var draft = draft(queryParameters: [KeyValue(key: "a", value: "1")])

        draft.queryParameters.append(KeyValue(key: "", value: ""))
        #expect(draft.url == "https://example.com?a=1")
        try #require(draft.queryParameters.count == 2)

        draft.queryParameters[1].key = "b"
        #expect(draft.url == "https://example.com?a=1&b=")
    }

    @Test("Disabling and removing rows updates the URL, down to no query at all")
    func disablingAndRemovingRows() {
        var draft = draft(queryParameters: [KeyValue(key: "a", value: "1"), KeyValue(key: "b", value: "2")])

        draft.queryParameters[0].isEnabled = false
        #expect(draft.url == "https://example.com?b=2")

        draft.queryParameters.remove(at: 1)
        #expect(draft.url == "https://example.com")
    }

    @Test("Editing a row keeps the URL's fragment")
    func rowEditKeepsFragment() {
        var draft = draft()
        draft.url = "https://example.com/users#top"

        draft.queryParameters.append(KeyValue(key: "a", value: "1"))

        #expect(draft.url == "https://example.com/users?a=1#top")
    }

    @Test("An edit takes the query out of the template, keeps the fragment and holds rows decoded")
    func editHoldsStoredForm() {
        var draft = draft()

        draft.url = "https://example.com/users?a=1%202#top"

        #expect(draft.edit.urlTemplate == "https://example.com/users#top")
        #expect(draft.edit.queryParameters.map(\.value) == ["1 2"])
    }

    @Test("An edit carries the method, headers and disabled rows")
    func editCarriesFields() {
        let disabled = KeyValue(key: "b", value: "2", isEnabled: false)
        let header = KeyValue(key: "Accept", value: "text/plain", isEnabled: false)
        var draft = draft(queryParameters: [disabled])

        draft.method = .post
        draft.headers = [header]

        #expect(draft.edit.method == .post)
        #expect(draft.edit.headers == [header])
        #expect(draft.edit.queryParameters == [disabled])
    }

    @Test("A template's own query loads into rows ahead of the stored ones, and leaves the template")
    func templateQueryLoadsIntoRows() {
        let request = Request(
            name: "Own Query",
            urlTemplate: "https://example.com?own=1",
            queryParameters: [KeyValue(key: "a", value: "2"), KeyValue(key: "b", value: "3", isEnabled: false)]
        )

        let draft = RequestDraft(request)

        #expect(draft.url == "https://example.com?own=1&a=2")
        #expect(draft.queryParameters.map(\.key) == ["own", "a", "b"])
        #expect(draft.edit.urlTemplate == "https://example.com")
    }

    @Test("A saved edit reloads with the same content")
    func editReloads() throws {
        var draft = draft(queryParameters: [KeyValue(key: "b", value: "2", isEnabled: false)])
        draft.url = "https://example.com/users/:id?a=1%202#top"
        try draft.setPathValue("42", for: #require(draft.pathParameters.first).id)
        draft.headers = [KeyValue(key: "Accept", value: "text/plain")]

        #expect(RequestDraft(draft.edit).hasSameContent(as: draft))
    }

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

    @Test("Comparing content ignores row identifiers")
    func comparisonIgnoresIdentifiers() {
        let rows = { [KeyValue(key: "a", value: "1")] }
        let first = RequestDraft(Request(name: "A", queryParameters: rows(), pathParameters: rows(), headers: rows()))
        let second = RequestDraft(Request(name: "B", queryParameters: rows(), pathParameters: rows(), headers: rows()))

        #expect(first.hasSameContent(as: second))
    }

    @Test("Comparing content sees every field", arguments: 0 ..< 6)
    func comparisonSeesEveryField(change: Int) throws {
        let original = comparisonDraft()
        try #require(original.queryParameters.count == 1)
        try #require(original.headers.count == 1)
        var changed = original

        switch change {
        case 0: changed.method = .post
        case 1: changed.url += "/more"
        case 2: changed.queryParameters[0].isEnabled = false
        case 3: changed.headers[0].value = "other"
        case 4: changed.headers[0].isEnabled = false
        default: try changed.setPathValue("other", for: #require(changed.pathParameters.first).id)
        }

        #expect(!changed.hasSameContent(as: original))
    }

    private func comparisonDraft() -> RequestDraft {
        var draft = draft(queryParameters: [KeyValue(key: "a", value: "1")])
        draft.url = "https://example.com/:id?a=1"
        draft.headers = [KeyValue(key: "Accept", value: "text/plain")]
        return draft
    }

    private func draft(queryParameters: [KeyValue] = []) -> RequestDraft {
        RequestDraft(Request(name: "Draft", urlTemplate: "https://example.com", queryParameters: queryParameters))
    }

}
