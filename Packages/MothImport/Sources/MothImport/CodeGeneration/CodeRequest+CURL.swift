//  CodeRequest+CURL.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

nonisolated extension CodeRequest {

    /// `--url` rather than a bare argument, so an address that starts with `-` can't read as an option.
    var curl: String {
        let options = globbingOptions + methodOptions + headers.map(\.curlOption)
        return (["curl --url \(address.shellQuoted)"] + options).joined(separator: " \\\n  ")
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

}

private nonisolated extension CodeHeader {

    /// `Name:` tells cURL to remove the header, and only `Name;` sends it empty.
    var curlOption: String {
        "--header \((value.isEmpty ? "\(name);" : "\(name): \(value)").shellQuoted)"
    }

}
