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
    let inheritedAuth: InheritedAuth
    @Binding var section: RequestEditorSection
    let credential: (SecretReference) -> SecretValue
    let loadCredential: (SecretReference) async -> Void
    let update: ((inout RequestDraft) -> Void) -> Void

    @FocusState private var focusedRow: KeyValue.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: name)
                .font(.headline)
                .lineLimit(1)

            address

            sectionBar

            sectionContent
                .frame(maxHeight: .infinity, alignment: .top)
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

    /// Add sits here, outside the scroll view, because a short pane would otherwise hide it below the rows.
    private var sectionBar: some View {
        HStack {
            Picker("REQUEST_EDITOR_SECTIONS_LABEL", selection: $section) {
                ForEach(RequestEditorSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("requestEditor.sections")

            Spacer()

            switch section {
            case .params:
                Button("REQUEST_EDITOR_ADD_PARAMETER") {
                    addRow(to: \.queryParameters)
                }
                .accessibilityIdentifier("params.add")
            case .headers:
                Button("REQUEST_EDITOR_ADD_HEADER") {
                    addRow(to: \.headers)
                }
                .accessibilityIdentifier("headers.add")
            case .body:
                addBodyRowButton
            case .auth:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var addBodyRowButton: some View {
        switch draft.body.kind {
        case .urlEncoded:
            Button("REQUEST_EDITOR_ADD_FIELD") {
                addURLEncodedRow()
            }
            .accessibilityIdentifier("urlEncoded.add")
        case .formData:
            Button("REQUEST_EDITOR_ADD_FIELD") {
                addFormDataRow()
            }
            .accessibilityIdentifier("formData.add")
        case .none, .raw, .binary, .graphQL:
            EmptyView()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .params:
            ScrollingRows(focusedRow: focusedRow) {
                VStack(alignment: .leading, spacing: 16) {
                    KeyValueGrid(
                        rows: draft.queryParameters,
                        identifierPrefix: "params",
                        removeLabel: "REQUEST_EDITOR_REMOVE_PARAMETER",
                        focusedRow: $focusedRow
                    ) { change in
                        update { change(&$0.queryParameters) }
                    }

                    if !draft.pathParameters.isEmpty {
                        PathVariablesGrid(rows: draft.pathParameters) { value, id in
                            update { $0.setPathValue(value, for: id) }
                        }
                    }
                }
            }
        case .headers:
            ScrollingRows(focusedRow: focusedRow) {
                KeyValueGrid(
                    rows: draft.headers,
                    identifierPrefix: "headers",
                    removeLabel: "REQUEST_EDITOR_REMOVE_HEADER",
                    focusedRow: $focusedRow
                ) { change in
                    update { change(&$0.headers) }
                }
            }
        case .body:
            BodyEditor(draft: draft.body, focusedRow: $focusedRow) { change in
                update { change(&$0.body) }
            }
        case .auth:
            ScrollView {
                AuthEditor(
                    draft: draft.auth,
                    inherited: inheritedAuth,
                    credential: credential,
                    load: loadCredential
                ) { change in
                    update { change(&$0.auth) }
                }
            }
        }
    }

    /// Focus moves on the next turn, because the new row's field does not exist until this change has rendered.
    private func addRow(to rows: WritableKeyPath<RequestDraft, [KeyValue]>) {
        let row = KeyValue(key: "", value: "")
        update { $0[keyPath: rows].append(row) }
        Task {
            focusedRow = row.id
        }
    }

    private func addURLEncodedRow() {
        let row = KeyValue(key: "", value: "")
        update { $0.body.urlEncodedRows.append(row) }
        Task {
            focusedRow = row.id
        }
    }

    private func addFormDataRow() {
        let row = FormDataField(key: "", value: .text(""))
        update { $0.body.formDataFields.append(row) }
        Task {
            focusedRow = row.id
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
