//  BodyEditor.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct BodyEditor: View {

    let draft: BodyDraft
    var focusedRow: FocusState<UUID?>.Binding
    let update: ((inout BodyDraft) -> Void) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                kindPicker

                if draft.kind == .raw {
                    contentTypePicker
                }
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var kindPicker: some View {
        Picker("BODY_KIND_LABEL", selection: kind) {
            ForEach(draft.kinds, id: \.self) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("body.kind")
    }

    /// A stored type outside the four keeps its entry, because an import can bring one and a change can be undone.
    private var contentTypePicker: some View {
        Picker("RAW_CONTENT_TYPE_LABEL", selection: contentType) {
            ForEach(RawContentType.allCases, id: \.self) { type in
                Text(type.title).tag(type.rawValue)
            }
            if let stored = draft.storedContentType {
                Text(verbatim: stored).tag(stored)
            }
        }
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("body.rawType")
    }

    @ViewBuilder
    private var content: some View {
        switch draft.kind {
        case .none:
            EmptyView()
        case .raw:
            TextEditor(text: rawContent)
                .font(.body.monospaced())
                .border(.separator)
                .accessibilityLabel("RAW_BODY_LABEL")
                .accessibilityIdentifier("body.raw")
        case .urlEncoded:
            ScrollingRows(focusedRow: focusedRow.wrappedValue) {
                KeyValueGrid(
                    rows: draft.urlEncodedRows,
                    identifierPrefix: "urlEncoded",
                    removeLabel: "REQUEST_EDITOR_REMOVE_FIELD",
                    focusedRow: focusedRow
                ) { change in
                    update { change(&$0.urlEncodedRows) }
                }
            }
        case .formData:
            ScrollingRows(focusedRow: focusedRow.wrappedValue) {
                KeyValueGrid(
                    rows: draft.formDataFields,
                    identifierPrefix: "formData",
                    removeLabel: "REQUEST_EDITOR_REMOVE_FIELD",
                    focusedRow: focusedRow
                ) { change in
                    update { change(&$0.formDataFields) }
                }
            }
        case .binary, .graphQL:
            Text("NOT_SUPPORTED_YET")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("body.notSupported")
        }
    }

    private var kind: Binding<BodyKind> {
        Binding {
            draft.kind
        } set: { kind in
            update { $0.kind = kind }
        }
    }

    private var contentType: Binding<String> {
        Binding {
            draft.rawContentType
        } set: { contentType in
            update { $0.rawContentType = contentType }
        }
    }

    private var rawContent: Binding<String> {
        Binding {
            draft.rawContent
        } set: { content in
            update { $0.rawContent = content }
        }
    }

}

private struct BodyEditorPreview: View {

    @State var draft: BodyDraft
    @FocusState private var focusedRow: UUID?

    var body: some View {
        BodyEditor(draft: draft, focusedRow: $focusedRow) { change in
            change(&draft)
        }
        .padding()
        .frame(width: 560, height: 240)
    }

}

#Preview("Raw") {
    BodyEditorPreview(draft: BodyDraft(.raw(content: "{\n  \"name\": \"Ada\"\n}", contentType: "application/json")))
}

#Preview("Raw With a Stored Type") {
    BodyEditorPreview(draft: BodyDraft(.raw(content: "print()", contentType: "application/javascript")))
}

#Preview("URL Encoded") {
    BodyEditorPreview(draft: BodyDraft(.urlEncoded([
        KeyValue(key: "name", value: "Ada"),
        KeyValue(key: "age", value: "36", isEnabled: false)
    ])))
}

#Preview("Form Data With a File") {
    BodyEditorPreview(draft: BodyDraft(.formData([
        FormDataField(key: "name", value: .text("Ada")),
        FormDataField(key: "photo", value: .file(paths: ["/tmp/photo.png"]))
    ])))
}

#Preview("Binary") {
    BodyEditorPreview(draft: BodyDraft(.binary(filePath: "/tmp/a.bin")))
}
