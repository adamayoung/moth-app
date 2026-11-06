//  CollectionModel+Descriptors.swift
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
