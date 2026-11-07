//  HistoryRequestView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct HistoryRequestView: View {

    let request: Request

    var body: some View {
        ScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("HISTORY_REQUEST_AUTH")
                        .fontWeight(.medium)

                    Text(RequestDraft(request).auth.kind.title)
                        .accessibilityIdentifier("history.request.auth")
                }

                if !headers.isEmpty {
                    heading("HISTORY_REQUEST_HEADERS")

                    ForEach(headers) { header in
                        GridRow {
                            Text(verbatim: header.key)
                                .fontWeight(.medium)
                                .accessibilityIdentifier("history.request.header.name")

                            Text(verbatim: header.value)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("history.request.header.value")
                        }
                    }
                }

                if let bodyText {
                    heading("HISTORY_REQUEST_BODY")

                    Text(verbatim: bodyText)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .gridCellColumns(2)
                        .accessibilityIdentifier("history.request.body")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var headers: [KeyValue] {
        request.headers.filter(\.isEnabled)
    }

    private var bodyText: String? {
        switch request.body {
        case .none, .binary:
            nil
        case .raw(let content, _):
            content
        case .graphQL(let query, _):
            query
        case .urlEncoded(let rows):
            rows.filter(\.isEnabled).map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        case .formData(let fields):
            fields.filter(\.isEnabled).compactMap { field in
                guard case .text(let value) = field.value else {
                    return nil
                }
                return "\(field.key)=\(value)"
            }
            .joined(separator: "\n")
        }
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
            .gridCellColumns(2)
    }

}

#Preview {
    HistoryRequestView(request: Request(
        name: "Create",
        method: .post,
        urlTemplate: "https://api.example.com/users",
        headers: [
            KeyValue(key: "Authorization", value: HistoryEntry.maskedValue),
            KeyValue(key: "Content-Type", value: "application/json")
        ],
        body: .raw(content: #"{"name":"Moth"}"#, contentType: "application/json"),
        auth: .bearer(BearerAuth(token: SecretReference(identifier: "token")))
    ))
    .frame(width: 500, height: 260)
}
