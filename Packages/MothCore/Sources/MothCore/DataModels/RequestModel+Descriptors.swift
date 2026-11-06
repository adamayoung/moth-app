//  RequestModel+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension RequestModel {

    static func withID(_ id: UUID) -> FetchDescriptor<RequestModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

}
