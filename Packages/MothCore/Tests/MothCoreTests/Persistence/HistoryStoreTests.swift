//  HistoryStoreTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct HistoryStoreTests {
    @Test("The store keeps the newest 500 entries, dropping the oldest")
    func keepsTheNewestFiveHundred() async throws {
        let dataModel = try DataModel.inMemory()
        let context = ModelContext(dataModel.container)
        for second in 0 ..< 500 {
            try context.insert(HistoryEntryModel(Self.entry(sentAt: Double(second))))
        }
        try context.save()

        try await dataModel.writer.addHistoryEntry(Self.entry(sentAt: 1000))

        let sentAt = try Self.savedEntries(in: dataModel).map(\.sentAt.timeIntervalSinceReferenceDate)
        #expect(sentAt.count == 500)
        #expect(sentAt.min() == 1)
        #expect(sentAt.max() == 1000)
    }

    @Test("Clear History removes every entry")
    func clearRemovesEveryEntry() async throws {
        let dataModel = try DataModel.inMemory(seed: Workspace())
        try await dataModel.writer.addHistoryEntry(Self.entry(sentAt: 1))
        try await dataModel.writer.addHistoryEntry(Self.entry(sentAt: 2))

        try await dataModel.writer.clearHistory()

        #expect(try Self.savedEntries(in: dataModel).isEmpty)
    }

    /// One implicit workspace owns history, so a merge that replaces its row must not lose it.
    @Test("History survives reconcile replacing this Mac's workspace with one of lower id")
    func historySurvivesAWorkspaceMerge() async throws {
        let local = Workspace(id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000") ?? UUID())
        let dataModel = try DataModel.inMemory(seed: local)
        let entry = Self.entry(sentAt: 1)
        try await dataModel.writer.addHistoryEntry(entry)
        let synced = ModelContext(dataModel.container)
        try synced
            .insert(WorkspaceModel(Workspace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID())))
        try synced.save()

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try ModelContext(dataModel.container).fetch(FetchDescriptor<WorkspaceModel>()).count == 1)
        #expect(try Self.savedEntries(in: dataModel) == [entry])
    }

    private static func entry(sentAt seconds: Double) -> HistoryEntry {
        HistoryEntry(
            request: Request(name: "Ping", urlTemplate: "https://example.com"),
            sentAt: Date(timeIntervalSinceReferenceDate: seconds),
            duration: .milliseconds(1),
            response: HistoryResponse(status: 200)
        )
    }

    private static func savedEntries(in dataModel: DataModel) throws -> [HistoryEntry] {
        try ModelContext(dataModel.container).fetch(FetchDescriptor<HistoryEntryModel>()).map { try $0.asDomain() }
    }
}
