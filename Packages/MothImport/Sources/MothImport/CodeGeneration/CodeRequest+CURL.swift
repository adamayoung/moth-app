//  CodeRequest+CURL.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

nonisolated extension CodeRequest {

    /// `--url` rather than a bare argument, so an address that starts with `-` can't read as an option.
    var curl: String {
        let options = globbingOptions + methodOptions + headers.map(\.curlOption) + userOptions + bodyOptions
        let command = (["curl --url \(address.shellQuoted)"] + options).joined(separator: " \\\n  ")
        return (notes.map { "# \($0)" } + [command]).joined(separator: "\n")
    }

    /// cURL reads `{}` and `[]` in a URL as ranges to expand.
    private var globbingOptions: [String] {
        address.contains { "{}[]".contains($0) } ? ["--globoff"] : []
    }

    /// `--request HEAD` waits for a body that never comes.
    private var methodOptions: [String] {
        switch method {
        case .get: []
        case .head: ["--head"]
        default: ["--request \(method.rawValue.shellQuoted)"]
        }
    }

    private var userOptions: [String] {
        basicCredentials.map { ["--user \($0.shellQuoted)"] } ?? []
    }

    /// `--data` reads a leading `@` as a file and strips newlines, so a body goes out as `--data-raw`.
    private var bodyOptions: [String] {
        switch body {
        case .none: []
        case .text(let text): ["--data-raw \(text.shellQuoted)"]
        case .file(let path): ["--data-binary \("@\(path)".shellQuoted)"]
        case .form(let parts): parts.map(\.curlOption)
        }
    }

}

private nonisolated extension CodeHeader {

    /// `Name:` with a blank value tells cURL to remove the header, and only `Name;` sends it empty.
    var curlOption: String {
        "--header \((value.allSatisfy(\.isWhitespace) ? "\(name);" : "\(name): \(value)").shellQuoted)"
    }

}

private nonisolated extension CodeFormPart {

    /// `--form` reads a value's leading `@` or `<` as a file, unless the value is in its own double quotes.
    var curlOption: String {
        let type = contentType.map { ";type=\($0)" } ?? ""

        switch content {
        case .text(let text) where contentType == nil:
            return "--form-string \("\(name)=\(text)".shellQuoted)"
        case .text(let text):
            return "--form \("\(name)=\"\(text.curlFormEscaped)\"\(type)".shellQuoted)"
        case .file(let path):
            return "--form \("\(name)=@\"\(path.curlFormEscaped)\"\(type)".shellQuoted)"
        }
    }

}

private nonisolated extension String {

    var curlFormEscaped: String {
        unicodeScalars.reduce(into: "") { escaped, scalar in
            if scalar == "\\" || scalar == "\"" {
                escaped += "\\"
            }
            escaped.unicodeScalars.append(scalar)
        }
    }

}
