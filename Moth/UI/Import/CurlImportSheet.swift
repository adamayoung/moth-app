//  CurlImportSheet.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import SwiftUI

struct CurlImportSheet: View {

    @Bindable var model: ImportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURL_IMPORT_TITLE")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            TextEditor(text: $model.curlText)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .border(.separator)
                .accessibilityLabel("CURL_IMPORT_TEXT_LABEL")
                .accessibilityIdentifier("curlImport.text")

            if let problem = model.curlProblem {
                Text(verbatim: problem.message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("curlImport.problem")
            }

            buttons
        }
        .padding()
        .frame(minWidth: 520, minHeight: 280)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("curlImport")
    }

    private var buttons: some View {
        HStack {
            Spacer()

            Button("CURL_IMPORT_CANCEL") {
                model.cancelCurlImport()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(model.isImporting)
            .accessibilityIdentifier("curlImport.cancel")

            Button("CURL_IMPORT_IMPORT") {
                Task { await model.importCurl() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canSubmitCurl)
            .accessibilityIdentifier("curlImport.import")
        }
    }

}

@MainActor
private func previewModel(text: String = "", problem: CurlImportProblem? = nil) -> ImportModel? {
    guard let dataModel = try? DataModel.inMemory() else {
        return nil
    }
    let secretStore = InMemorySecretStore()
    let model = ImportModel(
        source: .panel,
        secretStore: secretStore,
        sidebar: SidebarModel(writer: dataModel.writer, secretStore: secretStore),
        environments: EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: nil)
        ),
        write: { _ in },
        createRequest: { _, _ in },
        openRequest: { _ in }
    )
    model.curlText = text
    model.curlProblem = problem
    return model
}

#Preview("Empty") {
    if let model = previewModel() {
        CurlImportSheet(model: model)
    }
}

#Preview("Command") {
    if let model = previewModel(text: "curl -X POST https://api.example.com/users \\\n  -d 'name=Ada'") {
        CurlImportSheet(model: model)
    }
}

#Preview("Invalid") {
    if let model = previewModel(text: "not a command", problem: .invalidCommand) {
        CurlImportSheet(model: model)
    }
}
