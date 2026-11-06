//  RequestResponses.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Observation

/// One window's latest responses, keyed by request and held only in memory, so a relaunch returns to No Response.
@Observable
final class RequestResponses {

    enum State: Equatable {

        case sending
        case finished(SendResult)

    }

    typealias Send = @MainActor (Request.ID, RequestDraft, CollectionTree) async -> SendResult

    private struct InFlight {

        let token = UUID()
        var task: Task<Void, Never>?

    }

    private var states: [Request.ID: State] = [:]
    @ObservationIgnored private var inFlight: [Request.ID: InFlight] = [:]
    private let perform: Send

    init(send: @escaping Send) {
        self.perform = send
    }

    convenience init(
        dataModel: DataModel,
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        activeEnvironment: ActiveEnvironment
    ) {
        let sender = RequestSender(transport: transport, secretStore: secretStore)
        self.init { id, draft, tree in
            do {
                guard let context = try dataModel.sendContext(
                    for: id,
                    in: tree,
                    environment: activeEnvironment.id
                ) else {
                    return .cancelled
                }
                let outgoing = try draft.outgoing(from: context.request, in: tree)
                return await sender.send(outgoing, scopes: context.scopes)
            } catch {
                return .failed(SendFailure(notSent: error), notes: [])
            }
        }
    }

    isolated deinit {
        inFlight.values.forEach { $0.task?.cancel() }
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
        let send = InFlight()
        inFlight[id] = send
        states[id] = .sending
        let task = Task { [weak self, perform] in
            let result = await perform(id, draft, tree)
            self?.finish(id, token: send.token, with: result)
        }
        inFlight[id]?.task = task
        return task
    }

    /// Shows at once rather than waiting for the transport, which may finish its work first. A result that still
    /// arrives has lost its token.
    func cancel(_ id: Request.ID) {
        guard let send = inFlight.removeValue(forKey: id) else {
            return
        }
        send.task?.cancel()
        states[id] = .finished(.cancelled)
    }

    func keep(_ ids: Set<Request.ID>) {
        for (id, send) in inFlight where !ids.contains(id) {
            send.task?.cancel()
            inFlight[id] = nil
        }
        if states.keys.contains(where: { !ids.contains($0) }) {
            states = states.filter { ids.contains($0.key) }
        }
    }

    private func finish(_ id: Request.ID, token: UUID, with result: SendResult) {
        guard inFlight[id]?.token == token else {
            return
        }
        inFlight[id] = nil
        states[id] = .finished(result)
    }

}
