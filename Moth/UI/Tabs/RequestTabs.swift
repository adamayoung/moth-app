//  RequestTabs.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

struct RequestTabs: Codable, Equatable {

    private(set) var ids: [Request.ID] = []
    private(set) var selected: Request.ID?

    mutating func open(_ id: Request.ID) {
        if !ids.contains(id) {
            ids.append(id)
        }
        selected = id
    }

    mutating func select(_ id: Request.ID) {
        if ids.contains(id) {
            selected = id
        }
    }

    mutating func close(_ id: Request.ID) {
        guard let index = ids.firstIndex(of: id) else {
            return
        }
        ids.remove(at: index)
        if selected == id {
            selected = ids.indices.contains(index) ? ids[index] : ids.last
        }
    }

}
