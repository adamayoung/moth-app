//  GenerateCodeSheet.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothImport
import SwiftUI

struct GenerateCodeSheet: View {

    let code: GeneratedCode
    let copy: (String) -> Void

    @State private var language = CodeLanguage.curl
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GENERATE_CODE_TITLE")
                .font(.headline)

            Picker("GENERATE_CODE_LANGUAGE", selection: $language) {
                Text("GENERATE_CODE_LANGUAGE_CURL").tag(CodeLanguage.curl)
                Text("GENERATE_CODE_LANGUAGE_SWIFT").tag(CodeLanguage.swiftURLSession)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("generateCode.language")

            ReadOnlyTextView(text: code.text(in: language), accessibilityIdentifier: "generateCode.text")

            HStack {
                Button("GENERATE_CODE_COPY") {
                    copy(code.text(in: language))
                }
                .accessibilityIdentifier("generateCode.copy")

                Spacer()

                Button("GENERATE_CODE_DONE") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("generateCode.done")
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generateCode")
    }

}

#Preview {
    GenerateCodeSheet(
        code: GeneratedCode(
            curl: """
            curl --url 'https://example.com/users?limit=10' \\
              --header 'Accept: application/json' \\
              --header 'Authorization: Bearer <token>'
            """,
            swift: """
            import Foundation

            var request = URLRequest(url: URL(string: "https://example.com/users?limit=10")!)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer <token>", forHTTPHeaderField: "Authorization")
            """
        ),
        copy: { _ in }
    )
}
