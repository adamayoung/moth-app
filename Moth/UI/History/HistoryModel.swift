//  HistoryModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Observation
import OSLog

/// One window's History: which entry the detail column shows, and the commands on it.
@Observable
final class HistoryModel {

    typealias SendAgain = @MainActor (HistoryEntry) async -> SendAgainOutcome
    typealias Record = @MainActor (HistoryEntry) async throws -> Void
    typealias Clear = @MainActor () async throws -> Void

    private(set) var openEntry: HistoryEntry.ID?
    private(set) var isSendingAgain = false
    private(set) var secretUnavailable: HistoryEntry.ID?
    var isConfirmingClear = false

    private let performSendAgain: SendAgain
    private let record: Record
    private let performClear: Clear
    private let openTab: (Request.ID) -> Void

    init(
        sendAgain: @escaping SendAgain,
        record: @escaping Record,
        clear: @escaping Clear,
        openTab: @escaping (Request.ID) -> Void
    ) {
        self.performSendAgain = sendAgain
        self.record = record
        self.performClear = clear
        self.openTab = openTab
    }

    convenience init(
        writer: StoreWriter,
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        openTab: @escaping (Request.ID) -> Void
    ) {
        let sender = RequestSender(transport: transport, secretStore: secretStore)
        self.init(
            sendAgain: { await sender.sendAgain($0) },
            record: { try await writer.addHistoryEntry($0) },
            clear: { try await writer.clearHistory() },
            openTab: openTab
        )
    }

    static var preview: HistoryModel {
        HistoryModel(sendAgain: { _ in .secretUnavailable }, record: { _ in }, clear: {}, openTab: { _ in })
    }

    func open(_ id: HistoryEntry.ID) {
        openEntry = id
    }

    func close() {
        openEntry = nil
    }

    func canOpenRequest(_ id: Request.ID, in tree: CollectionTree) -> Bool {
        tree.contains(.request(id))
    }

    func openRequest(_ id: Request.ID) {
        close()
        openTab(id)
    }

    /// Opens the new entry, so the response it shows is the one just sent.
    func sendAgain(_ entry: HistoryEntry) async {
        guard !isSendingAgain else {
            return
        }
        isSendingAgain = true
        defer { isSendingAgain = false }
        secretUnavailable = nil

        switch await performSendAgain(entry) {
        case .secretUnavailable:
            secretUnavailable = entry.id
        case .sent(let recorded):
            guard let newEntry = recorded.entry else {
                return
            }
            do {
                try await record(newEntry)
                openEntry = newEntry.id
            } catch {
                Logger.history.error("Couldn’t record a send in History: \(error)")
            }
        }
    }

    func clear() async {
        do {
            try await performClear()
            close()
        } catch {
            Logger.history.error("Couldn’t clear History: \(error)")
        }
    }

}
