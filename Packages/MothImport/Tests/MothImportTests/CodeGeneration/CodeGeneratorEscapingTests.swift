//  CodeGeneratorEscapingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
@testable import MothImport
import Testing

struct CodeGeneratorEscapingTests {

    private nonisolated static let hostileValues = [
        "it's",
        "'; rm -rf / #",
        "a\u{301}'\u{301}b",
        #"say "hi""#,
        "$(whoami)",
        "`whoami`",
        "line one\nline two",
        "crlf\r\nend",
        #"back\slash"#,
        #"\(interpolated)"#,
        "naïve 日本語 🦋",
        "-o/etc/passwd",
        "@/etc/passwd",
        "<file",
        ""
    ]

    #if os(macOS)
        @Test("A quoted value reaches a POSIX shell's command unchanged", arguments: hostileValues)
        func shellRoundTrip(value: String) throws {
            let shell = Process()
            shell.executableURL = URL(filePath: "/bin/sh")
            shell.arguments = ["-c", "printf %s \(value.shellQuoted)"]
            let output = Pipe()
            shell.standardOutput = output

            try shell.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            shell.waitUntilExit()

            #expect(String(decoding: data, as: UTF8.self) == value)
        }
    #endif

    @Test(
        "A value's special characters are escaped for a Swift string",
        arguments: [
            (#"say "hi""#, #"say \"hi\""#),
            ("line one\nline two", #"line one\nline two"#),
            ("crlf\r\nend", #"crlf\r\nend"#),
            ("a\tb", #"a\tb"#),
            (#"back\slash"#, #"back\\slash"#),
            (#"\(interpolated)"#, #"\\(interpolated)"#),
            ("naïve 日本語 🦋", "naïve 日本語 🦋"),
            ("nul\u{0}bell\u{7}", #"nul\u{0}bell\u{7}"#),
            ("rtl\u{202E}override", #"rtl\u{202e}override"#),
            ("line\u{2028}separator", #"line\u{2028}separator"#)
        ]
    )
    func swiftEscaping(value: String, escaped: String) {
        #expect(value.swiftEscaped == escaped)
    }

    @Test("A hostile URL, method, header and body stay inside their quotes")
    func hostileRequest() async throws {
        let code = try await CodeGenerator().code(
            for: Request(
                name: "Users",
                method: HTTPMethod(rawValue: "PO'ST"),
                urlTemplate: "-o/etc/passwd",
                headers: [KeyValue(key: "X-It's", value: "line one\nline two")],
                body: .raw(content: #"it's "quoted" \(here)"#, contentType: "")
            ),
            scopes: VariableScopes()
        )

        #expect(code.curl.contains(#"--url 'http://-o/etc/passwd'"#))
        #expect(code.curl.contains(#"--request 'PO'\''ST'"#))
        #expect(code.curl.contains("--header 'X-It'\\''s: line one\nline two'"))
        #expect(code.curl.contains(#"--data-raw 'it'\''s "quoted" \(here)'"#))
        #expect(code.swift.contains(#"request.httpMethod = "PO'ST""#))
        #expect(code.swift.contains(#"request.addValue("line one\nline two", forHTTPHeaderField: "X-It's")"#))
        #expect(code.swift.contains(#"Data("it's \"quoted\" \\(here)".utf8)"#))
    }

    @Test("A variable holding a hostile value is quoted once it has resolved")
    func hostileVariable() async throws {
        let code = try await CodeGenerator().code(
            for: Request(name: "Users", urlTemplate: "https://example.com/{{tail}}"),
            scopes: VariableScopes(environment: [
                Variable(name: "tail", value: .plain(initial: "", current: "'; whoami; '"))
            ])
        )

        #expect(code.curl.contains(#"'https://example.com/'\''; whoami; '\'''"#))
    }

    @Test("A form-data name and a Content-Type stay on their own header line in Swift")
    func hostileFormField() async throws {
        let code = try await CodeGenerator().code(
            for: Request(
                name: "Users",
                method: .post,
                urlTemplate: "https://example.com",
                body: .formData([
                    FormDataField(key: "na\"me\r\n", value: .text("value"), contentType: "text/plain\r\nX-Evil: 1")
                ])
            ),
            scopes: VariableScopes()
        )

        #expect(code.swift.contains(#"name=\"na%22me%0D%0A\"\r\nContent-Type: text/plainX-Evil: 1\r\n\r\nvalue"#))
    }

}
