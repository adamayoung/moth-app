//  RequestEditorForm.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

enum RequestEditorSection: CaseIterable, Identifiable {

    case params
    case headers
    case body
    case auth

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .params: "REQUEST_EDITOR_SECTION_PARAMS"
        case .headers: "REQUEST_EDITOR_SECTION_HEADERS"
        case .body: "REQUEST_EDITOR_SECTION_BODY"
        case .auth: "REQUEST_EDITOR_SECTION_AUTH"
        }
    }

}

struct RequestEditorForm: View {

    let name: String
    let draft: RequestDraft
    @Binding var section: RequestEditorSection
    let update: ((inout RequestDraft) -> Void) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: name)
                .font(.headline)
                .lineLimit(1)

            address

            Picker("REQUEST_EDITOR_SECTIONS_LABEL", selection: $section) {
                ForEach(RequestEditorSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("requestEditor.sections")

            ScrollView {
                sectionContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private var address: some View {
        HStack {
            Picker("REQUEST_EDITOR_METHOD_LABEL", selection: method) {
                ForEach(methods, id: \.self) { method in
                    Text(verbatim: method.rawValue).tag(method)
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("requestEditor.method")

            TextField("REQUEST_EDITOR_URL_LABEL", text: url)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("requestEditor.url")
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .params:
            VStack(alignment: .leading, spacing: 16) {
                KeyValueGrid(
                    rows: draft.queryParameters,
                    identifierPrefix: "params",
                    addTitle: "REQUEST_EDITOR_ADD_PARAMETER",
                    removeLabel: "REQUEST_EDITOR_REMOVE_PARAMETER"
                ) { rows in
                    update { $0.queryParameters = rows }
                }

                if !draft.pathParameters.isEmpty {
                    PathVariablesGrid(rows: draft.pathParameters) { value, id in
                        update { $0.setPathValue(value, for: id) }
                    }
                }
            }
        case .headers:
            KeyValueGrid(
                rows: draft.headers,
                identifierPrefix: "headers",
                addTitle: "REQUEST_EDITOR_ADD_HEADER",
                removeLabel: "REQUEST_EDITOR_REMOVE_HEADER"
            ) { rows in
                update { $0.headers = rows }
            }
        case .body, .auth:
            EmptyView()
        }
    }

    /// A custom method keeps its entry, because a request can arrive with one from an import.
    private var methods: [HTTPMethod] {
        HTTPMethod.standard.contains(draft.method) ? HTTPMethod.standard : HTTPMethod.standard + [draft.method]
    }

    private var method: Binding<HTTPMethod> {
        Binding {
            draft.method
        } set: { method in
            update { $0.method = method }
        }
    }

    private var url: Binding<String> {
        Binding {
            draft.url
        } set: { url in
            update { $0.url = url }
        }
    }

}
