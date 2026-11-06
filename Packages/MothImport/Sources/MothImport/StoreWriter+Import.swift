//  StoreWriter+Import.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

public extension StoreWriter {

    func create(_ content: PostmanImportContent) throws {
        switch content {
        case .collection(let collection): try createCollection(collection)
        case .environment(let environment): try createEnvironment(environment)
        }
    }

}
