//  ImportResultSheet.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct ImportResultSheet: View {

    let report: ImportReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(report.message)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("importResult.message")

            if let skipped = report.skipped {
                Text(skipped)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("importResult.skipped")
            }

            HStack {
                Spacer()
                Button("IMPORT_RESULT_DONE") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("importResult.done")
            }
        }
        .padding()
        .frame(minWidth: 360, maxWidth: 480, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importResult")
    }

}

#Preview("With Skipped Items") {
    ImportResultSheet(report: ImportReport(
        message: "Imported \u{201C}auth-v1\u{201D}: 2 requests, 1 folder.",
        skipped: "Skipped 8 scripts, 1 folder variable, 5 descriptions and 1 OAuth 1.0 auth."
    ))
}

#Preview("Nothing Skipped") {
    ImportResultSheet(report: ImportReport(
        message: "Imported \u{201C}Multipart/form-data\u{201D}: 1 request, 0 folders.",
        skipped: nil
    ))
}

#Preview("Rejected") {
    ImportResultSheet(report: .rejected)
}
