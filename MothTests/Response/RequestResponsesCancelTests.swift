//  RequestResponsesCancelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct RequestResponsesCancelTests: RequestResponsesTesting {

    @Test("A send shows as sending until it finishes")
    func sendingState() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        let wasSending = responses.isSending(request.id)
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(wasSending)
            #expect(!responses.isSending(request.id))
        }
    }

    @Test("Cancel shows at once, even if the transport never answers")
    func cancelShowsAtOnce() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        let state = responses.state(for: request.id)
        let wasCancelled = transport.wasCancelled
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(state == .finished(.cancelled))
            #expect(wasCancelled)
        }
    }

    @Test("A result that arrives after Cancel doesn't replace it")
    func lateResultIgnored() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(responses.state(for: request.id) == .finished(.cancelled))
        }
    }

    @Test("A cancelled send's late result doesn't land on the send that followed it")
    func lateResultMissesTheNextSend() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)
        let draft = RequestDraft(request)

        let first = responses.send(request.id, draft: draft, tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        transport.release()
        let second = responses.send(request.id, draft: draft, tree: tree)
        await first.value
        let isStillSending = responses.isSending(request.id)
        await transport.waitForSend()
        transport.release()
        await second.value

        withExtendedLifetime(dataModel) {
            #expect(isStillSending)
        }
    }

    @Test("Keeping other requests cancels a send in flight, and its late result lands nowhere")
    func keepCancelsSends() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.keep([])
        let wasCancelled = transport.wasCancelled
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(wasCancelled)
            #expect(responses.state(for: request.id) == nil)
        }
    }

    @Test("Closing the window cancels a send in flight")
    func releaseCancels() async throws {
        let transport = HoldingHTTPTransport()
        let (dataModel, send) = try await startSendThenReleaseItsModel(through: transport)

        let wasCancelled = await eventually { transport.wasCancelled }
        transport.release()
        await send.value

        withExtendedLifetime(dataModel) {
            #expect(wasCancelled)
        }
    }

    private func startSendThenReleaseItsModel(
        through transport: HoldingHTTPTransport
    ) async throws -> (DataModel, Task<Void, Never>) {
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)
        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        return (dataModel, send)
    }

    /// An isolated deinit runs on a later turn of the main actor.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        return condition()
    }

}
