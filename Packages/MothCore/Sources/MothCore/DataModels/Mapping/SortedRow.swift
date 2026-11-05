//  SortedRow.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated protocol SortedRow {

    var id: UUID { get }
    var sortOrder: Int { get }

}

nonisolated extension Sequence where Element: SortedRow {

    /// Ties fall back to `id` because a sync can give two rows one `sortOrder`, and devices must agree.
    var inSortOrder: [Element] {
        sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
    }

    var nextSortOrder: Int {
        (map(\.sortOrder).max() ?? -1) + 1
    }

}

nonisolated extension Optional where Wrapped: Sequence, Wrapped.Element: SortedRow {

    var inSortOrder: [Wrapped.Element] {
        self?.inSortOrder ?? []
    }

}

nonisolated extension CollectionModel: SortedRow {}
nonisolated extension EnvironmentModel: SortedRow {}
nonisolated extension VariableModel: SortedRow {}
