//  ICloudSyncOffFooter.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct ICloudSyncOffFooter: View {

    private static let helpText: LocalizedStringKey = "SIDEBAR_ICLOUD_SYNC_OFF_HELP"

    var body: some View {
        Label("SIDEBAR_ICLOUD_SYNC_OFF", systemImage: "icloud.slash")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .help(Self.helpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("SIDEBAR_ICLOUD_SYNC_OFF")
            // A tooltip needs a pointer and its text never reaches XCUITest. macOS exposes a value only on static text.
            .accessibilityValue(Self.helpText)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("iCloudSyncOffFooter")
    }

}

#Preview {
    ICloudSyncOffFooter()
        .frame(width: 240)
}
