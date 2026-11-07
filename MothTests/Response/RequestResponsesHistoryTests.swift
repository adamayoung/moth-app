//  RequestResponsesHistoryTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestResponsesHistoryTests: RequestResponsesTesting {

    @Test("A finished send is recorded in History")
    func finishedSendIsRecorded() async throws {
        let request = Request(name: "List", urlTemplate: "{{host}}/users")
        let (dataModel, responses, tree) = try responses(holding: request, through: RecordingHTTPTransport())

        await responses.send(request.id, draft: RequestDraft(request), tree: tree).value

        let entries = try ModelContext(dataModel.container).fetch(FetchDescriptor<HistoryEntryModel>())
        #expect(entries.map(\.url) == ["https://staging.test/users"])
        #expect(entries.map(\.requestID) == [request.id])
    }

    @Test("A send cancelled while the transport still answers isn't recorded")
    func cancelledSendIsNotRecorded() async throws {
        let transport = HoldingHTTPTransport()
        let request = Request(name: "List", urlTemplate: "https://example.com")
        let (dataModel, responses, tree) = try responses(holding: request, through: transport)

        let send = responses.send(request.id, draft: RequestDraft(request), tree: tree)
        await transport.waitForSend()
        responses.cancel(request.id)
        transport.release()
        await send.value

        #expect(try ModelContext(dataModel.container).fetch(FetchDescriptor<HistoryEntryModel>()).isEmpty)
    }

}
