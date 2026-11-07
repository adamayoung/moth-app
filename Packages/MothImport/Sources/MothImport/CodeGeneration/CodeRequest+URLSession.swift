//  CodeRequest+URLSession.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

nonisolated extension CodeRequest {

    var urlSession: String {
        let setup = ["var request = URLRequest(url: URL(string: \(address.swiftLiteral))!)"]
            + methodLines
            + headers.map(\.urlSessionLine)
        let send = [
            "let (data, response) = try await URLSession.shared.data(for: request)",
            "print(response)",
            "print(String(decoding: data, as: UTF8.self))"
        ]
        return (["import Foundation", ""] + setup + [""] + send).joined(separator: "\n")
    }

    private var methodLines: [String] {
        method == .get ? [] : ["request.httpMethod = \(method.rawValue.swiftLiteral)"]
    }

}

private nonisolated extension CodeHeader {

    var urlSessionLine: String {
        "request.addValue(\(value.swiftLiteral), forHTTPHeaderField: \(name.swiftLiteral))"
    }

}
