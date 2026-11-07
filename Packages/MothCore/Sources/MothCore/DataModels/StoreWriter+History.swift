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
            let newestFirst = FetchDescriptor<HistoryEntryModel>(sortBy: [SortDescriptor(\.sentAt, order: .reverse)])
            try context.fetch(newestFirst).dropFirst(Self.historyLimit).forEach(context.delete)
        }
    }

    func clearHistory() throws {
        try write { context in
            try context.fetch(FetchDescriptor<HistoryEntryModel>()).forEach(context.delete)
        }
    }

}
