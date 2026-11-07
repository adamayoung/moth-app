//  HistoryEntryPane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct HistoryEntryPane: View {

    @Query private var rows: [HistoryEntryModel]
    @State private var shown: ShownHistoryEntry?
    let history: HistoryModel
    let canOpenRequest: (Request.ID) -> Bool

    init(id: HistoryEntry.ID, history: HistoryModel, canOpenRequest: @escaping (Request.ID) -> Bool) {
        _rows = Query(filter: #Predicate<HistoryEntryModel> { $0.id == id })
        self.history = history
        self.canOpenRequest = canOpenRequest
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("HISTORY_ENTRY_LABEL")
            .accessibilityIdentifier("history.entry")
            .task(id: rows.first?.id) {
                guard let entry = try? rows.first?.asDomain() else {
                    shown = nil
                    return
                }
                shown = await ShownHistoryEntry.make(entry)
            }
    }

    @ViewBuilder
    private var content: some View {
        if rows.isEmpty {
            ContentUnavailableView("HISTORY_ENTRY_GONE", systemImage: "clock.arrow.circlepath")
        } else if let shown, shown.entry.id == rows.first?.id {
            HistoryEntryView(shown: shown, history: history, canOpenRequest: canOpenRequest(shown.entry.request.id))
        } else {
            ProgressView()
        }
    }

}

/// Works out the response's content off the main actor, as a live send does, because a body can be megabytes.
struct ShownHistoryEntry: Sendable {

    let entry: HistoryEntry
    let response: SentResponse?

    @concurrent
    static func make(_ entry: HistoryEntry) async -> ShownHistoryEntry {
        ShownHistoryEntry(entry: entry, response: entry.response.map { SentResponse($0, duration: entry.duration) })
    }

}

struct HistoryEntryView: View {

    let shown: ShownHistoryEntry
    let history: HistoryModel
    let canOpenRequest: Bool

    @State private var section = ResponseSection.body

    private var entry: HistoryEntry {
        shown.entry
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding()

            Divider()

            VSplitView {
                HistoryRequestView(request: entry.request)
                    .frame(minHeight: 120)

                response
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 160)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: entry.request.method.rawValue)
                .font(.headline.monospaced())

            Text(verbatim: RequestDraft(entry.request).url)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityIdentifier("history.url")

            Spacer()

            if history.secretUnavailable == entry.id {
                Label("HISTORY_SECRET_UNAVAILABLE", systemImage: "key.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("history.secretUnavailable")
            }

            Button("HISTORY_OPEN_REQUEST") {
                history.openRequest(entry.request.id)
            }
            .disabled(!canOpenRequest)
            .accessibilityIdentifier("history.openRequest")

            Button("HISTORY_SEND_AGAIN") {
                Task { await history.sendAgain(entry) }
            }
            .disabled(history.isSendingAgain)
            .accessibilityIdentifier("history.sendAgain")
        }
    }

    @ViewBuilder
    private var response: some View {
        if let response = shown.response {
            ResponseView(response: response, section: $section, isBodyKept: entry.response?.body != nil)
        } else if let failure = entry.failure {
            ResponseFailureView(failure: failure, notes: [])
        }
    }

}

#Preview("Response") {
    let entry = HistoryEntry(
        request: Request(
            name: "List",
            urlTemplate: "https://api.example.com/users",
            headers: [KeyValue(key: "Authorization", value: HistoryEntry.maskedValue)],
            auth: .none
        ),
        sentAt: .now,
        duration: .milliseconds(142),
        response: HistoryResponse(
            status: 200,
            reasonPhrase: "OK",
            headers: [KeyValue(key: "Content-Type", value: "application/json")],
            timing: [PhaseTiming(phase: .dns, duration: .milliseconds(12))],
            size: 22,
            body: Data(#"{"id":1,"name":"Moth"}"#.utf8)
        )
    )
    HistoryEntryView(
        shown: ShownHistoryEntry(
            entry: entry,
            response: entry.response.map { SentResponse($0, duration: .milliseconds(142)) }
        ),
        history: .preview,
        canOpenRequest: true
    )
    .frame(width: 700, height: 500)
}

#Preview("Body Not Kept") {
    let entry = HistoryEntry(
        request: Request(name: "Download", urlTemplate: "https://api.example.com/export"),
        sentAt: .now,
        duration: .seconds(2),
        response: HistoryResponse(status: 200, reasonPhrase: "OK", size: 6_000_000, body: nil)
    )
    HistoryEntryView(
        shown: ShownHistoryEntry(
            entry: entry,
            response: entry.response.map { SentResponse($0, duration: .seconds(2)) }
        ),
        history: .preview,
        canOpenRequest: false
    )
    .frame(width: 700, height: 500)
}
