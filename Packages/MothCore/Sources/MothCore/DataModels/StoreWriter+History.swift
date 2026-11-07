//  StoreWriter+History.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public extension StoreWriter {

    static let historyLimit = 500

    func addHistoryEntry(_ entry: HistoryEntry) throws {
        try write { context in
            try context.insert(HistoryEntryModel(entry))
            let overflow = try context.fetchCount(FetchDescriptor<HistoryEntryModel>()) - Self.historyLimit
            guard overflow > 0 else {
                return
            }
            var oldestFirst = FetchDescriptor<HistoryEntryModel>(sortBy: [SortDescriptor(\.sentAt)])
            oldestFirst.fetchLimit = overflow
            try context.fetch(oldestFirst).forEach(context.delete)
        }
    }

    func clearHistory() throws {
        try write { context in
            try context.fetch(FetchDescriptor<HistoryEntryModel>()).forEach(context.delete)
        }
    }

}
