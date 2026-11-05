//  VariableModel+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension VariableModel {

    static var globals: FetchDescriptor<VariableModel> {
        FetchDescriptor(predicate: #Predicate { $0.isGlobal })
    }

}
