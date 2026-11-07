//  CurlImportBodyTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CurlImportBodyTests {

    private static let formType = "application/x-www-form-urlencoded"

    @Test("A body takes the Content-Type header's type, whatever its case")
    func rawBodyTakesTheHeader() async throws {
        let request = try await CurlImportTesting.request(
            #"curl -H 'content-type: application/json' -d '{"a":1}' https://a.example"#
        )

        #expect(request.body == .raw(content: #"{"a":1}"#, contentType: "application/json"))
        #expect(request.headers.pairs == [Pair("content-type", "application/json")])
    }

    @Test("A body that isn't pairs takes the form type curl would send, and stays raw")
    func rawBodyWithoutAHeader() async throws {
        let request = try await CurlImportTesting.request(#"curl -d '{"a=b":1}' https://a.example"#)

        #expect(request.body == .raw(content: #"{"a=b":1}"#, contentType: Self.formType))
    }

    @Test("Form pairs become rows, joined across flags and decoded, because the builder encodes them")
    func formPairsBecomeRows() async throws {
        let request = try await CurlImportTesting.request(
            "curl -d a=1 --data 'b=c%20d+e' --data-ascii f=g --data-binary h=i --data-raw j=k https://a.example"
        )

        #expect(rows(of: request.body) == [
            Pair("a", "1"), Pair("b", "c d e"), Pair("f", "g"), Pair("h", "i"), Pair("j", "k")
        ])
    }

    @Test("A # in a form value is text, not a fragment")
    func formValueKeepsAHash() async throws {
        let request = try await CurlImportTesting.request("curl -d 'a=b#c' https://a.example")

        #expect(rows(of: request.body) == [Pair("a", "b#c")])
    }

    @Test("An explicit form type still makes rows, and a charset doesn't stop it")
    func explicitFormTypeMakesRows() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' -d a=1 https://a.example"
        )

        #expect(rows(of: request.body) == [Pair("a", "1")])
    }

    @Test(
        "Form text that rows can't send back unchanged stays raw",
        arguments: ["name=caf%E9", "a=1 ", "a=1\n"]
    )
    func unsendableFormTextStaysRaw(text: String) async throws {
        let request = try await CurlImportTesting.request("curl --data-raw '\(text)' https://a.example")

        #expect(request.body == .raw(content: text, contentType: Self.formType))
    }

    @Test("Pairs under another type stay raw")
    func otherTypeStaysRaw() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Content-Type: text/plain' -d a=1 https://a.example"
        )

        #expect(request.body == .raw(content: "a=1", contentType: "text/plain"))
    }

    @Test("--data-raw takes an @ literally")
    func dataRawKeepsAnAt() async throws {
        let result = try await CurlImportTesting.importing("curl --data-raw @handle https://a.example")

        #expect(result.request.body == .raw(content: "@handle", contentType: Self.formType))
        #expect(result.ignored.isEmpty)
    }

    @Test(
        "--data-urlencode takes each of curl's forms",
        arguments: [
            ("name=a b", [Pair("name", "a b")]),
            ("name=+1&2", [Pair("name", "+1&2")]),
            ("name=a@b.example", [Pair("name", "a@b.example")])
        ]
    )
    func dataURLEncodePairs(value: String, expected: [Pair]) async throws {
        let request = try await CurlImportTesting.request("curl --data-urlencode '\(value)' https://a.example")

        #expect(rows(of: request.body) == expected)
    }

    @Test("--data-urlencode with no name sends the content encoded", arguments: ["a b", "=a b"])
    func dataURLEncodeContent(value: String) async throws {
        let request = try await CurlImportTesting.request("curl --data-urlencode '\(value)' https://a.example")

        #expect(request.body == .raw(content: "a%20b", contentType: Self.formType))
    }

    @Test("An empty -d is a POST with no body")
    func emptyData() async throws {
        let request = try await CurlImportTesting.request("curl -d '' https://a.example")

        #expect(request.method == .post)
        #expect(request.body == .none)
    }

    @Test("-F makes form rows: text, a file by path, and a stated type")
    func form() async throws {
        let request = try await CurlImportTesting.request(#"""
        curl -F a=b --form 'c=@/tmp/d.png;type=image/png' -F 'e="f;g";type=text/plain' \
          -F 'h=@"i j.txt"' a.example
        """#)

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected form-data")
            return
        }
        #expect(fields.map(\.key) == ["a", "c", "e", "h"])
        #expect(fields.map(\.value) == [
            .text("b"), .file(paths: ["/tmp/d.png"]), .text("f;g"), .file(paths: ["i j.txt"])
        ])
        #expect(fields.map(\.contentType) == [nil, "image/png", "text/plain", nil])
    }

    @Test("A multipart Content-Type leaves the rows, because only the builder knows the boundary it will use")
    func formDropsItsContentTypeHeader() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Accept: a' -H 'Content-Type: multipart/form-data' -F a=b https://a.example"
        )

        #expect(request.headers.pairs == [Pair("Accept", "a")])
    }

    @Test("--data-urlencode looks for = before @, as curl does")
    func dataURLEncodePrefersTheEquals() async throws {
        let result = try await CurlImportTesting.importing("curl --data-urlencode 'user@host=a' https://a.example")

        #expect(result.ignored.isEmpty)
        #expect(result.request.body == .raw(content: "user@host=a", contentType: Self.formType))
    }

    @Test(
        "A form part's type survives a blank before it and a parameter after it",
        arguments: [
            ("a=@b.json; type=application/json", "application/json"),
            ("a=b;type=text/plain;charset=utf-8", "text/plain;charset=utf-8"),
            ("a=@b;type=text/plain;filename=c.txt", "text/plain"),
            ("a=@b;filename=c.txt;type=text/plain", "text/plain")
        ]
    )
    func formPartType(argument: String, contentType: String) async throws {
        let request = try await CurlImportTesting.request("curl -F '\(argument)' https://a.example")

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected form-data")
            return
        }
        #expect(fields.map(\.contentType) == [contentType])
    }

    @Test(
        "A quoted form value unescapes only a backslash and a quote, as curl does",
        arguments: [
            (#"a="b\nc""#, #"b\nc"#),
            (#"a="b\"c""#, #"b"c"#),
            (#"a="b\\c""#, #"b\c"#)
        ]
    )
    func quotedFormValue(argument: String, value: String) async throws {
        let request = try await CurlImportTesting.request("curl -F '\(argument)' https://a.example")

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected form-data")
            return
        }
        #expect(fields.map(\.value) == [.text(value)])
    }

    private func rows(of body: RequestBody) -> [Pair] {
        guard case .urlEncoded(let rows) = body else {
            return []
        }
        return rows.pairs
    }

}
