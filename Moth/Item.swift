//  Item.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
