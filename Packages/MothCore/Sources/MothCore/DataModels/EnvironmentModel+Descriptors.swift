//  EnvironmentModel+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension EnvironmentModel {

    static func withID(_ id: UUID) -> FetchDescriptor<EnvironmentModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

}
