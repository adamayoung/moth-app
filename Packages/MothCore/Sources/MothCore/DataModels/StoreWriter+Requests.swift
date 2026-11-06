//  StoreWriter+Requests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public extension StoreWriter {

    /// Every row with this id, because sync can duplicate one, and a twin left behind would bring the old fields back.
    func updateRequest(_ id: Request.ID, with edit: RequestEdit) throws {
        try write { context in
            for row in try context.fetch(RequestModel.withID(id)) {
                try row.apply(edit)
            }
        }
    }

}
