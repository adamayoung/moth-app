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
    case settings

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .params: "REQUEST_EDITOR_SECTION_PARAMS"
        case .headers: "REQUEST_EDITOR_SECTION_HEADERS"
        case .body: "REQUEST_EDITOR_SECTION_BODY"
        case .auth: "REQUEST_EDITOR_SECTION_AUTH"
        case .settings: "REQUEST_EDITOR_SECTION_SETTINGS"
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
    let isSending: Bool
    let send: () -> Void
    let cancelSend: () -> Void
    var urlFocusRequests = 0
    var accessToken = AccessTokenControls()

    @FocusState private var focusedRow: KeyValue.ID?
    @FocusState private var isURLFocused: Bool
    @State private var urlSelection: TextSelection?

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

            TextField("REQUEST_EDITOR_URL_LABEL", text: url, selection: $urlSelection)
                .textFieldStyle(.roundedBorder)
                .focused($isURLFocused)
                .accessibilityIdentifier("requestEditor.url")
                .onChange(of: urlFocusRequests) {
                    isURLFocused = true
                    urlSelection = TextSelection(range: draft.url.startIndex ..< draft.url.endIndex)
                }
                .onChange(of: isURLFocused) { _, isFocused in
                    if !isFocused {
                        urlSelection = nil
                    }
                }

            if isSending {
                Button("REQUEST_EDITOR_CANCEL_SEND", action: cancelSend)
                    .accessibilityIdentifier("requestEditor.cancel")
            } else {
                Button("REQUEST_EDITOR_SEND", action: send)
                    .buttonStyle(.borderedProminent)
                    .disabled(!draft.hasURL)
                    .accessibilityIdentifier("requestEditor.send")
            }
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
                    addRow(KeyValue(key: "", value: ""), to: \.queryParameters)
                }
                .accessibilityIdentifier("params.add")
            case .headers:
                Button("REQUEST_EDITOR_ADD_HEADER") {
                    addRow(KeyValue(key: "", value: ""), to: \.headers)
                }
                .accessibilityIdentifier("headers.add")
            case .body:
                addBodyRowButton
            case .auth, .settings:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var addBodyRowButton: some View {
        switch draft.body.kind {
        case .urlEncoded:
            Button("REQUEST_EDITOR_ADD_FIELD") {
                addRow(KeyValue(key: "", value: ""), to: \.body.urlEncodedRows)
            }
            .accessibilityIdentifier("urlEncoded.add")
        case .formData:
            Button("REQUEST_EDITOR_ADD_FIELD") {
                addRow(FormDataField(key: "", value: .text("")), to: \.body.formDataFields)
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
                    load: loadCredential,
                    update: { change in update { change(&$0.auth) } },
                    accessToken: accessToken
                )
            }
        case .settings:
            SettingsEditor(settings: draft.settings) { change in
                update { change(&$0.settings) }
            }
        }
    }

    /// Focus moves on the next turn, because the new row's field does not exist until this change has rendered.
    private func addRow<Row: EditableRow>(_ row: Row, to rows: WritableKeyPath<RequestDraft, [Row]>) {
        update { $0[keyPath: rows].append(row) }
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
