//  RequestResponses.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Observation
import OSLog

/// One window's latest responses, keyed by request and held only in memory, so a relaunch returns to No Response.
@Observable
final class RequestResponses {

    enum State: Equatable {

        case sending
        case finished(SendResult)

    }

    typealias Send = @MainActor (Request.ID, RequestDraft, CollectionTree) async -> RecordedSend
    typealias Record = @MainActor (HistoryEntry) async -> Void

    private struct InFlight {

        let token: UUID
        let task: Task<Void, Never>

    }

    private var states: [Request.ID: State] = [:]
    @ObservationIgnored private var inFlight: [Request.ID: InFlight] = [:]
    private let perform: Send
    private let record: Record

    init(send: @escaping Send, record: @escaping Record = { _ in }) {
        self.perform = send
        self.record = record
    }

    convenience init(
        dataModel: DataModel,
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        activeEnvironment: ActiveEnvironment
    ) {
        let sender = RequestSender(transport: transport, secretStore: secretStore)
        let writer = dataModel.writer
        self.init { id, draft, tree in
            do {
                let context = try dataModel.sendContext(for: id, in: tree, environment: activeEnvironment.id)
                let outgoing = try draft.outgoing(from: context.request, in: tree)
                return await sender.sendRecording(outgoing, scopes: context.scopes)
            } catch {
                return RecordedSend(result: .failed(SendFailure(notSent: error), notes: []), entry: nil)
            }
        } record: { entry in
            do {
                try await writer.addHistoryEntry(entry)
            } catch {
                Logger.response.error("Couldn’t record a send in History: \(error)")
            }
        }
    }

    isolated deinit {
        inFlight.values.forEach { $0.task.cancel() }
    }

    /// New on every use, because previews share one process and one would otherwise show another's responses.
    static var preview: RequestResponses {
        RequestResponses { _, _, _ in .cancelled }
    }

    func state(for id: Request.ID) -> State? {
        states[id]
    }

    func isSending(_ id: Request.ID) -> Bool {
        states[id] == .sending
    }

    /// Returns the send's task, which a caller only needs in order to wait for it.
    @discardableResult
    func send(_ id: Request.ID, draft: RequestDraft, tree: CollectionTree) -> Task<Void, Never> {
        if let current = inFlight[id]?.task {
            return current
        }
        let token = UUID()
        let task = Task { [weak self, perform] in
            let recorded = await perform(id, draft, tree)
            guard let self, finish(id, token: token, with: recorded.result), let entry = recorded.entry else {
                return
            }
            await record(entry)
        }
        inFlight[id] = InFlight(token: token, task: task)
        states[id] = .sending
        return task
    }

    /// Shows at once rather than waiting for the transport, which may finish its work first. A result that still
    /// arrives has lost its token.
    func cancel(_ id: Request.ID) {
        guard let send = inFlight.removeValue(forKey: id) else {
            return
        }
        send.task.cancel()
        states[id] = .finished(.cancelled)
    }

    func keep(_ ids: Set<Request.ID>) {
        for (id, send) in inFlight where !ids.contains(id) {
            send.task.cancel()
            inFlight[id] = nil
        }
        if states.keys.contains(where: { !ids.contains($0) }) {
            states = states.filter { ids.contains($0.key) }
        }
    }

    /// False for a send that was cancelled, or replaced, before its result arrived.
    private func finish(_ id: Request.ID, token: UUID, with result: SendResult) -> Bool {
        guard inFlight[id]?.token == token else {
            return false
        }
        inFlight[id] = nil
        states[id] = .finished(result)
        return true
    }

}
