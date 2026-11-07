//  CurlImportTesting.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

enum CurlImportTesting {

    static func importing(
        _ command: String,
        secretStore: any SecretStore = RecordingSecretStore()
    ) async throws -> CurlImportResult {
        try await CurlImporter(secretStore: secretStore).importCommand(command) { _ in }
    }

    static func request(_ command: String) async throws -> Request {
        try await importing(command).request
    }

    static func ignored(_ command: String) async throws -> [String] {
        try await importing(command).ignored
    }

}

nonisolated struct Pair: Equatable, Sendable, CustomTestStringConvertible {

    let key: String
    let value: String

    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }

    var testDescription: String {
        "\(key)=\(value)"
    }

}

extension [KeyValue] {

    var pairs: [Pair] {
        map { Pair($0.key, $0.value) }
    }

}
