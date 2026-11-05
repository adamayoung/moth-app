//  TreeRow+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension CollectionModel {

    static func withID(_ id: UUID) -> FetchDescriptor<CollectionModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

}

nonisolated extension FolderModel {

    static func withID(_ id: UUID) -> FetchDescriptor<FolderModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

}

nonisolated extension RequestModel {

    static func withID(_ id: UUID) -> FetchDescriptor<RequestModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

}
