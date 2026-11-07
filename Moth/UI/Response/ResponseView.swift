//  ResponseView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

enum ResponseSection: CaseIterable, Identifiable {

    case body
    case headers
    case timing

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .body: String(localized: "RESPONSE_SECTION_BODY")
        case .headers: String(localized: "RESPONSE_SECTION_HEADERS")
        case .timing: String(localized: "RESPONSE_SECTION_TIMING")
        }
    }

}

struct ResponseView: View {

    let response: SentResponse
    @Binding var section: ResponseSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: response.statusLine())
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("response.status")

                Spacer()

                Picker("RESPONSE_SECTIONS_LABEL", selection: $section) {
                    ForEach(ResponseSection.allCases) { section in
                        Text(verbatim: section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("response.sections")
            }

            ResponseNotesView(notes: response.notes)

            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding()
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .body: ResponseBodyView(content: response.content)
        case .headers: ResponseHeadersView(headers: response.headers)
        case .timing: ResponseTimingView(timing: response.timing, total: response.duration)
        }
    }

}

struct ResponseNotesView: View {

    let notes: [ResponseNote]

    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(notes, id: \.self) { note in
                    Label {
                        Text(verbatim: note.message)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("response.note")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

}

struct ResponseBodyView: View {

    let content: ResponseContent

    var body: some View {
        switch content {
        case .empty:
            ContentUnavailableView("RESPONSE_BODY_EMPTY", systemImage: "doc")
        case .text(let text):
            ReadOnlyTextView(text: text, accessibilityIdentifier: "response.body")
        case .tooLarge(let raw):
            VStack(alignment: .leading, spacing: 8) {
                Text("RESPONSE_BODY_TOO_LARGE")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("response.bodyNote")

                ReadOnlyTextView(text: raw, accessibilityIdentifier: "response.body")
            }
        case .binary(let contentType, let size):
            ContentUnavailableView(
                "RESPONSE_BODY_BINARY",
                systemImage: "doc.zipper",
                description: Text(verbatim: [contentType, size.byteCountText].compactMap(\.self)
                    .joined(separator: " · "))
            )
        }
    }

}

struct ResponseHeadersView: View {

    let headers: [ResponseHeader]

    var body: some View {
        ScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(headers, id: \.name) { header in
                    GridRow {
                        Text(verbatim: header.name)
                            .fontWeight(.medium)
                            .accessibilityIdentifier("response.header.name")

                        Text(verbatim: header.value)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("response.header.value")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

struct ResponseTimingView: View {

    let timing: [PhaseTiming]
    let total: Duration

    var body: some View {
        ScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(timing, id: \.phase) { row in
                    GridRow {
                        Text(verbatim: row.phase.title)
                            .accessibilityIdentifier("response.timing.phase")

                        Text(verbatim: row.duration.responseText())
                            .accessibilityIdentifier("response.timing.duration")
                    }
                }

                GridRow {
                    Text("RESPONSE_TIMING_TOTAL")
                        .fontWeight(.medium)
                        .accessibilityIdentifier("response.timing.phase")

                    Text(verbatim: total.responseText())
                        .fontWeight(.medium)
                        .accessibilityIdentifier("response.timing.duration")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

struct ResponseFailureView: View {

    let failure: SendFailure
    let notes: [ResponseNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ResponseNotesView(notes: notes)

            ContentUnavailableView(
                failure.kind.title,
                systemImage: "exclamationmark.triangle",
                description: failure.description.map { Text(verbatim: $0) }
            )
        }
        .padding()
    }

}
