//  CodeGeneratorRequestTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CodeGeneratorRequestTests {

    private func code(for request: Request) async throws -> GeneratedCode {
        try await CodeGenerator().code(for: request, scopes: VariableScopes())
    }

    @Test("A GET with nothing else is one cURL line")
    func plainGETInCURL() async throws {
        let code = try await code(for: Request(name: "Users", urlTemplate: "https://example.com/users"))

        #expect(code.curl == "curl --url 'https://example.com/users'")
    }

    @Test("A GET in Swift builds a request and sends it")
    func plainGETInSwift() async throws {
        let code = try await code(for: Request(name: "Users", urlTemplate: "https://example.com/users"))

        #expect(code.swift == """
        import Foundation

        var request = URLRequest(url: URL(string: "https://example.com/users")!)

        let (data, response) = try await URLSession.shared.data(for: request)
        print(response)
        print(String(decoding: data, as: UTF8.self))
        """)
    }

    @Test("Each language reads back through the language it was asked for")
    func textInLanguage() async throws {
        let code = try await code(for: Request(name: "Users", urlTemplate: "https://example.com"))

        #expect(code.text(in: .curl) == code.curl)
        #expect(code.text(in: .swiftURLSession) == code.swift)
    }

    @Test("A method other than GET is written out, and a custom one is kept as written")
    func methods() async throws {
        let post = try await code(for: Request(name: "A", method: .post, urlTemplate: "https://example.com"))
        let custom = try await code(
            for: Request(name: "B", method: HTTPMethod(rawValue: "PROPFIND"), urlTemplate: "https://example.com")
        )

        #expect(post.curl == "curl --url 'https://example.com' \\\n  --request 'POST'")
        #expect(post.swift.contains(#"request.httpMethod = "POST""#))
        #expect(custom.curl.contains("--request 'PROPFIND'"))
        #expect(custom.swift.contains(#"request.httpMethod = "PROPFIND""#))
    }

    @Test("HEAD uses cURL's own option, because --request HEAD waits for a body that never comes")
    func head() async throws {
        let code = try await code(for: Request(name: "A", method: .head, urlTemplate: "https://example.com"))

        #expect(code.curl == "curl --url 'https://example.com' \\\n  --head")
        #expect(code.swift.contains(#"request.httpMethod = "HEAD""#))
    }

    @Test("A disabled query, path or header row is left out")
    func disabledRows() async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com/users/:id",
            queryParameters: [
                KeyValue(key: "limit", value: "10"),
                KeyValue(key: "offset", value: "0", isEnabled: false)
            ],
            pathParameters: [KeyValue(key: "id", value: "42", isEnabled: false)],
            headers: [
                KeyValue(key: "Accept", value: "application/json"),
                KeyValue(key: "X-Debug", value: "1", isEnabled: false)
            ]
        ))

        #expect(code.curl == """
        curl --url 'https://example.com/users/:id?limit=10' \\
          --header 'Accept: application/json'
        """)
        #expect(code.swift.contains(#"URL(string: "https://example.com/users/:id?limit=10")!"#))
        #expect(code.swift.contains(#"request.addValue("application/json", forHTTPHeaderField: "Accept")"#))
        #expect(!code.swift.contains("offset"))
        #expect(!code.swift.contains("X-Debug"))
    }

    @Test("A repeated header stays repeated, and repeated cookies join as Send joins them")
    func repeatedHeaders() async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [
                KeyValue(key: "Accept", value: "text/plain"),
                KeyValue(key: "Accept", value: "text/html"),
                KeyValue(key: "Cookie", value: "a=1"),
                KeyValue(key: "cookie", value: "b=2")
            ]
        ))

        #expect(code.curl == """
        curl --url 'https://example.com' \\
          --header 'Accept: text/plain' \\
          --header 'Accept: text/html' \\
          --header 'Cookie: a=1; b=2'
        """)
        #expect(code.swift.contains(#"request.addValue("a=1; b=2", forHTTPHeaderField: "Cookie")"#))
    }

    @Test("A header with an empty value keeps its name, which cURL needs a semicolon to send")
    func emptyHeaderValue() async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Empty", value: "")]
        ))

        #expect(code.curl.contains("--header 'X-Empty;'"))
        #expect(code.swift.contains(#"request.addValue("", forHTTPHeaderField: "X-Empty")"#))
    }

    @Test(
        "A header Send refuses is left out, with a comment",
        arguments: [
            ("@/etc/passwd", "cURL reads this name as a file"),
            ("X-Inject", "a\r\nEvil: b"),
            ("not a token", "1"),
            ("X-Wide", "日本語")
        ]
    )
    func unsendableHeader(name: String, value: String) async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: name, value: value)]
        ))

        let comment = "Headers that can\u{2019}t be sent are left out."
        #expect(code.curl == "# \(comment)\ncurl --url 'https://example.com'")
        #expect(code.swift.hasPrefix("// \(comment)\nimport Foundation"))
        #expect(!code.swift.contains("forHTTPHeaderField"))
    }

    @Test(
        "A variable in a row doesn't excuse what filling it in can't fix",
        arguments: [
            ("X-Inject", "a\r\nEvil: {{token}}"),
            ("{{name}}", "a\r\nEvil: b"),
            ("not a token", "{{value}}"),
            ("@{{path}}", "1"),
            ("X-Key", "日本語{{"),
            ("X-Key", "日本語")
        ]
    )
    func variableDoesntExcuseARow(name: String, value: String) async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: name, value: value)]
        ))

        #expect(!code.curl.contains("--header"))
        #expect(code.curl.hasPrefix("# "))
    }

    @Test("A non-breaking space is a value, so cURL doesn't send it as empty")
    func nonBreakingSpaceIsAValue() async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Sep", value: "\u{A0}")]
        ))

        #expect(code.curl.contains("--header 'X-Sep: \u{A0}'"))
    }

    @Test("A header with a variable left in it stays, because filling it in may make it valid")
    func headerWithAVariableLeftIn() async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "{{name}}", value: "1"), KeyValue(key: "X-Key", value: "日本語{{token}}")]
        ))

        #expect(code.curl.contains("--header '{{name}}: 1'"))
        #expect(code.curl.contains("--header 'X-Key: 日本語{{token}}'"))
        #expect(!code.curl.contains("#"))
    }

    @Test("A blank header value is sent as empty, because cURL drops the header otherwise")
    func blankHeaderValue() async throws {
        let code = try await code(for: Request(
            name: "Users",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Blank", value: "   ")]
        ))

        #expect(code.curl.contains("--header 'X-Blank;'"))
    }

    @Test("A URL with a space works in cURL, which refuses it as written")
    func urlWithASpace() async throws {
        let code = try await code(for: Request(name: "Users", urlTemplate: "https://example.com/my files"))

        #expect(code.curl == "curl --url 'https://example.com/my%20files'")
    }

    @Test("An empty URL renders as written, because this is text to fill in")
    func emptyURL() async throws {
        let code = try await code(for: Request(name: "Health"))

        #expect(code.curl == "curl --url ''")
        #expect(code.swift.contains(#"URL(string: "")!"#))
    }

    @Test("A brace or bracket in the URL turns off cURL's globbing, or it would read them as ranges")
    func globbing() async throws {
        let braces = try await code(for: Request(name: "A", urlTemplate: "https://example.com/{{id}}"))
        let brackets = try await code(for: Request(name: "B", urlTemplate: "https://example.com/a[1]"))
        let neither = try await code(for: Request(name: "C", urlTemplate: "https://example.com/a"))

        #expect(braces.curl.contains("--globoff"))
        #expect(brackets.curl.contains("--globoff"))
        #expect(!neither.curl.contains("--globoff"))
    }

}
