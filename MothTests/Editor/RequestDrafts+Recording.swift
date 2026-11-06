//  RequestDrafts+Recording.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import MothCore

typealias RecordedSave = @MainActor (Request.ID, RequestEdit) async throws -> Void

extension RequestDrafts {

    convenience init(recording save: @escaping RecordedSave) {
        self.init(secretStore: InMemorySecretStore()) { id, edit, _ in
            try await save(id, edit)
            return []
        }
    }

}
