//  ImportProgressFooter.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// A footer, not a sheet, because a sheet would block the window for as long as a large file takes.
struct ImportProgressFooter: View {

    var body: some View {
        Label {
            Text("IMPORT_PROGRESS")
        } icon: {
            ProgressView()
                .controlSize(.mini)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("IMPORT_PROGRESS")
        .accessibilityIdentifier("importProgress")
    }

}

#Preview {
    ImportProgressFooter()
        .frame(width: 240)
}
