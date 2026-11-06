//  FolderModel+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension FolderModel {

    static func withID(_ id: UUID) -> FetchDescriptor<FolderModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

}
