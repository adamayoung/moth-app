//  ImportFile.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated enum ImportFile {

    /// The sandbox grants a file the system panel returned only inside this scope.
    @concurrent
    static func read(_ url: URL) async throws -> Data {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

}
