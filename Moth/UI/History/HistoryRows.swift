//  HistoryRows.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

/// Buttons rather than list selection, which names collection tree rows only.
struct HistoryRows: View {

    @Query(Self.summaries) private var entries: [HistoryEntryModel]
    let history: HistoryModel
    let didOpen: () -> Void

    /// Leaves out the snapshot and response, so a row reads no blob.
    private static var summaries: FetchDescriptor<HistoryEntryModel> {
        var descriptor = FetchDescriptor<HistoryEntryModel>(sortBy: [SortDescriptor(\.sentAt, order: .reverse)])
        descriptor.propertiesToFetch = [\.id, \.method, \.url, \.statusCode, \.sentAt]
        return descriptor
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Text("SIDEBAR_HISTORY_EMPTY")
            }
        } else {
            ForEach(entries) { entry in
                Button {
                    history.open(entry.id)
                    didOpen()
                } label: {
                    HistoryRowLabel(entry: entry)
                }
                .buttonStyle(.plain)
                .listRowBackground(history.openEntry == entry.id ? Color.accentColor.opacity(0.2) : nil)
                .accessibilityLabel(Text(verbatim: "\(entry.method) \(entry.url)"))
                .accessibilityIdentifier("history.row")
                .contextMenu {
                    ClearHistoryButton(history: history)
                }
            }
        }
    }

}

struct ClearHistoryButton: View {

    let history: HistoryModel

    var body: some View {
        Button("HISTORY_CLEAR") {
            history.isConfirmingClear = true
        }
    }

}

private struct HistoryRowLabel: View {

    let entry: HistoryEntryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(verbatim: entry.method)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(verbatim: entry.url)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 6) {
                status
                Spacer(minLength: 0)
                Text(entry.sentAt, format: .dateTime.hour().minute())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var status: some View {
        if let statusCode = entry.statusCode {
            Text(verbatim: String(statusCode))
        } else {
            Text("HISTORY_ROW_FAILED")
        }
    }

}
