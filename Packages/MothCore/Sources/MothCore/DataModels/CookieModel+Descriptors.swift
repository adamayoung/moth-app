//  CookieModel+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension CookieModel {

    static func inWorkspace(_ workspaceID: UUID) -> FetchDescriptor<CookieModel> {
        FetchDescriptor(predicate: #Predicate { $0.workspaceID == workspaceID })
    }

    static func withIDs(_ ids: [UUID]) -> FetchDescriptor<CookieModel> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

}
